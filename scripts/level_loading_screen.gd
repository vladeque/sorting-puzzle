extends CanvasLayer
class_name LevelLoadingScreen

const CLOSED_HOLE_RADIUS := 0.0
const OPEN_HOLE_RADIUS := 1.0
const COVER_SECONDS := 0.24
const HERO_ENTER_SECONDS := 0.28
const HERO_EXIT_SECONDS := 0.16
const REVEAL_SECONDS := 0.32
const MINIMUM_VISIBLE_SECONDS := 0.95

@onready var _screen_root := %ScreenRoot as Control
@onready var _backdrop := %Backdrop as ColorRect
@onready var _hero_holder := %HeroHolder as Control
@onready var _hero := %Hero as TextureRect
@onready var _hero_shadow := %HeroShadow as TextureRect
@onready var _loading_dots := %LoadingDots as HBoxContainer

var _backdrop_material: ShaderMaterial
var _shown_at_msec := 0
var _dot_phase := 0.0
var _is_animating := false


func _ready() -> void:
	_backdrop_material = _backdrop.material.duplicate() as ShaderMaterial
	_backdrop.material = _backdrop_material
	get_viewport().size_changed.connect(_apply_viewport_size)
	_apply_viewport_size()
	_prepare_hidden_state()


func _process(delta: float) -> void:
	if not _is_animating:
		return
	_dot_phase += delta * 5.2
	var dots := _loading_dots.get_children()
	for index in range(dots.size()):
		var dot := dots[index] as Control
		var pulse := (sin(_dot_phase - float(index) * 0.85) + 1.0) * 0.5
		dot.modulate.a = lerpf(0.35, 1.0, pulse)
		dot.scale = Vector2.ONE * lerpf(0.82, 1.12, pulse)


func _input(_event: InputEvent) -> void:
	if _is_animating:
		get_viewport().set_input_as_handled()


func play_cover() -> void:
	_shown_at_msec = Time.get_ticks_msec()
	_is_animating = true
	_screen_root.show()
	_set_hole_radius(OPEN_HOLE_RADIUS)
	_hero_holder.modulate.a = 0.0
	_hero_holder.scale = Vector2(0.72, 0.72)
	_loading_dots.modulate.a = 0.0

	var cover_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	cover_tween.tween_method(_set_hole_radius, OPEN_HOLE_RADIUS, CLOSED_HOLE_RADIUS, COVER_SECONDS)
	await cover_tween.finished

	var hero_tween := create_tween().set_parallel(true)
	hero_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hero_tween.tween_property(_hero_holder, "scale", Vector2.ONE, HERO_ENTER_SECONDS)
	hero_tween.tween_property(_hero_holder, "modulate:a", 1.0, HERO_ENTER_SECONDS * 0.55)
	hero_tween.tween_property(_loading_dots, "modulate:a", 1.0, HERO_ENTER_SECONDS * 0.8)
	await hero_tween.finished


func play_reveal() -> void:
	var elapsed_seconds := float(Time.get_ticks_msec() - _shown_at_msec) / 1000.0
	var remaining_hold := maxf(MINIMUM_VISIBLE_SECONDS - elapsed_seconds, 0.0)
	if remaining_hold > 0.0:
		await get_tree().create_timer(remaining_hold, true, false, true).timeout

	var exit_tween := create_tween().set_parallel(true)
	exit_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(_hero_holder, "scale", Vector2(0.86, 0.86), HERO_EXIT_SECONDS)
	exit_tween.tween_property(_hero_holder, "modulate:a", 0.0, HERO_EXIT_SECONDS)
	exit_tween.tween_property(_loading_dots, "modulate:a", 0.0, HERO_EXIT_SECONDS * 0.7)
	await exit_tween.finished

	var reveal_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_method(_set_hole_radius, CLOSED_HOLE_RADIUS, OPEN_HOLE_RADIUS, REVEAL_SECONDS)
	await reveal_tween.finished
	_is_animating = false
	_screen_root.hide()


func show_preview() -> void:
	_is_animating = true
	_screen_root.show()
	_set_hole_radius(CLOSED_HOLE_RADIUS)
	_hero_holder.modulate = Color.WHITE
	_hero_holder.scale = Vector2.ONE
	_loading_dots.modulate = Color.WHITE


func _prepare_hidden_state() -> void:
	_set_hole_radius(OPEN_HOLE_RADIUS)
	_hero_holder.modulate.a = 0.0
	_loading_dots.modulate.a = 0.0


func _set_hole_radius(radius: float) -> void:
	_backdrop_material.set_shader_parameter("hole_radius", radius)


func _apply_viewport_size() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_backdrop_material.set_shader_parameter("viewport_size", viewport_size)
	await get_tree().process_frame
	if not is_instance_valid(_hero_holder):
		return
	_hero_holder.pivot_offset = _hero_holder.size * 0.5
	for dot_node in _loading_dots.get_children():
		var dot := dot_node as Control
		dot.pivot_offset = dot.size * 0.5
