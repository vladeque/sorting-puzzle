extends Control
class_name ToastMessage

## Short notice centered on the screen. It fades in, stays for `display_seconds` in total, and then
## fades out and hides itself. Showing a new message while one is visible swaps the text and restarts
## the timer. The toast never takes input, so taps pass through to the screen beneath it.

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const _TOAST_TWEEN_META := &"_toast_message_tween"

@export var display_seconds := 2.0
@export var fade_in_seconds := 0.12
@export var fade_out_seconds := 0.25

@onready var _message_label := %MessageLabel as Label


func show_message(message: String) -> void:
	_message_label.text = message
	if not visible:
		modulate.a = 0.0
		show()
	var hold_seconds := maxf(display_seconds - fade_in_seconds - fade_out_seconds, 0.0)
	var tween := UIMotionScript.retween(self, _TOAST_TWEEN_META)
	tween.tween_property(self, "modulate:a", 1.0, fade_in_seconds)
	tween.tween_interval(hold_seconds)
	tween.tween_property(self, "modulate:a", 0.0, fade_out_seconds)
	tween.tween_callback(hide)


func get_message() -> String:
	return _message_label.text
