extends RefCounted

## Capture setup for the Hammer impact pose on a representative real level board.

const LEVEL_NUMBER := 2


func setup(scene_root: Node, tree: SceneTree) -> void:
	# Preserve the capture tool's exact requested viewport, including the squarer tablet case.
	tree.root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("hammer_haptics_enabled", false)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_apply_level_config", scene_root.call("_load_level_config", LEVEL_NUMBER))
	scene_root.call("_collect_slots")
	scene_root.call("_use_hammer")

	# Let the three goods finish gathering, then hold the supplied impact frame for inspection.
	await tree.create_timer(0.4).timeout
	var effect := scene_root.get_node_or_null("UI/HammerImpactEffect") as HammerImpactEffect
	if effect != null:
		var animation_player := effect.get_node("AnimationPlayer") as AnimationPlayer
		animation_player.seek(0.58, true)
		animation_player.pause()

	for _frame in range(2):
		await tree.process_frame
