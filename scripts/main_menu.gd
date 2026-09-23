extends Control

const MIN_LEVEL := 1
## Upper bound for the fallback config scan. The `%03d` level config name stops being unique above
## it, and no chapter is expected to reach that size.
const MAX_SCANNED_LEVEL := 999
const LEVEL_CONFIG_PATH_TEMPLATE := "res://configs/levels/level_%03d.json"
const DEV_LEVEL_SELECT_SETTING := "application/config/dev_level_select_enabled"
const TESTING_MENU_SCENE := "res://scenes/main_menu_testing.tscn"

@onready var _selector_label := $Content/SelectorLabel as Label
@onready var _play_button := %PlayButton as Button
@onready var _level_picker := %LevelPicker as DevLevelPicker

var _campaign_level_numbers := PackedInt32Array()


func _ready() -> void:
	PlayerProgress.load_progress()
	PlayerProgress.refresh_lives()
	_campaign_level_numbers = _collect_campaign_level_numbers()
	_play_button.pressed.connect(_launch_campaign_level)
	_level_picker.level_selected.connect(_launch_dev_level)
	_update_campaign_progress()
	_populate_level_selector()
	%StickyPreviewButton.visible = _is_dev_level_select_enabled()
	%StickyPreviewButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/testing/sticky_items_preview.tscn"))
	%CollapsingColumnsPreviewButton.visible = _is_dev_level_select_enabled()
	%CollapsingColumnsPreviewButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/testing/collapsing_columns_preview.tscn"))
	%ThrowingDispensersPreviewButton.visible = _is_dev_level_select_enabled()
	%ThrowingDispensersPreviewButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/testing/throwing_dispensers_preview.tscn"))


func _update_campaign_progress() -> void:
	var current_level := PlayerProgress.get_current_level()
	if _is_campaign_level(current_level):
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
	var dev_level_select_enabled := _is_dev_level_select_enabled()
	_level_picker.visible = dev_level_select_enabled
	if not dev_level_select_enabled:
		return

	_selector_label.text = "DEVELOPER LEVELS"
	_level_picker.set_levels(_campaign_level_numbers, PlayerProgress.get_current_level())


## The testing menu offers every level of the first chapter, so the catalog owns the list and this
## menu never repeats a hardcoded level count.
func _collect_campaign_level_numbers() -> PackedInt32Array:
	var level_numbers := PackedInt32Array()
	if ChapterCatalog.is_valid():
		for level_id in ChapterCatalog.get_level_ids(ChapterCatalog.get_first_chapter_id()):
			level_numbers.append(level_id)
	if level_numbers.is_empty():
		level_numbers = _scan_level_configs()
	return level_numbers


## Fallback for a missing or invalid chapter catalog: walk the shipped level configs from the first
## one until the numbering stops, so a broken catalog still leaves the dev menu usable.
func _scan_level_configs() -> PackedInt32Array:
	var level_numbers := PackedInt32Array()
	for level_number in range(MIN_LEVEL, MAX_SCANNED_LEVEL + 1):
		if not _level_config_exists(level_number):
			break
		level_numbers.append(level_number)
	return level_numbers


func _launch_campaign_level() -> void:
	PlayerProgress.refresh_lives()
	if PlayerProgress.get_lives() <= 0:
		_update_campaign_progress()
		return

	var current_level := PlayerProgress.get_current_level()
	if not _is_campaign_level(current_level):
		return

	_launch_level(current_level, false)


func _launch_dev_level(level_number: int) -> void:
	_launch_level(level_number, true)


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


func _is_campaign_level(level_number: int) -> bool:
	return _campaign_level_numbers.has(level_number) and _level_config_exists(level_number)


func _level_config_exists(level_number: int) -> bool:
	return FileAccess.file_exists(LEVEL_CONFIG_PATH_TEMPLATE % level_number)
