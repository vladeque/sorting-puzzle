extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Main-menu modal overlay verification must run through run_isolated_godot_test.ps1.")
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
		_check_overlay_above_actions(selection, level_button, chapter_button, "Chapter selection")
		_check(
			selection.mouse_filter == Control.MOUSE_FILTER_STOP,
			"The chapter selection overlay blocks input to main-menu controls beneath it."
		)
		selection.queue_free()
		await process_frame

	menu.call("_open_profile_menu")
	await process_frame
	var profile_menu := menu.get_node_or_null("ProfileMenu") as Control
	_check(profile_menu != null, "The profile button opens the profile modal.")
	if profile_menu != null:
		_check_overlay_above_actions(profile_menu, level_button, chapter_button, "Profile modal")
		profile_menu.queue_free()
		await process_frame

	menu.call("_open_settings_menu")
	await process_frame
	var settings_menu := menu.get_node_or_null("MainMenuSettingsOverlay") as Control
	_check(settings_menu != null, "The settings button opens the settings modal.")
	if settings_menu != null:
		_check_overlay_above_actions(settings_menu, level_button, chapter_button, "Settings modal")
		var support_button := settings_menu.find_child("SupportButton", true, false) as Button
		_check(support_button != null, "Settings retains its Support action.")
		if support_button != null:
			support_button.pressed.emit()
			await process_frame
			var support_screen := menu.get_node_or_null("SupportScreen") as Control
			_check(support_screen != null, "Support opens the native FAQ screen.")
			if support_screen != null:
				_check_overlay_above_actions(
					support_screen, level_button, chapter_button, "Support screen"
				)
				support_screen.queue_free()
				await process_frame
		settings_menu.queue_free()
		await process_frame

	menu.call("_open_reward_chest_menu")
	await process_frame
	var reward_chest_menu := menu.get_node_or_null("RewardChestMenu") as Control
	_check(reward_chest_menu != null, "The reward chest opens its detail modal.")
	if reward_chest_menu != null:
		_check_overlay_above_actions(
			reward_chest_menu,
			level_button,
			chapter_button,
			"Reward chest modal"
		)

	var leaderboard_reward_dialog := menu.get_node("%LeaderboardRewardDialog") as Control
	_check_overlay_above_actions(
		leaderboard_reward_dialog,
		level_button,
		chapter_button,
		"Leaderboard reward dialog"
	)

	menu.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Main-menu modal overlay verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _check_overlay_above_actions(
	overlay: Control,
	level_button: Button,
	chapter_button: Button,
	label: String
) -> void:
	_check(
		overlay.z_index > level_button.z_index,
		"%s renders above the level button." % label
	)
	_check(
		overlay.z_index > chapter_button.z_index,
		"%s renders above the chapter button." % label
	)
