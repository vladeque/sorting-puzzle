extends Control

signal avatar_saved(avatar_id: String)

const GRID_COLUMNS := 3
const SIDE_MARGIN := 36.0
const TOP_MARGIN := 54.0
const BOTTOM_MARGIN := 34.0
const AVATAR_BUTTON_MIN_SIZE := 92.0
const AVATAR_BUTTON_MAX_SIZE := 132.0
const GRID_H_SEPARATION := 12
const GRID_V_SEPARATION := 14
const AVATAR_TEXTURE_INSET := 10.0
const SAVE_BUTTON_MAX_WIDTH := 420.0

@onready var _content_margin := %ContentMargin as MarginContainer
@onready var _avatar_grid := %AvatarGrid as GridContainer
@onready var _save_button := %SaveButton as Button

var _selected_avatar_id := ""
var _avatar_buttons := {}


func _ready() -> void:
	_selected_avatar_id = PlayerProgress.get_avatar_id()
	_avatar_grid.columns = GRID_COLUMNS
	_avatar_grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
	_avatar_grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
	_save_button.text = "Save"
	_save_button.pressed.connect(_save_selection)
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

		button.add_child(avatar_texture)
		_avatar_grid.add_child(button)
		_avatar_buttons[avatar_id] = button


func _select_avatar(avatar_id: String) -> void:
	_selected_avatar_id = avatar_id
	_update_avatar_button_states()


func _save_selection() -> void:
	if PlayerProgress.set_avatar_id(_selected_avatar_id):
		avatar_saved.emit(_selected_avatar_id)
		queue_free()


func _update_avatar_button_states() -> void:
	for avatar_id in _avatar_buttons.keys():
		var button := _avatar_buttons[avatar_id] as Button
		var is_selected := avatar_id == _selected_avatar_id
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
	var side_margin := minf(SIDE_MARGIN, maxf(viewport_size.x * 0.06, 20.0))
	_content_margin.add_theme_constant_override("margin_left", roundi(safe_margins.x + side_margin))
	_content_margin.add_theme_constant_override("margin_top", roundi(safe_margins.y + TOP_MARGIN))
	_content_margin.add_theme_constant_override("margin_right", roundi(safe_margins.z + side_margin))
	_content_margin.add_theme_constant_override("margin_bottom", roundi(safe_margins.w + BOTTOM_MARGIN))

	var available_width := maxf(viewport_size.x - safe_margins.x - safe_margins.z - side_margin * 2.0, 1.0)
	var avatar_size := clampf(
		floorf((available_width - float(GRID_H_SEPARATION * (GRID_COLUMNS - 1))) / float(GRID_COLUMNS)),
		AVATAR_BUTTON_MIN_SIZE,
		AVATAR_BUTTON_MAX_SIZE
	)
	for button in _avatar_buttons.values():
		(button as Button).custom_minimum_size = Vector2(avatar_size, avatar_size)

	var save_minimum_size := _save_button.custom_minimum_size
	save_minimum_size.x = minf(SAVE_BUTTON_MAX_WIDTH, available_width)
	_save_button.custom_minimum_size = save_minimum_size


func _create_avatar_style(is_selected: bool, is_hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.94, 0.88, 0.96)
	style.border_color = Color(0.54, 0.35, 0.62, 0.78)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.12, 0.12, 0.18, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)

	if is_selected:
		style.bg_color = Color(0.91, 1.0, 0.84, 0.98)
		style.border_color = Color(0.2, 0.66, 0.27, 1.0)
		style.border_width_left = 5
		style.border_width_top = 5
		style.border_width_right = 5
		style.border_width_bottom = 5
	elif is_hover:
		style.bg_color = Color(1.0, 0.97, 0.9, 0.98)
		style.border_color = Color(0.72, 0.5, 0.38, 0.95)

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
