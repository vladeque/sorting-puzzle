extends RefCounted


func setup(scene_root: Node, _tree: SceneTree) -> void:
	scene_root.call("set_concept", 2)
