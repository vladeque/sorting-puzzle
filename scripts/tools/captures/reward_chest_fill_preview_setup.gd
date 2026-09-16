extends RefCounted


func setup(scene_root: Node, _tree: SceneTree) -> void:
	scene_root.call("prepare_capture")
