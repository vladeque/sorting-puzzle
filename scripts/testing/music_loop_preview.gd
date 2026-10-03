extends Control

## Standalone listening preview of the production soundtrack scene and its native loop. The
## autoload remains suspended on this non-level scene; preview transport never changes its
## playback position or any saved preference. Buttons are silent to keep the join easy to hear.

const MANIFEST_PATH := "res://assets/audio/music/corner_shop_sorting_loop.json"

@export_range(1.0, 15.0, 0.5) var seconds_before_loop := 5.0

@onready var _player: AudioStreamPlayer = $Soundtrack
@onready var _phase_label: Label = %PhaseLabel
@onready var _position_label: Label = %PositionLabel
@onready var _loop_label: Label = %LoopLabel
@onready var _timeline: ProgressBar = %Timeline
@onready var _seam_button: Button = %SeamButton
@onready var _beginning_button: Button = %BeginningButton
@onready var _pause_button: Button = %PauseButton
@onready var _stop_button: Button = %StopButton

var _has_playback := false
var _paused := false
var _app_interrupted := false
var _crossfade_seconds := 0.0
var _loops_heard := 0


func _ready() -> void:
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	_crossfade_seconds = float(manifest.get("crossfade_seconds", 0.0))
	_timeline.max_value = _player.stream.get_length()
	_seam_button.pressed.connect(play_loop_seam)
	_beginning_button.pressed.connect(play_from_beginning)
	_pause_button.pressed.connect(toggle_pause)
	_stop_button.pressed.connect(stop_preview)
	for button in [_seam_button, _beginning_button, _pause_button, _stop_button]:
		SfxManager.set_button_click_suppressed(button)
	%Instructions.text = (
		"Play loop seam starts %.0f seconds before the end. Listen as the music continues "
		+ "at the loop start, then replay the seam whenever you like."
	) % seconds_before_loop
	_update_display()


func _process(_delta: float) -> void:
	if _has_playback:
		_loops_heard = _player.get_stream_playback().get_loop_count()
	_update_display()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_app_interrupted = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_app_interrupted = false
	else:
		return
	if is_node_ready():
		_player.stream_paused = _paused or _app_interrupted


func play_loop_seam() -> void:
	_start_at(maxf(_player.stream.get_length() - seconds_before_loop, 0.0))


func play_from_beginning() -> void:
	_start_at(0.0)


func toggle_pause() -> void:
	if not _has_playback:
		return
	_paused = not _paused
	_player.stream_paused = _paused or _app_interrupted
	_update_display()


func stop_preview() -> void:
	_player.stop()
	_has_playback = false
	_paused = false
	_loops_heard = 0
	_update_display()


func _start_at(position: float) -> void:
	_player.stream_paused = _app_interrupted
	_player.play(position)
	_has_playback = true
	_paused = false
	_loops_heard = 0
	_update_display()


func _update_display() -> void:
	var position := _player.get_playback_position() if _has_playback else 0.0
	var stream := _player.stream as AudioStreamOggVorbis
	var remaining := maxf(stream.get_length() - position, 0.0)
	_position_label.text = "%s / %s" % [_format_time(position), _format_time(stream.get_length())]
	_timeline.value = position
	_loop_label.text = "Loop start: %s  |  Loops heard: %d" % [
		_format_time(stream.loop_offset), _loops_heard
	]
	_pause_button.text = "Resume" if _paused else "Pause"
	_pause_button.disabled = not _has_playback
	_stop_button.disabled = not _has_playback
	if not _has_playback:
		_phase_label.text = "Ready to listen"
	elif _paused or _app_interrupted:
		_phase_label.text = "Paused"
	elif _loops_heard > 0:
		_phase_label.text = "Loop passed — music continues"
	elif remaining <= _crossfade_seconds:
		_phase_label.text = "Crossfade — loop in %.1f s" % remaining
	else:
		_phase_label.text = "Loop in %.1f s" % remaining
	_phase_label.modulate = Color(0.58, 1.0, 0.72) if _loops_heard > 0 else Color.WHITE


func _format_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	return "%02d:%05.2f" % [minutes, fmod(seconds, 60.0)]
