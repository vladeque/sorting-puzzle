extends RefCounted

## Shared driver for the purchase reward sequence captures: tunes the sequence for a chosen beat,
## and pins the pulsing tap prompt so every resolution matches.

const UIMotionScript := preload("res://scripts/ui_motion.gd")


## Holds the reveal indefinitely, or (with `flight_seconds`) moves straight on to slow flights so a
## single-resolution capture can freeze them mid-air.
static func prepare(sequence: Node, flight_seconds: float = 0.0) -> void:
	if flight_seconds <= 0.0:
		sequence.set("reveal_hold", 999.0)
		return
	sequence.set("reveal_hold", 0.1)
	var row := sequence.get_node("%RewardRow")
	row.set("coin_flight_duration", flight_seconds)
	row.set("ability_flight_duration", flight_seconds)


static func pin_tap_hint(sequence: Node) -> void:
	var hint := sequence.get_node("%TapHint") as Control
	UIMotionScript.stop_tween(hint, &"_purchase_hint_tween")
	hint.modulate.a = 1.0
