extends SceneTree

## Focused verification for the ShelfItem ground shadow (scripts/item.gd's _apply_shadow). Covers the
## properties the shadow rework had to deliver: the shadow is derived from the item's own texture
## instead of one shared authored blob, it anchors on the art's ground line, and it has two distinct
## readings -- flattened onto the shelf at rest, standing upright and displaced while carried -- with
## the carried one travelling with the dragged item instead of being dropped.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"

## The lift tween runs for SHADOW_LIFT_SECONDS (0.12); sample well clear of both ends.
const LIFT_SETTLE_SECONDS := 0.2

const DRAG_STEP := Vector2(90.0, -60.0)

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Item contact shadow verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level = level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 2)
	root.add_child(level)
	await process_frame
	await process_frame

	var visible_items := level.call("_get_visible_items") as Array
	_check(not visible_items.is_empty(), "Level 2 exposes at least one visible item to shadow.")
	if visible_items.is_empty():
		_finish(level)
		return

	var item := visible_items[0] as ShelfItem
	var shadow := item.get_node_or_null("Shadow") as Sprite2D

	_check(shadow != null, "The item shadow is a Sprite2D that can carry the item's silhouette.")
	if shadow == null:
		_finish(level)
		return

	_verify_shadow_follows_item_form(item, shadow)
	_verify_resting_shape(item, shadow)
	_verify_carried_shape(item, shadow)
	await _verify_drag_lift(level, item, shadow)

	_finish(level)


func _verify_shadow_follows_item_form(item: ShelfItem, shadow: Sprite2D) -> void:
	_check(
		item.texture != null and shadow.texture == item.texture,
		"The shadow is derived from the item's own texture, not a shared authored shape."
	)
	_check(
		shadow.material is ShaderMaterial,
		"The shadow renders through the silhouette shader."
	)
	_check(
		is_equal_approx(shadow.offset.y, -ShelfItem.SHADOW_GROUND_TEXELS),
		"The shadow sprite is offset so the art's ground line sits on its own origin."
	)
	_check(
		is_equal_approx(shadow.position.y, ShelfItem.SHADOW_GROUND_TEXELS * item.visual_scale),
		"A resting shadow is anchored on the item's contact point, undisplaced."
	)


func _verify_resting_shape(item: ShelfItem, shadow: Sprite2D) -> void:
	item.shadow_lift = 0.0

	_check(
		shadow.scale.y < 0.0,
		"A resting shadow folds toward the viewer, so it is not hidden behind the item's own body."
	)
	_check(
		absf(shadow.scale.y) < absf(shadow.scale.x) * 0.5,
		"A resting shadow is flattened onto the shelf rather than standing up."
	)
	_check(
		not is_zero_approx(shadow.skew),
		"A resting shadow is sheared along the light direction."
	)


func _verify_carried_shape(item: ShelfItem, shadow: Sprite2D) -> void:
	var resting_blur := _get_blur(shadow)
	var ground_y := ShelfItem.SHADOW_GROUND_TEXELS * item.visual_scale

	item.shadow_lift = 1.0

	_check(
		shadow.scale.y > 0.0 and shadow.scale.y > shadow.scale.x * 0.8,
		"A carried shadow stands back up to the item's own height instead of lying on the floor."
	)
	_check(
		is_zero_approx(shadow.skew),
		"A carried shadow drops straight, without the resting shear."
	)
	_check(
		shadow.position.x > 0.0 and shadow.position.y > ground_y,
		"A carried shadow separates down-right of the item it belongs to."
	)
	_check(
		_get_blur(shadow) > resting_blur,
		"A carried shadow is softer than a resting one, its casting surface being further away."
	)

	item.shadow_lift = 0.0


func _verify_drag_lift(level: Node, item: ShelfItem, shadow: Sprite2D) -> void:
	var resting_position := shadow.position
	var grab_position := item.global_position

	level.call("_begin_drag", item, grab_position)
	await create_timer(LIFT_SETTLE_SECONDS).timeout

	_check(shadow.visible, "A dragged item keeps its shadow instead of dropping it.")
	_check(
		is_equal_approx(item.shadow_lift, 1.0),
		"Grabbing an item drives its shadow all the way to the carried shape."
	)
	_check(
		shadow.position.x > resting_position.x and shadow.position.y > resting_position.y,
		"Carrying displaces the shadow down-right of where it rested."
	)

	var shadow_before_move := shadow.global_position
	level.call("_move_active_drag", grab_position + DRAG_STEP)

	_check(
		shadow.global_position.is_equal_approx(shadow_before_move + DRAG_STEP),
		"The shadow travels with the item for the whole drag."
	)

	level.call("_finish_active_drag", item.global_position)
	await create_timer(LIFT_SETTLE_SECONDS).timeout

	_check(
		is_zero_approx(item.shadow_lift) and shadow.scale.y < 0.0,
		"Dropping the item lays its shadow back down onto the shelf."
	)


func _get_blur(shadow: Sprite2D) -> float:
	var material := shadow.material as ShaderMaterial
	if material == null:
		return -1.0
	return float(material.get_shader_parameter("blur_radius_px"))


func _finish(level: Node) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Item contact shadow verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
