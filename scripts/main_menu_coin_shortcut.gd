extends PressScaleButton

## Wraps the shared coin_balance_widget.tscn (compact) with the Main Menu's "+" badge and makes
## the whole thing a tap target. production_main_menu.gd connects the native `pressed` signal to
## open the Shop -- this script owns only the wrapped widget's compact size, not navigation.

const RECEIVE_PULSE_META := &"_coin_receive_pulse_tween"

@onready var _coin_widget := %CoinBalanceWidget as Control


func _ready() -> void:
	super._ready()
	_coin_widget.call("set_compact", true)


func set_amount(amount: int) -> void:
	_coin_widget.call("set_amount", amount)


## Flight target for coins delivered to the balance (the reward-chest opening sequence).
func get_coin_icon_global_center() -> Vector2:
	return _coin_widget.call("get_coin_icon_global_center") as Vector2


## A short bump on the wrapped widget as a delivered coin lands. It scales the widget rather than
## this button, so it never fights PressScaleButton's own held/released scale.
func play_receive_pulse() -> void:
	_coin_widget.pivot_offset = _coin_widget.size * 0.5
	var tween := UIMotionScript.retween(_coin_widget, RECEIVE_PULSE_META)
	tween.tween_property(_coin_widget, "scale", Vector2(1.12, 1.12), 0.07) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_coin_widget, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
