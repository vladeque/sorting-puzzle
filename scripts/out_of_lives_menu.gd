extends Control
class_name OutOfLivesMenu

## Reusable campaign-lives modal. ProductionMainMenu opens it from a zero-life launch request or the
## lives widget; level.gd also opens it when Failure's Retry finds zero lives. Presentation and
## motion stay inside this scene while the current owner supplies the offer and handles intent.
##
## The modal renders one of two states, chosen entirely from the count set_offer() receives. Below
## the cap it offers recovery: the `MM:SS` countdown plus coin and rewarded-ad actions. At the cap
## there is nothing left to sell, so the countdown swaps to a full-lives message and the two
## purchase actions swap to a single dismissing `Got it`.

signal close_requested
signal purchase_requested
signal rewarded_ad_requested

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const CONTENT_REGION_HEIGHT := 224.0
const OUT_OF_LIVES_TITLE := "OUT OF LIVES"
const GET_MORE_LIVES_TITLE := "GET MORE LIVES"
const FULL_LIVES_TITLE := "LIVES FULL"
const REWARDED_STATE_UNAVAILABLE := &"unavailable"
const REWARDED_STATE_READY := &"ready"
const REWARDED_STATE_LOADING := &"loading"
const REWARDED_STATE_VERIFYING := &"verifying"
const REWARDED_STATE_PENDING := &"pending"
const REWARDED_STATE_ERROR := &"error"

@export var rewarded_action_font_size := 24
@export var minimum_rewarded_action_font_size := 16
@export var rewarded_action_text_padding := 24.0

@onready var _shell := %Shell as GameplayModalShell
@onready var _life_content := %LifeContent as Control
@onready var _purchase_button := %PurchaseButton as Button
@onready var _rewarded_ad_button := %RewardedAdButton as Button
@onready var _got_it_button := %GotItButton as Button
@onready var _life_count_label := %LifeCountLabel as Label
@onready var _countdown_label := %CountdownLabel as Label
@onready var _price_label := %PriceLabel as Label
@onready var _timer_center := %TimerCenter as Control
@onready var _message_center := %MessageCenter as Control
@onready var _reward_status_label := %RewardStatusLabel as Label


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
	_rewarded_ad_button.reparent(_shell.get_action_row(), false)
	_got_it_button.reparent(_shell.get_action_row(), false)
	_purchase_button.pressed.connect(func() -> void: purchase_requested.emit())
	_rewarded_ad_button.pressed.connect(func() -> void: rewarded_ad_requested.emit())
	_got_it_button.pressed.connect(func() -> void: close_requested.emit())
	_rewarded_ad_button.resized.connect(_fit_rewarded_action_text)
	set_rewarded_action_state(REWARDED_STATE_UNAVAILABLE, false)


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
	_rewarded_ad_button.visible = not is_full
	_got_it_button.visible = is_full
	_reward_status_label.visible = not is_full and not _reward_status_label.text.is_empty()


func set_purchase_enabled(is_enabled: bool) -> void:
	_purchase_button.disabled = not is_enabled


func set_rewarded_action_state(state: StringName, is_available: bool) -> void:
	_reward_status_label.text = ""
	match state:
		REWARDED_STATE_READY:
			_rewarded_ad_button.text = "Watch Ad"
		REWARDED_STATE_LOADING:
			_rewarded_ad_button.text = "Loading..."
		REWARDED_STATE_VERIFYING:
			_rewarded_ad_button.text = "Verifying..."
		REWARDED_STATE_PENDING:
			_rewarded_ad_button.text = "Verify Reward"
			_reward_status_label.text = "Reward verification is still pending."
		REWARDED_STATE_ERROR:
			_rewarded_ad_button.text = "Try Again"
			_reward_status_label.text = "Ad unavailable. Please try again."
		_:
			_rewarded_ad_button.text = "Watch Ad"
	_rewarded_ad_button.disabled = not is_available
	_reward_status_label.visible = (
		_rewarded_ad_button.visible and not _reward_status_label.text.is_empty()
	)
	_fit_rewarded_action_text.call_deferred()


func _fit_rewarded_action_text() -> void:
	var font := _rewarded_ad_button.get_theme_font("font")
	var available_width := maxf(
		minf(_rewarded_ad_button.size.x, _rewarded_ad_button.custom_minimum_size.x)
		- rewarded_action_text_padding, 1.0
	)
	var font_size := rewarded_action_font_size
	while font_size > minimum_rewarded_action_font_size:
		if font.get_string_size(_rewarded_ad_button.atr(_rewarded_ad_button.text),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available_width:
			break
		font_size -= 1
	_rewarded_ad_button.add_theme_font_size_override("font_size", font_size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fit_rewarded_action_text.call_deferred()


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
