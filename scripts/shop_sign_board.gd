@tool
extends Control
class_name ShopSignBoard

## Wooden board of the Main Menu Starter Bundle shop sign and the two chains it hangs from. The
## chains run from this node's top edge, where they hook onto ShopSignBracket's bar, down to the
## board, which fills the rest of the rect below `board_top`. The board is drawn here because its
## wood gradient and grain cannot be expressed by a StyleBoxFlat; the coin art, label, and discount
## tag on the board are scene children.

@export var board_top := 29.0:
	set(value):
		board_top = value
		queue_redraw()
## Distance of each chain from the board's left and right edges.
@export var chain_inset := 18.0:
	set(value):
		chain_inset = value
		queue_redraw()
@export var corner_radius := 14.0:
	set(value):
		corner_radius = value
		queue_redraw()
@export var wood_top_color := Color(0.839, 0.553, 0.322, 1.0):
	set(value):
		wood_top_color = value
		queue_redraw()
@export var wood_bottom_color := Color(0.702, 0.384, 0.184, 1.0):
	set(value):
		wood_bottom_color = value
		queue_redraw()
@export var grain_color := Color(0.369, 0.153, 0.086, 0.16):
	set(value):
		grain_color = value
		queue_redraw()
@export var grain_spacing := 14.5:
	set(value):
		grain_spacing = maxf(value, 4.0)
		queue_redraw()
@export var outline_color := Color(0.369, 0.153, 0.086, 1.0):
	set(value):
		outline_color = value
		queue_redraw()
@export var outline_width := 3:
	set(value):
		outline_width = value
		queue_redraw()
@export var shadow_color := Color(0.157, 0.059, 0.02, 0.45):
	set(value):
		shadow_color = value
		queue_redraw()
@export var chain_color := Color(0.122, 0.082, 0.071, 1.0):
	set(value):
		chain_color = value
		queue_redraw()
@export var chain_highlight_color := Color(0.541, 0.416, 0.369, 1.0):
	set(value):
		chain_highlight_color = value
		queue_redraw()
@export var hook_color := Color(0.29, 0.212, 0.188, 1.0):
	set(value):
		hook_color = value
		queue_redraw()

const CORNER_STEPS := 8


func _draw() -> void:
	_draw_chains()

	var board := Rect2(0.0, board_top, size.x, size.y - board_top)
	var base := StyleBoxFlat.new()
	base.bg_color = wood_bottom_color
	base.set_corner_radius_all(int(corner_radius))
	base.shadow_color = shadow_color
	base.shadow_size = 6
	base.shadow_offset = Vector2(0.0, 5.0)
	base.anti_aliasing = true
	draw_style_box(base, board)

	# Vertical wood gradient: per-vertex colors on a rounded-rect polygon interpolate linearly in y.
	var outline := _rounded_rect_points(board.grow(-1.0), corner_radius - 1.0)
	var colors := PackedColorArray()
	for point in outline:
		var weight := clampf((point.y - board.position.y) / board.size.y, 0.0, 1.0)
		colors.append(wood_top_color.lerp(wood_bottom_color, weight))
	draw_polygon(outline, colors)

	var inner_left := board.position.x + outline_width
	var inner_right := board.end.x - outline_width
	var grain_y := board.position.y + corner_radius
	while grain_y < board.end.y - corner_radius:
		draw_line(Vector2(inner_left, grain_y), Vector2(inner_right, grain_y), grain_color, 1.5)
		grain_y += grain_spacing

	draw_line(
		Vector2(board.position.x + corner_radius, board.position.y + outline_width + 1.0),
		Vector2(board.end.x - corner_radius, board.position.y + outline_width + 1.0),
		Color(1.0, 0.863, 0.706, 0.45),
		2.0,
		true
	)
	draw_line(
		Vector2(board.position.x + corner_radius, board.end.y - outline_width - 1.5),
		Vector2(board.end.x - corner_radius, board.end.y - outline_width - 1.5),
		Color(0.314, 0.118, 0.039, 0.3),
		3.0,
		true
	)

	var border := StyleBoxFlat.new()
	border.draw_center = false
	border.border_color = outline_color
	border.set_border_width_all(outline_width)
	border.set_corner_radius_all(int(corner_radius))
	border.anti_aliasing = true
	draw_style_box(border, board)


func _draw_chains() -> void:
	for chain_x in [chain_inset, size.x - chain_inset]:
		var top := Vector2(chain_x, 0.0)
		var bottom := Vector2(chain_x, board_top + 2.0)
		draw_dashed_line(top, bottom, chain_color, 4.0, 5.0, true, true)
		draw_dashed_line(top, bottom, chain_highlight_color, 1.6, 5.0, true, true)
		draw_circle(top, 3.8, chain_color, true, -1.0, true)
		draw_circle(top, 2.6, hook_color, true, -1.0, true)


func _rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - radius, rect.position.y + radius), -PI * 0.5],
		[Vector2(rect.end.x - radius, rect.end.y - radius), 0.0],
		[Vector2(rect.position.x + radius, rect.end.y - radius), PI * 0.5],
		[Vector2(rect.position.x + radius, rect.position.y + radius), PI],
	]
	for corner in corners:
		var center: Vector2 = corner[0]
		var start_angle: float = corner[1]
		for step in range(CORNER_STEPS + 1):
			var angle := start_angle + (PI * 0.5) * float(step) / CORNER_STEPS
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
