extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const ROUTER_SCENE := "res://scenes/app_launch_router.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVEL_SCENE := "res://level.tscn"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("App launch router verification must run through run_isolated_godot_test.ps1.")
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

	_check(
		str(ProjectSettings.get_setting("application/run/main_scene", "")) == ROUTER_SCENE,
		"The launch router is the project's main scene."
	)
	await _test_fresh_save_starts_in_level_one(progress)
	await _test_zero_lives_opens_main_menu(progress)
	await _test_beaten_first_level_opens_main_menu(progress)
	await _test_disabled_first_level_start_opens_main_menu(progress)

	if _failures.is_empty():
		print("App launch router verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_fresh_save_starts_in_level_one(progress) -> void:
	progress.reset_progress()
	var router := await _open_router()
	var loading_screen := _find_loading_screen()
	_check(loading_screen != null, "A fresh save starts the level loading screen at launch.")
	if loading_screen != null:
		var backdrop := loading_screen.get_node("%Backdrop") as ColorRect
		var material := backdrop.material as ShaderMaterial
		_check(
			is_equal_approx(float(material.get_shader_parameter("hole_radius")), 0.0),
			"The startup loading screen begins fully closed instead of closing over a blank screen."
		)

	await _wait_for_level_transition(router)
	var level := current_scene
	_check(
		level != null and level.scene_file_path == LEVEL_SCENE,
		"A fresh save opens the level scene instead of the Main Menu."
	)
	if level != null and level.scene_file_path == LEVEL_SCENE:
		_check(int(level.get("selected_level")) == 1, "The startup level is level 1.")
		_check(
			not bool(level.get("launched_from_dev_mode")),
			"The startup level is a campaign run that records progress."
		)
		_check(
			str(level.get("return_menu_scene_path")) == MAIN_MENU_SCENE,
			"Leaving the startup level returns to the production Main Menu."
		)
	await _free_current_scene()


func _test_zero_lives_opens_main_menu(progress) -> void:
	progress.reset_progress()
	while progress.get_lives() > 0:
		_check(progress.spend_life(), "Test setup spends one life.")
	await _open_router()
	await _wait_frames(5)
	_check_main_menu_opened("An unbeaten first level with no lives left opens the Main Menu.")
	await _free_current_scene()


func _test_beaten_first_level_opens_main_menu(progress) -> void:
	progress.reset_progress()
	_check(progress.complete_level(1, 0), "Test setup completes level 1.")
	await _open_router()
	await _wait_frames(5)
	_check_main_menu_opened("A beaten first level opens the Main Menu.")
	await _free_current_scene()


func _test_disabled_first_level_start_opens_main_menu(progress) -> void:
	progress.reset_progress()
	await _open_router(false)
	await _wait_frames(5)
	_check_main_menu_opened("Turning the first-level start off opens the Main Menu on a fresh save.")
	await _free_current_scene()


func _open_router(start_unbeaten_first_level := true) -> Node:
	var router := (load(ROUTER_SCENE) as PackedScene).instantiate()
	router.set("start_unbeaten_first_level", start_unbeaten_first_level)
	root.add_child(router)
	current_scene = router
	await process_frame
	return router


func _check_main_menu_opened(message: String) -> void:
	_check(current_scene != null and current_scene.scene_file_path == MAIN_MENU_SCENE, message)
	_check(_find_loading_screen() == null, "%s No loading screen is shown." % message)
	var transition := root.get_node_or_null("LevelTransition")
	_check(
		transition != null and not bool(transition.call("is_transitioning")),
		"%s No level launch is pending." % message
	)


func _find_loading_screen() -> Node:
	for child in root.get_children():
		if child is LevelLoadingScreen:
			return child
	return null


func _wait_for_level_transition(previous_scene: Node, timeout_seconds := 4.0) -> void:
	var transition := root.get_node_or_null("LevelTransition")
	_check(transition != null, "LevelTransition autoload is available.")
	if transition == null:
		return
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while (
		current_scene == previous_scene
		and not bool(transition.call("is_transitioning"))
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	while bool(transition.call("is_transitioning")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not bool(transition.call("is_transitioning")), "Level transition finishes before timeout.")
	await process_frame


func _free_current_scene() -> void:
	if current_scene != null:
		current_scene.queue_free()
	await _wait_frames(2)


func _wait_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
