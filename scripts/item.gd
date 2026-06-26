@tool
class_name ShelfItem
extends Area2D

@export var item_id: StringName = &""

@export var texture: Texture2D:
	set(value):
		texture = value
		_apply_texture()

@export_range(0.1, 2.0, 0.01) var visual_scale: float = 0.34:
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

func _ready() -> void:
	_prepare_outline_material()
	_apply_texture()
	_apply_visual_scale()
	_apply_outline()


func set_outline(enabled: bool, color: Color, width: float) -> void:
	_outline_enabled = enabled
	outline_color = color
	outline_width = width


func _apply_texture() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = texture

	var outline_sprite := get_node_or_null("OutlineSprite") as Sprite2D
	if outline_sprite != null:
		outline_sprite.texture = texture


func _apply_visual_scale() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.scale = Vector2.ONE * visual_scale

	var outline_sprite := get_node_or_null("OutlineSprite") as Sprite2D
	if outline_sprite != null:
		outline_sprite.scale = _get_outline_scale()


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
	if _outline_material == null:
		var outline_sprite := get_node_or_null("OutlineSprite") as Sprite2D
		if outline_sprite != null:
			_outline_material = outline_sprite.material as ShaderMaterial

	if _outline_material == null:
		return

	var outline_sprite := get_node_or_null("OutlineSprite") as Sprite2D
	if outline_sprite != null:
		outline_sprite.visible = _outline_enabled
		outline_sprite.scale = _get_outline_scale()

	_outline_material.set_shader_parameter("outline_color", outline_color)
	_outline_material.set_shader_parameter("alpha_threshold", outline_alpha_threshold)


func _get_outline_scale() -> Vector2:
	if not _outline_enabled or texture == null:
		return Vector2.ONE * visual_scale

	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ONE * visual_scale

	return Vector2(
		visual_scale + outline_width * 2.0 / texture_size.x,
		visual_scale + outline_width * 2.0 / texture_size.y
	)
