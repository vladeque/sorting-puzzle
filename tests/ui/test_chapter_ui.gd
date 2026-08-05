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
		chapter_button.text == "CHAPTER 1",
		"The main menu chapter link does not identify the selected chapter."
	)
	_check(
		chapter_button.tooltip_text.contains("Grocery Town"),
		"The compact chapter button does not expose the selected chapter title."
	)
	_check(
		chapter_button.custom_minimum_size == Vector2(280.0, 74.0),
		"The main menu chapter button does not use its compact secondary-CTA size."
	)
	var action_column := menu.get_node("BottomBar/ActionColumn") as VBoxContainer
	_check(
		action_column.get_theme_constant("separation") == -12,
		"The chapter button's transparent edge is not tucked against the level button."
	)
	var chapter_button_style := chapter_button.get_theme_stylebox("normal") as StyleBoxTexture
	_check(chapter_button_style != null, "The main menu chapter button is missing its artwork.")
	if chapter_button_style != null:
		_check(
			chapter_button_style.texture != null
				and chapter_button_style.texture.resource_path
					== "res://assets/ui/level_button_blank_light_blue_new.png",
			"The main menu chapter button is not using the light-blue level-button artwork."
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
				is_equal_approx(current_card.size.x, pager.size.x),
				"The current chapter background should fill the pager width (got %s)." % current_card.size
			)
			var current_art := current_card.get_node("%Art") as TextureRect
			_check(
				current_art.texture != null
				and current_art.texture.resource_path == "res://assets/backgrounds/main_menu.jpeg",
				"Chapter 1 should reuse the main-menu background."
			)
			var current_progress := current_card.get_node("%ProgressBar") as ProgressBar
			_check(
				is_equal_approx(current_progress.value, 0.0)
				and is_equal_approx(current_progress.max_value, 10.0),
				"Chapter 1 should expose its exact current progress in the bottom panel."
			)
			_check(
				str(current_card.get_node("%ProgressValueLabel").text) == "0 / 10",
				"Chapter 1's progress value should be readable beside the bar."
			)

			var locked_card := track.get_child(1)
			var locked_cta := locked_card.get_node("%CtaButton") as Button
			_check(locked_cta.disabled, "Chapter 2 should be locked for a new player.")
			_check(
				str(locked_cta.text) == "LOCKED",
				"Chapter 2's CTA should read LOCKED while it is locked."
			)
			var locked_progress := locked_card.get_node("%ProgressBar") as ProgressBar
			_check(
				is_equal_approx(locked_progress.value, 0.0)
				and is_equal_approx(locked_progress.max_value, 25.0),
				"Chapter 2 does not show its exact unlock progress."
			)
			_check(
				str(locked_card.get_node("%ProgressValueLabel").text) == "0 / 25",
				"Chapter 2 does not label its exact unlock progress."
			)
			_check(
				str(locked_card.get_node("%StatusLabel").text)
				== "Complete 25 more Grocery Town levels to unlock",
				"Chapter 2 does not show its exact unlock requirement."
			)
			_check(
				(pager.get_node("%NextArrow") as Button).visible
				and not (pager.get_node("%PrevArrow") as Button).visible,
				"The first chapter should advertise the next page with only the right arrow."
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
			_check(
				pager.global_position.y >= 0.0
				and pager.global_position.y + pager.size.y <= logical_size.y + 1.0,
				"The chapter pager should remain a full-screen background at %s." % resolution
			)
			var current_card := (pager.get_node("%Track") as Control).get_child(0) as Control
			var info_panel := current_card.get_node("%InfoPanel") as Control
			_check(
				info_panel.global_position.x >= 0.0
				and info_panel.global_position.x + info_panel.size.x <= logical_size.x + 1.0
				and info_panel.global_position.y >= 0.0
				and info_panel.global_position.y + info_panel.size.y <= logical_size.y + 1.0,
				"The chapter information panel escaped the viewport at %s." % resolution
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
