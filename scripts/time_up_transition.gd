extends Control
class_name TimeUpTransition

## Brief timeout punctuation shown after the countdown reaches 00:00 and before the recoverable
## time-extension modal opens. The level owns gameplay state and audio; this scene owns the
## fullscreen dim, expanding alarm ring, input block, and their timing.

const PULSE_DELAY_SECONDS := 0.08
const PULSE_DURATION_SECONDS := 0.52
const DIM_DELAY_SECONDS := 0.10
const DIM_DURATION_SECONDS := 0.56
const RELEASE_DURATION_SECONDS := 0.18
const START_SHADE_COLOR := Color(0.16, 0.015, 0.01, 0.0)
const END_SHADE_COLOR := Color(0.16, 0.015, 0.01, 0.64)

@onready var _shade := %Shade as ColorRect

var _pulse_origin := Vector2.ZERO
var _pulse_target_radius := 1.0
var _pulse_progress := 0.0:
	set(value):
		_pulse_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var _pulse_tween: Tween
var _dim_tween: Tween
var _release_tween: Tween


func _ready() -> void:
	hide()


func is_transitioning() -> bool:
	return visible


## Keeps the final shade visible when it returns. Level starts the modal reveal first, then calls
## release(), so the two shades crossfade without flashing the bright board between them.
func play(timer_global_center: Vector2) -> void:
	_reset_tweens()
	modulate = Color.WHITE
	_shade.color = START_SHADE_COLOR
	_pulse_origin = get_global_transform_with_canvas().affine_inverse() * timer_global_center
	_pulse_target_radius = _farthest_corner_distance(_pulse_origin) + 32.0
	_pulse_progress = 0.0
	show()

	_pulse_tween = create_tween()
	_pulse_tween.tween_interval(PULSE_DELAY_SECONDS)
	_pulse_tween.tween_property(
		self,
		"_pulse_progress",
		1.0,
		PULSE_DURATION_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_dim_tween = create_tween()
	_dim_tween.tween_interval(DIM_DELAY_SECONDS)
	_dim_tween.tween_property(
		_shade,
		"color",
		END_SHADE_COLOR,
		DIM_DURATION_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(DIM_DELAY_SECONDS + DIM_DURATION_SECONDS).timeout
	if not is_inside_tree():
		return


func release() -> void:
	if not visible or _release_tween != null:
		return

	_release_tween = create_tween()
	_release_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		RELEASE_DURATION_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _release_tween.finished
	if not is_inside_tree():
		return
	hide()
	modulate = Color.WHITE
	_release_tween = null


func reset() -> void:
	_reset_tweens()
	_pulse_progress = 0.0
	modulate = Color.WHITE
	if _shade != null:
		_shade.color = START_SHADE_COLOR
	hide()


func _draw() -> void:
	if not visible or _pulse_progress <= 0.0 or _pulse_progress >= 1.0:
		return

	var eased_progress := ease(_pulse_progress, -1.7)
	var radius := lerpf(20.0, _pulse_target_radius, eased_progress)
	var alpha := pow(1.0 - _pulse_progress, 1.25)
	var soft_width := lerpf(20.0, 44.0, _pulse_progress)
	var bright_width := lerpf(6.0, 13.0, _pulse_progress)
	draw_arc(
		_pulse_origin,
		radius,
		0.0,
		TAU,
		128,
		Color(0.42, 0.015, 0.01, alpha * 0.34),
		soft_width,
		true
	)
	draw_arc(
		_pulse_origin,
		radius,
		0.0,
		TAU,
		128,
		Color(1.0, 0.2, 0.08, alpha * 0.82),
		bright_width,
		true
	)


func _farthest_corner_distance(origin: Vector2) -> float:
	var farthest := 0.0
	for corner in [Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]:
		farthest = maxf(farthest, origin.distance_to(corner))
	return farthest


func _reset_tweens() -> void:
	for tween in [_pulse_tween, _dim_tween, _release_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_pulse_tween = null
	_dim_tween = null
	_release_tween = null
