extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const BOARD_SCENE_PATH := "res://scenes/collapsing_shelf_board.tscn"
const SHELF_SCENE_PATH := "res://scenes/shelf.tscn"
const CELL_SCALE := 1.06
const CELL_SIZE := Vector2(224, 135) * CELL_SCALE
const CELL_STEP := Vector2(228.96, 144.902)
## Ceiling-cap rise above a row's center at the level's cell scale.
const CAP_RISE := -Shelf.TOP_CEILING_CAP_TOP_Y * CELL_SCALE

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

	await _verify_level_builds_columns_in_authored_order()
	await _verify_hidden_shelves_are_unreachable()
	await _verify_committed_move_collapse_chain()
	await _verify_middle_and_top_removal()
	await _verify_drags_never_destroy_their_origin()
	await _verify_hammer_batches_emptied_shelves()
	await _verify_shuffle_leaves_hidden_shelves_untouched()
	await _verify_highlight_uses_active_shelves_only()
	await _verify_input_and_abilities_blocked_during_collapse()
	await _verify_freezer_does_not_stop_collapse()
	await _verify_completion_waits_for_the_last_shelf()
	await _verify_retry_rebuilds_the_authored_board()
	await _verify_interruptions_during_collapse()
	await _verify_invalid_collapsing_configs_fail_closed()
	await _verify_responsive_windows()
	await _verify_classic_levels_are_unchanged()
	await _verify_preview_scene_builds_the_fixture()
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

	var peeking := _shelf_by_id(board, 3)
	_check(not board.is_shelf_active(peeking), "The fourth shelf of a three-shelf window must be inactive.")
	_check(peeking.visible, "The first shelf above the window peeks over it instead of vanishing.")
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

	_check(not _cap_visible(_shelf_by_id(board, 2)), "The window's top shelf drops its cap once a shelf peeks over it.")
	_check(_cap_visible(peeking), "The peeking shelf carries the cap, past the clip edge where it cannot cover the shelf below.")
	_check(not _cap_visible(_shelf_by_id(board, 1)), "A shelf with an active shelf above has no cap.")
	_check(_cap_visible(_shelf_by_id(board, 5)), "A column with nothing above the window keeps the cap on its top shelf.")

	var window := board.get_node("Window") as Control
	_check(window.clip_contents, "The board must clip shelves waiting above the window.")
	var top_row_cap := board.to_local(
		_shelf_by_id(board, 2).to_global(Vector2(0.0, Shelf.TOP_CEILING_CAP_TOP_Y))
	)
	_check(
		absf(window.position.y - top_row_cap.y) < 0.5,
		"Without spare height the clip window still opens exactly at the top row's ceiling cap."
	)
	var max_peek := board.get_max_peek_height()
	_check(max_peek > 0.0, "A board with shelves above its window has a strip to open.")
	board.set_peek_height(max_peek * 0.5)
	_check(is_equal_approx(board.get_peek_height(), max_peek * 0.5), "Half the spare height opens half the strip.")
	_check(
		absf(window.position.y - (top_row_cap.y - max_peek * 0.5)) < 0.5,
		"The clip window opens exactly that far above the cap."
	)
	board.set_peek_height(max_peek * 4.0)
	_check(is_equal_approx(board.get_peek_height(), max_peek), "The strip never opens deeper than peek_reveal_ratio allows.")
	_check(peeking.visible and not board.is_shelf_active(peeking), "An opened strip still does not make its shelf playable.")
	board.free()

	# One row peeks, however deep the stack: the strip is one shelf tall, not a second window.
	var deep := _make_board([8], 3)
	deep.set_peek_height(deep.get_max_peek_height())
	_check(_shelf_by_id(deep, 3).visible, "The first shelf above the window peeks over it.")
	for authored_id in [4, 5, 6, 7]:
		_check(not _shelf_by_id(deep, authored_id).visible, "Shelf %s stays out of sight." % (authored_id + 1))
	_check(deep.get_active_shelves().size() == 3, "Peeking never widens the playable window.")
	deep.free()

	# The escape hatch: no strip, and the pile ends at the window's cap as it did before.
	var capped := _make_board([4], 3)
	capped.peek_reveal_ratio = 0.0
	_check(is_equal_approx(capped.get_max_peek_height(), 0.0), "A zero ratio leaves no strip to open.")
	_check(not _shelf_by_id(capped, 3).visible, "A zero ratio hides every shelf above the window again.")
	_check(_cap_visible(_shelf_by_id(capped, 2)), "The window's top shelf carries the cap again.")
	capped.free()


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
	var expected_height := 3.0 * CELL_STEP.y + CAP_RISE + CELL_SIZE.y * 0.5
	_check(is_equal_approx(bounds.size.y, expected_height), "The footprint is the four-row window and its top cap, not the stack.")
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
		is_equal_approx(short.get_layout_bounds().size.y, 2.0 * CELL_STEP.y + CAP_RISE + CELL_SIZE.y * 0.5),
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
	var removed := _shelf_by_id(board, 0)
	board.collapse_shelves([removed, _shelf_by_id(board, 4)])
	_check(board.is_collapsing(), "The board reports a running collapse.")
	_check(board.get_active_shelves().is_empty(), "No shelf is playable while columns move.")
	_check(not board.is_shelf_active(_shelf_by_id(board, 1)), "Even an unaffected-looking survivor is blocked.")
	_check(not board.is_cleared(), "A running collapse is never read as a cleared board.")
	_check(
		entering.visible and is_equal_approx(entering.modulate.a, 1.0),
		"The revealed shelf stays opaque and enters physically through the clip window."
	)
	var effect := board.get_column(0).get_node_or_null(
		"ShelfDestructionEffect_%s" % board.get_authored_shelf_id(removed)
	)
	_check(effect != null, "An animated removal creates the reusable wood destruction effect.")
	await board.collapse_finished
	await process_frame
	_check(not board.is_collapsing(), "The collapse ends.")
	_check(finished_count[0] == 1, "collapse_finished fires exactly once.")
	_check(board.get_active_shelves().size() == 4, "Both windows are full again.")
	_check(is_equal_approx(entering.position.y, _row_y(1)) and is_equal_approx(entering.modulate.a, 1.0), "The revealed shelf rests fully opaque on row 2.")
	_check(
		board.get_column(0).find_children("ShelfDestructionEffect_*").is_empty(),
		"Destruction effects clean themselves up when the collapse settles."
	)
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


