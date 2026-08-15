extends RefCounted

## Capture setup for the zero-life Retry recovery modal opened from LevelFailureScreen.


func setup(scene_root: Node, tree: SceneTree) -> void:
	PlayerProgress.reset_progress()
	while PlayerProgress.get_lives() > 1:
		PlayerProgress.spend_life()

	scene_root.set("launched_from_dev_mode", false)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_fail_level")
	await tree.create_timer(0.4).timeout
	scene_root.call("_on_failure_retry_pressed")
	await tree.create_timer(0.4).timeout

	for _frame in range(2):
		await tree.process_frame
