@tool
extends Control
class_name ShopSignBracket

## Wrought-iron wall bracket the Main Menu Starter Bundle sign hangs from: a wall plate on this
## node's right edge, a horizontal bar ending in a ring on the left, and a curved brace with a
## scroll under the bar. It is drawn here rather than shipped as a raster so it stays crisp at every
## responsive scale. The chains and board that swing below the bar are drawn by ShopSignBoard.

@export var iron_color := Color(0.29, 0.212, 0.188, 1.0):
	set(value):
		iron_color = value
		queue_redraw()
@export var plate_color := Color(0.239, 0.173, 0.153, 1.0):
	set(value):
		plate_color = value
		queue_redraw()
@export var outline_color := Color(0.122, 0.082, 0.071, 1.0):
	set(value):
		outline_color = value
		queue_redraw()
@export var highlight_color := Color(0.541, 0.416, 0.369, 1.0):
	set(value):
		highlight_color = value
		queue_redraw()
## Centre line of the bar, in node-local pixels; the sign's chains hook on here.
@export var bar_y := 13.0:
	set(value):
		bar_y = value
		queue_redraw()
@export var bar_thickness := 6.0:
	set(value):
		bar_thickness = value
		queue_redraw()
@export var plate_width := 12.0:
	set(value):
		plate_width = value
		queue_redraw()
@export var plate_height := 58.0:
	set(value):
		plate_height = value
		queue_redraw()

const CURVE_STEPS := 18


func _notification(what: int) -> void:
	if what in [NOTIFICATION_LAYOUT_DIRECTION_CHANGED, NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_RESIZED]:
		queue_redraw()


func _draw() -> void:
	# Mirror only this node's drawn ironwork; the sign's text and children shape independently.
	if is_layout_rtl():
		draw_set_transform(Vector2(size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	var right := size.x
	var plate_left := right - plate_width

	# The brace runs from low on the wall plate up to the bar; the plate and bar cover its ends.
	var brace := _bezier(
		Vector2(right - 6.0, bar_y + 37.0),
		Vector2(right - 28.0, bar_y + 37.0),
		Vector2(right - 44.0, bar_y + 23.0),
		Vector2(right - 56.0, bar_y + 2.0)
	)
	_draw_iron_stroke(brace, 6.5, 3.5)

	# A small scroll tucked under the bar, between the brace and the wall.
	var scroll := _bezier(
		Vector2(right - 30.0, bar_y + 31.0),
		Vector2(right - 37.0, bar_y + 30.0),
		Vector2(right - 39.0, bar_y + 22.0),
		Vector2(right - 33.0, bar_y + 20.0)
	)
	scroll.append_array(_bezier(
		Vector2(right - 33.0, bar_y + 20.0),
		Vector2(right - 29.0, bar_y + 19.0),
		Vector2(right - 27.0, bar_y + 24.0),
		Vector2(right - 30.0, bar_y + 26.0)
	))
	_draw_iron_stroke(scroll, 4.5, 2.0)

	var plate := StyleBoxFlat.new()
	plate.bg_color = plate_color
	plate.border_color = outline_color
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(3)
	plate.anti_aliasing = true
	draw_style_box(plate, Rect2(plate_left, 0.0, plate_width, plate_height))
	for rivet_y in [8.0, plate_height - 8.0]:
		draw_circle(Vector2(plate_left + plate_width * 0.5, rivet_y), 1.8, highlight_color, true, -1.0, true)

	var bar_left := 8.0
	var bar_rect := Rect2(
		bar_left, bar_y - bar_thickness * 0.5, plate_left + 2.0 - bar_left, bar_thickness
	)
	var bar := StyleBoxFlat.new()
	bar.bg_color = iron_color
	bar.border_color = outline_color
	bar.set_border_width_all(1)
	bar.set_corner_radius_all(3)
	bar.anti_aliasing = true
	draw_style_box(bar, bar_rect)
	draw_line(
		Vector2(bar_rect.position.x + 3.0, bar_rect.position.y + 1.8),
		Vector2(bar_rect.end.x - 4.0, bar_rect.position.y + 1.8),
		highlight_color,
		1.5,
		true
	)

	var ring_center := Vector2(bar_left + 1.0, bar_y)
	draw_arc(ring_center, 5.0, 0.0, TAU, 28, outline_color, 4.0, true)
	draw_arc(ring_center, 5.0, 0.0, TAU, 28, iron_color, 2.0, true)


func _draw_iron_stroke(points: PackedVector2Array, outline_width: float, core_width: float) -> void:
	draw_polyline(points, outline_color, outline_width, true)
	for end_point in [points[0], points[points.size() - 1]]:
		draw_circle(end_point, outline_width * 0.5, outline_color, true, -1.0, true)
	draw_polyline(points, iron_color, core_width, true)
	for end_point in [points[0], points[points.size() - 1]]:
		draw_circle(end_point, core_width * 0.5, iron_color, true, -1.0, true)


func _bezier(start: Vector2, control_1: Vector2, control_2: Vector2, end: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(CURVE_STEPS + 1):
		points.append(start.bezier_interpolate(control_1, control_2, end, float(step) / CURVE_STEPS))
	return points