# --- Level integration -------------------------------------------------------------------------------

const LEVEL_SCENE_PATH := "res://level.tscn"
const RESPONSIVE_VIEWPORTS := [
	Vector2(540, 960), Vector2(720, 1280), Vector2(1080, 1920),
	Vector2(1080, 2400), Vector2(1200, 1600),
]
## Short letters keep fixtures readable; `_` is an empty slot.
const ITEM_IDS := {
	"a": "milk_carton",
	"b": "soda_bottle",
	"c": "soda_bottle_orange",
	"d": "soda_bottle_grape",
	"e": "soda_can_lime",
	"h": "soda_can_grape",
	"p": "soda_can_strawberry",
	"q": "soda_can_orange",
	"x": "juice_box_orange",
	"y": "juice_box_grape_tall",
	"z": "juice_box_apple",
}
const SETTLE_TIMEOUT_MSEC := 8000


func _shelf_config(slots: String) -> Dictionary:
	var layer: Array = []
	for letter in slots:
		layer.append(null if letter == "_" else ITEM_IDS[letter])
	return {"layers": [layer]}


func _collapsing_config(heights: Array, visible_count: int, shelves: Array) -> Dictionary:
	var shelf_configs: Array = []
	for slots in shelves:
		shelf_configs.append(_shelf_config(slots))
	return {
		"level": 1,
		"time_seconds": 300,
		"gameplay_mode": "collapsing_columns",
		"column_layout": {"shelf_counts": heights, "visible_shelves_per_column": visible_count},
		"shelves": shelf_configs,
	}


## Builds `level.tscn` on a config. The window is pinned to the authored minimum so a fixture's
## hidden shelves stay hidden whatever size the headless viewport is.
func _make_level(config: Dictionary, animated := false, settle := true) -> Node:
	var level := (load(LEVEL_SCENE_PATH) as PackedScene).instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 1)
	level.set("_sound_effects_enabled", false)
	level.set("hammer_haptics_enabled", false)
	level.set("item_move_duration_seconds", 0.0)
	level.set("match_gather_duration_seconds", 0.0)
	level.set("match_shrink_duration_seconds", 0.0)
	var column_layout: Dictionary = config.get("column_layout", {})
	level.set("max_collapsing_visible_shelves", int(column_layout.get("visible_shelves_per_column", 0)))
	root.add_child(level)
	await process_frame
	level.call("_apply_level_config", config)
	var board := _level_board(level)
	if board != null:
		_set_board_animation(board, animated)
	level.call("_collect_slots")
	if settle:
		await _settle(level)
	return level


func _set_board_animation(board: CollapsingShelfBoard, animated: bool) -> void:
	board.destroy_duration_seconds = 0.12 if animated else 0.0
	board.shift_duration_seconds = 0.2 if animated else 0.0


func _level_board(level: Node) -> CollapsingShelfBoard:
	return level.get_node_or_null("Shelves/CollapsingShelfBoard") as CollapsingShelfBoard


func _is_level_busy(level: Node) -> bool:
	return (
		bool(level.get("_is_resolving_shelves"))
		or bool(level.call("_is_collapse_in_progress"))
		or bool(level.get("_hammer_effect_active"))
		or bool(level.get("_shuffle_effect_active"))
		or not (level.get("_transitioning_item_ids") as Array).is_empty()
		or not (level.get("_clearing_item_ids") as Array).is_empty()
	)


