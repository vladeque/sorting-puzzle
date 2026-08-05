extends Control

const LEVEL_SCENE := preload("res://level.tscn")
const PROFILE_MENU_SCENE := preload("res://scenes/ui/profile_menu.tscn")
const SETTINGS_MENU_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const REWARD_CHEST_MENU_SCENE := preload("res://scenes/ui/reward_chest_menu.tscn")
const CHAPTER_SELECTION_SCENE := preload("res://scenes/ui/chapter_selection_screen.tscn")
const MenuBackgroundResolverScript := preload("res://scripts/chapters/menu_background_resolver.gd")
const AVATAR_CLIP_SHADER := preload("res://assets/ui/avatar_circle_clip.gdshader")
const PRODUCTION_MENU_SCENE := "res://scenes/main_menu.tscn"
const SHOP_SCENE := "res://scenes/ui/shop_screen.tscn"
const LEADERBOARD_SCENE := "res://scenes/ui/leaderboard_screen.tscn"
const TOP_BAR_HEIGHT := 86.0
const TOP_MARGIN := 28.0
const TOP_SIDE_MARGIN := 24.0
const CAMERA_CUTOUT_PADDING := 12.0
const STATUS_CENTER_VISUAL_OVERFLOW := 6.0
const CUTOUT_LAYOUT_TOLERANCE := 0.5
const PROFILE_WIDGET_WIDTH := 76.0
const REWARD_CHEST_SIZE := Vector2(116.0, 136.0)
const REWARD_CHEST_TOP_GAP := 72.0
const BOTTOM_BAR_HEIGHT := 245.0
const BOTTOM_MARGIN := 112.0
const SIDE_MARGIN := 48.0
const LEVEL_BUTTON_MAX_WIDTH := 420.0
const CHAPTER_BUTTON_MAX_WIDTH := 280.0
const BOTTOM_NAVIGATION_HEIGHT := 96.0
const LIFE_STATUS_REFRESH_SECONDS := 1.0
const MAIN_MENU_OVERLAY_Z_INDEX := 100

@onready var _background := %Background as TextureRect
@onready var _top_status_bar := %TopStatusBar as MarginContainer
@onready var _reward_chest := %RewardChest as Control
@onready var _house_reward_origin := %HouseRewardOrigin as Control
@onready var _reward_coin_flyer := %RewardCoinFlyer as Control
@onready var _bottom_bar := %BottomBar as MarginContainer
@onready var _level_button := %LevelButton as Button
@onready var _chapter_button := %ChapterButton as Button
@onready var _bottom_navigation := %BottomNavigation as MarginContainer
@onready var _leaderboard_reward_dialog := %LeaderboardRewardDialog as Control
@onready var _top_status := %TopStatusBar.get_node("MainMenuTopStatus") as HBoxContainer
@onready var _profile_button := %TopStatusBar.get_node("MainMenuTopStatus/ProfileWidget") as Button
@onready var _settings_button := %TopStatusBar.get_node("MainMenuTopStatus/SettingsWidget/SettingsButton") as Button
@onready var _profile_avatar_texture := %TopStatusBar.get_node("MainMenuTopStatus/ProfileWidget/AvatarTexture") as TextureRect
@onready var _coin_shortcut := %TopStatusBar.get_node("MainMenuTopStatus/CoinsWidget") as Button
@onready var _life_count_label := %TopStatusBar.get_node("MainMenuTopStatus/LivesWidget/LifeCount") as Label
@onready var _life_status_label := %TopStatusBar.get_node("MainMenuTopStatus/LivesWidget/LifeStatus") as Label

var _life_status_refresh_time := 0.0
var _profile_menu: Control
var _settings_menu: Control
var _reward_chest_menu: Control
var _chapter_selection_screen: Control
var _animated_reward_stars := 0
var _animated_reward_goal_index := 0


