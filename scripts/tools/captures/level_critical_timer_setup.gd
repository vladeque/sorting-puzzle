extends RefCounted

## Capture setup for `level.tscn`: shows the stable 00:30 critical-timer state after its short
## per-second pulse has settled, so the red badge can be compared across responsive resolutions.

const LEVEL_NUMBER := 5


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_apply_level_config", scene_root.call("_load_level_config", LEVEL_NUMBER))
	scene_root.call("_collect_slots")
	scene_root.set("_has_player_started_timer", true)
	scene_root.set("_time_remaining", 30.0)
	scene_root.call("_update_timer_label")
	# Hold the runtime after entering the real active state so every resolution captures the same
	# displayed second instead of allowing the level's `_process()` countdown to keep advancing.
	scene_root.set("_app_interrupted", true)

	await tree.create_timer(0.35).timeout
	for _frame in range(4):
		await tree.process_frame
