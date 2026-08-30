class_name MovingShelfRow
extends Control

const ROW_HEIGHT_PADDING := 50.88
const SHELF_WIDTH_REDUCTION := 15.0
const WINDOW_EDGE_EPSILON := 0.1
const MOTION_HORIZONTAL_WRAP := "horizontal_wrap"
const MOTION_VERTICAL_WRAP := "vertical_wrap"

@export_range(1, 12, 1) var visible_shelf_count := 3
@export var shelf_cell_size := Vector2(237.44, 143.1)
@export var shelf_step := Vector2(228.96, 144.902)
@export_enum("horizontal_wrap", "vertical_wrap") var motion_type := MOTION_HORIZONTAL_WRAP
@export var speed_pixels_per_second := 0.0
@export var direction := 1

var _motion_offset := 0.0
var _previous_motion_offset := 0.0
var _movement_paused := false
var _shelves: Array[Node2D] = []
var _shelf_horizontal_visual_scale := 1.0
var _layout_center := Vector2.ZERO
var _travel_length := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_apply_visible_size()
	_layout_shelves()


func configure(
	row_visible_shelf_count: int,
	row_shelf_step: Vector2,
	row_shelf_cell_size: Vector2,
	row_motion_type: String,
	row_speed_pixels_per_second: float,
	row_direction: int,
	row_layout_center := Vector2.ZERO
) -> void:
	visible_shelf_count = maxi(row_visible_shelf_count, 1)
	shelf_step = Vector2(maxf(row_shelf_step.x, 1.0), maxf(row_shelf_step.y, 1.0))
	shelf_cell_size = Vector2(
		maxf(row_shelf_cell_size.x - SHELF_WIDTH_REDUCTION, 1.0),
		row_shelf_cell_size.y
	)
	_shelf_horizontal_visual_scale = shelf_cell_size.x / maxf(row_shelf_cell_size.x, 1.0)
	motion_type = _normalize_motion_type(row_motion_type)
	speed_pixels_per_second = maxf(row_speed_pixels_per_second, 0.0)
	direction = -1 if row_direction < 0 else 1
	_layout_center = row_layout_center
	_travel_length = 0.0
	position = get_layout_bounds().position
	_previous_motion_offset = _motion_offset
	_apply_visible_size()
	_layout_shelves()


func add_shelf(shelf: Node2D) -> void:
	if shelf == null:
		return

	if not _shelves.has(shelf):
		_shelves.append(shelf)
		if shelf.has_method("set_horizontal_visual_scale"):
			shelf.call("set_horizontal_visual_scale", _shelf_horizontal_visual_scale)

	_layout_shelves()


func set_movement_paused(should_pause: bool) -> void:
	_movement_paused = should_pause
	# Collapse the interpolation pair at pause boundaries so resuming never blends from a stale tick.
	_previous_motion_offset = _motion_offset
	_layout_shelves(_motion_offset)


## Keep authored bounds separate from the expanded travel window so repeated responsive layout
## passes fit the same board instead of shrinking it to fit the previous viewport's belt length.
func get_layout_bounds() -> Rect2:
	var authored_size := _get_authored_visible_size()
	return Rect2(_layout_center - authored_size * 0.5, authored_size)


## The level supplies the playable background in the shelf root's local coordinates, after fitting
## the board. Only the motion axis expands; the authored lane and shelf spacing stay unchanged.
func set_play_area(play_area: Rect2) -> void:
	position = get_layout_bounds().position
	if motion_type == MOTION_VERTICAL_WRAP:
		position.y = play_area.position.y
		_travel_length = maxf(play_area.size.y, 1.0)
	else:
		position.x = play_area.position.x
		_travel_length = maxf(play_area.size.x, 1.0)
	_apply_visible_size()
	_layout_shelves()


func get_visible_size() -> Vector2:
	var visible_size := _get_authored_visible_size()
	if _travel_length > 0.0:
		if motion_type == MOTION_VERTICAL_WRAP:
			visible_size.y = _travel_length
		else:
			visible_size.x = _travel_length
	return visible_size


## Standalone rows use their configured cell count. Cross-axis padding leaves room for shadows.
func _get_authored_visible_size() -> Vector2:
	if motion_type == MOTION_VERTICAL_WRAP:
		# Whole steps rather than cells plus gaps: cells overlap by their shared edge, so a window
		# ending at the last cell's own bottom edge would also expose the top sliver of the shelf
		# after it -- which, stacked vertically, shows as item tips floating under the row. Ending it
		# where the next cell begins clips only the empty band the next shelf would have overlapped.
		var height := float(maxi(visible_shelf_count, 1)) * shelf_step.y
		return Vector2(shelf_cell_size.x + ROW_HEIGHT_PADDING, height)

	var width := float(maxi(visible_shelf_count, 1) - 1) * shelf_step.x + shelf_cell_size.x
	return Vector2(width, shelf_cell_size.y + ROW_HEIGHT_PADDING)


func is_shelf_inside_visible_window(shelf: Node2D) -> bool:
	if shelf == null or not is_instance_valid(shelf):
		return false

	if shelf.get_parent() != self:
		return false

	# The trailing/leading item can still be visible after the shelf center crosses the edge.
	# Match rendering here; the level clips individual item picks and slot targets to the window.
	return shelf.visible and _is_shelf_cell_touching_window(shelf.position, get_visible_size())


