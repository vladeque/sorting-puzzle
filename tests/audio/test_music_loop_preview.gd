extends SceneTree

const PREVIEW_SCENE_PATH := "res://scenes/testing/music_loop_preview.tscn"
const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Music preview verification must use run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress := root.get_node("PlayerProgress")
	progress.call("set_setting_disabled", &"music", true)
	var saved_settings: Dictionary = progress.call("get_disabled_settings")
	var saved_level := int(progress.call("get_current_level"))
	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(preview)
	current_scene = preview
	await process_frame
	var player := preview.get_node("Soundtrack") as AudioStreamPlayer
	var game_player := root.get_node("MusicManager/Soundtrack") as AudioStreamPlayer
	_check(not player.playing, "The preview waits for a deliberate Play press.")
	_check(not game_player.playing, "The game autoload stays silent on the listening preview.")
	_check(player.stream == game_player.stream and player.volume_db == game_player.volume_db
		and player.bus == game_player.bus, "The preview shares the production stream, volume, and bus.")
	_check(is_equal_approx(float(preview.get("seconds_before_loop")), 5.0),
		"The default listening window begins five seconds before the loop.")
	for button_name in ["SeamButton", "BeginningButton", "PauseButton", "StopButton"]:
		_check(bool(root.get_node("SfxManager").call("is_button_click_suppressed",
			preview.get_node("%" + button_name))), "Preview controls keep button clicks out of the music.")

	# Shorten only this automated listening window; it still exercises the actual native wrap.
	preview.set("seconds_before_loop", 0.3)
	preview.get_node("%SeamButton").emit_signal("pressed")
	await create_timer(0.6).timeout
	var stream := player.stream as AudioStreamOggVorbis
	_check(player.playing and not player.stream_paused, "The preview plays even with saved Music Off.")
	_check(int(preview.get("_loops_heard")) >= 1, "The loop counter observes a real native wrap.")
	_check(player.get_playback_position() >= stream.loop_offset
		and player.get_playback_position() < stream.loop_offset + 1.0,
		"Playback continues at the production loop offset.")
	_check((preview.get_node("%PhaseLabel") as Label).text.begins_with("Loop passed"),
		"The listener sees confirmation after the seam passes.")
	var decoder := player.get_stream_playback()
	preview.get_node("%PauseButton").emit_signal("pressed")
	await create_timer(0.08).timeout
	var paused_position := player.get_playback_position()
	await create_timer(0.1).timeout
	_check(player.stream_paused and absf(player.get_playback_position() - paused_position) < 0.025,
		"Pause freezes the preview at its current position.")
	preview.get_node("%PauseButton").emit_signal("pressed")
	_check(not player.stream_paused and player.get_stream_playback() == decoder,
		"Resume keeps the existing preview decoder.")
	decoder = null
	preview.get_node("%BeginningButton").emit_signal("pressed")
	await process_frame
	_check(player.get_playback_position() < 1.0 and int(preview.get("_loops_heard")) == 0,
		"From beginning plays the intro and resets the loop counter.")
	preview.get_node("%StopButton").emit_signal("pressed")
	_check(not player.playing and (preview.get_node("%PauseButton") as Button).disabled,
		"Stop ends preview playback and disables Pause.")
	_check(progress.call("get_disabled_settings") == saved_settings
		and int(progress.call("get_current_level")) == saved_level,
		"Preview transport leaves saved preferences and progression unchanged.")
	preview.queue_free()
	await create_timer(0.1).timeout
	if _failures.is_empty():
		print("Music loop preview verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
