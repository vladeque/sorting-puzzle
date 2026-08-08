class_name LevelCompletionConfetti
extends Control

## Layered paper-confetti celebration played while a completed board remains visible and while the
## reward overlay begins opening. Five independently tuned particle layers per side give the burst
## silhouette variety and depth without increasing the previous effect's approximate particle
## budget. A delayed center flash and star pop provide a clear visual beat where both arcs meet.

signal finished

const DESIGN_WIDTH := 720.0
const DESIGN_HEIGHT := 1280.0
const MIN_PIECE_SCALE := 0.75
const MAX_PIECE_SCALE := 1.35
const GRAVITY_AT_DESIGN_HEIGHT := 1250.0
const DAMPING_COMPENSATION := 1.03
const VELOCITY_SPREAD := 0.14
const SETTLE_SECONDS := 0.35
const CENTER_BEAT_DELAY := 0.22
const CENTER_FLASH_SCALE := 1.35
const CENTER_FLASH_SECONDS := 0.42

@export var muzzle_inset := Vector2(28.0, 10.0)
@export_range(0.25, 0.75, 0.01) var center_height_ratio := 0.43

@onready var _central_flash: Sprite2D = %CentralFlash
@onready var _center_burst: CPUParticles2D = %CenterBurst
@onready var _left_back_curl: CPUParticles2D = %LeftBackCurl
@onready var _right_back_curl: CPUParticles2D = %RightBackCurl
@onready var _left_cannon: CPUParticles2D = %LeftCannon
@onready var _right_cannon: CPUParticles2D = %RightCannon
@onready var _left_fold: CPUParticles2D = %LeftFold
@onready var _right_fold: CPUParticles2D = %RightFold
@onready var _left_stars: CPUParticles2D = %LeftStars
@onready var _right_stars: CPUParticles2D = %RightStars
@onready var _left_front_curl: CPUParticles2D = %LeftFrontCurl
@onready var _right_front_curl: CPUParticles2D = %RightFrontCurl

var _side_emitters: Array[CPUParticles2D] = []
var _base_piece_sizes: Dictionary = {}
var _viewport_size := Vector2.ZERO
var _safe_margins := Vector4.ZERO
var _center_tween: Tween
var _play_generation := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_side_emitters = [
		_left_back_curl,
		_right_back_curl,
		_left_cannon,
		_right_cannon,
		_left_fold,
		_right_fold,
		_left_stars,
		_right_stars,
		_left_front_curl,
		_right_front_curl,
	]
	for emitter: CPUParticles2D in _side_emitters:
		_base_piece_sizes[emitter] = Vector2(emitter.scale_amount_min, emitter.scale_amount_max)
	_apply_full_rect()


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_safe_margins = safe_margins
	_viewport_size = viewport_size
	_apply_full_rect()


## Fires all layers and returns once the last paper piece has faded. The caller deliberately opens
## the reward overlay before this finishes so the falling foreground pieces bridge both states.
func play() -> void:
	_play_generation += 1
	var my_generation := _play_generation
	_apply_full_rect()
	visible = true
	var viewport_size := _viewport_size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size

	_aim_layer_pair(_left_back_curl, _right_back_curl, viewport_size, 0.52, 1.02)
	_aim_layer_pair(_left_cannon, _right_cannon, viewport_size, 0.46, 0.92)
	_aim_layer_pair(_left_fold, _right_fold, viewport_size, 0.44, 0.88)
	_aim_layer_pair(_left_stars, _right_stars, viewport_size, 0.4, 0.82)
	_aim_layer_pair(_left_front_curl, _right_front_curl, viewport_size, 0.36, 0.72)
	_play_center_beat(viewport_size)

	await get_tree().create_timer(get_burst_duration()).timeout
	if not is_inside_tree() or my_generation != _play_generation:
		return

	visible = false
	finished.emit()


