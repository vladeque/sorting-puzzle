class_name CollapsingShelfBoard
extends Node2D

## The board of a `collapsing_columns` level (`scenes/collapsing_shelf_board.tscn`).
##
## Owns the columns, the clip window they draw through, the resolved visible count, and the one
## coordinated collapse that removes emptied shelves. `scripts/level.gd` builds shelves through its
## usual factory, registers them here, asks which shelves are playable, and hands over the shelves
## it has found empty; it never reaches into a column's private order.
##
## The board keeps one footprint for the whole level: its size follows the resolved visible count,
## not the shelves left, so it never rescales or recenters as columns shrink. Above the window that
## footprint reserves a peek strip, where the next shelf of each column draws cut off, so a pile
## that continues past the top of the board reads as one instead of looking finished.

signal collapse_started
signal collapse_finished(result: Dictionary)
signal _columns_settled

const COLUMN_SCENE := preload("res://scenes/collapsing_shelf_column.tscn")
## Mirrors `MAX_VISIBLE_SHELVES_PER_COLUMN` in `scripts/tools/validate_level_solvable.py`: the
## deepest window this board is built to draw, and the ceiling on any authored minimum.
const MAX_VISIBLE_SHELVES_PER_COLUMN := 8
const WINDOW_NODE := "Window"
const BOTTOM_SHADOW_NODE := "BoardBottomShadow"
const RIGHT_SHADOW_NODE := "BoardRightShadow"
const FRAME_BOTTOM_Y := 46.0
const CAST_SHADOW_DEPTH := 16.0
const CAST_SHADOW_SKEW := 14.0

## Only the window's top edge clips anything: that is where shelves wait before they drop in. The
## other three edges sit this far out so items travelling between columns, or gathered by the
## hammer, are never cut off.
@export var window_outer_margin := 4096.0
## How far the clip window opens above the window's top row, as a share of one shelf row. The next
## shelf of every column draws into that strip, cut off by the clip edge, instead of being hidden
## outright. A peeking shelf is never playable -- the window alone decides that -- so this is
## presentation only. Set it to 0 to close the strip and end the pile at the top row's ceiling cap.
@export_range(0.0, 1.0, 0.01) var peek_reveal_ratio := 0.3:
	set(value):
		peek_reveal_ratio = clampf(value, 0.0, 1.0)
		# Before `configure()` there is no window node to lay out yet.
		if not _columns.is_empty():
			_peek_height = minf(_peek_height, get_max_peek_height())
			_layout_window()
@export_range(0.0, 1.0, 0.01) var destroy_duration_seconds := 0.18:
	set(value):
		destroy_duration_seconds = maxf(value, 0.0)
		_apply_column_durations()
@export_range(0.0, 1.0, 0.01) var shift_duration_seconds := 0.24:
	set(value):
		shift_duration_seconds = maxf(value, 0.0)
		_apply_column_durations()
@export_range(0.0, 0.25, 0.01) var shift_overlap_seconds := 0.04:
	set(value):
		shift_overlap_seconds = maxf(value, 0.0)
		_apply_column_durations()

var _columns: Array[CollapsingShelfColumn] = []
var _authored_column_heights: Array[int] = []
var _authored_visible_count := 1
var _visible_count := 1
var _shelf_step := Vector2.ZERO
var _cell_size := Vector2.ZERO
var _shelf_scale := 1.0
var _peek_height := 0.0
var _pending_columns: Array[CollapsingShelfColumn] = []
var _is_collapsing := false


## `column_heights` is the authored shelf count per column, left to right. `visible_count` is the
## authored guaranteed minimum window; `set_visible_count()` may later widen it for a taller screen.
func configure(
	column_heights: Array[int],
	visible_count: int,
	shelf_step: Vector2,
	cell_size: Vector2,
	shelf_scale := 1.0
) -> void:
	_clear_columns()
	_authored_column_heights = column_heights.duplicate()
	_authored_visible_count = clampi(visible_count, 1, MAX_VISIBLE_SHELVES_PER_COLUMN)
	_visible_count = _authored_visible_count
	_shelf_step = shelf_step
	_cell_size = cell_size
	_shelf_scale = shelf_scale
	# The strip reopens from the play area the level is about to fit this board into.
	_peek_height = 0.0

	var window := _get_window()
	for column_index in range(_authored_column_heights.size()):
		var column := COLUMN_SCENE.instantiate() as CollapsingShelfColumn
		column.name = "Column%02d" % (column_index + 1)
		window.add_child(column)
		column.configure(column_index, _visible_count, _shelf_step)
		column.collapse_settled.connect(_on_column_collapse_settled.bind(column))
		_columns.append(column)

	_apply_column_durations()
	_layout_window()


