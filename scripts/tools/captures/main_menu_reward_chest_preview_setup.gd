extends RefCounted

## Main Menu reward-chest preview after its star flight, with the chest lifted and waiting for a tap
## above the preview bar.

const SupportScript := preload("res://scripts/tools/captures/reward_chest_ceremony_capture_support.gd")


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("autoplay", false)
	var ceremony := scene_root.get_node("%MainMenu").get_node("%RewardChestOpenCeremony") as Control
	ceremony.set("auto_open_delay", 999.0)
	ceremony.set("shake_pause", 999.0)
	scene_root.call("play_preview")
	await tree.create_timer(3.2).timeout
	SupportScript.pin_tap_hint(ceremony)
