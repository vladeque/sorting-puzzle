class_name MovingShelfRow
extends Control

const ROW_HEIGHT_PADDING := 50.88
const MOTION_HORIZONTAL_WRAP := "horizontal_wrap"
const MOTION_VERTICAL_WRAP := "vertical_wrap"

@export_range(1, 12, 1) var visible_shelf_count := 3
@export var shelf_cell_size := Vector2(237.44, 143.1)
@export var shelf_step := Vector2(228.96, 134.62)
@export_enum("horizontal_wrap", "vertical_wrap") var motion_type := MOTION_HORIZONTAL_WRAP
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
	row_shelf_step: Vector2,
	row_shelf_cell_size: Vector2,
	row_motion_type: String,
	row_speed_pixels_per_second: float,
	row_direction: int
) -> void:
	visible_shelf_count = maxi(row_visible_shelf_count, 1)
	shelf_step = Vector2(maxf(row_shelf_step.x, 1.0), maxf(row_shelf_step.y, 1.0))
	shelf_cell_size = row_shelf_cell_size
	motion_type = _normalize_motion_type(row_motion_type)
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
	if motion_type == MOTION_VERTICAL_WRAP:
		var height := float(maxi(visible_shelf_count, 1) - 1) * shelf_step.y + shelf_cell_size.y + ROW_HEIGHT_PADDING
		return Vector2(shelf_cell_size.x, height)

	var width := float(maxi(visible_shelf_count, 1) - 1) * shelf_step.x + shelf_cell_size.x
	return Vector2(width, shelf_cell_size.y + ROW_HEIGHT_PADDING)


func is_shelf_inside_visible_window(shelf: Node2D) -> bool:
	if shelf == null or not is_instance_valid(shelf):
		return false

	if shelf.get_parent() != self:
		return false

	if motion_type == MOTION_VERTICAL_WRAP:
		return shelf.position.y >= 0.0 and shelf.position.y <= size.y

	return shelf.position.x >= 0.0 and shelf.position.x <= size.x


func _process(delta: float) -> void:
	if _movement_paused or speed_pixels_per_second <= 0.0:
		return

	if _get_live_shelves().is_empty():
		return

	var cycle_length := _get_cycle_length()
	if cycle_length <= 0.0:
		return

	_motion_offset = fposmod(
		_motion_offset + speed_pixels_per_second * float(direction) * delta,
		cycle_length
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

	var cycle_length := _get_cycle_length()
	var row_center := size * 0.5
	for shelf_index in range(live_shelves.size()):
		var shelf := live_shelves[shelf_index]
		if motion_type == MOTION_VERTICAL_WRAP:
			var base_y := shelf_cell_size.y * 0.5 + float(shelf_index) * shelf_step.y
			var wrapped_y := fposmod(base_y + _motion_offset, cycle_length)
			if wrapped_y > size.y + shelf_cell_size.y * 0.5:
				wrapped_y -= cycle_length

			shelf.position = Vector2(row_center.x, wrapped_y)
		else:
			var base_x := shelf_cell_size.x * 0.5 + float(shelf_index) * shelf_step.x
			var wrapped_x := fposmod(base_x + _motion_offset, cycle_length)
			if wrapped_x > size.x + shelf_cell_size.x * 0.5:
				wrapped_x -= cycle_length

			shelf.position = Vector2(wrapped_x, row_center.y)


func _get_live_shelves() -> Array[Node2D]:
	for shelf_index in range(_shelves.size() - 1, -1, -1):
		var shelf := _shelves[shelf_index]
		if shelf == null or not is_instance_valid(shelf):
			_shelves.remove_at(shelf_index)

	return _shelves


func _get_cycle_length() -> float:
	if motion_type == MOTION_VERTICAL_WRAP:
		return maxf(float(maxi(_shelves.size(), visible_shelf_count)) * shelf_step.y, shelf_step.y)

	return maxf(float(maxi(_shelves.size(), visible_shelf_count)) * shelf_step.x, shelf_step.x)


func _normalize_motion_type(row_motion_type: String) -> String:
	var normalized_motion_type := row_motion_type.to_lower()
	if normalized_motion_type == MOTION_VERTICAL_WRAP:
		return MOTION_VERTICAL_WRAP

	return MOTION_HORIZONTAL_WRAP
