extends RefCounted

## Shows every settings toggle's disabled marker for deterministic visual capture.


func setup(scene_root: Node, tree: SceneTree) -> void:
	for button_name in [&"MusicButton", &"SoundEffectsButton", &"VibrationButton"]:
		var button := scene_root.find_child(String(button_name), true, false) as Button
		if button == null:
			push_error("settings_disabled_setup could not find %s." % button_name)
			continue
		var cross_out := button.get_node_or_null("CrossOut") as Control
		if cross_out == null:
			push_error("settings_disabled_setup could not find %s/CrossOut." % button_name)
			continue
		cross_out.show()

	for _frame in range(2):
		await tree.process_frame