func get_burst_duration() -> float:
	var duration := 0.0
	for emitter: CPUParticles2D in _side_emitters:
		var emission_seconds := emitter.lifetime * (1.0 - emitter.explosiveness)
		duration = maxf(duration, emission_seconds + emitter.lifetime)
	return duration + SETTLE_SECONDS


func _aim_layer_pair(
	left: CPUParticles2D,
	right: CPUParticles2D,
	viewport_size: Vector2,
	apex_height_ratio: float,
	horizontal_reach_ratio: float
) -> void:
	_aim_emitter(left, 1.0, viewport_size, apex_height_ratio, horizontal_reach_ratio)
	_aim_emitter(right, -1.0, viewport_size, apex_height_ratio, horizontal_reach_ratio)


func _aim_emitter(
	emitter: CPUParticles2D,
	horizontal_sign: float,
	viewport_size: Vector2,
	apex_height_ratio: float,
	horizontal_reach_ratio: float
) -> void:
	var piece_scale := clampf(
		minf(viewport_size.x / DESIGN_WIDTH, viewport_size.y / DESIGN_HEIGHT),
		MIN_PIECE_SCALE,
		MAX_PIECE_SCALE
	)
	var gravity := GRAVITY_AT_DESIGN_HEIGHT * viewport_size.y / DESIGN_HEIGHT
	var inset := muzzle_inset * piece_scale
	var muzzle_x := inset.x if horizontal_sign > 0.0 else viewport_size.x - inset.x
	emitter.position = Vector2(muzzle_x, viewport_size.y - _safe_margins.w - inset.y)

	var apex_height := viewport_size.y * apex_height_ratio
	var vertical_speed := sqrt(2.0 * gravity * apex_height)
	var rise_seconds := vertical_speed / gravity
	var horizontal_distance := absf(viewport_size.x * 0.5 - muzzle_x) * horizontal_reach_ratio
	var horizontal_speed := horizontal_distance / rise_seconds
	var launch_speed := Vector2(horizontal_speed, vertical_speed).length() * DAMPING_COMPENSATION

	emitter.gravity = Vector2(0.0, gravity)
	emitter.direction = Vector2(horizontal_speed * horizontal_sign, -vertical_speed).normalized()
	emitter.initial_velocity_min = launch_speed * (1.0 - VELOCITY_SPREAD)
	emitter.initial_velocity_max = launch_speed * (1.0 + VELOCITY_SPREAD)
	var base_size: Vector2 = _base_piece_sizes[emitter]
	emitter.scale_amount_min = base_size.x * piece_scale
	emitter.scale_amount_max = base_size.y * piece_scale
	emitter.restart()


func _play_center_beat(viewport_size: Vector2) -> void:
	var center := Vector2(viewport_size.x * 0.5, viewport_size.y * center_height_ratio)
	var piece_scale := clampf(
		minf(viewport_size.x / DESIGN_WIDTH, viewport_size.y / DESIGN_HEIGHT),
		MIN_PIECE_SCALE,
		MAX_PIECE_SCALE
	)
	_center_burst.position = center
	_center_burst.scale_amount_min = 0.12 * piece_scale
	_center_burst.scale_amount_max = 0.22 * piece_scale
	_central_flash.position = center
	_central_flash.scale = Vector2.ZERO
	_central_flash.modulate.a = 0.0

	if _center_tween != null and _center_tween.is_valid():
		_center_tween.kill()
	_center_tween = create_tween()
	_center_tween.tween_interval(CENTER_BEAT_DELAY)
	_center_tween.tween_callback(_center_burst.restart)
	_center_tween.tween_property(
		_central_flash,
		"modulate:a",
		0.82,
		CENTER_FLASH_SECONDS * 0.32
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_center_tween.parallel().tween_property(
		_central_flash,
		"scale",
		Vector2.ONE * CENTER_FLASH_SCALE * piece_scale,
		CENTER_FLASH_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_center_tween.tween_property(
		_central_flash,
		"modulate:a",
		0.0,
		CENTER_FLASH_SECONDS * 0.68
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _apply_full_rect() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
