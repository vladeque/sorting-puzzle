extends RefCounted

## Capture setup for verifying that the pause shade treats both Freezer render passes equally.

const LEVEL_NUMBER := 5


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_apply_level_config", scene_root.call("_load_level_config", LEVEL_NUMBER))
	scene_root.call("_collect_slots")
	scene_root.call("_use_freezer")
	await tree.create_timer(0.55).timeout
	scene_root.call("_open_pause_menu")
	await tree.create_timer(0.25).timeout

	for _frame in range(2):
		await tree.process_frame
