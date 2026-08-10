extends Control
class_name OutOfLivesMenu

## Main-menu modal shown when a campaign launch is requested at zero lives. Presentation and
## motion stay inside this scene; ProductionMainMenu supplies the live countdown/price and handles
## the purchase or close signals.

signal close_requested
signal purchase_requested

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const CONTENT_REGION_HEIGHT := 224.0

@onready var _shell := %Shell as GameplayModalShell
@onready var _life_content := %LifeContent as Control
@onready var _purchase_button := %PurchaseButton as Button
@onready var _coming_soon_button := %ComingSoonButton as Button
@onready var _life_count_label := %LifeCountLabel as Label
@onready var _countdown_label := %CountdownLabel as Label
@onready var _price_label := %PriceLabel as Label


func _ready() -> void:
	_shell.configure("OUT OF LIVES")
	_shell.set_preferred_size(Vector2(
		GameplayUIThemeScript.MODAL_MAX_WIDTH,
		GameplayUIThemeScript.MODAL_COMPACT_HEIGHT
	))
	_shell.set_content_region_height(CONTENT_REGION_HEIGHT)
	_shell.close_requested.connect(func() -> void: close_requested.emit())
	_life_content.reparent(_shell.get_content_region(), false)
	_purchase_button.reparent(_shell.get_action_row(), false)
	_coming_soon_button.reparent(_shell.get_action_row(), false)
	_purchase_button.pressed.connect(func() -> void: purchase_requested.emit())


func set_offer(lives: int, seconds_remaining: int, coin_price: int) -> void:
	_life_count_label.text = str(maxi(lives, 0))
	_countdown_label.text = _format_restore_time(seconds_remaining)
	_price_label.text = str(maxi(coin_price, 0))


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


func _format_restore_time(seconds_remaining: int) -> String:
	var clamped_seconds := maxi(seconds_remaining, 0)
	var minutes_remaining := floori(float(clamped_seconds) / 60.0)
	return "%02d:%02d" % [minutes_remaining, clamped_seconds % 60]
