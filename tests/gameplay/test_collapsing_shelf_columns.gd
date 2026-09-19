extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const BOARD_SCENE_PATH := "res://scenes/collapsing_shelf_board.tscn"
const SHELF_SCENE_PATH := "res://scenes/shelf.tscn"
const CELL_SCALE := 1.06
const CELL_SIZE := Vector2(224, 135) * CELL_SCALE
const CELL_STEP := Vector2(228.96, 144.902)

var _failures: Array[String] = []
var _shelf_scene: PackedScene


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Collapsing shelf column verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_shelf_scene = load(SHELF_SCENE_PATH) as PackedScene
	_check(_shelf_scene != null, "The standard shelf scene should load.")
	_check(load(BOARD_SCENE_PATH) is PackedScene, "The collapsing board scene should load.")
	if _shelf_scene == null or not load(BOARD_SCENE_PATH) is PackedScene:
		_finish()
		return

	_verify_cap_geometry_constant()
	_verify_construction_and_window()
	await _verify_removing_the_lowest_shelf()
	await _verify_removing_a_middle_shelf()
	await _verify_removing_the_top_visible_shelf_reveals_the_next()
	await _verify_multiple_removals_are_order_independent()
	await _verify_a_shelf_is_destroyed_at_most_once()
	await _verify_fixed_footprint_and_visible_count_resolution()
	await _verify_animated_collapse_blocks_and_restores()
	await _verify_settle_immediately_ends_a_running_collapse()
	_finish()


## Board fixture: columns of the given heights, every shelf registered bottom to top with its
## flat authored index as ID, exactly as `scripts/level.gd` consumes a `column_layout`.
func _make_board(column_heights: Array[int], visible_count: int) -> CollapsingShelfBoard:
	var board := (load(BOARD_SCENE_PATH) as PackedScene).instantiate() as CollapsingShelfBoard
	root.add_child(board)
	board.destroy_duration_seconds = 0.0
	board.shift_duration_seconds = 0.0
	board.configure(column_heights, visible_count, CELL_STEP, CELL_SIZE, CELL_SCALE)
	var authored_id := 0
	for column_index in range(column_heights.size()):
		for _stack_index in range(column_heights[column_index]):
			var shelf := _shelf_scene.instantiate() as Shelf
			shelf.name = "Shelf%02d" % (authored_id + 1)
			shelf.scale = Vector2.ONE * CELL_SCALE
			board.get_column_parent(column_index).add_child(shelf)
			board.register_shelf(column_index, authored_id, shelf)
			authored_id += 1
	board.settle_immediately()
	return board


func _ids(board: CollapsingShelfBoard, column_index: int) -> Array[int]:
	var ids: Array[int] = []
	for shelf in board.get_column(column_index).get_shelves():
		ids.append(board.get_authored_shelf_id(shelf))
	return ids


func _shelf_by_id(board: CollapsingShelfBoard, authored_id: int) -> Shelf:
	for shelf in board.get_all_shelves():
		if board.get_authored_shelf_id(shelf) == authored_id:
			return shelf as Shelf
	return null


func _row_y(stack_index: int) -> float:
	return -float(stack_index) * CELL_STEP.y


func _cap_visible(shelf: Shelf) -> bool:
	var placement := shelf.get_row_placement().capitalize()
	var cap := shelf.get_node_or_null("PlacementVisuals/%s/TopCeilingCap" % placement) as CanvasItem
	return cap != null and cap.visible


func _verify_cap_geometry_constant() -> void:
	var shelf := _shelf_scene.instantiate() as Shelf
	var back_board := shelf.get_node("PlacementVisuals/Middle/TopCeilingCap/BackBoard") as Polygon2D
	var top := INF
	for point in back_board.polygon:
		top = minf(top, point.y)
	_check(
		is_equal_approx(top, Shelf.TOP_CEILING_CAP_TOP_Y),
		"Shelf.TOP_CEILING_CAP_TOP_Y must match the cap art in scenes/shelf.tscn (found %s)." % top
	)
	shelf.free()


