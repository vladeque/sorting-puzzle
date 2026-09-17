extends SceneTree

## AUDIO-001 playback-owner verification for scripts/audio/sfx_manager.gd and
## scripts/audio/ui_click_binder.gd: bus routing, pool reuse, per-event polyphony and cooldown,
## variant selection, missing-stream safety, the mute paths, and the generic button-click policy.
##
## Run through scripts/tools/run_isolated_godot_test.ps1:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/audio/test_sfx_manager.gd
##
## Assertions are made against the owner's observable bookkeeping (`event_played`, active-play
## counts, player state), never against audible output, so this runs headless with no audio device.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")
const UiClickBinderScript := preload("res://scripts/audio/ui_click_binder.gd")

const SOUND_EFFECTS_SETTING := &"sound_effects"

var _failures: Array[String] = []
var _manager: Node
var _progress: Node
var _played_events: Array[StringName] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("SFX manager verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_manager = root.get_node_or_null(^"SfxManager")
	_progress = root.get_node_or_null(^"PlayerProgress")
	_check(_manager != null, "The SfxManager autoload is available to every scene.")
	_check(_progress != null, "PlayerProgress autoload is available.")
	if _manager == null or _progress == null:
		quit(1)
		return

	_check(
		bool(_manager.call("is_muted")),
		"A headless automated run starts muted, so tests never need an audio device."
	)
	_manager.connect("event_played", _on_event_played)
	_manager.call("set_muted", false)

	_test_bus_and_pool()
	_test_master_limiter()
	_test_pool_reuse()
	_test_start_position_and_event_stop()
	_test_polyphony_keeps_the_newest_cue()
	_test_cooldown()
	_test_variant_selection()
	_test_missing_event_and_stream_are_safe()
	_test_count_scaling()
	_test_global_mute()
	_test_saved_setting_and_toggle_acknowledgement()
	await _test_setting_persists_across_scenes()
	await _test_button_click_policy()

	_progress.call("set_setting_disabled", SOUND_EFFECTS_SETTING, false)
	if _failures.is_empty():
		print("SFX manager verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_bus_and_pool() -> void:
	var bus_index := AudioServer.get_bus_index(&"SFX")
	_check(bus_index >= 0, "The committed bus layout provides a dedicated SFX bus.")
	if bus_index >= 0:
		_check(
			AudioServer.get_bus_send(bus_index) == &"Master",
			"The SFX bus sends to Master."
		)

	var players := _get_pool_players()
	_check(players.size() > 1, "The owner builds a reusable player pool.")
	_check(
		players.size() == int(_manager.call("get_player_pool_size")),
		"The reported pool size matches the pooled player nodes."
	)
	for player in players:
		if player.bus != &"SFX":
			_failures.append("Pooled player %s is not routed to the SFX bus." % player.name)
			break


func _test_master_limiter() -> void:
	var master_index := AudioServer.get_bus_index(&"Master")
	_check(master_index >= 0, "The committed bus layout provides the Master bus.")
	if master_index < 0:
		return

	_check(
		AudioServer.get_bus_effect_count(master_index) >= 1,
		"Master carries a peak-safety effect."
	)
	if AudioServer.get_bus_effect_count(master_index) < 1:
		return

	var limiter := AudioServer.get_bus_effect(master_index, 0) as AudioEffectHardLimiter
	_check(limiter != null, "Master's first effect is the hard limiter.")
	if limiter != null:
		_check(
			is_equal_approx(limiter.ceiling_db, -1.0),
			"The Master limiter ceiling is the documented -1 dB."
		)
		_check(
			AudioServer.is_bus_effect_enabled(master_index, 0),
			"The Master limiter is enabled."
		)


func _test_pool_reuse() -> void:
	_manager.call("reset_playback_state")
	var players_before := _get_pool_players().size()
	for index in range(40):
		_manager.call("play", SfxCatalogScript.EVENT_ITEM_PLACE_VALID, {"bypass_cooldown": true})

	_check(
		_get_pool_players().size() == players_before,
		"Forty rapid plays reuse the pool instead of creating players without bound."
	)
	_check(
		int(_manager.call("get_active_play_count", SfxCatalogScript.EVENT_ITEM_PLACE_VALID))
			<= int(SfxCatalogScript.get_event(SfxCatalogScript.EVENT_ITEM_PLACE_VALID).get("max_polyphony", 0)),
		"Placement polyphony stays inside its catalog budget."
	)
	_manager.call("stop_all")


func _test_start_position_and_event_stop() -> void:
	_manager.call("reset_playback_state")
	var timer := _manager.call(
		"play",
		SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK,
		{"start_position_seconds": 7.0}
	) as AudioStreamPlayer
	var click := _manager.call(
		"play", SfxCatalogScript.EVENT_UI_CLICK, {"bypass_cooldown": true}
	) as AudioStreamPlayer
	_check(
		timer != null and timer.playing and timer.get_playback_position() >= 6.9,
		"A long cue can start at a synchronized playback offset."
	)
	_manager.call("stop_event", SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK)
	_check(
		timer != null and not timer.playing
			and int(_manager.call("get_active_play_count", SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK)) == 0,
		"Stopping one semantic event removes every active instance of that event."
	)
	_check(click != null and click.playing, "Stopping the timer leaves unrelated feedback sounding.")
	_manager.call("stop_all")


## The burst rule: when an event is at its limit, its own oldest instance yields, so the most recent
## action is always the one still sounding.
func _test_polyphony_keeps_the_newest_cue() -> void:
	_manager.call("reset_playback_state")
	var event_id := SfxCatalogScript.EVENT_REWARD_CHEST_STAR_ARRIVAL
	var max_polyphony := int(SfxCatalogScript.get_event(event_id).get("max_polyphony", 0))
	var newest: AudioStreamPlayer
	for index in range(max_polyphony + 5):
		newest = _manager.call("play", event_id, {"bypass_cooldown": true}) as AudioStreamPlayer

	_check(
		int(_manager.call("get_active_play_count", event_id)) == max_polyphony,
		"A burst of reward arrivals is capped at the event's polyphony budget."
	)
	_check(
		newest != null and newest.playing,
		"The most recent cue of a burst is the one that survives."
	)
	_manager.call("stop_all")


func _test_cooldown() -> void:
	_manager.call("reset_playback_state")
	var first = _manager.call("play", SfxCatalogScript.EVENT_UI_CLICK)
	var second = _manager.call("play", SfxCatalogScript.EVENT_UI_CLICK)
	_check(first != null, "The first click of a cooldown window plays.")
	_check(second == null, "A repeat inside the cooldown window is dropped.")
	_manager.call("stop_all")


func _test_variant_selection() -> void:
	_manager.call("reset_playback_state")
	var selected_streams: Array[String] = []
	for index in range(12):
		var player := _manager.call(
			"play", SfxCatalogScript.EVENT_UI_CLICK, {"bypass_cooldown": true}
		) as AudioStreamPlayer
		if player != null and player.stream != null:
			selected_streams.append(player.stream.resource_path)

	_check(selected_streams.size() >= 10, "A variant pool keeps producing playable variants.")
	var distinct: Array[String] = []
	var repeated_immediately := false
	for index in range(selected_streams.size()):
		if not distinct.has(selected_streams[index]):
			distinct.append(selected_streams[index])
		if index > 0 and selected_streams[index] == selected_streams[index - 1]:
			repeated_immediately = true

	_check(not repeated_immediately, "A variant is never selected twice in a row.")
	_check(distinct.size() >= 2, "Variant selection actually rotates through the pool.")
	_manager.call("stop_all")

	var config := SfxCatalogScript.get_event(SfxCatalogScript.EVENT_UI_CLICK)
	var offsets := config.get("stream_volume_offsets_db", {}) as Dictionary
	var variation := float(config.get("volume_variation_db", 0.0))
	_check(offsets.size() == 3, "The click pool declares one loudness-match offset per variant.")
	_manager.call("reset_playback_state")
	for index in range(12):
		var player := _manager.call(
			"play", SfxCatalogScript.EVENT_UI_CLICK, {"bypass_cooldown": true}
		) as AudioStreamPlayer
		if player == null or player.stream == null:
			continue

		var nominal := float(config.get("volume_db", 0.0)) + float(
			offsets.get(player.stream.resource_path, 0.0)
		)
		_check(
			absf(player.volume_db - nominal) <= variation + 0.001,
			"Per-stream loudness matching is applied before bounded play variation."
		)
	_manager.call("stop_all")


func _test_missing_event_and_stream_are_safe() -> void:
	_manager.call("reset_playback_state")
	_check(
		_manager.call("play", &"not_an_approved_event") == null,
		"An unknown event id returns null instead of blocking its caller."
	)
	_check(
		_manager.call("_load_stream", &"probe_event", "res://assets/audio/missing_event/missing.wav") == null,
		"A missing stream resolves to null instead of raising."
	)
	# Both branches warn once; reaching this line at all is the "never blocks the caller" assertion.
	_check(
		_manager.call("play", SfxCatalogScript.EVENT_UI_CLICK) != null,
		"A failed lookup leaves the owner usable for the next real event."
	)
	_manager.call("stop_all")


func _test_count_scaling() -> void:
	_manager.call("reset_playback_state")
	var single := _manager.call(
		"play", SfxCatalogScript.EVENT_STAR_HUD_ARRIVAL, {"bypass_cooldown": true}
	) as AudioStreamPlayer
	var single_volume := single.volume_db if single != null else 0.0
	var single_pitch := single.pitch_scale if single != null else 0.0

	var multiple := _manager.call(
		"play", SfxCatalogScript.EVENT_STAR_HUD_ARRIVAL, {"bypass_cooldown": true, "count": 5}
	) as AudioStreamPlayer
	_check(
		multiple != null and multiple.volume_db > single_volume,
		"A multi-star reward is louder than a single-star one."
	)
	_check(
		multiple != null and multiple.pitch_scale > single_pitch,
		"A multi-star reward steps up in pitch rather than stacking full-volume copies."
	)

	var huge := _manager.call(
		"play", SfxCatalogScript.EVENT_STAR_HUD_ARRIVAL, {"bypass_cooldown": true, "count": 40}
	) as AudioStreamPlayer
	var scaling := SfxCatalogScript.get_event(SfxCatalogScript.EVENT_STAR_HUD_ARRIVAL).get(
		"count_scaling", {}
	) as Dictionary
	_check(
		huge != null and huge.pitch_scale <= float(scaling.get("max_pitch", 1.0)) + 0.0001,
		"Count scaling is bounded rather than unbounded."
	)
	_manager.call("stop_all")


func _test_global_mute() -> void:
	_manager.call("reset_playback_state")
	_manager.call("play", SfxCatalogScript.EVENT_MATCH_CLEAR)
	_check(
		int(_manager.call("get_active_play_count")) > 0,
		"A cue is sounding before the mute check."
	)
	_manager.call("set_muted", true)
	_check(
		int(_manager.call("get_active_play_count")) == 0,
		"Muting stops everything already sounding."
	)
	_check(
		_manager.call("play", SfxCatalogScript.EVENT_MATCH_CLEAR) == null,
		"Nothing plays while muted."
	)
	_manager.call("set_muted", false)
	_manager.call("reset_playback_state")
	_check(
		_manager.call("play", SfxCatalogScript.EVENT_MATCH_CLEAR) != null,
		"Unmuting restores playback."
	)
	_manager.call("stop_all")


func _test_saved_setting_and_toggle_acknowledgement() -> void:
	_manager.call("reset_playback_state")
	_progress.call("set_setting_disabled", SOUND_EFFECTS_SETTING, false)
	_check(bool(_manager.call("is_enabled")), "Sound effects are enabled by default.")
	_manager.call("play", SfxCatalogScript.EVENT_ITEM_SELECT)
	_check(int(_manager.call("get_active_play_count")) > 0, "An enabled request sounds.")

	_progress.call("set_setting_disabled", SOUND_EFFECTS_SETTING, true)
	_check(
		not bool(_manager.call("is_enabled")),
		"The saved sound-effects setting gates every request."
	)
	_manager.call("notify_sound_effects_setting_changed")
	_check(
		int(_manager.call("get_active_play_count")) == 0,
		"Disabling sound effects stops active cues immediately."
	)
	_manager.call("reset_playback_state")
	_check(
		_manager.call("play", SfxCatalogScript.EVENT_ITEM_SELECT) == null,
		"No event plays while the saved setting is disabled."
	)

	# Turning the setting off still acknowledges the press that turned it off, and that
	# acknowledgement is the only thing left sounding.
	_played_events.clear()
	_manager.call("acknowledge_sound_effects_toggle", true)
	_check(
		_played_events.has(SfxCatalogScript.EVENT_UI_CLICK),
		"Switching sound effects off acknowledges the accepted press before muting."
	)
	_check(
		int(_manager.call("get_active_play_count")) <= 1,
		"Only the acknowledgement survives the mute."
	)

	_progress.call("set_setting_disabled", SOUND_EFFECTS_SETTING, false)
	_manager.call("reset_playback_state")
	_played_events.clear()
	_manager.call("acknowledge_sound_effects_toggle", false)
	_check(
		_played_events.has(SfxCatalogScript.EVENT_UI_CLICK),
		"Switching sound effects on acknowledges the press right after enabling."
	)
	_manager.call("stop_all")


func _test_setting_persists_across_scenes() -> void:
	var manager_id := _manager.get_instance_id()
	_progress.call("set_setting_disabled", SOUND_EFFECTS_SETTING, true)

	var scene := Control.new()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	_check(
		root.get_node_or_null(^"SfxManager") != null
			and root.get_node_or_null(^"SfxManager").get_instance_id() == manager_id,
		"The playback owner survives a scene change instead of being rebuilt per screen."
	)
	_check(
		not bool(_manager.call("is_enabled")),
		"The saved setting still applies after a scene change."
	)

	scene.queue_free()
	current_scene = null
	await process_frame
	_progress.call("set_setting_disabled", SOUND_EFFECTS_SETTING, false)
	_manager.call("reset_playback_state")
	_check(
		_manager.call("play", SfxCatalogScript.EVENT_UI_CLICK) != null,
		"Re-enabling after a scene change restores playback."
	)
	_manager.call("stop_all")


func _test_button_click_policy() -> void:
	var binder := _manager.get_node_or_null(^"UiClickBinder")
	_check(binder != null, "The owner installs exactly one generic click policy.")
	if binder == null:
		return

	var host := Control.new()
	root.add_child(host)
	var button := Button.new()
	host.add_child(button)
	await process_frame

	_check(
		_count_binder_connections(button, binder) == 1,
		"A button added to the tree is bound exactly once."
	)

	# Reparenting/pooling must not add a second generic owner.
	host.remove_child(button)
	host.add_child(button)
	await process_frame
	_check(
		_count_binder_connections(button, binder) == 1,
		"Re-entering the tree does not bind a second generic click."
	)

	_manager.call("reset_playback_state")
	_played_events.clear()
	button.pressed.emit()
	_check(
		_played_events.size() == 1 and _played_events[0] == SfxCatalogScript.EVENT_UI_CLICK,
		"An enabled visible button plays exactly one generic click."
	)

	_manager.call("reset_playback_state")
	_played_events.clear()
	button.disabled = true
	button.pressed.emit()
	button.disabled = false
	_check(_played_events.is_empty(), "A disabled button stays silent.")

	_manager.call("reset_playback_state")
	_played_events.clear()
	button.visible = false
	button.pressed.emit()
	button.visible = true
	_check(_played_events.is_empty(), "A hidden button stays silent.")

	_manager.call("reset_playback_state")
	_played_events.clear()
	_manager.call("set_button_click_suppressed", button, true)
	button.pressed.emit()
	_check(
		_played_events.is_empty(),
		"A suppressed button (no-op active tab, sound-effects toggle) stays silent."
	)
	_check(
		bool(_manager.call("is_button_click_suppressed", button)),
		"Suppression is observable through the owner."
	)

	_manager.call("reset_playback_state")
	_played_events.clear()
	_manager.call("set_button_click_suppressed", button, false)
	button.pressed.emit()
	_check(
		_played_events.size() == 1 and _played_events[0] == SfxCatalogScript.EVENT_UI_CLICK,
		"Clearing suppression restores the generic click."
	)

	host.queue_free()
	await process_frame
	_manager.call("stop_all")


func _count_binder_connections(button: BaseButton, binder: Node) -> int:
	var count := 0
	for connection in button.pressed.get_connections():
		var callable := connection.get("callable") as Callable
		if callable.get_object() == binder:
			count += 1

	return count


func _get_pool_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child in _manager.get_children():
		var player := child as AudioStreamPlayer
		if player != null:
			players.append(player)

	return players


func _on_event_played(event_id: StringName, _context: Dictionary) -> void:
	_played_events.append(event_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
