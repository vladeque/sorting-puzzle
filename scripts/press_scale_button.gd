extends Button
class_name PressScaleButton

@export_range(0.85, 1.0, 0.01) var held_scale := 0.94

var _released_scale := Vector2.ONE
var _is_held := false


func _ready() -> void:
	_released_scale = scale
	_update_pivot_offset()
	button_down.connect(_apply_held_scale)
	button_up.connect(_restore_released_scale)
	visibility_changed.connect(_restore_released_scale)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_pivot_offset()
	elif what == NOTIFICATION_EXIT_TREE:
		_restore_released_scale()


func _apply_held_scale() -> void:
	if disabled:
		return

	if not _is_held:
		_released_scale = scale

	_is_held = true
	scale = _released_scale * held_scale


func _restore_released_scale() -> void:
	if not _is_held:
		return

	_is_held = false
	scale = _released_scale


func _update_pivot_offset() -> void:
	pivot_offset = size * 0.5
