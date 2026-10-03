extends SceneTree

## Exercise the actual level, pause/settings UI, scene replacements, and Vorbis decoder. Run via
## scripts/tools/run_isolated_godot_test.ps1 so the saved Music toggle never touches a real save.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"
const MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const MUSIC_MANIFEST := "res://assets/audio/music/corner_shop_sorting_loop.json"

var _failures: Array[String] = []
var _manager: Node
var _progress: Node
var _player: AudioStreamPlayer
var _initial_playback: AudioStreamPlayback
var _level_scene: PackedScene


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Music verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_manager = root.get_node_or_null(^"MusicManager")
	_progress = root.get_node_or_null(^"PlayerProgress")
	if _manager == null or _progress == null:
		push_error("MusicManager and PlayerProgress are required.")
		quit(1)
		return
	_player = _manager.get_node("Soundtrack") as AudioStreamPlayer
	_check(bool(_manager.call("is_muted")), "Headless runs start with music muted.")
	_check(not _player.playing, "Music does not autoplay before entering a level.")
	_test_asset_and_bus()
	_progress.call("set_setting_disabled", &"music", false)
	_manager.call("set_muted", false)
	await _open_scene(MENU_SCENE_PATH)
	_check(not _player.playing, "The main menu does not start the soundtrack.")
	_level_scene = load(LEVEL_SCENE_PATH) as PackedScene
	var level := await _open_level(2)
	_check(_player.playing and not _player.stream_paused, "Active gameplay starts music.")
	_initial_playback = _player.get_stream_playback()
	_check(_initial_playback != null, "The soundtrack has a persistent stream decoder.")
	_player.seek(35.0)
	await _wait_frames(3)
	# AudioStreamPlayer.seek() itself replaces the decoder; record the reference after this test
	# setup seek. The music owner never seeks or calls play() again.
	_initial_playback = _player.get_stream_playback()
	await _test_pause_and_settings(level)
	await _test_gameplay_gates(level)
	await _test_restart(level)
	await _test_next_level()
	await _test_menu_return()
	await _test_native_loop()
	_manager.call("set_muted", true)
	if current_scene != null:
		current_scene.queue_free()
	await _wait_frames(2)
	_initial_playback = null
	_level_scene = null
	# Release the test's last sounding stream before shutting down the audio server. Production
	# code deliberately never stops this player; this is only isolated-test teardown.
	_player.stop()
	await create_timer(0.1).timeout
	if _failures.is_empty():
		print("Level music verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_asset_and_bus() -> void:
	var bus_index := AudioServer.get_bus_index(&"Music")
	_check(bus_index >= 0 and _player.bus == &"Music", "Music has its own bus and player.")
	if bus_index >= 0:
		_check(AudioServer.get_bus_send(bus_index) == &"Master", "Music passes through the Master limiter.")
	var stream := _player.stream as AudioStreamOggVorbis
	_check(stream != null, "The soundtrack uses compressed Ogg Vorbis.")
	if stream == null:
		return
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MUSIC_MANIFEST)) as Dictionary
	_check(not manifest.is_empty(), "Loop preparation and measurements are recorded.")
	_check(stream.loop, "Looping is enabled in the imported stream.")
	_check(absf(stream.loop_offset - float(manifest.loop_offset_seconds)) < 0.001,
		"The native loop starts after the crossfaded phrase instead of replaying the intro.")
	_check(absf(stream.get_length() - float(manifest.duration_seconds)) < 0.01,
		"The imported soundtrack ends at the prepared loop boundary.")
	_check(FileAccess.get_sha256(str(manifest.path)) == str(manifest.sha256),
		"The loop manifest matches the committed Ogg bytes.")
	var measurements := manifest.decoded_measurements as Dictionary
	_check(float(measurements.true_peak_dbtp) <= -3.0, "The decoded music asset has peak headroom.")
	var runtime_loudness := float(measurements.integrated_lufs) + _player.volume_db
	_check(runtime_loudness >= -29.0 and runtime_loudness <= -25.0,
		"Music stays inside the -27 +/- 2 LUFS-I background mix policy.")


func _test_pause_and_settings(level: Node) -> void:
	level.call("_on_pause_menu_button_pressed")
	await _wait_frames(4)
	_check(_player.stream_paused, "The pause menu pauses the soundtrack.")
	await _check_position_frozen("pause menu")
	var pause_menu := level.get_node("UI/PauseMenuOverlay")
	var music_button := pause_menu.find_child("MusicButton", true, false) as Button
	# Wait for the pause shell's animation before pressing its settings controls.
	await create_timer(0.4).timeout
	music_button.pressed.emit()
	await _wait_frames(2)
	_check(bool(_progress.call("is_setting_disabled", &"music")), "The Music button saves its disabled state.")
	level.set("_level_paused", false)
	_manager.call("refresh_playback")
	_check(_player.stream_paused, "Music Off stays silent when gameplay resumes.")
	music_button.pressed.emit()
	await _wait_frames(2)
	_check(not _player.stream_paused, "Music On resumes the existing stream during gameplay.")
	_check(_player.get_playback_position() > 34.0, "Music toggling does not rewind the soundtrack.")
	_check_decoder("Music toggling")
	_progress.call("set_setting_disabled", &"sound_effects", true)
	await _wait_frames(2)
	_check(not _player.stream_paused, "Sound Effects Off does not mute music.")
	_progress.call("set_setting_disabled", &"sound_effects", false)
	_manager.call("set_muted", true)
	_check(_player.stream_paused, "Capture/test muting pauses the music immediately.")
	_manager.call("set_muted", false)
	_check_decoder("capture/test mute")


