extends SceneTree

## Verification for the dispenser shelf: a one-slot, source-only shelf whose segmented indicator
## counts the items it still holds, the one on display included.
##
## The board is supplied inline rather than by loading a campaign level, because no campaign level
## uses dispensers yet. `_apply_level_config()` rebuilds the shelves from a config dictionary exactly
## the way `_ready()` does, so this exercises the real construction path.
##
## This run reports two leaked `SceneTreeTimer` instances at exit. They belong to the completion
## reveal window, which this test reaches by force-freeing a level instead of letting it change
## scene; the shipped path re-checks `is_inside_tree()` after that await. Not a dispenser leak --
## `--verbose` names the two objects if it needs re-checking.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"

## Two standard shelves and one dispenser. The standard pair starts one candy_bag short of a triple
## and the dispenser holds the third, so the first move both drains a socket and clears a match.
const DISPENSER_LEVEL_CONFIG := {
	"level": 1,
	"time_seconds": 300,
	"row_layouts": [
		{"shelf_count": 2},
		{"shelf_count": 1},
	],
	"shelves": [
		{"layers": [["candy_bag", "candy_bag", null]]},
		{"layers": [[null, null, null]]},
		{
			"type": "dispenser",
			"layers": [["candy_bag"], ["milk_carton"], ["toy_unicorn"]],
		},
	],
}

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Dispenser shelf verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return

	call_deferred("_run")


