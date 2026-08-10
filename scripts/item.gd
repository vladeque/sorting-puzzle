@tool
class_name ShelfItem
extends Area2D

const UIMotionScript := preload("res://scripts/ui_motion.gd")

const DEFAULT_VISUAL_SCALE := 0.92

const SHADOW_NODE_NAME := ^"Shadow"

## Distance from the sprite's texture center down to the art's ground line, in source texels. Item
## textures are a 128x128 canvas whose visible artwork ends at y=120 (docs/ITEM_ASSET_REQUIREMENTS),
## so the contact point is 120 - 64 texels below the center for every catalog item.
const SHADOW_GROUND_TEXELS := 56.0

## Resting shadow: a soft, full-size copy of the item silhouette displaced slightly
## up-right, as if the item stands close to the shelf's back wall. It has no crisp silhouette core:
## the broad mask transition and low opacity keep neighboring shelf items from becoming visually
## crowded while the bottle/box/tub form remains legible behind its owner.
const SHADOW_REST_WIDTH := 1.0
const SHADOW_REST_FLATTEN := 1.0
const SHADOW_REST_SKEW := 0.0
const SHADOW_REST_BLUR_PX := 7.5
const SHADOW_REST_MASK_LOW := 0.12
const SHADOW_REST_ALPHA_SCALE := 0.56
const SHADOW_REST_OFFSET := Vector2(16.0, -2.0)

## Carried shadow: the item is held well above the board, so a ground projection is the wrong read.
## The silhouette moves farther down-right of the item -- the same shape, displaced, the way a
## lifted object's shadow separates from it. A source-alpha core keeps
## narrow necks, handles and irregular edges recognizable while a smaller filtered fill softens it.
const SHADOW_CARRY_WIDTH := 1.0
const SHADOW_CARRY_FLATTEN := 1.0
const SHADOW_CARRY_SKEW := 0.0
const SHADOW_CARRY_BLUR_PX := 4.5
const SHADOW_CARRY_MASK_LOW := 0.3
const SHADOW_CARRY_SILHOUETTE_WEIGHT := 0.7
const SHADOW_CARRY_ALPHA_SCALE := 0.78

## How far the carried shadow separates from the item, in source texels (scaled with the sprite).
## Down and to the right, so the item reads as lifted toward the player and off to the light's side.
const SHADOW_CARRY_OFFSET := Vector2(30.0, 12.0)

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

## Shared shadow material, assigned in scenes/item.tscn. Each item renders through its own copy,
## because the resting/carried blend writes per-item shader uniforms.
@export var shadow_material: ShaderMaterial

@export var texture: Texture2D:
	set(value):
		texture = value
		_apply_texture()

@export_range(0.2, 4.0, 0.01) var visual_scale: float = 0.92:
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

## 0 while the item rests on a shelf, 1 while the player holds it above the board; the shadow blends
## between its two shapes across that range. Animated as its own channel (like land_squash) so a lift
## arriving mid-landing does not fight the bounce.
var shadow_lift := 0.0:
	set(value):
		shadow_lift = value
		_apply_shadow()

var _outline_enabled := false
var _outline_material: ShaderMaterial
var _shadow_material: ShaderMaterial
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
## slides further along the light direction and changes opacity so the item reads as held above the
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


## Draws the item's own silhouette as its shadow, in one of two readings blended by `shadow_lift`:
##
##   resting (0) -- the item is touching the shelf, so a soft, low-opacity copy of its silhouette
##                  sits just up-right on the shelf's back wall.
##   carried (1) -- the item is held above the board, so the silhouette separates farther down-right
##                  and gains a recognizable source-alpha core.
##
## Blending rather than switching means grabbing an item slides and sharpens its shadow, while
## dropping it returns to the nearby soft silhouette instead of either shape popping.
func _apply_shadow() -> void:
	var shadow := get_node_or_null(SHADOW_NODE_NAME) as Sprite2D
	if shadow == null:
		return

	shadow.texture = texture
	shadow.visible = _contact_shadow_enabled and texture != null
	# Puts the art's ground line (texture y=240) on the node's origin, so both readings pivot on the
	# item's contact point rather than on the middle of the texture canvas. At full carry height this
	# also makes the shadow line up exactly with the item sprite before it is displaced.
	shadow.offset = Vector2(0.0, -SHADOW_GROUND_TEXELS)

	_prepare_shadow_material(shadow)

	var sprite_scale := _get_effective_scale()
	var lift := clampf(shadow_lift, 0.0, 1.0)
	var flatten := lerpf(SHADOW_REST_FLATTEN, SHADOW_CARRY_FLATTEN, lift)
	var spread := lerpf(SHADOW_REST_WIDTH, SHADOW_CARRY_WIDTH, lift)

	shadow.skew = lerpf(SHADOW_REST_SKEW, SHADOW_CARRY_SKEW, lift)
	# The upright shadow follows both axes of the landing squash so its silhouette continues to match
	# the item during impact instead of briefly retaining the pre-impact height.
	shadow.scale = Vector2(
		sprite_scale * spread * land_squash.x,
		sprite_scale * flatten * land_squash.y
	)
	shadow.position = Vector2(0.0, SHADOW_GROUND_TEXELS * sprite_scale)
	shadow.position += SHADOW_REST_OFFSET.lerp(SHADOW_CARRY_OFFSET, lift) * sprite_scale

	if _shadow_material != null:
		var shadow_color := _shadow_base_color
		shadow_color.a *= lerpf(SHADOW_REST_ALPHA_SCALE, SHADOW_CARRY_ALPHA_SCALE, lift)
		_shadow_material.set_shader_parameter("shadow_color", shadow_color)
		_shadow_material.set_shader_parameter(
			"blur_radius_px",
			lerpf(SHADOW_REST_BLUR_PX, SHADOW_CARRY_BLUR_PX, lift)
		)
		_shadow_material.set_shader_parameter(
			"silhouette_weight",
			SHADOW_CARRY_SILHOUETTE_WEIGHT * lift
		)
		_shadow_material.set_shader_parameter(
			"mask_low",
			lerpf(SHADOW_REST_MASK_LOW, SHADOW_CARRY_MASK_LOW, lift)
		)


## Gives this item its own copy of the shared shadow material. The shader writes a flat color
## generated from the alpha mask and therefore ignores the node's modulate, so the resting/carried
## blend has to travel as uniforms -- which means a per-item copy, the same arrangement the outline
## already uses.
func _prepare_shadow_material(shadow: Sprite2D) -> void:
	if _shadow_material != null:
		shadow.material = _shadow_material
		return

	if shadow_material == null:
		return

	_shadow_material = shadow_material.duplicate() as ShaderMaterial
	var base_color = shadow_material.get_shader_parameter("shadow_color")
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
