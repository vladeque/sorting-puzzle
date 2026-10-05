extends Control
class_name LeaderboardRewardDialog

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const ModalAwningHeaderScript := preload("res://scripts/modal_awning_header.gd")

@onready var _header := %AwningHeader as ModalAwningHeaderScript
@onready var _message_label := %MessageLabel as Label
@onready var _close_button := %CloseButton as Button


func _ready() -> void:
	_close_button.pressed.connect(close)


var _rank := 0
var _coin_reward := 0


func show_reward(rank: int, coin_reward: int) -> void:
	_rank = rank
	_coin_reward = coin_reward
	_refresh_message()
	UIMotionScript.fade_in(self)


func _refresh_message() -> void:
	_header.set_title("WEEKLY REWARD!")
	_message_label.text = tr_n("leaderboard.reward.body", "leaderboard.reward.body.plural", _coin_reward) % [_rank, _coin_reward]
	var rank_token := "#%d" % _rank
	_message_label.text = _message_label.text.replace(rank_token, GameText.isolate_ltr(rank_token))


## Fades out and hides this dialog. Safe to call more than once (Close pressed, or the owning
## menu's `ui_cancel` handling) while already closing -- a repeat call is ignored.
func close() -> void:
	UIMotionScript.close_with_fade(self, hide)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_message()
