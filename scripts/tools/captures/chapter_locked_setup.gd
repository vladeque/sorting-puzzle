extends RefCounted

## Shows Chapter 2's locked card, including the localized remaining-level requirement.
func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.get_node("%Pager").call("go_to_page", 1, false)
	await tree.process_frame
