extends SceneTree

## Shared haptics-owner verification: catalog coverage, saved-setting gating, exact fallback pulses,
## cooldowns, priority replacement, count scaling, test mute, and the vibration-toggle preview.
##
## Run through scripts/tools/run_isolated_godot_test.ps1:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/haptics/test_haptics_manager.gd

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const HapticsCatalogScript := preload("res://scripts/haptics/haptics_catalog.gd")
const VIBRATION_SETTING := &"vibration"

var _failures: Array[String] = []
var _manager: Node
var _progress: Node
var _events: Array[StringName] = []
var _pulses: Array[Dictionary] = []
var _provider_calls: Array[Dictionary] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Haptics verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_manager = root.get_node_or_null(^"HapticsManager")
	_progress = root.get_node_or_null(^"PlayerProgress")
	_check(_manager != null, "The HapticsManager autoload is available to every scene.")
	_check(_progress != null, "PlayerProgress autoload is available.")
	if _manager == null or _progress == null:
		quit(1)
		return

	_check(bool(_manager.call("is_muted")), "Headless runs start with physical haptics muted.")
	_manager.connect("event_played", _on_event_played)
	_manager.connect("pulse_played", _on_pulse_played)
	_manager.call("set_vibration_provider", Callable(self, "_record_provider_call"))
	_manager.call("set_muted", false)
	_progress.call("set_setting_disabled", VIBRATION_SETTING, false)

	_test_catalog()
	await _test_exact_pattern_and_provider()
	_test_cooldown()
	await _test_priority_replacement()
	await _test_count_scaling()
	await _test_saved_setting_and_toggle_preview()
	_test_mute_cancels_patterns()

	_progress.call("set_setting_disabled", VIBRATION_SETTING, false)
	_manager.call("set_vibration_provider", Callable())
	_manager.call("set_muted", true)
	if _failures.is_empty():
		print("Haptics manager verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_catalog() -> void:
	var expected := [
		HapticsCatalogScript.EVENT_ITEM_SELECT,
		HapticsCatalogScript.EVENT_ITEM_PICKUP,
		HapticsCatalogScript.EVENT_ITEM_PLACE_VALID,
		HapticsCatalogScript.EVENT_STICKY_MOVE_BLOCKED,
		HapticsCatalogScript.EVENT_MATCH_CLEAR,
		HapticsCatalogScript.EVENT_SHELF_UNLOCK,
		HapticsCatalogScript.EVENT_ABILITY_HAMMER,
		HapticsCatalogScript.EVENT_ABILITY_SHUFFLE,
		HapticsCatalogScript.EVENT_ABILITY_LANTERN,
		HapticsCatalogScript.EVENT_ABILITY_FREEZER,
		HapticsCatalogScript.EVENT_TIME_UP,
		HapticsCatalogScript.EVENT_TIME_EXTENSION_SUCCESS,
		HapticsCatalogScript.EVENT_LEVEL_COMPLETE,
		HapticsCatalogScript.EVENT_LEVEL_FAILED,
		HapticsCatalogScript.EVENT_SHOP_PURCHASE_SUCCESS,
		HapticsCatalogScript.EVENT_LIFE_PURCHASE_SUCCESS,
		HapticsCatalogScript.EVENT_REWARD_CHEST_GOAL_COMPLETE,
		HapticsCatalogScript.EVENT_LEADERBOARD_REWARD,
		HapticsCatalogScript.EVENT_VIBRATION_TOGGLE,
	]
	_check(
		HapticsCatalogScript.get_event_ids().size() == expected.size(),
		"The catalog has exactly the approved semantic event set."
	)
	for event_id in expected:
		var config := HapticsCatalogScript.get_event(event_id)
		_check(not config.is_empty(), "Catalog event %s exists." % event_id)
		_check(int(config.get("priority", -1)) >= 0, "Catalog event %s has a priority." % event_id)
		var pattern := config.get("pattern", []) as Array
		_check(not pattern.is_empty(), "Catalog event %s has at least one pulse." % event_id)
		for pulse in pattern:
			var duration := int((pulse as Dictionary).get("duration_ms", 0))
			var amplitude := float((pulse as Dictionary).get("amplitude", -1.0))
			_check(duration > 0 and duration <= 70, "%s uses a short 1..70 ms pulse." % event_id)
			_check(amplitude > 0.0 and amplitude <= 0.75, "%s keeps amplitude in the comfort range." % event_id)


func _test_exact_pattern_and_provider() -> void:
	_reset_observation()
	var accepted := bool(_manager.call("play", HapticsCatalogScript.EVENT_ABILITY_SHUFFLE))
	await create_timer(0.25).timeout
	_check(accepted, "A known enabled event is accepted.")
	_check(_events == [HapticsCatalogScript.EVENT_ABILITY_SHUFFLE], "One event request emits once.")
	_check(_pulses.size() == 2, "Shuffle produces its two-pulse pattern (observed %d)." % _pulses.size())
	if _pulses.size() == 2:
		_check(int(_pulses[0].duration_ms) == 22, "Shuffle's first pulse has the catalog duration.")
		_check(int(_pulses[1].duration_ms) == 22, "Shuffle's second pulse has the catalog duration.")
	_check(
		_provider_calls.size() == _pulses.size(),
		"Every accepted fallback pulse reaches the injected provider exactly once."
	)


func _test_cooldown() -> void:
	_reset_observation()
	var first := bool(_manager.call("play", HapticsCatalogScript.EVENT_ITEM_SELECT))
	var second := bool(_manager.call("play", HapticsCatalogScript.EVENT_ITEM_SELECT))
	_check(first, "The first request in a cooldown window is accepted.")
	_check(not second, "A duplicate request inside its cooldown is dropped.")
	_manager.call("reset_playback_state")


func _test_priority_replacement() -> void:
	_reset_observation()
	var warning := bool(_manager.call("play", HapticsCatalogScript.EVENT_TIME_UP))
	var selection := bool(_manager.call("play", HapticsCatalogScript.EVENT_ITEM_SELECT))
	var completion := bool(_manager.call("play", HapticsCatalogScript.EVENT_LEVEL_COMPLETE))
	await create_timer(0.18).timeout
	_check(warning, "The initial warning pattern is accepted.")
	_check(not selection, "Low-priority selection cannot interrupt a warning.")
	_check(completion, "A terminal result replaces the warning pattern.")
	_check(
		_count_pulses(HapticsCatalogScript.EVENT_TIME_UP) == 1,
		"Replacing time-up cancels its queued second pulse."
	)
	_check(
		_count_pulses(HapticsCatalogScript.EVENT_LEVEL_COMPLETE) == 2,
		"The replacing completion pattern runs to completion."
	)


func _test_count_scaling() -> void:
	_reset_observation()
	_manager.call("play", HapticsCatalogScript.EVENT_MATCH_CLEAR, {"count": 4})
	await create_timer(0.06).timeout
	_check(_pulses.size() == 1, "A folded match burst remains one pulse.")
	if _pulses.size() == 1:
		_check(
			is_equal_approx(float(_pulses[0].amplitude), 0.54),
			"A folded match burst raises amplitude only to the configured cap."
		)


func _test_saved_setting_and_toggle_preview() -> void:
	_manager.call("reset_playback_state")
	_progress.call("set_setting_disabled", VIBRATION_SETTING, true)
	_reset_observation(false)
	_check(not bool(_manager.call("is_enabled")), "The saved disabled setting gates haptics.")
	_check(
		not bool(_manager.call("play", HapticsCatalogScript.EVENT_MATCH_CLEAR)),
		"Ordinary events are rejected while vibration is disabled."
	)
	_manager.call("acknowledge_vibration_toggle", true)
	await create_timer(0.04).timeout
	_check(
		_events == [HapticsCatalogScript.EVENT_VIBRATION_TOGGLE] and _pulses.size() == 1,
		"Turning vibration off still gives one final forced preview pulse."
	)

	_progress.call("set_setting_disabled", VIBRATION_SETTING, false)
	_manager.call("reset_playback_state")
	_reset_observation(false)
	_manager.call("acknowledge_vibration_toggle", false)
	await create_timer(0.04).timeout
	_check(
		_events == [HapticsCatalogScript.EVENT_VIBRATION_TOGGLE] and _pulses.size() == 1,
		"Turning vibration on previews the newly enabled setting."
	)


func _test_mute_cancels_patterns() -> void:
	_manager.call("reset_playback_state")
	_reset_observation(false)
	_manager.call("play", HapticsCatalogScript.EVENT_TIME_UP)
	_manager.call("set_muted", true)
	_check(not bool(_manager.call("is_enabled")), "The independent test/capture mute gates haptics.")
	_check(
		not bool(_manager.call("play", HapticsCatalogScript.EVENT_ITEM_SELECT)),
		"Muted requests are rejected."
	)
	_check(
		not bool(_manager.call(
			"play",
			HapticsCatalogScript.EVENT_VIBRATION_TOGGLE,
			{"force": true, "bypass_cooldown": true}
		)),
		"The setting-preview exception cannot bypass the independent test/capture mute."
	)
	_manager.call("set_muted", false)


func _reset_observation(reset_manager := true) -> void:
	if reset_manager:
		_manager.call("reset_playback_state")
	_events.clear()
	_pulses.clear()
	_provider_calls.clear()


func _on_event_played(event_id: StringName, _context: Dictionary) -> void:
	_events.append(event_id)


func _on_pulse_played(
	event_id: StringName,
	duration_ms: int,
	amplitude: float,
	pulse_index: int
) -> void:
	_pulses.append({
		"event_id": event_id,
		"duration_ms": duration_ms,
		"amplitude": amplitude,
		"pulse_index": pulse_index,
	})


func _record_provider_call(duration_ms: int, amplitude: float) -> void:
	_provider_calls.append({"duration_ms": duration_ms, "amplitude": amplitude})


func _count_pulses(event_id: StringName) -> int:
	var count := 0
	for pulse in _pulses:
		if pulse.event_id == event_id:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