## Waits until resolution, collapses, and ability effects have all been quiet for a few frames.
func _settle(level: Node) -> void:
	var deadline := Time.get_ticks_msec() + SETTLE_TIMEOUT_MSEC
	var calm_frames := 0
	while Time.get_ticks_msec() < deadline:
		calm_frames = 0 if _is_level_busy(level) else calm_frames + 1
		if calm_frames >= 3:
			return
		await process_frame
	_check(false, "The level should settle within %s ms." % SETTLE_TIMEOUT_MSEC)


func _wait_for_collapse_start(level: Node) -> bool:
	var deadline := Time.get_ticks_msec() + SETTLE_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if bool(level.call("_is_collapse_in_progress")):
			return true
		await process_frame
	return false


func _front_item(level: Node, shelf: Node, slot_index := 0) -> ShelfItem:
	return level.call("_get_slot_item", shelf.get_node("Slot%02d" % (slot_index + 1))) as ShelfItem


func _slot(shelf: Node, slot_index: int) -> Node2D:
	return shelf.get_node("Slot%02d" % (slot_index + 1)) as Node2D


func _shelf_item_ids(level: Node, shelf: Node) -> Array[String]:
	var ids: Array[String] = []
	for slot_index in range(3):
		var item := _front_item(level, shelf, slot_index)
		ids.append("" if item == null else String(item.item_id))
	return ids


func _is_on_active_shelf(level: Node, item: ShelfItem) -> bool:
	var board := _level_board(level)
	return board.is_shelf_active(level.call("_get_owning_shelf", item))


## Commits an ordinary move exactly as a tap or drop does.
func _move(level: Node, from_shelf: Node, from_slot: int, to_shelf: Node, to_slot: int) -> bool:
	var item := _front_item(level, from_shelf, from_slot)
	return bool(level.call("_move_item_to_slot", item, _slot(from_shelf, from_slot), _slot(to_shelf, to_slot)))


func _dispose(level: Node) -> void:
	level.queue_free()
	await process_frame
	await process_frame


func _verify_level_builds_columns_in_authored_order() -> void:
	var config := _collapsing_config([3, 2, 2], 2, ["a__", "b__", "c__", "d__", "e__", "x__", "y__"])
	var level := await _make_level(config)
	var board := _level_board(level)
	_check(board != null, "A collapsing level builds a CollapsingShelfBoard under Shelves.")
	if board == null:
		await _dispose(level)
		return
	_check(level.get_node("Shelves").get_child_count() == 1, "The board is the only board node; no grid fallback.")
	_check(board.get_column_count() == 3, "One column per shelf_counts entry.")
	_check(_ids(board, 0) == [0, 1, 2] and _ids(board, 1) == [3, 4] and _ids(board, 2) == [5, 6], "Flat shelves are consumed column by column, bottom to top.")
	_check(_shelf_item_ids(level, _shelf_by_id(board, 1))[0] == ITEM_IDS["b"], "Shelf 2 carries its authored items.")
	_check(_shelf_by_id(board, 1).name == "Shelf02", "Shelves keep the standard naming.")
	_check(board.get_visible_count() == 2, "The pinned window is the authored minimum.")
	_check(board.get_active_shelves().size() == 6, "Two active shelves per column.")
	_check(not _shelf_by_id(board, 2).visible and not board.is_shelf_active(_shelf_by_id(board, 2)), "Shelf 3 starts hidden.")
	var bounds: Rect2 = level.call("_get_shelves_local_bounds")
	_check(is_equal_approx(bounds.size.y, CELL_STEP.y + CAP_RISE + CELL_SIZE.y * 0.5), "Responsive fitting uses the two-row window and its cap, not the stack.")
	await _dispose(level)


