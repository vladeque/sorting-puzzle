extends RefCounted

## Shows the level-20 frame after recording its completion.


func setup(scene_root: Node, tree: SceneTree) -> void:
	var progress := tree.root.get_node("PlayerProgress")
	var snapshot := progress.get("_data") as Dictionary
	(snapshot["completion_stars_by_level"] as Dictionary)["20"] = 1
	scene_root.call("_switch_tab", &"frame")
	await tree.process_frame
	scene_root.call("_select_choice", "frame_level_20")
	await tree.process_frame
	var tile := (scene_root.get("_choice_tiles") as Dictionary)["frame_level_20"] as Control
	(scene_root.get_node("%ChoiceScroll") as ScrollContainer).ensure_control_visible(tile)
	await tree.create_timer(0.3).timeout
