extends PanelContainer
class_name ShopBundleCard

signal purchase_pressed(offer_id: StringName)

@onready var _title_label := %TitleLabel as Label
@onready var _hammer_count := %HammerCount as Label
@onready var _shuffle_count := %ShuffleCount as Label
@onready var _lantern_count := %LanternCount as Label
@onready var _freezer_count := %FreezerCount as Label
@onready var _coin_count := %CoinCount as Label
@onready var _purchase_button := %PurchaseButton as Button

var _offer_id := &""
var _formatted_price := ""


func _ready() -> void:
	_purchase_button.pressed.connect(_emit_purchase)


func set_offer(offer: Dictionary) -> void:
	_offer_id = StringName(str(offer.get("id", "")))
	_title_label.text = str(offer.get("title", "Bundle"))
	var rewards := offer.get("rewards", {}) as Dictionary
	var abilities := rewards.get("abilities", {}) as Dictionary
	_hammer_count.text = "×%d" % maxi(int(abilities.get("hammer", 0)), 0)
	_shuffle_count.text = "×%d" % maxi(int(abilities.get("shuffle", 0)), 0)
	_lantern_count.text = "×%d" % maxi(int(abilities.get("highlight", 0)), 0)
	_freezer_count.text = "×%d" % maxi(int(abilities.get("freezer", 0)), 0)
	_coin_count.text = _format_count(maxi(int(rewards.get("coins", 0)), 0))
	var store := offer.get("store", {}) as Dictionary
	_formatted_price = str(store.get("formatted_price", "Unavailable"))
	_purchase_button.text = _formatted_price


func get_offer_id() -> StringName:
	return _offer_id


func set_shop_locked(is_locked: bool, is_active_purchase: bool = false) -> void:
	_purchase_button.disabled = is_locked
	_purchase_button.text = "Purchasing..." if is_locked and is_active_purchase else _formatted_price
	modulate = Color(1, 1, 1, 0.78) if is_locked and not is_active_purchase else Color.WHITE


func set_compact(is_compact: bool) -> void:
	custom_minimum_size.y = 216.0 if is_compact else 246.0


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