func _verify_hidden_shelves_are_unreachable() -> void:
	var config := _collapsing_config([4, 2], 2, ["aa_", "b__", "ccc", "d__", "a__", "bb_"])
	var level := await _make_level(config)
	var board := _level_board(level)
	var hidden_triple := _shelf_by_id(board, 2)
	var hidden_open := _shelf_by_id(board, 3)
	var active_source := _shelf_by_id(board, 4)
	_check(board.get_remaining_shelf_count() == 6, "Nothing resolves at build.")
	_check((level.call("_get_shelf_items", hidden_triple) as Array).size() == 3, "A hidden authored triple does not auto-match.")
	_check(not bool(level.call("_is_shelf_move_source_eligible", hidden_triple)), "A hidden shelf is not a move source.")
	_check(not bool(level.call("_is_slot_drop_target_eligible", _slot(hidden_open, 1))), "A hidden slot is not a drop target.")
	for item in level.call("_get_visible_items") as Array:
		_check(_is_on_active_shelf(level, item), "Visible-item enumeration skips hidden shelves.")
	for item in level.call("_get_unlocked_items", true) as Array:
		_check(_is_on_active_shelf(level, item), "Ability item enumeration skips hidden shelves.")
	var hidden_item := _front_item(level, hidden_triple, 0)
	_check(level.call("_find_item_at_position", hidden_item.global_position, true) == null, "A hidden item cannot be picked.")
	_check(not hidden_item.input_pickable, "A hidden item is not input-pickable.")
	_check(
		not bool(level.call("_move_item_to_slot", hidden_item, _slot(hidden_triple, 0), _slot(active_source, 1))),
		"A direct move off a hidden shelf is rejected."
	)
	_check(not _move(level, active_source, 0, hidden_open, 1), "A direct move onto a hidden shelf is rejected.")
	_check(_front_item(level, active_source, 0) != null, "A rejected move leaves the item home.")
	var snap_target = level.call("_find_nearest_slot", _slot(hidden_open, 1).get_node("ItemSlot02").global_position)
	_check(snap_target == null or board.is_shelf_active(level.call("_get_owning_shelf", snap_target)), "Snap targeting never lands on a hidden slot.")
	for item in level.call("_find_immediate_triple_items") as Array:
		_check(_is_on_active_shelf(level, item), "Highlight candidates come from active shelves only.")
	for item in level.call("_find_hammer_targets", level.call("_get_visible_items", true)) as Array:
		_check(_is_on_active_shelf(level, item), "Hammer targets come from active shelves only.")
	await _dispose(level)


func _verify_committed_move_collapse_chain() -> void:
	var config := _collapsing_config([3, 3, 2], 2, ["a__", "bb_", "ccc", "aa_", "d__", "bd_", "de_", "ee_"])
	var level := await _make_level(config)
	var board := _level_board(level)
	var untouched_positions := [_shelf_by_id(board, 6).position, _shelf_by_id(board, 7).position]
	_check(_move(level, _shelf_by_id(board, 0), 0, _shelf_by_id(board, 3), 2), "The move is committed.")
	await _settle(level)
	# Shelf 4 completes its triple and is destroyed, shelf 1 is left empty and destroyed, and the
	# revealed shelf 3 is an authored triple that clears and collapses in turn.
	_check(_ids(board, 0) == [1], "Column 1 settles to shelf 2 after the reveal chain.")
	_check(_ids(board, 1) == [4, 5], "Column 2 drops shelves 5 and 6.")
	_check(_ids(board, 2) == [6, 7], "Column 3 is untouched.")
	_check(int(level.get("_triples_cleared")) == 2, "Both the committed and the revealed triple count.")
	_check(is_equal_approx(_shelf_by_id(board, 1).position.y, _row_y(0)), "Shelf 2 lands on row 1.")
	_check(is_equal_approx(_shelf_by_id(board, 4).position.y, _row_y(0)) and is_equal_approx(_shelf_by_id(board, 5).position.y, _row_y(1)), "Column 2 survivors drop exactly one row.")
	_check(board.is_shelf_active(_shelf_by_id(board, 5)), "The revealed shelf becomes playable.")
	_check(_shelf_by_id(board, 6).position == untouched_positions[0] and _shelf_by_id(board, 7).position == untouched_positions[1], "Unaffected columns never move.")
	var slots := level.get("_slots") as Array
	_check(slots.size() == 15, "Slot bookkeeping drops destroyed shelves.")
	for slot in slots:
		_check(is_instance_valid(slot) and (slot as Node).is_inside_tree(), "No slot of a destroyed shelf remains registered.")
	_check((level.get("_shelves_resolving_ids") as Array).is_empty(), "No resolver stays registered.")
	_check(_cap_visible(_shelf_by_id(board, 1)) and _cap_visible(_shelf_by_id(board, 5)) and not _cap_visible(_shelf_by_id(board, 4)), "Caps follow each column's new top shelf.")
	_check(not bool(level.get("_level_completed")), "Shelves remain, so the level is not complete.")
	await _dispose(level)