func get_visible_global_rect() -> Rect2:
	return get_global_transform() * Rect2(Vector2.ZERO, get_visible_size())


## Advance the authoritative belt offset on fixed ticks. Rendering interpolates between these two
## samples in `_process()`, avoiding uneven visible steps when the display refresh rate and physics
## tick do not line up.
func _physics_process(delta: float) -> void:
	if _movement_paused or speed_pixels_per_second <= 0.0:
		return

	if _get_live_shelves().is_empty():
		return

	var cycle_length := _get_cycle_length()
	if cycle_length <= 0.0:
		return

	_previous_motion_offset = _motion_offset
	_motion_offset += speed_pixels_per_second * float(direction) * delta


func _process(_delta: float) -> void:
	if _movement_paused or speed_pixels_per_second <= 0.0:
		return

	if _get_live_shelves().is_empty() or _get_cycle_length() <= 0.0:
		return

	_layout_shelves(_get_interpolated_motion_offset(Engine.get_physics_interpolation_fraction()))


func _apply_visible_size() -> void:
	var visible_size := get_visible_size()
	custom_minimum_size = visible_size
	size = visible_size


func _layout_shelves(rendered_motion_offset := _motion_offset) -> void:
	var live_shelves := _get_live_shelves()
	if live_shelves.is_empty():
		return

	var cycle_length := _get_cycle_length()
	# Laid out against the configured window rather than `size`: shelves are added before the Control
	# has resolved its own size, and a row that never moves -- paused, or authored at zero speed --
	# never lays out again to correct itself.
	var visible_size := get_visible_size()
	var row_center := visible_size * 0.5
	for shelf_index in range(live_shelves.size()):
		var shelf := live_shelves[shelf_index]
		if motion_type == MOTION_VERTICAL_WRAP:
			var base_y := shelf_cell_size.y * 0.5 + float(shelf_index) * shelf_step.y
			var half_height := shelf_cell_size.y * 0.5
			var wrapped_y := (
				fposmod(base_y + rendered_motion_offset + half_height, cycle_length) - half_height
			)

			shelf.position = Vector2(row_center.x, wrapped_y)
		else:
			var base_x := shelf_cell_size.x * 0.5 + float(shelf_index) * shelf_step.x
			var half_width := shelf_cell_size.x * 0.5
			var wrapped_x := (
				fposmod(base_x + rendered_motion_offset + half_width, cycle_length) - half_width
			)

			shelf.position = Vector2(wrapped_x, row_center.y)

		shelf.visible = _is_shelf_cell_touching_window(shelf.position, visible_size)


func _get_interpolated_motion_offset(interpolation_fraction: float) -> float:
	return lerpf(
		_previous_motion_offset,
		_motion_offset,
		clampf(interpolation_fraction, 0.0, 1.0)
	)


## Items stand taller than the cell they sit on, so a shelf parked just outside the window still
## paints the tips of its items inside it. Clipping alone cannot tell those tips apart from a shelf
## sliding in; the cell rectangle can, and a shelf whose cell has fully left the window has nothing
## left to show.
##
## `WINDOW_EDGE_EPSILON` decides the flush case. A row at rest parks the next shelf exactly at the
## window edge, and `Vector2` keeps positions at float precision, so an exact comparison there is
## decided by rounding: the shelf reads as a hair inside and paints its item tips just past the row.
func _is_shelf_cell_touching_window(shelf_position: Vector2, visible_size: Vector2) -> bool:
	if motion_type == MOTION_VERTICAL_WRAP:
		var cell_half_height := shelf_cell_size.y * 0.5
		return (
			shelf_position.y + cell_half_height > WINDOW_EDGE_EPSILON
			and shelf_position.y - cell_half_height < visible_size.y - WINDOW_EDGE_EPSILON
		)

	var cell_half_width := shelf_cell_size.x * 0.5
	return (
		shelf_position.x + cell_half_width > WINDOW_EDGE_EPSILON
		and shelf_position.x - cell_half_width < visible_size.x - WINDOW_EDGE_EPSILON
	)


func _get_live_shelves() -> Array[Node2D]:
	for shelf_index in range(_shelves.size() - 1, -1, -1):
		var shelf := _shelves[shelf_index]
		if shelf == null or not is_instance_valid(shelf):
			_shelves.remove_at(shelf_index)

	return _shelves


func _get_cycle_length() -> float:
	# Even a belt with fewer shelves than fit on screen must fully leave the window before wrapping.
	# Keep the authored spacing and real shelf count; extend the empty part of the loop if needed.
	var visible_size := get_visible_size()
	var axis := 1 if motion_type == MOTION_VERTICAL_WRAP else 0
	return maxf(
		float(maxi(_shelves.size(), visible_shelf_count)) * shelf_step[axis],
		visible_size[axis] + shelf_cell_size[axis]
	)


func _normalize_motion_type(row_motion_type: String) -> String:
	var normalized_motion_type := row_motion_type.to_lower()
	if normalized_motion_type == MOTION_VERTICAL_WRAP:
		return MOTION_VERTICAL_WRAP

	return MOTION_HORIZONTAL_WRAP
