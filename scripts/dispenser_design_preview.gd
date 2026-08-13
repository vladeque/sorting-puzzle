extends Node2D

## Throwaway harness for choosing a new dispenser shelf look. Run this scene directly, or capture it
## through `scripts/tools/capture_ui.ps1`.
##
## Two strips, because the current dispenser has two separate problems and they are judged in
## different views:
##
## * The art strip compares the frames on their own, zoomed, which is where the niche proportions,
##   the inner shading and the count readout can actually be seen.
## * The footprint strip puts each dispenser above the next shelf row at the spacing that design
##   would really need, because the count readout hanging below the frame is what forces
##   `scripts/level.gd`'s `DISPENSER_ROW_EXTRA_HEIGHT` and breaks the board into two blocks.
##
## Nothing here ships. Delete this scene and its script once a direction is picked and built into
## `scenes/dispenser_shelf.tscn`.

const SHELF_SCENE := preload("res://scenes/shelf.tscn")
const DISPENSER_SCENE := preload("res://scenes/dispenser_shelf.tscn")
const ITEM_SCENE := preload("res://scenes/item.tscn")

const DISPENSER_ITEM := preload("res://assets/items/item_chips_can_cheese.png")
const LOWER_ROW_ITEMS: Array[Texture2D] = [
	preload("res://assets/items/item_ketchup_bottle.png"),
	preload("res://assets/items/item_cupcake.png"),
	preload("res://assets/items/item_juice_box_apple.png"),
]

const SLOT_ITEM_POSITION := Vector2(0.0, -32.0)
const SLOT_NAMES := ["Slot01", "Slot02", "Slot03"]

## `scripts/level.gd`'s row step in shelf-local units: one cell height less the edge neighbouring
## rows share. Anything a shelf draws below its floor has to be paid for on top of this.
const ROW_STEP := 135.0 - 8.0
## `DISPENSER_ROW_EXTRA_HEIGHT`, converted out of the 1.06 cell scale `scripts/level.gd` applies.
const CURRENT_ROW_EXTRA := 58.0 / 1.06
## What the same rule would ask for once the segmented bar is gone and the badge is the only thing
## reaching past the floor lip.
const PROPOSED_ROW_EXTRA := 28.0 / 1.06

const CAPACITY := 3
const REMAINING := 2

const ART_STRIP_ZOOM := 1.55
const ART_STRIP_Y := 250.0
const ART_STRIP_X := [128.0, 360.0, 592.0]
const FOOTPRINT_Y := 700.0
const FOOTPRINT_X := [180.0, 540.0]

## chapter_01's `legacy` background bands, the surface every playable level draws its shelves on.
const BACKGROUND_WALL_COLOR := Color(0.78, 0.67, 0.55)
const BACKGROUND_PLAY_WALL_COLOR := Color(0.86, 0.77, 0.65)
const BACKGROUND_Z_INDEX := -100

## Shared shelf palette, copied from `scenes/shelf.tscn` so the proposals stay inside the art the
## rest of the board already uses.
const WOOD_MID := Color(0.78039217, 0.52156866, 0.2901961)
const WOOD_DARK := Color(0.6392157, 0.3882353, 0.1882353)
const WOOD_FLOOR := Color(0.64, 0.39, 0.19)
const PANEL_LIGHT := Color(0.85882354, 0.76862746, 0.6509804)
const PANEL_SHADE := Color(0.68884707, 0.6076549, 0.5096408)
const GRAIN_COLOR := Color(0.38, 0.21, 0.1, 0.34)

## Proposal C's accent body: cool enough to separate a dispenser from the honey-brown shelving at a
## glance, still inside the game's saturated-toy palette.
const CRATE_MID := Color(0.31, 0.56, 0.58)
const CRATE_DARK := Color(0.19, 0.38, 0.42)
const CRATE_LIGHT := Color(0.45, 0.72, 0.72)
const CRATE_PANEL := Color(0.89, 0.91, 0.87)
const CRATE_PANEL_SHADE := Color(0.72, 0.77, 0.75)

