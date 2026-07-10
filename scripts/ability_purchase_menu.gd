extends ColorRect
class_name AbilityPurchaseMenu

signal close_pressed
signal buy_pressed
signal ad_pressed

@onready var _close_button := $PurchasePanel/CloseButton as Button
@onready var _ability_icon := $PurchasePanel/InnerPanel/AbilitySlot/Icon as TextureRect
@onready var _buy_button := $PurchasePanel/ButtonRow/BuyButton as Button
@onready var _price_label := $PurchasePanel/ButtonRow/BuyButton/PriceRow/PriceLabel as Label
@onready var _watch_ad_button := $PurchasePanel/ButtonRow/WatchAdButton as Button


func _ready() -> void:
	_close_button.pressed.connect(func() -> void: close_pressed.emit())
	_buy_button.pressed.connect(func() -> void: buy_pressed.emit())
	_watch_ad_button.pressed.connect(func() -> void: ad_pressed.emit())


func set_offer(ability_texture: Texture2D, price: int, available_coins: int) -> void:
	_ability_icon.texture = ability_texture
	_price_label.text = str(maxi(price, 0))
	_buy_button.disabled = available_coins < price
	_buy_button.modulate = Color(1, 1, 1, 0.62) if _buy_button.disabled else Color.WHITE