func get_column_count() -> int:
	return _columns.size()


func get_column(column_index: int) -> CollapsingShelfColumn:
	if column_index < 0 or column_index >= _columns.size():
		return null

	return _columns[column_index]


## Where the level parents a new shelf before registering it.
func get_column_parent(column_index: int) -> Node2D:
	return get_column(column_index)


## Registration order inside a column is bottom to top. Left/middle/right shelf art follows the
## column's position on the board, never how many shelves happen to survive in a row.
func register_shelf(column_index: int, authored_shelf_id: int, shelf: Shelf) -> void:
	var column := get_column(column_index)
	if column == null or shelf == null:
		push_error("Cannot register shelf %s in missing column %s." % [authored_shelf_id, column_index])
		return

	column.add_shelf(shelf, authored_shelf_id)
	shelf.set_row_placement(_get_column_row_placement(column_index))
	shelf.set_collapsing_visuals_enabled(true)


func get_authored_visible_count() -> int:
	return _authored_visible_count


func get_visible_count() -> int:
	return _visible_count


## The deepest window worth drawing: no taller than the tallest authored column, never below the
## authored minimum, never above the design cap.
func get_max_visible_count() -> int:
	return maxi(
		_authored_visible_count,
		mini(MAX_VISIBLE_SHELVES_PER_COLUMN, _get_tallest_authored_column())
	)


## Resolved once when the level is built. It is clamped so the authored minimum always holds, which
## is the window the solver proved the level against.
func set_visible_count(visible_count: int) -> void:
	_visible_count = clampi(visible_count, _authored_visible_count, get_max_visible_count())
	# A window that now holds the tallest column has nothing left to show above it.
	_peek_height = minf(_peek_height, get_max_peek_height())
	for column in _columns:
		column.set_visible_count(_visible_count)
	_layout_window()


## Largest window that fits `play_size` at the scale the authored minimum already needs. Extra rows
## only ever use spare height, so revealing more shelves never makes the board or its touch targets
## smaller than the authored minimum would have.
func resolve_visible_count(play_size: Vector2, min_scale: float, max_scale: float) -> int:
	var base_bounds := get_layout_bounds_for_visible_count(_authored_visible_count)
	if base_bounds.size.x <= 0.0 or base_bounds.size.y <= 0.0 or play_size.x <= 0.0 or play_size.y <= 0.0:
		return _authored_visible_count

	var fit_scale := clampf(
		minf(play_size.x / base_bounds.size.x, play_size.y / base_bounds.size.y),
		min_scale,
		max_scale
	)
	var visible_count := _authored_visible_count
	var limit := get_max_visible_count()
	while (
		visible_count < limit
		and get_layout_bounds_for_visible_count(visible_count + 1).size.y * fit_scale
			<= play_size.y + 0.01
	):
		visible_count += 1

	return visible_count


## The fixed footprint the level fits to the screen, in the board's parent space. Hidden stack depth
## never contributes, and neither do the shelves already destroyed.
func get_layout_bounds() -> Rect2:
	var local_bounds := get_layout_bounds_for_visible_count(_visible_count)
	return Rect2(position + local_bounds.position, local_bounds.size)


## Cell rectangles plus the top row's ceiling cap. Static boards fit cell rectangles alone and
## always leave spare height, but this board is sized to fill the play area, so a cap left out of the
## bounds would rise into the HUD clearance. The peek strip is deliberately absent: it is opened into
## the spare height this footprint leaves, never into the footprint itself. Row 0 is centered on the
## board origin's y.
func get_layout_bounds_for_visible_count(visible_count: int) -> Rect2:
	if _columns.is_empty():
		return Rect2()

	var rows := clampi(visible_count, 1, maxi(_get_tallest_authored_column(), 1))
	var width := float(_columns.size() - 1) * _shelf_step.x + _cell_size.x
	var top := -float(rows - 1) * _shelf_step.y - maxf(_get_cap_rise(), _cell_size.y * 0.5)
	var bottom := _cell_size.y * 0.5
	return Rect2(Vector2(-width * 0.5, top), Vector2(width, bottom - top))


## Deepest strip this board would open above the window, in board-local units. Zero once the window
## holds the tallest authored column, because no shelf could ever wait above it. Read from the
## authored heights, never from the shelves left, so the strip does not close mid-level.
func get_max_peek_height() -> float:
	if peek_reveal_ratio <= 0.0 or _get_tallest_authored_column() <= _visible_count:
		return 0.0

	return peek_reveal_ratio * _shelf_step.y