func _verify_middle_and_top_removal() -> void:
	var middle := await _make_level(_collapsing_config([4, 1], 3, ["x__", "a__", "y__", "z__", "aa_"]))
	var board := _level_board(middle)
	var below_position := _shelf_by_id(board, 0).position
	_move(middle, _shelf_by_id(board, 1), 0, _shelf_by_id(board, 4), 2)
	await _settle(middle)
	_check(_ids(board, 0) == [0, 2, 3], "Emptying a middle shelf removes only that shelf.")
	_check(_shelf_by_id(board, 0).position == below_position, "The shelf below a removed shelf stays exactly still.")
	_check(is_equal_approx(_shelf_by_id(board, 2).position.y, _row_y(1)) and is_equal_approx(_shelf_by_id(board, 3).position.y, _row_y(2)), "Shelves above drop one row.")
	_check(board.is_shelf_active(_shelf_by_id(board, 3)) and _shelf_by_id(board, 3).visible, "The next hidden shelf enters the window.")
	await _dispose(middle)

	var top := await _make_level(_collapsing_config([3, 1], 2, ["x__", "a__", "y__", "aa_"]))
	board = _level_board(top)
	below_position = _shelf_by_id(board, 0).position
	_move(top, _shelf_by_id(board, 1), 0, _shelf_by_id(board, 3), 2)
	await _settle(top)
	_check(_ids(board, 0) == [0, 2], "Emptying the top visible shelf removes it.")
	_check(board.is_shelf_active(_shelf_by_id(board, 2)), "The shelf above the window is revealed.")
	_check(_shelf_by_id(board, 0).position == below_position, "The bottom shelf does not move.")
	await _dispose(top)


func _verify_drags_never_destroy_their_origin() -> void:
	var level := await _make_level(_collapsing_config([2, 2], 2, ["a__", "b__", "c__", "d__"]))
	var board := _level_board(level)
	var origin := _shelf_by_id(board, 0)
	var item := _front_item(level, origin, 0)
	level.call("_begin_drag", item, item.global_position)
	_check(level.get("_dragged_item") == item, "The drag starts.")
	level.call("_on_shelf_resolution_drained")
	await _settle(level)
	_check(board.get_remaining_shelf_count() == 4, "A lifted item does not make its origin shelf empty.")
	level.call("_finish_active_drag", Vector2(-100000, -100000))
	await _settle(level)
	_check(_front_item(level, origin, 0) == item and board.get_remaining_shelf_count() == 4, "A cancelled drop restores the origin without destroying it.")
	_check(not bool(level.call("_move_item_to_slot", item, _slot(origin, 0), null)), "A rejected drop is refused.")
	_check(board.get_remaining_shelf_count() == 4, "A rejected drop destroys nothing.")

	# A collapse elsewhere mid-drag cancels the drag first, then destroys only the empty shelf.
	level.call("_begin_drag", item, item.global_position)
	var other := _shelf_by_id(board, 3)
	_front_item(level, other, 0).queue_free()
	await process_frame
	level.call("_on_shelf_resolution_drained")
	await _settle(level)
	_check(level.get("_dragged_item") == null, "A collapse cancels an active drag.")
	_check(_front_item(level, origin, 0) == item and board.get_remaining_shelf_count() == 3, "Only the genuinely empty shelf is destroyed.")
	await _dispose(level)


func _verify_hammer_batches_emptied_shelves() -> void:
	var level := await _make_level(_collapsing_config([3, 2], 2, ["h__", "h__", "ppp", "h__", "qq_"]))
	var board := _level_board(level)
	var results: Array[Dictionary] = []
	board.collapse_finished.connect(func(result: Dictionary) -> void: results.append(result))
	_check(bool(level.call("_apply_ability_from_button", &"hammer")), "Hammer applies.")
	await _settle(level)
	_check(results.size() == 2, "Hammer's three emptied shelves form one batch, and the revealed triple a second (got %s)." % results.size())
	if results.size() >= 1:
		var first: Array = (results[0]["removed_ids"] as Array).duplicate()
		first.sort()
		_check(first == [0, 1, 3], "The first batch removes shelves 1, 2 (same column) and 4 together.")
	_check(board.get_column(0).get_shelf_count() == 0 and _ids(board, 1) == [4], "Column 1 empties; column 2 keeps shelf 5.")
	_check(int(level.get("_triples_cleared")) == 2, "The hammer triple and the revealed triple both count.")
	await _dispose(level)


func _verify_shuffle_leaves_hidden_shelves_untouched() -> void:
	var level := await _make_level(_collapsing_config([3, 3], 1, ["ab_", "cd_", "ee_", "ba_", "dc_", "x__"]))
	var board := _level_board(level)
	var hidden_before := {}
	for authored_id in [1, 2, 4, 5]:
		hidden_before[authored_id] = _shelf_item_ids(level, _shelf_by_id(board, authored_id))
	_check(bool(level.call("_apply_ability_from_button", &"shuffle")), "Shuffle applies.")
	await _settle(level)
	for authored_id in hidden_before:
		_check(_shelf_item_ids(level, _shelf_by_id(board, authored_id)) == hidden_before[authored_id], "Shuffle leaves hidden shelf %s unchanged." % (authored_id + 1))
	for authored_id in [0, 3]:
		_check((level.call("_get_shelf_items", _shelf_by_id(board, authored_id)) as Array).size() == 2, "Shuffle keeps active shelf %s's occupancy." % (authored_id + 1))
	_check(board.get_remaining_shelf_count() == 6, "Shuffle itself removes no shelf.")
	await _dispose(level)


