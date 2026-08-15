extends RefCounted

## Capture setup for the failed-level modal over a representative campaign board.

const LEVEL_NUMBER := 7


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_fail_level")
	await tree.create_timer(0.45).timeout

	for _frame in range(2):
		await tree.process_frame