func _ready() -> void:
	PlayerProgress.load_progress()
	PlayerProgress.refresh_lives()
	var pending_reward_animation := PlayerProgress.consume_pending_reward_chest_animation()
	var pending_leaderboard_reward := PlayerProgress.consume_pending_leaderboard_reward()
	_level_button.pressed.connect(_launch_campaign_level)
	_chapter_button.pressed.connect(_open_chapter_selection)
	_profile_button.pressed.connect(_open_profile_menu)
	_settings_button.pressed.connect(_open_settings_menu)
	_coin_shortcut.pressed.connect(_open_shop)
	if _reward_chest.has_signal("chest_pressed"):
		_reward_chest.connect("chest_pressed", Callable(self, "_open_reward_chest_menu"))
	_bottom_navigation.connect("shop_pressed", Callable(self, "_open_shop"))
	_bottom_navigation.connect("leaderboard_pressed", Callable(self, "_open_leaderboard"))
	if _bottom_navigation.has_method("set_active_tab"):
		_bottom_navigation.call("set_active_tab", &"home")
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_update_profile_avatar()
	_update_coin_balance()
	_update_lives_status()
	if pending_reward_animation.is_empty():
		_update_reward_chest_status()
	else:
		_prepare_pending_reward_animation(pending_reward_animation)
	_update_level_button()
	_update_chapter_button()
	_update_chapter_background(PlayerProgress.get_selected_chapter_id())
	_leaderboard_reward_dialog.z_index = MAIN_MENU_OVERLAY_Z_INDEX
	_apply_responsive_layout()
	if not pending_reward_animation.is_empty():
		_play_pending_reward_animation.call_deferred(pending_reward_animation)
	if not pending_leaderboard_reward.is_empty():
		_leaderboard_reward_dialog.call(
			"show_reward",
			int(pending_leaderboard_reward.get("rank", 0)),
			int(pending_leaderboard_reward.get("coin_reward", 0))
		)


func _process(delta: float) -> void:
	_life_status_refresh_time += delta
	if _life_status_refresh_time < LIFE_STATUS_REFRESH_SECONDS:
		return

	_life_status_refresh_time = fmod(_life_status_refresh_time, LIFE_STATUS_REFRESH_SECONDS)
	_update_lives_status()
	_update_level_button()
	_update_chapter_button()


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_margins := _get_safe_area_margins(viewport_size)
	var display_cutouts := _get_display_cutouts(viewport_size)
	_layout_top_status_bar(safe_margins, viewport_size, display_cutouts)
	_layout_reward_chest(safe_margins)
	_layout_bottom_navigation(safe_margins)
	_bottom_bar.anchor_left = 0.0
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_left = safe_margins.x + SIDE_MARGIN
	_bottom_bar.offset_top = -(BOTTOM_MARGIN + BOTTOM_BAR_HEIGHT + maxf(safe_margins.w, 0.0))
	_bottom_bar.offset_right = -(safe_margins.z + SIDE_MARGIN)
	_bottom_bar.offset_bottom = -(BOTTOM_MARGIN + maxf(safe_margins.w, 0.0))

	var available_width := maxf(viewport_size.x - safe_margins.x - safe_margins.z - SIDE_MARGIN * 2.0, 1.0)
	var button_minimum_size := _level_button.custom_minimum_size
	button_minimum_size.x = minf(LEVEL_BUTTON_MAX_WIDTH, available_width)
	_level_button.custom_minimum_size = button_minimum_size
	var chapter_minimum_size := _chapter_button.custom_minimum_size
	chapter_minimum_size.x = minf(CHAPTER_BUTTON_MAX_WIDTH, available_width)
	_chapter_button.custom_minimum_size = chapter_minimum_size


func _layout_bottom_navigation(safe_margins: Vector4) -> void:
	if _bottom_navigation == null:
		return

	var safe_bottom := maxf(safe_margins.w, 0.0)
	_bottom_navigation.anchor_left = 0.0
	_bottom_navigation.anchor_top = 1.0
	_bottom_navigation.anchor_right = 1.0
	_bottom_navigation.anchor_bottom = 1.0
	_bottom_navigation.offset_left = 0.0
	_bottom_navigation.offset_top = -(BOTTOM_NAVIGATION_HEIGHT + safe_bottom)
	_bottom_navigation.offset_right = 0.0
	_bottom_navigation.offset_bottom = 0.0
	if _bottom_navigation.has_method("set_safe_bottom_margin"):
		_bottom_navigation.call("set_safe_bottom_margin", safe_bottom)


