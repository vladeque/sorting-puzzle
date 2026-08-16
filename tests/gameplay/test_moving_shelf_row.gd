extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const MOVING_ROW_SCENE_PATH := "res://scenes/moving_shelf_row.tscn"
const SHELF_SCENE_PATH := "res://scenes/shelf.tscn"
const CELL_SIZE := Vector2(237.44, 143.1)
const CELL_STEP := Vector2(228.96, 134.62)

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Moving-shelf-row verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
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

	row.free()
	_finish()


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
