@tool
class_name ShelfItem
extends Area2D

const UIMotionScript := preload("res://scripts/ui_motion.gd")

const DEFAULT_VISUAL_SCALE := 0.46

## Local-space y of the art's ground contact, matching the Shadow node's authored position in
## item.tscn. The landing bounce pivots here so the item's feet stay planted on the shelf; scaling a
## centered sprite about its own middle would visibly lift it off the board instead.
const CONTACT_ANCHOR_Y := 42.0

## Landing impact shape. Measured frame-by-frame off a reference title: compress for ~70ms, rebound
## past rest for ~70ms, settle over ~90ms, staying roughly volume-conserving (x +9% while y -8%).
const LAND_SQUASH_SCALE := Vector2(1.09, 0.92)
const LAND_STRETCH_SCALE := Vector2(0.98, 1.05)
const LAND_SQUASH_SECONDS := 0.07
const LAND_STRETCH_SECONDS := 0.07
const LAND_SETTLE_SECONDS := 0.09

const LAND_IMPACT_TWEEN_META := &"_shelf_item_land_impact_tween"

@export var item_id: StringName = &""

@export var texture: Texture2D:
	set(value):
		texture = value
		_apply_texture()

@export_range(0.1, 2.0, 0.01) var visual_scale: float = 0.46:
	set(value):
		visual_scale = value
		_apply_visual_scale()

@export var outline_color := Color(1.0, 0.86, 0.18, 1.0):
	set(value):
		outline_color = value
		_apply_outline()

@export_range(0.0, 8.0, 0.25) var outline_width := 0.0:
	set(value):
		outline_width = value
		_apply_outline()

@export_range(0.0, 1.0, 0.01) var outline_alpha_threshold := 0.1:
	set(value):
		outline_alpha_threshold = value
		_apply_outline()

## Non-uniform multiplier layered on top of visual_scale and the highlight scale, driving the
## landing bounce. Kept as its own channel so set_highlight_scale() and set_outline() can keep
## writing their uniform scale without clobbering an in-flight impact, and vice versa.
var land_squash := Vector2.ONE:
	set(value):
		land_squash = value
		_apply_visual_scale()

var _outline_enabled := false
var _outline_material: ShaderMaterial
var _contact_shadow_enabled := true
var _highlight_scale_multiplier := 1.0

func _ready() -> void:
	_prepare_outline_material()
	_apply_texture()
	_apply_visual_scale()


func set_outline(enabled: bool, color: Color, width: float) -> void:
	_outline_enabled = enabled
	outline_color = color
	outline_width = width


func set_highlight_scale(multiplier: float) -> void:
	if is_equal_approx(_highlight_scale_multiplier, multiplier):
		return

	_highlight_scale_multiplier = multiplier
	_apply_visual_scale()


func set_contact_shadow_enabled(enabled: bool) -> void:
	_contact_shadow_enabled = enabled
	_apply_texture()


