extends Control

const LEVEL_SCENE := preload("res://level.tscn")
const PROFILE_MENU_SCENE := preload("res://scenes/ui/profile_menu.tscn")
const MIN_LEVEL := 1
const MAX_LEVEL := 10
const PRODUCTION_MENU_SCENE := "res://scenes/main_menu.tscn"
const TOP_BAR_HEIGHT := 86.0
const TOP_MARGIN := 28.0
const TOP_SIDE_MARGIN := 24.0
const BOTTOM_BAR_HEIGHT := 220.0
const BOTTOM_MARGIN := 152.0
const SIDE_MARGIN := 48.0
const LEVEL_BUTTON_MAX_WIDTH := 420.0
const LIFE_STATUS_REFRESH_SECONDS := 1.0

@onready var _top_status_bar := %TopStatusBar as MarginContainer
@onready var _bottom_bar := %BottomBar as MarginContainer
@onready var _level_button := %LevelButton as Button
@onready var _profile_button := %TopStatusBar.get_node("MainMenuTopStatus/ProfileWidget") as Button
@onready var _profile_avatar_texture := %TopStatusBar.get_node("MainMenuTopStatus/ProfileWidget/AvatarTexture") as TextureRect
@onready var _life_count_label := %TopStatusBar.get_node("MainMenuTopStatus/LivesWidget/LifeCount") as Label
@onready var _life_status_label := %TopStatusBar.get_node("MainMenuTopStatus/LivesWidget/LifeStatus") as Label

var _life_status_refresh_time := 0.0
var _profile_menu: Control


func _ready() -> void:
	PlayerProgress.load_progress()
	PlayerProgress.refresh_lives()
	_level_button.pressed.connect(_launch_campaign_level)
	_profile_button.pressed.connect(_open_profile_menu)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_update_profile_avatar()
	_update_lives_status()
	_update_level_button()
	_apply_responsive_layout()


func _process(delta: float) -> void:
	_life_status_refresh_time += delta
	if _life_status_refresh_time < LIFE_STATUS_REFRESH_SECONDS:
		return

	_life_status_refresh_time = 0.0
	_update_lives_status()
	_update_level_button()


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_margins := _get_safe_area_margins(viewport_size)
	_layout_top_status_bar(safe_margins)
	_bottom_bar.anchor_left = 0.0
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_left = safe_margins.x + SIDE_MARGIN
	_bottom_bar.offset_top = -(BOTTOM_BAR_HEIGHT + maxf(safe_margins.w, 0.0))
	_bottom_bar.offset_right = -(safe_margins.z + SIDE_MARGIN)
	_bottom_bar.offset_bottom = -(BOTTOM_MARGIN + maxf(safe_margins.w, 0.0))

	var available_width := maxf(viewport_size.x - safe_margins.x - safe_margins.z - SIDE_MARGIN * 2.0, 1.0)
	var button_minimum_size := _level_button.custom_minimum_size
	button_minimum_size.x = minf(LEVEL_BUTTON_MAX_WIDTH, available_width)
	_level_button.custom_minimum_size = button_minimum_size


func _layout_top_status_bar(safe_margins: Vector4) -> void:
	_top_status_bar.anchor_left = 0.0
	_top_status_bar.anchor_top = 0.0
	_top_status_bar.anchor_right = 1.0
	_top_status_bar.anchor_bottom = 0.0
	_top_status_bar.offset_left = safe_margins.x + TOP_SIDE_MARGIN
	_top_status_bar.offset_top = safe_margins.y + TOP_MARGIN
	_top_status_bar.offset_right = -(safe_margins.z + TOP_SIDE_MARGIN)
	_top_status_bar.offset_bottom = safe_margins.y + TOP_MARGIN + TOP_BAR_HEIGHT


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


func _update_level_button() -> void:
	var current_level := PlayerProgress.get_current_level()
	var has_level_to_play := current_level >= MIN_LEVEL and current_level <= MAX_LEVEL and _level_config_exists(current_level)
	if has_level_to_play:
		if PlayerProgress.get_lives() <= 0:
			_level_button.text = "No Lives"
			_level_button.disabled = true
		else:
			_level_button.text = "Level %d" % current_level
			_level_button.disabled = false
	else:
		_level_button.text = "Complete"
		_level_button.disabled = true


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
	var minutes_remaining := maxi(ceili(float(seconds_remaining) / 60.0), 1)
	_life_status_label.text = "%dm" % minutes_remaining


func _update_profile_avatar() -> void:
	if _profile_avatar_texture == null:
		return

	var avatar_id := PlayerProgress.get_avatar_id()
	_profile_avatar_texture.texture = load(PlayerProgress.get_avatar_texture_path(avatar_id)) as Texture2D


func _open_profile_menu() -> void:
	if is_instance_valid(_profile_menu):
		return

	_profile_menu = PROFILE_MENU_SCENE.instantiate() as Control
	add_child(_profile_menu)
	_profile_menu.connect("avatar_saved", Callable(self, "_on_profile_avatar_saved"))
	_profile_menu.tree_exited.connect(_clear_profile_menu_reference)


func _on_profile_avatar_saved(_avatar_id: String) -> void:
	_update_profile_avatar()


func _clear_profile_menu_reference() -> void:
	_profile_menu = null


func _launch_campaign_level() -> void:
	PlayerProgress.refresh_lives()
	if PlayerProgress.get_lives() <= 0:
		_update_lives_status()
		_update_level_button()
		return

	var current_level := PlayerProgress.get_current_level()
	if current_level < MIN_LEVEL or current_level > MAX_LEVEL or not _level_config_exists(current_level):
		return

	var level_scene := LEVEL_SCENE.instantiate()
	level_scene.selected_level = current_level
	level_scene.launched_from_dev_mode = false
	level_scene.return_menu_scene_path = PRODUCTION_MENU_SCENE

	var tree := get_tree()
	var current_scene := tree.current_scene
	tree.root.add_child(level_scene)
	tree.current_scene = level_scene

	if current_scene != null:
		current_scene.queue_free()


func _level_config_exists(level_number: int) -> bool:
	return FileAccess.file_exists("res://configs/levels/level_%03d.json" % level_number)
