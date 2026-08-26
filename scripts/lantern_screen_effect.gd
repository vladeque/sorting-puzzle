class_name LanternScreenEffect
extends CanvasLayer

## Full-screen Lantern Focus Mode presentation. A procedural overlay shades non-target gameplay,
## cuts warm pools around highlighted items, and falls back to a searching beam when no target
## currently exists.
## Gameplay owns the timer; this scene only mirrors visual state and never intercepts input.

const MAX_TARGET_COUNT := 16

@export_range(0.05, 1.5, 0.01) var activation_duration_seconds := 0.52
@export_range(0.05, 1.5, 0.01) var fade_duration_seconds := 0.38

@onready var _overlay := %Overlay as Control
@onready var _searchlight_wash := %SearchlightWash as ColorRect

var _is_active := false
var _intensity := 0.0
var _activation_progress := 1.0
var _elapsed_seconds := 0.0
var _viewport_size := Vector2.ZERO
var _target_screen_positions: Array[Vector2] = []
var _transition_tween: Tween
var _wash_material: ShaderMaterial


func _ready() -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_searchlight_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash_material = _searchlight_wash.material as ShaderMaterial
	if _wash_material != null:
		_wash_material = _wash_material.duplicate() as ShaderMaterial
		_searchlight_wash.material = _wash_material
	apply_layout(get_viewport().get_visible_rect().size)
	_apply_inactive_state()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed_seconds += maxf(delta, 0.0)
	if _wash_material != null:
		_wash_material.set_shader_parameter(&"elapsed_seconds", _elapsed_seconds)


func apply_layout(viewport_size: Vector2) -> void:
	_viewport_size = Vector2(maxf(viewport_size.x, 0.0), maxf(viewport_size.y, 0.0))
	_apply_target_shader_parameters()


## Receives viewport-space item centers from Level. Positions are refreshed during the Lantern
## window so pools follow moving shelves and item transitions instead of lagging behind them.
func set_target_positions(screen_positions: Array[Vector2]) -> void:
	_target_screen_positions.clear()
	for screen_position in screen_positions:
		if _target_screen_positions.size() >= MAX_TARGET_COUNT:
			break
		_target_screen_positions.append(screen_position)
	_apply_target_shader_parameters()


func get_target_count() -> int:
	return _target_screen_positions.size()


func get_target_positions_normalized() -> PackedVector2Array:
	var normalized_positions := PackedVector2Array()
	if _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		return normalized_positions
	for screen_position in _target_screen_positions:
		normalized_positions.append(screen_position / _viewport_size)
	return normalized_positions


## Repeated active updates are intentionally idempotent because Level refreshes timed visuals
## from several state paths. `immediate` is reserved for level rebuild/teardown cleanup.
func set_active(should_be_active: bool, immediate := false) -> void:
	if should_be_active == _is_active:
		if immediate:
			_kill_transition()
			if should_be_active:
				_apply_active_state()
			else:
				_apply_inactive_state()
		return

	_is_active = should_be_active
	_kill_transition()
	if _is_active:
		_play_activation(immediate)
	else:
		_play_fade(immediate)


func is_active() -> bool:
	return _is_active


func get_effect_intensity() -> float:
	return _intensity


func get_activation_progress() -> float:
	return _activation_progress


func get_elapsed_seconds() -> float:
	return _elapsed_seconds


func _play_activation(immediate: bool) -> void:
	visible = true
	_elapsed_seconds = 0.0
	if _wash_material != null:
		_wash_material.set_shader_parameter(&"elapsed_seconds", 0.0)
	if immediate:
		_apply_active_state()
		return

	_set_effect_intensity(0.0)
	_set_activation_progress(0.0)
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_method(
		_set_effect_intensity,
		0.0,
		1.0,
		activation_duration_seconds * 0.72
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_method(
		_set_activation_progress,
		0.0,
		1.0,
		activation_duration_seconds
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _play_fade(immediate: bool) -> void:
	if immediate or not visible:
		_apply_inactive_state()
		return

	_transition_tween = create_tween()
	_transition_tween.tween_method(
		_set_effect_intensity,
		_intensity,
		0.0,
		fade_duration_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.finished.connect(_on_fade_finished)


func _on_fade_finished() -> void:
	if not _is_active:
		_apply_inactive_state()


func _apply_active_state() -> void:
	visible = true
	_set_effect_intensity(1.0)
	_set_activation_progress(1.0)


func _apply_inactive_state() -> void:
	visible = false
	_elapsed_seconds = 0.0
	_set_effect_intensity(0.0)
	_set_activation_progress(1.0)
	if _wash_material != null:
		_wash_material.set_shader_parameter(&"elapsed_seconds", 0.0)


func _set_effect_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	if _wash_material != null:
		_wash_material.set_shader_parameter(&"intensity", _intensity)


func _set_activation_progress(value: float) -> void:
	_activation_progress = clampf(value, 0.0, 1.0)
	if _wash_material != null:
		_wash_material.set_shader_parameter(&"activation_progress", _activation_progress)


func _apply_target_shader_parameters() -> void:
	if _wash_material == null:
		return
	var normalized_positions := PackedVector2Array()
	normalized_positions.resize(MAX_TARGET_COUNT)
	for target_index in range(MAX_TARGET_COUNT):
		normalized_positions[target_index] = Vector2(-2.0, -2.0)
	if _viewport_size.x > 0.0 and _viewport_size.y > 0.0:
		for target_index in range(_target_screen_positions.size()):
			normalized_positions[target_index] = (
				_target_screen_positions[target_index] / _viewport_size
			)
	_wash_material.set_shader_parameter(&"target_count", _target_screen_positions.size())
	_wash_material.set_shader_parameter(&"target_positions", normalized_positions)


func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
