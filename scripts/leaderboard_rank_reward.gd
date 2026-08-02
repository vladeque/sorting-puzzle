extends PanelContainer
class_name LeaderboardRankReward

const DEFAULT_SIZE := Vector2(90.0, 70.0)
const COMPACT_SIZE := Vector2(78.0, 54.0)
const DEFAULT_IMAGE_SIZE := Vector2(72.0, 58.0)
const COMPACT_IMAGE_SIZE := Vector2(58.0, 43.0)

@onready var _content := $Content as VBoxContainer
@onready var _coin_image := %CoinImage as TextureRect
@onready var _amount_label := %AmountLabel as Label


func set_reward(texture: Texture2D, coin_amount: int) -> void:
	var amount := maxi(coin_amount, 0)
	visible = texture != null and amount > 0
	if not visible:
		_coin_image.texture = null
		_amount_label.text = ""
		tooltip_text = ""
		return

	_coin_image.texture = texture
	_amount_label.text = _format_number(amount)
	tooltip_text = "%s coin weekly reward" % _amount_label.text


func clear_reward() -> void:
	set_reward(null, 0)


func set_compact(is_compact: bool) -> void:
	custom_minimum_size = COMPACT_SIZE if is_compact else DEFAULT_SIZE
	_coin_image.custom_minimum_size = COMPACT_IMAGE_SIZE if is_compact else DEFAULT_IMAGE_SIZE
	_amount_label.custom_minimum_size.y = 16.0 if is_compact else 20.0
	_amount_label.add_theme_font_size_override("font_size", 16 if is_compact else 20)
	_content.add_theme_constant_override("separation", -9 if is_compact else -14)


func _format_number(value: int) -> String:
	var digits := str(maxi(value, 0))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]

	return formatted
