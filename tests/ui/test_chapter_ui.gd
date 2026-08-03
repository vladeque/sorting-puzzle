extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const TEST_RESOLUTIONS := [
	Vector2i(540, 960),
	Vector2i(720, 1280),
	Vector2i(1080, 1920),
	Vector2i(1080, 2400),
	Vector2i(1200, 1600),
]

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Chapter UI verification must run through run_isolated_godot_test.ps1.")
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
	var main_menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	var menu := main_menu_scene.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for _frame in range(5):
		await process_frame

	var level_button := menu.get_node("%LevelButton") as Button
	var chapter_button := menu.get_node("%ChapterButton") as Button
	_check(level_button.text == "LEVEL 1", "The default chapter does not offer its first level.")
	_check(
		str(chapter_button.get_node("%ChapterLabel").text).contains("GROCERY TOWN"),
		"The main menu does not identify the selected chapter."
	)

	chapter_button.emit_signal("pressed")
	await process_frame
	var selection := menu.get_node_or_null("ChapterSelectionScreen") as Control
	_check(selection != null, "The chapter button did not open the selection screen.")
	if selection != null:
		var pager := selection.get_node("%Pager") as Control
		var track := pager.get_node("%Track") as Control
		_check(track.get_child_count() == 2, "Expected two configured chapter covers.")
		if track.get_child_count() == 2:
			var current_card := track.get_child(0) as Control
			var current_cta := current_card.get_node("%CtaButton") as Button
			_check(not current_cta.disabled, "Chapter 1 should be playable for a new player.")
			_check(
				current_card.size.x > 100.0 and current_card.size.x <= pager.size.x,
				"The current chapter cover was not sized by the pager (got %s)." % current_card.size
			)

			var locked_card := track.get_child(1)
			var locked_cta := locked_card.get_node("%CtaButton") as Button
			_check(locked_cta.disabled, "Chapter 2 should be locked for a new player.")
			_check(
				str(locked_cta.text) == "LOCKED",
				"Chapter 2's CTA should read LOCKED while it is locked."
			)
			var locked_ring := locked_card.get_node("%Ring") as ProgressRing
			_check(
				locked_ring.get_progress_current() == 0 and locked_ring.get_progress_total() == 25,
				"Chapter 2 does not show its exact unlock progress."
			)
			_check(
				str(locked_card.get_node("%CaptionLabel").text) == "Complete 25 levels in the previous chapter",
				"Chapter 2 does not show its exact unlock requirement."
			)

	for resolution in TEST_RESOLUTIONS:
		root.size = resolution
		for _frame in range(3):
			await process_frame
		var logical_size := menu.get_viewport_rect().size
		var bottom_bar := menu.get_node("%BottomBar") as Control
		var navigation := menu.get_node("%BottomNavigation") as Control
		_check(bottom_bar.position.x >= 0.0, "Chapter actions escaped the left edge at %s." % resolution)
		_check(
			bottom_bar.position.x + bottom_bar.size.x <= logical_size.x + 1.0,
			"Chapter actions escaped the right edge at %s." % resolution
		)
		_check(
			bottom_bar.position.y + bottom_bar.size.y <= navigation.position.y + 1.0,
			"Chapter actions overlap bottom navigation at %s." % resolution
		)
		if selection != null:
			var pager := selection.get_node("%Pager") as Control
			_check(
				pager.global_position.x >= 0.0,
				"The chapter pager escaped the left edge at %s." % resolution
			)
			_check(
				pager.global_position.x + pager.size.x <= logical_size.x + 1.0,
				"The chapter pager escaped the right edge at %s." % resolution
			)

	var background_scene := load("res://scenes/backgrounds/chapter_level_background.tscn") as PackedScene
	var chapter_background := background_scene.instantiate() as TextureRect
	root.add_child(chapter_background)
	chapter_background.call("show_chapter", "chapter_01")
	_check(chapter_background.texture != null, "Chapter 1 gameplay background did not load.")
	var chapter_one_path := chapter_background.texture.resource_path
	chapter_background.call("show_chapter", "chapter_02")
	_check(chapter_background.texture != null, "Chapter 2 gameplay background did not load.")
	_check(
		chapter_background.texture.resource_path != chapter_one_path,
		"Chapters 1 and 2 should have different gameplay backgrounds."
	)

	var level_scene := load("res://level.tscn") as PackedScene
	var chapter_one_level = level_scene.instantiate()
	chapter_one_level.selected_level = 1
	chapter_one_level.launched_from_dev_mode = true
	root.add_child(chapter_one_level)
	for _frame in range(3):
		await process_frame
	_check(
		not (chapter_one_level.get_node("Background/ChapterArtwork") as CanvasItem).visible,
		"Chapter 1 should not show full-screen chapter artwork during gameplay."
	)
	for legacy_node_path in ["Wall", "PlayWall", "Baseboard", "Floor"]:
		_check(
			(chapter_one_level.get_node("Background/%s" % legacy_node_path) as CanvasItem).visible,
			"Chapter 1 should restore its original %s background layer." % legacy_node_path
		)

	menu.queue_free()
	chapter_background.queue_free()
	chapter_one_level.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Chapter UI verification passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