const GAUGE_TRACK_COLOR := Color(0.24, 0.17, 0.12)
const GAUGE_FILL_COLOR := Color(0.35, 0.78, 0.22)
const GAUGE_FACE_COLOR := Color(0.97, 0.92, 0.79)
const GAUGE_TEXT_COLOR := Color(0.26, 0.15, 0.06)

const TITLE_COLOR := Color(0.2, 0.12, 0.05)
const NOTE_COLOR := Color(0.42, 0.31, 0.21)

const ART_PANELS := [
	{"builder": "_build_current", "title": "A  Current", "note": "badge + bar,\nheavy inner shading"},
	{"builder": "_build_tidy_niche", "title": "B  Tidy niche", "note": "one dial,\nopen niche"},
	{"builder": "_build_vending_crate", "title": "C  Crate", "note": "own body,\nnot a shelf"},
]

const FOOTPRINT_PANELS := [
	{
		"builder": "_build_current",
		"row_extra": CURRENT_ROW_EXTRA,
		"title": "Current",
		"note": "readout reaches 28px below the\nfloor lip, so the row below is\npushed away by 58px",
	},
	{
		"builder": "_build_tidy_niche",
		"row_extra": PROPOSED_ROW_EXTRA,
		"title": "Proposed",
		"note": "one dial reaches 13px below,\nso the row below closes back up\nby 30px",
	},
]


func _ready() -> void:
	_build_background()

	_add_label("Frame and readout", Vector2(40.0, 60.0), 26, TITLE_COLOR)
	for index in range(ART_PANELS.size()):
		_build_art_panel(ART_PANELS[index] as Dictionary, index)

	_add_label("What the readout costs the board", Vector2(40.0, 470.0), 26, TITLE_COLOR)
	for index in range(FOOTPRINT_PANELS.size()):
		_build_footprint_panel(FOOTPRINT_PANELS[index] as Dictionary, index)


func _build_art_panel(panel: Dictionary, index: int) -> void:
	var center_x := float(ART_STRIP_X[index])
	var dispenser := call(str(panel["builder"])) as Node2D
	dispenser.position = Vector2(center_x, ART_STRIP_Y)
	dispenser.scale = Vector2(ART_STRIP_ZOOM, ART_STRIP_ZOOM)
	add_child(dispenser)

	var label_x := center_x - 86.0
	_add_label(str(panel["title"]), Vector2(label_x, ART_STRIP_Y + 116.0), 20, TITLE_COLOR)
	_add_label(str(panel["note"]), Vector2(label_x, ART_STRIP_Y + 144.0), 15, NOTE_COLOR)


func _build_footprint_panel(panel: Dictionary, index: int) -> void:
	var origin := Vector2(float(FOOTPRINT_X[index]), FOOTPRINT_Y)

	var dispenser := call(str(panel["builder"])) as Node2D
	dispenser.position = origin
	add_child(dispenser)

	var lower := _make_stocked_shelf(LOWER_ROW_ITEMS)
	lower.position = origin + Vector2(0.0, ROW_STEP + float(panel["row_extra"]))
	add_child(lower)
	lower.set_row_placement(Shelf.ROW_PLACEMENT_MIDDLE)

	var label_x := origin.x - 116.0
	_add_label(str(panel["title"]), Vector2(label_x, origin.y + 244.0), 20, TITLE_COLOR)
	_add_label(str(panel["note"]), Vector2(label_x, origin.y + 272.0), 15, NOTE_COLOR)


# --- Panel A: the shipped scene, untouched. -----------------------------------------------------

func _build_current() -> Node2D:
	var dispenser := DISPENSER_SCENE.instantiate() as DispenserShelf
	_stock_slot(dispenser.get_node_or_null("Slot01") as Node2D, DISPENSER_ITEM)
	dispenser.set_capacity(CAPACITY)
	dispenser.set_remaining_count(REMAINING)
	return dispenser


