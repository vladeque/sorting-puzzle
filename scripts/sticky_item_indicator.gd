@tool
class_name StickyItemIndicator
extends Node2D

const PINK := preload("res://assets/ui/sticky_items/gum_pink.png")
const AMBER := preload("res://assets/ui/sticky_items/glue_amber.png")

@export_enum("pink", "amber") var variant := "pink":
	set(value):
		variant = value
		_refresh()

@export var display_width := 92.0:
	set(value):
		display_width = value
		_refresh()

var _feedback: Tween


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var texture := AMBER if variant == "amber" else PINK
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = texture
		sprite.scale = Vector2.ONE * display_width / float(texture.get_width())


func play_blocked_feedback() -> void:
	if not is_inside_tree():
		return
	if _feedback != null and _feedback.is_valid():
		_feedback.kill()
	modulate = Color.WHITE
	_feedback = create_tween()
	_feedback.tween_property(self, "modulate", Color(1.35, 1.35, 1.35), 0.07)
	_feedback.tween_property(self, "modulate", Color.WHITE, 0.18)
