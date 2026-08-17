extends Button
class_name ProfileChoiceTile

signal choice_selected(choice_id: String)

@onready var _preview := %ProfileAvatarView as ProfileAvatarView
@onready var _selected_badge := %SelectedBadge as Control

var choice_id := ""


func _ready() -> void:
	pressed.connect(_emit_selection)
	_apply_state(false)


func setup(next_choice_id: String, avatar_id: String, frame_id: String) -> void:
	choice_id = next_choice_id
	if is_node_ready():
		_preview.set_profile(avatar_id, frame_id)


func set_choice_selected(is_selected: bool) -> void:
	button_pressed = is_selected
	_apply_state(is_selected)


func _emit_selection() -> void:
	choice_selected.emit(choice_id)


func _apply_state(is_selected: bool) -> void:
	if _selected_badge != null:
		_selected_badge.visible = is_selected
	add_theme_stylebox_override("normal", _create_tile_style(is_selected, false))
	add_theme_stylebox_override("hover", _create_tile_style(is_selected, true))
	add_theme_stylebox_override("pressed", _create_tile_style(true, true))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _create_tile_style(is_selected: bool, is_hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.84, 0.68, 0.49, 1)
	style.border_color = Color(1.0, 0.91, 0.7, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0.3, 0.12, 0.07, 0.24)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	if is_selected:
		style.bg_color = Color(0.62, 0.25, 0.18, 1)
		style.border_color = Color(1.0, 0.92, 0.62, 1)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 5
	elif is_hover:
		style.bg_color = Color(0.9, 0.73, 0.52, 1)
	return style
