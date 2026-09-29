extends Control
class_name LeaderboardRewardDialog

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const ModalAwningHeaderScript := preload("res://scripts/modal_awning_header.gd")

@onready var _header := %AwningHeader as ModalAwningHeaderScript
@onready var _message_label := %MessageLabel as Label
@onready var _close_button := %CloseButton as Button


func _ready() -> void:
	_close_button.pressed.connect(close)


func show_reward(rank: int, coin_reward: int) -> void:
	_header.set_title("WEEKLY REWARD!")
	_message_label.text = "You finished #%d last week and earned %d coins!" % [rank, coin_reward]
	UIMotionScript.fade_in(self)


## Fades out and hides this dialog. Safe to call more than once (Close pressed, or the owning
## menu's `ui_cancel` handling) while already closing -- a repeat call is ignored.
func close() -> void:
	UIMotionScript.close_with_fade(self, hide)
