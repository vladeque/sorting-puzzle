extends SceneTree

## Deterministic rendered sequence. Use isolated runner -Windowed -GodotArguments @('--fixed-fps','60')
## and -UserArguments @('--out','D:/projects/sorting-puzzle/tmp/ui_capture/sticky_motion').
func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with("SortingPuzzleTest_"):
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--out" or not args[1].is_absolute_path() or DisplayServer.get_name() == "headless":
		push_error("Requires windowed isolated capture and --out ABSOLUTE_DIRECTORY")
		quit(1)
		return
	var output := args[1]
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join(".gdignore"), FileAccess.WRITE).close()
	root.size = Vector2i(720, 1280)
	await process_frame
	root.get_node("SfxManager").set_muted(true)
	var level = load("res://scenes/testing/sticky_items_preview.tscn").instantiate()
	root.add_child(level)
	level._set_moving_shelf_rows_paused(true)
	for frame in range(18):
		await process_frame
	var item: ShelfItem = level._get_slot_item(level._get_front_slots(level._get_all_shelves()[0])[0])
	var origin := item.global_position
	var pointer := origin
	for frame in range(180):
		match frame:
			18, 50: level._handle_press_at(origin)
			21: level._handle_release_at(origin)
			137: level._handle_release_at(pointer)
		if frame >= 52 and frame <= 74:
			pointer = origin + item.global_transform.basis_xform(Vector2(160, -50) * float(frame - 52) / 22.0)
			level._handle_motion_at(pointer)
		if frame >= 101 and frame <= 121:
			pointer = origin + item.global_transform.basis_xform(Vector2(lerpf(160, -160, float(frame - 101) / 20.0), -50))
			level._handle_motion_at(pointer)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame % 2 == 0:
			var capture := root.get_texture().get_image()
			if capture == null or capture.save_png(output.path_join("frame_%03d.png" % frame)) != OK:
				push_error("Failed to save motion frame %d" % frame)
				quit(1)
				return
	if item.get_node("StickyBlockedFeedback").pose != Vector3.ZERO or level._blocked_item != null:
		push_error("Motion capture did not finish at rest")
		quit(1)
		return
	print("STICKY MOTION CAPTURE PASSED: 90 frames, tap / pull right / pull left / release")
	level.queue_free()
	await process_frame
	quit(0)
