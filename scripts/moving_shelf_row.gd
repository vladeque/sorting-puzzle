class_name MovingShelfRow
extends Control

const ROW_HEIGHT_PADDING := 48.0

@export_range(1, 12, 1) var visible_shelf_count := 3
@export var shelf_cell_size := Vector2(224, 135)
@export var shelf_step_x := 216.0
@export var speed_pixels_per_second := 0.0
@export var direction := 1

var _motion_offset := 0.0
var _movement_paused := false
var _shelves: Array[Node2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_apply_visible_size()
	_layout_shelves()


func configure(
	row_visible_shelf_count: int,
	row_shelf_step_x: float,
	row_shelf_cell_size: Vector2,
	row_speed_pixels_per_second: float,
	row_direction: int
) -> void:
	visible_shelf_count = maxi(row_visible_shelf_count, 1)
	shelf_step_x = maxf(row_shelf_step_x, 1.0)
	shelf_cell_size = row_shelf_cell_size
	speed_pixels_per_second = maxf(row_speed_pixels_per_second, 0.0)
	direction = -1 if row_direction < 0 else 1
	_apply_visible_size()
	_layout_shelves()


func add_shelf(shelf: Node2D) -> void:
	if shelf == null:
		return

	if not _shelves.has(shelf):
		_shelves.append(shelf)

	_layout_shelves()


func set_movement_paused(should_pause: bool) -> void:
	_movement_paused = should_pause


func get_visible_size() -> Vector2:
	var width := float(maxi(visible_shelf_count, 1) - 1) * shelf_step_x + shelf_cell_size.x
	return Vector2(width, shelf_cell_size.y + ROW_HEIGHT_PADDING)


func is_shelf_inside_visible_window(shelf: Node2D) -> bool:
	if shelf == null or not is_instance_valid(shelf):
		return false

	if shelf.get_parent() != self:
		return false

	return shelf.position.x >= 0.0 and shelf.position.x <= size.x


func _process(delta: float) -> void:
	if _movement_paused or speed_pixels_per_second <= 0.0:
		return

	if _get_live_shelves().is_empty():
		return

	var cycle_width := _get_cycle_width()
	if cycle_width <= 0.0:
		return

	_motion_offset = fposmod(
		_motion_offset + speed_pixels_per_second * float(direction) * delta,
		cycle_width
	)
	_layout_shelves()


func _apply_visible_size() -> void:
	var visible_size := get_visible_size()
	custom_minimum_size = visible_size
	size = visible_size


func _layout_shelves() -> void:
	var live_shelves := _get_live_shelves()
	if live_shelves.is_empty():
		return

	var cycle_width := _get_cycle_width()
	var row_center_y := size.y * 0.5
	for shelf_index in range(live_shelves.size()):
		var shelf := live_shelves[shelf_index]
		var base_x := shelf_cell_size.x * 0.5 + float(shelf_index) * shelf_step_x
		var wrapped_x := fposmod(base_x + _motion_offset, cycle_width)
		if wrapped_x > size.x + shelf_cell_size.x * 0.5:
			wrapped_x -= cycle_width

		shelf.position = Vector2(wrapped_x, row_center_y)


func _get_live_shelves() -> Array[Node2D]:
	for shelf_index in range(_shelves.size() - 1, -1, -1):
		var shelf := _shelves[shelf_index]
		if shelf == null or not is_instance_valid(shelf):
			_shelves.remove_at(shelf_index)

	return _shelves


func _get_cycle_width() -> float:
	return maxf(float(maxi(_shelves.size(), visible_shelf_count)) * shelf_step_x, shelf_step_x)
