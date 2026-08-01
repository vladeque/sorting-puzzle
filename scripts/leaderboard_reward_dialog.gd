extends Control
class_name LeaderboardRewardDialog

@onready var _title_label := %TitleLabel as Label
@onready var _message_label := %MessageLabel as Label
@onready var _close_button := %CloseButton as Button


func _ready() -> void:
	_close_button.pressed.connect(hide)


func show_reward(rank: int, coin_reward: int) -> void:
	_title_label.text = "WEEKLY REWARD!"
	_message_label.text = "You finished #%d last week and earned %d coins!" % [rank, coin_reward]
	show()
