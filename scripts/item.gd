@tool
class_name ShelfItem
extends Area2D

const DEFAULT_VISUAL_SCALE := 0.46

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
	var effective_scale := _get_effective_scale()

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.scale = Vector2.ONE * effective_scale

	var outline_sprite := get_node_or_null("OutlineSprite") as Sprite2D
	if outline_sprite != null:
		outline_sprite.scale = Vector2.ONE * effective_scale

	var shadow := get_node_or_null("Shadow") as Node2D
	if shadow != null:
		shadow.scale = Vector2.ONE * (visual_scale / DEFAULT_VISUAL_SCALE)

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
		outline_sprite.scale = Vector2.ONE * _get_effective_scale()

	_outline_material.set_shader_parameter("outline_color", outline_color)
	_outline_material.set_shader_parameter("alpha_threshold", outline_alpha_threshold)
	_outline_material.set_shader_parameter("outline_radius_px", _get_outline_radius_texels())


func _get_effective_scale() -> float:
	return visual_scale * _highlight_scale_multiplier


func _get_outline_radius_texels() -> float:
	var effective_scale := _get_effective_scale()
	if effective_scale <= 0.0:
		return 0.0

	# outline_width is expressed in screen pixels; convert it into source-texture
	# texels so the on-screen border thickness stays constant regardless of the
	# sprite's current scale.
	return outline_width / effective_scale
