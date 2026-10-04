extends CenterContainer

## Shared loading/empty/error/Retry presentation for Shop/Leaderboard-style destination screens.
## Purely presentational: the owning screen decides when to call each state and what the retry
## action actually does.

signal retry_pressed

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const PULSE_DURATION := UIMotionScript.OVERLAY_DURATION * 2.0
const PULSE_LOW_ALPHA := 0.55
const PULSE_TWEEN_META := &"_status_pulse_tween"

@onready var _message_label := %StatusMessageLabel as Label
@onready var _retry_button := %StatusRetryButton as Button


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry_pressed)
	_refresh_retry_text()


## No Retry action -- an in-progress load, not a failure. Pulses the message so a load that never
## resolves still reads as "in progress" rather than a frozen screen.
func show_loading(message: String) -> void:
	visible = true
	_message_label.text = message
	_retry_button.visible = false
	_start_pulse()


## No Retry action -- a legitimately empty result, not a failure.
func show_empty(message: String) -> void:
	visible = true
	_message_label.text = message
	_retry_button.visible = false
	_stop_pulse()


## Shows Retry so the player can ask the owning screen to reload.
func show_error(message: String) -> void:
	visible = true
	_message_label.text = message
	_retry_button.visible = true
	_stop_pulse()


func hide_status() -> void:
	visible = false
	_stop_pulse()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_retry_text()
	if what == NOTIFICATION_EXIT_TREE:
		_stop_pulse()


func _on_retry_pressed() -> void:
	retry_pressed.emit()


## Starts (or restarts) a looping opacity breathe on the loading message, using the shared motion
## tokens. Killing any previously tracked pulse first means repeated show_loading() calls across
## reloads never accumulate loop tweens.
func _start_pulse() -> void:
	_message_label.modulate.a = 1.0
	var tween := UIMotionScript.retween(_message_label, PULSE_TWEEN_META)
	tween.set_loops()
	tween.tween_property(_message_label, "modulate:a", PULSE_LOW_ALPHA, PULSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_message_label, "modulate:a", 1.0, PULSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	UIMotionScript.stop_tween(_message_label, PULSE_TWEEN_META)
	_message_label.modulate.a = 1.0


func _refresh_retry_text() -> void:
	_retry_button.text = tr("common.retry_load")
