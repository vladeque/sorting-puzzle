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
	var menu_background := menu.get_node("%Background") as TextureRect
	var warm_normal := load("res://assets/themes/style_box_warm_icon_normal.tres") as StyleBoxFlat
	var warm_pressed := load("res://assets/themes/style_box_warm_icon_pressed.tres") as StyleBoxFlat
	var status_counter_pill := load(
		"res://assets/themes/style_box_status_counter_pill.tres"
	) as StyleBoxFlat
	var orange_normal := load(
		"res://assets/themes/style_box_orange_utility_normal.tres"
	) as StyleBoxFlat
	_check(
		menu_background.texture != null
			and menu_background.texture.resource_path == "res://assets/backgrounds/main_menu.jpeg",
		"The production menu should start with the selected Chapter 1 background."
	)
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
					== "res://assets/ui/level_button_blank_yellow_orange_new.png",
			"The main menu chapter button is not using the yellow-orange level-button artwork."
		)
	_check(
		chapter_button.get_theme_color("font_color") == Color.WHITE
			and chapter_button.get_theme_color("font_pressed_color") == Color.WHITE
			and chapter_button.get_theme_color("font_outline_color")
				== Color(0.46, 0.16, 0.02, 0.95),
		"The yellow-orange Chapter button does not use its shared white/brown text treatment."
	)
	var settings_button := menu.get_node(
		"TopStatusBar/MainMenuTopStatus/SettingsWidget/SettingsButton"
	) as Button
	_check(
		settings_button.get_theme_stylebox("normal") == warm_normal
			and settings_button.get_theme_stylebox("pressed") == warm_pressed,
		"The Main Menu Settings button is not using the shared warm icon-button styles."
	)
	var coin_pill := menu.get_node(
		"TopStatusBar/MainMenuTopStatus/CoinsWidget/CoinBalanceWidget/Pill"
	) as Panel
	var lives_pill := menu.get_node(
		"TopStatusBar/MainMenuTopStatus/LivesWidget/LivesPill"
	) as Panel
	var life_status := menu.get_node(
		"TopStatusBar/MainMenuTopStatus/LivesWidget/LifeStatus"
	) as Label
	_check(
		coin_pill.get_theme_stylebox("panel") == status_counter_pill
			and lives_pill.get_theme_stylebox("panel") == status_counter_pill,
		"The Main Menu coin and lives counters should use the shared status-pill background."
	)
	_check(
		coin_pill.size == lives_pill.size,
		"The Main Menu coin and lives pill backgrounds should use the same compact size."
	)
	_check(
		is_equal_approx(
			life_status.position.y + life_status.size.y * 0.5,
			lives_pill.position.y + lives_pill.size.y * 0.5
		),
		"The life status text should be vertically centered in its pill background."
	)
	var reward_dialog_close := menu.get_node(
		"LeaderboardRewardDialog/Center/Panel/Stack/CloseButton"
	) as Button
	_check(
		reward_dialog_close.get_theme_stylebox("normal") == orange_normal,
		"The Leaderboard reward dialog is not using the shared orange utility style."
	)

	chapter_button.emit_signal("pressed")
	await process_frame
	var selection := menu.get_node_or_null("ChapterSelectionScreen") as Control
	_check(selection != null, "The chapter button did not open the selection screen.")
	if selection != null:
		var pager := selection.get_node("%Pager") as Control
		var back_button := selection.get_node("%BackButton") as Button
		var previous_button := pager.get_node("%PrevArrow") as Button
		var next_button := pager.get_node("%NextArrow") as Button
		_check(
			back_button.get_theme_stylebox("normal") == warm_normal
				and back_button.get_theme_stylebox("pressed") == warm_pressed
				and previous_button.get_theme_stylebox("normal") == warm_normal
				and previous_button.get_theme_stylebox("pressed") == warm_pressed
				and next_button.get_theme_stylebox("normal") == warm_normal
				and next_button.get_theme_stylebox("pressed") == warm_pressed,
			"Chapter Back and pager arrows should share one warm icon-button style pair."
		)
		_check(
			warm_normal.corner_radius_top_left == 16
				and warm_normal.corner_radius_top_right == 16
				and warm_normal.corner_radius_bottom_right == 16
				and warm_normal.corner_radius_bottom_left == 16,
			"Warm icon buttons should use the shared 16 px button-radius role."
		)
		var track := pager.get_node("%Track") as Control
		_check(track.get_child_count() == 2, "Expected two configured chapter covers.")
		if track.get_child_count() == 2:
			var current_card := track.get_child(0) as Control
			var current_cta := current_card.get_node("%CtaButton") as Button
			_check(not current_cta.disabled, "Chapter 1 should be playable for a new player.")
			var info_margins := current_card.get_node("%InfoMargins") as MarginContainer
			_check(
				is_equal_approx(info_margins.offset_top, -324.0)
					and is_equal_approx(info_margins.offset_bottom, -30.0),
				"The chapter information panel should use its expanded 294 px authored height (offsets: %s / %s; size: %s)."
					% [info_margins.offset_top, info_margins.offset_bottom, info_margins.size]
			)
			for style_state in [&"normal", &"hover", &"pressed"]:
				var current_cta_style := current_cta.get_theme_stylebox(style_state) as StyleBoxFlat
				_check(
					current_cta_style != null
						and current_cta_style.bg_color.g > current_cta_style.bg_color.r,
					"The actionable Chapter CTA's %s state should use a flat green style."
						% style_state
				)
			var current_cta_normal := current_cta.get_theme_stylebox("normal") as StyleBoxFlat
			_check(
				current_cta_normal != null
					and current_cta_normal.bg_color == Color(0.21, 0.81, 0.11, 1),
				"The Chapter CTA should use the sampled glossy level-button green palette."
			)
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
			var locked_art := locked_card.get_node("%Art") as TextureRect
			_check(
				locked_art.texture != null
					and locked_art.texture.resource_path
						== "res://assets/backgrounds/chapter_02_witch_apothecary.png",
				"Chapter 2 should show the witch apothecary cover art."
			)
			var locked_cta := locked_card.get_node("%CtaButton") as Button
			_check(locked_cta.disabled, "Chapter 2 should be locked for a new player.")
			var locked_info_margins := locked_card.get_node("%InfoMargins") as MarginContainer
			_check(
				is_equal_approx(locked_info_margins.offset_top, -370.0)
					and is_equal_approx(locked_info_margins.offset_bottom, -30.0),
				"The locked chapter information panel should use its expanded 340 px height."
			)
			_check(
				str(locked_cta.text) == "Locked",
				"Chapter 2's CTA should read Locked while it is locked."
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
			selection.emit_signal("chapter_selected", "chapter_02")
			await process_frame
			_check(
				menu_background.texture != null
					and menu_background.texture.resource_path
						== "res://assets/backgrounds/chapter_02_witch_apothecary.png",
				"The production menu background should change with the selected chapter."
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

	if selection != null:
		root.size = Vector2i(720, 1280)
		for _frame in range(3):
			await process_frame

		## The real safe-area lookup always yields Vector4.ZERO outside Android/iOS, so this
		## directly exercises _apply_safe_margins() with a fabricated inset -- the only way to
		## prove the back button, title, page arrows/indicators, and each card's information
		## panel actually respect a non-zero inset while the full-bleed art underneath does not.
		var simulated_margins := Vector4(40.0, 60.0, 50.0, 80.0)
		selection.call("_apply_safe_margins", simulated_margins)
		await process_frame

		var header_margins := selection.get_node("%HeaderMargins") as Control
		_check(
			is_equal_approx(header_margins.offset_left, simulated_margins.x)
				and is_equal_approx(header_margins.offset_top, simulated_margins.y)
				and is_equal_approx(header_margins.offset_right, -simulated_margins.z),
			"Chapter Selection's header did not respect the simulated safe-area inset."
		)

		var pager := selection.get_node("%Pager") as Control
		var prev_arrow := pager.get_node("%PrevArrow") as Control
		var next_arrow := pager.get_node("%NextArrow") as Control
		var dots := pager.get_node("%Dots") as Control
		_check(
			is_equal_approx(prev_arrow.offset_left, 2.0 + simulated_margins.x),
			"The pager's previous arrow did not shift inward for the simulated left inset."
		)
		_check(
			is_equal_approx(next_arrow.offset_right, -2.0 - simulated_margins.z),
			"The pager's next arrow did not shift inward for the simulated right inset."
		)
		_check(
			is_equal_approx(dots.offset_bottom, -10.0 - simulated_margins.w),
			"The pager's page indicators did not clear the simulated bottom inset."
		)

		var track := pager.get_node("%Track") as Control
		var current_card := track.get_child(0) as Control
		var current_art := current_card.get_node("%Art") as Control
		_check(
			is_equal_approx(current_art.offset_left, 0.0) and is_equal_approx(current_art.offset_right, 0.0),
			"Chapter cover art should stay full-bleed under a simulated safe-area inset."
		)
		var info_margins := current_card.get_node("%InfoMargins") as Control
		_check(
			is_equal_approx(info_margins.offset_left, 30.0 + simulated_margins.x)
				and is_equal_approx(info_margins.offset_right, -(30.0 + simulated_margins.z))
				and is_equal_approx(info_margins.offset_bottom, -(30.0 + simulated_margins.w)),
			"The chapter information panel did not respect the simulated safe-area inset."
		)

		# Restore a zero inset so later checks and cleanup see the normal, unshifted layout.
		selection.call("_apply_safe_margins", Vector4.ZERO)
		await process_frame

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
