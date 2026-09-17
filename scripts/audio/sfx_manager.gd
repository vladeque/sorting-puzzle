extends Node

## `SfxManager` autoload -- the single sound-effect playback owner for the whole game (AUDIO-001).
##
## Gameplay, Main Menu, Chapter Selection, Shop, Leaderboard, and every modal reach playback through
## `SfxManager.play(event_id, context)`. Nothing else creates an `AudioStreamPlayer` for a shared
## cue, so there is exactly one path that can double-trigger, one place that honours the saved
## sound-effects setting, and one pool that bounds how many transients can overlap.
##
## What lives where:
##   scripts/audio/sfx_catalog.gd    event -> streams/volume/pitch/cooldown/polyphony configuration
##   scripts/audio/ui_click_binder.gd generic `ui_click` policy for enabled BaseButton presses
##   scripts/tools/generate_core_sfx.gd  offline generator for the synthesized assets
##
## Playback rules:
## - Every request re-reads `PlayerProgress.is_setting_disabled(&"sound_effects")`, so a setting
##   changed on any screen takes effect immediately and survives scene changes and restarts.
## - Disabling sound effects also stops everything currently sounding.
## - Players are pooled and reused. A pool that is out of free players reclaims the oldest instance
##   of the same event first, so a rapid burst keeps its newest cue rather than its oldest.
## - Variant pools never repeat the immediately previous variant.
## - A missing event id or unloadable stream warns once and returns null; it never blocks the
##   gameplay or UI action that asked for it.

## Emitted whenever a request actually starts sounding -- after the mute, cooldown, catalog, and
## pool checks. The audio tests assert on this instead of on audible output, and it is the one
## reliable place to observe that an event was genuinely accepted rather than merely requested.
signal event_played(event_id: StringName, context: Dictionary)

const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")
const UiClickBinderScript := preload("res://scripts/audio/ui_click_binder.gd")

const SFX_BUS_NAME := &"SFX"
const SOUND_EFFECTS_SETTING := &"sound_effects"
## Comfortably above the worst authored case (a placement that completes a match while stars land,
## the critical timer ticks, and a button opens an overlay) without letting a runaway caller spawn
## nodes without bound.
const PLAYER_POOL_SIZE := 16
const VARIANT_SELECTION_SEED := 0x5F2B10C7
## The sound-effects toggle acknowledges its own press slightly under the normal click so the
## confirmation never reads louder than the setting it is turning off.
const SETTING_ACKNOWLEDGEMENT_VOLUME_DB := -3.0

var _players: Array[AudioStreamPlayer] = []
var _active_plays: Array[Dictionary] = []
var _streams: Dictionary = {}
var _last_play_msec: Dictionary = {}
var _last_variant_index: Dictionary = {}
var _warned_events: Dictionary = {}
var _play_sequence := 0
var _muted := false
var _rng := RandomNumberGenerator.new()
var _click_binder: Node


func _ready() -> void:
	# Cues must keep sounding through any future SceneTree pause: an overlay that pauses the tree
	# should not swallow the click that opened it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = VARIANT_SELECTION_SEED
	_ensure_sfx_bus()
	_build_player_pool()
	# Automated runs are headless and must not depend on an audio device or assert on audio state
	# they never asked about. Audio tests opt back in with set_muted(false).
	_muted = DisplayServer.get_name() == "headless"
	_click_binder = UiClickBinderScript.new()
	_click_binder.name = "UiClickBinder"
	add_child(_click_binder)


## Plays one catalog event. Returns the player that started, or null when the request was muted,
## rate-limited, or unresolvable -- callers never need to check the result.
##
## Supported `context` keys:
##   count             int    Folds a multi-item reward into one count-scaled cue.
##   volume_offset_db  float  Extra trim for this play only.
##   pitch_scale       float  Replaces the random pitch for this play only.
##   force             bool   Bypasses the mute check (only the sound-effects toggle acknowledgement
##                            uses this, to confirm the press that turned playback off).
##   bypass_cooldown   bool   Skips the per-event cooldown for a deliberately paired layer.
##   start_position_seconds float Starts a long authored cue at a synchronized offset.
func play(event_id: StringName, context: Dictionary = {}) -> AudioStreamPlayer:
	if not bool(context.get("force", false)) and not is_enabled():
		return null

	if not SfxCatalogScript.has_event(event_id):
		_warn_once(event_id, "Unknown sound-effect event: %s" % event_id)
		return null

	var config := SfxCatalogScript.EVENTS[event_id] as Dictionary
	var now_msec := Time.get_ticks_msec()
	if not bool(context.get("bypass_cooldown", false)) and _is_in_cooldown(event_id, config, now_msec):
		return null

	var stream := _select_stream(event_id, config)
	if stream == null:
		return null

	var player := _acquire_player(event_id, config)
	if player == null:
		return null

	var volume_db := float(config.get("volume_db", 0.0))
	var stream_volume_offsets := config.get("stream_volume_offsets_db", {}) as Dictionary
	volume_db += float(stream_volume_offsets.get(stream.resource_path, 0.0))
	var variation_db := float(config.get("volume_variation_db", 0.0))
	if variation_db > 0.0:
		volume_db += _rng.randf_range(-variation_db, variation_db)
	volume_db += float(context.get("volume_offset_db", 0.0))

	var pitch_scale := float(context.get("pitch_scale", 0.0))
	if pitch_scale <= 0.0:
		var pitch_range := config.get("pitch_range", Vector2.ONE) as Vector2
		pitch_scale = (
			pitch_range.x
			if is_equal_approx(pitch_range.x, pitch_range.y)
			else _rng.randf_range(pitch_range.x, pitch_range.y)
		)

	var scaled := _apply_count_scaling(config, int(context.get("count", 1)), volume_db, pitch_scale)
	player.stream = stream
	player.volume_db = scaled.x
	player.pitch_scale = scaled.y
	player.play(maxf(float(context.get("start_position_seconds", 0.0)), 0.0))

	_last_play_msec[event_id] = now_msec
	_play_sequence += 1
	_active_plays.append({
		"player": player,
		"event_id": event_id,
		"sequence": _play_sequence,
	})
	event_played.emit(event_id, context)
	return player


