extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Chapter selection overlay verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress = root.get_node_or_null("PlayerProgress")
	_check(progress != null, "PlayerProgress autoload is available.")
	if progress == null:
		quit(1)
		return
	progress.reset_progress()

	var menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for _frame in range(5):
		await process_frame

	var level_button := menu.get_node("%LevelButton") as Button
	var chapter_button := menu.get_node("%ChapterButton") as Button
	chapter_button.emit_signal("pressed")
	await process_frame

	var selection := menu.get_node_or_null("ChapterSelectionScreen") as Control
	_check(selection != null, "The chapter button opens the selection screen.")
	if selection != null:
		_check(
			selection.z_index > level_button.z_index,
			"The chapter selection overlay renders above the level button."
		)
		_check(
			selection.z_index > chapter_button.z_index,
			"The chapter selection overlay renders above the chapter button."
		)
		_check(
			selection.mouse_filter == Control.MOUSE_FILTER_STOP,
			"The chapter selection overlay blocks input to main-menu controls beneath it."
		)

	menu.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Chapter selection overlay verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
