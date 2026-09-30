extends RefCounted

## Main Menu reward-chest opening, open with its coins and abilities held in the reveal row.

const SupportScript := preload("res://scripts/tools/captures/reward_chest_ceremony_capture_support.gd")


func setup(scene_root: Node, tree: SceneTree) -> void:
	SupportScript.start(scene_root, {"auto_open_delay": 0.2, "reveal_hold": 999.0})
	await tree.create_timer(2.8).timeout