## Stops every sounding cue. `except_player` keeps one deliberate acknowledgement audible, which is
## how turning sound effects off can still confirm the press that turned them off.
func stop_all(except_player: AudioStreamPlayer = null) -> void:
	for entry in _active_plays.duplicate():
		var player := entry["player"] as AudioStreamPlayer
		if player == except_player or not is_instance_valid(player):
			continue

		player.stop()

	_prune_finished_plays()


## Stops every active instance of one semantic event without disturbing unrelated feedback. Long
## stateful cues use this when their owning gameplay state pauses or ends.
func stop_event(event_id: StringName) -> void:
	for entry in _get_active_entries(event_id):
		var player := entry["player"] as AudioStreamPlayer
		if is_instance_valid(player):
			player.stop()

	_prune_finished_plays()


## True when a `play()` request would be heard: sound effects enabled in the saved settings and no
## capture/test mute in force.
func is_enabled() -> bool:
	if _muted:
		return false

	var progress := _get_player_progress()
	if progress == null:
		return true

	return not bool(progress.is_setting_disabled(SOUND_EFFECTS_SETTING))


## Capture/test mute, independent of the player-facing setting. scripts/tools/capture_scene.gd and
## the headless default use this so automated runs never need an audio device.
func set_muted(is_muted: bool) -> void:
	if _muted == is_muted:
		return

	_muted = is_muted
	if _muted:
		stop_all()


func is_muted() -> bool:
	return _muted


## Called after the saved sound-effects setting changes so a disable silences what is already
## sounding instead of waiting for it to ring out.
func notify_sound_effects_setting_changed() -> void:
	if not is_enabled():
		stop_all()


## Deliberate handling for the sound-effects settings toggle (AUDIO-001 section 7). Turning it off
## acknowledges the accepted press and then mutes everything else; turning it on acknowledges
## immediately after enabling. Callers must have already written the new setting.
func acknowledge_sound_effects_toggle(is_disabled: bool) -> void:
	var acknowledgement := play(SfxCatalogScript.EVENT_UI_CLICK, {
		"force": is_disabled,
		"bypass_cooldown": true,
		"volume_offset_db": SETTING_ACKNOWLEDGEMENT_VOLUME_DB,
	})
	if is_disabled:
		stop_all(acknowledgement)


## Marks a button silent for (or audible again to) the generic `ui_click` policy. Scene scripts use
## this instead of reaching for the binder, so the meta key stays an implementation detail.
func set_button_click_suppressed(button: BaseButton, is_suppressed := true) -> void:
	UiClickBinderScript.set_click_suppressed(button, is_suppressed)


func is_button_click_suppressed(button: BaseButton) -> bool:
	return UiClickBinderScript.is_click_suppressed(button)


## Number of players currently sounding, optionally for one event. Used by the audio tests to
## assert pooling and polyphony instead of asserting on audible output.
func get_active_play_count(event_id: StringName = &"") -> int:
	_prune_finished_plays()
	if event_id == &"":
		return _active_plays.size()

	var count := 0
	for entry in _active_plays:
		if entry["event_id"] == event_id:
			count += 1

	return count


func get_player_pool_size() -> int:
	return _players.size()


## Clears cooldown and variant history. A level restart or a fresh test case starts from a known
## state rather than inheriting the previous run's spacing.
func reset_playback_state() -> void:
	stop_all()
	_last_play_msec.clear()
	_last_variant_index.clear()
	_rng.seed = VARIANT_SELECTION_SEED