func _verify_highlight_uses_active_shelves_only() -> void:
	var blocked := await _make_level(_collapsing_config([2, 2, 2], 1, ["aa_", "ac_", "bb_", "bc_", "c__", "x__"]))
	var uses := int((blocked.get("_ability_uses") as Dictionary).get(&"highlight", 0))
	_check(not bool(blocked.call("_can_apply_ability", &"highlight")), "Hidden copies never make a highlight available.")
	_check(not bool(blocked.call("_apply_ability_from_button", &"highlight")), "A refused highlight does not apply.")
	_check(int((blocked.get("_ability_uses") as Dictionary).get(&"highlight", 0)) == uses, "A refused highlight costs nothing.")
	await _dispose(blocked)

	var level := await _make_level(_collapsing_config([2, 2, 2], 1, ["aa_", "bbb", "a__", "bb_", "c__", "cc_"]))
	var board := _level_board(level)
	_check(bool(level.call("_apply_ability_from_button", &"highlight")), "Highlight applies to a visible triple.")
	var highlighted := level.get("_highlighted_items") as Array
	_check(highlighted.size() == 3, "Highlight marks the three visible copies.")
	for item in highlighted:
		_check(_is_on_active_shelf(level, item), "Highlight never marks a hidden item.")
	_move(level, _shelf_by_id(board, 2), 0, _shelf_by_id(board, 0), 2)
	await _settle(level)
	for item in level.get("_highlighted_items") as Array:
		_check(is_instance_valid(item) and _is_on_active_shelf(level, item), "Highlight refreshes to active shelves after a collapse.")
	await _dispose(level)


func _verify_input_and_abilities_blocked_during_collapse() -> void:
	var level := await _make_level(_collapsing_config([3, 1], 2, ["a__", "x__", "y__", "aa_"]), true)
	var board := _level_board(level)
	var finished := [0]
	board.collapse_finished.connect(func(_result: Dictionary) -> void: finished[0] += 1)
	var bystander := _front_item(level, _shelf_by_id(board, 1), 0)
	var freezer_uses := int((level.get("_ability_uses") as Dictionary).get(&"freezer", 0))
	_move(level, _shelf_by_id(board, 0), 0, _shelf_by_id(board, 3), 2)
	_check(await _wait_for_collapse_start(level), "The move starts a collapse.")
	_check(not bool(level.call("_can_apply_ability", &"freezer")), "No ability may start during a collapse.")
	level.call("_on_ability_button_pressed", &"freezer")
	_check(int((level.get("_ability_uses") as Dictionary).get(&"freezer", 0)) == freezer_uses and not bool(level.call("_is_freezer_active")), "A blocked ability spends nothing.")
	var buttons := (level.get("_ability_bar") as Node).get("_buttons") as Dictionary
	_check((buttons[&"freezer"] as Button).disabled, "Ability buttons are disabled during a collapse.")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = bystander.global_position
	level.call("_input", touch)
	_check(level.get("_pressed_item") == null, "A press during a collapse is ignored.")
	level.call("_handle_press_at", bystander.global_position)
	_check(level.get("_pressed_item") == null, "Even a direct press cannot pick an item while columns move.")
	await _settle(level)
	_check(finished[0] == 1, "The collapse finishes exactly once.")
	_check(bool(level.call("_can_apply_ability", &"freezer")) and not (buttons[&"freezer"] as Button).disabled, "Abilities come back after the collapse.")
	level.call("_handle_press_at", bystander.global_position)
	level.call("_handle_release_at", bystander.global_position)
	_check(level.get("_selected_item") == bystander, "Input comes back after the collapse.")
	await _dispose(level)


func _verify_freezer_does_not_stop_collapse() -> void:
	var level := await _make_level(_collapsing_config([3, 1], 2, ["a__", "x__", "y__", "aa_"]), true)
	var board := _level_board(level)
	_check(bool(level.call("_apply_ability_from_button", &"freezer")), "Freezer applies.")
	var time_before := float(level.get("_time_remaining"))
	_move(level, _shelf_by_id(board, 0), 0, _shelf_by_id(board, 3), 2)
	_check(await _wait_for_collapse_start(level), "A collapse starts under Freezer.")
	await _settle(level)
	_check(bool(level.call("_is_freezer_active")), "Freezer is still running when the collapse ends.")
	_check(_ids(board, 0) == [1, 2], "Columns still move while frozen.")
	# The move's target resolves in the same request as its emptied origin. It must clear before any
	# collapse starts, or the collapse would make it unavailable and its triple would never resolve.
	_check(board.get_column(1).get_shelf_count() == 0 and int(level.get("_triples_cleared")) == 1, "The move's completed triple clears alongside the animated collapse.")
	_check(is_equal_approx(float(level.get("_time_remaining")), time_before), "Freezer still holds the countdown.")
	await _dispose(level)


