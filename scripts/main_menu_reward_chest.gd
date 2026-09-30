extends Control

signal chest_pressed

const DEFAULT_GOAL := 1
const DEFAULT_FONT_SIZE := 18
const MEDIUM_FONT_SIZE := 16
const SMALL_FONT_SIZE := 14
const REFILL_DURATION := 0.45

@onready var _progress_bar := %ProgressBar as ProgressBar
@onready var _amount_label := %AmountLabel as Label
@onready var _chest_button := %ChestButton as Button
@onready var _chest_icon := $Visual/ChestIcon as Control
@onready var _icon_shadow := $Visual/IconShadow as Control

var _receive_pulse_tween: Tween
var _refill_tween: Tween


func _ready() -> void:
	_chest_button.pressed.connect(_on_chest_button_pressed)


func _on_chest_button_pressed() -> void:
	chest_pressed.emit()


func set_reward_progress(current_stars: int, goal_stars: int) -> void:
	if _refill_tween != null and _refill_tween.is_valid():
		_refill_tween.kill()
	_apply_reward_progress(current_stars, goal_stars)


## Empties the bar and counts it up to the next goal's carried-over stars, after the chest-opening
## sequence has taken the filled chest's rewards.
func play_refill(current_stars: int, goal_stars: int) -> void:
	set_reward_progress(0, goal_stars)
	var target := clampi(current_stars, 0, maxi(goal_stars, DEFAULT_GOAL))
	if target <= 0:
		return
	_refill_tween = create_tween()
	_refill_tween.tween_method(
		_apply_refill_value.bind(goal_stars), 0.0, float(target), REFILL_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _apply_refill_value(value: float, goal_stars: int) -> void:
	_apply_reward_progress(roundi(value), goal_stars)


func get_chest_icon_global_rect() -> Rect2:
	return _chest_icon.get_global_rect()


## The chest-opening sequence lifts a large copy of the chest out of this slot, so the small icon
## hides for its duration. The progress bar stays visible.
func set_chest_icon_hidden(is_hidden: bool) -> void:
	_chest_icon.modulate.a = 0.0 if is_hidden else 1.0
	_icon_shadow.modulate.a = 0.0 if is_hidden else 1.0


func _apply_reward_progress(current_stars: int, goal_stars: int) -> void:
	var safe_goal := maxi(goal_stars, DEFAULT_GOAL)
	var safe_current := clampi(current_stars, 0, safe_goal)

	if _progress_bar != null:
		_progress_bar.max_value = safe_goal
		_progress_bar.value = safe_current

	if _amount_label == null:
		return

	var amount_text := "%d/%d" % [safe_current, safe_goal]
	var font_size := DEFAULT_FONT_SIZE
	if amount_text.length() >= 10:
		font_size = SMALL_FONT_SIZE
	elif amount_text.length() >= 8:
		font_size = MEDIUM_FONT_SIZE

	_amount_label.add_theme_font_size_override("font_size", font_size)
	_amount_label.text = amount_text


func get_reward_target_global_position() -> Vector2:
	return _chest_icon.get_global_rect().get_center()


func play_receive_pulse() -> void:
	if _receive_pulse_tween != null and _receive_pulse_tween.is_valid():
		_receive_pulse_tween.kill()

	scale = Vector2.ONE
	pivot_offset = size * 0.5
	_receive_pulse_tween = create_tween()
	_receive_pulse_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_receive_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
