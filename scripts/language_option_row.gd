extends "res://scripts/press_scale_button.gd"
class_name LanguageOptionRow

signal locale_selected(locale: String)

@onready var _selection_marker := %SelectionMarker as Label

var locale_code := ""


func _ready() -> void:
	super._ready()
	pressed.connect(_emit_locale_selected)


func setup(code: String, display_label: String, is_selected: bool) -> void:
	locale_code = code
	text = display_label
	set_locale_selected(is_selected)


func set_locale_selected(is_selected: bool) -> void:
	button_pressed = is_selected
	if is_instance_valid(_selection_marker):
		_selection_marker.text = "✓" if is_selected else ""


func _emit_locale_selected() -> void:
	locale_selected.emit(locale_code)
