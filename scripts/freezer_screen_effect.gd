class_name FreezerScreenEffect
extends CanvasLayer

## Full-screen visual treatment for the Freezer ability. A wide perimeter glow and small inward-
## moving snowflakes sit between gameplay and UI, while synchronized copies clip to the responsive
## top-HUD strip and render above it. Repeated state updates are intentionally idempotent because
## Level refreshes Freezer UI every active frame.

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const FreezerSnowflakeFieldScript := preload("res://scripts/freezer_snowflake_field.gd")
const GAMEPLAY_MODAL_SHADE_STYLE := preload(
	"res://assets/themes/style_box_gameplay_modal_shade.tres"
)

@export_range(0.05, 1.5, 0.01) var activation_duration_seconds := 0.42
@export_range(0.05, 1.5, 0.01) var thaw_duration_seconds := 0.46

@onready var _overlay := %Overlay as Control
@onready var _edge_glow := %EdgeGlow as ColorRect
@onready var _snowflake_field := %SnowflakeField as FreezerSnowflakeFieldScript
@onready var _hud_overlay_layer := %HudOverlayLayer as CanvasLayer
@onready var _hud_clip := %HudClip as Control
@onready var _hud_edge_glow := %HudEdgeGlow as ColorRect
@onready var _hud_snowflake_field := %HudSnowflakeField as FreezerSnowflakeFieldScript

var _is_active := false
var _activation_amount := 0.0
var _opacity := 0.0
var _transition_tween: Tween
var _modal_dim_tween: Tween
var _glow_materials: Array[ShaderMaterial] = []
var _hud_glow_material: ShaderMaterial
var _is_modal_dimmed := false
var _modal_shade_amount := 0.0


func _ready() -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snowflake_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_edge_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_snowflake_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_duplicate_and_register_material(_edge_glow)
	_hud_glow_material = _duplicate_and_register_material(_hud_edge_glow)
	if _hud_glow_material != null:
		_hud_glow_material.set_shader_parameter(
			&"modal_shade_color",
			GAMEPLAY_MODAL_SHADE_STYLE.bg_color
		)
	_snowflake_field.set_modal_shade(GAMEPLAY_MODAL_SHADE_STYLE.bg_color, 0.0)
	apply_layout(get_viewport().get_visible_rect().size, 112.0)
	_set_modal_shade_amount(0.0)
	_apply_inactive_state()


## Keeps the upper render pass at full-viewport scale, then clips it to exactly the live TopHud
## height. The glow and snowflakes therefore cross the HUD boundary without being squeezed.
func apply_layout(viewport_size: Vector2, top_hud_height: float) -> void:
	_hud_clip.anchor_left = 0.0
	_hud_clip.anchor_top = 0.0
	_hud_clip.anchor_right = 1.0
	_hud_clip.anchor_bottom = 0.0
	_hud_clip.offset_left = 0.0
	_hud_clip.offset_top = 0.0
	_hud_clip.offset_right = 0.0
	_hud_clip.offset_bottom = maxf(top_hud_height, 0.0)

	_apply_full_viewport_rect(_hud_edge_glow, viewport_size)
	_apply_full_viewport_rect(_hud_snowflake_field, viewport_size)


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


func get_activation_amount() -> float:
	return _activation_amount


func get_effect_opacity() -> float:
	return _opacity


## Mirrors the gameplay modal shade into the layer-11 TopHud copy. The main pass already receives
## the real layer-10 shade; matching its fade keeps the upper glow and flakes equally dimmed.
func set_modal_dimmed(should_be_dimmed: bool, immediate := false) -> void:
	if should_be_dimmed == _is_modal_dimmed:
		if immediate:
			_kill_modal_dim_transition()
			_set_modal_shade_amount(1.0 if should_be_dimmed else 0.0)
		return

	_is_modal_dimmed = should_be_dimmed
	_kill_modal_dim_transition()
	var target_amount := 1.0 if should_be_dimmed else 0.0
	if immediate or not visible:
		_set_modal_shade_amount(target_amount)
		return

	_modal_dim_tween = create_tween()
	_modal_dim_tween.tween_method(
		_set_modal_shade_amount,
		_modal_shade_amount,
		target_amount,
		UIMotionScript.OVERLAY_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT if should_be_dimmed else Tween.EASE_IN
	)


func get_modal_shade_amount() -> float:
	return _modal_shade_amount


func _play_freeze_transition(immediate: bool) -> void:
	_set_effect_visible(true)
	_snowflake_field.set_emitting(true)
	if immediate:
		_apply_active_state()
		return

	_set_activation_amount(0.0)
	_set_effect_opacity(0.0)
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_method(
		_set_activation_amount,
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
	_snowflake_field.set_emitting(false, immediate)
	if immediate or not visible:
		_apply_inactive_state()
		return

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_method(
		_set_activation_amount,
		_activation_amount,
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
	_snowflake_field.set_emitting(true)
	_set_activation_amount(1.0)
	_set_effect_opacity(1.0)


func _apply_inactive_state() -> void:
	_snowflake_field.set_emitting(false, true)
	_set_effect_visible(false)
	_set_activation_amount(0.0)
	_set_effect_opacity(0.0)


func _set_activation_amount(value: float) -> void:
	_activation_amount = clampf(value, 0.0, 1.0)
	for material in _glow_materials:
		material.set_shader_parameter(&"activation_amount", _activation_amount)


func _set_effect_opacity(value: float) -> void:
	_opacity = clampf(value, 0.0, 1.0)
	for material in _glow_materials:
		material.set_shader_parameter(&"opacity", _opacity)
	_snowflake_field.set_effect_opacity(_opacity)


func _set_modal_shade_amount(value: float) -> void:
	_modal_shade_amount = clampf(value, 0.0, 1.0)
	if _hud_glow_material != null:
		_hud_glow_material.set_shader_parameter(&"modal_shade_amount", _modal_shade_amount)
	_snowflake_field.set_modal_shade(
		GAMEPLAY_MODAL_SHADE_STYLE.bg_color,
		_modal_shade_amount
	)


func _duplicate_and_register_material(frame: ColorRect) -> ShaderMaterial:
	var material := frame.material as ShaderMaterial
	if material == null:
		return null
	material = material.duplicate() as ShaderMaterial
	frame.material = material
	_glow_materials.append(material)
	return material


func _apply_full_viewport_rect(control: Control, viewport_size: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = maxf(viewport_size.x, 0.0)
	control.offset_bottom = maxf(viewport_size.y, 0.0)


func _set_effect_visible(should_be_visible: bool) -> void:
	visible = should_be_visible
	_hud_overlay_layer.visible = should_be_visible


func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


func _kill_modal_dim_transition() -> void:
	if _modal_dim_tween != null and _modal_dim_tween.is_valid():
		_modal_dim_tween.kill()
	_modal_dim_tween = null
