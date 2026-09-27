class_name GameplayTipBubble
extends Control

## A speech bubble for a gameplay tip: a rounded panel with a tail pointing up at what the tip is
## about. It never takes input. The tail is two triangles: the border one sits under the panel and
## the fill one sits over it, covering the panel's top border where the tail joins so the two read
## as one outline.
##
## Size comes from measuring the text with the label's own font rather than from a container pass,
## so `place()` is exact on the frame it is called and captures do not depend on layout timing.

@export var max_panel_width := 460.0
@export var content_margin := Vector2(26.0, 18.0)
@export var tail_height := 18.0
@export var tail_half_width := 17.0
## Keeps the tail on the flat part of the top edge, clear of the rounded corners.
@export var tail_edge_margin := 34.0

var _panel: Panel
var _label: Label
var _tail_border: Polygon2D
var _tail_fill: Polygon2D
var _panel_style: StyleBoxFlat


func _ready() -> void:
	_panel = get_node("Panel") as Panel
	_label = get_node("Label") as Label
	_tail_border = get_node("TailBorder") as Polygon2D
	_tail_fill = get_node("TailFill") as Polygon2D
	_panel_style = _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if _panel_style != null:
		_tail_border.color = _panel_style.border_color
		_tail_fill.color = _panel_style.bg_color
	visible = false


## Translated here rather than by the label, so `place()` measures the text that is shown.
func set_message(text: String) -> void:
	_label.text = tr(text)


func get_message() -> String:
	return _label.text


func has_message() -> bool:
	return not _label.text.is_empty()


func show_bubble() -> void:
	if visible and modulate.a > 0.99:
		return

	UIMotion.fade_in(self)


func hide_bubble(fade := true) -> void:
	if not fade or not visible:
		UIMotion.stop_tween(self, UIMotion._FADE_TWEEN_META)
		visible = false
		return

	UIMotion.close_with_fade(self, hide)


## Lays the bubble out below `tail_tip`, which is where the tail points. The panel is centred on
## `center_x` and kept inside `bounds`; the tail follows `tail_tip.x` along the panel's top edge.
func place(tail_tip: Vector2, center_x: float, bounds: Rect2) -> void:
	var panel_width := minf(max_panel_width, bounds.size.x)
	var text_width := maxf(panel_width - content_margin.x * 2.0, 1.0)
	var font := _label.get_theme_font(&"font")
	var font_size := _label.get_theme_font_size(&"font_size")
	var text_size := font.get_multiline_string_size(
		_label.text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size
	)
	var line_count := maxi(roundi(text_size.y / maxf(font.get_height(font_size), 1.0)), 1)
	var text_height := text_size.y + float(line_count - 1) * float(_label.get_theme_constant(&"line_spacing"))
	var panel_height := text_height + content_margin.y * 2.0

	var panel_left := clampf(center_x - panel_width * 0.5, bounds.position.x, bounds.end.x - panel_width)
	position = Vector2(panel_left, tail_tip.y)
	size = Vector2(panel_width, tail_height + panel_height)
	_panel.position = Vector2(0.0, tail_height)
	_panel.size = Vector2(panel_width, panel_height)
	_label.position = Vector2(content_margin.x, tail_height + content_margin.y)
	_label.size = Vector2(text_width, text_height)

	var tail_x := clampf(tail_tip.x - panel_left, tail_edge_margin, panel_width - tail_edge_margin)
	_shape_tail(tail_x)


## The bubble's panel in the parent's coordinates, for overlap checks.
func get_panel_rect() -> Rect2:
	return Rect2(position + _panel.position, _panel.size)


func _shape_tail(tail_x: float) -> void:
	var border := 3.0
	if _panel_style != null:
		border = float(_panel_style.border_width_top)

	# Both triangles run from the tip down past the panel's top border, where the panel hides the
	# border triangle's base and the fill triangle paints over the border segment under the tail.
	var base_y := tail_height + border + 1.0
	var slope := tail_half_width / tail_height
	var outer_half := base_y * slope
	_tail_border.polygon = PackedVector2Array([
		Vector2(tail_x, 0.0),
		Vector2(tail_x + outer_half, base_y),
		Vector2(tail_x - outer_half, base_y),
	])

	# The inner apex drops by border / sin(half-angle) so the two edges stay `border` apart.
	var inner_apex := border * sqrt(1.0 + slope * slope) / slope
	var inner_half := maxf(base_y - inner_apex, 0.0) * slope
	_tail_fill.polygon = PackedVector2Array([
		Vector2(tail_x, inner_apex),
		Vector2(tail_x + inner_half, base_y),
		Vector2(tail_x - inner_half, base_y),
	])
