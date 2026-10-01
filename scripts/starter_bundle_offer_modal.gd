extends Control
class_name StarterBundleOfferModal

## Main Menu Starter Bundle offer in the "shop window" layout: a sunburst hero stage with the coin
## pile, a ribbon carrying the coin amount, a pinned discount tag and a one-time-offer badge, then
## the positive-count boosters as ability-bar sockets, and a Buy button whose top line shows the
## crossed-out compare price. Every amount and price comes from the loaded offer.
##
## Also owns the checking/purchasing and failure presentation: the status pill that sits on the
## content region's bottom edge and the button states. It never grants rewards; the Main Menu runs
## the purchase and, on success, closes the modal and plays scenes/ui/purchase_reward_sequence.tscn
## with the rewards lifting off this modal's coin art and booster chips.

signal buy_requested
signal close_requested

enum StatusTone { BUSY, ERROR }

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const MODAL_HEIGHT := 734.0
const CONTENT_HEIGHT := 484.0
const BUSY_BUTTON_TINT := Color(0.78, 0.8, 0.78, 1.0)
## Opaque, so the Main Menu badge under the rail's end never shows through the dimmed close button.
const DISABLED_CLOSE_TINT := Color(0.66, 0.62, 0.62, 1.0)
const STATUS_TEXT_COLORS := {
	StatusTone.BUSY: Color(0.42, 0.29, 0.188, 1.0),
	StatusTone.ERROR: Color(0.557, 0.106, 0.071, 1.0),
}

@export var status_busy_style: StyleBox
@export var status_error_style: StyleBox

@onready var _shell := %Shell as GameplayModalShell
@onready var _offer_content := %OfferContent as VBoxContainer
@onready var _coin_art := %CoinArt as TextureRect
@onready var _coin_ribbon := %CoinRibbon as OfferRibbonBanner
@onready var _one_time_badge := %OneTimeBadge as Control
@onready var _discount_badge := %DiscountBadge as Control
@onready var _percent_label := %PercentLabel as Label
@onready var _ability_header := %AbilityHeader as Control
@onready var _ability_row := %AbilityRow as Control
@onready var _hammer_reward := %HammerReward as OfferBoosterChip
@onready var _shuffle_reward := %ShuffleReward as OfferBoosterChip
@onready var _lantern_reward := %LanternReward as OfferBoosterChip
@onready var _freezer_reward := %FreezerReward as OfferBoosterChip
@onready var _status_pill := %StatusPill as PanelContainer
@onready var _status_label := %StatusLabel as Label
@onready var _buy_button := %BuyButton as Button
@onready var _compare_at_price_label := %CompareAtPriceLabel as Label
@onready var _buy_price_label := %BuyPriceLabel as Label
@onready var _close_button := %Shell.get_node("OuterPanel/CloseButton") as Button

var _price_text := ""
var _compare_at_text := ""
var _is_busy := false


func _ready() -> void:
	_shell.configure("STARTER BUNDLE", true)
	_shell.set_preferred_size(Vector2(GameplayUIThemeScript.MODAL_MAX_WIDTH, MODAL_HEIGHT))
	_shell.set_content_region_height(CONTENT_HEIGHT)
	_offer_content.reparent(_shell.get_content_region(), false)
	# The pill is anchored to the content region's bottom edge and straddles it, just above Buy.
	_status_pill.reparent(_shell.get_content_region(), false)
	_buy_button.reparent(_shell.get_action_row(), false)
	_shell.close_requested.connect(request_close)
	_buy_button.pressed.connect(buy_requested.emit)
	_set_status("")


