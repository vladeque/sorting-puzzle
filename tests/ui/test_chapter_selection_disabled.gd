extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Disabled chapter-selection verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress = root.get_node_or_null("PlayerProgress")
	var chapter_catalog = root.get_node_or_null("ChapterCatalog")
	_check(progress != null, "PlayerProgress autoload is available.")
	_check(chapter_catalog != null, "ChapterCatalog autoload is available.")
	if progress == null or chapter_catalog == null:
		quit(1)
		return
	progress.reset_progress()

	_check(
		not bool(ProjectSettings.get_setting(
			"application/config/chapter_selection_enabled",
			true
		)),
		"Chapter selection is disabled by default for the release build."
	)

	var menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for _frame in range(5):
		await process_frame

	var chapter_button := menu.get_node("%ChapterButton") as Button
	_check(not chapter_button.visible, "The disabled chapter button is hidden.")
	_check(chapter_button.disabled, "The disabled chapter button cannot receive an action.")
	menu.call("_open_chapter_selection")
	await process_frame
	_check(
		menu.get_node_or_null("ChapterSelectionScreen") == null,
		"The disabled chapter-selection screen cannot be opened through its handler."
	)

	var level_button := menu.get_node("%LevelButton") as Button
	menu.call("_update_level_button")
	_check(level_button.text == "LEVEL 1", "Campaign play remains available with chapters hidden.")
	for level_id in chapter_catalog.get_level_ids("chapter_01"):
		_check(progress.complete_level(level_id, 0), "Chapter 1 level %d completion commits." % level_id)
	menu.call("_update_level_button")
	_check(
		level_button.text == "MORE LEVELS COMING SOON",
		"Completed Chapter 1 uses the release-facing final campaign label."
	)
	_check(level_button.disabled, "The final campaign label remains non-interactive.")

	menu.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Disabled chapter-selection verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