func _verify_completion_waits_for_the_last_shelf() -> void:
	var level := await _make_level(_collapsing_config([2], 1, ["aaa", "bbb"]), true, false)
	var board := _level_board(level)
	var saw_empty_window := false
	var completed_cleanly := false
	var deadline := Time.get_ticks_msec() + SETTLE_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline and not bool(level.get("_level_completed")):
		if bool(level.call("_is_collapse_in_progress")) and (level.call("_get_visible_items") as Array).is_empty():
			saw_empty_window = true
			level.call("_check_level_completed")
			_check(not bool(level.get("_level_completed")), "An empty window over remaining shelves is not a win.")
		await process_frame
	if bool(level.get("_level_completed")):
		completed_cleanly = board.get_remaining_shelf_count() == 0 and not board.is_collapsing()
	_check(saw_empty_window, "The fixture passes through an empty window while a shelf waits above.")
	_check(bool(level.get("_level_completed")), "Destroying the last shelf completes the level.")
	_check(completed_cleanly, "Completion begins only after the final shelf's collapse has settled.")
	await _dispose(level)


func _verify_retry_rebuilds_the_authored_board() -> void:
	var config := _collapsing_config([3, 3, 2], 2, ["a__", "bb_", "ccc", "aa_", "d__", "bd_", "de_", "ee_"])
	var level := await _make_level(config)
	var board := _level_board(level)
	_move(level, _shelf_by_id(board, 0), 0, _shelf_by_id(board, 3), 2)
	await _settle(level)
	level.call("_apply_level_config", config)
	level.call("_collect_slots")
	await _settle(level)
	board = _level_board(level)
	_check(level.get_node("Shelves").get_child_count() == 1, "A rebuild leaves exactly one board.")
	_check(_ids(board, 0) == [0, 1, 2] and _ids(board, 1) == [3, 4, 5] and _ids(board, 2) == [6, 7], "The authored columns come back.")
	_check((level.call("_get_shelf_items", _shelf_by_id(board, 2)) as Array).size() == 3, "Hidden authored content comes back.")
	_check(not board.is_shelf_active(_shelf_by_id(board, 2)), "Hidden shelves start hidden again.")
	_check(int(level.get("_triples_cleared")) == 0 and is_equal_approx(float(level.get("_time_remaining")), 300.0), "Run state resets from config.")
	await _dispose(level)


func _verify_interruptions_during_collapse() -> void:
	var paused := await _make_level(_collapsing_config([3, 1], 2, ["a__", "x__", "y__", "aa_"]), true)
	var board := _level_board(paused)
	_move(paused, _shelf_by_id(board, 0), 0, _shelf_by_id(board, 3), 2)
	_check(await _wait_for_collapse_start(paused), "A collapse starts before pausing.")
	paused.call("_open_pause_menu")
	await _settle(paused)
	_check(_ids(board, 0) == [1, 2] and not board.is_collapsing(), "A collapse under the pause menu completes to the committed order.")
	paused.call("_close_pause_menu")
	_check(bool(paused.call("_can_apply_ability", &"freezer")), "Abilities are available after resuming.")
	await _dispose(paused)

	var interrupted := await _make_level(_collapsing_config([3, 1], 2, ["a__", "x__", "y__", "aa_"]), true)
	board = _level_board(interrupted)
	_move(interrupted, _shelf_by_id(board, 0), 0, _shelf_by_id(board, 3), 2)
	_check(await _wait_for_collapse_start(interrupted), "A collapse starts before backgrounding.")
	interrupted.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _settle(interrupted)
	interrupted.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(_ids(board, 0) == [1, 2] and not bool(interrupted.call("_is_collapse_in_progress")), "Backgrounding cannot leave a half-applied order or a stuck lock.")
	await _dispose(interrupted)

	var failed := await _make_level(_collapsing_config([1], 1, ["aaa"]), true, false)
	board = _level_board(failed)
	_check(await _wait_for_collapse_start(failed), "The authored triple clears and collapses.")
	failed.call("_fail_level")
	await _settle(failed)
	_check(board.get_remaining_shelf_count() == 0 and not bool(failed.get("_level_completed")), "A failed run is never completed by a late collapse.")
	await _dispose(failed)

	var torn_down := await _make_level(_collapsing_config([3, 1], 2, ["a__", "x__", "y__", "aa_"]), true)
	board = _level_board(torn_down)
	_move(torn_down, _shelf_by_id(board, 0), 0, _shelf_by_id(board, 3), 2)
	_check(await _wait_for_collapse_start(torn_down), "A collapse starts before teardown.")
	torn_down.queue_free()
	for _frame in range(10):
		await process_frame
	_check(not is_instance_valid(torn_down), "Tearing the level down mid-collapse frees it cleanly.")


