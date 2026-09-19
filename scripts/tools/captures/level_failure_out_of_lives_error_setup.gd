extends RefCounted

## Capture setup for the retryable rewarded-life error state.


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
	var modal := scene_root.get("_out_of_lives_overlay") as OutOfLivesMenu
	modal.set_rewarded_action_state(OutOfLivesMenu.REWARDED_STATE_ERROR, true)

	for _frame in range(2):
		await tree.process_frame
