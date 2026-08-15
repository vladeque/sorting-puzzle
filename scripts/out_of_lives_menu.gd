extends Control
class_name OutOfLivesMenu

## Main-menu modal for campaign lives, opened either by a launch request at zero lives or by the
## top status bar's lives widget. Presentation and motion stay inside this scene; ProductionMainMenu
## supplies the live count/countdown/price and handles the purchase or close signals.
##
## The modal renders one of two states, chosen entirely from the count set_offer() receives. Below
## the cap it offers recovery: the `MM:SS` countdown plus the coin-price purchase action. At the cap
## there is nothing left to sell, so the countdown swaps to a full-lives message and the two
## purchase actions swap to a single dismissing `Got it`.

signal close_requested
signal purchase_requested

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const CONTENT_REGION_HEIGHT := 224.0
const OUT_OF_LIVES_TITLE := "OUT OF LIVES"
const GET_MORE_LIVES_TITLE := "GET MORE LIVES"
const FULL_LIVES_TITLE := "LIVES FULL"

@onready var _shell := %Shell as GameplayModalShell
@onready var _life_content := %LifeContent as Control
@onready var _purchase_button := %PurchaseButton as Button
@onready var _coming_soon_button := %ComingSoonButton as Button
@onready var _got_it_button := %GotItButton as Button
@onready var _life_count_label := %LifeCountLabel as Label
@onready var _countdown_label := %CountdownLabel as Label
@onready var _price_label := %PriceLabel as Label
@onready var _timer_center := %TimerCenter as Control
@onready var _message_center := %MessageCenter as Control


func _ready() -> void:
	_shell.configure(OUT_OF_LIVES_TITLE)
	_shell.set_preferred_size(Vector2(
		GameplayUIThemeScript.MODAL_MAX_WIDTH,
		GameplayUIThemeScript.MODAL_COMPACT_HEIGHT
	))
	_shell.set_content_region_height(CONTENT_REGION_HEIGHT)
	_shell.close_requested.connect(func() -> void: close_requested.emit())
	_life_content.reparent(_shell.get_content_region(), false)
	_purchase_button.reparent(_shell.get_action_row(), false)
	_coming_soon_button.reparent(_shell.get_action_row(), false)
	_got_it_button.reparent(_shell.get_action_row(), false)
	_purchase_button.pressed.connect(func() -> void: purchase_requested.emit())
	_got_it_button.pressed.connect(func() -> void: close_requested.emit())


## Applies the whole modal state from the current life economy. `max_lives` decides which of the two
## states renders, so the modal switches in place when a countdown restores the last missing life
## while it is open.
func set_offer(lives: int, max_lives: int, seconds_remaining: int, coin_price: int) -> void:
	var available_lives := maxi(lives, 0)
	var is_full := max_lives > 0 and available_lives >= max_lives
	_life_count_label.text = str(available_lives)
	_countdown_label.text = _format_restore_time(seconds_remaining)
	_price_label.text = str(maxi(coin_price, 0))
	_shell.configure(_resolve_title(available_lives, is_full))
	_timer_center.visible = not is_full
	_message_center.visible = is_full
	_purchase_button.visible = not is_full
	_coming_soon_button.visible = not is_full
	_got_it_button.visible = is_full


func set_purchase_enabled(is_enabled: bool) -> void:
	_purchase_button.disabled = not is_enabled


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


func _resolve_title(lives: int, is_full: bool) -> String:
	if is_full:
		return FULL_LIVES_TITLE
	if lives <= 0:
		return OUT_OF_LIVES_TITLE
	return GET_MORE_LIVES_TITLE


func _format_restore_time(seconds_remaining: int) -> String:
	var clamped_seconds := maxi(seconds_remaining, 0)
	var minutes_remaining := floori(float(clamped_seconds) / 60.0)
	return "%02d:%02d" % [minutes_remaining, clamped_seconds % 60]
