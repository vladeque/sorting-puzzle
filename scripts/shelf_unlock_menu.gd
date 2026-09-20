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

@onready var _shell := %Shell as GameplayModalShell
@onready var _unlock_content := %UnlockContent as Control
@onready var _rewarded_ad_button := %RewardedAdButton as Button
@onready var _offer_label := %OfferLabel as Label
@onready var _reward_status_label := %RewardStatusLabel as Label


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
	set_rewarded_action_state(REWARDED_STATE_UNAVAILABLE, false)


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


## The remaining clear count the shelf still shows. Stating it keeps the alternative honest: the ad
## is a shortcut past a requirement that is still there and unchanged if the ad fails.
func set_offer(remaining_clears: int) -> void:
	var remaining := maxi(remaining_clears, 0)
	_offer_label.text = (
		"Watch one ad to unlock this shelf now."
		if remaining <= 0
		else "Watch one ad to unlock this shelf now, or clear %s more." % remaining
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
