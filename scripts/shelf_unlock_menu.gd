extends Control
class_name ShelfUnlockMenu

## ADS-006 rewarded locked-shelf confirmation. `scripts/shelf_lock_overlay.gd` reports a tap on a
## shelf's `AD` plate; `scripts/level.gd` answers it by opening this modal, so an incidental shelf
## tap can never start an ad on its own. Composes `scenes/ui/gameplay_modal_shell.tscn` for shade,
## outer panel, title, close button, content region, and action row (UI-003; see docs/SCENES.md's
## "Shared Gameplay UI Roles").
##
## The modal states the exact offer -- one ad unlocks this one shelf -- and renders whichever
## rewarded state its owner supplies. It never decides eligibility, requests an ad, or unlocks a
## shelf: it only emits `close_requested` and `rewarded_ad_requested`.

signal close_requested
signal rewarded_ad_requested

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const CONTENT_REGION_HEIGHT := 224.0
const TITLE := "UNLOCK SHELF"
const REWARDED_STATE_UNAVAILABLE := &"unavailable"
const REWARDED_STATE_READY := &"ready"
const REWARDED_STATE_LOADING := &"loading"
const REWARDED_STATE_VERIFYING := &"verifying"
const REWARDED_STATE_PENDING := &"pending"
const REWARDED_STATE_ERROR := &"error"
## Names both the ad and the exact reward, matching the rewarded-copy rule the other placements use.
const READY_LABEL := "Watch Ad · Unlock Shelf"

@export var rewarded_action_font_size := 24
@export var minimum_rewarded_action_font_size := 16
@export var rewarded_action_text_padding := 24.0

@onready var _shell := %Shell as GameplayModalShell
@onready var _unlock_content := %UnlockContent as Control
@onready var _offer_row := $UnlockContent/OfferRow as HBoxContainer
@onready var _rewarded_ad_button := %RewardedAdButton as Button
@onready var _offer_label := %OfferLabel as Label
@onready var _reward_status_label := %RewardStatusLabel as Label

var _remaining_clears := 0
var _content_height := CONTENT_REGION_HEIGHT
var _safe_margins := Vector4.ZERO
var _layout_viewport := Vector2.ZERO


func _ready() -> void:
	_shell.configure(TITLE)
	_shell.set_preferred_size(Vector2(
		GameplayUIThemeScript.MODAL_MAX_WIDTH,
		GameplayUIThemeScript.MODAL_COMPACT_HEIGHT
	))
	_shell.set_content_region_height(CONTENT_REGION_HEIGHT)
	_shell.close_requested.connect(func() -> void: close_requested.emit())
	_unlock_content.reparent(_shell.get_content_region(), false)
	_rewarded_ad_button.reparent(_shell.get_action_row(), false)
	_rewarded_ad_button.pressed.connect(func() -> void: rewarded_ad_requested.emit())
	_rewarded_ad_button.resized.connect(_fit_rewarded_action_text)
	_offer_row.minimum_size_changed.connect(_refresh_content_fit.call_deferred)
	set_rewarded_action_state(REWARDED_STATE_UNAVAILABLE, false)
	_refresh_content_fit.call_deferred()


## Renders one authoritative rewarded state. `is_enabled` stays the owner's decision so a loaded ad
## the backend cannot yet accept still reads as unavailable rather than as a button that will fail.
func set_rewarded_action_state(state: StringName, is_enabled: bool) -> void:
	_reward_status_label.text = ""
	match state:
		REWARDED_STATE_LOADING:
			_rewarded_ad_button.text = "Loading..."
		REWARDED_STATE_VERIFYING:
			_rewarded_ad_button.text = "Verifying..."
		REWARDED_STATE_PENDING:
			_rewarded_ad_button.text = "Verify Reward"
			_reward_status_label.text = "Reward verification is still pending."
		REWARDED_STATE_ERROR:
			_rewarded_ad_button.text = "Try Again"
			_reward_status_label.text = "Ad unavailable. This shelf stays locked."
		_:
			_rewarded_ad_button.text = READY_LABEL
	_rewarded_ad_button.disabled = not is_enabled
	_rewarded_ad_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if is_enabled else Control.CURSOR_ARROW
	)
	_reward_status_label.visible = not _reward_status_label.text.is_empty()
	_fit_rewarded_action_text.call_deferred()
	_refresh_content_fit.call_deferred()


## Keep the complete translated action inside the authored button rather than widening the row.
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


## The remaining clear count the shelf still shows. Stating it keeps the alternative honest: the ad
## is a shortcut past a requirement that is still there and unchanged if the ad fails.
func set_offer(remaining_clears: int) -> void:
	var remaining := maxi(remaining_clears, 0)
	_remaining_clears = remaining
	_offer_label.text = (
		"Watch one ad to unlock this shelf now."
		if remaining <= 0
		else tr_n("shelf_unlock.offer_or_clear", "shelf_unlock.offer_or_clear.plural", remaining) % remaining
	)
	_refresh_content_fit.call_deferred()


func is_transitioning() -> bool:
	return _shell.is_transitioning()


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_safe_margins = safe_margins
	_layout_viewport = viewport_size
	_shell.apply_safe_layout(safe_margins, viewport_size)
	_refresh_content_fit.call_deferred()


## Reserve the row's complete wrapped height, including a visible reward-status message.
func _refresh_content_fit() -> void:
	if not is_node_ready():
		return
	var row_padding := _offer_row.offset_top - _offer_row.offset_bottom
	var height := maxf(CONTENT_REGION_HEIGHT, _offer_row.get_combined_minimum_size().y + row_padding)
	if is_equal_approx(height, _content_height):
		return
	_content_height = height
	_shell.set_content_region_height(height)
	_shell.set_preferred_size(Vector2(GameplayUIThemeScript.MODAL_MAX_WIDTH,
		GameplayUIThemeScript.MODAL_COMPACT_HEIGHT + height - CONTENT_REGION_HEIGHT))
	if _layout_viewport != Vector2.ZERO:
		_shell.apply_safe_layout(_safe_margins, _layout_viewport)


func open() -> void:
	show()
	_shell.open()


func close() -> void:
	await _shell.close()
	if _shell.visible:
		return
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		set_offer(_remaining_clears)
		_fit_rewarded_action_text.call_deferred()
		_refresh_content_fit.call_deferred()
