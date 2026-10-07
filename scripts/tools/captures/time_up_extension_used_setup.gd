extends "res://scripts/tools/captures/time_up_extension_setup.gd"

## Both extension methods have been used; preserve the complete localized captions.
func setup(scene_root: Node, tree: SceneTree) -> void:
	await super.setup(scene_root, tree)
	var offer := scene_root.get("_time_up_extension_overlay") as TimeUpExtensionModal
	offer.set_offer(60, 500, false, false, true)
	await tree.process_frame
