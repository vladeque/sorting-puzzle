extends Control
class_name TimeUpExtensionModal

## Recoverable timeout offer shown before Level enters its terminal failure state. This scene owns
## the shared-shell composition, copy, price presentation, and rewarded-ad request state; level.gd
## owns the timer state, authoritative claim flow, per-attempt limits, Shop routing, and economy.

signal declined
signal coin_requested
signal ad_requested

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const CONTENT_REGION_HEIGHT := 224.0

@export var price_font_size := 30
@export var minimum_price_font_size := 14

@onready var _shell := %Shell as GameplayModalShell
@onready var _extension_content := %ExtensionContent as Control
@onready var _extension_column := %ExtensionColumn as VBoxContainer
@onready var _extension_label := %ExtensionLabel as Label
@onready var _coin_button := %CoinButton as Button
@onready var _coin_icon := %CoinIcon as TextureRect
@onready var _price_label := %PriceLabel as Label
@onready var _price_row := _price_label.get_parent() as HBoxContainer
@onready var _watch_ad_button := %WatchAdButton as Button

var _coin_available := true
var _rewarded_ad_available := false
var _rewarded_ad_used := false
var _content_height := CONTENT_REGION_HEIGHT
var _safe_margins := Vector4.ZERO
var _layout_viewport := Vector2.ZERO


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
	_extension_column.minimum_size_changed.connect(_refresh_content_fit.call_deferred)
	_coin_button.resized.connect(_fit_price_label.call_deferred)
	_refresh_content_fit.call_deferred()


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
	_fit_price_label()
	_coin_button.disabled = not coin_available
	_coin_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if coin_available else Control.CURSOR_ARROW
	)

	_rewarded_ad_available = rewarded_ad_available
	_rewarded_ad_used = rewarded_ad_used
	set_ad_action_state(&"ready")


func set_coin_action_enabled(is_enabled: bool) -> void:
	_coin_button.disabled = not is_enabled or not _coin_available
	_coin_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if not _coin_button.disabled else Control.CURSOR_ARROW
	)


func set_ad_action_state(state: StringName) -> void:
	match state:
		&"loading":
			_watch_ad_button.text = "Loading..."
			_watch_ad_button.disabled = true
		&"verifying":
			_watch_ad_button.text = "Verifying..."
			_watch_ad_button.disabled = true
		&"retry_verification":
			_watch_ad_button.text = "Verify Reward"
			_watch_ad_button.disabled = false
		&"retry":
			_watch_ad_button.text = "Try Again"
			_watch_ad_button.disabled = not _rewarded_ad_available
		_:
			_watch_ad_button.disabled = not _rewarded_ad_available or _rewarded_ad_used
			if _rewarded_ad_used:
				_watch_ad_button.text = "Used"
			elif _rewarded_ad_available:
				_watch_ad_button.text = "Watch Ad"
			else:
				_watch_ad_button.text = "Watch Ad\nUnavailable"
	_watch_ad_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if not _watch_ad_button.disabled else Control.CURSOR_ARROW
	)


func is_transitioning() -> bool:
	return _shell.is_transitioning()


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_safe_margins = safe_margins
	_layout_viewport = viewport_size
	_shell.apply_safe_layout(safe_margins, viewport_size)
	_refresh_content_fit.call_deferred()


## Keep the wrapped explanation inside the cream panel when fallback font metrics or localized
## copy exceed the authored column height. Uniform shell scaling still fits small safe viewports.
func _refresh_content_fit() -> void:
	if not is_node_ready():
		return
	_fit_price_label()
	var height := maxf(CONTENT_REGION_HEIGHT, _extension_column.get_combined_minimum_size().y + 18.0)
	if is_equal_approx(height, _content_height):
		return
	_content_height = height
	_shell.set_content_region_height(height)
	_shell.set_preferred_size(Vector2(GameplayUIThemeScript.MODAL_MAX_WIDTH,
		GameplayUIThemeScript.MODAL_COMPACT_HEIGHT + height - CONTENT_REGION_HEIGHT))
	if _layout_viewport != Vector2.ZERO:
		_shell.apply_safe_layout(_safe_margins, _layout_viewport)


## Fit both numeric prices and translated "Used" labels inside the authored action's padding.
## Start from the normal size each time so switching languages or restoring an offer can grow it.
func _fit_price_label() -> void:
	if not is_node_ready():
		return
	var available_width := _coin_button.custom_minimum_size.x
	if _coin_button.size.x > 0.0:
		available_width = minf(available_width, _coin_button.size.x)
	available_width -= _price_row.offset_left - _price_row.offset_right
	if _coin_icon.visible:
		available_width -= _coin_icon.custom_minimum_size.x + _price_row.get_theme_constant("separation")
	_price_label.add_theme_font_size_override("font_size", GameplayUIThemeScript.fit_label_font_size(
		_price_label, available_width, price_font_size, minimum_price_font_size))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_content_fit.call_deferred()


func open(with_pop := false) -> void:
	show()
	_shell.open(with_pop)


func close() -> void:
	await _shell.close()
	if _shell.visible:
		return
	hide()
