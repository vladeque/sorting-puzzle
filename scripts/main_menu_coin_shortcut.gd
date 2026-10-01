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


## Flight target for coins delivered to the balance (reward-chest and purchase reward sequences).
func get_coin_icon_global_center() -> Vector2:
	return _coin_widget.call("get_coin_icon_global_center") as Vector2


## A short bump as a delivered coin lands. The wrapped widget scales itself rather than this button,
## so the pulse never fights PressScaleButton's own held/released scale.
func play_receive_pulse() -> void:
	_coin_widget.call("play_receive_pulse")