## How far the clip window actually opens above the window's top cap right now.
func get_peek_height() -> float:
	return _peek_height


## The strip is spare height and nothing else: `scripts/level.gd` passes the room left between the
## fitted footprint and the HUD clearance, in board-local units, and the board takes as much of it as
## `peek_reveal_ratio` allows. So the shelf peeking in never costs board scale, touch-target size, a
## playable row, or a pixel of the HUD's space -- on a screen with no room to spare the strip simply
## closes, and the shelf above still reads through the overlap every stacked pair already has.
func set_peek_height(available_height: float) -> void:
	var height := clampf(available_height, 0.0, get_max_peek_height())
	if is_equal_approx(height, _peek_height):
		return

	_peek_height = height
	_layout_window()


func owns_shelf(shelf: Node) -> bool:
	return shelf != null and _columns.has(shelf.get_parent())


## Playable right now: inside its column's window, finished arriving, and no collapse running.
func is_shelf_active(shelf: Node) -> bool:
	if _is_collapsing:
		return false

	var column := _get_shelf_column(shelf)
	return column != null and column.is_shelf_active(shelf)


func get_active_shelves() -> Array[Node]:
	var active: Array[Node] = []
	if _is_collapsing:
		return active

	for column in _columns:
		active.append_array(column.get_active_shelves())

	return active


## Every surviving shelf, hidden ones included, column by column and bottom to top.
func get_all_shelves() -> Array[Node]:
	var shelves: Array[Node] = []
	for column in _columns:
		shelves.append_array(column.get_shelves())

	return shelves


func get_column_index(shelf: Node) -> int:
	var column := _get_shelf_column(shelf)
	return -1 if column == null else column.column_index


func get_stack_index(shelf: Node) -> int:
	var column := _get_shelf_column(shelf)
	return -1 if column == null else column.get_stack_index(shelf)


func get_authored_shelf_id(shelf: Node) -> int:
	if shelf == null:
		return -1

	return int(shelf.get_meta(CollapsingShelfColumn.AUTHORED_ID_META, -1))


func get_remaining_shelf_count() -> int:
	var remaining := 0
	for column in _columns:
		remaining += column.get_shelf_count()

	return remaining


func get_remaining_shelf_counts() -> Array[int]:
	var counts: Array[int] = []
	for column in _columns:
		counts.append(column.get_shelf_count())

	return counts


## Shelf destruction is the objective, so the level is cleared when no shelf survives anywhere --
## not when the visible shelves happen to be empty.
func is_cleared() -> bool:
	return get_remaining_shelf_count() == 0 and not _is_collapsing


func is_collapsing() -> bool:
	return _is_collapsing


## Removes `shelves_to_remove` in one batch and returns once every affected column has settled.
## Each column commits its new order before anything moves; columns then animate in parallel.
## Result keys: `removed_ids` (authored IDs), `removed_count`, and `revealed` (shelves that entered
## the window, active again by the time this returns).
func collapse_shelves(shelves_to_remove: Array) -> Dictionary:
	var removed_ids: Array[int] = []
	var revealed: Array[Node] = []
	var result := {"removed_ids": removed_ids, "removed_count": 0, "revealed": revealed}
	if _is_collapsing:
		push_warning("A collapse is already running; the level must serialize collapses.")
		return result

	var affected: Array[CollapsingShelfColumn] = []
	for column in _columns:
		var column_result := column.remove_shelves(shelves_to_remove)
		var removed: Array = column_result["removed"]
		if removed.is_empty():
			continue

		affected.append(column)
		for shelf in removed:
			removed_ids.append(get_authored_shelf_id(shelf))
		revealed.append_array(column_result["revealed"])

	result["removed_count"] = removed_ids.size()
	if affected.is_empty():
		return result

	_is_collapsing = true
	collapse_started.emit()
	_pending_columns = affected.duplicate()
	for column in affected:
		column.start_collapse()

	if not _pending_columns.is_empty():
		await _columns_settled

	_is_collapsing = false
	var live_revealed: Array[Node] = []
	for shelf in revealed:
		if shelf != null and is_instance_valid(shelf):
			live_revealed.append(shelf)
	result["revealed"] = live_revealed
	collapse_finished.emit(result)
	return result


## Deterministic, animation-free completion of any running collapse, and a plain relayout
## otherwise. Used by setup, tests, and teardown.
func settle_immediately() -> void:
	for column in _columns:
		column.settle_immediately()


func _on_column_collapse_settled(column: CollapsingShelfColumn) -> void:
	if not _pending_columns.has(column):
		return

	_pending_columns.erase(column)
	if _pending_columns.is_empty():
		_columns_settled.emit()


