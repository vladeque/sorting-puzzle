extends PanelContainer
class_name ShopCoinOfferRow

signal purchase_pressed(offer_id: StringName)

const COIN_ICON_MAX_AMOUNTS := [100, 300, 750, 1600, 3500, 13000]
const COIN_ICON_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/shop_coin_offers/shop_coin_offer_tier_01.png"),
	preload("res://assets/ui/shop_coin_offers/shop_coin_offer_tier_02.png"),
	preload("res://assets/ui/shop_coin_offers/shop_coin_offer_tier_03.png"),
	preload("res://assets/ui/shop_coin_offers/shop_coin_offer_tier_04.png"),
	preload("res://assets/ui/shop_coin_offers/shop_coin_offer_tier_05.png"),
	preload("res://assets/ui/shop_coin_offers/shop_coin_offer_tier_06.png"),
	preload("res://assets/ui/shop_coin_offers/shop_coin_offer_tier_07.png"),
]

@onready var _tag_banner := %TagBanner as Control
@onready var _tag_label := %TagLabel as Label
@onready var _coin_icon := %CoinIcon as TextureRect
@onready var _amount_label := %AmountLabel as Label
@onready var _purchase_button := %PurchaseButton as Button

var _offer_id := &""
var _coin_amount := 0
var _formatted_price := ""


func _ready() -> void:
	_purchase_button.pressed.connect(_emit_purchase)


func set_offer(offer: Dictionary) -> void:
	_offer_id = StringName(str(offer.get("id", "")))
	var rewards := offer.get("rewards", {}) as Dictionary
	var coin_amount := maxi(int(rewards.get("coins", 0)), 0)
	_coin_amount = coin_amount
	_coin_icon.texture = _get_coin_icon_texture(coin_amount)
	_amount_label.text = _format_count(coin_amount)
	var store := offer.get("store", {}) as Dictionary
	_formatted_price = str(store.get("formatted_price", "Unavailable"))
	_purchase_button.text = _formatted_price

	var tag := str(offer.get("tag", ""))
	_tag_banner.visible = not tag.is_empty()
	if not tag.is_empty():
		_tag_label.text = tag


func get_offer_id() -> StringName:
	return _offer_id


## Where the coin art sits on the row, so the purchase reward sequence can lift the coins off it.
func get_reward_icon_global_rects() -> Dictionary:
	return {"coins": _coin_icon.get_global_rect()}


func set_shop_locked(is_locked: bool, is_active_purchase: bool = false) -> void:
	_purchase_button.disabled = is_locked
	_purchase_button.text = "Purchasing…" if is_locked and is_active_purchase else _formatted_price
	modulate = Color(1, 1, 1, 0.78) if is_locked and not is_active_purchase else Color.WHITE


func set_compact(is_compact: bool) -> void:
	custom_minimum_size.y = 92.0 if is_compact else 108.0


func _emit_purchase() -> void:
	if not _offer_id.is_empty():
		purchase_pressed.emit(_offer_id)


func _get_coin_icon_texture(coin_amount: int) -> Texture2D:
	for index in COIN_ICON_MAX_AMOUNTS.size():
		if coin_amount <= COIN_ICON_MAX_AMOUNTS[index]:
			return COIN_ICON_TEXTURES[index]
	return COIN_ICON_TEXTURES[-1]


func _format_count(value: int) -> String:
	return GameText.format_number(value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_amount_label.text = _format_count(_coin_amount)