func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS_NAME) >= 0:
		return

	# The committed layout (assets/audio/default_bus_layout.tres) normally provides this bus. A
	# project that somehow starts without it still gets routed playback rather than an error.
	push_warning("SFX audio bus missing from the loaded bus layout; adding it at runtime.")
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, String(SFX_BUS_NAME))
	AudioServer.set_bus_send(bus_index, &"Master")


func _build_player_pool() -> void:
	for index in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%02d" % index
		player.bus = SFX_BUS_NAME
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)


func _is_in_cooldown(event_id: StringName, config: Dictionary, now_msec: int) -> bool:
	var cooldown_seconds := float(config.get("cooldown_seconds", 0.0))
	if cooldown_seconds <= 0.0 or not _last_play_msec.has(event_id):
		return false

	return now_msec - int(_last_play_msec[event_id]) < int(round(cooldown_seconds * 1000.0))


## Picks the next variant without repeating the immediately previous one, and caches the loaded
## stream so repeated plays never hit the resource loader.
func _select_stream(event_id: StringName, config: Dictionary) -> AudioStream:
	var stream_paths := config.get("streams", []) as Array
	if stream_paths.is_empty():
		_warn_once(event_id, "Sound-effect event has no streams: %s" % event_id)
		return null

	var index := 0
	if stream_paths.size() > 1:
		var previous_index := int(_last_variant_index.get(event_id, -1))
		index = _rng.randi_range(0, stream_paths.size() - 1)
		if index == previous_index:
			index = (index + 1) % stream_paths.size()

	_last_variant_index[event_id] = index
	return _load_stream(event_id, str(stream_paths[index]))


func _load_stream(event_id: StringName, stream_path: String) -> AudioStream:
	if _streams.has(stream_path):
		return _streams[stream_path] as AudioStream

	if not ResourceLoader.exists(stream_path):
		_warn_once(event_id, "Missing sound-effect stream: %s" % stream_path)
		return null

	var stream := load(stream_path) as AudioStream
	if stream == null:
		_warn_once(event_id, "Sound-effect stream is not an AudioStream: %s" % stream_path)
		return null

	_streams[stream_path] = stream
	return stream


## Reuses a finished player when one is free. Otherwise the event's own oldest instance yields
## first (so the newest cue of a burst survives), and only then the globally oldest play.
func _acquire_player(event_id: StringName, config: Dictionary) -> AudioStreamPlayer:
	_prune_finished_plays()

	var max_polyphony := maxi(int(config.get("max_polyphony", 1)), 1)
	var event_entries := _get_active_entries(event_id)
	if event_entries.size() >= max_polyphony:
		return _reclaim_oldest(event_entries)

	for player in _players:
		if not player.playing and not _is_player_active(player):
			return player

	if not _active_plays.is_empty():
		return _reclaim_oldest(_active_plays)

	return null


func _reclaim_oldest(entries: Array) -> AudioStreamPlayer:
	var oldest: Dictionary = entries[0]
	for entry in entries:
		if int(entry["sequence"]) < int(oldest["sequence"]):
			oldest = entry

	var player := oldest["player"] as AudioStreamPlayer
	if is_instance_valid(player):
		player.stop()

	_active_plays.erase(oldest)
	return player if is_instance_valid(player) else null


func _get_active_entries(event_id: StringName) -> Array:
	var entries := []
	for entry in _active_plays:
		if entry["event_id"] == event_id:
			entries.append(entry)

	return entries


func _is_player_active(player: AudioStreamPlayer) -> bool:
	for entry in _active_plays:
		if entry["player"] == player:
			return true

	return false


func _prune_finished_plays() -> void:
	for entry in _active_plays.duplicate():
		var player := entry["player"] as AudioStreamPlayer
		if not is_instance_valid(player) or not player.playing:
			_active_plays.erase(entry)


## Folds an n-item reward into one cue: a bounded volume lift and a small upward pitch step, rather
## than n overlapping full-volume plays.
func _apply_count_scaling(
	config: Dictionary,
	count: int,
	volume_db: float,
	pitch_scale: float
) -> Vector2:
	var scaling := config.get("count_scaling", {}) as Dictionary
	var extra := maxi(count, 1) - 1
	if scaling.is_empty() or extra <= 0:
		return Vector2(volume_db, pitch_scale)

	var volume_lift := minf(
		float(scaling.get("volume_db_per_extra", 0.0)) * float(extra),
		float(scaling.get("max_volume_db", 0.0))
	)
	var pitch_lift := minf(
		pitch_scale + float(scaling.get("pitch_per_extra", 0.0)) * float(extra),
		float(scaling.get("max_pitch", pitch_scale))
	)
	return Vector2(volume_db + volume_lift, pitch_lift)


func _get_player_progress() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null

	return tree.root.get_node_or_null(^"PlayerProgress")


## One warning per event id: a missing asset should be obvious in a development run without
## flooding the log from a per-frame gameplay cue.
func _warn_once(event_id: StringName, message: String) -> void:
	if _warned_events.has(event_id):
		return

	_warned_events[event_id] = true
	push_warning(message)
