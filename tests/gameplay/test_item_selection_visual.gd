extends SceneTree

## Verifies the tap-selection presentation shared by ordinary items and Lantern-highlighted items.
## Run through scripts/tools/run_isolated_godot_test.ps1.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"
const TEST_LEVEL := 2

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Item selection visual verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level = level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", TEST_LEVEL)
	root.add_child(level)
	await process_frame
	await process_frame

	var visible_items := level.call("_get_visible_items") as Array
	_check(not visible_items.is_empty(), "Level %d exposes a visible item to select." % TEST_LEVEL)
	if visible_items.is_empty():
		_finish(level)
		return

	var item := visible_items[0] as ShelfItem
	var slot := item.get_parent() as Node2D
	var sprite := item.get_node("Sprite2D") as Sprite2D
	var outline := item.get_node("OutlineSprite") as Sprite2D
	var shadow := item.get_node("Shadow") as Sprite2D
	var collision := item.get_node("CollisionShape2D") as CollisionShape2D
	var resting_sprite_scale := sprite.scale
	var resting_outline_scale := outline.scale
	var resting_shadow_y := shadow.position.y
	var selected_offset := float(level.get("selected_item_forward_offset"))

	level.call("_set_selected_item", item, slot)
	_check(outline.visible, "A selected item enables the silhouette outline.")
	_check(
		_is_color_approx(
			outline.material.get_shader_parameter("outline_color"),
			Color.WHITE
		),
		"A selected item's silhouette outline is white."
	)
	_check(
		is_equal_approx(sprite.position.y, selected_offset)
		and is_equal_approx(outline.position.y, selected_offset),
		"Selection moves the item and its outline toward the shelf edge."
	)
	_check(
		is_equal_approx(shadow.position.y, resting_shadow_y + selected_offset),
		"The selected item's ground shadow moves forward with its artwork."
	)
	_check(
		is_equal_approx(collision.position.y, selected_offset),
		"The selected item's hit area stays aligned with the shifted artwork."
	)

	var highlighted_items := level.get("_highlighted_items") as Array
	highlighted_items.append(item)
	level.call("_apply_item_visual_state", item)
	_check(
		sprite.scale.is_equal_approx(resting_sprite_scale)
		and outline.scale.is_equal_approx(resting_outline_scale),
		"Lantern does not enlarge a highlighted item or its outline."
	)
	_check(
		outline.visible
		and _is_color_approx(
			outline.material.get_shader_parameter("outline_color"),
			Color.WHITE
		),
		"Selection keeps the white outline when Lantern also highlights the item."
	)
	var selected_highlighted_shadow_y := shadow.position.y

	level.call("_clear_selected_item")
	_check(
		outline.visible
		and _is_color_approx(
			outline.material.get_shader_parameter("outline_color"),
			level.get("highlight_outline_color")
		),
		"Clearing selection restores Lantern's gold outline when its highlight remains active."
	)
	_check(
		is_equal_approx(sprite.position.y, selected_offset)
		and is_equal_approx(outline.position.y, selected_offset)
		and is_equal_approx(collision.position.y, selected_offset),
		"A Lantern-highlighted item stays shifted toward the shelf edge after selection clears."
	)
	_check(
		is_equal_approx(shadow.position.y, selected_highlighted_shadow_y),
		"A Lantern-highlighted item's shadow stays aligned with its shelf-edge offset."
	)

	highlighted_items.clear()
	level.call("_apply_item_visual_state", item)
	_check(not outline.visible, "An ordinary deselected item has no outline.")
	_check(
		is_zero_approx(sprite.position.y)
		and is_zero_approx(outline.position.y)
		and is_zero_approx(collision.position.y),
		"Removing Lantern returns the deselected item and hit area to the slot."
	)
	_check(
		is_equal_approx(shadow.position.y, resting_shadow_y),
		"Removing Lantern returns the deselected ground shadow to its original resting position."
	)
	_finish(level)


func _is_color_approx(actual: Variant, expected: Color) -> bool:
	return actual is Color and (actual as Color).is_equal_approx(expected)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(level: Node) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	await process_frame

	if _failures.is_empty():
		print("Item selection visual verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
