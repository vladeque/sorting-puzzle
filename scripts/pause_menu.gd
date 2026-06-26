extends ColorRect

const SETTINGS_BUTTON_PATHS: Array[NodePath] = [
	^"PauseMenuPanel/MarginContainer/VBoxContainer/IconRow/MusicButton",
	^"PauseMenuPanel/MarginContainer/VBoxContainer/IconRow/SoundEffectsButton",
	^"PauseMenuPanel/MarginContainer/VBoxContainer/IconRow/VibrationButton",
]
const CROSS_OUT_NAME := "CrossOut"


func _ready() -> void:
	for button_path in SETTINGS_BUTTON_PATHS:
		var button := get_node_or_null(button_path) as Button
		if button == null:
			push_warning("Missing pause menu setting button: %s" % button_path)
			continue

		var cross_out := _create_cross_out_marker(button)
		button.pressed.connect(_on_setting_button_pressed.bind(cross_out))


func _on_setting_button_pressed(cross_out: Control) -> void:
	cross_out.visible = not cross_out.visible


func _create_cross_out_marker(button: Button) -> Control:
	var existing := button.get_node_or_null(CROSS_OUT_NAME) as Control
	if existing != null:
		existing.visible = false
		return existing

	var cross_out := Control.new()
	cross_out.name = CROSS_OUT_NAME
	cross_out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross_out.position = Vector2(6, 38)
	cross_out.size = Vector2(74, 16)
	cross_out.pivot_offset = cross_out.size * 0.5
	cross_out.rotation_degrees = -38.0
	cross_out.visible = false
	button.add_child(cross_out)

	var border := ColorRect.new()
	border.name = "Border"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.color = Color(1.0, 0.82, 0.26, 1.0)
	border.size = cross_out.size
	cross_out.add_child(border)

	var slash := ColorRect.new()
	slash.name = "Slash"
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.color = Color(0.86, 0.08, 0.06, 1.0)
	slash.position = Vector2(3, 3)
	slash.size = cross_out.size - Vector2(6, 6)
	cross_out.add_child(slash)

	return cross_out
