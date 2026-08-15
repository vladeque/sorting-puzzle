class_name FreezerScreenEffect
extends CanvasLayer

## Full-screen visual treatment for the Freezer ability. The main frame sits between gameplay and
## UI, while a second copy clips to the responsive top-HUD strip and renders above it. The
## transparent texture never recolors the chapter background or intercepts input. Repeated state
## updates are intentionally idempotent because Level refreshes Freezer UI every active frame.

@export_range(0.05, 1.5, 0.01) var activation_duration_seconds := 0.42
@export_range(0.05, 1.5, 0.01) var thaw_duration_seconds := 0.46

@onready var _overlay := %Overlay as Control
@onready var _ice_frame := %IceFrame as TextureRect
@onready var _hud_overlay_layer := %HudOverlayLayer as CanvasLayer
@onready var _hud_clip := %HudClip as Control
@onready var _hud_ice_frame := %HudIceFrame as TextureRect

var _is_active := false
var _reveal_amount := 0.0
var _opacity := 0.0
var _transition_tween: Tween
var _ice_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ice_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ice_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_duplicate_and_register_material(_ice_frame)
	_duplicate_and_register_material(_hud_ice_frame)
	apply_layout(get_viewport().get_visible_rect().size, 112.0)
	_apply_inactive_state()


## Keeps the upper copy at full-viewport texture scale, then clips it to exactly the live TopHud
## height. This avoids vertically squeezing the ice artwork into the short HUD strip.
func apply_layout(viewport_size: Vector2, top_hud_height: float) -> void:
	_hud_clip.anchor_left = 0.0
	_hud_clip.anchor_top = 0.0
	_hud_clip.anchor_right = 1.0
	_hud_clip.anchor_bottom = 0.0
	_hud_clip.offset_left = 0.0
	_hud_clip.offset_top = 0.0
	_hud_clip.offset_right = 0.0
	_hud_clip.offset_bottom = maxf(top_hud_height, 0.0)

	_hud_ice_frame.anchor_left = 0.0
	_hud_ice_frame.anchor_top = 0.0
	_hud_ice_frame.anchor_right = 0.0
	_hud_ice_frame.anchor_bottom = 0.0
	_hud_ice_frame.offset_left = 0.0
	_hud_ice_frame.offset_top = 0.0
	_hud_ice_frame.offset_right = maxf(viewport_size.x, 0.0)
	_hud_ice_frame.offset_bottom = maxf(viewport_size.y, 0.0)


func get_hud_overlay_height() -> float:
	return _hud_clip.size.y


## Starts the edge-in freeze or thaw transition only when the logical state changes. `immediate` is
## used by level rebuild/teardown paths so an old run can never leave frost over a fresh board.
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
		_play_freeze_transition(immediate)
	else:
		_play_thaw_transition(immediate)


func is_active() -> bool:
	return _is_active


func get_reveal_amount() -> float:
	return _reveal_amount


func get_effect_opacity() -> float:
	return _opacity


func _play_freeze_transition(immediate: bool) -> void:
	_set_effect_visible(true)
	if immediate:
		_apply_active_state()
		return

	_set_reveal_amount(0.0)
	_set_effect_opacity(0.0)
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_method(
		_set_reveal_amount,
		0.0,
		1.0,
		activation_duration_seconds
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_method(
		_set_effect_opacity,
		0.0,
		1.0,
		activation_duration_seconds * 0.72
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_thaw_transition(immediate: bool) -> void:
	if immediate or not visible:
		_apply_inactive_state()
		return

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_method(
		_set_reveal_amount,
		_reveal_amount,
		0.0,
		thaw_duration_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.tween_method(
		_set_effect_opacity,
		_opacity,
		0.0,
		thaw_duration_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.finished.connect(_on_thaw_finished)


func _on_thaw_finished() -> void:
	if not _is_active:
		_apply_inactive_state()


func _apply_active_state() -> void:
	_set_effect_visible(true)
	_set_reveal_amount(1.0)
	_set_effect_opacity(1.0)


func _apply_inactive_state() -> void:
	_set_effect_visible(false)
	_set_reveal_amount(0.0)
	_set_effect_opacity(0.0)


func _set_reveal_amount(value: float) -> void:
	_reveal_amount = clampf(value, 0.0, 1.0)
	for material in _ice_materials:
		material.set_shader_parameter(&"reveal_amount", _reveal_amount)


func _set_effect_opacity(value: float) -> void:
	_opacity = clampf(value, 0.0, 1.0)
	for material in _ice_materials:
		material.set_shader_parameter(&"opacity", _opacity)


func _duplicate_and_register_material(frame: TextureRect) -> void:
	var material := frame.material as ShaderMaterial
	if material == null:
		return
	material = material.duplicate() as ShaderMaterial
	frame.material = material
	_ice_materials.append(material)


func _set_effect_visible(should_be_visible: bool) -> void:
	visible = should_be_visible
	_hud_overlay_layer.visible = should_be_visible


func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
