@tool
class_name ShelfItem
extends Area2D

const UIMotionScript := preload("res://scripts/ui_motion.gd")

const DEFAULT_VISUAL_SCALE := 0.46

const SHADOW_NODE_NAME := ^"Shadow"

## Two competing ground-shadow prototypes, both derived from the item's own alpha silhouette:
## CAST_PROJECTION flattens and skews the whole silhouette onto the floor, CONTACT_POOL keeps only
## the contact region and lets it spread into a soft pool. See docs/SCENES.md.
enum ShadowStyle {
	CAST_PROJECTION,
	CONTACT_POOL,
}

## Prototype selector every new item is created with; holds a ShadowStyle value. Change this one
## line to try the other style everywhere, including on device. Typed as int rather than ShadowStyle
## because cross-script assignment to an enum-typed static is rejected at runtime.
static var default_shadow_style: int = ShadowStyle.CAST_PROJECTION

## Distance from the sprite's texture center down to the art's ground line, in source texels. Item
## textures are a 256x256 canvas whose visible artwork ends at y=240 (docs/ITEM_ASSET_REQUIREMENTS),
## so the contact point is 240 - 128 texels below the center for every catalog item.
const SHADOW_GROUND_TEXELS := 112.0

## Cast projection: the silhouette squashed onto the floor and sheared up-right, matching the light
## direction the shelf's own cast shadows already imply.
const SHADOW_CAST_WIDTH := 1.02
const SHADOW_CAST_FLATTEN := 0.3
const SHADOW_CAST_SKEW := 0.45
const SHADOW_CAST_LIFT_OFFSET := Vector2(18.0, -12.0)

## Contact pool: no shear, flattened much harder, and slightly wider than the item so the blurred
## contact region spreads out from under it.
const SHADOW_POOL_WIDTH := 1.14
const SHADOW_POOL_FLATTEN := 0.18
const SHADOW_POOL_OFFSET_X := 3.0
const SHADOW_POOL_LIFT_OFFSET := Vector2(12.0, -4.0)

## Must match the pool material's `ground_fade_texels`: the pool is only as tall as the part of the
## silhouette the shader keeps, and that height decides how far to drop it so it straddles the
## contact line instead of sitting entirely above it.
const SHADOW_POOL_FADE_TEXELS := 90.0

## Lifting an item off the board pushes its shadow further along the light direction, spreads it,
## and washes it out -- the readable cue that the item is now held above the shelf rather than on it.
const SHADOW_LIFT_SCALE := 1.22
const SHADOW_LIFT_ALPHA := 0.55
const SHADOW_LIFT_SECONDS := 0.12
const SHADOW_LIFT_TWEEN_META := &"_shelf_item_shadow_lift_tween"

## Local-space y the landing bounce pivots on, so the item's feet stay planted on the shelf; scaling
## a centered sprite about its own middle would visibly lift it off the board instead. Tuned by eye
## against the art, and deliberately left alone by the shadow rework -- the shadow anchors on
## SHADOW_GROUND_TEXELS, which is measured from the item texture contract instead.
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

## Shared shadow materials, one per prototype style. Assigned in scenes/item.tscn and never
## duplicated per item: the styles differ only in uniforms that are identical across every item,
## and the one per-item value (the drag lift's opacity) rides on self_modulate instead.
@export var shadow_cast_material: ShaderMaterial
@export var shadow_pool_material: ShaderMaterial

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

## This item's ground-shadow style, seeded at construction from default_shadow_style. Per item
## rather than global so scenes/shadow_style_preview.tscn can show both prototypes at once; in the
## level every item simply takes the default.
var shadow_style: int = default_shadow_style:
	set(value):
		shadow_style = value
		_apply_shadow()

## 0 while the item rests on a shelf, 1 while the player holds it above the board. Animated as its
## own channel (like land_squash) so a lift arriving mid-landing does not fight the bounce.
var shadow_lift := 0.0:
	set(value):
		shadow_lift = value
		_apply_shadow()

var _outline_enabled := false
var _outline_material: ShaderMaterial
var _shadow_material: ShaderMaterial
var _shadow_material_style := -1
var _shadow_base_color := Color(0.1, 0.05, 0.02, 0.34)
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


