class_name HammerImpactEffect
extends Control

signal pre_impact
signal impact
signal finished

const DESIGN_WIDTH := 720.0
const BURST_RAY_COUNT := 18
const SPARK_COUNT := 20
const TRAIL_LINE_COUNT := 4
const PINK := Color(1.0, 0.18, 0.72, 1.0)
const LIGHT_PINK := Color(1.0, 0.76, 0.94, 1.0)
const TEAL := Color(0.2, 1.0, 0.92, 1.0)

@export_range(0.1, 2.0, 0.01) var base_hammer_scale := 0.68

@onready var _impact_anchor: Node2D = %ImpactAnchor
@onready var _hammer_pivot: Node2D = %HammerPivot
@onready var _hammer_sprite: Sprite2D = %HammerSprite
@onready var _afterimage_early: Sprite2D = %AfterimageEarly
@onready var _afterimage_late: Sprite2D = %AfterimageLate
@onready var _animation_player: AnimationPlayer = %AnimationPlayer
@onready var _windup_audio: AudioStreamPlayer = %WindupAudio
@onready var _downstroke_audio: AudioStreamPlayer = %DownstrokeAudio
@onready var _impact_low_audio: AudioStreamPlayer = %ImpactLowAudio
@onready var _impact_magic_audio: AudioStreamPlayer = %ImpactMagicAudio
@onready var _sparkle_tail_audio: AudioStreamPlayer = %SparkleTailAudio

var _impact_position := Vector2.ZERO
var _layout_scale := 1.0
var _sound_enabled := true
var _haptics_enabled := true
var _pre_impact_reached := false
var _has_impacted := false
var _burst_amount := 0.0:
	set(value):
		_burst_amount = value
		queue_redraw()
var _flash_amount := 0.0:
	set(value):
		_flash_amount = value
		queue_redraw()
var _glow_amount := 0.0:
	set(value):
		_glow_amount = value
		queue_redraw()
var _trail_amount := 0.0:
	set(value):
		_trail_amount = value
		queue_redraw()
var _debris_amount := 0.0:
	set(value):
		_debris_amount = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_to_group(&"hammer_impact_effect")
	_apply_full_rect()


func play(target_screen_position: Vector2, sound_enabled := true, haptics_enabled := true) -> void:
	_apply_full_rect()
	_impact_position = target_screen_position
	_layout_scale = clampf(size.x / DESIGN_WIDTH, 0.75, 1.35)
	_sound_enabled = sound_enabled
	_haptics_enabled = haptics_enabled
	_pre_impact_reached = false
	_has_impacted = false
	visible = true
	_burst_amount = 0.0
	_flash_amount = 0.0
	_glow_amount = 0.0
	_trail_amount = 0.0
	_debris_amount = 0.0

	_impact_anchor.position = _impact_position
	_impact_anchor.scale = Vector2.ONE
	_hammer_sprite.scale = Vector2.ONE * base_hammer_scale * _layout_scale
	_afterimage_early.scale = _hammer_sprite.scale
	_afterimage_late.scale = _hammer_sprite.scale
	_animation_player.stop()
	_animation_player.play(&"strike")


func has_reached_pre_impact() -> bool:
	return _pre_impact_reached


func has_impacted() -> bool:
	return _has_impacted


func set_sound_enabled(enabled: bool) -> void:
	_sound_enabled = enabled
	if enabled:
		return
	for player in [_windup_audio, _downstroke_audio, _impact_low_audio, _impact_magic_audio, _sparkle_tail_audio]:
		if player != null:
			player.stop()


func _draw() -> void:
	if _trail_amount > 0.0:
		_draw_swing_trails()

	if _flash_amount > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.82, 0.95, 0.24 * _flash_amount))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.72, 1.0, 0.98, 0.08 * _flash_amount))

	if _glow_amount > 0.0:
		_draw_radial_glow()

	if _burst_amount > 0.0:
		_draw_shockwave_and_starburst()

	if _debris_amount > 0.0:
		_draw_sparks_and_debris()


func _draw_swing_trails() -> void:
	var alpha := sin(_trail_amount * PI)
	if alpha <= 0.0:
		return
	for trail_index in range(TRAIL_LINE_COUNT):
		var spacing := float(trail_index) * 18.0 * _layout_scale
		var points := PackedVector2Array([
			_impact_position + Vector2(248.0, -330.0) * _layout_scale + Vector2(spacing, -spacing * 0.25),
			_impact_position + Vector2(202.0, -258.0) * _layout_scale + Vector2(spacing * 0.5, 0.0),
			_impact_position + Vector2(130.0, -166.0) * _layout_scale,
			_impact_position + Vector2(50.0, -62.0) * _layout_scale,
		])
		var color := TEAL if trail_index % 2 == 0 else LIGHT_PINK
		color.a = alpha * (0.5 - float(trail_index) * 0.07)
		draw_polyline(points, color, (8.0 - float(trail_index)) * _layout_scale, true)


