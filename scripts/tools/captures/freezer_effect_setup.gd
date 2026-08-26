extends RefCounted

## Capture setup for the active Freezer overlay on a representative real level board.

const LEVEL_NUMBER := 5


func setup(scene_root: Node, tree: SceneTree) -> void:
	# The capture tool resizes its root viewport directly. Ignore the project's keep-width stretch
	# policy in this isolated diagnostic process so squarer tablet requests retain their exact size.
	tree.root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_apply_level_config", scene_root.call("_load_level_config", LEVEL_NUMBER))
	scene_root.call("_collect_slots")
	scene_root.call("_use_freezer")
	await tree.create_timer(0.55).timeout

	for _frame in range(2):
		await tree.process_frame
