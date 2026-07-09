extends ColorRect

signal setting_toggled(setting_id: StringName, is_disabled: bool)

const SETTING_MUSIC := &"music"
const SETTING_SOUND_EFFECTS := &"sound_effects"
const SETTING_VIBRATION := &"vibration"
const SETTINGS_BUTTONS: Array[Dictionary] = [
	{
		"path": ^"PauseMenuPanel/InnerPanel/IconRow/MusicOption/MusicButton",
		"setting_id": SETTING_MUSIC,
	},
	{
		"path": ^"PauseMenuPanel/InnerPanel/IconRow/SoundEffectsOption/SoundEffectsButton",
		"setting_id": SETTING_SOUND_EFFECTS,
	},
	{
		"path": ^"PauseMenuPanel/InnerPanel/IconRow/VibrationOption/VibrationButton",
		"setting_id": SETTING_VIBRATION,
	},
]
const CROSS_OUT_NAME := "CrossOut"

static var _disabled_settings: Dictionary = {}


func _ready() -> void:
	for button_config in SETTINGS_BUTTONS:
		var button_path := button_config.get("path") as NodePath
		var setting_id := button_config.get("setting_id") as StringName
		var button := get_node_or_null(button_path) as Button
		if button == null:
			push_warning("Missing pause menu setting button: %s" % button_path)
			continue

		var cross_out := _create_cross_out_marker(button)
		cross_out.visible = is_setting_disabled(setting_id)
		button.pressed.connect(_on_setting_button_pressed.bind(cross_out, setting_id))


func is_setting_disabled(setting_id: StringName) -> bool:
	return bool(_disabled_settings.get(setting_id, false))


func _on_setting_button_pressed(cross_out: Control, setting_id: StringName) -> void:
	var is_disabled := not is_setting_disabled(setting_id)
	_disabled_settings[setting_id] = is_disabled
	cross_out.visible = is_disabled
	setting_toggled.emit(setting_id, is_disabled)


func _create_cross_out_marker(button: Button) -> Control:
	var existing := button.get_node_or_null(CROSS_OUT_NAME) as Control
	if existing != null:
		return existing

	var cross_out := Control.new()
	cross_out.name = CROSS_OUT_NAME
	cross_out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross_out.position = Vector2(2, 42)
	cross_out.size = Vector2(96, 14)
	cross_out.pivot_offset = cross_out.size * 0.5
	cross_out.rotation_degrees = -45.0
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