# --- Panel B: same wooden niche, corrected. -----------------------------------------------------

## Keeps the shelf vocabulary and fixes what makes the current cell read badly: two heavy inner
## shades that eat a quarter of an already narrow niche, and a two-part count readout where the
## number and the bar say the same thing.
func _build_tidy_niche() -> Node2D:
	var root := Node2D.new()
	root.name = "TidyNiche"

	_add_polygon(root, "BackWall", [
		Vector2(-40, -81), Vector2(40, -81), Vector2(40, 16), Vector2(-40, 16),
	], PANEL_LIGHT, 1)
	# Halved, and the 10px-wide left shade dropped entirely: on an 80px niche those two bands were
	# taking a quarter of the width the single item has to sit in.
	_add_polygon(root, "BackWallTopShade", [
		Vector2(-40, -81), Vector2(40, -81), Vector2(40, -74), Vector2(-40, -74),
	], PANEL_SHADE, 2)
	_add_polygon(root, "LeftShadowEdge", [
		Vector2(-40, -81), Vector2(-38.5, -81), Vector2(-38.5, 16), Vector2(-40, 16),
	], PANEL_SHADE, 3)
	_add_polygon(root, "RightShadowEdge", [
		Vector2(38.5, -81), Vector2(40, -81), Vector2(40, 16), Vector2(38.5, 16),
	], PANEL_SHADE, 3)

	_add_polygon(root, "LeftWall", [
		Vector2(-48, -89), Vector2(-40, -89), Vector2(-40, 46), Vector2(-48, 46),
	], WOOD_MID, 4)
	_add_polygon(root, "RightWall", [
		Vector2(40, -89), Vector2(48, -89), Vector2(48, 46), Vector2(40, 46),
	], WOOD_MID, 4)
	_add_polygon(root, "Ceiling", [
		Vector2(-40, -89), Vector2(40, -89), Vector2(48, -81), Vector2(-48, -81),
	], WOOD_MID, 3)
	_add_top_cap(root, WOOD_DARK)

	_add_polygon(root, "FloorSurface", [
		Vector2(-40, 16), Vector2(40, 16), Vector2(40, 42), Vector2(-40, 42),
	], WOOD_FLOOR, 5)
	_add_polygon(root, "FloorFrontLip", [
		Vector2(-48, 38), Vector2(48, 38), Vector2(48, 46), Vector2(-48, 46),
	], WOOD_MID, 5)
	_add_line(root, "FloorGrainBack", [Vector2(-34, 21), Vector2(0, 21), Vector2(34, 21)], 1.2,
		GRAIN_COLOR, 6)
	_add_line(root, "FloorGrainFront", [Vector2(-40, 33), Vector2(40, 33)], 1.0, GRAIN_COLOR, 6)

	_stock_slot(_add_slot(root), DISPENSER_ITEM)
	_add_dial(root, Vector2(0.0, 40.0), WOOD_DARK)
	return root


# --- Panel C: a purpose-built fixture. ----------------------------------------------------------

