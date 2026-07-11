extends Control

const DEFAULT_GOAL := 1
const DEFAULT_FONT_SIZE := 18
const MEDIUM_FONT_SIZE := 16
const SMALL_FONT_SIZE := 14

@onready var _progress_bar := %ProgressBar as ProgressBar
@onready var _amount_label := %AmountLabel as Label

var _receive_pulse_tween: Tween


func set_reward_progress(current_stars: int, goal_stars: int) -> void:
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


func get_coin_target_global_position() -> Vector2:
	var chest_icon := get_node_or_null("ChestIcon") as Control
	if chest_icon == null:
		return get_global_rect().get_center()

	return chest_icon.get_global_rect().get_center()


func play_receive_pulse() -> void:
	if _receive_pulse_tween != null and _receive_pulse_tween.is_valid():
		_receive_pulse_tween.kill()

	scale = Vector2.ONE
	pivot_offset = size * 0.5
	_receive_pulse_tween = create_tween()
	_receive_pulse_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_receive_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
