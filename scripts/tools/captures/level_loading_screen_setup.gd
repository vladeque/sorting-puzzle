extends RefCounted


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("show_preview")
	await tree.process_frame