## Gives the dispenser its own object identity instead of dressing it as a one-slot shelf: an accent
## body, a hood, and a chute under the item. The footprint is identical to panel B, so this is a
## pure art choice layered on the same layout fix.
func _build_vending_crate() -> Node2D:
	var root := Node2D.new()
	root.name = "VendingCrate"

	_add_polygon(root, "BackPanel", [
		Vector2(-38, -80), Vector2(38, -80), Vector2(38, 16), Vector2(-38, 16),
	], CRATE_PANEL, 1)
	_add_polygon(root, "BackPanelTopShade", [
		Vector2(-38, -80), Vector2(38, -80), Vector2(38, -72), Vector2(-38, -72),
	], CRATE_PANEL_SHADE, 2)

	_add_polygon(root, "LeftWall", [
		Vector2(-48, -80), Vector2(-38, -80), Vector2(-38, 46), Vector2(-48, 46),
	], CRATE_MID, 4)
	_add_polygon(root, "RightWall", [
		Vector2(38, -80), Vector2(48, -80), Vector2(48, 46), Vector2(38, 46),
	], CRATE_MID, 4)
	_add_polygon(root, "LeftWallHighlight", [
		Vector2(-48, -80), Vector2(-44.5, -80), Vector2(-44.5, 46), Vector2(-48, 46),
	], CRATE_LIGHT, 5)
	_add_polygon(root, "RightWallShade", [
		Vector2(44.5, -80), Vector2(48, -80), Vector2(48, 46), Vector2(44.5, 46),
	], CRATE_DARK, 5)

	# A shallow dome instead of a flat board, so the top of the unit is not one more straight shelf
	# line competing with the real shelving beside it.
	_add_polygon(root, "Hood", _hood_points(), CRATE_MID, 6)
	_add_polygon(root, "HoodShade", _hood_points(6.0), CRATE_DARK, 5)
	_add_polygon(root, "HoodPlate", _rounded_rect_points(Vector2(54.0, 19.0), 8.0), CRATE_PANEL, 7,
		Vector2(0.0, -92.0))
	_add_label_2d(root, "STOCK", Vector2(-27.0, -101.0), 12, CRATE_DARK, 8, 54.0)

	_add_polygon(root, "FloorSurface", [
		Vector2(-38, 16), Vector2(38, 16), Vector2(38, 42), Vector2(-38, 42),
	], CRATE_DARK, 5)
	# The chute the next item comes up through, so the fixture explains its own one-way rule.
	_add_polygon(root, "Chute", _rounded_rect_points(Vector2(54.0, 9.0), 4.0),
		Color(0.11, 0.22, 0.25), 6, Vector2(0.0, 21.0))
	_add_polygon(root, "FloorFrontLip", [
		Vector2(-48, 38), Vector2(48, 38), Vector2(48, 46), Vector2(-48, 46),
	], CRATE_MID, 7)

	_stock_slot(_add_slot(root), DISPENSER_ITEM)
	_add_dial(root, Vector2(0.0, 40.0), CRATE_DARK)
	return root


