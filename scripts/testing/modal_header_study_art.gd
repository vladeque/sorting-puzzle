extends Control

## Draws vector-only concept art. Everything under the header is the real Pause modal scene.

var concept := 0

const BLUE_DARK := Color("145083")
const BLUE := Color("298bd1")
const BLUE_LIGHT := Color("77cef2")
const GOLD := Color("ffb83d")
const GOLD_LIGHT := Color("ffe48d")
const GOLD_DARK := Color("b65b15")
const BROWN := Color("65321e")


func _draw() -> void:
	match concept:
		0:
			_draw_ribbon()
		1:
			_draw_tag()
		2:
			_draw_marquee()


func _draw_ribbon() -> void:
	# Wide folded tails give the modal a distinctive outline, like the first two references.
	polygon(Vector2Array([
		Vector2(12, 57), Vector2(67, 57), Vector2(67, 133), Vector2(12, 133),
		Vector2(27, 96),
	]), BLUE_DARK)
	polygon(Vector2Array([
		Vector2(568, 57), Vector2(513, 57), Vector2(513, 133), Vector2(568, 133),
		Vector2(553, 96),
	]), BLUE_DARK)
	polygon(Vector2Array([
		Vector2(19, 52), Vector2(68, 52), Vector2(68, 117), Vector2(19, 117),
		Vector2(31, 84),
	]), BLUE)
	polygon(Vector2Array([
		Vector2(561, 52), Vector2(512, 52), Vector2(512, 117), Vector2(561, 117),
		Vector2(549, 84),
	]), BLUE)
	polygon(Vector2Array([Vector2(67, 111), Vector2(94, 130), Vector2(94, 107)]), BLUE_DARK)
	polygon(Vector2Array([Vector2(513, 111), Vector2(486, 130), Vector2(486, 107)]), BLUE_DARK)
	_rounded(Rect2(48, 25, 484, 104), BLUE_DARK, Color("0e355c"), 5, 52, Color(0, 0, 0, 0.24), 8)
	_rounded(Rect2(53, 27, 474, 91), BLUE, BLUE_LIGHT, 4, 46)
	_rounded(Rect2(70, 35, 440, 25), Color(0.72, 0.92, 1, 0.26), Color.TRANSPARENT, 0, 14)
	_rounded(Rect2(78, 114, 424, 8), Color("10568c"), Color.TRANSPARENT, 0, 4)
	for x in [105.0, 474.0]:
		draw_circle(Vector2(x, 83), 5.0, Color("c9ecfa"))
		draw_circle(Vector2(x, 83), 2.0, BLUE_DARK)


func _draw_tag() -> void:
	# Warm product tag with a blue hanging loop: a direct visual connection to sorted goods.
	_rounded(Rect2(205, 23, 170, 36), BLUE_DARK, BLUE_LIGHT, 3, 18)
	_rounded(Rect2(218, 36, 144, 27), Color("253f6c"), Color.TRANSPARENT, 0, 13)
	_rounded(Rect2(94, 43, 392, 88), GOLD_DARK, BROWN, 4, 27, Color(0, 0, 0, 0.23), 8)
	_rounded(Rect2(100, 39, 380, 82), GOLD, GOLD_LIGHT, 4, 24)
	_rounded(Rect2(117, 47, 346, 21), Color(1, 1, 1, 0.27), Color.TRANSPARENT, 0, 11)
	for x in [125.0, 455.0]:
		draw_circle(Vector2(x, 81), 12.0, Color("c27318"))
		draw_circle(Vector2(x, 78), 8.0, GOLD_LIGHT)
		draw_circle(Vector2(x, 78), 3.0, Color("e59a27"))
	# Small blue corner tabs pull the tag into the terracotta body.
	polygon(Vector2Array([Vector2(98, 104), Vector2(140, 124), Vector2(111, 131)]), BLUE_DARK)
	polygon(Vector2Array([Vector2(482, 104), Vector2(440, 124), Vector2(469, 131)]), BLUE_DARK)


func _draw_marquee() -> void:
	# A compact shelf canopy: blue enamel face, golden ledge, and visible corner fasteners.
	_rounded(Rect2(43, 37, 494, 97), BROWN, Color("422318"), 4, 24, Color(0, 0, 0, 0.25), 9)
	_rounded(Rect2(49, 29, 482, 94), BLUE_DARK, GOLD_DARK, 5, 22)
	_rounded(Rect2(59, 35, 462, 74), Color("267cad"), BLUE_LIGHT, 3, 17)
	_rounded(Rect2(68, 40, 444, 16), Color(0.77, 0.95, 1, 0.24), Color.TRANSPARENT, 0, 8)
	_rounded(Rect2(35, 115, 510, 19), GOLD_DARK, BROWN, 3, 8)
	_rounded(Rect2(39, 112, 502, 13), GOLD, GOLD_LIGHT, 2, 6)
	for x in [78.0, 502.0]:
		draw_circle(Vector2(x, 80), 11.0, GOLD_DARK)
		draw_circle(Vector2(x, 78), 7.0, GOLD_LIGHT)
		draw_circle(Vector2(x, 78), 2.5, BROWN)
	# A little shelf lip and corner caps make it read as part of the game's furniture.
	_rounded(Rect2(53, 128, 49, 9), BROWN, Color.TRANSPARENT, 0, 4)
	_rounded(Rect2(478, 128, 49, 9), BROWN, Color.TRANSPARENT, 0, 4)


func _rounded(
	rect: Rect2, fill: Color, stroke: Color, border: int, radius: int,
	shadow: Color = Color.TRANSPARENT, shadow_size: int = 0
) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = stroke
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	if shadow_size > 0:
		style.shadow_color = shadow
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0, 4)
	draw_style_box(style, rect)


func polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)


func Vector2Array(points: Array[Vector2]) -> PackedVector2Array:
	return PackedVector2Array(points)
