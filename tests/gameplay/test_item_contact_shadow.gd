extends SceneTree

## Focused verification for the ShelfItem ground shadow (scripts/item.gd's _apply_shadow). Covers the
## properties the shadow rework had to deliver: the shadow is derived from the item's own texture
## instead of one shared authored blob, it anchors on the art's ground line, and it has two distinct
## readings -- a nearby soft silhouette at rest and a more separated, shape-preserving silhouette
## while carried -- with the carried one travelling with the dragged item instead of being dropped.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"
const SHELF_SCENE_PATH := "res://scenes/shelf.tscn"

const SHELF_SHADOW_PATHS := [
	"Shadow",
	"RightColumnShadow",
	"BackWallTopShade",
	"PlacementVisuals/Left/BackWallLeftShade",
	"PlacementVisuals/Left/LeftShadowEdge",
	"PlacementVisuals/Middle/BackWallLeftShade",
	"PlacementVisuals/Middle/LeftShadowEdge",
	"PlacementVisuals/Middle/RightShadowEdge",
	"PlacementVisuals/Right/BackWallLeftShade",
	"PlacementVisuals/Right/RightShadowEdge",
]

const ORIGINAL_REST_SHADOW_SOURCE := Color(0.1, 0.05, 0.02, 0.4 * 0.56)
const SHELF_BACK_WALL_COLOR := Color(0.85882354, 0.76862746, 0.6509804, 1.0)

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
	_verify_shared_shelf_shadow_color(item, shadow)
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
		shadow.position.is_equal_approx(
			Vector2(0.0, ShelfItem.SHADOW_GROUND_TEXELS * item.visual_scale)
				+ ShelfItem.SHADOW_REST_OFFSET * item.visual_scale
		),
		"A resting shadow is anchored on the ground line and uses its configured offset."
	)
	_check(
		ShelfItem.SHADOW_REST_OFFSET.x > 0.0 and ShelfItem.SHADOW_REST_OFFSET.y < 0.0,
		"A resting shadow falls slightly up-right of the item."
	)


func _verify_shared_shelf_shadow_color(item: ShelfItem, shadow: Sprite2D) -> void:
	var expected_original_rest := _source_over(
		ORIGINAL_REST_SHADOW_SOURCE,
		SHELF_BACK_WALL_COLOR
	)
	_check(
		ShelfItem.SHELF_SHADOW_COLOR.is_equal_approx(expected_original_rest),
		"The canonical shelf color preserves the original resting item-shadow appearance."
	)

	item.shadow_lift = 0.0
	var resting_color := _get_shadow_color(shadow)
	_check(
		resting_color.is_equal_approx(ShelfItem.SHELF_SHADOW_COLOR),
		"The resting item shadow uses the canonical shelf-shadow color."
	)

	item.shadow_lift = 1.0
	var carried_color := _get_shadow_color(shadow)
	_check(
		carried_color.is_equal_approx(ShelfItem.SHELF_SHADOW_COLOR),
		"The carried item shadow uses the canonical shelf-shadow color."
	)

	var shelf_scene := load(SHELF_SCENE_PATH) as PackedScene
	var shelf: Node = shelf_scene.instantiate() if shelf_scene != null else null
	_check(shelf != null, "The shelf scene is available for shadow color verification.")
	if shelf == null:
		item.shadow_lift = 0.0
		return

	for shadow_path in SHELF_SHADOW_PATHS:
		var shelf_shadow := shelf.get_node_or_null(shadow_path) as Polygon2D
		_check(shelf_shadow != null, "Shelf shadow '%s' exists." % shadow_path)
		if shelf_shadow == null:
			continue

		_check(
			shelf_shadow.color.is_equal_approx(ShelfItem.SHELF_SHADOW_COLOR),
			"Shelf shadow '%s' uses the item-shadow color." % shadow_path
		)

		var soft_item_color := ShelfItem.SHELF_SHADOW_COLOR
		soft_item_color.a = 0.5
		_check(
			_source_over(soft_item_color, shelf_shadow.color).is_equal_approx(
				shelf_shadow.color
			),
			"A soft item-shadow edge does not darken shelf shadow '%s'." % shadow_path
		)

	shelf.free()
	item.shadow_lift = 0.0


