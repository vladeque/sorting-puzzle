extends Control
class_name LevelCompletionScreen

## Reusable completed-level reward overlay. The shared shell still owns shade/title/action layout;
## this scene owns the completion-specific star, count, paper-star glints, and their intro motion.

signal next_pressed

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")

const STAR_SIZE := Vector2(340, 340)
const STAR_CENTER_Y := 466.0
const STARS_LABEL_SIZE := Vector2(320, 84)
const STARS_LABEL_OFFSET_Y := 150.0
const INTRO_DURATION := 0.92
const SPARKLE_OFFSETS: Array[Vector2] = [
	Vector2(-154.0, -116.0),
	Vector2(146.0, -92.0),
	Vector2(-176.0, 10.0),
	Vector2(176.0, 18.0),
	Vector2(126.0, 122.0),
]
const SPARKLE_SIZES: Array[float] = [42.0, 30.0, 25.0, 34.0, 22.0]
const SPARKLE_COLORS: Array[Color] = [
	Color(1.0, 0.92, 0.28),
	Color(0.38, 0.88, 1.0),
	Color(1.0, 0.47, 0.72),
	Color(0.55, 0.96, 0.57),
	Color(0.78, 0.58, 1.0),
]

@onready var _shell := %Shell as GameplayResultShell
@onready var _star_image := %StarImage as TextureRect
@onready var _earned_stars_label := %EarnedStarsLabel as Label
@onready var _sparkle_layer := %SparkleLayer as Control
@onready var _next_button := %NextButton as Button

var _sparkles: Array[TextureRect] = []
var _motion_tweens: Array[Tween] = []
var _intro_active := false
var _intro_generation := 0
var _button_rest_position := Vector2.ZERO


func _ready() -> void:
	_shell.configure("GREAT JOB!")
	var content := _shell.get_content_region()
	_star_image.reparent(content, false)
	_earned_stars_label.reparent(content, false)

	_sparkles = [
		%SparkleTopLeft,
		%SparkleTopRight,
		%SparkleMiddleLeft,
		%SparkleMiddleRight,
		%SparkleBottomRight,
	]
	for index in range(_sparkles.size()):
		_sparkles[index].self_modulate = SPARKLE_COLORS[index]

	var action := _shell.get_action_region()
	_next_button.reparent(action, false)
	_next_button.anchor_left = 0.0
	_next_button.anchor_top = 0.0
	_next_button.anchor_right = 1.0
	_next_button.anchor_bottom = 1.0
	_next_button.offset_left = 0.0
	_next_button.offset_top = 0.0
	_next_button.offset_right = 0.0
	_next_button.offset_bottom = 0.0
	_next_button.pressed.connect(_on_next_button_pressed)


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_shell.apply_safe_layout(safe_margins, viewport_size)
	_sparkle_layer.anchor_left = 0.0
	_sparkle_layer.anchor_top = 0.0
	_sparkle_layer.anchor_right = 0.0
	_sparkle_layer.anchor_bottom = 0.0
	_sparkle_layer.offset_left = 0.0
	_sparkle_layer.offset_top = 0.0
	_sparkle_layer.offset_right = viewport_size.x
	_sparkle_layer.offset_bottom = viewport_size.y

	var scale := GameplayUIThemeScript.get_result_title_scale(viewport_size)
	var center_x := viewport_size.x * 0.5
	var star_center := Vector2(center_x, safe_margins.y + STAR_CENTER_Y * scale)
	_layout_centered_control(_star_image, star_center, STAR_SIZE * scale)
	_layout_centered_control(
		_earned_stars_label,
		star_center + Vector2(0.0, STARS_LABEL_OFFSET_Y * scale),
		STARS_LABEL_SIZE * scale
	)
	for index in range(_sparkles.size()):
		var sparkle_size: Vector2 = Vector2.ONE * SPARKLE_SIZES[index] * scale
		_layout_centered_control(
			_sparkles[index],
			star_center + SPARKLE_OFFSETS[index] * scale,
			sparkle_size
		)

	_set_center_pivot(_shell.get_title_label())
	_set_center_pivot(_star_image)
	_set_center_pivot(_earned_stars_label)
	for sparkle: TextureRect in _sparkles:
		_set_center_pivot(sparkle)
	_set_center_pivot(_next_button)
	_button_rest_position = _next_button.position


func set_earned_stars(stars: int) -> void:
	var earned_text := "×%d" % stars
	var font_size := 58
	if earned_text.length() >= 8:
		font_size = 42
	elif earned_text.length() >= 7:
		font_size = 48
	elif earned_text.length() >= 6:
		font_size = 52

	_earned_stars_label.add_theme_font_size_override("font_size", font_size)
	_earned_stars_label.text = earned_text


func set_continue_enabled(is_enabled: bool) -> void:
	_next_button.disabled = not is_enabled
	_next_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if is_enabled else Control.CURSOR_ARROW
	)


func is_transitioning() -> bool:
	return _shell.is_transitioning() or _intro_active


