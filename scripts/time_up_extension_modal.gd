extends Control
class_name TimeUpExtensionModal

## Recoverable timeout offer shown before Level enters its terminal failure state. This scene owns
## the shared-shell composition, copy, price presentation, and disabled rewarded-ad placeholder;
## level.gd owns the timer state, per-attempt limits, Shop routing, and economy mutation.

signal declined
signal coin_requested
signal ad_requested

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const CONTENT_REGION_HEIGHT := 224.0

@onready var _shell := %Shell as GameplayModalShell
@onready var _extension_content := %ExtensionContent as Control
@onready var _extension_label := %ExtensionLabel as Label
@onready var _coin_button := %CoinButton as Button
@onready var _coin_icon := %CoinIcon as TextureRect
@onready var _price_label := %PriceLabel as Label
@onready var _watch_ad_button := %WatchAdButton as Button

var _coin_available := true


func _ready() -> void:
	_shell.configure("TIME'S UP")
	_shell.set_preferred_size(Vector2(
		GameplayUIThemeScript.MODAL_MAX_WIDTH,
		GameplayUIThemeScript.MODAL_COMPACT_HEIGHT
	))
	_shell.set_content_region_height(CONTENT_REGION_HEIGHT)
	_shell.close_requested.connect(func() -> void: declined.emit())
	_extension_content.reparent(_shell.get_content_region(), false)
	_coin_button.reparent(_shell.get_action_row(), false)
	_watch_ad_button.reparent(_shell.get_action_row(), false)
	_coin_button.pressed.connect(func() -> void: coin_requested.emit())
	_watch_ad_button.pressed.connect(func() -> void: ad_requested.emit())


func set_offer(
	seconds_granted: int,
	coin_price: int,
	coin_available: bool,
	rewarded_ad_available: bool,
	rewarded_ad_used: bool
) -> void:
	var safe_seconds := maxi(seconds_granted, 1)
	var whole_minutes := floori(float(safe_seconds) / 60.0)
	_extension_label.text = "+%02d:%02d" % [whole_minutes, safe_seconds % 60]
	_coin_available = coin_available
	_coin_icon.visible = coin_available
	_price_label.text = str(maxi(coin_price, 0)) if coin_available else "Used"
	_coin_button.disabled = not coin_available
	_coin_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if coin_available else Control.CURSOR_ARROW
	)

	_watch_ad_button.disabled = not rewarded_ad_available or rewarded_ad_used
	_watch_ad_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if not _watch_ad_button.disabled else Control.CURSOR_ARROW
	)
	if rewarded_ad_used:
		_watch_ad_button.text = "Used"
	elif rewarded_ad_available:
		_watch_ad_button.text = "Watch Ad"
	else:
		_watch_ad_button.text = "Watch Ad\nComing Soon"


func set_coin_action_enabled(is_enabled: bool) -> void:
	_coin_button.disabled = not is_enabled or not _coin_available
	_coin_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if not _coin_button.disabled else Control.CURSOR_ARROW
	)


func is_transitioning() -> bool:
	return _shell.is_transitioning()


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_shell.apply_safe_layout(safe_margins, viewport_size)


func open() -> void:
	show()
	_shell.open()


func close() -> void:
	await _shell.close()
	if _shell.visible:
		return
	hide()
