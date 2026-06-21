@tool
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


func _ready() -> void:
	_apply_texture()
	_apply_visual_scale()


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
