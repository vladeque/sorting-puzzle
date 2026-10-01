extends PanelContainer
class_name ShopBundleCard

signal purchase_pressed(offer_id: StringName)
signal info_requested(ability_id: StringName)

## Keeps the title clear of %DiscountBadge, which overlaps the card's top-left corner.
const DISCOUNT_BADGE_TITLE_INSET := 62.0

@onready var _title_label := %TitleLabel as Label
@onready var _title_spacer := %TitleSpacer as Control
@onready var _discount_badge := %DiscountBadge as Control
@onready var _percent_label := %PercentLabel as Label
@onready var _compare_at_price_label := %CompareAtPriceLabel as RichTextLabel
@onready var _hammer_count := %HammerCount as Label
@onready var _shuffle_count := %ShuffleCount as Label
@onready var _lantern_count := %LanternCount as Label
@onready var _freezer_count := %FreezerCount as Label
@onready var _coin_count := %CoinCount as Label
@onready var _purchase_button := %PurchaseButton as Button
@onready var _reward_icons := {
	"coins": $CardBody/CardStack/Rewards/CoinReward/Stack/Icon as Control,
	"hammer": $CardBody/CardStack/Rewards/HammerReward/Stack/Icon as Control,
	"shuffle": $CardBody/CardStack/Rewards/ShuffleReward/Stack/Icon as Control,
	"highlight": $CardBody/CardStack/Rewards/LanternReward/Stack/Icon as Control,
	"freezer": $CardBody/CardStack/Rewards/FreezerReward/Stack/Icon as Control,
}
@onready var _ability_info_buttons := {
	&"hammer": %HammerInfoButton as Button,
	&"shuffle": %ShuffleInfoButton as Button,
	&"highlight": %LanternInfoButton as Button,
	&"freezer": %FreezerInfoButton as Button,
}

var _offer_id := &""
var _formatted_price := ""


func _ready() -> void:
	_purchase_button.pressed.connect(_emit_purchase)
	for ability_id in _ability_info_buttons:
		var button := _ability_info_buttons[ability_id] as Button
		if button != null:
			button.pressed.connect(info_requested.emit.bind(ability_id))


func set_offer(offer: Dictionary) -> void:
	_offer_id = StringName(str(offer.get("id", "")))
	_title_label.text = str(offer.get("title", "Bundle")).to_upper()
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

	var discount_percent := maxi(int(offer.get("discount_percent", 0)), 0)
	_discount_badge.visible = discount_percent > 0
	_title_spacer.custom_minimum_size.x = DISCOUNT_BADGE_TITLE_INSET if discount_percent > 0 else 0.0
	if discount_percent > 0:
		_percent_label.text = "%d%%" % discount_percent

	var compare_at_price := str(store.get("compare_at_formatted_price", ""))
	_compare_at_price_label.visible = not compare_at_price.is_empty()
	if not compare_at_price.is_empty():
		_compare_at_price_label.text = "[center][s]%s[/s][/center]" % compare_at_price


func get_offer_id() -> StringName:
	return _offer_id


## Where each reward's art sits on the card, keyed "coins" or by ability id, so the purchase reward
## sequence can lift the bought rewards straight off it.
func get_reward_icon_global_rects() -> Dictionary:
	var rects := {}
	for key in _reward_icons.keys():
		var icon := _reward_icons[key] as Control
		if icon.is_visible_in_tree():
			rects[key] = icon.get_global_rect()
	return rects


func set_shop_locked(is_locked: bool, is_active_purchase: bool = false) -> void:
	_purchase_button.disabled = is_locked
	_purchase_button.text = "Purchasing…" if is_locked and is_active_purchase else _formatted_price
	modulate = Color(1, 1, 1, 0.78) if is_locked and not is_active_purchase else Color.WHITE


func set_compact(is_compact: bool) -> void:
	custom_minimum_size.y = 246.0 if is_compact else 286.0


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
