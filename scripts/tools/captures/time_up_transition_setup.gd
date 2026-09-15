extends RefCounted

## Captures the strongest readable frame of the 00:00 snap between timeout and the extension offer.

const LEVEL_NUMBER := 7


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.set("_time_remaining", 0.0)
	scene_root.call("_handle_level_time_expired")
	await tree.create_timer(0.26).timeout
	await RenderingServer.frame_post_draw
