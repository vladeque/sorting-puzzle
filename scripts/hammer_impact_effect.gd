class_name HammerImpactEffect
extends Control

signal pre_impact
signal impact
signal finished

const DESIGN_WIDTH := 720.0
const BURST_RAY_COUNT := 18
const SPARK_COUNT := 20
const TRAIL_LINE_COUNT := 4
const TRAIL_SAMPLE_COUNT := 7
const PINK := Color(1.0, 0.18, 0.72, 1.0)
const LIGHT_PINK := Color(1.0, 0.76, 0.94, 1.0)
const WARM := Color(1.0, 0.86, 0.42, 1.0)

## Strikes landing right of this fraction of the overlay mirror their approach so the opening pose
## stays inside the viewport instead of hanging off the right edge.
const MIRROR_THRESHOLD_RATIO := 0.55

const WINDUP_TEXTURE := preload("res://assets/abilities/ability_hammer_swing_1.png")
const RISE_TEXTURE := preload("res://assets/abilities/ability_hammer_swing_2.png")
const ANTICIPATION_TEXTURE := preload("res://assets/abilities/ability_hammer_swing_3.png")
const MID_TEXTURE := preload("res://assets/abilities/ability_hammer_swing_4.png")
const SMEAR_EARLY_TEXTURE := preload("res://assets/abilities/ability_hammer_swing_5.png")
const SMEAR_LATE_TEXTURE := preload("res://assets/abilities/ability_hammer_swing_6.png")
const IMPACT_TEXTURE := preload("res://assets/abilities/ability_hammer_swing_7.png")
const IMPACT_OVERSHOOT_TEXTURE := preload("res://assets/abilities/ability_hammer_swing_8.png")

## Offset of each supplied frame's head centre from its texture centre, in texture pixels. The
## sprite is shifted by the negation of this so the head follows one continuous arc and the final
## frame lands on the pivot where the impact VFX are drawn.
const POSE_HEAD_OFFSETS := {
	WINDUP_TEXTURE: Vector2(-8.0, -145.0),
	RISE_TEXTURE: Vector2(4.0, -148.0),
	ANTICIPATION_TEXTURE: Vector2(0.0, 0.0),
	MID_TEXTURE: Vector2(2.0, -140.0),
	SMEAR_EARLY_TEXTURE: Vector2(0.0, -158.0),
	SMEAR_LATE_TEXTURE: Vector2(-3.0, -170.0),
	IMPACT_TEXTURE: Vector2(34.0, -205.0),
	IMPACT_OVERSHOOT_TEXTURE: Vector2(46.0, -195.0),
}

@export_range(0.1, 2.0, 0.01) var base_hammer_scale := 0.4

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
var _trail_points: PackedVector2Array = PackedVector2Array()
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
	# Runs after the child AnimationPlayer so pose alignment reads the current frame's texture.
	process_priority = 1
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
	_trail_points.clear()

	_impact_anchor.position = _impact_position
	_impact_anchor.scale = Vector2(-1.0, 1.0) if _should_mirror_approach() else Vector2.ONE
	_hammer_sprite.scale = Vector2.ONE * base_hammer_scale * _layout_scale
	_afterimage_early.scale = _hammer_sprite.scale
	_afterimage_late.scale = _hammer_sprite.scale
	_align_sprite_to_pivot(_hammer_sprite)
	_align_sprite_to_pivot(_afterimage_early)
	_align_sprite_to_pivot(_afterimage_late)
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


func _process(_delta: float) -> void:
	if not visible:
		return

	_align_sprite_to_pivot(_hammer_sprite)
	_sample_trail_point()


## Keeps the head centre of whichever supplied frame is on screen pinned to the pivot origin.
func _align_sprite_to_pivot(sprite: Sprite2D) -> void:
	if sprite == null or sprite.texture == null:
		return
	var head_offset: Vector2 = POSE_HEAD_OFFSETS.get(sprite.texture, Vector2.ZERO)
	sprite.position = -head_offset * sprite.scale


func _get_head_position() -> Vector2:
	# The sprite alignment above places the head centre exactly on the pivot origin, so the head
	# position collapses to the pivot's own transform.
	return _impact_anchor.position + _impact_anchor.scale * _hammer_pivot.position


