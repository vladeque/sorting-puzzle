extends Control
class_name AbilityPurchaseMenu

## Reusable in-level ability-purchase overlay shown when the player taps an ability with zero
## remaining uses. Composes scenes/ui/gameplay_modal_shell.tscn for shade, outer panel, title,
## close button, content region, and action row (UI-003; see docs/SCENES.md "Shared Gameplay UI
## Roles"). Buying applies one ability immediately -- it is not an inventory purchase, hence "USE
## ABILITY"/"USE NOW" rather than "GET MORE ITEMS"/"×1" (see
## docs/UI_003_LEVEL_UI_CONSISTENCY_TICKET.md). scripts/level.gd only calls set_offer()/open()/
## close() and listens for close_pressed/buy_pressed/ad_pressed.

signal close_pressed
signal buy_pressed
signal ad_pressed

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const AFFORDABLE_BUY_STYLE := preload("res://assets/themes/style_box_green_primary_button.tres")
const UNAFFORDABLE_BUY_STYLE := preload("res://assets/themes/style_box_disabled_action_button.tres")

@onready var _shell := %Shell as GameplayModalShell
@onready var _purchase_content := %PurchaseContent as Control
@onready var _ability_icon := %AbilityIcon as TextureRect
@onready var _buy_button := %BuyButton as Button
@onready var _price_label := %PriceLabel as Label
@onready var _watch_ad_button := %WatchAdButton as Button


func _ready() -> void:
	_shell.configure("USE ABILITY")
	_shell.set_preferred_size(Vector2(GameplayUIThemeScript.MODAL_MAX_WIDTH, 560.0))
	_shell.close_requested.connect(func() -> void: close_pressed.emit())
	_purchase_content.reparent(_shell.get_content_region(), false)
	_buy_button.reparent(_shell.get_action_row(), false)
	_watch_ad_button.reparent(_shell.get_action_row(), false)
	_buy_button.pressed.connect(func() -> void: buy_pressed.emit())
	_watch_ad_button.pressed.connect(func() -> void: ad_pressed.emit())

	# The rewarded-ad placeholder grants nothing until a separate feature is approved (see
	# docs/UI_003_LEVEL_UI_CONSISTENCY_TICKET.md). Hidden in production; visible-but-disabled with
	# "Coming Soon" copy (the scene's authored default) in a debug build so it stays reviewable
	# without ever exposing a live no-op to a player.
	_watch_ad_button.visible = OS.is_debug_build()


func set_offer(ability_texture: Texture2D, price: int, available_coins: int) -> void:
	_ability_icon.texture = ability_texture
	_price_label.text = str(maxi(price, 0))

	var can_afford := available_coins >= price
	_buy_button.disabled = not can_afford
	_buy_button.modulate = Color.WHITE
	_buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_afford else Control.CURSOR_ARROW

	# A deliberate neutral "unavailable" resource, not alpha-only styling, so an unaffordable Buy
	# reads and behaves as inert rather than a dimmed version of the positive action. Explicitly
	# typed StyleBox: the two branches are different concrete StyleBox subclasses (StyleBoxTexture
	# vs StyleBoxFlat), and this project's strict GDScript warnings reject an inferred Variant.
	var style: StyleBox = AFFORDABLE_BUY_STYLE if can_afford else UNAFFORDABLE_BUY_STYLE
	_buy_button.add_theme_stylebox_override("normal", style)
	_buy_button.add_theme_stylebox_override("pressed", style)
	_buy_button.add_theme_stylebox_override("hover", style)
	_buy_button.add_theme_stylebox_override("disabled", style)


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
