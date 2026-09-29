extends RefCounted

## Show the real first-place picker state for responsive UI captures.


func setup(scene_root: Node, tree: SceneTree) -> void:
	var progress := tree.root.get_node("PlayerProgress")
	var snapshot := progress.get("_data") as Dictionary
	snapshot["weekly_frame_best_rank"] = 1
	scene_root.call("_switch_tab", &"frame")
	await tree.process_frame
	scene_root.call("_select_choice", "frame_weekly_gold")
	await tree.process_frame
