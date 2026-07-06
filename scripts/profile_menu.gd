extends Control

signal avatar_saved(avatar_id: String)

const AVATAR_CLIP_SHADER := preload("res://assets/ui/avatar_circle_clip.gdshader")
const GRID_COLUMNS := 3
const PANEL_MAX_WIDTH := 520.0
const PANEL_MAX_HEIGHT := 740.0
const PANEL_MIN_MARGIN := 24.0
const PANEL_HORIZONTAL_PADDING := 140.0
const AVATAR_BUTTON_MIN_SIZE := 82.0
const AVATAR_BUTTON_MAX_SIZE := 104.0
const GRID_H_SEPARATION := 14
const GRID_V_SEPARATION := 14
const AVATAR_TEXTURE_INSET := 10.0
const SAVE_BUTTON_MAX_WIDTH := 240.0

@onready var _panel := %ProfileMenuPanel as Panel
@onready var _name_line_edit := %NameLineEdit as LineEdit
@onready var _avatar_grid := %AvatarGrid as GridContainer
@onready var _save_button := %SaveButton as Button
@onready var _close_button := %CloseButton as Button

var _selected_avatar_id := ""
var _avatar_buttons := {}


func _ready() -> void:
	_selected_avatar_id = PlayerProgress.get_avatar_id()
	_name_line_edit.text = PlayerProgress.get_player_name()
	_avatar_grid.columns = GRID_COLUMNS
	_avatar_grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
	_avatar_grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
	_save_button.text = "Save"
	_save_button.pressed.connect(_save_selection)
	_close_button.pressed.connect(queue_free)
	_name_line_edit.text_submitted.connect(_save_from_name_submit)
	resized.connect(_apply_responsive_layout)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_build_avatar_buttons()
	_apply_responsive_layout()
	_update_avatar_button_states()


func _build_avatar_buttons() -> void:
	for avatar_id in PlayerProgress.get_available_avatar_ids():
		var button := Button.new()
		button.name = avatar_id
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_select_avatar.bind(avatar_id))

		var avatar_texture := TextureRect.new()
		avatar_texture.name = "AvatarTexture"
		avatar_texture.anchor_left = 0.0
		avatar_texture.anchor_top = 0.0
		avatar_texture.anchor_right = 1.0
		avatar_texture.anchor_bottom = 1.0
		avatar_texture.offset_left = AVATAR_TEXTURE_INSET
		avatar_texture.offset_top = AVATAR_TEXTURE_INSET
		avatar_texture.offset_right = -AVATAR_TEXTURE_INSET
		avatar_texture.offset_bottom = -AVATAR_TEXTURE_INSET
		avatar_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_texture.texture = load(PlayerProgress.get_avatar_texture_path(avatar_id)) as Texture2D
		avatar_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_apply_avatar_clip_material(avatar_texture)

		button.add_child(avatar_texture)
		_avatar_grid.add_child(button)
		_avatar_buttons[avatar_id] = button


func _select_avatar(avatar_id: String) -> void:
	_selected_avatar_id = avatar_id
	_update_avatar_button_states()


func _save_selection() -> void:
	if PlayerProgress.set_profile(_selected_avatar_id, _name_line_edit.text):
		avatar_saved.emit(_selected_avatar_id)
		queue_free()


func _save_from_name_submit(_new_text: String) -> void:
	_save_selection()


func _update_avatar_button_states() -> void:
	for raw_avatar_id in _avatar_buttons.keys():
		var avatar_id := str(raw_avatar_id)
		var button := _avatar_buttons[avatar_id] as Button
		var is_selected: bool = avatar_id == _selected_avatar_id
		button.button_pressed = is_selected
		button.add_theme_stylebox_override("normal", _create_avatar_style(is_selected, false))
		button.add_theme_stylebox_override("hover", _create_avatar_style(is_selected, true))
		button.add_theme_stylebox_override("pressed", _create_avatar_style(true, true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_margins := _get_safe_area_margins(viewport_size)
	var available_width := maxf(viewport_size.x - safe_margins.x - safe_margins.z - PANEL_MIN_MARGIN * 2.0, 1.0)
	var available_height := maxf(viewport_size.y - safe_margins.y - safe_margins.w - PANEL_MIN_MARGIN * 2.0, 1.0)
	var panel_width := minf(PANEL_MAX_WIDTH, available_width)
	var panel_height := minf(PANEL_MAX_HEIGHT, available_height)
	_panel.offset_left = -panel_width * 0.5
	_panel.offset_top = -panel_height * 0.5
	_panel.offset_right = panel_width * 0.5
	_panel.offset_bottom = panel_height * 0.5

	var grid_width := maxf(panel_width - PANEL_HORIZONTAL_PADDING, 1.0)
	var avatar_size := clampf(
		floorf((grid_width - float(GRID_H_SEPARATION * (GRID_COLUMNS - 1))) / float(GRID_COLUMNS)),
		AVATAR_BUTTON_MIN_SIZE,
		AVATAR_BUTTON_MAX_SIZE
	)
	for button in _avatar_buttons.values():
		(button as Button).custom_minimum_size = Vector2(avatar_size, avatar_size)

	var save_minimum_size := _save_button.custom_minimum_size
	save_minimum_size.x = minf(SAVE_BUTTON_MAX_WIDTH, available_width)
	_save_button.custom_minimum_size = save_minimum_size


func _apply_avatar_clip_material(avatar_texture: TextureRect) -> void:
	var clip_material := ShaderMaterial.new()
	clip_material.shader = AVATAR_CLIP_SHADER
	avatar_texture.material = clip_material


func _create_avatar_style(is_selected: bool, is_hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.83, 0.66, 0.47, 1)
	style.border_color = Color(0.98, 0.87, 0.66, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.shadow_color = Color(0.3, 0.12, 0.07, 0.24)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)

	if is_selected:
		style.bg_color = Color(0.62, 0.25, 0.18, 1)
		style.border_color = Color(1.0, 0.92, 0.62, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 4
	elif is_hover:
		style.bg_color = Color(0.9, 0.72, 0.5, 1)
		style.border_color = Color(1.0, 0.92, 0.62, 1.0)

	return style


func _get_safe_area_margins(viewport_size: Vector2) -> Vector4:
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe_area := DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return Vector4.ZERO

	var scale := Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	var safe_end := safe_area.position + safe_area.size
	return Vector4(
		maxf(float(safe_area.position.x) * scale.x, 0.0),
		maxf(float(safe_area.position.y) * scale.y, 0.0),
		maxf(float(window_size.x - safe_end.x) * scale.x, 0.0),
		maxf(float(window_size.y - safe_end.y) * scale.y, 0.0)
	)
