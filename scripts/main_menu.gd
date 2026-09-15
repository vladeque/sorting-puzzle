extends Control

const MIN_LEVEL := 1
const MAX_LEVEL := 10
const DEV_LEVEL_SELECT_SETTING := "application/config/dev_level_select_enabled"
const TESTING_MENU_SCENE := "res://scenes/main_menu_testing.tscn"

@onready var _selector_label := $Content/SelectorLabel as Label
@onready var _play_button := %PlayButton as Button
@onready var _level_grid := %LevelGrid as GridContainer


func _ready() -> void:
	PlayerProgress.load_progress()
	PlayerProgress.refresh_lives()
	_play_button.pressed.connect(_launch_campaign_level)
	_update_campaign_progress()
	_populate_level_selector()
	%StickyPreviewButton.visible = _is_dev_level_select_enabled()
	%StickyPreviewButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/testing/sticky_items_preview.tscn"))


func _update_campaign_progress() -> void:
	var current_level := PlayerProgress.get_current_level()
	var has_level_to_play := current_level <= MAX_LEVEL and _level_config_exists(current_level)
	if has_level_to_play:
		if PlayerProgress.get_lives() <= 0:
			_selector_label.text = "LEVEL %d" % current_level
			_play_button.text = "NO LIVES"
			_play_button.disabled = true
		else:
			_selector_label.text = "LEVEL %d" % current_level
			_play_button.text = "Play"
			_play_button.disabled = false
	else:
		_selector_label.text = "ALL LEVELS COMPLETE"
		_play_button.text = "COMPLETE"
		_play_button.disabled = true


func _populate_level_selector() -> void:
	for child in _level_grid.get_children():
		child.queue_free()

	var dev_level_select_enabled := _is_dev_level_select_enabled()
	_level_grid.visible = dev_level_select_enabled
	if not dev_level_select_enabled:
		return

	_selector_label.text = "DEVELOPER LEVELS"
	for level_number in range(MIN_LEVEL, MAX_LEVEL + 1):
		var button := Button.new()
		button.text = str(level_number)
		button.custom_minimum_size = Vector2(96, 88)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_launch_level.bind(level_number, true))
		_level_grid.add_child(button)


func _launch_campaign_level() -> void:
	PlayerProgress.refresh_lives()
	if PlayerProgress.get_lives() <= 0:
		_update_campaign_progress()
		return

	var current_level := PlayerProgress.get_current_level()
	if current_level > MAX_LEVEL or not _level_config_exists(current_level):
		return

	_launch_level(current_level, false)


func _launch_level(level_number: int, launched_from_dev_mode: bool) -> void:
	LevelTransition.launch_level(
		level_number,
		launched_from_dev_mode,
		TESTING_MENU_SCENE,
		{},
		self
	)


func _is_dev_level_select_enabled() -> bool:
	if ProjectSettings.has_setting(DEV_LEVEL_SELECT_SETTING):
		return bool(ProjectSettings.get_setting(DEV_LEVEL_SELECT_SETTING))

	return OS.is_debug_build()


func _level_config_exists(level_number: int) -> bool:
	return FileAccess.file_exists("res://configs/levels/level_%03d.json" % level_number)
