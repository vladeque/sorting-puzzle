extends Control
class_name CoinBalanceWidget

@onready var _amount_label := %AmountLabel as Label

var _amount := 0


func _ready() -> void:
	_update_label()


func set_amount(amount: int) -> void:
	_amount = maxi(amount, 0)
	if is_node_ready():
		_update_label()


func _update_label() -> void:
	var amount_text := _format_amount(_amount)
	_amount_label.text = amount_text
	_amount_label.add_theme_font_size_override("font_size", _get_font_size(amount_text.length()))


func _get_font_size(character_count: int) -> int:
	if character_count <= 5:
		return 25
	if character_count <= 7:
		return 21
	return 18


func _format_amount(amount: int) -> String:
	var amount_text := str(maxi(amount, 0))
	var formatted := ""
	while amount_text.length() > 3:
		formatted = ",%s%s" % [amount_text.right(3), formatted]
		amount_text = amount_text.substr(0, amount_text.length() - 3)
	return amount_text + formatted