func _verify_invalid_collapsing_configs_fail_closed() -> void:
	var level := await _make_level({"level": 1, "shelves": [_shelf_config("aa_"), _shelf_config("a__")]})
	var shelves_root := level.get_node("Shelves")
	var existing_children := shelves_root.get_child_count()
	var bad_configs := [
		_collapsing_config([2, 2], 1, ["a__", "b__", "c__"]),
		_collapsing_config([1], 0, ["a__"]),
		_collapsing_config([1], 1, ["___"]),
		_collapsing_config([2], 1, ["a__", "b__"]).merged({"layout_preset": "grid_3x3"}),
		{"level": 1, "gameplay_mode": "conveyor", "shelves": [_shelf_config("aaa")]},
		{"level": 1, "column_layout": {"shelf_counts": [1], "visible_shelves_per_column": 1}, "shelves": [_shelf_config("aaa")]},
	]
	var two_layers := _collapsing_config([1], 1, ["a__"])
	(two_layers["shelves"][0]["layers"] as Array).append([ITEM_IDS["b"], null, null])
	bad_configs.append(two_layers)
	for config in bad_configs:
		level.call("_apply_level_config", config)
		_check(not String(level.get("_level_config_error")).is_empty(), "Invalid config is reported: %s" % JSON.stringify(config))
		_check(_level_board(level) == null and shelves_root.get_child_count() == existing_children, "An invalid collapsing config builds nothing and never falls back to a grid.")
	await _dispose(level)


func _verify_responsive_windows() -> void:
	var shelves: Array = []
	for _index in range(24):
		shelves.append("ab_")
	var level := await _make_level(_collapsing_config([8, 8, 8], 4, shelves))
	var board := _level_board(level)
	var shelves_root := level.get_node("Shelves") as Node2D
	for viewport in RESPONSIVE_VIEWPORTS:
		var play_rect: Rect2 = level.call("_get_shelves_play_rect", viewport, Vector4.ZERO)
		var visible_count := board.resolve_visible_count(play_rect.size, 0.45, 1.5)
		_check(visible_count >= 4 and visible_count <= 8, "%s reveals at least the authored window (got %s)." % [viewport, visible_count])
		board.set_visible_count(4)
		level.call("_layout_shelves", viewport, Vector4.ZERO)
		var minimum_scale := float(level.get("_shelves_layout_scale"))
		board.set_visible_count(visible_count)
		level.call("_layout_shelves", viewport, Vector4.ZERO)
		var scale := float(level.get("_shelves_layout_scale"))
		_check(scale >= minimum_scale - 0.001, "%s: revealing more rows never shrinks the board." % viewport)
		var fitted := shelves_root.get_transform() * board.get_layout_bounds()
		_check(play_rect.grow(1.0).encloses(fitted), "%s: the window fits between the HUD and the ability bar." % viewport)
	await _dispose(level)


func _verify_classic_levels_are_unchanged() -> void:
	var config := {
		"level": 1,
		"row_layouts": [{"shelf_count": 2}],
		"shelves": [
			{"layers": [[ITEM_IDS["a"], ITEM_IDS["a"], null]]},
			{"layers": [[ITEM_IDS["a"], null, null], [ITEM_IDS["b"], ITEM_IDS["b"], ITEM_IDS["b"]]]},
		],
	}
	var level := await _make_level(config)
	_check(_level_board(level) == null, "A level without gameplay_mode builds no collapsing board.")
	var shelves := level.call("_get_all_shelves") as Array
	_move(level, shelves[1], 0, shelves[0], 2)
	await _settle(level)
	_check(int(level.get("_triples_cleared")) == 2, "Classic matching and layer promotion still clear both triples.")
	_check((level.call("_get_all_shelves") as Array).size() == 2, "Emptied classic shelves are never destroyed.")
	_check(bool(level.call("_is_shelf_drop_target_eligible", shelves[0])), "An emptied classic shelf stays a legal destination.")
	_check(bool(level.get("_level_completed")), "Classic levels still complete when every item is gone.")
	await _dispose(level)


## The debug preview is the touch-device check for this mode, so it must build the real fixture
## through the ordinary runtime.
func _verify_preview_scene_builds_the_fixture() -> void:
	var preview := (load("res://scenes/testing/collapsing_columns_preview.tscn") as PackedScene).instantiate()
	preview.set("_sound_effects_enabled", false)
	root.add_child(preview)
	await process_frame
	await process_frame
	var board := _level_board(preview)
	_check(String(preview.get("_level_config_error")).is_empty(), "The preview fixture passes runtime validation.")
	_check(board != null and board.get_remaining_shelf_count() == 30, "The preview builds the 30-shelf fixture board.")
	if board != null:
		_check(board.get_column_count() == 3 and board.get_visible_count() >= 4, "The preview opens three columns with at least the authored window.")
		_check(board.get_active_shelves().size() < board.get_remaining_shelf_count(), "The preview keeps shelves waiting above the window.")
	await _dispose(preview)


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
