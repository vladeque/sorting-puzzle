extends Control
class_name LeaderboardRow

const DEFAULT_ROW_HEIGHT := 92.0
const COMPACT_ROW_HEIGHT := 76.0
const DEFAULT_AVATAR_SIZE := 64.0
const COMPACT_AVATAR_SIZE := 54.0

@onready var _current_background := %CurrentBackground as Panel
@onready var _rank_slot := %RankSlot as Control
@onready var _gold_circle := %GoldCircle as Control
@onready var _silver_circle := %SilverCircle as Control
@onready var _bronze_circle := %BronzeCircle as Control
@onready var _rank_label := %RankLabel as Label
@onready var _profile_avatar_view := %ProfileAvatarView as ProfileAvatarView
@onready var _name_label := %NameLabel as Label
@onready var _rank_reward := %RankReward as LeaderboardRankReward
@onready var _score_label := %ScoreLabel as Label

var _entry: Dictionary = {}


func _ready() -> void:
	_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func set_entry(entry: Dictionary) -> void:
	var rank := maxi(int(entry.get("rank", 0)), 0)
	var score := maxi(int(entry.get("score", 0)), 0)
	_entry = entry.duplicate(true)
	var display_name := str(entry.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = tr("leaderboard.default_name")

	_gold_circle.visible = rank == 1
	_silver_circle.visible = rank == 2
	_bronze_circle.visible = rank == 3
	_rank_label.text = str(rank) if rank in [1, 2, 3] else ("#%d" % rank if rank > 0 else "—")
	_name_label.text = display_name
	_score_label.text = _format_number(score)
	_profile_avatar_view.set_profile(
		str(entry.get("avatar_id", "avatar_cat")),
		str(entry.get("avatar_frame_id", "frame_classic"))
	)
	_rank_reward.clear_reward()
	_current_background.visible = bool(entry.get("is_current_player", false))
	tooltip_text = tr_n("leaderboard.row_tooltip", "leaderboard.row_tooltip.plural", score) % [rank, display_name, score]


func set_rank_reward(texture: Texture2D, coin_amount: int) -> void:
	_rank_reward.set_reward(texture, coin_amount)


func clear_rank_reward() -> void:
	_rank_reward.clear_reward()


func set_compact(is_compact: bool) -> void:
	custom_minimum_size.y = COMPACT_ROW_HEIGHT if is_compact else DEFAULT_ROW_HEIGHT
	var avatar_size := COMPACT_AVATAR_SIZE if is_compact else DEFAULT_AVATAR_SIZE
	_profile_avatar_view.custom_minimum_size = Vector2(avatar_size, avatar_size)
	_rank_slot.custom_minimum_size = Vector2(avatar_size, avatar_size)
	_rank_label.add_theme_font_size_override("font_size", 24 if is_compact else 28)
	_name_label.add_theme_font_size_override("font_size", 24 if is_compact else 28)
	_rank_reward.set_compact(is_compact)
	_score_label.add_theme_font_size_override("font_size", 26 if is_compact else 30)


func _format_number(value: int) -> String:
	return GameText.format_number(value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		var score := maxi(int(_entry.get("score", 0)), 0)
		var name_text := str(_entry.get("display_name", "")).strip_edges()
		if name_text.is_empty():
			name_text = tr("leaderboard.default_name")
		_name_label.text = name_text
		_score_label.text = _format_number(score)
		tooltip_text = tr_n("leaderboard.row_tooltip", "leaderboard.row_tooltip.plural", score) % [
			maxi(int(_entry.get("rank", 0)), 0), name_text, score
		]