func _layout_top_status_bar(
	safe_margins: Vector4,
	viewport_size: Vector2,
	display_cutouts: Array[Rect2]
) -> void:
	var bar_left := safe_margins.x + TOP_SIDE_MARGIN
	var bar_right := viewport_size.x - safe_margins.z - TOP_SIDE_MARGIN
	var bar_width := maxf(bar_right - bar_left, 0.0)
	var bar_center_x := (bar_left + bar_right) * 0.5
	var default_bar_rect := Rect2(
		Vector2(bar_left, TOP_MARGIN),
		Vector2(bar_width, TOP_BAR_HEIGHT)
	)
	var required_center_exclusion := 0.0
	var cutout_fallback_top := TOP_MARGIN

	for cutout: Rect2 in display_cutouts:
		var padded_cutout := cutout.grow(CAMERA_CUTOUT_PADDING)
		if not padded_cutout.intersects(default_bar_rect):
			continue

		var farthest_horizontal_edge := maxf(
			absf(padded_cutout.position.x - bar_center_x),
			absf(padded_cutout.end.x - bar_center_x)
		)
		required_center_exclusion = maxf(
			required_center_exclusion,
			(farthest_horizontal_edge + STATUS_CENTER_VISUAL_OVERFLOW) * 2.0
		)
		cutout_fallback_top = maxf(cutout_fallback_top, padded_cutout.end.y)

	var actual_center_exclusion := 0.0
	if _top_status.has_method("set_center_exclusion_width"):
		actual_center_exclusion = float(
			_top_status.call("set_center_exclusion_width", required_center_exclusion, bar_width)
		)

	var bar_top := TOP_MARGIN
	if required_center_exclusion > actual_center_exclusion + CUTOUT_LAYOUT_TOLERANCE:
		bar_top = cutout_fallback_top
		if _top_status.has_method("set_center_exclusion_width"):
			_top_status.call("set_center_exclusion_width", 0.0, bar_width)

	_top_status_bar.anchor_left = 0.0
	_top_status_bar.anchor_top = 0.0
	_top_status_bar.anchor_right = 1.0
	_top_status_bar.anchor_bottom = 0.0
	_top_status_bar.offset_left = bar_left
	_top_status_bar.offset_top = bar_top
	_top_status_bar.offset_right = -(safe_margins.z + TOP_SIDE_MARGIN)
	_top_status_bar.offset_bottom = bar_top + TOP_BAR_HEIGHT


func _layout_reward_chest(safe_margins: Vector4) -> void:
	if _reward_chest == null:
		return

	var centered_left := safe_margins.x + TOP_SIDE_MARGIN + ((PROFILE_WIDGET_WIDTH - REWARD_CHEST_SIZE.x) * 0.5)
	var left := maxf(centered_left, safe_margins.x + 26.0)
	var top := _top_status_bar.offset_top + PROFILE_WIDGET_WIDTH + REWARD_CHEST_TOP_GAP
	_reward_chest.anchor_left = 0.0
	_reward_chest.anchor_top = 0.0
	_reward_chest.anchor_right = 0.0
	_reward_chest.anchor_bottom = 0.0
	_reward_chest.offset_left = left
	_reward_chest.offset_top = top
	_reward_chest.offset_right = left + REWARD_CHEST_SIZE.x
	_reward_chest.offset_bottom = top + REWARD_CHEST_SIZE.y


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


func _get_display_cutouts(viewport_size: Vector2) -> Array[Rect2]:
	var logical_cutouts: Array[Rect2] = []
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return logical_cutouts

	var scale := Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	for display_cutout: Rect2 in DisplayServer.get_display_cutouts():
		logical_cutouts.append(Rect2(
			Vector2(display_cutout.position) * scale,
			Vector2(display_cutout.size) * scale
		))
	return logical_cutouts


func _update_level_button() -> void:
	var chapter_id := PlayerProgress.get_selected_chapter_id()
	var next_level := PlayerProgress.get_next_level_for_chapter(chapter_id)
	if next_level > 0:
		if PlayerProgress.get_lives() <= 0:
			_level_button.text = "NO LIVES"
			_level_button.disabled = true
		else:
			_level_button.text = "LEVEL %d" % ChapterCatalog.get_local_level_number(next_level)
			_level_button.disabled = false
	else:
		var progress := PlayerProgress.get_chapter_progress(chapter_id)
		_level_button.text = "CHAPTER COMPLETE" if bool(progress.get("complete", false)) else "COMING SOON"
		_level_button.disabled = true


