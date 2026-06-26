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

var _outline_material: ShaderMaterial

func _ready() -> void:
	_prepare_outline_material()
	_apply_texture()
	_apply_visual_scale()
	_apply_outline()


func set_outline(enabled: bool, color: Color, width: float) -> void:
	outline_color = color
	outline_width = width if enabled else 0.0


func _apply_texture() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	sprite.texture = texture


func _apply_visual_scale() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	sprite.scale = Vector2.ONE * visual_scale


func _prepare_outline_material() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	var shader_material := sprite.material as ShaderMaterial
	if shader_material == null:
		return

	_outline_material = shader_material.duplicate() as ShaderMaterial
	sprite.material = _outline_material


func _apply_outline() -> void:
	if _outline_material == null:
		var sprite := get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			_outline_material = sprite.material as ShaderMaterial

	if _outline_material == null:
		return

	_outline_material.set_shader_parameter("outline_color", outline_color)
	_outline_material.set_shader_parameter("outline_width", outline_width)
	_outline_material.set_shader_parameter("alpha_threshold", outline_alpha_threshold)
