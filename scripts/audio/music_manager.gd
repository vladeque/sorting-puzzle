extends Node

## Persistent level soundtrack owner. The level exposes its playback gate; this autoload keeps the
## same decoder across pauses, menus, restarts, and next-level scene replacements.

const MUSIC_SETTING := &"music"
const PLAYBACK_GATE := &"is_background_music_allowed"

var _has_started := false
var _muted := false
var _app_interrupted := false

@onready var _player: AudioStreamPlayer = $Soundtrack


func _ready() -> void:
	_muted = DisplayServer.get_name() == "headless"
	refresh_playback()


func _process(_delta: float) -> void:
	# Gameplay has several independent pause paths. Read the current scene's state in one place
	# instead of making each modal, result, and scene replacement manage an audio player.
	refresh_playback()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_app_interrupted = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_app_interrupted = false
	else:
		return
	if is_node_ready():
		refresh_playback()


func is_enabled() -> bool:
	return not _muted and not PlayerProgress.is_setting_disabled(MUSIC_SETTING)


## Capture/test mute, independent of the saved Music setting. Suspending never resets position.
func set_muted(is_muted: bool) -> void:
	_muted = is_muted
	refresh_playback()


func is_muted() -> bool:
	return _muted


## The Music toggle calls this for immediate feedback. The per-frame check also covers preferences
## restored by existing save/account flows without adding a music dependency to those systems.
func refresh_playback() -> void:
	if not is_node_ready():
		return
	var tree := get_tree()
	var scene := tree.current_scene
	var should_play := (
		is_enabled()
		and not _app_interrupted
		and not tree.paused
		and is_instance_valid(scene)
		and scene.can_process()
		and scene.has_method(PLAYBACK_GATE)
		and bool(scene.call(PLAYBACK_GATE))
	)
	_player.stream_paused = not should_play
	if should_play and not _has_started:
		_player.play()
		_has_started = true