func _verify_resting_shape(item: ShelfItem, shadow: Sprite2D) -> void:
	item.shadow_lift = 0.0
	var item_sprite := item.get_node_or_null("Sprite2D") as Sprite2D

	_check(
		item_sprite != null and shadow.scale.is_equal_approx(item_sprite.scale),
		"A resting shadow has the same size as the item sprite."
	)
	_check(
		is_zero_approx(shadow.skew),
		"A resting shadow stays upright without shearing the recognizable silhouette."
	)
	_check(
		is_zero_approx(_get_silhouette_weight(shadow)),
		"A resting shadow uses only the filtered projection, without the carried silhouette core."
	)
	_check(
		is_equal_approx(_get_blur(shadow), ShelfItem.SHADOW_REST_BLUR_PX),
		"A resting shadow uses the broad blur radius of the soft wall silhouette."
	)
	_check(
		is_equal_approx(_get_mask_low(shadow), ShelfItem.SHADOW_REST_MASK_LOW),
		"A resting shadow uses the broad mask transition that softens its penumbra."
	)
	_check(
		is_equal_approx(
			_get_shadow_alpha(shadow),
			_get_base_shadow_alpha(item) * ShelfItem.SHADOW_REST_ALPHA_SCALE
		),
		"A resting shadow keeps the canonical shelf-shadow opacity."
	)


func _verify_carried_shape(item: ShelfItem, shadow: Sprite2D) -> void:
	var ground_y := ShelfItem.SHADOW_GROUND_TEXELS * item.visual_scale

	item.shadow_lift = 1.0
	var item_sprite := item.get_node_or_null("Sprite2D") as Sprite2D

	_check(
		item_sprite != null and shadow.scale.is_equal_approx(item_sprite.scale),
		"A carried shadow has the same size as the item sprite."
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
		is_equal_approx(_get_blur(shadow), ShelfItem.SHADOW_CARRY_BLUR_PX),
		"A carried shadow uses the compact blur radius that preserves recognizable edges."
	)
	_check(
		is_equal_approx(_get_mask_low(shadow), ShelfItem.SHADOW_CARRY_MASK_LOW),
		"A carried shadow restores the tighter soft-edge threshold."
	)
	_check(
		is_equal_approx(
			_get_silhouette_weight(shadow),
			ShelfItem.SHADOW_CARRY_SILHOUETTE_WEIGHT
		),
		"A carried shadow retains a source-alpha core for narrow and irregular silhouette details."
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
		is_zero_approx(item.shadow_lift)
			and shadow.scale.is_equal_approx((item.get_node("Sprite2D") as Sprite2D).scale),
		"Dropping the item returns its shadow to the item-sized resting silhouette."
	)


func _get_blur(shadow: Sprite2D) -> float:
	var material := shadow.material as ShaderMaterial
	if material == null:
		return -1.0
	return float(material.get_shader_parameter("blur_radius_px"))


func _get_silhouette_weight(shadow: Sprite2D) -> float:
	var material := shadow.material as ShaderMaterial
	if material == null:
		return -1.0
	return float(material.get_shader_parameter("silhouette_weight"))


func _get_mask_low(shadow: Sprite2D) -> float:
	var material := shadow.material as ShaderMaterial
	if material == null:
		return -1.0
	return float(material.get_shader_parameter("mask_low"))


func _get_shadow_alpha(shadow: Sprite2D) -> float:
	return _get_shadow_color(shadow).a


func _get_shadow_color(shadow: Sprite2D) -> Color:
	var material := shadow.material as ShaderMaterial
	if material == null:
		return Color.TRANSPARENT
	var color = material.get_shader_parameter("shadow_color")
	return color if color is Color else Color.TRANSPARENT


func _source_over(source: Color, destination: Color) -> Color:
	var source_alpha := clampf(source.a, 0.0, 1.0)
	return Color(
		lerpf(destination.r, source.r, source_alpha),
		lerpf(destination.g, source.g, source_alpha),
		lerpf(destination.b, source.b, source_alpha),
		1.0
	)


func _get_base_shadow_alpha(item: ShelfItem) -> float:
	if item.shadow_material == null:
		return -1.0
	var color = item.shadow_material.get_shader_parameter("shadow_color")
	return color.a if color is Color else -1.0


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
