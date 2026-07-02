extends Node2D

const SLOT_COUNT := 3
const SLOT_ITEM_POSITION := Vector2(0, -32)
const SHELF_CELL_SIZE := Vector2(224, 135)
const SHELF_SHARED_EDGE_THICKNESS := 8.0
const SHELF_GRID_STEP := SHELF_CELL_SIZE - Vector2(SHELF_SHARED_EDGE_THICKNESS, SHELF_SHARED_EDGE_THICKNESS)
const BACK_LAYER_PREFIX := "ShelfLayer"
const FIRST_BACK_LAYER_INDEX := 1
const ABILITY_HAMMER := &"hammer"
const ABILITY_SHUFFLE := &"shuffle"
const ABILITY_HIGHLIGHT := &"highlight"
const HIGHLIGHT_DURATION_SECONDS := 15.0
const SHELF_SCENE := preload("res://scenes/shelf.tscn")
const MOVING_SHELF_ROW_SCENE := preload("res://scenes/moving_shelf_row.tscn")
const ITEM_SCENE := preload("res://scenes/item.tscn")
const ITEM_SPRITES_CONFIG := "res://configs/item_sprites.json"
const LEVEL_CONFIG_TEMPLATE := "res://configs/levels/level_%03d.json"
const DEFAULT_LEVEL_CONFIG := "res://configs/levels/level_001.json"
const LAYOUT_SCENE_TEMPLATE := "res://scenes/layouts/layout_%s.tscn"
const DEFAULT_LAYOUT_PRESET := "grid_3x3"
const LEVEL_SCENE_PATH := "res://level.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const ITEM_PLACE_SOUND := preload("res://assets/audio/item_place.wav")
const TRIPLE_CLEAR_SOUND := preload("res://assets/audio/triple_clear.wav")
const PAUSE_SETTING_SOUND_EFFECTS := &"sound_effects"
const SHELF_UNLOCK_REQUIREMENT_META := &"unlock_after_triples"
const SHELF_LOCKED_META := &"is_locked"
const LOCKED_OVERLAY_NAME := "LockedOverlay"
const LOCK_REMAINING_LABEL_NAME := "RemainingLabel"
const ROW_LAYOUTS_KEY := "row_layouts"
const ROW_MOTION_HORIZONTAL_WRAP := "horizontal_wrap"
const SHELF_VISUAL_VARIANT_FULL := "full"
const SHELF_VISUAL_VARIANT_FLOOR_ONLY := "floor_only"
const HUD_TOP_MARGIN := 28.0
const HUD_SIDE_MARGIN := 24.0
const LEVEL_LABEL_MARGIN_LEFT := 32.0
const LEVEL_LABEL_TOP := 42.0
const LEVEL_LABEL_SIZE := Vector2(194, 40)
const TIMER_LABEL_HEIGHT := 64.0
const PAUSE_BUTTON_SIZE := Vector2(64, 64)
const ABILITY_BAR_HEIGHT := 126.0
const ABILITY_BAR_DESIGN_BOTTOM_MARGIN := 96.0
const ABILITY_BAR_SAFE_BOTTOM_PADDING := 24.0
const ABILITY_BUTTON_ROW_SIZE := Vector2(396, 100)
const ABILITY_BUTTON_ROW_TOP := 12.0
const SHELVES_TOP_CLEARANCE := 128.0
const SHELVES_BOTTOM_CLEARANCE := 52.0
const SHELVES_SIDE_MARGIN := 32.0
const SHELVES_MIN_LAYOUT_SCALE := 0.45
const SHELVES_MAX_LAYOUT_SCALE := 1.5
const RESULT_LABEL_HEIGHT := 96.0
const PAUSE_MENU_PANEL_SIZE := Vector2(520, 363)
const SHELF_FLOOR_ONLY_HIDDEN_NODES := [
	"BackWall",
	"BackWallLeftShade",
	"Ceiling",
	"LeftWall",
	"RightWall",
	"Highlight",
]

@export var slot_snap_distance := 98.0
@export var item_pick_size := Vector2(74, 112)
@export var drag_start_distance := 12.0
@export var back_layer_offset := Vector2(0, -10)
@export var back_layer_item_scale := 0.86
@export var back_layer_item_modulate := Color(0.42, 0.42, 0.42, 0.34)
@export var layer_promotion_duration_seconds := 0.22
@export var item_move_duration_seconds := 0.16
@export var highlight_outline_color := Color(1.0, 0.86, 0.18, 1.0)
@export var selected_highlight_outline_color := Color(1.0, 0.96, 0.36, 1.0)
@export_range(0.0, 8.0, 0.25) var highlight_outline_width := 4.0
@export var match_gather_duration_seconds := 0.18
@export var match_shrink_duration_seconds := 0.16
@export var level_duration_seconds := 300.0
@export var completion_return_delay_seconds := 1.75
@export_range(-40.0, 6.0, 0.5) var item_place_volume_db := -5.0
@export_range(-40.0, 6.0, 0.5) var triple_clear_volume_db := -5.0
@export_range(1, 10, 1) var selected_level := 1
@export var launched_from_dev_mode := false

var _slots: Array[Node2D] = []
var _item_textures: Dictionary = {}
var _max_layer_count := 1
var _dragged_item: ShelfItem
var _origin_slot: Node2D
var _drag_offset := Vector2.ZERO
var _drag_layer: Node2D
var _background: Control
var _shelves_root: Node2D
var _timer_label: Label
var _level_label: Label
var _failure_panel: Control
var _completion_panel: Control
var _pause_menu_button: Button
var _pause_menu_overlay: Control
var _leave_button: Button
var _continue_button: Button
var _ability_bar: Control
var _ability_button_row: Control
var _ability_buttons: Dictionary = {}
var _highlight_timer_label: Label
var _ability_uses: Dictionary = {
	ABILITY_HAMMER: 3,
	ABILITY_SHUFFLE: 3,
	ABILITY_HIGHLIGHT: 3,
}
var _time_remaining := 0.0
var _has_player_started_timer := false
var _level_failed := false
var _level_completed := false
var _level_paused := false
var _completion_return_time_remaining := 0.0
var _returning_to_menu := false
var _highlight_timer := 0.0
var _highlighted_items: Array[ShelfItem] = []
var _layout_preset := DEFAULT_LAYOUT_PRESET
var _rng := RandomNumberGenerator.new()
var _pressed_item: ShelfItem
var _pressed_origin_slot: Node2D
var _press_position := Vector2.ZERO
var _selected_item: ShelfItem
var _selected_slot: Node2D
var _is_resolving_shelves := false
var _shelves_pending_resolve: Array[Node] = []
var _clearing_item_ids: Array[int] = []
var _transitioning_item_ids: Array[int] = []
var _item_place_audio_player: AudioStreamPlayer
var _triple_clear_audio_player: AudioStreamPlayer
var _sound_effects_enabled := true
var _triples_cleared := 0
var _shelves_layout_scale := 1.0


func _ready() -> void:
	_background = get_node("Background") as Control
	_shelves_root = get_node("Shelves") as Node2D
	_drag_layer = get_node("DragLayer") as Node2D
	_timer_label = get_node("UI/TimerLabel") as Label
	_level_label = get_node("UI/LevelLabel") as Label
	_failure_panel = get_node("UI/FailurePanel") as Control
	_completion_panel = get_node("UI/CompletionPanel") as Control
	_pause_menu_button = get_node("UI/PauseMenuButton") as Button
	_pause_menu_overlay = get_node("UI/PauseMenuOverlay") as Control
	_leave_button = get_node("UI/PauseMenuOverlay/PauseMenuPanel/MarginContainer/VBoxContainer/ButtonRow/LeaveButton") as Button
	_continue_button = get_node("UI/PauseMenuOverlay/PauseMenuPanel/MarginContainer/VBoxContainer/ButtonRow/ContinueButton") as Button
	_ability_bar = get_node("UI/AbilityBar") as Control
	_ability_button_row = get_node("UI/AbilityBar/HBoxContainer") as Control
	_failure_panel.visible = false
	_completion_panel.visible = false
	_pause_menu_overlay.visible = false
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_rng.randomize()
	_setup_audio_players()
	_setup_pause_menu_buttons()
	_setup_ability_buttons()
	_load_item_textures()
	_apply_level_config(_load_level_config(selected_level))
	_collect_slots()
	_update_level_label()
	_update_timer_label()
	_update_ability_buttons()
	_update_pause_menu_button()


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_margins := _get_safe_area_margins(viewport_size)
	if _background != null:
		_background.position = Vector2.ZERO
		_background.size = viewport_size

	_layout_top_hud(safe_margins)
	_layout_ability_bar(safe_margins)
	_layout_result_panel(_failure_panel, safe_margins)
	_layout_result_panel(_completion_panel, safe_margins)
	_layout_pause_menu_overlay()
	_layout_shelves(viewport_size, safe_margins)


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


func _layout_top_hud(safe_margins: Vector4) -> void:
	if _timer_label != null:
		_timer_label.anchor_left = 0.0
		_timer_label.anchor_top = 0.0
		_timer_label.anchor_right = 1.0
		_timer_label.anchor_bottom = 0.0
		_timer_label.offset_left = safe_margins.x
		_timer_label.offset_top = safe_margins.y + HUD_TOP_MARGIN
		_timer_label.offset_right = -safe_margins.z
		_timer_label.offset_bottom = safe_margins.y + HUD_TOP_MARGIN + TIMER_LABEL_HEIGHT

	if _level_label != null:
		_level_label.anchor_left = 0.0
		_level_label.anchor_top = 0.0
		_level_label.anchor_right = 0.0
		_level_label.anchor_bottom = 0.0
		_level_label.offset_left = safe_margins.x + LEVEL_LABEL_MARGIN_LEFT
		_level_label.offset_top = safe_margins.y + LEVEL_LABEL_TOP
		_level_label.offset_right = _level_label.offset_left + LEVEL_LABEL_SIZE.x
		_level_label.offset_bottom = _level_label.offset_top + LEVEL_LABEL_SIZE.y

	if _pause_menu_button != null:
		_pause_menu_button.anchor_left = 1.0
		_pause_menu_button.anchor_top = 0.0
		_pause_menu_button.anchor_right = 1.0
		_pause_menu_button.anchor_bottom = 0.0
		_pause_menu_button.offset_right = -(safe_margins.z + HUD_SIDE_MARGIN)
		_pause_menu_button.offset_left = _pause_menu_button.offset_right - PAUSE_BUTTON_SIZE.x
		_pause_menu_button.offset_top = safe_margins.y + HUD_TOP_MARGIN
		_pause_menu_button.offset_bottom = _pause_menu_button.offset_top + PAUSE_BUTTON_SIZE.y


