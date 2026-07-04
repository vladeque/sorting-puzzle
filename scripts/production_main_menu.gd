extends Control

const LEVEL_SCENE := preload("res://level.tscn")
const MIN_LEVEL := 1
const MAX_LEVEL := 10
const PRODUCTION_MENU_SCENE := "res://scenes/main_menu.tscn"
const BOTTOM_BAR_HEIGHT := 160.0
const BOTTOM_MARGIN := 52.0
const SIDE_MARGIN := 48.0
const LEVEL_BUTTON_MAX_WIDTH := 420.0

@onready var _bottom_bar := %BottomBar as MarginContainer
@onready var _level_button := %LevelButton as Button


func _ready() -> void:
	PlayerProgress.load_progress()
	_level_button.pressed.connect(_launch_campaign_level)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_update_level_button()
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_margins := _get_safe_area_margins(viewport_size)
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
		_level_button.text = "Level %d" % current_level
		_level_button.disabled = false
	else:
		_level_button.text = "Complete"
		_level_button.disabled = true


func _launch_campaign_level() -> void:
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
