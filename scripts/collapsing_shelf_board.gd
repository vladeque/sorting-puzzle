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
## not the shelves left, so it never rescales or recenters as columns shrink.

signal collapse_started
signal collapse_finished(result: Dictionary)
signal _columns_settled

const COLUMN_SCENE := preload("res://scenes/collapsing_shelf_column.tscn")
## Mirrors `MAX_VISIBLE_SHELVES_PER_COLUMN` in `scripts/tools/validate_level_solvable.py`: the
## deepest window this board is built to draw, and the ceiling on any authored minimum.
const MAX_VISIBLE_SHELVES_PER_COLUMN := 8
const WINDOW_NODE := "Window"

## Only the window's top edge clips anything: that is where shelves wait before they drop in. The
## other three edges sit this far out so items travelling between columns, or gathered by the
## hammer, are never cut off.
@export var window_outer_margin := 4096.0
@export_range(0.0, 1.0, 0.01) var destroy_duration_seconds := 0.14:
	set(value):
		destroy_duration_seconds = maxf(value, 0.0)
		_apply_column_durations()
@export_range(0.0, 1.0, 0.01) var shift_duration_seconds := 0.24:
	set(value):
		shift_duration_seconds = maxf(value, 0.0)
		_apply_column_durations()

var _columns: Array[CollapsingShelfColumn] = []
var _authored_column_heights: Array[int] = []
var _authored_visible_count := 1
var _visible_count := 1
var _shelf_step := Vector2.ZERO
var _cell_size := Vector2.ZERO
var _shelf_scale := 1.0
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
## bounds would rise into the HUD clearance. Row 0 is centered on the board origin's y.
func get_layout_bounds_for_visible_count(visible_count: int) -> Rect2:
	if _columns.is_empty():
		return Rect2()

	var rows := clampi(visible_count, 1, maxi(_get_tallest_authored_column(), 1))
	var width := float(_columns.size() - 1) * _shelf_step.x + _cell_size.x
	var top := -float(rows - 1) * _shelf_step.y - maxf(_get_cap_rise(), _cell_size.y * 0.5)
	var bottom := _cell_size.y * 0.5
	return Rect2(Vector2(-width * 0.5, top), Vector2(width, bottom - top))


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


## The window's top edge is the top shelf row's ceiling cap. Everything above it -- shelves waiting
## to drop in -- is clipped; the other edges are pushed far out.
func _layout_window() -> void:
	var window := _get_window()
	var footprint := get_layout_bounds_for_visible_count(_visible_count)
	var top_row := clampi(_visible_count, 1, maxi(_get_tallest_authored_column(), 1)) - 1
	var window_top := -float(top_row) * _shelf_step.y - _get_cap_rise()
	var window_rect := Rect2(
		Vector2(footprint.position.x - window_outer_margin, window_top),
		Vector2(
			footprint.size.x + window_outer_margin * 2.0,
			footprint.end.y - window_top + window_outer_margin
		)
	)
	window.position = window_rect.position
	window.size = window_rect.size

	var column_count := _columns.size()
	for column in _columns:
		var column_x := (float(column.column_index) - float(column_count - 1) * 0.5) * _shelf_step.x
		column.position = Vector2(column_x, 0.0) - window_rect.position


func _apply_column_durations() -> void:
	for column in _columns:
		column.destroy_duration_seconds = destroy_duration_seconds
		column.shift_duration_seconds = shift_duration_seconds


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
