extends SceneTree

## Verifies that the testing menu offers every Chapter 1 level instead of a hardcoded range, and
## that the picker still reaches an arbitrary level once the chapter grows to a few hundred entries.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
## Both scenes are loaded at run time: preloading them would compile menu scripts that reference
## autoload singletons before this script's own early compile has any of them registered.
const TESTING_MENU_SCENE_PATH := "res://scenes/main_menu_testing.tscn"
const PICKER_SCENE_PATH := "res://scenes/testing/dev_level_picker.tscn"
const LARGE_CHAPTER_LEVEL_COUNT := 500

var _failures: Array[String] = []
var _selected_levels: Array[int] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Dev level picker verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	ProjectSettings.set_setting("application/config/dev_level_select_enabled", true)
	var chapter_catalog := root.get_node_or_null(^"ChapterCatalog")
	_check(chapter_catalog != null, "ChapterCatalog autoload is available.")
	if chapter_catalog == null:
		_finish()
		return

	await _check_menu_lists_whole_chapter(chapter_catalog)
	await _check_picker_scales_to_a_large_chapter()
	_finish()


func _check_menu_lists_whole_chapter(chapter_catalog: Node) -> void:
	var chapter_id: String = chapter_catalog.call("get_first_chapter_id")
	var expected_levels: Array = chapter_catalog.call("get_level_ids", chapter_id)
	_check(expected_levels.size() > 10, "Chapter 1 has grown past the old ten-level dev grid.")

	var menu := (load(TESTING_MENU_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for _frame in range(4):
		await process_frame

	var picker := menu.get_node("%LevelPicker")
	var listed: PackedInt32Array = picker.call("get_level_numbers")
	var lists_whole_chapter := listed.size() == expected_levels.size()
	for level_index in range(mini(listed.size(), expected_levels.size())):
		lists_whole_chapter = lists_whole_chapter and listed[level_index] == int(
			expected_levels[level_index]
		)
	_check(
		lists_whole_chapter,
		"The testing menu lists exactly the Chapter 1 levels from the catalog."
	)
	var last_level: int = expected_levels.back() if not expected_levels.is_empty() else 0
	_check(
		picker.call("get_level_button", last_level) != null,
		"The last Chapter 1 level has a selectable button."
	)

	menu.queue_free()
	await process_frame


func _check_picker_scales_to_a_large_chapter() -> void:
	var levels := PackedInt32Array()
	for level_number in range(1, LARGE_CHAPTER_LEVEL_COUNT + 1):
		levels.append(level_number)

	var host := Control.new()
	host.size = Vector2(720, 700)
	root.add_child(host)
	var picker := (load(PICKER_SCENE_PATH) as PackedScene).instantiate() as Control
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(picker)
	picker.connect("level_selected", Callable(self, "_on_level_selected"))
	picker.call("set_levels", levels, LARGE_CHAPTER_LEVEL_COUNT)
	for _frame in range(4):
		await process_frame

	var grid := picker.get_node("%LevelGrid") as GridContainer
	var scroll := picker.get_node("%LevelScroll") as ScrollContainer
	_check(
		grid.get_child_count() == LARGE_CHAPTER_LEVEL_COUNT,
		"A 500-level chapter produces one button per level."
	)
	_check(
		grid.columns >= 3,
		"The grid keeps at least three columns at the design width."
	)
	_check(
		grid.size.y > scroll.size.y and scroll.get_v_scroll_bar().visible,
		"A 500-level grid scrolls instead of overflowing the menu."
	)
	var focus_button := picker.call("get_level_button", LARGE_CHAPTER_LEVEL_COUNT) as Button
	var focus_top := focus_button.position.y - float(scroll.scroll_vertical)
	_check(
		focus_top >= 0.0 and focus_top + focus_button.size.y <= scroll.size.y,
		"The picker scrolls the requested level into view instead of resting at level 1."
	)

	var typed_level := 473
	var level_input := picker.get_node("%LevelInput") as LineEdit
	level_input.text = "47x3"
	level_input.emit_signal("text_changed", level_input.text)
	_check(level_input.text == "473", "The jump field keeps digits only.")
	level_input.emit_signal("text_submitted", level_input.text)
	await process_frame
	_check(
		_selected_levels == [typed_level],
		"Typing a level number launches that level directly."
	)

	var status_label := picker.get_node("%StatusLabel") as Label
	level_input.text = str(LARGE_CHAPTER_LEVEL_COUNT + 1)
	level_input.emit_signal("text_submitted", level_input.text)
	await process_frame
	_check(
		_selected_levels == [typed_level] and status_label.text.contains("not in this chapter"),
		"A level outside the chapter is reported instead of launched."
	)

	host.queue_free()
	await process_frame


func _on_level_selected(level_number: int) -> void:
	_selected_levels.append(level_number)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dev level picker verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
