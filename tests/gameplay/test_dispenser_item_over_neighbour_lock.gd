extends SceneTree

## Verification that an item standing in a dispenser is drawn over the padlock of a locked shelf in the
## row above it, without disturbing how the dispenser layers its own parts.
##
## A dispenser is packed directly under the row above, and a locked shelf there hangs its padlock to
## the bottom of that shelf, so a tall item's tip -- a pump nozzle, a unicorn horn -- reaches under
## it. The item's body is lifted over the lock overlay for that. Everything else in the dispenser has
## a fixed order the lift must not upset: the ground shadow stays under the side guards, the stock
## readout stays over the item's base, and a locked dispenser still covers its own item. Run through:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/gameplay/test_dispenser_item_over_neighbour_lock.gd
##
## The boards are supplied inline so verification does not depend on mutable campaign content.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"

## A locked standard shelf, a dispenser under it, and a standard shelf under that.
const LOCK_ABOVE_DISPENSER_CONFIG := {
	"level": 1,
	"time_seconds": 300,
	"row_layouts": [
		{"shelf_count": 1},
		{"shelf_count": 1},
		{"shelf_count": 1},
	],
	"shelves": [
		{"layers": [["candy_bag", "milk_carton", null]], "unlock_after_triples": 5},
		{
			"type": "dispenser",
			"layers": [["soap_pump"], ["candy_bag"], ["milk_carton"]],
		},
		{"layers": [[null, null, null]]},
	],
}

## The same column with the dispenser itself locked.
const LOCKED_DISPENSER_CONFIG := {
	"level": 1,
	"time_seconds": 300,
	"row_layouts": [
		{"shelf_count": 1},
		{"shelf_count": 1},
		{"shelf_count": 1},
	],
	"shelves": [
		{"layers": [["candy_bag", "milk_carton", null]]},
		{
			"type": "dispenser",
			"layers": [["soap_pump"], ["candy_bag"], ["milk_carton"]],
			"unlock_after_triples": 5,
		},
		{"layers": [[null, null, null]]},
	],
}

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Dispenser item layering verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return

	call_deferred("_run")


