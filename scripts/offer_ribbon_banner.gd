@tool
extends Control
class_name OfferRibbonBanner

## Folded ribbon banner for offer amounts (the Starter Bundle's "1,000 COINS"): a rounded front band
## with two notched tails that hang lower than the band and tuck behind it at a darker fold. The
## shape is drawn here so it follows the node's size; the label is the scene-authored %RibbonLabel.
## `tone` switches between the red offer ribbon and the green "rewards added" ribbon, and long
## (translated) text shrinks toward `min_font_size` until it fits on the band.

enum Tone { OFFER, SUCCESS }

const TONE_COLORS := {
	Tone.OFFER: {
		"band": Color(0.847, 0.224, 0.169, 1.0),
		"tail": Color(0.659, 0.137, 0.102, 1.0),
		"fold": Color(0.431, 0.078, 0.047, 1.0),
		"outline": Color(0.353, 0.071, 0.031, 1.0),
		"text_outline": Color(0.431, 0.055, 0.024, 1.0),
	},
	Tone.SUCCESS: {
		"band": Color(0.263, 0.71, 0.227, 1.0),
		"tail": Color(0.173, 0.541, 0.141, 1.0),
		"fold": Color(0.094, 0.353, 0.075, 1.0),
		"outline": Color(0.055, 0.239, 0.043, 1.0),
		"text_outline": Color(0.039, 0.29, 0.047, 1.0),
	},
}

@export var tone := Tone.OFFER:
	set(value):
		tone = value
		_apply_tone()
## Band top/bottom insets from this node's top and bottom edges; the tails span the rest.
@export var band_top := 4.0:
	set(value):
		band_top = value
		queue_redraw()
@export var band_bottom_inset := 14.0:
	set(value):
		band_bottom_inset = value
		queue_redraw()
## How far each tail extends beyond the band's end, and how far it reaches under the band.
@export var tail_outset := 24.0:
	set(value):
		tail_outset = value
		queue_redraw()
@export var tail_underlap := 20.0:
	set(value):
		tail_underlap = value
		queue_redraw()
@export var tail_top := 18.0:
	set(value):
		tail_top = value
		queue_redraw()
@export var notch_depth := 14.0:
	set(value):
		notch_depth = value
		queue_redraw()
@export var outline_width := 3.0:
	set(value):
		outline_width = value
		queue_redraw()
@export var max_font_size := 32
@export var min_font_size := 20

@onready var _label := %RibbonLabel as Label


func _ready() -> void:
	resized.connect(_fit_text)
	_apply_tone()
	_fit_text()


func set_text(text: String) -> void:
	_label.text = text
	_fit_text()


func get_text() -> String:
	return _label.text


func _apply_tone() -> void:
	queue_redraw()
	if _label == null:
		return
	_label.add_theme_color_override("font_outline_color", _tone_color("text_outline"))
	_label.add_theme_color_override("font_shadow_color", _tone_color("text_outline"))


func _fit_text() -> void:
	if _label == null:
		return
	var font := _label.get_theme_font("font")
	var max_width := size.x - (tail_outset + 12.0) * 2.0
	var font_size := max_font_size
	if font != null and max_width > 0.0:
		while (
			font_size > min_font_size
			and font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width
		):
			font_size -= 1
	_label.add_theme_font_size_override("font_size", font_size)


func _tone_color(key: String) -> Color:
	return (TONE_COLORS[tone] as Dictionary)[key]


func _draw() -> void:
	var width := size.x
	var tail_bottom := size.y - 4.0
	var band_bottom := size.y - band_bottom_inset
	var tail_inner := tail_outset + tail_underlap
	var notch_y := (tail_top + tail_bottom) * 0.5

	var left_tail := PackedVector2Array([
		Vector2(0.0, tail_top),
		Vector2(tail_inner, tail_top),
		Vector2(tail_inner, tail_bottom),
		Vector2(0.0, tail_bottom),
		Vector2(notch_depth, notch_y),
	])
	var right_tail := PackedVector2Array()
	for point in left_tail:
		right_tail.append(Vector2(width - point.x, point.y))
	for tail in [left_tail, right_tail]:
		draw_colored_polygon(tail, _tone_color("tail"))
		var outline := (tail as PackedVector2Array).duplicate()
		outline.append(outline[0])
		draw_polyline(outline, _tone_color("outline"), outline_width, true)

	# Folds: where each tail tucks behind the band's lower corner.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(tail_outset, band_bottom),
			Vector2(tail_inner, band_bottom),
			Vector2(tail_inner, tail_bottom),
		]),
		_tone_color("fold")
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(width - tail_outset, band_bottom),
			Vector2(width - tail_inner, band_bottom),
			Vector2(width - tail_inner, tail_bottom),
		]),
		_tone_color("fold")
	)

	var band := StyleBoxFlat.new()
	band.bg_color = _tone_color("band")
	band.border_color = _tone_color("outline")
	band.set_border_width_all(int(outline_width))
	band.set_corner_radius_all(6)
	band.anti_aliasing = true
	draw_style_box(band, Rect2(tail_outset, band_top, width - tail_outset * 2.0, band_bottom - band_top))

	var highlight := StyleBoxFlat.new()
	highlight.bg_color = Color(1.0, 1.0, 1.0, 0.22)
	highlight.set_corner_radius_all(3)
	draw_style_box(
		highlight,
		Rect2(tail_outset + 8.0, band_top + 5.0, width - (tail_outset + 8.0) * 2.0, 7.0)
	)