func _verify_construction_and_window() -> void:
	var board := _make_board([4, 2, 3], 3)
	_check(board.get_column_count() == 3, "The board should build one column per shelf count.")
	_check(_ids(board, 0) == [0, 1, 2, 3], "Column 1 should hold shelves 1-4 bottom to top.")
	_check(_ids(board, 1) == [4, 5], "Column 2 should hold shelves 5-6 bottom to top.")
	_check(_ids(board, 2) == [6, 7, 8], "Column 3 should hold shelves 7-9 bottom to top.")
	_check(board.get_remaining_shelf_count() == 9, "Every registered shelf should count as remaining.")
	_check(board.get_active_shelves().size() == 8, "Only min(window, height) shelves per column are active.")

	var hidden := _shelf_by_id(board, 3)
	_check(not board.is_shelf_active(hidden), "The fourth shelf of a three-shelf window must be inactive.")
	_check(not hidden.visible, "A shelf above the window must not render.")
	for authored_id in [0, 1, 2, 4, 5, 6, 7, 8]:
		var shelf := _shelf_by_id(board, authored_id)
		_check(board.is_shelf_active(shelf) and shelf.visible, "Shelf %s should be active and visible." % (authored_id + 1))

	for column_index in range(3):
		var shelves := board.get_column(column_index).get_shelves()
		for stack_index in range(shelves.size()):
			_check(
				is_equal_approx(shelves[stack_index].position.y, _row_y(stack_index)),
				"Column %s shelf %s should sit at its absolute row." % [column_index + 1, stack_index + 1]
			)

	_check(_shelf_by_id(board, 0).get_row_placement() == Shelf.ROW_PLACEMENT_LEFT, "Column 1 uses left art.")
	_check(_shelf_by_id(board, 4).get_row_placement() == Shelf.ROW_PLACEMENT_MIDDLE, "Column 2 uses middle art.")
	_check(_shelf_by_id(board, 6).get_row_placement() == Shelf.ROW_PLACEMENT_RIGHT, "Column 3 uses right art.")

	_check(_cap_visible(_shelf_by_id(board, 2)), "The window's top shelf carries the cap even with more above.")
	_check(not _cap_visible(_shelf_by_id(board, 1)), "A shelf with an active shelf above has no cap.")
	_check(_cap_visible(_shelf_by_id(board, 5)), "A short column's top shelf carries the cap.")

	var window := board.get_node("Window") as Control
	_check(window.clip_contents, "The board must clip shelves waiting above the window.")
	var top_row_cap := board.to_local(
		_shelf_by_id(board, 2).to_global(Vector2(0.0, Shelf.TOP_CEILING_CAP_TOP_Y))
	)
	_check(
		absf(window.position.y - top_row_cap.y) < 0.5,
		"The clip window must open exactly at the top row's ceiling cap."
	)
	board.free()


func _verify_removing_the_lowest_shelf() -> void:
	var board := _make_board([5], 3)
	var bottom := _shelf_by_id(board, 0)
	var result := await _collapse_now(board, [bottom])
	_check(result["removed_ids"] == [0], "Removing the bottom shelf reports its authored ID.")
	_check(not is_instance_valid(bottom) or not bottom.is_inside_tree(), "A destroyed shelf leaves the tree at once.")
	_check(_ids(board, 0) == [1, 2, 3, 4], "Every survivor keeps its order.")
	for stack_index in range(4):
		var shelf := board.get_column(0).get_shelves()[stack_index]
		_check(is_equal_approx(shelf.position.y, _row_y(stack_index)), "Survivor %s drops exactly one row." % stack_index)
	var revealed: Array = result["revealed"]
	_check(revealed.size() == 1 and revealed[0] == _shelf_by_id(board, 3), "Shelf 4 enters the window.")
	_check(board.is_shelf_active(_shelf_by_id(board, 3)), "A revealed shelf is active once settled.")
	_check(not board.is_shelf_active(_shelf_by_id(board, 4)), "Shelf 5 is still above the window.")
	board.free()