func _update_chapter_button() -> void:
	var chapter_id := PlayerProgress.get_selected_chapter_id()
	var chapter := ChapterCatalog.get_chapter(chapter_id)
	if chapter.is_empty():
		return
	if _chapter_button.has_method("set_chapter"):
		_chapter_button.call("set_chapter", chapter, PlayerProgress.get_chapter_progress(chapter_id))


func _update_lives_status() -> void:
	var lives := PlayerProgress.get_lives()
	if _life_count_label != null:
		_life_count_label.text = str(lives)

	if _life_status_label == null:
		return

	if lives >= PlayerProgress.get_max_lives():
		_life_status_label.text = "Full"
		return

	var seconds_remaining := PlayerProgress.get_next_life_restore_seconds_remaining()
	_life_status_label.text = _format_life_restore_time(seconds_remaining)


func _update_reward_chest_status() -> void:
	if _reward_chest == null or not _reward_chest.has_method("set_reward_progress"):
		return

	var progress := PlayerProgress.get_reward_chest_progress()
	_reward_chest.call(
		"set_reward_progress",
		int(progress.get("stars", 0)),
		int(progress.get("goal", 1))
	)


func _prepare_pending_reward_animation(pending: Dictionary) -> void:
	_animated_reward_stars = maxi(int(pending.get("start_stars", 0)), 0)
	_animated_reward_goal_index = maxi(int(pending.get("start_goal_index", 0)), 0)
	_set_animated_reward_chest_status()


func _play_pending_reward_animation(pending: Dictionary) -> void:
	var amount := maxi(int(pending.get("amount", 0)), 0)
	if amount <= 0 or _reward_coin_flyer == null or _house_reward_origin == null:
		_update_reward_chest_status()
		return

	if not _reward_coin_flyer.coin_arrived.is_connected(_on_reward_coin_arrived):
		_reward_coin_flyer.coin_arrived.connect(_on_reward_coin_arrived)
	if not _reward_coin_flyer.animation_finished.is_connected(_on_reward_coin_animation_finished):
		_reward_coin_flyer.animation_finished.connect(_on_reward_coin_animation_finished)

	var start_position := _house_reward_origin.get_global_rect().get_center()
	var target_position := _reward_chest.get_global_rect().get_center()
	if _reward_chest.has_method("get_coin_target_global_position"):
		target_position = _reward_chest.call("get_coin_target_global_position") as Vector2
	_reward_coin_flyer.call("play", amount, start_position, target_position)


func _on_reward_coin_arrived() -> void:
	_animated_reward_stars += 1
	var goal := PlayerProgress.get_reward_chest_goal_at_index(_animated_reward_goal_index)
	if _animated_reward_stars >= goal:
		_animated_reward_stars -= goal
		_animated_reward_goal_index = mini(
			_animated_reward_goal_index + 1,
			PlayerProgress.get_reward_chest_last_goal_index()
		)

	_set_animated_reward_chest_status()
	if _reward_chest.has_method("play_receive_pulse"):
		_reward_chest.call("play_receive_pulse")


func _on_reward_coin_animation_finished() -> void:
	_update_reward_chest_status()


func _set_animated_reward_chest_status() -> void:
	if _reward_chest == null or not _reward_chest.has_method("set_reward_progress"):
		return

	_reward_chest.call(
		"set_reward_progress",
		_animated_reward_stars,
		PlayerProgress.get_reward_chest_goal_at_index(_animated_reward_goal_index)
	)


func _format_life_restore_time(seconds_remaining: int) -> String:
	var clamped_seconds := maxi(seconds_remaining, 0)
	var minutes_remaining := floori(float(clamped_seconds) / 60.0)
	var remaining_seconds := clamped_seconds % 60
	return "%02d:%02d" % [minutes_remaining, remaining_seconds]