func _hood_points(drop := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 18
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		points.append(Vector2(
			lerpf(-52.0, 52.0, t),
			-80.0 + drop - 22.0 * sin(PI * t)
		))
	points.append(Vector2(52.0, -72.0 + drop))
	points.append(Vector2(-52.0, -72.0 + drop))
	return points


# --- Shared proposal part: one readout instead of two. ------------------------------------------

## Merges the segmented bar and the number badge into a single dial. The ring is the "how much is
## left" gauge the bar used to be; the face carries the exact number, at the size the badge already
## proved readable. One element instead of two is what lets the whole readout sit on the shelf lip.
func _add_dial(root: Node2D, center: Vector2, rim_color: Color) -> void:
	_add_polygon(root, "DialShadow", _circle_points(19.0), Color(0, 0, 0, 0.2), 8,
		center + Vector2(0.0, 2.5))
	_add_polygon(root, "DialRim", _circle_points(19.0), rim_color, 9, center)
	_add_polygon(root, "DialTrack", _circle_points(16.0), GAUGE_TRACK_COLOR, 10, center)

	var arc := Line2D.new()
	arc.name = "DialFill"
	arc.position = center
	arc.width = 5.0
	arc.default_color = GAUGE_FILL_COLOR
	arc.z_index = 11
	arc.points = _arc_points(13.2, float(REMAINING) / float(CAPACITY))
	root.add_child(arc)

	_add_polygon(root, "DialFace", _circle_points(10.6), GAUGE_FACE_COLOR, 12, center)
	_add_label_2d(root, str(REMAINING), center + Vector2(-20.0, -14.0), 20, GAUGE_TEXT_COLOR, 13,
		40.0)


func _arc_points(radius: float, fraction: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 30
	var sweep := TAU * clampf(fraction, 0.0, 1.0)
	for index in range(steps + 1):
		var angle := -TAU * 0.25 + sweep * float(index) / float(steps)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _add_top_cap(root: Node2D, color: Color) -> void:
	_add_polygon(root, "TopCapBoard", [
		Vector2(-48, -103), Vector2(48, -103), Vector2(48, -89), Vector2(-48, -89),
	], color, 7)
	_add_line(root, "TopCapGrain",
		[Vector2(-32, -100), Vector2(-10, -100), Vector2(10, -99), Vector2(32, -100)], 1.0,
		Color(0.22, 0.12, 0.055, 0.32), 8)


# --- Scene plumbing -----------------------------------------------------------------------------

func _add_slot(root: Node2D) -> Node2D:
	var slot := Node2D.new()
	slot.name = "Slot01"
	slot.position = Vector2(0.0, 15.0)
	root.add_child(slot)
	return slot


func _make_stocked_shelf(textures: Array[Texture2D]) -> Shelf:
	var shelf := SHELF_SCENE.instantiate() as Shelf
	for index in range(mini(textures.size(), SLOT_NAMES.size())):
		_stock_slot(shelf.get_node_or_null(SLOT_NAMES[index]) as Node2D, textures[index])
	return shelf


func _stock_slot(slot: Node2D, texture: Texture2D) -> void:
	if slot == null:
		return
	var item := ITEM_SCENE.instantiate() as ShelfItem
	item.texture = texture
	item.position = SLOT_ITEM_POSITION
	slot.add_child(item)


func _add_polygon(
	root: Node2D,
	node_name: String,
	points: Variant,
	color: Color,
	z_index: int,
	offset := Vector2.ZERO
) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.color = color
	polygon.z_index = z_index
	polygon.position = offset
	polygon.polygon = (points if points is PackedVector2Array
		else PackedVector2Array(points as Array))
	root.add_child(polygon)
	return polygon


func _add_line(
	root: Node2D, node_name: String, points: Array, width: float, color: Color, z_index: int
) -> void:
	var line := Line2D.new()
	line.name = node_name
	line.width = width
	line.default_color = color
	line.z_index = z_index
	line.points = PackedVector2Array(points)
	root.add_child(line)


func _add_label_2d(
	root: Node2D,
	text: String,
	position: Vector2,
	font_size: int,
	color: Color,
	z_index: int,
	width: float
) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = z_index
	label.position = position
	label.size = Vector2(width, float(font_size) + 10.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	root.add_child(label)


func _add_label(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.z_index = 40
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)


func _build_background() -> void:
	var size := get_viewport_rect().size
	var wall := ColorRect.new()
	wall.color = BACKGROUND_WALL_COLOR
	wall.size = size
	wall.z_index = BACKGROUND_Z_INDEX
	add_child(wall)

	var play_wall := ColorRect.new()
	play_wall.color = BACKGROUND_PLAY_WALL_COLOR
	play_wall.position = Vector2(0.0, 100.0)
	play_wall.size = Vector2(size.x, maxf(size.y - 100.0, 0.0))
	play_wall.z_index = BACKGROUND_Z_INDEX + 1
	add_child(play_wall)


func _rounded_rect_points(size: Vector2, radius: float) -> PackedVector2Array:
	var half := size * 0.5
	var corner_radius := minf(radius, minf(half.x, half.y))
	var points := PackedVector2Array()
	var centers := [
		Vector2(half.x - corner_radius, -half.y + corner_radius),
		Vector2(half.x - corner_radius, half.y - corner_radius),
		Vector2(-half.x + corner_radius, half.y - corner_radius),
		Vector2(-half.x + corner_radius, -half.y + corner_radius),
	]
	for corner_index in range(centers.size()):
		var center := centers[corner_index] as Vector2
		var start_angle := -TAU * 0.25 + float(corner_index) * TAU * 0.25
		for step in range(5):
			var angle := start_angle + TAU * 0.25 * float(step) / 4.0
			points.append(center + Vector2(cos(angle), sin(angle)) * corner_radius)
	return points


func _circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