func _verify_removing_a_middle_shelf() -> void:
	var board := _make_board([4], 4)
	var below := _shelf_by_id(board, 0)
	var below_position := below.position
	var result := await _collapse_now(board, [_shelf_by_id(board, 1)])
	_check(result["removed_count"] == 1, "One middle shelf is removed.")
	_check(below.position == below_position, "A shelf below the removed one never moves.")
	_check(_ids(board, 0) == [0, 2, 3], "Shelves above the removed one close the gap in order.")
	_check(is_equal_approx(_shelf_by_id(board, 2).position.y, _row_y(1)), "The shelf above drops to row 2.")
	_check(is_equal_approx(_shelf_by_id(board, 3).position.y, _row_y(2)), "The top shelf drops to row 3.")
	_check((result["revealed"] as Array).is_empty(), "Nothing is revealed when nothing was hidden.")
	_check(_cap_visible(_shelf_by_id(board, 3)), "The new top shelf keeps the cap.")
	board.free()


func _verify_removing_the_top_visible_shelf_reveals_the_next() -> void:
	var board := _make_board([4], 2)
	var result := await _collapse_now(board, [_shelf_by_id(board, 1)])
	var revealed: Array = result["revealed"]
	_check(revealed.size() == 1 and revealed[0] == _shelf_by_id(board, 2), "Emptying the top visible shelf reveals shelf 3.")
	_check(_shelf_by_id(board, 2).visible and board.is_shelf_active(_shelf_by_id(board, 2)), "Shelf 3 is playable after settling.")
	_check(is_equal_approx(_shelf_by_id(board, 0).position.y, _row_y(0)), "The bottom shelf does not move.")
	_check(_cap_visible(_shelf_by_id(board, 2)), "The revealed shelf now carries the top cap.")
	_check(not _cap_visible(_shelf_by_id(board, 0)), "The shelf under it no longer does.")
	board.free()


func _verify_multiple_removals_are_order_independent() -> void:
	var forward := _make_board([6, 3], 3)
	var backward := _make_board([6, 3], 3)
	await _collapse_now(forward, [_shelf_by_id(forward, 0), _shelf_by_id(forward, 2), _shelf_by_id(forward, 7)])
	await _collapse_now(backward, [_shelf_by_id(backward, 7), _shelf_by_id(backward, 2), _shelf_by_id(backward, 0)])
	_check(_ids(forward, 0) == [1, 3, 4, 5], "Two removals from one column keep survivor order.")
	_check(_ids(forward, 0) == _ids(backward, 0), "Discovery order must not change the result.")
	_check(_ids(forward, 1) == [6, 8] and _ids(backward, 1) == [6, 8], "The second column settles identically.")
	for stack_index in range(4):
		_check(
			is_equal_approx(forward.get_column(0).get_shelves()[stack_index].position.y, _row_y(stack_index)),
			"Survivor %s lands on its exact row after a double removal." % stack_index
		)
	forward.free()
	backward.free()


func _verify_a_shelf_is_destroyed_at_most_once() -> void:
	var board := _make_board([3], 3)
	var shelf := _shelf_by_id(board, 1)
	var first := await _collapse_now(board, [shelf, shelf])
	_check(first["removed_count"] == 1, "Listing a shelf twice still destroys it once.")
	var second := await _collapse_now(board, [shelf])
	_check(second["removed_count"] == 0, "A destroyed shelf cannot be destroyed again.")
	_check(board.get_remaining_shelf_count() == 2, "Only one shelf is gone.")
	await _collapse_now(board, board.get_all_shelves())
	_check(board.is_cleared(), "The board is cleared once no shelf survives.")
	board.free()


