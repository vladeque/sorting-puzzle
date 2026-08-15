extends RefCounted

## Capture setup for Golden Searchlight on a representative real level board.

const LEVEL_NUMBER := 5


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_apply_level_config", scene_root.call("_load_level_config", LEVEL_NUMBER))
	scene_root.call("_collect_slots")
	scene_root.call("_use_highlight")
	# Hold until the periodic beam reaches the middle shelves, not only its top-edge entry.
	await tree.create_timer(3.2).timeout

	for _frame in range(2):
		await tree.process_frame
