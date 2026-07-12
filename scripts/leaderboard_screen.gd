extends Control

const LeaderboardServiceScript := preload("res://scripts/leaderboards/leaderboard_service.gd")
const ROW_SCENE := preload("res://scenes/ui/leaderboard_row.tscn")
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const SCOPE_WEEKLY := &"weekly"
const SCOPE_COUNTRY := &"country"
const SCOPE_WORLD := &"world"
const ROW_LIMIT := 50
const CONTENT_MAX_WIDTH := 720.0
const CONTENT_SIDE_MARGIN := 16.0
const CONTENT_TOP_MARGIN := 18.0
const CONTENT_BOTTOM_GAP := 12.0
const BOTTOM_NAVIGATION_HEIGHT := 96.0
const COMPACT_VIEWPORT_HEIGHT := 1100.0

@onready var _content_margin := %ContentMargin as MarginContainer
@onready var _title_label := %TitleLabel as Label
@onready var _weekly_button := %WeeklyButton as Button
@onready var _country_button := %CountryButton as Button
@onready var _world_button := %WorldButton as Button
@onready var _period_label := %PeriodLabel as Label
@onready var _leaderboard_scroll := %LeaderboardScroll as ScrollContainer
@onready var _rows_container := %RowsContainer as VBoxContainer
@onready var _status_container := %StatusContainer as CenterContainer
@onready var _status_label := %StatusLabel as Label
@onready var _retry_button := %RetryButton as Button
@onready var _pinned_player_row := %PinnedPlayerRow as Control
@onready var _bottom_navigation := %BottomNavigation as MarginContainer

var _service
var _selected_scope := SCOPE_WEEKLY
var _request_serial := 0
var _period_end_unix := 0
var _timer_refresh_accumulator := 0.0
var _rows: Array[Control] = []


func _ready() -> void:
	_service = LeaderboardServiceScript.new()
	_weekly_button.pressed.connect(_select_scope.bind(SCOPE_WEEKLY))
	_country_button.pressed.connect(_select_scope.bind(SCOPE_COUNTRY))
	_world_button.pressed.connect(_select_scope.bind(SCOPE_WORLD))
	_retry_button.pressed.connect(_load_selected_scope)
	_bottom_navigation.connect("home_pressed", Callable(self, "_return_to_main_menu"))
	_bottom_navigation.connect("leaderboard_pressed", Callable(self, "_load_selected_scope"))
	if _bottom_navigation.has_method("set_active_tab"):
		_bottom_navigation.call("set_active_tab", &"leaderboard")
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_select_scope(SCOPE_WEEKLY)


func _process(delta: float) -> void:
	if _selected_scope != SCOPE_WEEKLY or _period_end_unix <= 0:
		return

	_timer_refresh_accumulator += delta
	if _timer_refresh_accumulator < 1.0:
		return

	_timer_refresh_accumulator = fmod(_timer_refresh_accumulator, 1.0)
	_update_period_label()


func _select_scope(scope: StringName) -> void:
	_selected_scope = scope
	_weekly_button.button_pressed = scope == SCOPE_WEEKLY
	_country_button.button_pressed = scope == SCOPE_COUNTRY
	_world_button.button_pressed = scope == SCOPE_WORLD
	_load_selected_scope()


func _load_selected_scope() -> void:
	_request_serial += 1
	var request_serial := _request_serial
	_set_loading_state()
	var result: Dictionary = await _service.fetch_leaderboard(
		_selected_scope,
		_build_current_player_profile(),
		ROW_LIMIT
	)
	if request_serial != _request_serial:
		return

	if not bool(result.get("ok", false)):
		_set_error_state(str(result.get("error", "Could not load leaderboard.")))
		return

	_period_end_unix = int(result.get("period_end_unix", 0))
	_populate_entries(result.get("entries", []) as Array, result.get("player_entry", {}) as Dictionary)
	_update_period_label()


func _build_current_player_profile() -> Dictionary:
	return {
		"player_id": "local_player",
		"display_name": PlayerProgress.get_player_name(),
		"avatar_id": PlayerProgress.get_avatar_id(),
		"country_code": "",
		"total_score": PlayerProgress.get_total_earned_stars(),
		"weekly_score": PlayerProgress.get_weekly_earned_stars(),
		"week_end_unix": PlayerProgress.get_current_leaderboard_week_end_unix(),
	}


func _populate_entries(entries: Array, player_entry: Dictionary) -> void:
	_clear_rows()
	var is_compact := get_viewport_rect().size.y < COMPACT_VIEWPORT_HEIGHT
	var contains_current_player := false
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue

		var entry := raw_entry as Dictionary
		var row := ROW_SCENE.instantiate() as Control
		_rows_container.add_child(row)
		row.call("set_entry", entry)
		row.call("set_compact", is_compact)
		_rows.append(row)
		contains_current_player = contains_current_player or bool(entry.get("is_current_player", false))

	var has_entries := not _rows.is_empty()
	_leaderboard_scroll.visible = has_entries
	_status_container.visible = not has_entries
	_status_label.text = "No scores yet" if not has_entries else ""
	_retry_button.visible = false

	var should_pin_player := not player_entry.is_empty() and not contains_current_player
	_pinned_player_row.visible = should_pin_player
	if should_pin_player:
		_pinned_player_row.call("set_entry", player_entry)
		_pinned_player_row.call("set_compact", is_compact)


func _clear_rows() -> void:
	for row in _rows:
		if is_instance_valid(row):
			_rows_container.remove_child(row)
			row.queue_free()
	_rows.clear()


func _set_loading_state() -> void:
	_clear_rows()
	_leaderboard_scroll.visible = false
	_pinned_player_row.visible = false
	_status_container.visible = true
	_status_label.text = "Loading leaderboard…"
	_retry_button.visible = false


func _set_error_state(message: String) -> void:
	_leaderboard_scroll.visible = false
	_pinned_player_row.visible = false
	_status_container.visible = true
	_status_label.text = message
	_retry_button.visible = true


func _update_period_label() -> void:
	match _selected_scope:
		SCOPE_WEEKLY:
			var remaining := maxi(_period_end_unix - int(Time.get_unix_time_from_system()), 0)
			_period_label.text = "Weekly reset in %s" % _format_duration(remaining)
		SCOPE_COUNTRY:
			_period_label.text = "Country · All-time stars"
		_:
			_period_label.text = "Worldwide · All-time stars"


func _format_duration(seconds: int) -> String:
	var days := floori(float(seconds) / float(24 * 60 * 60))
	var hours := floori(float(seconds % (24 * 60 * 60)) / float(60 * 60))
	var minutes := floori(float(seconds % (60 * 60)) / 60.0)
	if days > 0:
		return "%dd %dh" % [days, hours]
	if hours > 0:
		return "%dh %dm" % [hours, minutes]

	return "%dm" % minutes


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_margins := _get_safe_area_margins(viewport_size)
	var available_width := maxf(
		viewport_size.x - safe_margins.x - safe_margins.z - CONTENT_SIDE_MARGIN * 2.0,
		1.0
	)
	var content_width := minf(CONTENT_MAX_WIDTH, available_width)
	var content_left := safe_margins.x + (viewport_size.x - safe_margins.x - safe_margins.z - content_width) * 0.5
	_content_margin.offset_left = content_left
	_content_margin.offset_top = safe_margins.y + CONTENT_TOP_MARGIN
	_content_margin.offset_right = -(viewport_size.x - content_left - content_width)
	_content_margin.offset_bottom = -(BOTTOM_NAVIGATION_HEIGHT + safe_margins.w + CONTENT_BOTTOM_GAP)
	_layout_bottom_navigation(safe_margins)

	var is_compact := viewport_size.y < COMPACT_VIEWPORT_HEIGHT
	_title_label.add_theme_font_size_override("font_size", 36 if is_compact else 44)
	var tab_height := 54.0 if is_compact else 64.0
	for button in [_weekly_button, _country_button, _world_button]:
		(button as Button).custom_minimum_size.y = tab_height
	for row in _rows:
		if is_instance_valid(row):
			row.call("set_compact", is_compact)
	_pinned_player_row.call("set_compact", is_compact)


func _layout_bottom_navigation(safe_margins: Vector4) -> void:
	var safe_bottom := maxf(safe_margins.w, 0.0)
	_bottom_navigation.offset_top = -(BOTTOM_NAVIGATION_HEIGHT + safe_bottom)
	_bottom_navigation.offset_bottom = 0.0
	if _bottom_navigation.has_method("set_safe_bottom_margin"):
		_bottom_navigation.call("set_safe_bottom_margin", safe_bottom)


func _get_safe_area_margins(viewport_size: Vector2) -> Vector4:
	if OS.get_name() not in ["Android", "iOS"]:
		return Vector4.ZERO

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


func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
