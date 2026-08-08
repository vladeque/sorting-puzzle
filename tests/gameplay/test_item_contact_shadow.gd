extends SceneTree

## Focused verification for the ShelfItem ground shadow (scripts/item.gd's _apply_shadow). Covers the
## three properties the shadow rework had to deliver: the shadow is derived from the item's own
## texture instead of one shared authored blob, both prototype styles anchor on the art's ground
## line, and a dragged item keeps a lifted shadow that travels with it rather than losing it.

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
	_verify_cast_projection(item, shadow)
	_verify_contact_pool(item, shadow)
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
		"The shadow is anchored on the item's contact point rather than the texture centre."
	)


func _verify_cast_projection(item: ShelfItem, shadow: Sprite2D) -> void:
	ShelfItem.shadow_style = ShelfItem.ShadowStyle.CAST_PROJECTION
	item.refresh_shadow_style()

	_check(
		_get_ground_fade(shadow) == 0.0,
		"Cast projection keeps the whole silhouette instead of fading it above the contact line."
	)
	_check(
		shadow.skew > 0.0,
		"Cast projection shears the silhouette along the light direction."
	)
	_check(
		shadow.scale.y > 0.0 and shadow.scale.y < shadow.scale.x,
		"Cast projection flattens the silhouette onto the floor without mirroring it."
	)


func _verify_contact_pool(item: ShelfItem, shadow: Sprite2D) -> void:
	var cast_height := shadow.scale.y
	var ground_y := ShelfItem.SHADOW_GROUND_TEXELS * item.visual_scale

	ShelfItem.shadow_style = ShelfItem.ShadowStyle.CONTACT_POOL
	item.refresh_shadow_style()

	_check(
		is_equal_approx(_get_ground_fade(shadow), ShelfItem.SHADOW_POOL_FADE_TEXELS),
		"Contact pool keeps only the contact region, matching the pool geometry in item.gd."
	)
	_check(
		is_zero_approx(shadow.skew),
		"Contact pool spreads straight under the item instead of shearing."
	)
	_check(
		shadow.scale.y < cast_height,
		"Contact pool flattens harder than the cast projection."
	)
	_check(
		shadow.position.y > ground_y,
		"Contact pool straddles the contact line instead of sitting entirely above it."
	)

	ShelfItem.shadow_style = ShelfItem.ShadowStyle.CAST_PROJECTION
	item.refresh_shadow_style()


func _verify_drag_lift(level: Node, item: ShelfItem, shadow: Sprite2D) -> void:
	var resting_offset := shadow.position
	var resting_scale := shadow.scale
	var resting_alpha := _get_shadow_alpha(shadow)
	var grab_position := item.global_position

	level.call("_begin_drag", item, grab_position)
	await create_timer(LIFT_SETTLE_SECONDS).timeout

	_check(shadow.visible, "A dragged item keeps its shadow instead of dropping it.")
	_check(
		shadow.position.x > resting_offset.x and shadow.position.y < resting_offset.y,
		"Lifting pushes the shadow further along the light direction."
	)
	_check(
		shadow.scale.x > resting_scale.x and _get_shadow_alpha(shadow) < resting_alpha,
		"A lifted shadow spreads and washes out."
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
		is_zero_approx(item.shadow_lift)
		and is_equal_approx(_get_shadow_alpha(shadow), resting_alpha),
		"Dropping the item settles its shadow back onto the shelf."
	)


func _get_ground_fade(shadow: Sprite2D) -> float:
	var material := shadow.material as ShaderMaterial
	if material == null:
		return -1.0
	return float(material.get_shader_parameter("ground_fade_texels"))


func _get_shadow_alpha(shadow: Sprite2D) -> float:
	var material := shadow.material as ShaderMaterial
	if material == null:
		return -1.0
	var color = material.get_shader_parameter("shadow_color")
	return color.a if color is Color else -1.0


func _finish(level: Node) -> void:
	ShelfItem.shadow_style = ShelfItem.ShadowStyle.CAST_PROJECTION
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
