extends RefCounted

## Main Menu reward-chest opening, lifted to the centre and waiting for a tap.

const SupportScript := preload("res://scripts/tools/captures/reward_chest_ceremony_capture_support.gd")


func setup(scene_root: Node, tree: SceneTree) -> void:
	var ceremony := SupportScript.start(scene_root, {"auto_open_delay": 999.0, "shake_pause": 999.0})
	await tree.create_timer(1.0).timeout
	SupportScript.pin_tap_hint(ceremony)