func _run() -> void:
	await process_frame

	await _test_construction_and_capabilities()
	await _test_taking_an_item_drains_one_socket()
	await _test_cancelled_move_leaves_the_count_alone()
	await _test_ability_targeting()
	await _test_completion_waits_for_the_queue()

	await _wait_frames(30)

	if _failures.is_empty():
		print("Dispenser shelf verification passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


## One slot, a full indicator, and a shelf that can be taken from but not placed onto.
func _test_construction_and_capabilities() -> void:
	var level := await _make_dispenser_level()
	var dispenser := _find_dispenser(level)
	if dispenser == null:
		_failures.append("Config with a dispenser shelf should build a DispenserShelf node.")
		await _teardown(level)
		return

	var front_slots: Array = level.call("_get_front_slots", dispenser)
	_check(front_slots.size() == 1, "A dispenser exposes exactly one front slot.")
	_check(
		int(dispenser.call("get_capacity")) == 3,
		"Indicator capacity should equal the dispenser's authored item count."
	)
	_check(
		int(dispenser.call("get_remaining_count")) == 3,
		"A freshly built dispenser holds every authored item."
	)

	var indicator := dispenser.get_node_or_null("LayerIndicator")
	_check(indicator != null, "A dispenser owns a layer indicator.")
	if indicator != null:
		_check(
			int(indicator.call("get_capacity")) == 3 and int(indicator.call("get_remaining")) == 3,
			"Indicator should start with every socket lit."
		)
		var count_label := indicator.get_node_or_null("CountLabel") as Label
		_check(
			count_label != null and count_label.text == "3",
			"Count badge should read the number of items still on the shelf."
		)
		var sockets := indicator.get_node_or_null("Sockets")
		_check(
			sockets != null and sockets.get_child_count() == 3,
			"Indicator should build one socket per authored item."
		)

	var dispenser_slot := front_slots[0] as Node2D
	_check(
		bool(level.call("_is_slot_move_source_eligible", dispenser_slot)),
		"A dispenser's item can be picked up."
	)
	_check(
		not bool(level.call("_is_slot_drop_target_eligible", dispenser_slot)),
		"A dispenser never accepts a dropped item."
	)
	_check(
		not bool(dispenser.call("forms_triples")),
		"A dispenser never resolves its own layer as a triple."
	)

	# Drop targeting runs off the marker positions, so prove the dispenser is skipped even when the
	# pointer is sitting directly on its slot.
	var marker := level.call("_get_slot_marker", dispenser_slot) as Marker2D
	if marker != null:
		var nearest := level.call("_find_nearest_slot", marker.global_position) as Node2D
		_check(
			nearest != dispenser_slot,
			"Releasing a dragged item over a dispenser should not resolve to its slot."
		)

	await _teardown(level)


## Taking the visible item drops the count by exactly one and promotes the next queued item.
func _test_taking_an_item_drains_one_socket() -> void:
	var level := await _make_dispenser_level()
	var dispenser := _find_dispenser(level)
	var target_slot := _find_empty_standard_slot(level)
	if dispenser == null or target_slot == null:
		_failures.append("Dispenser board should offer an empty standard slot to move into.")
		await _teardown(level)
		return

	var dispenser_slot := (level.call("_get_front_slots", dispenser) as Array)[0] as Node2D
	var taken_item := level.call("_get_slot_item", dispenser_slot) as ShelfItem
	_check(
		taken_item != null and str(taken_item.item_id) == "candy_bag",
		"A dispenser displays its first authored layer."
	)

	var did_move := bool(level.call("_move_item_to_slot", taken_item, dispenser_slot, target_slot))
	_check(did_move, "An item can be moved off a dispenser onto a standard shelf.")
	_check(
		int(dispenser.call("get_remaining_count")) == 2,
		"Taking one item drops the remaining count by exactly one."
	)

	await _wait_seconds(0.6)

	var promoted_item := level.call("_get_slot_item", dispenser_slot) as ShelfItem
	_check(
		promoted_item != null and str(promoted_item.item_id) == "milk_carton",
		"The next queued item promotes into the slot once the front layer empties."
	)
	_check(
		int(dispenser.call("get_remaining_count")) == 2,
		"Promoting the queue does not change the count -- the item is still on the shelf."
	)

	var indicator := dispenser.get_node_or_null("LayerIndicator")
	if indicator != null:
		var count_label := indicator.get_node_or_null("CountLabel") as Label
		_check(
			count_label != null and count_label.text == "2",
			"The count badge follows the remaining count."
		)
		var sockets := indicator.get_node_or_null("Sockets")
		_check(
			sockets != null and sockets.get_child_count() == 3,
			"Depleting a socket leaves the track width alone; the socket goes dark instead."
		)
		var drained_fill := _get_socket_fill(indicator, 2)
		_check(
			drained_fill != null and not drained_fill.visible,
			"The drained socket's lit fill should be hidden once its animation finishes."
		)

	await _teardown(level)


## A pick-up that never commits must leave the count untouched, even though the item spends the drag
## reparented away from its slot.
func _test_cancelled_move_leaves_the_count_alone() -> void:
	var level := await _make_dispenser_level()
	var dispenser := _find_dispenser(level)
	if dispenser == null:
		await _teardown(level)
		return

	var dispenser_slot := (level.call("_get_front_slots", dispenser) as Array)[0] as Node2D
	var item := level.call("_get_slot_item", dispenser_slot) as ShelfItem
	var marker := level.call("_get_slot_marker", dispenser_slot) as Marker2D

	level.call("_begin_drag", item, marker.global_position)
	_check(
		int(dispenser.call("get_remaining_count")) == 3,
		"Picking an item up does not spend it."
	)

	# Release far from every shelf so the drag resolves to no target and the item goes home.
	level.call("_finish_active_drag", marker.global_position + Vector2(0.0, -4000.0))
	await _wait_seconds(0.6)

	_check(
		int(dispenser.call("get_remaining_count")) == 3,
		"An item returned to its dispenser is still on the shelf."
	)
	_check(
		level.call("_get_slot_item", dispenser_slot) != null,
		"A cancelled drag puts the item back in the dispenser's slot."
	)

	await _teardown(level)


## Hammer and shuffle leave dispensers alone so the authored queue survives; highlight still reads
## them, because it only draws an outline.
func _test_ability_targeting() -> void:
	var level := await _make_dispenser_level()
	var dispenser := _find_dispenser(level)
	if dispenser == null:
		await _teardown(level)
		return

	var all_visible: Array = level.call("_get_visible_items")
	var ability_visible: Array = level.call("_get_visible_items", true)
	_check(
		_has_item_from(level, all_visible, dispenser),
		"A dispenser's visible item is still a visible item."
	)
	_check(
		not _has_item_from(level, ability_visible, dispenser),
		"Hammer's candidate list excludes dispenser items."
	)
	_check(
		not _has_item_from(level, level.call("_get_first_back_layer_items", true), dispenser),
		"Hammer's back-layer supplement excludes a dispenser's queue."
	)
	_check(
		not _has_item_from(level, level.call("_get_shuffle_eligible_items"), dispenser),
		"Shuffle excludes a dispenser's queue so its authored identities survive."
	)
	_check(
		_has_item_from(level, level.call("_find_immediate_triple_items"), dispenser),
		"Highlight should point at the dispenser item that completes the waiting pair."
	)

	await _teardown(level)


## The level is not won while a dispenser still holds items, and is won once it drains.
func _test_completion_waits_for_the_queue() -> void:
	var level := await _make_dispenser_level()
	var dispenser := _find_dispenser(level)
	if dispenser == null:
		await _teardown(level)
		return

	# Empty every standard shelf, leaving only the dispenser's queue on the board.
	for shelf in level.call("_get_all_shelves") as Array:
		if shelf == dispenser:
			continue

		for item in level.call("_get_shelf_items", shelf) as Array:
			item.free()

	level.call("_check_level_completed")
	_check(
		not bool(level.get("_level_completed")),
		"A board is not cleared while a dispenser still holds items."
	)

	for item in level.call("_get_all_items") as Array:
		item.free()

	level.call("_check_level_completed")
	_check(
		bool(level.get("_level_completed")),
		"Draining the dispenser clears the board."
	)

	# Completion opens a COMPLETION_REVEAL_SECONDS window before the reward screen; wait it out so
	# the level is not freed with that timer still suspended.
	await _wait_seconds(1.5)
	await _teardown(level)


## Lets in-flight move/promotion/indicator tweens and the suspended shelf-resolution coroutines
## finish before the board goes away, so teardown does not strand references to freed nodes.
func _teardown(level: Node) -> void:
	await _wait_seconds(0.5)
	level.free()


func _make_dispenser_level() -> Node:
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level := level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 1)
	root.add_child(level)
	await process_frame

	level.set("_sound_effects_enabled", false)
	level.call("_apply_level_config", DISPENSER_LEVEL_CONFIG)
	# _ready() collects slots after applying its own config; rebuilding the board here has to
	# refresh the same cache or drop targeting would still be pointing at the freed shelves.
	level.call("_collect_slots")
	await process_frame
	return level


func _find_dispenser(level: Node) -> Node2D:
	for shelf in level.call("_get_all_shelves") as Array:
		if shelf is DispenserShelf:
			return shelf as Node2D

	return null


func _find_empty_standard_slot(level: Node) -> Node2D:
	for shelf in level.call("_get_all_shelves") as Array:
		if shelf is DispenserShelf:
			continue

		for slot in level.call("_get_front_slots", shelf) as Array:
			if level.call("_get_slot_item", slot) == null:
				return slot as Node2D

	return null


func _has_item_from(level: Node, items: Array, shelf: Node2D) -> bool:
	for item in items:
		if level.call("_get_owning_shelf", item) == shelf:
			return true

	return false


func _get_socket_fill(indicator: Node, index: int) -> Node2D:
	var sockets := indicator.get_node_or_null("Sockets")
	if sockets == null or index >= sockets.get_child_count():
		return null

	var socket := sockets.get_child(index) as Node2D
	return socket.get_node_or_null("Fill") as Node2D


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout
