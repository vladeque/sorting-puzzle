extends Control

const LeaderboardServiceScript := preload("res://scripts/leaderboards/leaderboard_service.gd")
const DestinationScreenLayoutScript := preload("res://scripts/destination_screen_layout.gd")
const ROW_SCENE := preload("res://scenes/ui/leaderboard_row.tscn")
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const SHOP_SCENE := "res://scenes/ui/shop_screen.tscn"
const SCOPE_WEEKLY := &"weekly"
const SCOPE_COUNTRY := &"country"
const SCOPE_WORLD := &"world"
const ROW_LIMIT := 50
const RANK_REWARD_TEXTURES := {
	1: preload("res://assets/ui/shop_coin_offers/shop_coin_offer_tier_04.png"),
	2: preload("res://assets/ui/shop_coin_offers/shop_coin_offer_tier_03.png"),
	3: preload("res://assets/ui/shop_coin_offers/shop_coin_offer_tier_02.png"),
}
## Ranks at or below this are assumed visible without scrolling (about how many rows fit above
## the fold at the reference 720x1280 viewport); beyond it the pinned row keeps the player's
## standing visible without requiring a scroll.
const PINNED_ROW_RANK_THRESHOLD := 10

@onready var _destination_shell := %DestinationShell as Control
@onready var _content_margin := %ContentMargin as MarginContainer
@onready var _title_label := %TitleLabel as Label
@onready var _weekly_button := %WeeklyButton as Button
@onready var _country_button := %CountryButton as Button
@onready var _world_button := %WorldButton as Button
@onready var _period_label := %PeriodLabel as Label
@onready var _list_background := %ListBackground as Panel
@onready var _leaderboard_scroll := %LeaderboardScroll as ScrollContainer
@onready var _rows_container := %RowsContainer as VBoxContainer
@onready var _status_panel := %StatusPanel as Control
@onready var _pinned_player_row := %PinnedPlayerRow as Control
@onready var _bottom_navigation := %BottomNavigation as MarginContainer

var _service
var _selected_scope := SCOPE_WEEKLY
var _request_serial := 0
var _period_end_unix := 0
var _timer_refresh_accumulator := 0.0
var _rows: Array[Control] = []
var _is_navigating := false


func _ready() -> void:
	_service = LeaderboardServiceScript.new()
	_weekly_button.pressed.connect(_select_scope.bind(SCOPE_WEEKLY))
	_country_button.pressed.connect(_select_scope.bind(SCOPE_COUNTRY))
	_world_button.pressed.connect(_select_scope.bind(SCOPE_WORLD))
	_status_panel.connect("retry_pressed", Callable(self, "_load_selected_scope"))
	_bottom_navigation.connect("shop_pressed", Callable(self, "_open_shop"))
	_bottom_navigation.connect("home_pressed", Callable(self, "_return_to_main_menu"))
	_bottom_navigation.connect("leaderboard_pressed", Callable(self, "_on_leaderboard_tab_reselected"))
	if _bottom_navigation.has_method("set_active_tab"):
		_bottom_navigation.call("set_active_tab", &"leaderboard")
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_destination_shell.call("set_background_for_chapter", PlayerProgress.get_selected_chapter_id())
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
	var player_entry := result.get("player_entry", {}) as Dictionary
	_populate_entries(result.get("entries", []) as Array, player_entry)
	_update_period_label()

	if _selected_scope == SCOPE_WEEKLY and int(player_entry.get("rank", 0)) > 0:
		PlayerProgress.record_weekly_leaderboard_rank(int(player_entry.get("rank", 0)))


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
	var is_compact := DestinationScreenLayoutScript.is_compact_viewport(get_viewport_rect().size)
	var contains_current_player := false
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue

		var entry := raw_entry as Dictionary
		var row := ROW_SCENE.instantiate() as Control
		_rows_container.add_child(row)
		row.call("set_entry", entry)
		_configure_row_reward(row, int(entry.get("rank", 0)))
		row.call("set_compact", is_compact)
		_rows.append(row)
		contains_current_player = contains_current_player or bool(entry.get("is_current_player", false))

	var has_entries := not _rows.is_empty()
	_list_background.visible = has_entries
	_leaderboard_scroll.visible = has_entries
	if has_entries:
		_status_panel.call("hide_status")
	else:
		_status_panel.call("show_empty", "No scores yet")

	var player_rank := int(player_entry.get("rank", 0))
	var should_pin_player := not player_entry.is_empty() and (
		not contains_current_player
		or player_rank <= 0
		or player_rank > PINNED_ROW_RANK_THRESHOLD
	)
	_pinned_player_row.visible = should_pin_player
	if should_pin_player:
		_pinned_player_row.call("set_entry", player_entry)
		_configure_row_reward(_pinned_player_row, player_rank)
		_pinned_player_row.call("set_compact", is_compact)


