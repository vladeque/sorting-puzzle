extends RefCounted

## Capture setup for the profile editor's cosmetic-frame tab.


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("_switch_tab", &"frame")
	for _frame in range(2):
		await tree.process_frame
