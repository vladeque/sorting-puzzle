extends RefCounted

## Shows the standalone completion overlay and keeps its layout in sync during capture resizes.
func setup(scene_root: Node, tree: SceneTree) -> void:
	var fit := func() -> void:
		scene_root.call("apply_safe_layout", Vector4.ZERO, scene_root.get_viewport_rect().size)
	tree.root.size_changed.connect(fit)
	fit.call()
	scene_root.call("set_earned_stars", 12345)
	scene_root.call("open")
	await tree.create_timer(1.2).timeout