func _test_gameplay_gates(level: Node) -> void:
	for flag in ["_level_paused", "_level_failed", "_level_completed", "_app_interrupted",
		"_loading_transition_pending", "_returning_to_menu"]:
		level.set(flag, true)
		await _wait_frames(2)
		_check(_player.stream_paused, "%s pauses music." % flag)
		await _check_position_frozen(flag)
		level.set(flag, false)
		await _wait_frames(2)
		_check(not _player.stream_paused, "Clearing %s resumes music." % flag)
		_check_decoder(flag)
	level.set("_level_config_error", "invalid test configuration")
	await _wait_frames(2)
	_check(_player.stream_paused, "Invalid levels stay silent.")
	level.set("_level_config_error", "")
	paused = true
	await _wait_frames(2)
	_check(_player.stream_paused, "A SceneTree pause also suspends music.")
	paused = false
	_manager.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(_player.stream_paused, "Backgrounding the application immediately pauses music.")
	_manager.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _wait_frames(2)
	_check_decoder("application resume")


func _test_restart(level: Node) -> void:
	var position_before := _player.get_playback_position()
	level.call("_restart_level")
	await _wait_for_transition()
	_check(current_scene != level and int(current_scene.get("selected_level")) == 2,
		"Restart replaces the actual level scene.")
	_check(not _player.stream_paused, "Restart resumes music after the loading reveal.")
	_check(absf(_player.get_playback_position() - position_before) < 0.6,
		"Restart retains the soundtrack position through loading.")
	_check_decoder("level restart")


func _test_next_level() -> void:
	var previous := current_scene
	previous.set("_level_completed", true)
	await _wait_frames(2)
	var position_before := _player.get_playback_position()
	root.get_node("LevelTransition").call("launch_level", 3, true, MENU_SCENE_PATH, {}, previous)
	await _wait_for_transition()
	_check(current_scene != previous and int(current_scene.get("selected_level")) == 3,
		"Next-level launch replaces the scene with the requested level.")
	_check(not _player.stream_paused, "Next-level gameplay resumes the music.")
	_check(absf(_player.get_playback_position() - position_before) < 0.6,
		"The next level retains the soundtrack position.")
	_check_decoder("next level")


func _test_menu_return() -> void:
	current_scene.call("_return_to_main_menu")
	await _wait_frames(5)
	_check(current_scene.scene_file_path == MENU_SCENE_PATH, "Leaving opens the actual main menu.")
	_check(_player.stream_paused, "Music stays silent in the main menu after gameplay.")
	await _check_position_frozen("main menu")
	await _open_level(2)
	_check(not _player.stream_paused, "Returning from the menu resumes music.")
	_check_decoder("menu return")


func _test_native_loop() -> void:
	var stream := _player.stream as AudioStreamOggVorbis
	var master_index := AudioServer.get_bus_index(&"Master")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	var effect_index := AudioServer.get_bus_effect_count(master_index)
	AudioServer.add_bus_effect(master_index, capture)
	_player.seek(stream.get_length() - 0.15)
	_initial_playback = _player.get_stream_playback()
	await create_timer(0.45).timeout
	_check(_player.playing and not _player.stream_paused, "The decoder continues playing across the loop boundary.")
	var position := _player.get_playback_position()
	_check(position >= stream.loop_offset and position < stream.loop_offset + 1.0,
		"The native decoder wraps to the prepared offset without replaying the intro.")
	_check_decoder("native loop")
	var mixed_frames := capture.get_buffer(capture.get_frames_available())
	_check(mixed_frames.size() > AudioServer.get_mix_rate() * 0.25,
		"Native loop verification captures actual Master output across the boundary.")
	var peak := 0.0
	var energy := 0.0
	for frame in mixed_frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		energy += frame.length_squared()
	_check(peak > 0.001, "The decoder produces sounding audio across the boundary.")
	_check(linear_to_db(peak) <= -1.0, "Captured Master output stays under its -1 dB ceiling.")
	if not mixed_frames.is_empty():
		var rms := sqrt(energy / float(mixed_frames.size() * 2))
		_check(linear_to_db(rms) > -45.0, "The loop capture has no silent end-of-file gap.")
		print("Native music loop capture: %.2f dBFS peak, %.2f dBFS RMS." % [
			linear_to_db(peak), linear_to_db(rms)
		])
	AudioServer.remove_bus_effect(master_index, effect_index)
	capture = null


func _check_position_frozen(reason: String) -> void:
	# Allow the mixer to consume its last buffered block, then verify that a pause freezes time.
	await create_timer(0.06).timeout
	var before := _player.get_playback_position()
	await create_timer(0.08).timeout
	_check(absf(_player.get_playback_position() - before) < 0.025,
		"Playback position is frozen during %s." % reason)


func _check_decoder(reason: String) -> void:
	_check(_player.get_stream_playback() == _initial_playback, "%s keeps the same decoder." % reason)


func _open_level(number: int) -> Node:
	var level := _level_scene.instantiate()
	level.set("selected_level", number)
	level.set("launched_from_dev_mode", true)
	level.set("return_menu_scene_path", MENU_SCENE_PATH)
	await _replace_scene(level)
	return level


func _open_scene(path: String) -> void:
	await _replace_scene((load(path) as PackedScene).instantiate())


func _replace_scene(scene: Node) -> void:
	var previous := current_scene
	root.add_child(scene)
	current_scene = scene
	if previous != null:
		previous.queue_free()
	await _wait_frames(3)


func _wait_for_transition() -> void:
	var transition := root.get_node("LevelTransition")
	var deadline := Time.get_ticks_msec() + 5000
	while bool(transition.call("is_transitioning")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not bool(transition.call("is_transitioning")), "Level loading finishes before timeout.")
	await _wait_frames(3)


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