func set_offer(offer: Dictionary) -> void:
	var rewards := offer.get("rewards", {}) as Dictionary
	var abilities := rewards.get("abilities", {}) as Dictionary
	var coins := maxi(int(rewards.get("coins", 0)), 0)
	_coin_art.visible = coins > 0
	_coin_ribbon.visible = coins > 0
	_coin_ribbon.set_text("%s COINS" % _format_count(coins))
	_hammer_reward.set_count(int(abilities.get("hammer", 0)))
	_shuffle_reward.set_count(int(abilities.get("shuffle", 0)))
	_lantern_reward.set_count(int(abilities.get("highlight", 0)))
	_freezer_reward.set_count(int(abilities.get("freezer", 0)))
	var has_boosters := false
	for chip in _booster_chips():
		has_boosters = has_boosters or chip.visible
	_ability_header.visible = has_boosters
	_ability_row.visible = has_boosters
	# The Starter Bundle is a lifetime one-time purchase in both catalog modes.
	_one_time_badge.visible = true

	var store := offer.get("store", {}) as Dictionary
	_price_text = str(store.get("formatted_price", ""))
	_compare_at_text = str(store.get("compare_at_formatted_price", "")).strip_edges()
	var discount := maxi(int(offer.get("discount_percent", 0)), 0)
	_discount_badge.visible = discount > 0
	_percent_label.text = "%d%%" % discount
	_set_buy_label("Buy for %s" % _price_text, not _compare_at_text.is_empty())
	_compare_at_price_label.text = _compare_at_text

	_set_status("")
	_buy_button.visible = true
	_buy_button.disabled = false
	_buy_button.modulate = Color.WHITE
	_set_close_enabled(true)
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
	_set_close_enabled(false)
	_buy_button.disabled = true
	_buy_button.modulate = BUSY_BUTTON_TINT
	_set_buy_label("Purchasing…" if status == "Purchasing…" else "Checking…", false)
	_set_status(status, StatusTone.BUSY)


func show_error(message: String, can_retry: bool) -> void:
	_is_busy = false
	_set_close_enabled(true)
	_buy_button.disabled = not can_retry
	_buy_button.modulate = Color.WHITE if can_retry else BUSY_BUTTON_TINT
	_set_buy_label("Try Again" if can_retry else "Unavailable", false)
	_set_status(message, StatusTone.ERROR)


## Ends the purchase and closes the modal; the Main Menu's purchase reward sequence confirms the
## purchase in its place.
func close_after_purchase() -> void:
	_is_busy = false
	_set_close_enabled(true)
	close()


## Where each reward's art sits in the modal, keyed "coins" or by ability id, so the purchase reward
## sequence can lift the bought rewards straight off it.
func get_reward_icon_global_rects() -> Dictionary:
	var rects := {}
	if _coin_art.is_visible_in_tree():
		rects["coins"] = _coin_art.get_global_rect()
	var chip_ids := {"hammer": _hammer_reward, "shuffle": _shuffle_reward,
		"highlight": _lantern_reward, "freezer": _freezer_reward}
	for ability_id in chip_ids.keys():
		var chip := chip_ids[ability_id] as OfferBoosterChip
		if chip.is_visible_in_tree():
			rects[ability_id] = chip.get_icon_global_rect()
	return rects


func _booster_chips() -> Array[OfferBoosterChip]:
	var chips: Array[OfferBoosterChip] = [
		_hammer_reward, _shuffle_reward, _lantern_reward, _freezer_reward
	]
	return chips


## The Buy label's second line; the crossed-out compare price above it only accompanies the price.
func _set_buy_label(text: String, show_compare_at: bool) -> void:
	_buy_price_label.text = text
	_buy_button.accessibility_name = text
	_compare_at_price_label.visible = show_compare_at


func _set_close_enabled(is_enabled: bool) -> void:
	_close_button.disabled = not is_enabled
	_close_button.modulate = Color.WHITE if is_enabled else DISABLED_CLOSE_TINT


func _set_status(message: String, tone: StatusTone = StatusTone.BUSY) -> void:
	_status_label.text = message
	_status_pill.visible = not message.is_empty()
	var style: StyleBox = {
		StatusTone.BUSY: status_busy_style,
		StatusTone.ERROR: status_error_style,
	}[tone]
	_status_pill.add_theme_stylebox_override("panel", style)
	_status_label.add_theme_color_override("font_color", STATUS_TEXT_COLORS[tone])


func _format_count(value: int) -> String:
	var value_text := str(value)
	var formatted := ""
	while value_text.length() > 3:
		formatted = ",%s%s" % [value_text.right(3), formatted]
		value_text = value_text.substr(0, value_text.length() - 3)
	return value_text + formatted