## Plays the landing squash-and-stretch, restarting cleanly if one is already running. Fire and
## forget: the tween is bound to this node (UIMotion.retween uses node.create_tween()) so it dies
## with the item if the landing immediately completes a triple and the match-clear frees it.
## `strength` scales the whole effect toward the resting shape for softer landings.
func play_land_impact(strength: float = 1.0) -> void:
	var clamped_strength := clampf(strength, 0.0, 1.0)
	reset_land_impact()
	if clamped_strength <= 0.0 or not is_inside_tree():
		return

	var tween := UIMotionScript.retween(self, LAND_IMPACT_TWEEN_META)
	tween.tween_property(
		self,
		"land_squash",
		Vector2.ONE.lerp(LAND_SQUASH_SCALE, clamped_strength),
		LAND_SQUASH_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self,
		"land_squash",
		Vector2.ONE.lerp(LAND_STRETCH_SCALE, clamped_strength),
		LAND_STRETCH_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		self,
		"land_squash",
		Vector2.ONE,
		LAND_SETTLE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Cancels an in-flight landing bounce and restores the resting shape, so an item that is grabbed or
## consumed mid-squash never starts its next animation from a deformed pose.
func reset_land_impact() -> void:
	UIMotionScript.stop_tween(self, LAND_IMPACT_TWEEN_META)
	land_squash = Vector2.ONE


func _apply_texture() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = texture

	var outline_sprite := get_node_or_null("OutlineSprite") as Sprite2D
	if outline_sprite != null:
		outline_sprite.texture = texture

	var shadow := get_node_or_null("Shadow") as CanvasItem
	if shadow != null:
		shadow.visible = _contact_shadow_enabled and texture != null


func _apply_visual_scale() -> void:
	var sprite_scale := _get_sprite_scale()
	var contact_pivot_offset_y := _get_contact_pivot_offset_y()

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.scale = sprite_scale
		sprite.position.y = contact_pivot_offset_y

	var outline_sprite := get_node_or_null("OutlineSprite") as Sprite2D
	if outline_sprite != null:
		outline_sprite.scale = sprite_scale
		outline_sprite.position.y = contact_pivot_offset_y

	var shadow := get_node_or_null("Shadow") as Node2D
	if shadow != null:
		# Only the shadow's width follows the squash: a landing spreads the contact patch sideways,
		# it does not push the shadow further from the item along the shelf.
		var shadow_scale := visual_scale / DEFAULT_VISUAL_SCALE
		shadow.scale = Vector2(shadow_scale * land_squash.x, shadow_scale)

	_apply_outline()


func _prepare_outline_material() -> void:
	var outline_sprite := get_node_or_null("OutlineSprite") as Sprite2D
	if outline_sprite == null:
		return

	var shader_material := outline_sprite.material as ShaderMaterial
	if shader_material == null:
		return

	_outline_material = shader_material.duplicate() as ShaderMaterial
	outline_sprite.material = _outline_material


func _apply_outline() -> void:
	var outline_sprite := get_node_or_null("OutlineSprite") as Sprite2D
	if _outline_material == null:
		if outline_sprite != null:
			_outline_material = outline_sprite.material as ShaderMaterial

	if _outline_material == null:
		return

	if outline_sprite != null:
		outline_sprite.visible = _outline_enabled
		# Must mirror _apply_visual_scale() exactly: this runs on its own whenever an outline
		# property changes, and writing a plain uniform scale here would flatten an in-flight
		# landing bounce on any highlighted item.
		outline_sprite.scale = _get_sprite_scale()
		outline_sprite.position.y = _get_contact_pivot_offset_y()

	_outline_material.set_shader_parameter("outline_color", outline_color)
	_outline_material.set_shader_parameter("alpha_threshold", outline_alpha_threshold)
	_outline_material.set_shader_parameter("outline_radius_px", _get_outline_radius_texels())


func _get_effective_scale() -> float:
	return visual_scale * _highlight_scale_multiplier


func _get_sprite_scale() -> Vector2:
	var effective_scale := _get_effective_scale()
	return Vector2(effective_scale * land_squash.x, effective_scale * land_squash.y)


# Vertical shift that keeps the art's ground contact planted while land_squash deforms it: a
# centered sprite scaled by s lifts its base by contact_offset * (1 - s), so shift back by that
# much. The contact offset tracks the sprite's own scale, the same relationship the Shadow uses.
func _get_contact_pivot_offset_y() -> float:
	var contact_offset := CONTACT_ANCHOR_Y * (_get_effective_scale() / DEFAULT_VISUAL_SCALE)
	return contact_offset * (1.0 - land_squash.y)


func _get_outline_radius_texels() -> float:
	var effective_scale := _get_effective_scale()
	if effective_scale <= 0.0:
		return 0.0

	# outline_width is expressed in screen pixels; convert it into source-texture
	# texels so the on-screen border thickness stays constant regardless of the
	# sprite's current scale.
	return outline_width / effective_scale
