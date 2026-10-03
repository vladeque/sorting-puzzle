extends RefCounted


func setup(scene_root: Node, tree: SceneTree) -> void:
	# Fill the requested tablet viewport rather than capturing the project's portrait letterbox.
	tree.root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)
	scene_root.call("play_loop_seam")
	await tree.create_timer(float(scene_root.get("seconds_before_loop")) + 0.5).timeout
	# Freeze the actual post-wrap display for a consistent, silent contact sheet.
	scene_root.set_process(false)
	(scene_root.get_node("Soundtrack") as AudioStreamPlayer).stream_paused = true
