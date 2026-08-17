extends Control
class_name PencilIcon

## Small code-drawn pencil used by compact edit buttons.

@export var outline_color := Color(0.32, 0.1, 0.02, 1.0)
@export var body_color := Color(1.0, 0.98, 0.86, 1.0)
@export var band_color := Color(1.0, 0.78, 0.25, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var extent := minf(size.x, size.y)
	if extent <= 0.0:
		return
	var center := size * 0.5
	var direction := Vector2(1.0, -1.0).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var half_length := extent * 0.33
	var outline_half_width := extent * 0.115
	var body_half_width := extent * 0.075
	var tail := center - direction * half_length
	var tip_base := center + direction * half_length * 0.58
	var tip := center + direction * half_length * 1.25

	draw_colored_polygon(_shaft_polygon(tail, tip_base, normal, outline_half_width), outline_color)
	draw_colored_polygon(
		PackedVector2Array([
			tip_base - normal * outline_half_width,
			tip_base + normal * outline_half_width,
			tip,
		]),
		outline_color
	)
	draw_colored_polygon(_shaft_polygon(tail, tip_base, normal, body_half_width), body_color)
	draw_colored_polygon(
		PackedVector2Array([
			tip_base - normal * body_half_width,
			tip_base + normal * body_half_width,
			tip - direction * extent * 0.035,
		]),
		body_color
	)
	var band_center := tail + direction * extent * 0.1
	draw_line(
		band_center - normal * body_half_width,
		band_center + normal * body_half_width,
		band_color,
		maxf(extent * 0.055, 1.0),
		true
	)


func _shaft_polygon(
	start: Vector2,
	end: Vector2,
	normal: Vector2,
	half_width: float
) -> PackedVector2Array:
	return PackedVector2Array([
		start - normal * half_width,
		start + normal * half_width,
		end + normal * half_width,
		end - normal * half_width,
	])
