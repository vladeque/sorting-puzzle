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

var _pressure := 0.0
var _lean := 0.0


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var texture := AMBER if variant == "amber" else PINK
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = texture
		sprite.scale = Vector2(1.0 + 0.11 * _pressure, 1.0 - 0.14 * _pressure) * display_width / float(texture.get_width())
		sprite.skew = _lean * 0.65


## Scale/skew compose with texture sizing; never overwrite the scene-authored sprite position.
func set_resistance_pose(lean: float, pressure: float) -> void:
	_lean = lean
	_pressure = clampf(pressure, -0.3, 1.0)
	_refresh()