func _run() -> void:
	await process_frame

	await _test_item_body_draws_over_the_lock_above()
	await _test_dispenser_parts_keep_their_order()
	await _test_locked_dispenser_still_covers_its_item()
	await _test_lift_follows_the_shelf_the_item_rests_on()

	await _wait_frames(30)

	if _failures.is_empty():
		print("Dispenser item over neighbour lock verification passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_item_body_draws_over_the_lock_above() -> void:
	var level := await _make_level(LOCK_ABOVE_DISPENSER_CONFIG)
	var dispenser := _find_dispenser(level)
	var locked_shelf := _find_locked_shelf(level)
	var item := _get_dispenser_item(level, dispenser)
	var overlay := (
		locked_shelf.get_node_or_null("LockedOverlay") as ShelfLockOverlay
		if locked_shelf != null
		else null
	)
	if item == null or overlay == null or not overlay.visible:
		_check(false, "The fixture needs a dispenser item under a locked shelf.")
		await _teardown(level)
		return

	var body := item.get_node("Sprite2D") as CanvasItem
	var outline := item.get_node("OutlineSprite") as CanvasItem
	var body_z := _get_absolute_z_index(body)
	_check(
		body_z > _get_highest_absolute_z_index(overlay),
		"A dispenser item's body is drawn over the padlock of the locked shelf above it."
	)
	_check(
		_get_absolute_z_index(outline) == body_z,
		"The selection outline lifts with the body it outlines."
	)

	# The lift is on the body only: the item's own depth is what orders it against other items.
	_check(
		item.z_index == 10,
		"The item's own z-index is unchanged by the body lift."
	)
	await _teardown(level)


func _test_dispenser_parts_keep_their_order() -> void:
	var level := await _make_level(LOCK_ABOVE_DISPENSER_CONFIG)
	var dispenser := _find_dispenser(level)
	var item := _get_dispenser_item(level, dispenser)
	if item == null:
		_check(false, "The fixture needs a dispenser item.")
		await _teardown(level)
		return

	var body_z := _get_absolute_z_index(item.get_node("Sprite2D") as CanvasItem)
	var shadow_z := _get_absolute_z_index(item.get_node("Shadow") as CanvasItem)
	for wall_name in [
		"RightWallInnerFace",
		"RightWallTopBevel",
		"RightWallUpperFace",
		"RightWallLowerBevel",
	]:
		var wall := dispenser.get_node_or_null(wall_name) as CanvasItem
		_check(
			wall != null and _get_absolute_z_index(wall) > shadow_z,
			"%s stays over the item's ground shadow, so the shadow cannot stain the guard." % wall_name
		)

	var indicator := dispenser.get_node_or_null("LayerIndicator") as Node
	if indicator == null:
		_check(false, "The dispenser has a stock readout.")
	else:
		_check(
			_get_absolute_z_index(indicator.get_node("TrackBacking") as CanvasItem) < body_z,
			"The stock rail's backing stays behind the item's base."
		)
		_check(
			_get_lowest_absolute_z_index(indicator.get_node("Segments")) > body_z
			and _get_absolute_z_index(indicator.get_node("CountLabel") as CanvasItem) > body_z,
			"The stock segments and count badge stay over the item's base."
		)

	await _teardown(level)


func _test_locked_dispenser_still_covers_its_item() -> void:
	var level := await _make_level(LOCKED_DISPENSER_CONFIG)
	var dispenser := _find_dispenser(level)
	var item := _get_dispenser_item(level, dispenser)
	var overlay := (
		dispenser.get_node_or_null("LockedOverlay") as ShelfLockOverlay
		if dispenser != null
		else null
	)
	if item == null or overlay == null or not overlay.visible:
		_check(false, "The fixture needs a locked dispenser holding an item.")
		await _teardown(level)
		return

	var overlay_lowest := _get_lowest_absolute_z_index(overlay)
	_check(
		overlay_lowest > _get_absolute_z_index(item.get_node("Sprite2D") as CanvasItem),
		"A locked dispenser's own overlay covers its item's lifted body."
	)
	var indicator := dispenser.get_node("LayerIndicator") as Node
	_check(
		overlay_lowest > _get_highest_absolute_z_index(indicator),
		"A locked dispenser's own overlay covers its stock readout."
	)

	# An item released over the locked dispenser rewinds home above its overlay, not under it.
	var constants := (level.get_script() as GDScript).get_script_constant_map()
	_check(
		int(constants.get("ITEM_MOVE_FLIGHT_Z_INDEX", 0)) > _get_highest_absolute_z_index(overlay),
		"A landing item flies above a locked dispenser's overlay."
	)
	await _teardown(level)


func _test_lift_follows_the_shelf_the_item_rests_on() -> void:
	var level := await _make_level(LOCK_ABOVE_DISPENSER_CONFIG)
	var dispenser := _find_dispenser(level)
	var item := _get_dispenser_item(level, dispenser)
	var target_slot := _find_empty_standard_slot(level)
	if item == null or target_slot == null:
		_check(false, "The fixture needs a dispenser item and an empty standard slot.")
		await _teardown(level)
		return

	var body := item.get_node("Sprite2D") as CanvasItem
	var lift := DispenserShelf.ITEM_BODY_Z_LIFT
	var dispenser_slot := (level.call("_get_front_slots", dispenser) as Array)[0] as Node2D
	var marker := level.call("_get_slot_marker", dispenser_slot) as Marker2D
	var target_marker := level.call("_get_slot_marker", target_slot) as Marker2D
	level.set("item_move_duration_seconds", 0.0)
	_check(body.z_index == lift, "An item resting in a dispenser is lifted.")

	level.call("_begin_drag", item, marker.global_position)
	_check(body.z_index == 0, "An item the player is carrying is not lifted.")

	# Released far from every shelf, it goes home and is lifted again.
	level.call("_finish_active_drag", marker.global_position + Vector2(0.0, -4000.0))
	await _wait_seconds(0.4)
	_check(
		level.call("_get_slot_item", dispenser_slot) == item and body.z_index == lift,
		"An item put back in its dispenser is lifted again."
	)

	# Dropped on a standard shelf it is not.
	level.call("_begin_drag", item, marker.global_position)
	level.call("_move_active_drag", target_marker.global_position)
	level.call("_finish_active_drag", target_marker.global_position)
	await _wait_seconds(0.4)
	_check(
		level.call("_get_slot_item", target_slot) == item and body.z_index == 0,
		"An item moved onto a standard shelf is not lifted."
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


## Lowest z-index among the nodes that actually draw something, so a bare grouping node that draws
## nothing cannot stand in for the parts that do.
func _get_lowest_absolute_z_index(node: Node) -> int:
	var lowest := 4096
	if _draws(node):
		lowest = _get_absolute_z_index(node as CanvasItem)

	for child in node.get_children():
		lowest = mini(lowest, _get_lowest_absolute_z_index(child))

	return lowest


func _draws(node: Node) -> bool:
	return node is Polygon2D or node is Sprite2D or node is Label or node is Line2D


func _make_level(config: Dictionary) -> Node:
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level := level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 1)
	root.add_child(level)
	await process_frame

	level.set("_sound_effects_enabled", false)
	level.call("_apply_level_config", config)
	# _ready() collects slots after applying its own config; rebuilding the board here has to refresh
	# the same cache or drop targeting would still be pointing at the freed shelves.
	level.call("_collect_slots")
	await process_frame
	return level


func _find_dispenser(level: Node) -> Node2D:
	for shelf in level.call("_get_all_shelves") as Array:
		if shelf is DispenserShelf:
			return shelf as Node2D

	return null


func _find_locked_shelf(level: Node) -> Node2D:
	for shelf in level.call("_get_all_shelves") as Array:
		if bool(level.call("_is_shelf_locked", shelf)):
			return shelf as Node2D

	return null


func _get_dispenser_item(level: Node, dispenser: Node2D) -> ShelfItem:
	if dispenser == null:
		return null

	var slot := (level.call("_get_front_slots", dispenser) as Array)[0] as Node2D
	return level.call("_get_slot_item", slot) as ShelfItem


func _find_empty_standard_slot(level: Node) -> Node2D:
	for shelf in level.call("_get_all_shelves") as Array:
		if shelf is DispenserShelf or bool(level.call("_is_shelf_locked", shelf)):
			continue

		for slot in level.call("_get_front_slots", shelf) as Array:
			if level.call("_get_slot_item", slot) == null:
				return slot as Node2D

	return null


## Lets in-flight move tweens finish before the board goes away, so teardown does not strand
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
