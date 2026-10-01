extends RefCounted

## Shows every earned frame on a broad avatar to compare the shared opening.


func setup(scene_root: Node, tree: SceneTree) -> void:
	var progress := tree.root.get_node("PlayerProgress")
	var snapshot := progress.get("_data") as Dictionary
	snapshot["combo_best"] = 50
	snapshot["weekly_frame_best_rank"] = 1
	var avatar_id := OS.get_environment("PROFILE_FRAME_CAPTURE_AVATAR")
	if not progress.get_available_avatar_ids().has(avatar_id):
		avatar_id = "avatar_penguin"
	scene_root.call("_select_choice", avatar_id)
	scene_root.call("_switch_tab", &"frame")
	await tree.process_frame
	scene_root.call("_select_choice", "frame_combo_50")
	await tree.process_frame
	var tile := (scene_root.get("_choice_tiles") as Dictionary)["frame_combo_50"] as Control
	(scene_root.get_node("%ChoiceScroll") as ScrollContainer).ensure_control_visible(tile)
	await tree.create_timer(0.3).timeout