## Lifts the shadow off the item while the player carries it, instead of hiding the shadow the way
## earlier drags did: the shadow stays a child of the item, so it follows the finger for free, but it
## slides further along the light direction, spreads and fades so the item reads as held above the
## board. Fire and forget -- the tween is bound to this node, so it dies with the item.
func set_drag_lifted(lifted: bool) -> void:
	var target := 1.0 if lifted else 0.0
	if not is_inside_tree():
		UIMotionScript.stop_tween(self, SHADOW_LIFT_TWEEN_META)
		shadow_lift = target
		return

	if is_equal_approx(shadow_lift, target):
		return

	var tween := UIMotionScript.retween(self, SHADOW_LIFT_TWEEN_META)
	tween.tween_property(self, "shadow_lift", target, SHADOW_LIFT_SECONDS).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)


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

	_apply_shadow()


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

	_apply_shadow()
	_apply_outline()


## Projects the item's own silhouette onto the floor. Both prototype styles share one sprite fed by
## the item texture; they differ in how hard the silhouette is flattened, whether it is sheared, and
## (through the material) how much of it survives the shader's blur and ground fade.
func _apply_shadow() -> void:
	var shadow := get_node_or_null(SHADOW_NODE_NAME) as Sprite2D
	if shadow == null:
		return

	shadow.texture = texture
	shadow.visible = _contact_shadow_enabled and texture != null
	# Puts the art's ground line (texture y=240) on the node's origin, so every projection below
	# pivots on the item's contact point rather than on the middle of the texture canvas.
	shadow.offset = Vector2(0.0, -SHADOW_GROUND_TEXELS)

	var sprite_scale := _get_effective_scale()
	var ground_y := SHADOW_GROUND_TEXELS * sprite_scale
	var spread := lerpf(1.0, SHADOW_LIFT_SCALE, shadow_lift)
	# Only the shadow's width follows the landing squash: an impact spreads the contact patch
	# sideways, it does not push the shadow further from the item along the shelf.
	var width := sprite_scale * spread * land_squash.x
	var height := sprite_scale * spread

	_prepare_shadow_material(shadow)

	if shadow_style == ShadowStyle.CONTACT_POOL:
		shadow.skew = 0.0
		shadow.scale = Vector2(width * SHADOW_POOL_WIDTH, height * SHADOW_POOL_FLATTEN)
		# The shader keeps only SHADOW_POOL_FADE_TEXELS of silhouette above the contact line, so
		# dropping the sprite by half that projected height centers the pool under the item.
		var pool_center := 0.5 * SHADOW_POOL_FADE_TEXELS * SHADOW_POOL_FLATTEN * height
		shadow.position = Vector2(SHADOW_POOL_OFFSET_X * sprite_scale, ground_y + pool_center)
		shadow.position += SHADOW_POOL_LIFT_OFFSET * sprite_scale * shadow_lift
	else:
		shadow.skew = SHADOW_CAST_SKEW
		shadow.scale = Vector2(width * SHADOW_CAST_WIDTH, height * SHADOW_CAST_FLATTEN)
		shadow.position = Vector2(0.0, ground_y)
		shadow.position += SHADOW_CAST_LIFT_OFFSET * sprite_scale * shadow_lift

	if _shadow_material != null:
		var lift_color := _shadow_base_color
		lift_color.a *= lerpf(1.0, SHADOW_LIFT_ALPHA, shadow_lift)
		_shadow_material.set_shader_parameter("shadow_color", lift_color)


## Gives this item its own copy of the current style's material. The shader writes a flat color
## generated from the alpha mask and therefore ignores the node's modulate, so the drag lift's
## opacity has to travel as a uniform -- which means a per-item copy, the same arrangement the
## outline already uses. The copy is remade only when the prototype style actually changes.
func _prepare_shadow_material(shadow: Sprite2D) -> void:
	if _shadow_material != null and _shadow_material_style == shadow_style:
		shadow.material = _shadow_material
		return

	var source := shadow_cast_material
	if shadow_style == ShadowStyle.CONTACT_POOL:
		source = shadow_pool_material

	if source == null:
		return

	_shadow_material = source.duplicate() as ShaderMaterial
	_shadow_material_style = shadow_style
	var base_color = source.get_shader_parameter("shadow_color")
	if base_color is Color:
		_shadow_base_color = base_color
	shadow.material = _shadow_material


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