func _sample_trail_point() -> void:
	if _trail_amount <= 0.0:
		if not _trail_points.is_empty():
			_trail_points.clear()
		return

	_trail_points.append(_get_head_position())
	if _trail_points.size() > TRAIL_SAMPLE_COUNT:
		_trail_points.remove_at(0)
	queue_redraw()


func _draw() -> void:
	if _trail_amount > 0.0:
		_draw_swing_trails()

	if _glow_amount > 0.0:
		_draw_radial_glow()

	if _burst_amount > 0.0:
		_draw_starburst()

	if _flash_amount > 0.0:
		_draw_flash_core()

	if _debris_amount > 0.0:
		_draw_sparks_and_debris()


## Traces the path the head actually travelled this swing rather than a fixed screen-space arc.
func _draw_swing_trails() -> void:
	if _trail_points.size() < 2:
		return

	var travel := _trail_points[_trail_points.size() - 1] - _trail_points[0]
	if travel.length() < 1.0:
		return

	var perpendicular := travel.normalized().orthogonal()
	for strand_index in range(TRAIL_LINE_COUNT):
		var spread := (float(strand_index) - float(TRAIL_LINE_COUNT - 1) * 0.5) * 15.0 * _layout_scale
		var strand := PackedVector2Array()
		for point in _trail_points:
			strand.append(point + perpendicular * spread)
		var color := WARM if strand_index % 2 == 0 else LIGHT_PINK
		color.a = _trail_amount * (0.3 - absf(spread) * 0.005)
		draw_polyline(strand, color, (6.0 - float(strand_index)) * _layout_scale, true)


## Drawn additively (see the overlay's canvas material), so the glow brightens the board instead of
## staining it. Sized to roughly the target cell plus its neighbours rather than the whole shelf.
func _draw_radial_glow() -> void:
	var alpha := _glow_amount
	var expansion := 1.0 - alpha
	for glow_index in range(6, 0, -1):
		var radius := lerpf(150.0, 218.0, expansion) * float(glow_index) / 6.0 * _layout_scale
		var glow_color := PINK if glow_index % 2 == 0 else LIGHT_PINK
		glow_color.a = alpha * (0.035 + float(7 - glow_index) * 0.024)
		draw_circle(_impact_position, radius, glow_color)


func _draw_starburst() -> void:
	var alpha := _burst_amount
	var expansion := 1.0 - alpha
	for ray_index in range(BURST_RAY_COUNT):
		var direction := Vector2.RIGHT.rotated(TAU * float(ray_index) / float(BURST_RAY_COUNT))
		var tangent := direction.orthogonal()
		var long_ray := ray_index % 3 == 0
		var base_distance := 30.0 * _layout_scale
		var initial_distance := 168.0 if long_ray else 126.0
		var final_distance := 258.0 if long_ray else 190.0
		var tip_distance := lerpf(initial_distance, final_distance, expansion) * _layout_scale
		var half_width := (13.0 if long_ray else 7.5) * _layout_scale * alpha
		var spike := PackedVector2Array([
			_impact_position + direction * tip_distance,
			_impact_position + direction * base_distance + tangent * half_width,
			_impact_position + direction * base_distance - tangent * half_width,
		])
		var ray_color := Color.WHITE if long_ray else WARM
		ray_color.a = (0.95 if long_ray else 0.7) * alpha
		draw_colored_polygon(spike, ray_color)


## Localised hot core. A full-screen flash washed out the board and hid what was being cleared.
func _draw_flash_core() -> void:
	var alpha := _flash_amount
	var expansion := 1.0 - alpha
	for core_index in range(4, 0, -1):
		var radius := lerpf(46.0, 112.0, expansion) * float(core_index) / 4.0 * _layout_scale
		var core_color := Color(1.0, 0.94, 0.99, alpha * (0.1 + float(5 - core_index) * 0.11))
		draw_circle(_impact_position, radius, core_color)


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
		var color := WARM if spark_index % 2 == 0 else LIGHT_PINK
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


func _should_mirror_approach() -> bool:
	return size.x > 0.0 and _impact_position.x > size.x * MIRROR_THRESHOLD_RATIO


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