func _clear_rows() -> void:
	for row in _rows:
		if is_instance_valid(row):
			_rows_container.remove_child(row)
			row.queue_free()
	_rows.clear()


func _set_loading_state() -> void:
	_clear_rows()
	_list_background.visible = false
	_leaderboard_scroll.visible = false
	_pinned_player_row.visible = false
	_status_panel.call("show_loading", "Loading leaderboard…")


func _set_error_state(message: String) -> void:
	_list_background.visible = false
	_leaderboard_scroll.visible = false
	_pinned_player_row.visible = false
	_status_panel.call("show_error", message)


func _update_period_label() -> void:
	match _selected_scope:
		SCOPE_WEEKLY:
			var remaining := maxi(_period_end_unix - int(Time.get_unix_time_from_system()), 0)
			_period_label.text = "Weekly reset in %s" % _format_duration(remaining)
		SCOPE_COUNTRY:
			_period_label.text = "Country · All-time stars"
		_:
			_period_label.text = "Worldwide · All-time stars"


## Weekly payouts are shown directly on ranks 1-3. The coin amount still comes from the shared
## reward-tier configuration, while this screen owns the presentation-only rank-to-art mapping.
func _configure_row_reward(row: Control, rank: int) -> void:
	if _selected_scope != SCOPE_WEEKLY or not RANK_REWARD_TEXTURES.has(rank):
		row.call("clear_rank_reward")
		return

	var coin_reward := _get_weekly_coin_reward(rank)
	if coin_reward <= 0:
		row.call("clear_rank_reward")
		return

	row.call("set_rank_reward", RANK_REWARD_TEXTURES[rank] as Texture2D, coin_reward)


func _get_weekly_coin_reward(rank: int) -> int:
	for raw_tier in PlayerProgress.get_leaderboard_reward_tiers():
		var tier := raw_tier as Dictionary
		if rank >= int(tier.get("min_rank", 0)) and rank <= int(tier.get("max_rank", 0)):
			return maxi(int(tier.get("coin_reward", 0)), 0)

	return 0


func _format_duration(seconds: int) -> String:
	var days := floori(float(seconds) / float(24 * 60 * 60))
	var hours := floori(float(seconds % (24 * 60 * 60)) / float(60 * 60))
	var minutes := floori(float(seconds % (60 * 60)) / 60.0)
	if days > 0:
		return "%dd %dh" % [days, hours]
	if hours > 0:
		return "%dh %dm" % [hours, minutes]

	return "%dm" % minutes


## Leaderboard has no scoped overlay of its own, so `ui_cancel` always returns to Main Menu,
## matching Shop (see docs/SCENES.md's "Back/ui_cancel Behavior").
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	get_viewport().set_input_as_handled()
	_return_to_main_menu()


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_margins := DestinationScreenLayoutScript.get_safe_area_margins(viewport_size)
	DestinationScreenLayoutScript.apply_content_rect(
		_content_margin,
		viewport_size,
		safe_margins,
		DestinationScreenLayoutScript.get_bottom_reserved(safe_margins)
	)
	DestinationScreenLayoutScript.layout_bottom_navigation(_bottom_navigation, safe_margins)

	var is_compact := DestinationScreenLayoutScript.is_compact_viewport(viewport_size)
	_title_label.add_theme_font_size_override(
		"font_size", DestinationScreenLayoutScript.get_title_font_size(viewport_size)
	)
	var tab_height := 54.0 if is_compact else 64.0
	for button in [_weekly_button, _country_button, _world_button]:
		(button as Button).custom_minimum_size.y = tab_height
	for row in _rows:
		if is_instance_valid(row):
			row.call("set_compact", is_compact)
	_pinned_player_row.call("set_compact", is_compact)


## Retapping the already-active Leaderboard tab is a no-op (see docs/SCENES.md's "Active-Tab
## Reselection Rule"); ranking refresh stays available only through the status panel's explicit
## Retry action, not a hidden tab-retap convention.
func _on_leaderboard_tab_reselected() -> void:
	pass


func _return_to_main_menu() -> void:
	_begin_navigation(MAIN_MENU_SCENE)


func _open_shop() -> void:
	_begin_navigation(SHOP_SCENE)


## Ignores a duplicate cross-destination press while a scene transition is already underway, so a
## rapid double-tap on Home/Shop can never call change_scene_to_file() twice.
func _begin_navigation(scene_path: String) -> void:
	if _is_navigating:
		return

	_is_navigating = true
	get_tree().change_scene_to_file(scene_path)