func _layout_ability_bar(safe_margins: Vector4) -> void:
	if _ability_bar == null:
		return

	var bottom_margin := _get_ability_bar_bottom_margin(safe_margins)
	_ability_bar.anchor_left = 0.0
	_ability_bar.anchor_top = 1.0
	_ability_bar.anchor_right = 1.0
	_ability_bar.anchor_bottom = 1.0
	_ability_bar.offset_left = safe_margins.x
	_ability_bar.offset_top = -(bottom_margin + ABILITY_BAR_HEIGHT)
	_ability_bar.offset_right = -safe_margins.z
	_ability_bar.offset_bottom = -bottom_margin

	if _ability_button_row != null:
		_ability_button_row.anchor_left = 0.5
		_ability_button_row.anchor_top = 0.0
		_ability_button_row.anchor_right = 0.5
		_ability_button_row.anchor_bottom = 0.0
		_ability_button_row.offset_left = -ABILITY_BUTTON_ROW_SIZE.x * 0.5
		_ability_button_row.offset_top = ABILITY_BUTTON_ROW_TOP
		_ability_button_row.offset_right = ABILITY_BUTTON_ROW_SIZE.x * 0.5
		_ability_button_row.offset_bottom = ABILITY_BUTTON_ROW_TOP + ABILITY_BUTTON_ROW_SIZE.y


func _get_ability_bar_bottom_margin(safe_margins: Vector4) -> float:
	return maxf(ABILITY_BAR_DESIGN_BOTTOM_MARGIN, safe_margins.w + ABILITY_BAR_SAFE_BOTTOM_PADDING)


func _layout_result_panel(panel: Control, safe_margins: Vector4) -> void:
	if panel == null:
		return

	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0

	for child in panel.get_children():
		var label := child as Label
		if label == null:
			continue

		label.anchor_left = 0.0
		label.anchor_top = 0.5
		label.anchor_right = 1.0
		label.anchor_bottom = 0.5
		label.offset_left = safe_margins.x
		label.offset_top = -RESULT_LABEL_HEIGHT * 0.5
		label.offset_right = -safe_margins.z
		label.offset_bottom = RESULT_LABEL_HEIGHT * 0.5


func _layout_pause_menu_overlay() -> void:
	if _pause_menu_overlay == null:
		return

	_pause_menu_overlay.anchor_left = 0.0
	_pause_menu_overlay.anchor_top = 0.0
	_pause_menu_overlay.anchor_right = 1.0
	_pause_menu_overlay.anchor_bottom = 1.0
	_pause_menu_overlay.offset_left = 0.0
	_pause_menu_overlay.offset_top = 0.0
	_pause_menu_overlay.offset_right = 0.0
	_pause_menu_overlay.offset_bottom = 0.0

	var panel := _pause_menu_overlay.get_node_or_null("PauseMenuPanel") as Control
	if panel == null:
		return

	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PAUSE_MENU_PANEL_SIZE.x * 0.5
	panel.offset_top = -PAUSE_MENU_PANEL_SIZE.y * 0.5
	panel.offset_right = PAUSE_MENU_PANEL_SIZE.x * 0.5
	panel.offset_bottom = PAUSE_MENU_PANEL_SIZE.y * 0.5


func _layout_shelves(viewport_size: Vector2, safe_margins: Vector4) -> void:
	if _shelves_root == null:
		return

	var play_top := safe_margins.y + SHELVES_TOP_CLEARANCE
	var ability_top := viewport_size.y - _get_ability_bar_bottom_margin(safe_margins) - ABILITY_BAR_HEIGHT
	var play_bottom := maxf(play_top, ability_top - SHELVES_BOTTOM_CLEARANCE)
	var play_left := safe_margins.x + SHELVES_SIDE_MARGIN
	var play_right := viewport_size.x - safe_margins.z - SHELVES_SIDE_MARGIN
	var shelf_bounds := _get_shelves_local_bounds()
	_shelves_layout_scale = _get_shelves_layout_scale(shelf_bounds, play_left, play_right, play_top, play_bottom)
	_shelves_root.scale = Vector2.ONE * _shelves_layout_scale

	var scaled_bounds := _get_scaled_rect(shelf_bounds, _shelves_layout_scale)
	var root_position := Vector2((play_left + play_right) * 0.5, (play_top + play_bottom) * 0.5)
	if shelf_bounds.size.y > 0.0:
		var bounds_center_x := scaled_bounds.position.x + scaled_bounds.size.x * 0.5
		root_position.x = (play_left + play_right) * 0.5 - bounds_center_x

		var min_root_x := play_left - scaled_bounds.position.x
		var max_root_x := play_right - (scaled_bounds.position.x + scaled_bounds.size.x)
		if min_root_x <= max_root_x:
			root_position.x = clampf(root_position.x, min_root_x, max_root_x)

		var bounds_center_y := scaled_bounds.position.y + scaled_bounds.size.y * 0.5
		root_position.y = (play_top + play_bottom) * 0.5 - bounds_center_y

		var min_root_y := play_top - scaled_bounds.position.y
		var max_root_y := play_bottom - (scaled_bounds.position.y + scaled_bounds.size.y)
		if min_root_y <= max_root_y:
			root_position.y = clampf(root_position.y, min_root_y, max_root_y)
		else:
			root_position.y = min_root_y

	_shelves_root.position = root_position


func _get_shelves_layout_scale(
	shelf_bounds: Rect2,
	play_left: float,
	play_right: float,
	play_top: float,
	play_bottom: float
) -> float:
	if shelf_bounds.size.x <= 0.0 or shelf_bounds.size.y <= 0.0:
		return 1.0

	var play_width := maxf(play_right - play_left, 1.0)
	var play_height := maxf(play_bottom - play_top, 1.0)
	var fit_scale := minf(play_width / shelf_bounds.size.x, play_height / shelf_bounds.size.y)
	return clampf(fit_scale, SHELVES_MIN_LAYOUT_SCALE, SHELVES_MAX_LAYOUT_SCALE)


func _get_scaled_rect(rect: Rect2, scale_value: float) -> Rect2:
	return Rect2(rect.position * scale_value, rect.size * scale_value)


func _get_shelves_local_bounds() -> Rect2:
	if _shelves_root == null:
		return Rect2()

	var bounds := Rect2()
	var has_bounds := false
	for child in _shelves_root.get_children():
		var child_rect := _get_shelves_root_child_bounds(child)
		if child_rect.size.x <= 0.0 or child_rect.size.y <= 0.0:
			continue

		if has_bounds:
			bounds = bounds.merge(child_rect)
		else:
			bounds = child_rect
			has_bounds = true

	return bounds if has_bounds else Rect2()


func _get_shelves_root_child_bounds(child: Node) -> Rect2:
	var moving_row := child as MovingShelfRow
	if moving_row != null:
		return Rect2(moving_row.position, moving_row.size)

	var shelf_node := child as Node2D
	if shelf_node != null and _is_shelf_node(shelf_node):
		return Rect2(shelf_node.position - SHELF_CELL_SIZE * 0.5, SHELF_CELL_SIZE)

	return Rect2()


func _setup_audio_players() -> void:
	_item_place_audio_player = _create_audio_player("ItemPlaceAudio", ITEM_PLACE_SOUND, item_place_volume_db)
	_triple_clear_audio_player = _create_audio_player("TripleClearAudio", TRIPLE_CLEAR_SOUND, triple_clear_volume_db)


