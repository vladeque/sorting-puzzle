extends RefCounted

## Shared driver for the reward-chest opening captures: queues the first chest goal's rewards in
## the real Main Menu, holds its widget at full, and starts the opening sequence with the given
## timing overrides so a capture can freeze a chosen beat.

const UIMotionScript := preload("res://scripts/ui_motion.gd")


static func start(scene_root: Node, overrides: Dictionary) -> Control:
	var ceremony := scene_root.get_node("%RewardChestOpenCeremony") as Control
	for property in overrides.keys():
		ceremony.set(property, overrides[property])

	var progress := scene_root.get_node(^"/root/PlayerProgress")
	scene_root.call("_queue_chest_ceremony_rewards", 0)
	scene_root.set("_chest_full_hold_goal", int(progress.call("get_reward_chest_goal_at_index", 0)))
	scene_root.call("_set_animated_reward_chest_status")
	scene_root.call("_on_reward_star_animation_finished")
	return ceremony


## The prompt pulses on a loop; captures pin it at full strength so every resolution matches.
static func pin_tap_hint(ceremony: Control) -> void:
	var hint := ceremony.get_node("%TapHint") as Control
	UIMotionScript.stop_tween(hint, &"_chest_hint_tween")
	hint.modulate.a = 1.0
