extends RefCounted


func setup(scene_root: Node, tree: SceneTree) -> void:
	await tree.process_frame
	var report_item := scene_root.get_node_or_null("%ReportAdItem") as Control
	if report_item != null:
		report_item.call("set_expanded", true)
