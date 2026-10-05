extends "res://scripts/tools/captures/account_deletion_modal_setup.gd"

## Verifies the final retained-records/deadline paragraph is reachable in long localized copy.
func setup(scene_root: Node, tree: SceneTree) -> void:
	await super.setup(scene_root, tree)
	var modal := scene_root.get("_account_deletion_modal") as Control
	var scroll := modal.get_node("%MessageScroll") as ScrollContainer
	var scroll_to_end := func() -> void:
		await tree.process_frame
		await tree.process_frame
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	tree.root.size_changed.connect(scroll_to_end)
	await scroll_to_end.call()
