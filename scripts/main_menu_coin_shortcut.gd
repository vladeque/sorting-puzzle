extends PressScaleButton

## Wraps the shared coin_balance_widget.tscn (compact) with the Main Menu's "+" badge and makes
## the whole thing a tap target. production_main_menu.gd connects the native `pressed` signal to
## open the Shop -- this script owns only the wrapped widget's compact size, not navigation.

@onready var _coin_widget := %CoinBalanceWidget as Control


func _ready() -> void:
	super._ready()
	_coin_widget.call("set_compact", true)


func set_amount(amount: int) -> void:
	_coin_widget.call("set_amount", amount)