func _create_audio_player(player_name: String, stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player


func _play_item_place_sound() -> void:
	if not _sound_effects_enabled or _item_place_audio_player == null:
		return

	_item_place_audio_player.stop()
	_item_place_audio_player.play()


func _play_triple_clear_sound() -> void:
	if not _sound_effects_enabled or _triple_clear_audio_player == null:
		return

	_triple_clear_audio_player.stop()
	_triple_clear_audio_player.play()


func _stop_sound_effects() -> void:
	if _item_place_audio_player != null:
		_item_place_audio_player.stop()

	if _triple_clear_audio_player != null:
		_triple_clear_audio_player.stop()


func _process(delta: float) -> void:
	if _level_completed:
		_completion_return_time_remaining = maxf(_completion_return_time_remaining - delta, 0.0)
		if _completion_return_time_remaining <= 0.0 and not _returning_to_menu:
			_advance_after_completion()
		return

	if _level_failed:
		return

	if _level_paused:
		return

	_update_highlight_timer(delta)
	_clear_drag_drop_selection_if_unavailable()

	if not _has_player_started_timer:
		return

	_time_remaining = maxf(_time_remaining - delta, 0.0)
	_update_timer_label()

	if _time_remaining <= 0.0:
		_fail_level()


func _input(event: InputEvent) -> void:
	if _level_failed or _level_completed:
		return

	if _level_paused:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		var pointer_position := get_global_mouse_position()
		if mouse_event.pressed:
			_handle_press_at(pointer_position)
		else:
			_handle_release_at(pointer_position)
	elif event is InputEventMouseMotion:
		_handle_motion_at(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		var pointer_position := _screen_position_to_global(touch_event.position)
		if touch_event.pressed:
			_handle_press_at(pointer_position)
		else:
			_handle_release_at(pointer_position)
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_handle_motion_at(_screen_position_to_global(drag_event.position))


func _load_item_textures() -> void:
	_item_textures.clear()

	var config := _load_json_file(ITEM_SPRITES_CONFIG)
	var items := config.get("items", []) as Array
	for item_data in items:
		var item_config := item_data as Dictionary
		if item_config == null:
			continue

		var item_id := str(item_config.get("id", ""))
		var texture_path := str(item_config.get("texture", ""))
		if item_id.is_empty() or texture_path.is_empty():
			continue

		var texture := load(texture_path) as Texture2D
		if texture != null:
			_item_textures[item_id] = texture


func _load_level_config(level_number: int) -> Dictionary:
	var level_config_path := LEVEL_CONFIG_TEMPLATE % level_number
	if not FileAccess.file_exists(level_config_path):
		push_warning("Missing %s. Using %s." % [level_config_path, DEFAULT_LEVEL_CONFIG])
		level_config_path = DEFAULT_LEVEL_CONFIG

	return _load_json_file(level_config_path)


func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open config: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	var config := parsed as Dictionary
	if config == null:
		push_error("Config is not a JSON object: %s" % path)
		return {}

	return config


func _apply_level_config(config: Dictionary) -> void:
	level_duration_seconds = float(config.get("time_seconds", level_duration_seconds))
	_time_remaining = level_duration_seconds
	_has_player_started_timer = false
	_max_layer_count = 1
	_level_failed = false
	_level_completed = false
	_level_paused = false
	_triples_cleared = 0
	_completion_return_time_remaining = 0.0
	_returning_to_menu = false
	_failure_panel.visible = false
	_completion_panel.visible = false
	if _pause_menu_overlay != null:
		_pause_menu_overlay.visible = false

	_clear_ability_highlights()
	_load_ability_uses()

	var shelves_config := config.get("shelves", []) as Array
	_layout_preset = str(config.get("layout_preset", DEFAULT_LAYOUT_PRESET))
	var shelves := get_node("Shelves") as Node2D
	_clear_shelves(shelves)

	var row_layouts := config.get(ROW_LAYOUTS_KEY, []) as Array
	if row_layouts != null and not row_layouts.is_empty():
		_add_row_layout_shelves(shelves, shelves_config, row_layouts)
	else:
		_add_preset_layout_shelves(shelves, shelves_config)

	_apply_responsive_layout()
	_set_moving_shelf_rows_paused(false)
	_update_locked_shelves()
	_resolve_shelves(_get_all_shelves())
	_check_level_completed()
	_update_pause_menu_button()


func _clear_shelves(shelves: Node) -> void:
	for child in shelves.get_children():
		shelves.remove_child(child)
		child.free()


func _add_preset_layout_shelves(shelves: Node2D, shelves_config: Array) -> void:
	if _add_layout_template_shelves(shelves, shelves_config, _layout_preset):
		return

	push_warning("Layout preset '%s' has no compatible template scene. Using %s." % [_layout_preset, DEFAULT_LAYOUT_PRESET])
	var shelf_positions := _get_grid_layout_positions(3, shelves_config.size())
	for shelf_index in range(shelves_config.size()):
		var shelf_config := shelves_config[shelf_index] as Dictionary
		if shelf_config == null:
			continue

		var shelf := _add_shelf(shelves, shelf_index + 1, shelf_positions[shelf_index])
		_configure_shelf_from_config(shelf, shelf_config)


func _add_row_layout_shelves(shelves: Node2D, shelves_config: Array, row_layouts: Array) -> void:
	var configured_shelf_count := _get_row_layout_shelf_count(row_layouts)
	if configured_shelf_count != shelves_config.size():
		push_warning(
			"%s shelf_count total must match shelves size. Using %s."
			% [ROW_LAYOUTS_KEY, DEFAULT_LAYOUT_PRESET]
		)
		_add_preset_layout_shelves(shelves, shelves_config)
		return

	var row_origin_y := -float(row_layouts.size() - 1) * SHELF_GRID_STEP.y * 0.5
	var shelf_config_index := 0
	for row_index in range(row_layouts.size()):
		var row_config := row_layouts[row_index] as Dictionary
		if row_config == null:
			continue

		var row_shelf_count := int(row_config.get("shelf_count", 0))
		var row_center_y := row_origin_y + float(row_index) * SHELF_GRID_STEP.y
		var is_moving := _is_row_layout_moving(row_config)
		var visible_count := _get_row_visible_count(row_config, row_shelf_count, is_moving)
		var visual_variant := _get_row_visual_variant(row_config, is_moving)

		if is_moving:
			_add_moving_shelf_row(
				shelves,
				shelves_config,
				shelf_config_index,
				row_shelf_count,
				visible_count,
				Vector2(0.0, row_center_y),
				row_config,
				visual_variant
			)
		else:
			_add_static_shelf_row(
				shelves,
				shelves_config,
				shelf_config_index,
				row_shelf_count,
				row_center_y,
				visual_variant
			)

		shelf_config_index += row_shelf_count


func _get_row_layout_shelf_count(row_layouts: Array) -> int:
	var shelf_count := 0
	for row_layout in row_layouts:
		var row_config := row_layout as Dictionary
		if row_config == null:
			return -1

		var row_shelf_count := int(row_config.get("shelf_count", 0))
		if row_shelf_count <= 0:
			return -1

		shelf_count += row_shelf_count

	return shelf_count


func _add_static_shelf_row(
	shelves: Node2D,
	shelves_config: Array,
	start_shelf_index: int,
	row_shelf_count: int,
	row_center_y: float,
	visual_variant: String
) -> void:
	var row_origin_x := -float(row_shelf_count - 1) * SHELF_GRID_STEP.x * 0.5
	for row_shelf_index in range(row_shelf_count):
		var shelf_config := shelves_config[start_shelf_index + row_shelf_index] as Dictionary
		if shelf_config == null:
			continue

		var shelf_number := start_shelf_index + row_shelf_index + 1
		var shelf_position := Vector2(row_origin_x + float(row_shelf_index) * SHELF_GRID_STEP.x, row_center_y)
		var shelf := _add_shelf(shelves, shelf_number, shelf_position)
		_apply_shelf_visual_variant(shelf, visual_variant)
		_configure_shelf_from_config(shelf, shelf_config)


func _add_moving_shelf_row(
	shelves: Node2D,
	shelves_config: Array,
	start_shelf_index: int,
	row_shelf_count: int,
	visible_count: int,
	row_center_position: Vector2,
	row_config: Dictionary,
	visual_variant: String
) -> void:
	var row := MOVING_SHELF_ROW_SCENE.instantiate() as MovingShelfRow
	row.name = "MovingShelfRow%02d" % (start_shelf_index + 1)
	row.configure(
		visible_count,
		SHELF_GRID_STEP.x,
		SHELF_CELL_SIZE,
		_get_row_motion_speed(row_config),
		_get_row_motion_direction(row_config)
	)
	var visible_size := row.get_visible_size()
	row.position = row_center_position - visible_size * 0.5
	shelves.add_child(row)

	for row_shelf_index in range(row_shelf_count):
		var shelf_config := shelves_config[start_shelf_index + row_shelf_index] as Dictionary
		if shelf_config == null:
			continue

		var shelf_number := start_shelf_index + row_shelf_index + 1
		var shelf := _add_shelf(row, shelf_number, Vector2.ZERO)
		row.add_shelf(shelf)
		_apply_shelf_visual_variant(shelf, visual_variant)
		_configure_shelf_from_config(shelf, shelf_config, false)


func _configure_shelf_from_config(shelf: Node2D, shelf_config: Dictionary, allow_locked := true) -> void:
	var layers := shelf_config.get("layers", []) as Array
	_max_layer_count = maxi(_max_layer_count, layers.size())
	_add_configured_layers(shelf, layers)
	_configure_shelf_unlock(shelf, shelf_config, allow_locked)


func _is_row_layout_moving(row_config: Dictionary) -> bool:
	var motion := _get_row_motion_config(row_config)
	var motion_type := str(motion.get("type", "")).to_lower()
	if motion_type == ROW_MOTION_HORIZONTAL_WRAP:
		return true

	if row_config.has("moving"):
		return bool(row_config.get("moving", false))

	return _get_row_motion_speed(row_config) > 0.0


func _get_row_motion_config(row_config: Dictionary) -> Dictionary:
	var motion := row_config.get("motion", {}) as Dictionary
	return {} if motion == null else motion


func _get_row_motion_speed(row_config: Dictionary) -> float:
	var motion := _get_row_motion_config(row_config)
	return maxf(float(motion.get("speed", row_config.get("speed", 0.0))), 0.0)


func _get_row_motion_direction(row_config: Dictionary) -> int:
	var motion := _get_row_motion_config(row_config)
	var direction_name := str(motion.get("direction", row_config.get("direction", "right"))).to_lower()
	return -1 if direction_name == "left" else 1


func _get_row_visible_count(row_config: Dictionary, row_shelf_count: int, is_moving: bool) -> int:
	var default_visible_count := mini(3, row_shelf_count) if is_moving else row_shelf_count
	var visible_count := int(row_config.get("visible_count", default_visible_count))
	return clampi(visible_count, 1, row_shelf_count)


func _get_row_visual_variant(row_config: Dictionary, is_moving: bool) -> String:
	var default_variant := SHELF_VISUAL_VARIANT_FLOOR_ONLY if is_moving else SHELF_VISUAL_VARIANT_FULL
	return str(row_config.get("visual_variant", default_variant)).to_lower()


func _add_layout_template_shelves(shelves: Node2D, shelves_config: Array, layout_preset: String) -> bool:
	var layout_scene_path := _get_layout_scene_path(layout_preset)
	if not ResourceLoader.exists(layout_scene_path):
		return false

	var layout_scene := load(layout_scene_path) as PackedScene
	if layout_scene == null:
		push_warning("Layout preset '%s' could not load from %s. Using %s." % [layout_preset, layout_scene_path, DEFAULT_LAYOUT_PRESET])
		return false

	var layout_template := layout_scene.instantiate() as Node2D
	if layout_template == null:
		push_warning("Layout preset '%s' is not a Node2D scene. Using %s." % [layout_preset, DEFAULT_LAYOUT_PRESET])
		return false

	var template_shelf_count := _get_layout_template_shelf_count(layout_template)
	if template_shelf_count != shelves_config.size():
		push_warning(
			"Layout preset '%s' expects %s shelves, got %s. Using %s."
			% [layout_preset, template_shelf_count, shelves_config.size(), DEFAULT_LAYOUT_PRESET]
		)
		layout_template.queue_free()
		return false

	var shelf_config_index := 0
	for layout_node in layout_template.get_children():
		if layout_node is ShelfLayoutRow:
			var layout_row := layout_node as ShelfLayoutRow
			var row_shelf_count := layout_row.shelf_count
			var visible_count := clampi(layout_row.visible_count, 1, row_shelf_count)
			var row_config := layout_row.to_row_config()
			var visual_variant := _get_row_visual_variant(row_config, true)
			_add_moving_shelf_row(
				shelves,
				shelves_config,
				shelf_config_index,
				row_shelf_count,
				visible_count,
				layout_row.global_position,
				row_config,
				visual_variant
			)
			shelf_config_index += row_shelf_count
		elif _is_layout_shelf_marker(layout_node):
			var shelf_config := shelves_config[shelf_config_index] as Dictionary
			if shelf_config != null:
				var shelf_marker := layout_node as Node2D
				var shelf := _add_shelf(shelves, shelf_config_index + 1, shelf_marker.global_position)
				_configure_shelf_from_config(shelf, shelf_config)

			shelf_config_index += 1

	layout_template.queue_free()
	return true


func _get_layout_scene_path(layout_preset: String) -> String:
	return LAYOUT_SCENE_TEMPLATE % layout_preset


func _get_layout_template_shelf_count(layout_template: Node2D) -> int:
	var shelf_count := 0
	for layout_node in layout_template.get_children():
		if layout_node is ShelfLayoutRow:
			var layout_row := layout_node as ShelfLayoutRow
			if layout_row.shelf_count <= 0:
				return -1

			shelf_count += layout_row.shelf_count
		elif _is_layout_shelf_marker(layout_node):
			shelf_count += 1

	return shelf_count


func _is_layout_shelf_marker(layout_node: Node) -> bool:
	return layout_node is Marker2D and str(layout_node.name).begins_with("Shelf")


func _apply_shelf_visual_variant(shelf: Node2D, visual_variant: String) -> void:
	match visual_variant:
		SHELF_VISUAL_VARIANT_FULL:
			return
		SHELF_VISUAL_VARIANT_FLOOR_ONLY:
			for node_name in SHELF_FLOOR_ONLY_HIDDEN_NODES:
				var node := shelf.get_node_or_null(node_name) as CanvasItem
				if node != null:
					node.visible = false
		_:
			push_warning("Unknown shelf visual_variant '%s'. Using full shelf." % visual_variant)


func _get_grid_layout_positions(columns: int, shelf_count: int) -> Array[Vector2]:
	var spacing := SHELF_GRID_STEP

	var rows := ceili(float(shelf_count) / float(columns))
	var origin := Vector2(
		-(columns - 1) * spacing.x * 0.5,
		-(rows - 1) * spacing.y * 0.5
	)
	var positions: Array[Vector2] = []
	for shelf_index in range(shelf_count):
		var column := shelf_index % columns
		var row := floori(float(shelf_index) / float(columns))
		positions.append(origin + Vector2(column * spacing.x, row * spacing.y))

	return positions


func _add_shelf(parent: Node, shelf_number: int, shelf_position: Vector2) -> Node2D:
	var shelf := SHELF_SCENE.instantiate() as Node2D
	shelf.name = "Shelf%02d" % shelf_number
	shelf.position = shelf_position
	parent.add_child(shelf)

	return shelf


func _add_configured_layers(shelf: Node2D, layers: Array) -> void:
	for layer_index in range(layers.size()):
		var item_ids := layers[layer_index] as Array
		if item_ids == null:
			push_warning("%s layer %s is not an array." % [shelf.name, layer_index + 1])
			continue

		if item_ids.size() != SLOT_COUNT:
			push_warning("%s layer %s expected %s slots, found %s." % [shelf.name, layer_index + 1, SLOT_COUNT, item_ids.size()])

		var layer_slots := _get_front_slots(shelf) if layer_index == 0 else _add_back_layer(shelf, layer_index)
		var fill_count = mini(SLOT_COUNT, item_ids.size())
		for slot_index in range(fill_count):
			_add_configured_item(layer_slots[slot_index], item_ids[slot_index], layer_index, slot_index)


func _configure_shelf_unlock(shelf: Node2D, shelf_config: Dictionary, allow_locked := true) -> void:
	var unlock_after_triples := maxi(int(shelf_config.get("unlock_after_triples", 0)), 0)
	if unlock_after_triples > 0 and not allow_locked:
		push_warning("%s is in a moving row. Locked moving shelves are not allowed." % shelf.name)
		unlock_after_triples = 0

	shelf.set_meta(SHELF_UNLOCK_REQUIREMENT_META, unlock_after_triples)
	shelf.set_meta(SHELF_LOCKED_META, false)


func _record_triples_cleared(triple_count: int) -> void:
	if triple_count <= 0:
		return

	_triples_cleared += triple_count
	var newly_unlocked_shelves := _update_locked_shelves()
	_queue_shelves_to_resolve(newly_unlocked_shelves)


func _update_locked_shelves() -> Array[Node]:
	var newly_unlocked_shelves: Array[Node] = []
	for shelf in _get_all_shelves():
		var shelf_node := shelf as Node2D
		if shelf_node == null:
			continue

		var was_locked := _is_shelf_locked(shelf_node)
		var should_lock := _get_shelf_unlock_requirement(shelf_node) > _triples_cleared
		shelf_node.set_meta(SHELF_LOCKED_META, should_lock)
		_update_shelf_lock_overlay(shelf_node, should_lock)
		_update_shelf_input_pickable(shelf_node, not should_lock)

		if was_locked and not should_lock:
			newly_unlocked_shelves.append(shelf_node)

	return newly_unlocked_shelves


func _get_shelf_unlock_requirement(shelf: Node) -> int:
	if shelf == null:
		return 0

	return maxi(int(shelf.get_meta(SHELF_UNLOCK_REQUIREMENT_META, 0)), 0)


func _is_shelf_locked(shelf: Node) -> bool:
	return shelf != null and bool(shelf.get_meta(SHELF_LOCKED_META, false))


func _is_slot_locked(slot: Node) -> bool:
	return _is_shelf_locked(_get_owning_shelf(slot))


func _is_slot_drag_drop_targetable(slot: Node) -> bool:
	return slot != null and _is_shelf_drag_drop_targetable(_get_owning_shelf(slot))


func _is_shelf_drag_drop_targetable(shelf: Node) -> bool:
	var shelf_node := shelf as Node2D
	if shelf_node == null:
		return false

	if _is_shelf_locked(shelf_node):
		return false

	var moving_row := _get_moving_shelf_row(shelf_node)
	return moving_row == null or moving_row.is_shelf_inside_visible_window(shelf_node)


func _get_moving_shelf_row(node: Node) -> MovingShelfRow:
	var current := node.get_parent()
	while current != null:
		var moving_row := current as MovingShelfRow
		if moving_row != null:
			return moving_row

		current = current.get_parent()

	return null


func _clear_drag_drop_selection_if_unavailable() -> void:
	if _selected_slot != null and not _is_slot_drag_drop_targetable(_selected_slot):
		_clear_selected_item()

	if _pressed_origin_slot != null and not _is_slot_drag_drop_targetable(_pressed_origin_slot):
		_pressed_item = null
		_pressed_origin_slot = null


func _update_shelf_lock_overlay(shelf: Node2D, should_lock: bool) -> void:
	var overlay := shelf.get_node_or_null(LOCKED_OVERLAY_NAME) as Node2D
	if overlay == null:
		return

	overlay.visible = should_lock
	if not should_lock:
		return

	var remaining := maxi(_get_shelf_unlock_requirement(shelf) - _triples_cleared, 0)
	var count_label := overlay.get_node_or_null(LOCK_REMAINING_LABEL_NAME) as Label
	if count_label != null:
		_update_lock_remaining_label(count_label, remaining)


func _update_lock_remaining_label(count_label: Label, remaining: int) -> void:
	var remaining_text := str(remaining)
	count_label.text = remaining_text

	var font_size := 34
	if remaining_text.length() >= 3:
		font_size = 24
	elif remaining_text.length() == 2:
		font_size = 30

	count_label.add_theme_font_size_override("font_size", font_size)


func _update_shelf_input_pickable(shelf: Node, should_enable: bool) -> void:
	for item in _get_shelf_items(shelf):
		if item == null or not is_instance_valid(item):
			continue

		item.input_pickable = should_enable and not _is_item_busy(item)


func _add_back_layer(shelf: Node2D, layer_index: int) -> Array[Node2D]:
	var layer := Node2D.new()
	layer.name = _get_back_layer_name(layer_index)
	layer.z_index = 4
	layer.visible = layer_index == FIRST_BACK_LAYER_INDEX
	shelf.add_child(layer)

	var layer_slots: Array[Node2D] = []
	for front_slot in _get_front_slots(shelf):
		layer_slots.append(_add_layer_slot(layer, front_slot))

	return layer_slots


func _add_configured_item(slot: Node2D, item_value, layer_index: int, slot_index: int) -> void:
	if item_value == null:
		return

	var item_id := str(item_value)
	if item_id.is_empty():
		return

	var item := ITEM_SCENE.instantiate() as ShelfItem
	item.name = "Item%sL%sS%s" % [item_id.to_pascal_case(), layer_index + 1, slot_index + 1]
	item.item_id = StringName(item_id)
	item.texture = _item_textures.get(item_id)
	if item.texture == null:
		push_warning("No texture configured for item '%s'." % item_id)

	item.position = SLOT_ITEM_POSITION
	slot.add_child(item)

	if layer_index > 0:
		_configure_back_layer_item(item, layer_index == FIRST_BACK_LAYER_INDEX)


func _collect_slots() -> void:
	_slots.clear()

	for shelf in _get_all_shelves():
		for slot in _get_front_slots(shelf):
			_slots.append(slot)


func _get_back_layer_name(layer_index: int) -> String:
	return "%s%02d" % [BACK_LAYER_PREFIX, layer_index + 1]


func _get_front_slots(shelf: Node) -> Array[Node2D]:
	var front_slots: Array[Node2D] = []
	for child in shelf.get_children():
		var slot := child as Node2D
		if slot != null and slot.name.begins_with("Slot"):
			front_slots.append(slot)

	return front_slots


func _add_layer_slot(layer: Node2D, front_slot: Node2D) -> Node2D:
	var layer_slot := Node2D.new()
	layer_slot.name = "Layer%s" % front_slot.name
	layer_slot.position = front_slot.position + back_layer_offset
	layer.add_child(layer_slot)

	return layer_slot


func _configure_back_layer_item(item: ShelfItem, should_show: bool) -> void:
	item.z_index = 0
	item.modulate = back_layer_item_modulate if should_show else Color.TRANSPARENT
	item.input_pickable = false
	item.visual_scale *= back_layer_item_scale

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true


func _update_timer_label() -> void:
	var remaining_seconds := ceili(_time_remaining)
	var minutes := floori(float(remaining_seconds) / 60.0)
	var seconds := remaining_seconds % 60
	_timer_label.text = "%02d:%02d" % [minutes, seconds]


func _update_level_label() -> void:
	_level_label.text = "Level %d" % selected_level


func _start_level_timer_from_player_action() -> void:
	if _has_player_started_timer:
		return

	_has_player_started_timer = true


func _fail_level() -> void:
	_level_failed = true
	_level_paused = false
	_clear_selected_item()
	_set_moving_shelf_rows_paused(true)
	_update_ability_buttons()
	_update_pause_menu_button()

	if _dragged_item != null and _origin_slot != null:
		_place_item_in_slot(_dragged_item, _origin_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	_pressed_item = null
	_pressed_origin_slot = null
	_failure_panel.visible = true
	_pause_menu_overlay.visible = false


func _complete_level() -> void:
	_level_completed = true
	_level_paused = false
	_completion_return_time_remaining = maxf(completion_return_delay_seconds, 0.0)
	if not launched_from_dev_mode:
		PlayerProgress.complete_level(selected_level)
	_clear_selected_item()
	_set_moving_shelf_rows_paused(true)
	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	_pressed_item = null
	_pressed_origin_slot = null
	_clear_ability_highlights()
	_update_ability_buttons()
	_update_pause_menu_button()
	_completion_panel.visible = true
	_pause_menu_overlay.visible = false


func _check_level_completed() -> void:
	if _level_failed or _level_completed:
		return

	if _get_all_items().is_empty():
		_complete_level()


func _return_to_main_menu() -> void:
	_level_paused = false
	_returning_to_menu = true
	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		_returning_to_menu = false
		push_error("Could not return to main menu: %s" % MAIN_MENU_SCENE)


func _advance_after_completion() -> void:
	if launched_from_dev_mode:
		_return_to_main_menu()
		return

	var next_level := selected_level + 1
	if not _level_config_exists(next_level):
		_return_to_main_menu()
		return

	_change_to_level(next_level, false)


func _change_to_level(level_number: int, dev_mode: bool) -> void:
	_level_paused = false
	_returning_to_menu = true
	var level_scene_resource := load(LEVEL_SCENE_PATH) as PackedScene
	if level_scene_resource == null:
		_returning_to_menu = false
		push_error("Could not load level scene: %s" % LEVEL_SCENE_PATH)
		return

	var level_scene := level_scene_resource.instantiate()
	level_scene.selected_level = level_number
	level_scene.launched_from_dev_mode = dev_mode

	var tree := get_tree()
	var current_scene := tree.current_scene
	tree.root.add_child(level_scene)
	tree.current_scene = level_scene

	if current_scene != null:
		current_scene.queue_free()


func _level_config_exists(level_number: int) -> bool:
	return FileAccess.file_exists(LEVEL_CONFIG_TEMPLATE % level_number)


func _setup_pause_menu_buttons() -> void:
	_pause_menu_button.pressed.connect(_on_pause_menu_button_pressed)
	_leave_button.pressed.connect(_on_pause_menu_leave_pressed)
	_continue_button.pressed.connect(_on_pause_menu_continue_pressed)
	if _pause_menu_overlay.has_signal(&"setting_toggled"):
		_pause_menu_overlay.connect(&"setting_toggled", _on_pause_menu_setting_toggled)


func _on_pause_menu_setting_toggled(setting_id: StringName, is_disabled: bool) -> void:
	if setting_id != PAUSE_SETTING_SOUND_EFFECTS:
		return

	_sound_effects_enabled = not is_disabled
	if not _sound_effects_enabled:
		_stop_sound_effects()


func _on_pause_menu_button_pressed() -> void:
	if _level_failed or _level_completed:
		return

	_open_pause_menu()


func _open_pause_menu() -> void:
	_cancel_active_interaction()
	_level_paused = true
	_set_moving_shelf_rows_paused(true)
	_pause_menu_overlay.visible = true
	_update_ability_buttons()
	_update_pause_menu_button()


func _on_pause_menu_leave_pressed() -> void:
	_return_to_main_menu()


func _on_pause_menu_continue_pressed() -> void:
	_close_pause_menu()


func _close_pause_menu() -> void:
	_level_paused = false
	_set_moving_shelf_rows_paused(false)
	_pause_menu_overlay.visible = false
	_update_ability_buttons()
	_update_pause_menu_button()


func _update_pause_menu_button() -> void:
	if _pause_menu_button == null:
		return

	_pause_menu_button.disabled = _level_failed or _level_completed or _level_paused


func _handle_press_at(pointer_global_position: Vector2) -> void:
	if _dragged_item != null:
		return

	var clicked_item := _find_item_at_position(pointer_global_position)
	if _selected_item != null:
		var target_slot := _find_clicked_slot(pointer_global_position, clicked_item)
		if target_slot != null:
			var moved_item := _move_item_to_slot(_selected_item, _selected_slot, target_slot)
			_clear_selected_item()
			if moved_item:
				get_viewport().set_input_as_handled()
				return
		else:
			_clear_selected_item()

	if clicked_item == null:
		return

	_start_level_timer_from_player_action()
	_pressed_item = clicked_item
	_pressed_origin_slot = clicked_item.get_parent() as Node2D
	_press_position = pointer_global_position
	get_viewport().set_input_as_handled()


func _handle_motion_at(pointer_global_position: Vector2) -> void:
	if _dragged_item != null:
		_move_active_drag(pointer_global_position)
		return

	if _pressed_item == null:
		return

	if not _is_slot_drag_drop_targetable(_pressed_origin_slot):
		_pressed_item = null
		_pressed_origin_slot = null
		return

	if pointer_global_position.distance_to(_press_position) < drag_start_distance:
		return

	_clear_selected_item()
	_begin_drag(_pressed_item, pointer_global_position)
	get_viewport().set_input_as_handled()


func _handle_release_at(pointer_global_position: Vector2) -> void:
	if _dragged_item != null:
		_finish_active_drag(pointer_global_position)
		_pressed_item = null
		_pressed_origin_slot = null
		return

	if _pressed_item == null:
		return

	if _pressed_item.get_parent() == _pressed_origin_slot and _is_slot_drag_drop_targetable(_pressed_origin_slot):
		_set_selected_item(_pressed_item, _pressed_origin_slot)

	_pressed_item = null
	_pressed_origin_slot = null
	get_viewport().set_input_as_handled()


func _begin_drag(item: ShelfItem, pointer_global_position: Vector2) -> void:
	var origin_slot := item.get_parent() as Node2D
	if not _is_slot_drag_drop_targetable(origin_slot):
		return

	_dragged_item = item
	_origin_slot = origin_slot
	_drag_offset = item.global_position - pointer_global_position
	item.reparent(_drag_layer, true)
	item.z_index = 100
	item.global_position = pointer_global_position + _drag_offset


func _move_active_drag(pointer_global_position: Vector2) -> void:
	if _dragged_item == null:
		return

	_dragged_item.global_position = pointer_global_position + _drag_offset
	get_viewport().set_input_as_handled()


func _finish_active_drag(pointer_global_position: Vector2) -> void:
	if _dragged_item == null:
		return

	var item := _dragged_item
	var origin_slot := _origin_slot
	var target_slot := _find_nearest_slot(pointer_global_position)
	if target_slot == null:
		_return_item_to_origin_after_animation(item, origin_slot)
	elif target_slot == origin_slot:
		_return_item_to_origin_after_animation(item, origin_slot)
	else:
		if not _move_item_to_slot(item, origin_slot, target_slot):
			_return_item_to_origin_after_animation(item, origin_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	get_viewport().set_input_as_handled()


func _move_item_to_slot(item: ShelfItem, origin_slot: Node2D, target_slot: Node2D) -> bool:
	if item == null or origin_slot == null or target_slot == null:
		return false

	if _is_slot_locked(origin_slot) or not _is_slot_drag_drop_targetable(target_slot):
		return false

	target_slot = _resolve_move_target_slot(origin_slot, target_slot)
	if target_slot == null:
		return false

	if target_slot == origin_slot:
		_place_item_in_slot(item, origin_slot, true)
		return true

	var shelves_to_check: Array[Node] = []
	_add_shelf_to_check(shelves_to_check, origin_slot)
	_add_shelf_to_check(shelves_to_check, target_slot)

	_move_item_to_slot_after_animation(item, target_slot, shelves_to_check)
	return true


func _find_item_at_position(pointer_global_position: Vector2) -> ShelfItem:
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if not _is_slot_drag_drop_targetable(slot):
			continue

		var item := _get_slot_item(slot)
		if item == null or _is_item_busy(item):
			continue

		var scaled_pick_size := item_pick_size * _shelves_layout_scale
		var item_rect := Rect2(item.global_position - scaled_pick_size * 0.5, scaled_pick_size)
		if item_rect.has_point(pointer_global_position):
			return item

	return null


func _find_clicked_slot(pointer_global_position: Vector2, clicked_item: ShelfItem) -> Node2D:
	if clicked_item != null:
		return clicked_item.get_parent() as Node2D

	return _find_nearest_empty_slot(pointer_global_position)


func _find_nearest_slot(pointer_global_position: Vector2) -> Node2D:
	var nearest_slot: Node2D
	var nearest_distance := _get_scaled_slot_snap_distance()

	for slot in _slots:
		if not _is_slot_drag_drop_targetable(slot):
			continue

		var marker := _get_slot_marker(slot)
		if marker == null:
			continue

		var distance := pointer_global_position.distance_to(marker.global_position)
		if distance <= nearest_distance:
			nearest_slot = slot
			nearest_distance = distance

	return nearest_slot


func _find_nearest_empty_slot(pointer_global_position: Vector2) -> Node2D:
	var nearest_slot: Node2D
	var nearest_distance := _get_scaled_slot_snap_distance()

	for slot in _slots:
		if not _is_slot_drag_drop_targetable(slot):
			continue

		if _get_slot_item(slot) != null:
			continue

		var marker := _get_slot_marker(slot)
		if marker == null:
			continue

		var distance := pointer_global_position.distance_to(marker.global_position)
		if distance <= nearest_distance:
			nearest_slot = slot
			nearest_distance = distance

	return nearest_slot


func _get_scaled_slot_snap_distance() -> float:
	return slot_snap_distance * _shelves_layout_scale


func _resolve_move_target_slot(origin_slot: Node2D, target_slot: Node2D) -> Node2D:
	if _is_slot_locked(origin_slot) or not _is_slot_drag_drop_targetable(target_slot):
		return null

	if target_slot == origin_slot:
		return target_slot

	if _get_slot_item(target_slot) == null:
		return target_slot

	if _get_owning_shelf(origin_slot) == _get_owning_shelf(target_slot):
		return origin_slot

	return _find_free_slot_on_target_shelf(target_slot, origin_slot)


func _find_free_slot_on_target_shelf(target_slot: Node2D, excluded_slot: Node2D) -> Node2D:
	var target_shelf := _get_owning_shelf(target_slot)
	if target_shelf == null:
		return null

	if not _is_shelf_drag_drop_targetable(target_shelf):
		return null

	var target_marker := _get_slot_marker(target_slot)
	if target_marker == null:
		return null

	var nearest_slot: Node2D
	var nearest_distance := INF
	for shelf_slot in _get_front_slots(target_shelf):
		if shelf_slot == excluded_slot or _get_slot_item(shelf_slot) != null:
			continue

		var marker := _get_slot_marker(shelf_slot)
		if marker == null:
			continue

		var distance := target_marker.global_position.distance_to(marker.global_position)
		if distance < nearest_distance:
			nearest_slot = shelf_slot
			nearest_distance = distance

	return nearest_slot


func _get_slot_marker(slot: Node2D) -> Marker2D:
	return slot.get_node_or_null("ItemSlot%s" % slot.name.trim_prefix("Slot")) as Marker2D


func _get_slot_item(slot: Node2D) -> ShelfItem:
	for child in slot.get_children():
		var item := child as ShelfItem
		if item != null and not item.is_queued_for_deletion():
			return item

	return null


func _place_item_in_slot(item: ShelfItem, slot: Node2D, should_play_sound := false) -> void:
	item.reparent(slot, true)
	item.position = SLOT_ITEM_POSITION
	item.z_index = 6
	_apply_item_visual_state(item)
	if should_play_sound:
		_play_item_place_sound()


func _move_item_to_slot_after_animation(item: ShelfItem, target_slot: Node2D, shelves_to_check: Array[Node]) -> void:
	await _play_item_move_animation(item, target_slot)
	_resolve_shelves(shelves_to_check)


func _return_item_to_origin_after_animation(item: ShelfItem, origin_slot: Node2D) -> void:
	await _play_item_move_animation(item, origin_slot)


func _play_item_move_animation(item: ShelfItem, target_slot: Node2D) -> void:
	if item == null or target_slot == null or not is_instance_valid(item):
		return

	var duration := maxf(item_move_duration_seconds, 0.0)
	item.reparent(target_slot, true)
	item.z_index = 9
	item.input_pickable = false
	_mark_item_transitioning_by_id(item.get_instance_id())

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true

	if duration > 0.0:
		var move_tween := create_tween()
		move_tween.tween_property(
			item,
			"position",
			SLOT_ITEM_POSITION,
			duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await move_tween.finished

	if item == null or not is_instance_valid(item):
		return

	item.position = SLOT_ITEM_POSITION
	item.z_index = 6
	item.input_pickable = true
	_unmark_item_transitioning_by_id(item.get_instance_id())

	collision = item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = false

	_apply_item_visual_state(item)
	_play_item_place_sound()


func _add_shelf_to_check(shelves_to_check: Array[Node], slot: Node2D) -> void:
	var shelf := _get_owning_shelf(slot)
	if shelf != null and not shelves_to_check.has(shelf):
		shelves_to_check.append(shelf)


func _resolve_shelves(shelves_to_check: Array[Node]) -> void:
	_queue_shelves_to_resolve(shelves_to_check)
	if _is_resolving_shelves:
		return

	_is_resolving_shelves = true
	while not _shelves_pending_resolve.is_empty():
		var active_shelves := _shelves_pending_resolve.duplicate()
		_shelves_pending_resolve.clear()

		while true:
			var cleared := await _clear_matching_shelves(active_shelves)
			var promoted := await _promote_empty_front_layers(active_shelves)
			if not cleared and not promoted:
				break

	_is_resolving_shelves = false
	_refresh_ability_highlights()
	_check_level_completed()
	_update_ability_buttons()


func _queue_shelves_to_resolve(shelves_to_check: Array[Node]) -> void:
	for shelf in shelves_to_check:
		if shelf != null and is_instance_valid(shelf) and not _shelves_pending_resolve.has(shelf):
			_shelves_pending_resolve.append(shelf)


func _clear_matching_shelves(shelves_to_check: Array[Node]) -> bool:
	var cleared_any := false

	for shelf in shelves_to_check:
		if _is_shelf_locked(shelf):
			continue

		var shelf_items := _get_shelf_items(shelf)
		if shelf_items.size() != 3:
			continue

		var item_id := shelf_items[0].item_id
		if item_id == &"":
			continue

		if shelf_items.all(func(item: ShelfItem) -> bool: return item.item_id == item_id):
			cleared_any = true

			if shelf_items.has(_selected_item):
				_clear_selected_item()

			for item in shelf_items:
				_highlighted_items.erase(item)

			await _play_match_clear_animation(shelf_items)
			_record_triples_cleared(1)

	return cleared_any


func _play_match_clear_animation(shelf_items: Array[ShelfItem]) -> void:
	if shelf_items.size() != SLOT_COUNT:
		return

	var center_item := shelf_items[1]
	if center_item == null or not is_instance_valid(center_item):
		for item in shelf_items:
			if item != null and is_instance_valid(item):
				item.queue_free()
		return

	var clearing_item_ids: Array[int] = []
	var center_position := center_item.global_position
	for item in shelf_items:
		if item == null or not is_instance_valid(item):
			continue

		var item_instance_id := item.get_instance_id()
		clearing_item_ids.append(item_instance_id)
		_mark_item_clearing_by_id(item_instance_id)
		item.input_pickable = false
		item.z_index = 20

	center_item.z_index = 21

	var gather_tween := create_tween()
	gather_tween.set_parallel(true)
	for item in shelf_items:
		if item == center_item or item == null or not is_instance_valid(item):
			continue

		gather_tween.tween_property(
			item,
			"global_position",
			center_position,
			match_gather_duration_seconds
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		gather_tween.tween_property(
			item,
			"scale",
			Vector2.ONE * 0.82,
			match_gather_duration_seconds
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await gather_tween.finished
	_play_triple_clear_sound()

	for item in shelf_items:
		if item != center_item and item != null and is_instance_valid(item):
			item.queue_free()

	if center_item == null or not is_instance_valid(center_item):
		for item_instance_id in clearing_item_ids:
			_unmark_item_clearing_by_id(item_instance_id)
		return

	var shrink_tween := create_tween()
	shrink_tween.set_parallel(true)
	shrink_tween.tween_property(
		center_item,
		"scale",
		Vector2.ZERO,
		match_shrink_duration_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	shrink_tween.tween_property(
		center_item,
		"modulate",
		Color(1, 1, 1, 0),
		match_shrink_duration_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await shrink_tween.finished

	if center_item != null and is_instance_valid(center_item):
		center_item.queue_free()

	for item_instance_id in clearing_item_ids:
		_unmark_item_clearing_by_id(item_instance_id)


func _mark_item_clearing_by_id(instance_id: int) -> void:
	if instance_id != 0 and not _clearing_item_ids.has(instance_id):
		_clearing_item_ids.append(instance_id)


func _unmark_item_clearing_by_id(instance_id: int) -> void:
	_clearing_item_ids.erase(instance_id)


func _is_item_clearing(item: ShelfItem) -> bool:
	return item != null and _clearing_item_ids.has(item.get_instance_id())


func _mark_item_transitioning_by_id(instance_id: int) -> void:
	if instance_id != 0 and not _transitioning_item_ids.has(instance_id):
		_transitioning_item_ids.append(instance_id)


func _unmark_item_transitioning_by_id(instance_id: int) -> void:
	_transitioning_item_ids.erase(instance_id)


func _is_item_transitioning(item: ShelfItem) -> bool:
	return item != null and _transitioning_item_ids.has(item.get_instance_id())


func _is_item_busy(item: ShelfItem) -> bool:
	return _is_item_clearing(item) or _is_item_transitioning(item)


func _promote_empty_front_layers(shelves_to_check: Array[Node]) -> bool:
	var promoted_any := false

	for shelf in shelves_to_check:
		var shelf_node := shelf as Node2D
		if shelf_node == null:
			continue

		if _is_shelf_locked(shelf_node):
			continue

		if not _front_layer_is_empty(shelf_node):
			continue

		if await _promote_back_layer(shelf_node):
			promoted_any = true

	return promoted_any


func _front_layer_is_empty(shelf: Node) -> bool:
	for slot in _get_front_slots(shelf):
		if _get_slot_item(slot) != null:
			return false

	return true


func _promote_back_layer(shelf: Node2D) -> bool:
	var next_layer := shelf.get_node_or_null(_get_back_layer_name(FIRST_BACK_LAYER_INDEX)) as Node2D
	if next_layer == null:
		return false

	var promotion_entries: Array[Dictionary] = []
	for front_slot in _get_front_slots(shelf):
		var layer_slot := next_layer.get_node_or_null("Layer%s" % front_slot.name) as Node2D
		if layer_slot == null:
			continue

		var layer_item := _get_slot_item(layer_slot)
		if layer_item == null:
			continue

		promotion_entries.append(_prepare_layer_promotion_item(layer_item, front_slot))

	shelf.remove_child(next_layer)
	next_layer.free()
	_advance_back_layers(shelf)
	await _play_layer_promotion_animation(promotion_entries)
	return true


func _prepare_layer_promotion_item(item: ShelfItem, front_slot: Node2D) -> Dictionary:
	var target_visual_scale := item.visual_scale
	if back_layer_item_scale > 0.0:
		target_visual_scale /= back_layer_item_scale

	item.reparent(front_slot, true)
	item.z_index = 8
	item.input_pickable = false
	_mark_item_transitioning_by_id(item.get_instance_id())

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true

	return {
		"item": item,
		"target_visual_scale": target_visual_scale,
	}


func _play_layer_promotion_animation(promotion_entries: Array[Dictionary]) -> void:
	if promotion_entries.is_empty():
		return

	var duration := maxf(layer_promotion_duration_seconds, 0.0)
	if duration <= 0.0:
		for entry in promotion_entries:
			_finish_layer_promotion_item(entry)
		return

	var promotion_tween := create_tween()
	promotion_tween.set_parallel(true)
	var did_add_tween := false

	for entry in promotion_entries:
		var item := entry.get("item") as ShelfItem
		if item == null or not is_instance_valid(item):
			continue

		var target_visual_scale := float(entry.get("target_visual_scale", item.visual_scale))
		did_add_tween = true
		promotion_tween.tween_property(
			item,
			"position",
			SLOT_ITEM_POSITION,
			duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		promotion_tween.tween_property(
			item,
			"modulate",
			Color.WHITE,
			duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		promotion_tween.tween_property(
			item,
			"visual_scale",
			target_visual_scale,
			duration
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if not did_add_tween:
		for entry in promotion_entries:
			_finish_layer_promotion_item(entry)
		return

	await promotion_tween.finished

	for entry in promotion_entries:
		_finish_layer_promotion_item(entry)


func _finish_layer_promotion_item(entry: Dictionary) -> void:
	var item := entry.get("item") as ShelfItem
	if item == null or not is_instance_valid(item):
		return

	item.position = SLOT_ITEM_POSITION
	item.z_index = 6
	item.modulate = Color.WHITE
	item.visual_scale = float(entry.get("target_visual_scale", item.visual_scale))
	item.input_pickable = true
	_unmark_item_transitioning_by_id(item.get_instance_id())

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = false

	_apply_item_visual_state(item)


func _advance_back_layers(shelf: Node2D) -> void:
	for layer_index in range(FIRST_BACK_LAYER_INDEX + 1, _max_layer_count):
		var layer := shelf.get_node_or_null(_get_back_layer_name(layer_index)) as Node2D
		if layer == null:
			continue

		layer.name = _get_back_layer_name(layer_index - 1)
		_configure_back_layer(layer, layer_index - 1)


func _configure_back_layer(layer: Node2D, layer_index: int) -> void:
	var should_show := layer_index == FIRST_BACK_LAYER_INDEX
	layer.visible = should_show

	for layer_slot in layer.get_children():
		var slot := layer_slot as Node2D
		if slot == null:
			continue

		var item := _get_slot_item(slot)
		if item != null:
			item.modulate = back_layer_item_modulate if should_show else Color.TRANSPARENT


func _get_shelf_items(shelf: Node) -> Array[ShelfItem]:
	var shelf_items: Array[ShelfItem] = []
	for child in shelf.get_children():
		var slot := child as Node2D
		if slot == null or not slot.name.begins_with("Slot"):
			continue

		var item := _get_slot_item(slot)
		if item != null:
			shelf_items.append(item)

	return shelf_items


func _screen_position_to_global(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _set_selected_item(item: ShelfItem, slot: Node2D) -> void:
	_clear_selected_item()
	_selected_item = item
	_selected_slot = slot
	_apply_item_visual_state(item)


func _clear_selected_item() -> void:
	var previous_item := _selected_item

	_selected_item = null
	_selected_slot = null

	if previous_item != null and is_instance_valid(previous_item):
		_apply_item_visual_state(previous_item)


func _apply_item_visual_state(item: ShelfItem) -> void:
	var sprite := item.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	var is_selected := item == _selected_item
	var is_highlighted := _highlighted_items.has(item)
	if is_selected:
		sprite.modulate = Color(1.12, 1.12, 1.12, 1.0)
	else:
		sprite.modulate = Color.WHITE

	var outline_color := selected_highlight_outline_color if is_selected else highlight_outline_color
	item.set_outline(is_highlighted, outline_color, highlight_outline_width)


func _setup_ability_buttons() -> void:
	_register_ability_button(ABILITY_HAMMER, "UI/AbilityBar/HBoxContainer/HammerButton")
	_register_ability_button(ABILITY_SHUFFLE, "UI/AbilityBar/HBoxContainer/ShuffleButton")
	_register_ability_button(ABILITY_HIGHLIGHT, "UI/AbilityBar/HBoxContainer/HighlightButton")
	_highlight_timer_label = get_node_or_null("UI/AbilityBar/HBoxContainer/HighlightButton/TimerLabel") as Label
	_update_highlight_timer_label()


func _register_ability_button(ability_id: StringName, button_path: NodePath) -> void:
	var button := get_node_or_null(button_path) as Button
	if button == null:
		push_warning("Missing ability button: %s" % button_path)
		return

	_ability_buttons[ability_id] = button
	button.pressed.connect(_on_ability_button_pressed.bind(ability_id))


func _on_ability_button_pressed(ability_id: StringName) -> void:
	if _level_failed or _level_completed or int(_ability_uses.get(ability_id, 0)) <= 0:
		return

	_cancel_active_interaction()

	var did_apply := false
	match ability_id:
		ABILITY_HAMMER:
			did_apply = _use_hammer()
		ABILITY_SHUFFLE:
			did_apply = _use_shuffle()
		ABILITY_HIGHLIGHT:
			did_apply = _use_highlight()

	if not did_apply:
		return

	_start_level_timer_from_player_action()
	_spend_ability_use(ability_id)
	_update_ability_buttons()


func _cancel_active_interaction() -> void:
	_clear_selected_item()

	if _dragged_item != null and _origin_slot != null:
		_place_item_in_slot(_dragged_item, _origin_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	_pressed_item = null
	_pressed_origin_slot = null


func _use_hammer() -> bool:
	var visible_items := _get_visible_items()
	var items_to_destroy := _find_hammer_targets(visible_items)
	if items_to_destroy.is_empty():
		items_to_destroy = _find_hammer_supplemented_targets(visible_items, _get_first_back_layer_items())

	if items_to_destroy.is_empty():
		return false

	_destroy_items(items_to_destroy)
	return true


func _find_hammer_targets(items: Array[ShelfItem]) -> Array[ShelfItem]:
	var items_by_type := _group_hammer_items_by_type(items)
	var candidate_ids: Array[StringName] = []
	for item_id in items_by_type.keys():
		var typed_items := items_by_type[item_id] as Array
		if typed_items.size() >= SLOT_COUNT:
			candidate_ids.append(item_id)

	if candidate_ids.is_empty():
		return []

	var chosen_id := candidate_ids[_rng.randi_range(0, candidate_ids.size() - 1)]
	var chosen_items := items_by_type[chosen_id] as Array
	_shuffle_array(chosen_items)

	var items_to_destroy: Array[ShelfItem] = []
	for item_index in range(SLOT_COUNT):
		var item := chosen_items[item_index] as ShelfItem
		if item != null:
			items_to_destroy.append(item)

	return items_to_destroy


func _find_hammer_supplemented_targets(
	front_items: Array[ShelfItem],
	back_layer_items: Array[ShelfItem]
) -> Array[ShelfItem]:
	var front_items_by_type := _group_hammer_items_by_type(front_items)
	var back_items_by_type := _group_hammer_items_by_type(back_layer_items)

	var candidate_ids: Array[StringName] = []
	for item_id in front_items_by_type.keys():
		var front_typed_items := front_items_by_type[item_id] as Array
		var back_typed_items := back_items_by_type.get(item_id, []) as Array
		if not front_typed_items.is_empty() and front_typed_items.size() + back_typed_items.size() >= SLOT_COUNT:
			candidate_ids.append(item_id)

	if candidate_ids.is_empty():
		return []

	var chosen_id := candidate_ids[_rng.randi_range(0, candidate_ids.size() - 1)]
	var chosen_front_items := front_items_by_type[chosen_id] as Array
	var chosen_back_items := back_items_by_type.get(chosen_id, []) as Array
	_shuffle_array(chosen_front_items)
	_shuffle_array(chosen_back_items)

	var items_to_destroy: Array[ShelfItem] = []
	var front_item_count = mini(chosen_front_items.size(), SLOT_COUNT)
	for item_index in range(front_item_count):
		var item := chosen_front_items[item_index] as ShelfItem
		if item != null:
			items_to_destroy.append(item)

	var back_items_needed := SLOT_COUNT - items_to_destroy.size()
	for item_index in range(back_items_needed):
		var item := chosen_back_items[item_index] as ShelfItem
		if item != null:
			items_to_destroy.append(item)

	return items_to_destroy


func _group_hammer_items_by_type(items: Array[ShelfItem]) -> Dictionary:
	var items_by_type := {}
	for item in items:
		if item.item_id == &"":
			continue

		if not items_by_type.has(item.item_id):
			items_by_type[item.item_id] = []

		items_by_type[item.item_id].append(item)

	return items_by_type


func _use_shuffle() -> bool:
	var items := _get_unlocked_items()
	if items.size() < 2:
		return false

	var item_ids: Array[StringName] = []
	for item in items:
		item_ids.append(item.item_id)

	_shuffle_array(item_ids)
	for item_index in range(items.size()):
		var item := items[item_index]
		var item_id := item_ids[item_index]
		item.item_id = item_id
		item.texture = _item_textures.get(String(item_id))
		_apply_item_visual_state(item)

	_resolve_shelves(_get_all_shelves())
	return true


func _use_highlight() -> bool:
	var items_to_highlight := _find_immediate_triple_items()
	_clear_ability_highlights()
	_highlighted_items = items_to_highlight
	_highlight_timer = HIGHLIGHT_DURATION_SECONDS
	for item in _highlighted_items:
		_apply_item_visual_state(item)

	_update_highlight_timer_label()
	return true


func _destroy_items(items_to_destroy: Array[ShelfItem]) -> void:
	var shelves_to_check: Array[Node] = []
	var destroyed_count := 0
	for item in items_to_destroy:
		if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
			continue

		var item_slot := item.get_parent() as Node2D
		if item_slot != null:
			_add_shelf_to_check(shelves_to_check, item_slot)

		_highlighted_items.erase(item)
		if item == _selected_item:
			_clear_selected_item()

		item.queue_free()
		destroyed_count += 1

	var destroyed_triples := floori(float(destroyed_count) / float(SLOT_COUNT))
	_record_triples_cleared(destroyed_triples)

	_resolve_shelves(shelves_to_check)


func _find_immediate_triple_items() -> Array[ShelfItem]:
	var visible_counts := {}
	for item in _get_visible_items():
		if not visible_counts.has(item.item_id):
			visible_counts[item.item_id] = 0

		visible_counts[item.item_id] = int(visible_counts[item.item_id]) + 1

	var triplable_ids := {}
	for shelf in _get_all_shelves():
		if _is_shelf_locked(shelf):
			continue

		var shelf_items := _get_shelf_items(shelf)
		if shelf_items.size() != SLOT_COUNT - 1:
			continue

		var first_id := shelf_items[0].item_id
		if first_id == &"" or int(visible_counts.get(first_id, 0)) < SLOT_COUNT:
			continue

		if shelf_items.all(func(item: ShelfItem) -> bool: return item.item_id == first_id):
			triplable_ids[first_id] = true

	if triplable_ids.is_empty():
		return []

	var highlighted: Array[ShelfItem] = []
	for item in _get_visible_items():
		if triplable_ids.has(item.item_id):
			highlighted.append(item)

	return highlighted


func _update_highlight_timer(delta: float) -> void:
	if _highlight_timer <= 0.0:
		return

	_highlight_timer = maxf(_highlight_timer - delta, 0.0)
	_update_highlight_timer_label()
	if _highlight_timer <= 0.0:
		_clear_ability_highlights()


func _refresh_ability_highlights() -> void:
	if _highlight_timer <= 0.0:
		return

	var previous_items := _highlighted_items.duplicate()
	_highlighted_items = _find_immediate_triple_items()
	for item in previous_items:
		if item != null and is_instance_valid(item):
			_apply_item_visual_state(item)

	for item in _highlighted_items:
		if item != null and is_instance_valid(item):
			_apply_item_visual_state(item)


func _clear_ability_highlights() -> void:
	var previous_items := _highlighted_items.duplicate()
	_highlighted_items.clear()
	_highlight_timer = 0.0
	_update_highlight_timer_label()

	for item in previous_items:
		if item != null and is_instance_valid(item):
			_apply_item_visual_state(item)


func _update_highlight_timer_label() -> void:
	if _highlight_timer_label == null:
		return

	var should_show := _highlight_timer > 0.0 and not _level_failed and not _level_completed
	_highlight_timer_label.visible = should_show
	if not should_show:
		return

	_highlight_timer_label.text = "%ds" % ceili(_highlight_timer)


func _update_ability_buttons() -> void:
	_update_ability_button(ABILITY_HAMMER)
	_update_ability_button(ABILITY_SHUFFLE)
	_update_ability_button(ABILITY_HIGHLIGHT)
	_update_highlight_timer_label()


func _reset_ability_uses() -> void:
	_ability_uses = {
		ABILITY_HAMMER: 3,
		ABILITY_SHUFFLE: 3,
		ABILITY_HIGHLIGHT: 3,
	}


func _load_ability_uses() -> void:
	if launched_from_dev_mode:
		_reset_ability_uses()
		return

	var saved_uses := PlayerProgress.get_ability_uses()
	_ability_uses = {
		ABILITY_HAMMER: maxi(int(saved_uses.get(String(ABILITY_HAMMER), 3)), 0),
		ABILITY_SHUFFLE: maxi(int(saved_uses.get(String(ABILITY_SHUFFLE), 3)), 0),
		ABILITY_HIGHLIGHT: maxi(int(saved_uses.get(String(ABILITY_HIGHLIGHT), 3)), 0),
	}


func _spend_ability_use(ability_id: StringName) -> void:
	if launched_from_dev_mode:
		_ability_uses[ability_id] = maxi(int(_ability_uses.get(ability_id, 0)) - 1, 0)
		return

	if not PlayerProgress.spend_ability(ability_id):
		push_warning("Could not spend ability use: %s" % String(ability_id))

	_load_ability_uses()


func _update_ability_button(ability_id: StringName) -> void:
	var button := _ability_buttons.get(ability_id) as Button
	if button == null:
		return

	var uses_left := int(_ability_uses.get(ability_id, 0))
	var uses_label := button.get_node_or_null("UsesLabel") as Label
	if uses_label != null:
		uses_label.text = str(uses_left)

	button.disabled = _level_failed or _level_completed or _level_paused or uses_left <= 0


func _set_moving_shelf_rows_paused(should_pause: bool) -> void:
	for moving_row in _get_all_moving_shelf_rows():
		moving_row.set_movement_paused(should_pause)


func _get_all_moving_shelf_rows() -> Array[MovingShelfRow]:
	var moving_rows: Array[MovingShelfRow] = []
	_collect_moving_shelf_rows_recursive(get_node("Shelves"), moving_rows)
	return moving_rows


func _collect_moving_shelf_rows_recursive(node: Node, moving_rows: Array[MovingShelfRow]) -> void:
	for child in node.get_children():
		var moving_row := child as MovingShelfRow
		if moving_row != null:
			moving_rows.append(moving_row)

		_collect_moving_shelf_rows_recursive(child, moving_rows)


func _get_all_shelves() -> Array[Node]:
	var shelves: Array[Node] = []
	_collect_shelves_recursive(get_node("Shelves"), shelves)

	return shelves


func _collect_shelves_recursive(node: Node, shelves: Array[Node]) -> void:
	for child in node.get_children():
		if _is_shelf_node(child):
			shelves.append(child)
			continue

		_collect_shelves_recursive(child, shelves)


func _is_shelf_node(node: Node) -> bool:
	return node is Node2D and _get_front_slots(node).size() == SLOT_COUNT


func _get_all_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for shelf in _get_all_shelves():
		_collect_items_recursive(shelf, items)

	return items


func _get_unlocked_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for shelf in _get_all_shelves():
		if _is_shelf_locked(shelf):
			continue

		_collect_items_recursive(shelf, items)

	return items


func _get_visible_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for shelf in _get_all_shelves():
		if _is_shelf_locked(shelf):
			continue

		for item in _get_shelf_items(shelf):
			if not _is_item_busy(item):
				items.append(item)

	return items


func _get_first_back_layer_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for shelf in _get_all_shelves():
		if _is_shelf_locked(shelf):
			continue

		var shelf_node := shelf as Node2D
		if shelf_node == null:
			continue

		var back_layer := shelf_node.get_node_or_null(_get_back_layer_name(FIRST_BACK_LAYER_INDEX)) as Node2D
		if back_layer == null:
			continue

		for layer_slot_node in back_layer.get_children():
			var layer_slot := layer_slot_node as Node2D
			if layer_slot == null:
				continue

			var item := _get_slot_item(layer_slot)
			if item != null and not _is_item_busy(item):
				items.append(item)

	return items


func _collect_items_recursive(node: Node, items: Array[ShelfItem]) -> void:
	for child in node.get_children():
		var item := child as ShelfItem
		if item != null:
			if not item.is_queued_for_deletion() and not _is_item_busy(item):
				items.append(item)
			continue

		_collect_items_recursive(child, items)


func _get_owning_shelf(node: Node) -> Node:
	var current := node
	var shelves := get_node("Shelves")
	while current != null:
		if current != shelves and _is_shelf_node(current):
			return current

		current = current.get_parent()

	return null


func _shuffle_array(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temp = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temp
