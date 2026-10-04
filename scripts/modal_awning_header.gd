@tool
extends Control
class_name ModalAwningHeader

## Striped shop-awning modal header: a wooden rail, a perspective canopy of alternating stripes with
## a scalloped valance, and a cream title plate that hangs behind the scallops and grows with the
## title. GameplayModalShell instances this and shows it instead of its plain title label when the
## owning modal selects the AWNING header style (see docs/SCENES.md).
##
## The canopy is drawn here because stripes and scallops depend on the header width and must stay
## crisp at every responsive scale. It is drawn onto the `Canopy` child rather than this root so
## that child order alone layers it: plate, then canopy over the plate's top edge, then rail. The
## rail and title plate are scene-authored StyleBoxFlat panels.

@export_range(2, 24) var stripe_count := 10:
	set(value):
		stripe_count = maxi(value, 2)
		_redraw_canopy()
@export var stripe_color := Color(0.878, 0.286, 0.231, 1.0):
	set(value):
		stripe_color = value
		_redraw_canopy()
@export var alternate_stripe_color := Color(1.0, 0.953, 0.863, 1.0):
	set(value):
		alternate_stripe_color = value
		_redraw_canopy()
@export var outline_color := Color(0.353, 0.118, 0.071, 1.0):
	set(value):
		outline_color = value
		_redraw_canopy()
@export var outline_width := 3.0:
	set(value):
		outline_width = value
		_redraw_canopy()
## Darkening under the rail, fading out by the middle of the canopy.
@export var canopy_shade_color := Color(0.235, 0.039, 0.0, 0.34):
	set(value):
		canopy_shade_color = value
		_redraw_canopy()
## Canopy top edge (under the rail) and valance line, in header-local pixels.
@export var canopy_top := 16.0:
	set(value):
		canopy_top = value
		_redraw_canopy()
@export var canopy_bottom := 62.0:
	set(value):
		canopy_bottom = value
		_redraw_canopy()
## Horizontal insets of the canopy's top and bottom edges; a larger top inset reads as perspective.
@export var canopy_top_inset := 16.0:
	set(value):
		canopy_top_inset = value
		_redraw_canopy()
@export var canopy_bottom_inset := 2.0:
	set(value):
		canopy_bottom_inset = value
		_redraw_canopy()
@export_range(4, 48) var scallop_segments := 16:
	set(value):
		scallop_segments = maxi(value, 4)
		_redraw_canopy()
@export var title_regular_font_size := 42
@export var title_long_font_size := 36
## Plate title for scenes that author it directly; GameplayModalShell sets it through set_title().
@export var title_text := "TITLE":
	set(value):
		title_text = value
		_apply_title()
## Selects the smaller long-title size so wide titles keep the plate inside the awning.
@export var use_long_title_size := false:
	set(value):
		use_long_title_size = value
		_apply_title()
## Titles that still overflow (translations, product names) shrink toward this size until the plate
## fits within the header width minus `plate_side_margin` on each side.
@export var title_min_font_size := 28
@export var plate_side_margin := 40.0

@onready var _canopy := $Canopy as Control
@onready var _title_label := %PlateLabel as Label


func _ready() -> void:
	_canopy.draw.connect(_draw_canopy)
	_canopy.resized.connect(_canopy.queue_redraw)
	# The fit depends on the header width, which is only known once the owner lays it out.
	resized.connect(_apply_title)
	_apply_title()


## Sets the plate's title; long titles use the smaller size so the plate stays inside the awning.
func set_title(title: String, is_long_title: bool = false) -> void:
	title_text = title
	use_long_title_size = is_long_title


func get_title() -> String:
	return title_text


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_title.call_deferred()


## Exported setters also run while the scene loads, before `_title_label` is resolved.
func _apply_title() -> void:
	if _title_label == null:
		return
	_title_label.text = title_text
	var font_size := title_long_font_size if use_long_title_size else title_regular_font_size
	var font := _title_label.get_theme_font("font")
	var plate_style := (%TitlePlate as Control).get_theme_stylebox("panel")
	var chrome_width := plate_style.get_margin(SIDE_LEFT) + plate_style.get_margin(SIDE_RIGHT)
	var max_text_width := size.x - plate_side_margin * 2.0 - chrome_width
	if font != null and max_text_width > 0.0:
		while (
			font_size > title_min_font_size
			and font.get_string_size(_title_label.atr(title_text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				> max_text_width
		):
			font_size -= 1
	_title_label.add_theme_font_size_override("font_size", font_size)


## Exported setters also run while the scene loads, before `_canopy` is resolved.
func _redraw_canopy() -> void:
	if _canopy != null:
		_canopy.queue_redraw()


func _draw_canopy() -> void:
	var width := _canopy.size.x
	var top_left := canopy_top_inset
	var top_step := (width - canopy_top_inset * 2.0) / stripe_count
	var bottom_left := canopy_bottom_inset
	var bottom_step := (width - canopy_bottom_inset * 2.0) / stripe_count

	for index in stripe_count:
		_canopy.draw_colored_polygon(
			PackedVector2Array([
				Vector2(top_left + index * top_step, canopy_top),
				Vector2(top_left + (index + 1) * top_step, canopy_top),
				Vector2(bottom_left + (index + 1) * bottom_step, canopy_bottom),
				Vector2(bottom_left + index * bottom_step, canopy_bottom),
			]),
			_stripe_color(index)
		)
	# Polygons are not antialiased; soften each slanted stripe seam with a thin antialiased line.
	for index in range(1, stripe_count):
		_canopy.draw_line(
			Vector2(top_left + index * top_step, canopy_top),
			Vector2(bottom_left + index * bottom_step, canopy_bottom),
			stripe_color,
			1.0,
			true
		)
	_draw_canopy_shade(width, top_left, bottom_left)

	var radius := bottom_step * 0.5
	var valance_y := canopy_bottom - 1.0
	for index in stripe_count:
		var scallop := _scallop_points(Vector2(bottom_left + (index + 0.5) * bottom_step, valance_y), radius)
		_canopy.draw_colored_polygon(scallop, _stripe_color(index))
		_canopy.draw_polyline(scallop, outline_color, outline_width, true)

	_canopy.draw_line(
		Vector2(top_left, canopy_top),
		Vector2(bottom_left, valance_y),
		outline_color,
		outline_width,
		true
	)
	_canopy.draw_line(
		Vector2(width - top_left, canopy_top),
		Vector2(width - bottom_left, valance_y),
		outline_color,
		outline_width,
		true
	)


func _stripe_color(index: int) -> Color:
	return stripe_color if index % 2 == 0 else alternate_stripe_color


## Vertical shade over the canopy: strongest under the rail, clear by the canopy's middle.
func _draw_canopy_shade(width: float, top_left: float, bottom_left: float) -> void:
	var middle_y := lerpf(canopy_top, canopy_bottom, 0.5)
	var middle_left := lerpf(top_left, bottom_left, 0.5)
	var clear := Color(canopy_shade_color, 0.0)
	_canopy.draw_polygon(
		PackedVector2Array([
			Vector2(top_left, canopy_top),
			Vector2(width - top_left, canopy_top),
			Vector2(width - middle_left, middle_y),
			Vector2(middle_left, middle_y),
		]),
		PackedColorArray([canopy_shade_color, canopy_shade_color, clear, clear])
	)


## Lower half-disc hanging below the valance line, ordered left to right so the same points serve
## as the filled scallop and as its outline arc (without the chord across the top).
func _scallop_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in scallop_segments + 1:
		var angle := PI - PI * float(step) / float(scallop_segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
