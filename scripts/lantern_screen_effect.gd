class_name LanternScreenEffect
extends CanvasLayer

## Full-screen Golden Searchlight presentation for the Lantern ability. A procedural overlay adds
## a restrained warm vignette, an activation bloom, and a slow shelf-search beam while a small
## particle layer supplies drifting light motes. Gameplay owns the timer; this scene only mirrors
## active/inactive visual state and never intercepts input.

@export_range(0.05, 1.5, 0.01) var activation_duration_seconds := 0.52
@export_range(0.05, 1.5, 0.01) var fade_duration_seconds := 0.38

@onready var _overlay := %Overlay as Control
@onready var _searchlight_wash := %SearchlightWash as ColorRect
@onready var _motes := %Motes as CPUParticles2D

var _is_active := false
var _intensity := 0.0
var _activation_progress := 1.0
var _elapsed_seconds := 0.0
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


## Keeps the low-count particle field distributed across the live portrait/tablet viewport.
func apply_layout(viewport_size: Vector2) -> void:
	var safe_size := Vector2(maxf(viewport_size.x, 0.0), maxf(viewport_size.y, 0.0))
	_motes.position = safe_size * 0.5
	_motes.emission_rect_extents = safe_size * 0.5


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
	_motes.restart()
	_motes.emitting = true
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
	_motes.emitting = false
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
	_motes.emitting = true
	_set_effect_intensity(1.0)
	_set_activation_progress(1.0)


func _apply_inactive_state() -> void:
	_motes.emitting = false
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
	_motes.modulate = Color(1.0, 1.0, 1.0, _intensity)


func _set_activation_progress(value: float) -> void:
	_activation_progress = clampf(value, 0.0, 1.0)
	if _wash_material != null:
		_wash_material.set_shader_parameter(&"activation_progress", _activation_progress)


func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
