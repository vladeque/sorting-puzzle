@tool
class_name StickyBlockedFeedback
extends Node

## Presentation only. The level owns pointer identity and the item composes these channels.
signal pose_changed(lean_radians: float, body_stretch: float, gum_pressure: float)

@export_range(0.0, 8.0, 0.25) var maximum_lean_degrees := 5.0
@export_range(1.0, 100.0, 1.0) var resistance_distance := 36.0
@export_range(0.0, 0.08, 0.005) var maximum_body_stretch := 0.025
@export var tap_max_seconds := 0.18
@export var tap_cooldown_seconds := 0.28
@export var return_seconds := 0.22
@export var follow_speed := 26.0

var pose := Vector3.ZERO:
	set(value):
		pose = value
		pose_changed.emit(deg_to_rad(maximum_lean_degrees) * pose.x,
			maximum_body_stretch * pose.y, pose.z)

var _motion: Tween
var _holding := false
var _pulled := false
var _held_seconds := 0.0
var _cooldown := 0.0
var _target := Vector3.ZERO


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _holding:
		_held_seconds += delta
		pose = pose.lerp(_target, 1.0 - exp(-follow_speed * delta))
	elif _motion == null and _cooldown <= 0.0:
		set_process(false)


func begin_hold() -> void:
	add_to_group(&"active_sticky_feedback")
	_stop_motion()
	_holding = true
	_pulled = false
	_held_seconds = 0.0
	_target = Vector3(0.0, 0.0, 0.18)
	set_process(true)


func update_pull(local_delta: Vector2) -> void:
	if not _holding:
		return
	_pulled = _pulled or local_delta.length() >= 6.0
	var horizontal := local_delta.x / (resistance_distance + absf(local_delta.x))
	var vertical := -local_delta.y / (resistance_distance + absf(local_delta.y))
	var pressure := clampf(local_delta.length() / resistance_distance, 0.18, 1.0)
	_target = Vector3(horizontal, vertical, pressure)


func end_hold() -> void:
	if not _holding:
		return
	_holding = false
	if not _pulled and _held_seconds <= tap_max_seconds and _cooldown <= 0.0:
		play_tap()
	else:
		_spring_home()


func play_tap() -> void:
	if _holding or _cooldown > 0.0 or not is_inside_tree():
		return
	_stop_motion()
	add_to_group(&"active_sticky_feedback")
	_cooldown = tap_cooldown_seconds
	set_process(true)
	_motion = create_tween()
	_motion.tween_property(self, "pose", Vector3(0.9, -0.25, 1.0), 0.085).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, "pose", Vector3(-0.55, 0.1, -0.25), 0.105).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(self, "pose", Vector3(0.22, 0.0, 0.2), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(self, "pose", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_callback(_finish_motion)


func cancel() -> void:
	remove_from_group(&"active_sticky_feedback")
	_stop_motion()
	_holding = false
	_pulled = false
	_cooldown = 0.0
	_target = Vector3.ZERO
	pose = Vector3.ZERO
	set_process(false)


func is_active() -> bool:
	return _holding or _motion != null


func _spring_home() -> void:
	_stop_motion()
	_motion = create_tween()
	_motion.tween_property(self, "pose", Vector3(-pose.x * 0.22, -pose.y * 0.15, -0.15), return_seconds * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, "pose", Vector3.ZERO, return_seconds * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_callback(_finish_motion)
	set_process(true)


func _stop_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func _finish_motion() -> void:
	remove_from_group(&"active_sticky_feedback")
	_motion = null
	pose = Vector3.ZERO
