extends PanelContainer
class_name ShopCoinOfferRow

signal purchase_pressed(offer_id: StringName)

@onready var _tag_banner := %TagBanner as Control
@onready var _tag_label := %TagLabel as Label
@onready var _amount_label := %AmountLabel as Label
@onready var _purchase_button := %PurchaseButton as Button

var _offer_id := &""
var _formatted_price := ""


func _ready() -> void:
	_purchase_button.pressed.connect(_emit_purchase)


func set_offer(offer: Dictionary) -> void:
	_offer_id = StringName(str(offer.get("id", "")))
	var rewards := offer.get("rewards", {}) as Dictionary
	_amount_label.text = _format_count(maxi(int(rewards.get("coins", 0)), 0))
	var store := offer.get("store", {}) as Dictionary
	_formatted_price = str(store.get("formatted_price", "Unavailable"))
	_purchase_button.text = _formatted_price

	var tag := str(offer.get("tag", ""))
	_tag_banner.visible = not tag.is_empty()
	if not tag.is_empty():
		_tag_label.text = tag


func get_offer_id() -> StringName:
	return _offer_id


func set_shop_locked(is_locked: bool, is_active_purchase: bool = false) -> void:
	_purchase_button.disabled = is_locked
	_purchase_button.text = "Purchasing..." if is_locked and is_active_purchase else _formatted_price
	modulate = Color(1, 1, 1, 0.78) if is_locked and not is_active_purchase else Color.WHITE


func set_compact(is_compact: bool) -> void:
	custom_minimum_size.y = 92.0 if is_compact else 108.0


func _emit_purchase() -> void:
	if not _offer_id.is_empty():
		purchase_pressed.emit(_offer_id)


func _format_count(value: int) -> String:
	var value_text := str(value)
	var formatted := ""
	while value_text.length() > 3:
		formatted = ",%s%s" % [value_text.right(3), formatted]
		value_text = value_text.substr(0, value_text.length() - 3)
	return value_text + formatted
