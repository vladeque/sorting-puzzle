extends Control
class_name StarterBundleOfferModal

signal buy_requested
signal close_requested

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const MODAL_HEIGHT := 640.0
const CONTENT_HEIGHT := 404.0

@onready var _shell := %Shell as GameplayModalShell
@onready var _offer_content := %OfferContent as VBoxContainer
@onready var _coin_reward := %CoinReward as PanelContainer
@onready var _coin_count := %CoinCount as Label
@onready var _hammer_reward := %HammerReward as PanelContainer
@onready var _hammer_count := %HammerCount as Label
@onready var _shuffle_reward := %ShuffleReward as PanelContainer
@onready var _shuffle_count := %ShuffleCount as Label
@onready var _lantern_reward := %LanternReward as PanelContainer
@onready var _lantern_count := %LanternCount as Label
@onready var _freezer_reward := %FreezerReward as PanelContainer
@onready var _freezer_count := %FreezerCount as Label
@onready var _discount_label := %DiscountLabel as Label
@onready var _compare_at_price_label := %CompareAtPriceLabel as RichTextLabel
@onready var _status_label := %StatusLabel as Label
@onready var _buy_button := %BuyButton as Button
@onready var _continue_button := %ContinueButton as Button
@onready var _close_button := %Shell.get_node("OuterPanel/CloseButton") as Button

var _price_text := ""
var _is_busy := false


func _ready() -> void:
	_shell.configure("STARTER BUNDLE", true)
	_shell.set_preferred_size(Vector2(GameplayUIThemeScript.MODAL_MAX_WIDTH, MODAL_HEIGHT))
	_shell.set_content_region_height(CONTENT_HEIGHT)
	_offer_content.reparent(_shell.get_content_region(), false)
	_buy_button.reparent(_shell.get_action_row(), false)
	_continue_button.reparent(_shell.get_action_row(), false)
	_shell.close_requested.connect(request_close)
	_buy_button.pressed.connect(buy_requested.emit)
	_continue_button.pressed.connect(request_close)


func set_offer(offer: Dictionary) -> void:
	var rewards := offer.get("rewards", {}) as Dictionary
	var abilities := rewards.get("abilities", {}) as Dictionary
	var coins := maxi(int(rewards.get("coins", 0)), 0)
	_coin_reward.visible = coins > 0
	_coin_count.text = "%s COINS" % _format_count(coins)
	_bind_ability(_hammer_reward, _hammer_count, "Hammer", int(abilities.get("hammer", 0)))
	_bind_ability(_shuffle_reward, _shuffle_count, "Shuffle", int(abilities.get("shuffle", 0)))
	_bind_ability(_lantern_reward, _lantern_count, "Lantern", int(abilities.get("highlight", 0)))
	_bind_ability(_freezer_reward, _freezer_count, "Freezer", int(abilities.get("freezer", 0)))

	var store := offer.get("store", {}) as Dictionary
	_price_text = str(store.get("formatted_price", ""))
	_buy_button.text = "Buy for %s" % _price_text
	var discount := maxi(int(offer.get("discount_percent", 0)), 0)
	_discount_label.visible = discount > 0
	_discount_label.text = "%d%% OFF" % discount
	var compare_at := str(store.get("compare_at_formatted_price", ""))
	_compare_at_price_label.visible = not compare_at.is_empty()
	_compare_at_price_label.text = "[s]%s[/s]" % compare_at.replace("[", "[lb]")
	_status_label.text = ""
	_buy_button.visible = true
	_buy_button.disabled = false
	_continue_button.visible = false
	_close_button.disabled = false
	_is_busy = false


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_shell.apply_safe_layout(safe_margins, viewport_size)


func open() -> void:
	show()
	_shell.open(true)


func request_close() -> void:
	if _is_busy or _shell.is_transitioning():
		return
	close_requested.emit()


func close() -> void:
	if _is_busy or not visible:
		return
	await _shell.close()
	if not _shell.visible:
		hide()


func is_busy() -> bool:
	return _is_busy


func set_busy(status: String = "Checking offer…") -> void:
	_is_busy = true
	_close_button.disabled = true
	_buy_button.disabled = true
	_buy_button.text = "Purchasing…" if status == "Purchasing…" else "Checking…"
	_status_label.text = status


func show_error(message: String, can_retry: bool) -> void:
	_is_busy = false
	_close_button.disabled = false
	_buy_button.disabled = not can_retry
	_buy_button.text = "Try Again" if can_retry else "Unavailable"
	_status_label.text = message


func show_success() -> void:
	_is_busy = false
	_close_button.disabled = false
	_status_label.text = "Purchase complete. Rewards added!"
	_buy_button.visible = false
	_continue_button.visible = true


func _bind_ability(cell: PanelContainer, count_label: Label, title: String, count: int) -> void:
	cell.visible = count > 0
	count_label.text = "×%d %s" % [maxi(count, 0), title]


func _format_count(value: int) -> String:
	var value_text := str(value)
	var formatted := ""
	while value_text.length() > 3:
		formatted = ",%s%s" % [value_text.right(3), formatted]
		value_text = value_text.substr(0, value_text.length() - 3)
	return value_text + formatted
