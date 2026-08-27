class_name FreezerSnowflakeField
extends Control

## Small, pooled snowflakes emitted inward from the Freezer's perimeter glow. One field owns the
## simulation; the clipped TopHud field points at it and draws the same particles so both render
## passes stay pixel-synchronized without running a duplicate simulation.

const DESIGN_SHORT_SIDE := 720.0
const FLAKE_COLOR := Color(0.7, 0.92, 1.0, 1.0)
const FLAKE_HIGHLIGHT := Color(0.95, 1.0, 1.0, 1.0)


class Snowflake:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var age := 0.0
	var lifetime := 0.6
	var radius := 6.0
	var rotation := 0.0
	var angular_velocity := 0.0
	var highlight_mix := 0.5


@export_range(1, 64, 1) var max_particles := 40
@export_range(0, 48, 1) var activation_burst_count := 18
@export_range(0.0, 48.0, 0.5) var emission_rate_per_second := 36.0
@export_range(0.1, 2.0, 0.01) var minimum_lifetime_seconds := 0.24
@export_range(0.1, 2.0, 0.01) var maximum_lifetime_seconds := 0.46
@export_range(0.05, 0.6, 0.01) var shutdown_fade_seconds := 0.16
@export var random_seed := 824_631
@export var mirror_source_path: NodePath

var _particles: Array[Snowflake] = []
var _rng := RandomNumberGenerator.new()
var _mirror_source: FreezerSnowflakeField
var _emission_accumulator := 0.0
var _activation_serial := 0
var _is_emitting := false
var _effect_opacity := 0.0
var _modal_shade_color := Color(0.02, 0.025, 0.03, 0.66)
var _modal_shade_amount := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not mirror_source_path.is_empty():
		_mirror_source = get_node_or_null(mirror_source_path) as FreezerSnowflakeField
		if _mirror_source == null:
			push_warning("Freezer snowflake mirror could not resolve its source field.")
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _mirror_source != null:
		if _mirror_source.is_emitting() or _mirror_source.get_particle_count() > 0:
			queue_redraw()
		return

	if not _is_emitting and _particles.is_empty():
		return

	var safe_delta := minf(maxf(delta, 0.0), 0.1)
	if _is_emitting:
		_emission_accumulator += safe_delta * emission_rate_per_second
		while _emission_accumulator >= 1.0 and _particles.size() < max_particles:
			_emission_accumulator -= 1.0
			_spawn_snowflake(false)

	for particle_index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[particle_index]
		particle.age += safe_delta
		if particle.age >= particle.lifetime:
			_particles.remove_at(particle_index)
			continue
		particle.position += particle.velocity * safe_delta
		particle.rotation += particle.angular_velocity * safe_delta
	queue_redraw()


func _draw() -> void:
	var source := _mirror_source if _mirror_source != null else self
	for particle in source._particles:
		_draw_snowflake(particle, source)


func set_emitting(should_emit: bool, immediate := false) -> void:
	if _mirror_source != null:
		return
	if should_emit == _is_emitting:
		if not should_emit and immediate:
			_particles.clear()
			queue_redraw()
		return

	_is_emitting = should_emit
	_emission_accumulator = 0.0
	if _is_emitting:
		_activation_serial += 1
		_rng.seed = random_seed + _activation_serial * 7_919
		for _burst_index in range(mini(activation_burst_count, max_particles)):
			_spawn_snowflake(true)
	else:
		for particle in _particles:
			particle.lifetime = minf(
				particle.lifetime,
				particle.age + shutdown_fade_seconds
			)
		if immediate:
			_particles.clear()
	queue_redraw()


func set_effect_opacity(value: float) -> void:
	_effect_opacity = clampf(value, 0.0, 1.0)
	queue_redraw()


func set_modal_shade(shade_color: Color, shade_amount: float) -> void:
	_modal_shade_color = shade_color
	_modal_shade_amount = clampf(shade_amount, 0.0, 1.0)
	queue_redraw()


func is_emitting() -> bool:
	return _is_emitting


