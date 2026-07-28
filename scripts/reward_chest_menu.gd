extends Control

@onready var _close_button := %CloseButton as Button
@onready var _continue_button := %ContinueButton as Button
@onready var _progress_bar := %ProgressBar as ProgressBar
@onready var _amount_label := %AmountLabel as Label
@onready var _goal_caption_label := %GoalCaptionLabel as Label
@onready var _next_reward_label := %NextRewardLabel as Label


func _ready() -> void:
	_close_button.pressed.connect(queue_free)
	_continue_button.pressed.connect(queue_free)
	_apply_reward_progress(PlayerProgress.get_reward_chest_progress())


func _apply_reward_progress(progress: Dictionary) -> void:
	var goal := maxi(int(progress.get("goal", 1)), 1)
	var stars := clampi(int(progress.get("stars", 0)), 0, goal)
	var coin_reward := maxi(int(progress.get("coin_reward", 0)), 0)

	_progress_bar.max_value = goal
	_progress_bar.value = stars
	_amount_label.text = "%d/%d" % [stars, goal]
	_goal_caption_label.text = "%d stars to go" % (goal - stars)
	_next_reward_label.text = "Reward: +%d coins" % coin_reward