func _get_shelf_column(shelf: Node) -> CollapsingShelfColumn:
	if shelf == null or not is_instance_valid(shelf):
		return null

	var column := shelf.get_parent() as CollapsingShelfColumn
	if column == null or not _columns.has(column) or not column.has_shelf(shelf):
		return null

	return column


func _get_column_row_placement(column_index: int) -> String:
	if _columns.size() <= 1:
		return Shelf.ROW_PLACEMENT_MIDDLE
	if column_index <= 0:
		return Shelf.ROW_PLACEMENT_LEFT
	if column_index >= _columns.size() - 1:
		return Shelf.ROW_PLACEMENT_RIGHT

	return Shelf.ROW_PLACEMENT_MIDDLE


## How far the shelf art rises above a row's center: the top of the ceiling cap.
func _get_cap_rise() -> float:
	return -Shelf.TOP_CEILING_CAP_TOP_Y * _shelf_scale


func _get_tallest_authored_column() -> int:
	var tallest := 0
	for column_height in _authored_column_heights:
		tallest = maxi(tallest, column_height)

	return tallest


## The window's top edge is the peek strip's ceiling: one strip above the top shelf row's cap, or the
## cap itself when no shelf can ever wait above. Everything past that edge -- the shelves still deep
## in the stack -- is clipped; the other edges are pushed far out.
func _layout_window() -> void:
	var window := _get_window()
	var footprint := get_layout_bounds_for_visible_count(_visible_count)
	_layout_board_shadows(footprint)
	var top_row := clampi(_visible_count, 1, maxi(_get_tallest_authored_column(), 1)) - 1
	var window_top := -float(top_row) * _shelf_step.y - _get_cap_rise() - get_peek_height()
	var window_rect := Rect2(
		Vector2(footprint.position.x - window_outer_margin, window_top),
		Vector2(
			footprint.size.x + window_outer_margin * 2.0,
			footprint.end.y - window_top + window_outer_margin
		)
	)
	window.position = window_rect.position
	window.size = window_rect.size

	# The strip and the row drawn into it are one decision: without the row the strip stays empty,
	# and without the strip that row would cover the window's top shelf instead of peeking over it.
	# The row is drawn even where the strip closes to nothing, because stacked shelf art overlaps by
	# more than the cap it replaces: the shelf above still shows through, just less of it.
	var peek_rows := 1 if peek_reveal_ratio > 0.0 else 0
	var column_count := _columns.size()
	for column in _columns:
		var column_x := (float(column.column_index) - float(column_count - 1) * 0.5) * _shelf_step.x
		column.position = Vector2(column_x, 0.0) - window_rect.position
		column.set_peek_row_count(peek_rows)


## The dense cabinet gets one background-independent exterior cast instead of allowing every
## shelf cell to stack its own translucent polygons at internal seams.
func _layout_board_shadows(footprint: Rect2) -> void:
	var bottom_shadow := get_node_or_null(BOTTOM_SHADOW_NODE) as Polygon2D
	var right_shadow := get_node_or_null(RIGHT_SHADOW_NODE) as Polygon2D
	if bottom_shadow == null or right_shadow == null or footprint.size == Vector2.ZERO:
		return

	var contact_bottom := FRAME_BOTTOM_Y * _shelf_scale
	var depth := CAST_SHADOW_DEPTH * _shelf_scale
	var skew := CAST_SHADOW_SKEW * _shelf_scale
	var left := footprint.position.x
	var right := footprint.end.x
	var top := footprint.position.y

	bottom_shadow.polygon = PackedVector2Array([
		Vector2(left, contact_bottom),
		Vector2(right, contact_bottom),
		Vector2(right + skew, contact_bottom + depth),
		Vector2(left + skew, contact_bottom + depth),
	])
	bottom_shadow.uv = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
	])
	right_shadow.polygon = PackedVector2Array([
		Vector2(right, top),
		Vector2(right, contact_bottom),
		Vector2(right + depth, contact_bottom + skew),
		Vector2(right + depth, top + skew),
	])
	right_shadow.uv = PackedVector2Array([
		Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0),
	])


func _apply_column_durations() -> void:
	for column in _columns:
		column.destroy_duration_seconds = destroy_duration_seconds
		column.shift_duration_seconds = shift_duration_seconds
		column.shift_overlap_seconds = shift_overlap_seconds


func _clear_columns() -> void:
	for column in _columns:
		if column != null and is_instance_valid(column):
			column.get_parent().remove_child(column)
			column.free()
	_columns.clear()
	_pending_columns.clear()
	_is_collapsing = false


func _get_window() -> Control:
	return get_node(WINDOW_NODE) as Control
