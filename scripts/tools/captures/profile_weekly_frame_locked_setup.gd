extends RefCounted

## Shows an unearned gold frame and its unlock explanation in the real profile picker.


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("_switch_tab", &"frame")
	await tree.process_frame
	var tile := (scene_root.get("_choice_tiles") as Dictionary)["frame_weekly_gold"] as Button
	tile.pressed.emit()
	await tree.process_frame
	var scroll := scene_root.get_node("%ChoiceScroll") as ScrollContainer
	scroll.ensure_control_visible(tile)
	await tree.process_frame