func _draw_radial_glow() -> void:
	var alpha := _glow_amount
	var expansion := 1.0 - alpha
	for glow_index in range(4, 0, -1):
		var radius := lerpf(96.0, 284.0, expansion) * float(glow_index) / 4.0 * _layout_scale
		var glow_color := PINK if glow_index % 2 == 0 else TEAL
		glow_color.a = alpha * (0.035 + float(5 - glow_index) * 0.016)
		draw_circle(_impact_position, radius, glow_color)


func _draw_shockwave_and_starburst() -> void:
	var alpha := _burst_amount
	var expansion := 1.0 - alpha
	var radius := lerpf(72.0, 224.0, expansion) * _layout_scale
	draw_arc(
		_impact_position,
		radius,
		0.0,
		TAU,
		64,
		Color(PINK, 0.9 * alpha),
		lerpf(10.0, 3.0, expansion) * _layout_scale,
		true
	)
	draw_arc(
		_impact_position,
		radius * 0.72,
		0.0,
		TAU,
		48,
		Color(TEAL, 0.75 * alpha),
		lerpf(7.0, 2.0, expansion) * _layout_scale,
		true
	)

	for ray_index in range(BURST_RAY_COUNT):
		var direction := Vector2.RIGHT.rotated(TAU * float(ray_index) / float(BURST_RAY_COUNT))
		var long_ray := ray_index % 3 == 0
		var start := _impact_position + direction * (34.0 * _layout_scale)
		var initial_distance := 230.0 if long_ray else 190.0
		var final_distance := 334.0 if long_ray else 272.0
		var end_distance := lerpf(initial_distance, final_distance, expansion)
		var end := _impact_position + direction * (end_distance * _layout_scale)
		var ray_color := Color.WHITE if long_ray else (TEAL if ray_index % 2 == 0 else LIGHT_PINK)
		ray_color.a = (0.96 if long_ray else 0.72) * alpha
		var ray_width := (7.0 if long_ray else 3.5) * _layout_scale
		draw_line(start, end, ray_color, ray_width, true)

	draw_circle(
		_impact_position,
		lerpf(38.0, 5.0, expansion) * _layout_scale,
		Color(1.0, 1.0, 1.0, 0.96 * alpha)
	)


func _draw_sparks_and_debris() -> void:
	var alpha := _debris_amount
	var travel := 1.0 - alpha
	for spark_index in range(SPARK_COUNT):
		var angle := TAU * float(spark_index) / float(SPARK_COUNT) + 0.17 * float(spark_index % 3)
		var direction := Vector2.RIGHT.rotated(angle)
		var distance_scale := 0.78 + 0.16 * float(spark_index % 4)
		var distance := lerpf(72.0, 248.0 * distance_scale, travel) * _layout_scale
		var position := _impact_position + direction * distance
		var size := (7.0 if spark_index % 3 == 0 else 4.5) * _layout_scale * maxf(alpha, 0.35)
		var color := TEAL if spark_index % 2 == 0 else LIGHT_PINK
		color.a = 0.88 * alpha
		if spark_index % 3 == 0:
			var tangent := direction.rotated(PI * 0.5)
			var points := PackedVector2Array([
				position + direction * size * 1.8,
				position + tangent * size * 0.65,
				position - direction * size * 1.2,
				position - tangent * size * 0.65,
			])
			draw_colored_polygon(points, color)
		else:
			draw_circle(position, size, color)


func _play_windup_audio() -> void:
	_play_audio(_windup_audio)


func _play_downstroke_audio() -> void:
	_play_audio(_downstroke_audio)


func _emit_pre_impact() -> void:
	_pre_impact_reached = true
	pre_impact.emit()


func _emit_impact() -> void:
	_has_impacted = true
	_play_audio(_impact_low_audio)
	_play_audio(_impact_magic_audio)
	if _haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(65, 0.75)
	impact.emit()


func _play_sparkle_tail_audio() -> void:
	_play_audio(_sparkle_tail_audio)


func _play_audio(player: AudioStreamPlayer) -> void:
	if not _sound_enabled or player == null:
		return
	player.stop()
	player.play()


func _emit_finished() -> void:
	visible = false
	finished.emit()


func _apply_full_rect() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
