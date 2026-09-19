extends Control
class_name AbilityPurchaseMenu

## Reusable in-level ability-purchase overlay shown when the player taps an ability with zero
## remaining uses. Composes scenes/ui/gameplay_modal_shell.tscn for shade, outer panel, title,
## close button, content region, and action row (UI-003; see docs/SCENES.md "Shared Gameplay UI
## Roles"). Buying applies one ability immediately -- it is not an inventory purchase, hence "USE
## ABILITY" rather than "GET MORE ITEMS"/"×1" (see
## docs/UI_003_LEVEL_UI_CONSISTENCY_TICKET.md). scripts/level.gd only calls set_offer()/open()/
## close() and listens for close_pressed/buy_pressed/ad_pressed. The owner supplies rewarded-ad
## visibility/readiness; this scene never decides authorization or applies an ability.

signal close_pressed
signal buy_pressed
signal ad_pressed

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const BUY_STYLE := preload("res://assets/themes/style_box_green_primary_button.tres")
const CONTENT_REGION_HEIGHT := 224.0

@onready var _shell := %Shell as GameplayModalShell
@onready var _purchase_content := %PurchaseContent as Control
@onready var _ability_icon := %AbilityIcon as TextureRect
@onready var _buy_button := %BuyButton as Button
@onready var _price_label := %PriceLabel as Label
@onready var _watch_ad_button := %WatchAdButton as Button


func _ready() -> void:
	_shell.configure("USE ABILITY")
	_shell.set_preferred_size(Vector2(
		GameplayUIThemeScript.MODAL_MAX_WIDTH,
		GameplayUIThemeScript.MODAL_COMPACT_HEIGHT
	))
	_shell.set_content_region_height(CONTENT_REGION_HEIGHT)
	_shell.close_requested.connect(func() -> void: close_pressed.emit())
	_purchase_content.reparent(_shell.get_content_region(), false)
	_buy_button.reparent(_shell.get_action_row(), false)
	_watch_ad_button.reparent(_shell.get_action_row(), false)
	_buy_button.pressed.connect(func() -> void: buy_pressed.emit())
	_watch_ad_button.pressed.connect(func() -> void: ad_pressed.emit())

	_watch_ad_button.visible = false


func set_offer(ability_texture: Texture2D, price: int, _available_coins: int) -> void:
	_ability_icon.texture = ability_texture
	_price_label.text = str(maxi(price, 0))

	# This remains an actionable price button when the player is short on coins: Level routes that
	# press to the in-level Shop instead of treating it as an inert unavailable action.
	_buy_button.disabled = false
	_buy_button.modulate = Color.WHITE
	_buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_buy_button.add_theme_stylebox_override("normal", BUY_STYLE)
	_buy_button.add_theme_stylebox_override("pressed", BUY_STYLE)
	_buy_button.add_theme_stylebox_override("hover", BUY_STYLE)
	_buy_button.add_theme_stylebox_override("disabled", BUY_STYLE)


func set_buy_action_enabled(is_enabled: bool) -> void:
	_buy_button.disabled = not is_enabled
	_buy_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if is_enabled else Control.CURSOR_ARROW
	)


func set_ad_action_state(state: StringName, is_visible: bool, is_enabled: bool = false) -> void:
	_watch_ad_button.visible = is_visible
	if not is_visible:
		return
	match state:
		&"loading":
			_watch_ad_button.text = "Loading..."
		&"verifying":
			_watch_ad_button.text = "Verifying..."
		&"pending":
			_watch_ad_button.text = "Verify Reward"
		&"error":
			_watch_ad_button.text = "Try Again"
		_:
			_watch_ad_button.text = "Watch Ad"
	_watch_ad_button.disabled = not is_enabled
	_watch_ad_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if is_enabled else Control.CURSOR_ARROW
	)
	_watch_ad_button.add_theme_stylebox_override("normal", BUY_STYLE)
	_watch_ad_button.add_theme_stylebox_override("pressed", BUY_STYLE)
	_watch_ad_button.add_theme_stylebox_override("hover", BUY_STYLE)


func is_transitioning() -> bool:
	return _shell.is_transitioning()


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_shell.apply_safe_layout(safe_margins, viewport_size)


## Shows this overlay's root immediately (so the shell's own fade-in is actually visible), then
## starts the shell's animated fade. The root's own visible flag is what scripts/level.gd's
## `_ability_purchase_overlay.visible` checks observe.
func open() -> void:
	show()
	_shell.open()


## Waits for the shell's fade-out before hiding the root -- hiding the root immediately would skip
## the fade entirely, since an invisible ancestor stops all descendant rendering regardless of the
## shell's own modulate/visible state.
func close() -> void:
	await _shell.close()
	if _shell.visible:
		return
	hide()
