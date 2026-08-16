extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const MOVING_ROW_SCENE_PATH := "res://scenes/moving_shelf_row.tscn"
const SHELF_SCENE_PATH := "res://scenes/shelf.tscn"
const LEVEL_SCENE_PATH := "res://level.tscn"
const PREVIEW_ARGUMENT := "--moving-shelf-motion-preview"
const LAYOUT_DIRECTORY := "res://scenes/layouts"
const CELL_SIZE := Vector2(237.44, 143.1)
const CELL_STEP := Vector2(228.96, 134.62)

var _failures: Array[String] = []


func _init() -> void:
	var preview_mode := OS.get_cmdline_user_args().has(PREVIEW_ARGUMENT)
	if not preview_mode and not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Moving-shelf-row verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	if OS.get_cmdline_user_args().has(PREVIEW_ARGUMENT):
		await _run_preview()
		return

	var row_scene := load(MOVING_ROW_SCENE_PATH) as PackedScene
	var shelf_scene := load(SHELF_SCENE_PATH) as PackedScene
	var row := row_scene.instantiate() as MovingShelfRow if row_scene != null else null
	var shelf := shelf_scene.instantiate() as Shelf if shelf_scene != null else null
	_check(row != null, "The moving shelf row scene should instantiate.")
	_check(shelf != null, "The standard shelf scene should instantiate.")
	if row == null or shelf == null:
		_finish()
		return

	row.configure(3, CELL_STEP, CELL_SIZE, MovingShelfRow.MOTION_HORIZONTAL_WRAP, 0.0, 1)
	row.add_child(shelf)
	row.add_shelf(shelf)

	var expected_width := CELL_SIZE.x - MovingShelfRow.SHELF_WIDTH_REDUCTION
	_check(
		is_equal_approx(row.shelf_cell_size.x, expected_width),
		"Moving shelves should use a cell that is exactly 15 px narrower."
	)
	_check(
		is_equal_approx(row.get_visible_size().x, CELL_STEP.x * 2.0 + expected_width),
		"The moving-row clipping window should follow the shortened shelf width."
	)
	_check(
		CELL_STEP.x > expected_width,
		"Shortened moving shelves should leave a visible gap instead of sharing an edge."
	)

	var expected_visual_scale := expected_width / CELL_SIZE.x
	for node_path in Shelf.HORIZONTAL_VISUAL_SCALE_NODES:
		var visual := shelf.get_node_or_null(node_path) as Node2D
		_check(visual != null, "%s should remain a moving-shelf visual node." % node_path)
		if visual != null and node_path != Shelf.FLOOR_FRONT_LIP_NODE:
			_check(
				is_equal_approx(visual.scale.x, expected_visual_scale),
				"%s should be shortened with the moving shelf body." % node_path
			)
		var polygon := visual as Polygon2D
		if polygon != null:
			_check(
				polygon.antialiased,
				"%s should antialias its moving outer edges." % node_path
			)

	var floor_surface := shelf.get_node_or_null(Shelf.FLOOR_SURFACE_NODE) as Polygon2D
	var floor_front_lip := shelf.get_node_or_null(Shelf.FLOOR_FRONT_LIP_NODE) as Polygon2D
	_check(floor_surface != null, "The moving shelf should keep its floor surface.")
	_check(floor_front_lip != null, "The moving shelf should keep its front lip.")
	if floor_surface != null and floor_front_lip != null:
		var surface_width := _get_polygon_width(floor_surface)
		var lip_width := _get_polygon_width(floor_front_lip)
		_check(
			is_equal_approx(surface_width, lip_width),
			"The moving shelf floor surface and front lip should finish at identical edges."
		)

	for slot_name in ["Slot01", "Slot02", "Slot03"]:
		var slot := shelf.get_node_or_null(slot_name) as Node2D
		_check(
			slot != null and is_equal_approx(slot.scale.x, 1.0),
			"%s and its item should keep their original proportions." % slot_name
		)

	row.speed_pixels_per_second = 60.0
	row.call("_physics_process", 1.0 / 60.0)
	_check(
		is_equal_approx(float(row.get("_motion_offset")), 1.0),
		"A fixed motion tick should advance the belt by speed multiplied by delta."
	)
	_check(
		is_equal_approx(float(row.call("_get_interpolated_motion_offset", 0.5)), 0.5),
		"Render motion should interpolate halfway between consecutive fixed-tick samples."
	)
	row.call("_layout_shelves", row.call("_get_interpolated_motion_offset", 0.5))
	_check(
		is_equal_approx(shelf.position.x, expected_width * 0.5 + 0.5),
		"The shelf should render at the interpolated subpixel position."
	)
	row.set_movement_paused(true)
	_check(
		is_equal_approx(
			float(row.get("_previous_motion_offset")),
			float(row.get("_motion_offset"))
		),
		"Pausing should collapse interpolation history so resume cannot jump."
	)
	_verify_authored_motion_speeds()

	row.free()
	_finish()


func _run_preview() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.size = Vector2i(720, 1280)
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level = level_scene.instantiate() if level_scene != null else null
	if level == null:
		push_error("The moving-shelf preview could not instantiate level.tscn.")
		quit(1)
		return

	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 8)
	level.set("_sound_effects_enabled", false)
	root.add_child(level)
	await create_timer(2.0).timeout
	level.queue_free()
	quit(0)


func _verify_authored_motion_speeds() -> void:
	for file_name in DirAccess.get_files_at(LAYOUT_DIRECTORY):
		if not file_name.ends_with(".tscn"):
			continue

		var scene_path := "%s/%s" % [LAYOUT_DIRECTORY, file_name]
		var packed_scene := load(scene_path) as PackedScene
		var layout := packed_scene.instantiate() if packed_scene != null else null
		_check(layout != null, "%s should remain loadable." % scene_path)
		if layout == null:
			continue

		for child in layout.get_children():
			var moving_row := child as ShelfLayoutRow
			if moving_row == null:
				continue
			_check(
				is_equal_approx(
					moving_row.speed_pixels_per_second,
					ShelfLayoutRow.DEFAULT_SMOOTH_SPEED
				),
				"%s/%s should use the smooth 60 px/s campaign cadence."
					% [file_name, child.name]
			)

		layout.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_polygon_width(polygon: Polygon2D) -> float:
	var points := polygon.polygon
	if points.is_empty():
		return 0.0

	var minimum_x := points[0].x
	var maximum_x := points[0].x
	for point in points:
		minimum_x = minf(minimum_x, point.x)
		maximum_x = maxf(maximum_x, point.x)

	return (maximum_x - minimum_x) * absf(polygon.scale.x)


func _finish() -> void:
	if _failures.is_empty():
		print("Moving shelf row verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
