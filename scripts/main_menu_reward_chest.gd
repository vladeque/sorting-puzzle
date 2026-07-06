extends Control

const DEFAULT_GOAL := 1
const DEFAULT_FONT_SIZE := 18
const MEDIUM_FONT_SIZE := 16
const SMALL_FONT_SIZE := 14

@onready var _progress_bar := %ProgressBar as ProgressBar
@onready var _amount_label := %AmountLabel as Label


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
