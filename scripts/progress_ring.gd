class_name ProgressRing
extends Control

const POINT_COUNT := 48
const START_ANGLE := -PI / 2.0

@export var ring_width := 6.0
@export var track_color := Color(0.4, 0.17, 0.22, 1.0)
@export var fill_color := Color(0.22, 0.77, 0.22, 1.0)

var _current := 0
var _total := 0
var _fraction := 0.0:
	set(value):
		_fraction = value
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func set_progress(current: int, total: int) -> void:
	_current = current
	_total = total
	_fraction = clampf(float(current) / float(total), 0.0, 1.0) if total > 0 else 0.0


func get_progress_current() -> int:
	return _current


func get_progress_total() -> int:
	return _total


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - ring_width * 0.5
	if radius <= 0.0:
		return

	draw_arc(center, radius, 0.0, TAU, POINT_COUNT, track_color, ring_width, true)
	if _fraction > 0.0:
		draw_arc(center, radius, START_ANGLE, START_ANGLE + TAU * _fraction, POINT_COUNT, fill_color, ring_width, true)