func _verify_fixed_footprint_and_visible_count_resolution() -> void:
	var board := _make_board([8, 8, 8], 4)
	var bounds := board.get_layout_bounds()
	var expected_height := 3.0 * CELL_STEP.y + CELL_SIZE.y
	_check(is_equal_approx(bounds.size.y, expected_height), "The footprint is the four-row window, not the stack.")
	_check(is_equal_approx(bounds.size.x, 2.0 * CELL_STEP.x + CELL_SIZE.x), "The footprint spans three columns.")
	await _collapse_now(board, [_shelf_by_id(board, 0), _shelf_by_id(board, 8), _shelf_by_id(board, 16)])
	_check(board.get_layout_bounds() == bounds, "The footprint must not change as columns shrink.")

	# A narrow, tall play area has spare height at the width-limited scale: reveal more rows.
	var tall := board.resolve_visible_count(Vector2(700, 2000), 0.45, 1.5)
	_check(tall > 4 and tall <= CollapsingShelfBoard.MAX_VISIBLE_SHELVES_PER_COLUMN, "A tall screen reveals extra rows (got %s)." % tall)
	var width_scale := minf(700.0 / bounds.size.x, 1.5)
	_check(
		board.get_layout_bounds_for_visible_count(tall).size.y * width_scale <= 2000.0 + 0.01,
		"Extra rows must fit at the scale the authored minimum already uses."
	)
	# A height-limited play area keeps the authored minimum.
	_check(board.resolve_visible_count(Vector2(2000, 560), 0.45, 1.5) == 4, "A short screen keeps the authored minimum.")
	board.set_visible_count(99)
	_check(board.get_visible_count() == 8, "The window never exceeds the tallest column or the design cap.")
	board.set_visible_count(1)
	_check(board.get_visible_count() == 4, "The window never drops below the authored minimum.")
	board.free()

	var short := _make_board([3, 2], 5)
	_check(short.get_max_visible_count() == 5, "An authored minimum above the column heights is kept.")
	_check(
		is_equal_approx(short.get_layout_bounds().size.y, 2.0 * CELL_STEP.y + CELL_SIZE.y),
		"The footprint never includes rows no column can fill."
	)
	short.free()


func _verify_animated_collapse_blocks_and_restores() -> void:
	var board := _make_board([4, 4], 2)
	board.destroy_duration_seconds = 0.05
	board.shift_duration_seconds = 0.08
	var finished_count := [0]
	board.collapse_finished.connect(func(_result: Dictionary) -> void: finished_count[0] += 1)
	var entering := _shelf_by_id(board, 2)
	board.collapse_shelves([_shelf_by_id(board, 0), _shelf_by_id(board, 4)])
	_check(board.is_collapsing(), "The board reports a running collapse.")
	_check(board.get_active_shelves().is_empty(), "No shelf is playable while columns move.")
	_check(not board.is_shelf_active(_shelf_by_id(board, 1)), "Even an unaffected-looking survivor is blocked.")
	_check(not board.is_cleared(), "A running collapse is never read as a cleared board.")
	_check(entering.visible and entering.modulate.a < 1.0, "The revealed shelf fades in rather than flashing.")
	await board.collapse_finished
	await process_frame
	_check(not board.is_collapsing(), "The collapse ends.")
	_check(finished_count[0] == 1, "collapse_finished fires exactly once.")
	_check(board.get_active_shelves().size() == 4, "Both windows are full again.")
	_check(is_equal_approx(entering.position.y, _row_y(1)) and is_equal_approx(entering.modulate.a, 1.0), "The revealed shelf rests fully opaque on row 2.")
	board.free()


func _verify_settle_immediately_ends_a_running_collapse() -> void:
	var board := _make_board([3], 2)
	board.destroy_duration_seconds = 0.5
	board.shift_duration_seconds = 0.5
	var finished_count := [0]
	board.collapse_finished.connect(func(_result: Dictionary) -> void: finished_count[0] += 1)
	board.collapse_shelves([_shelf_by_id(board, 0)])
	_check(board.is_collapsing(), "The slow collapse is running.")
	board.settle_immediately()
	await process_frame
	_check(not board.is_collapsing(), "settle_immediately() ends the collapse at once.")
	_check(finished_count[0] == 1, "Cutting a collapse short still reports it exactly once.")
	_check(_ids(board, 0) == [1, 2], "The committed order survives the interruption.")
	_check(is_equal_approx(_shelf_by_id(board, 2).position.y, _row_y(1)), "Shelves land on their exact rows.")
	board.free()


func _collapse_now(board: CollapsingShelfBoard, shelves: Array) -> Dictionary:
	# Zero durations settle synchronously; awaiting simply returns the result.
	return await board.collapse_shelves(shelves)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Collapsing shelf column verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