func get_particle_count() -> int:
	return _particles.size()


func get_maximum_lifetime() -> float:
	return maximum_lifetime_seconds


func get_mirror_source() -> FreezerSnowflakeField:
	return _mirror_source


func _spawn_snowflake(from_activation_burst: bool) -> void:
	if _particles.size() >= max_particles or size.x <= 0.0 or size.y <= 0.0:
		return

	var layout_scale := clampf(minf(size.x, size.y) / DESIGN_SHORT_SIDE, 0.75, 1.5)
	var emission_band := maxf(8.0, minf(size.x, size.y) * 0.045)
	var inward_direction := Vector2.ZERO
	var particle := Snowflake.new()
	match _rng.randi_range(0, 3):
		0:
			particle.position = Vector2(
				_rng.randf_range(0.0, size.x),
				_rng.randf_range(0.0, emission_band)
			)
			inward_direction = Vector2.DOWN
		1:
			particle.position = Vector2(
				_rng.randf_range(0.0, size.x),
				size.y - _rng.randf_range(0.0, emission_band)
			)
			inward_direction = Vector2.UP
		2:
			particle.position = Vector2(
				_rng.randf_range(0.0, emission_band),
				_rng.randf_range(0.0, size.y)
			)
			inward_direction = Vector2.RIGHT
		_:
			particle.position = Vector2(
				size.x - _rng.randf_range(0.0, emission_band),
				_rng.randf_range(0.0, size.y)
			)
			inward_direction = Vector2.LEFT

	var speed := _rng.randf_range(85.0, 145.0) * layout_scale
	particle.velocity = inward_direction.rotated(_rng.randf_range(-0.34, 0.34)) * speed
	particle.lifetime = _rng.randf_range(
		minimum_lifetime_seconds,
		maximum_lifetime_seconds
	)
	particle.radius = _rng.randf_range(4.0, 8.0) * layout_scale
	particle.rotation = _rng.randf_range(0.0, TAU)
	particle.angular_velocity = _rng.randf_range(-3.8, 3.8)
	particle.highlight_mix = _rng.randf_range(0.15, 0.85)
	if from_activation_burst:
		particle.age = _rng.randf_range(0.0, particle.lifetime * 0.16)
	_particles.append(particle)


func _draw_snowflake(particle: Snowflake, source: FreezerSnowflakeField) -> void:
	var life_ratio := clampf(particle.age / maxf(particle.lifetime, 0.001), 0.0, 1.0)
	var fade_in := smoothstep(0.0, 0.12, life_ratio)
	var fade_out := 1.0 - smoothstep(0.42, 1.0, life_ratio)
	var flake_color := FLAKE_COLOR.lerp(FLAKE_HIGHLIGHT, particle.highlight_mix)
	flake_color.a = fade_in * fade_out * source._effect_opacity * 0.94
	if _mirror_source != null:
		var shade_mix := source._modal_shade_color.a * source._modal_shade_amount
		flake_color.r = lerpf(flake_color.r, source._modal_shade_color.r, shade_mix)
		flake_color.g = lerpf(flake_color.g, source._modal_shade_color.g, shade_mix)
		flake_color.b = lerpf(flake_color.b, source._modal_shade_color.b, shade_mix)
	if flake_color.a <= 0.001:
		return

	var line_width := maxf(1.0, particle.radius * 0.17)
	for arm_index in range(6):
		var angle := particle.rotation + TAU * float(arm_index) / 6.0
		var direction := Vector2.RIGHT.rotated(angle)
		var tip := particle.position + direction * particle.radius
		draw_line(particle.position, tip, flake_color, line_width, true)
		var branch_base := particle.position + direction * particle.radius * 0.58
		var branch_length := particle.radius * 0.27
		draw_line(
			branch_base,
			branch_base + direction.rotated(PI - 0.62) * branch_length,
			flake_color,
			line_width,
			true
		)
		draw_line(
			branch_base,
			branch_base + direction.rotated(PI + 0.62) * branch_length,
			flake_color,
			line_width,
			true
		)
