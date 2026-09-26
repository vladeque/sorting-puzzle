extends SceneTree

## Verification that an item landing after a drop is drawn above a locked shelf's chains and padlock.
##
## A dispenser sits between shelves in a column, so the shelf directly above or below it is often a
## locked one. Releasing a dragged dispenser item over that shelf is an invalid drop, and the item
## rewinds home from where it was released -- underneath the lock overlay if its flight z-index does
## not clear the overlay's own. Run through:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/gameplay/test_item_flight_over_locked_shelf.gd
##
## The board is supplied inline so verification does not depend on mutable campaign content.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"
const RESTING_ITEM_Z_INDEX := 10
const FLIGHT_SECONDS := 0.4

## One locked standard shelf and one dispenser. The drag starts on the dispenser and is released over
## the locked shelf, which refuses drops.
const LOCKED_NEIGHBOUR_LEVEL_CONFIG := {
	"level": 1,
	"time_seconds": 300,
	"row_layouts": [
		{"shelf_count": 2},
		{"shelf_count": 1},
	],
	"shelves": [
		{"layers": [["candy_bag", "milk_carton", null]], "unlock_after_triples": 5},
		{"layers": [[null, null, null]]},
		{
			"type": "dispenser",
			"layers": [["toy_unicorn"], ["candy_bag"], ["milk_carton"]],
		},
	],
}

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Item flight verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return

	call_deferred("_run")


func _run() -> void:
	await process_frame

	await _test_rejected_drop_over_locked_shelf_flies_above_the_lock()

	await _wait_frames(30)

	if _failures.is_empty():
		print("Item flight over locked shelf verification passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_rejected_drop_over_locked_shelf_flies_above_the_lock() -> void:
	var level := await _make_level()
	var locked_shelf := _find_locked_shelf(level)
	var dispenser := _find_dispenser(level)
	if locked_shelf == null or dispenser == null:
		_check(false, "The fixture needs a locked shelf and a dispenser.")
		await _teardown(level)
		return

	var overlay := locked_shelf.get_node_or_null("LockedOverlay") as ShelfLockOverlay
	_check(overlay != null and overlay.visible, "The locked shelf shows its lock overlay.")
	if overlay == null:
		await _teardown(level)
		return

	var dispenser_slot := (level.call("_get_front_slots", dispenser) as Array)[0] as Node2D
	var item := level.call("_get_slot_item", dispenser_slot) as ShelfItem
	var marker := level.call("_get_slot_marker", dispenser_slot) as Marker2D
	var locked_marker := (
		level.call("_get_slot_marker", (level.call("_get_front_slots", locked_shelf) as Array)[1])
		as Marker2D
	)
	if item == null:
		_check(false, "The dispenser holds an item to drag.")
		await _teardown(level)
		return

	level.set("item_move_duration_seconds", FLIGHT_SECONDS)
	level.call("_begin_drag", item, marker.global_position)
	level.call("_move_active_drag", locked_marker.global_position)
	level.call("_finish_active_drag", locked_marker.global_position)
	await process_frame

	_check(
		level.call("_get_slot_item", dispenser_slot) == item,
		"A drop over a locked shelf is refused and the item heads back to its dispenser."
	)
	_check(
		_get_absolute_z_index(item) > _get_highest_absolute_z_index(overlay),
		"An item rewinding across a locked shelf is drawn above the chains and padlock."
	)
	var drag_layer := level.get("_drag_layer") as Node2D
	_check(
		_get_absolute_z_index(item) < _get_absolute_z_index(drag_layer),
		"A landing item stays below an item the player is still holding."
	)

	await _wait_seconds(FLIGHT_SECONDS + 0.4)
	_check(
		item.z_index == RESTING_ITEM_Z_INDEX,
		"An item that has landed returns to the resting z-index."
	)

	await _teardown(level)


## CanvasItem has no absolute-z getter, so this sums z_index up the ancestry the way the renderer
## resolves it: a node with z_as_relative off starts a fresh chain.
func _get_absolute_z_index(node: CanvasItem) -> int:
	var total := 0
	var current: Node = node
	while current is CanvasItem:
		var canvas_item := current as CanvasItem
		total += canvas_item.z_index
		if not canvas_item.z_as_relative:
			break
		current = current.get_parent()

	return total


func _get_highest_absolute_z_index(node: Node) -> int:
	var highest := -4096
	var canvas_item := node as CanvasItem
	if canvas_item != null:
		highest = _get_absolute_z_index(canvas_item)

	for child in node.get_children():
		highest = maxi(highest, _get_highest_absolute_z_index(child))

	return highest


func _make_level() -> Node:
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level := level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 1)
	root.add_child(level)
	await process_frame

	level.set("_sound_effects_enabled", false)
	level.call("_apply_level_config", LOCKED_NEIGHBOUR_LEVEL_CONFIG)
	# _ready() collects slots after applying its own config; rebuilding the board here has to refresh
	# the same cache or drop targeting would still be pointing at the freed shelves.
	level.call("_collect_slots")
	await process_frame
	return level


func _find_locked_shelf(level: Node) -> Node2D:
	for shelf in level.call("_get_all_shelves") as Array:
		if bool(level.call("_is_shelf_locked", shelf)):
			return shelf as Node2D

	return null


func _find_dispenser(level: Node) -> Node2D:
	for shelf in level.call("_get_all_shelves") as Array:
		if shelf is DispenserShelf:
			return shelf as Node2D

	return null


## Lets the in-flight move tween finish before the board goes away, so teardown does not strand
## references to freed nodes.
func _teardown(level: Node) -> void:
	await _wait_seconds(0.5)
	level.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout
