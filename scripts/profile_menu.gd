extends Control

signal profile_saved(avatar_id: String, avatar_frame_id: String)

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const ProfileFrameCatalogScript := preload("res://scripts/profile_frame_catalog.gd")
const PROFILE_CHOICE_TILE_SCENE := preload("res://scenes/ui/profile_choice_tile.tscn")
const GRID_COLUMNS := 3
const PANEL_MAX_WIDTH := 600.0
const PANEL_MAX_HEIGHT := 900.0
const PANEL_MIN_MARGIN := 18.0
const GRID_HORIZONTAL_PADDING := 116.0
const TILE_MIN_SIZE := 92.0
const TILE_MAX_SIZE := 160.0
const GRID_H_SEPARATION := 14
const GRID_V_SEPARATION := 14
const SAVE_BUTTON_MAX_WIDTH := 250.0
const TAB_AVATAR := &"avatar"
const TAB_FRAME := &"frame"

@onready var _panel := %ProfileMenuPanel as Panel
@onready var _profile_preview := %ProfilePreview as ProfileAvatarView
@onready var _name_line_edit := %NameLineEdit as LineEdit
@onready var _edit_name_button := %EditNameButton as Button
@onready var _avatar_tab := %AvatarTab as Button
@onready var _frame_tab := %FrameTab as Button
@onready var _choice_scroll := %ChoiceScroll as ScrollContainer
@onready var _choice_grid := %ChoiceGrid as GridContainer
@onready var _unlock_toast := %UnlockToast as ToastMessage
@onready var _save_button := %SaveButton as Button
@onready var _close_button := %CloseButton as Button

var _selected_avatar_id := ""
var _selected_avatar_frame_id := ""
var _pending_player_name := ""
var _active_tab := TAB_AVATAR
var _choice_tiles: Dictionary = {}
var _is_closing := false


func _ready() -> void:
	_selected_avatar_id = PlayerProgress.get_avatar_id()
	_selected_avatar_frame_id = PlayerProgress.get_avatar_frame_id()
	_pending_player_name = PlayerProgress.get_player_name()
	_name_line_edit.text = _pending_player_name
	_profile_preview.set_profile(_selected_avatar_id, _selected_avatar_frame_id)
	_choice_grid.columns = GRID_COLUMNS
	_choice_grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
	_choice_grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
	_save_button.text = "SAVE"
	_save_button.pressed.connect(_save_selection)
	_close_button.pressed.connect(close)
	_edit_name_button.pressed.connect(_begin_name_edit)
	_name_line_edit.text_submitted.connect(_finish_name_edit)
	_name_line_edit.focus_exited.connect(_finish_name_edit.bind(""))
	_avatar_tab.pressed.connect(_switch_tab.bind(TAB_AVATAR))
	_frame_tab.pressed.connect(_switch_tab.bind(TAB_FRAME))
	resized.connect(_apply_responsive_layout)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_switch_tab(TAB_AVATAR)


func _switch_tab(tab_id: StringName) -> void:
	_active_tab = tab_id if tab_id in [TAB_AVATAR, TAB_FRAME] else TAB_AVATAR
	_avatar_tab.button_pressed = _active_tab == TAB_AVATAR
	_frame_tab.button_pressed = _active_tab == TAB_FRAME
	_apply_tab_style(_avatar_tab, _active_tab == TAB_AVATAR, true)
	_apply_tab_style(_frame_tab, _active_tab == TAB_FRAME, false)
	_rebuild_choice_grid()


func _rebuild_choice_grid() -> void:
	for child in _choice_grid.get_children():
		_choice_grid.remove_child(child)
		child.queue_free()
	_choice_tiles.clear()
	var choice_ids: Array = (
		PlayerProgress.get_available_avatar_ids()
		if _active_tab == TAB_AVATAR
		else ProfileFrameCatalogScript.get_available_frame_ids()
	)
	var unlocked_frame_ids := PlayerProgress.get_available_avatar_frame_ids()
	for raw_choice_id in choice_ids:
		var choice_id := str(raw_choice_id)
		var tile := PROFILE_CHOICE_TILE_SCENE.instantiate() as ProfileChoiceTile
		_choice_grid.add_child(tile)
		var preview_avatar_id := choice_id if _active_tab == TAB_AVATAR else _selected_avatar_id
		var preview_frame_id := _selected_avatar_frame_id if _active_tab == TAB_AVATAR else choice_id
		tile.setup(choice_id, preview_avatar_id, preview_frame_id)
		tile.set_choice_locked(_active_tab == TAB_FRAME and not unlocked_frame_ids.has(choice_id))
		tile.choice_selected.connect(_select_choice)
		var is_selected := (
			choice_id == _selected_avatar_id
			if _active_tab == TAB_AVATAR
			else choice_id == _selected_avatar_frame_id
		)
		tile.set_choice_selected(is_selected)
		_choice_tiles[choice_id] = tile
	_apply_responsive_layout()
	_scroll_to_selected.call_deferred()


func _select_choice(choice_id: String) -> void:
	if _active_tab == TAB_AVATAR:
		_selected_avatar_id = choice_id
	else:
		if not PlayerProgress.get_available_avatar_frame_ids().has(choice_id):
			_show_locked_frame_hint(choice_id)
			return
		_selected_avatar_frame_id = choice_id
	_profile_preview.set_profile(_selected_avatar_id, _selected_avatar_frame_id)
	_rebuild_choice_grid()


func _show_locked_frame_hint(frame_id: String) -> void:
	var required_rank := ProfileFrameCatalogScript.get_weekly_rank_required(frame_id)
	if required_rank <= 0:
		return
	var placement := "1st" if required_rank == 1 else "top %d" % required_rank
	_unlock_toast.show_message("Finish %s on the Weekly leaderboard to unlock" % placement)


func _begin_name_edit() -> void:
	_name_line_edit.editable = true
	_name_line_edit.selecting_enabled = true
	_name_line_edit.focus_mode = Control.FOCUS_ALL
	_name_line_edit.text = _pending_player_name
	_name_line_edit.grab_focus()
	_name_line_edit.caret_column = _name_line_edit.text.length()


func _finish_name_edit(_submitted_text: String = "") -> void:
	if not _name_line_edit.editable:
		return
	var candidate := _name_line_edit.text.strip_edges()
	if not candidate.is_empty():
		_pending_player_name = candidate.left(24)
	_name_line_edit.text = _pending_player_name
	_name_line_edit.editable = false
	_name_line_edit.selecting_enabled = false
	_name_line_edit.focus_mode = Control.FOCUS_NONE


func _save_selection() -> void:
	_finish_name_edit()
	if PlayerProgress.set_profile_customization(
		_selected_avatar_id,
		_selected_avatar_frame_id,
		_pending_player_name
	):
		profile_saved.emit(_selected_avatar_id, _selected_avatar_frame_id)
		close()


func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	UIMotionScript.close_with_fade(self, queue_free)


func _scroll_to_selected() -> void:
	var selected_id := _selected_avatar_id if _active_tab == TAB_AVATAR else _selected_avatar_frame_id
	var selected_tile := _choice_tiles.get(selected_id) as Control
	if selected_tile != null and is_instance_valid(selected_tile):
		_choice_scroll.ensure_control_visible(selected_tile)


func _apply_responsive_layout() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var safe_margins := _get_safe_area_margins(viewport_size)
	var available_width := maxf(
		viewport_size.x - safe_margins.x - safe_margins.z - PANEL_MIN_MARGIN * 2.0,
		1.0
	)
	var available_height := maxf(
		viewport_size.y - safe_margins.y - safe_margins.w - PANEL_MIN_MARGIN * 2.0,
		1.0
	)
	var panel_width := minf(PANEL_MAX_WIDTH, available_width)
	var panel_height := minf(PANEL_MAX_HEIGHT, available_height)
	_panel.offset_left = -panel_width * 0.5
	_panel.offset_top = -panel_height * 0.5
	_panel.offset_right = panel_width * 0.5
	_panel.offset_bottom = panel_height * 0.5
	var grid_width := maxf(panel_width - GRID_HORIZONTAL_PADDING, 1.0)
	var tile_size := clampf(
		floorf((grid_width - float(GRID_H_SEPARATION * (GRID_COLUMNS - 1))) / float(GRID_COLUMNS)),
		TILE_MIN_SIZE,
		TILE_MAX_SIZE
	)
	for tile in _choice_tiles.values():
		(tile as Control).custom_minimum_size = Vector2(tile_size, tile_size)
	var save_minimum_size := _save_button.custom_minimum_size
	save_minimum_size.x = minf(SAVE_BUTTON_MAX_WIDTH, available_width)
	_save_button.custom_minimum_size = save_minimum_size


func _apply_tab_style(button: Button, is_selected: bool, is_left: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.66, 0.32, 0.22, 1) if is_selected else Color(0.91, 0.72, 0.46, 1)
	style.border_color = Color(1.0, 0.88, 0.56, 1) if is_selected else Color(0.55, 0.25, 0.16, 0.72)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 4
	style.corner_radius_top_left = 18 if is_left else 0
	style.corner_radius_bottom_left = 18 if is_left else 0
	style.corner_radius_top_right = 0 if is_left else 18
	style.corner_radius_bottom_right = 0 if is_left else 18
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style.duplicate())
	button.add_theme_stylebox_override("pressed", style.duplicate())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(1, 0.96, 0.82, 1) if is_selected else Color(0.35, 0.12, 0.07, 1))
	button.add_theme_color_override("font_outline_color", Color(0.28, 0.07, 0.03, 0.9) if is_selected else Color(1, 0.94, 0.74, 0.7))
	button.add_theme_constant_override("outline_size", 2)


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
