extends RefCounted

## Shows the unearned phoenix frame and its unlock toast in the profile picker.


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("_switch_tab", &"frame")
	await tree.process_frame
	(scene_root.get_node("%UnlockToast") as ToastMessage).display_seconds = 600.0
	var tile := (scene_root.get("_choice_tiles") as Dictionary)["frame_combo_50"] as Button
	tile.pressed.emit()
	var scroll := scene_root.get_node("%ChoiceScroll") as ScrollContainer
	scroll.ensure_control_visible(tile)
	await tree.create_timer(0.3).timeout
