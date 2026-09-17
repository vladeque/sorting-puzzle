extends Node

## Global handheld-haptics owner. Gameplay and UI request semantic events; this node owns saved
## preference gating, cooldowns, priority replacement, pattern timing, and the platform fallback.

signal event_played(event_id: StringName, context: Dictionary)
signal pulse_played(event_id: StringName, duration_ms: int, amplitude: float, pulse_index: int)

const HapticsCatalogScript := preload("res://scripts/haptics/haptics_catalog.gd")
const VIBRATION_SETTING := &"vibration"

var _muted := false
var _last_play_msec: Dictionary = {}
var _pattern_generation := 0
var _pattern_active := false
var _active_priority := -1
var _vibration_provider := Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless tests opt in explicitly and inject a provider. Ordinary automated runs must never
	# touch a host device's vibration service.
	_muted = DisplayServer.get_name() == "headless"


## Returns true only when the semantic event was accepted. An accepted event can remain physically
## silent on desktop or unsupported hardware while still being observable in wiring tests.
func play(event_id: StringName, context: Dictionary = {}) -> bool:
	# Test/capture mute is absolute. `force` is deliberately narrower: it only allows the setting's
	# final acknowledgement pulse after the saved preference has changed to disabled.
	if _muted:
		return false
	if not bool(context.get("force", false)) and not _is_preference_enabled():
		return false
	if not HapticsCatalogScript.has_event(event_id):
		push_warning("Unknown haptic event: %s" % event_id)
		return false

	var config := HapticsCatalogScript.EVENTS[event_id] as Dictionary
	var now_msec := Time.get_ticks_msec()
	if (
		not bool(context.get("bypass_cooldown", false))
		and _is_in_cooldown(event_id, config, now_msec)
	):
		return false

	var priority := int(config.get("priority", 0))
	if _pattern_active and priority < _active_priority:
		return false

	_pattern_generation += 1
	var generation := _pattern_generation
	_pattern_active = true
	_active_priority = priority
	_last_play_msec[event_id] = now_msec
	event_played.emit(event_id, context)
	_run_pattern(event_id, config, context, generation)
	return true


func is_enabled() -> bool:
	if _muted:
		return false
	return _is_preference_enabled()


func _is_preference_enabled() -> bool:
	var progress := _get_player_progress()
	if progress == null:
		return true
	return not bool(progress.is_setting_disabled(VIBRATION_SETTING))


func set_muted(is_muted: bool) -> void:
	if _muted == is_muted:
		return
	_muted = is_muted
	if _muted:
		cancel_active_pattern()


func is_muted() -> bool:
	return _muted


func cancel_active_pattern() -> void:
	_pattern_generation += 1
	_pattern_active = false
	_active_priority = -1


## The preview remains perceptible when turning vibration off by forcing this one accepted pulse
## after the saved setting changes. Enabling uses the normal newly-enabled path.
func acknowledge_vibration_toggle(is_disabled: bool) -> void:
	play(HapticsCatalogScript.EVENT_VIBRATION_TOGGLE, {
		"force": is_disabled,
		"bypass_cooldown": true,
	})


## Tests and future native Android/iOS bridges inject a `(duration_ms, amplitude)` callable here.
## An empty callable restores Godot's handheld fallback.
func set_vibration_provider(provider: Callable) -> void:
	_vibration_provider = provider


func reset_playback_state() -> void:
	cancel_active_pattern()
	_last_play_msec.clear()


func _run_pattern(
	event_id: StringName,
	config: Dictionary,
	context: Dictionary,
	generation: int
) -> void:
	var pattern := config.get("pattern", []) as Array
	for pulse_index in range(pattern.size()):
		var pulse := pattern[pulse_index] as Dictionary
		var delay_ms := maxi(int(pulse.get("delay_ms", 0)), 0)
		if delay_ms > 0:
			await get_tree().create_timer(float(delay_ms) / 1000.0, true, false, true).timeout
		if (
			generation != _pattern_generation
			or _muted
			or (not bool(context.get("force", false)) and not _is_preference_enabled())
		):
			return

		var duration_ms := maxi(int(pulse.get("duration_ms", 0)), 0)
		var amplitude := _get_scaled_amplitude(pulse, config, context)
		if duration_ms > 0 and amplitude > 0.0:
			_emit_pulse(event_id, duration_ms, amplitude, pulse_index)
			await get_tree().create_timer(float(duration_ms) / 1000.0, true, false, true).timeout
			if generation != _pattern_generation:
				return

	if generation == _pattern_generation:
		_pattern_active = false
		_active_priority = -1


func _emit_pulse(
	event_id: StringName,
	duration_ms: int,
	amplitude: float,
	pulse_index: int
) -> void:
	pulse_played.emit(event_id, duration_ms, amplitude, pulse_index)
	if _vibration_provider.is_valid():
		_vibration_provider.call(duration_ms, amplitude)
	elif OS.has_feature("mobile") or OS.has_feature("web"):
		Input.vibrate_handheld(duration_ms, amplitude)


func _get_scaled_amplitude(
	pulse: Dictionary,
	config: Dictionary,
	context: Dictionary
) -> float:
	var amplitude := float(pulse.get("amplitude", 0.0))
	var count := maxi(int(context.get("count", 1)), 1)
	if count > 1:
		var bonus := minf(
			float(count - 1) * float(config.get("count_amplitude_step", 0.0)),
			float(config.get("max_count_amplitude_bonus", 0.0))
		)
		amplitude += bonus
	return clampf(amplitude * maxf(float(context.get("intensity_scale", 1.0)), 0.0), 0.0, 1.0)


func _is_in_cooldown(event_id: StringName, config: Dictionary, now_msec: int) -> bool:
	var cooldown_seconds := float(config.get("cooldown_seconds", 0.0))
	if cooldown_seconds <= 0.0 or not _last_play_msec.has(event_id):
		return false
	return now_msec - int(_last_play_msec[event_id]) < int(round(cooldown_seconds * 1000.0))


func _get_player_progress() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null(^"/root/PlayerProgress")