func _update_profile_avatar() -> void:
	if _profile_avatar_texture == null:
		return

	var avatar_id := PlayerProgress.get_avatar_id()
	_profile_avatar_texture.texture = load(PlayerProgress.get_avatar_texture_path(avatar_id)) as Texture2D
	if _profile_avatar_texture.material == null:
		var clip_material := ShaderMaterial.new()
		clip_material.shader = AVATAR_CLIP_SHADER
		_profile_avatar_texture.material = clip_material


func _update_coin_balance() -> void:
	if _coin_shortcut != null:
		_coin_shortcut.call("set_amount", PlayerProgress.get_coins())


func _open_profile_menu() -> void:
	if is_instance_valid(_profile_menu):
		return

	_profile_menu = PROFILE_MENU_SCENE.instantiate() as Control
	_add_main_menu_overlay(_profile_menu)
	_profile_menu.connect("avatar_saved", Callable(self, "_on_profile_avatar_saved"))
	_profile_menu.tree_exited.connect(_clear_profile_menu_reference)


func _open_settings_menu() -> void:
	if is_instance_valid(_settings_menu):
		return

	_settings_menu = SETTINGS_MENU_SCENE.instantiate() as Control
	_add_main_menu_overlay(_settings_menu)

	var close_button := _settings_menu.get_node_or_null("PauseMenuPanel/CloseButton") as Button
	if close_button != null:
		close_button.pressed.connect(_close_settings_menu)

	_settings_menu.tree_exited.connect(_clear_settings_menu_reference)


func _close_settings_menu() -> void:
	if is_instance_valid(_settings_menu):
		_settings_menu.queue_free()


func _open_reward_chest_menu() -> void:
	if is_instance_valid(_reward_chest_menu):
		return

	_reward_chest_menu = REWARD_CHEST_MENU_SCENE.instantiate() as Control
	_add_main_menu_overlay(_reward_chest_menu)
	_reward_chest_menu.tree_exited.connect(_clear_reward_chest_menu_reference)


func _open_chapter_selection() -> void:
	if is_instance_valid(_chapter_selection_screen):
		return
	_chapter_selection_screen = CHAPTER_SELECTION_SCENE.instantiate() as Control
	_add_main_menu_overlay(_chapter_selection_screen)
	_chapter_selection_screen.connect("chapter_selected", Callable(self, "_on_chapter_selected"))
	_chapter_selection_screen.tree_exited.connect(_clear_chapter_selection_reference)


func _on_chapter_selected(chapter_id: String) -> void:
	_update_level_button()
	_update_chapter_button()
	_update_chapter_background(chapter_id)


func _update_chapter_background(chapter_id: String) -> void:
	MenuBackgroundResolverScript.apply_background(_background, chapter_id)


func _add_main_menu_overlay(overlay: Control) -> void:
	overlay.z_index = MAIN_MENU_OVERLAY_Z_INDEX
	add_child(overlay)


func _clear_chapter_selection_reference() -> void:
	_chapter_selection_screen = null


func _clear_reward_chest_menu_reference() -> void:
	_reward_chest_menu = null


func _on_profile_avatar_saved(_avatar_id: String) -> void:
	_update_profile_avatar()


func _clear_profile_menu_reference() -> void:
	_profile_menu = null


func _clear_settings_menu_reference() -> void:
	_settings_menu = null


func _open_leaderboard() -> void:
	get_tree().change_scene_to_file(LEADERBOARD_SCENE)


func _open_shop() -> void:
	get_tree().change_scene_to_file(SHOP_SCENE)


func _launch_campaign_level() -> void:
	PlayerProgress.refresh_lives()
	if PlayerProgress.get_lives() <= 0:
		_update_lives_status()
		_update_level_button()
		return

	var chapter_id := PlayerProgress.get_selected_chapter_id()
	var next_level := PlayerProgress.get_next_level_for_chapter(chapter_id)
	if next_level <= 0:
		return

	var level_scene := LEVEL_SCENE.instantiate()
	level_scene.selected_level = next_level
	level_scene.launched_from_dev_mode = false
	level_scene.return_menu_scene_path = PRODUCTION_MENU_SCENE

	var tree := get_tree()
	var current_scene := tree.current_scene
	tree.root.add_child(level_scene)
	tree.current_scene = level_scene

	if current_scene != null:
		current_scene.queue_free()
