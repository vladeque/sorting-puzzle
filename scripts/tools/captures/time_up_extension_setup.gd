extends RefCounted

## Capture setup for the recoverable timeout offer over a representative active board.

const LEVEL_NUMBER := 7


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.set("_time_remaining", 0.0)
	scene_root.call("_handle_level_time_expired")
	await tree.create_timer(1.1).timeout

	for _frame in range(2):
		await tree.process_frame