func open() -> void:
	show()
	_intro_generation += 1
	var my_generation := _intro_generation
	_stop_motion_tweens()
	_reset_intro_visuals()
	_shell.open()
	_play_intro(my_generation)


func close() -> void:
	_intro_generation += 1
	_intro_active = false
	_stop_motion_tweens()
	await _shell.close()
	hide()


func _play_intro(generation: int) -> void:
	_intro_active = true
	_start_title_intro()
	_start_star_intro()
	_start_count_intro()
	_start_button_intro()
	_start_sparkle_intro()
	await get_tree().create_timer(INTRO_DURATION).timeout
	if not is_inside_tree() or generation != _intro_generation:
		return
	_intro_active = false
	_next_button.disabled = false
	_start_sparkle_loops()


func _reset_intro_visuals() -> void:
	var title := _shell.get_title_label()
	title.scale = Vector2.ONE * 0.82
	title.modulate.a = 0.0
	_star_image.scale = Vector2.ONE * 0.65
	_star_image.rotation = deg_to_rad(-7.0)
	_star_image.modulate.a = 0.0
	_earned_stars_label.scale = Vector2.ONE * 0.65
	_earned_stars_label.modulate.a = 0.0
	_next_button.disabled = true
	_next_button.modulate.a = 0.0
	_next_button.position = _button_rest_position + Vector2(0.0, 24.0)
	for sparkle: TextureRect in _sparkles:
		sparkle.scale = Vector2.ZERO
		sparkle.modulate.a = 0.0


func _start_title_intro() -> void:
	var title := _shell.get_title_label()
	var tween := _track_tween(create_tween())
	tween.tween_property(title, "scale", Vector2.ONE * 1.06, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(title, "modulate:a", 1.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(title, "scale", Vector2.ONE, 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_star_intro() -> void:
	var tween := _track_tween(create_tween())
	tween.tween_interval(0.1)
	tween.tween_property(_star_image, "scale", Vector2.ONE * 1.12, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_star_image, "rotation", deg_to_rad(3.0), 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_star_image, "modulate:a", 1.0, 0.14)
	tween.tween_property(_star_image, "scale", Vector2.ONE, 0.13) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_star_image, "rotation", 0.0, 0.13) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_count_intro() -> void:
	var tween := _track_tween(create_tween())
	tween.tween_interval(0.48)
	tween.tween_property(_earned_stars_label, "scale", Vector2.ONE * 1.08, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_earned_stars_label, "modulate:a", 1.0, 0.12)
	tween.tween_property(_earned_stars_label, "scale", Vector2.ONE, 0.09)


func _start_button_intro() -> void:
	var tween := _track_tween(create_tween())
	tween.tween_interval(0.66)
	tween.tween_property(_next_button, "position", _button_rest_position, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_next_button, "modulate:a", 1.0, 0.18)


func _start_sparkle_intro() -> void:
	for index in range(_sparkles.size()):
		var sparkle := _sparkles[index]
		var tween := _track_tween(create_tween())
		tween.tween_interval(0.3 + float(index) * 0.055)
		tween.tween_property(sparkle, "scale", Vector2.ONE * 1.08, 0.17) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sparkle, "modulate:a", 1.0, 0.1)
		tween.parallel().tween_property(sparkle, "rotation", deg_to_rad(22.0), 0.22)
		tween.tween_property(sparkle, "scale", Vector2.ONE * 0.72, 0.16)
		tween.parallel().tween_property(sparkle, "modulate:a", 0.58, 0.16)


func _start_sparkle_loops() -> void:
	for index in range(_sparkles.size()):
		var sparkle := _sparkles[index]
		var tween := _track_tween(create_tween().set_loops())
		tween.tween_interval(0.28 + float(index) * 0.13)
		tween.tween_property(sparkle, "scale", Vector2.ONE, 0.36) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(sparkle, "modulate:a", 0.96, 0.3)
		tween.parallel().tween_property(sparkle, "rotation", sparkle.rotation + deg_to_rad(18.0), 0.5)
		tween.tween_property(sparkle, "scale", Vector2.ONE * 0.72, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(sparkle, "modulate:a", 0.48, 0.42)
		tween.tween_interval(0.36)


func _track_tween(tween: Tween) -> Tween:
	_motion_tweens.append(tween)
	return tween


func _stop_motion_tweens() -> void:
	for tween: Tween in _motion_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_motion_tweens.clear()


func _layout_centered_control(control: Control, center: Vector2, size: Vector2) -> void:
	if control == null:
		return
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = center.x - size.x * 0.5
	control.offset_top = center.y - size.y * 0.5
	control.offset_right = center.x + size.x * 0.5
	control.offset_bottom = center.y + size.y * 0.5
	_set_center_pivot(control)


func _set_center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5


func _on_next_button_pressed() -> void:
	if _intro_active:
		return
	_intro_generation += 1
	_stop_motion_tweens()
	next_pressed.emit()
