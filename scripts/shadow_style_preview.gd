extends Node2D

## Side-by-side harness for tuning the item ground shadow. Run this scene directly: it lays the same
## contrasting silhouettes out twice on real shelves -- once resting and once at full carry height --
## plus a copy that animates continuously between the two, so the grab and drop transitions can be
## judged as motion rather than as two stills.
##
## The background reproduces chapter_01's `legacy` flat wall/floor colors from level.tscn, because
## that is what every currently playable level renders behind the shelves, and a shadow can only be
## judged against the surface it actually lands on.
##
## Nothing here is part of the shipped game; delete this scene and its script once the shadow is
## signed off. Pass `-- --capture <path>` on the command line to save a screenshot and quit.

const ITEM_SCENE := preload("res://scenes/item.tscn")
const SHELF_SCENE := preload("res://scenes/shelf.tscn")

## Deliberately contrasting silhouettes: a tall narrow bottle, a squat wide tub, and an irregular
## shape with detail that a good shadow should simplify rather than copy.
const PREVIEW_ITEM_TEXTURES := [
	"res://assets/items/item_water_bottle.png",
	"res://assets/items/item_ice_cream_tub_pink.png",
	"res://assets/items/item_cupcake.png",
]

const ROWS := [
	{"lift": 0.0, "label": "Resting on shelf", "y": 300.0},
	{"lift": 0.5, "label": "Mid-grab (blend)", "y": 700.0},
	{"lift": 1.0, "label": "Carried (dragged)", "y": 1100.0},
]

const SHELF_X := 300.0
const SLOT_NAMES := ["Slot01", "Slot02", "Slot03"]
const SLOT_ITEM_POSITION := Vector2(0.0, -32.0)

## The animated copy cycles rest -> carry -> rest, slow enough to actually watch.
const LIFT_CYCLE_SECONDS := 2.4

const CAPTURE_ARGUMENT := "--capture"
const CAPTURE_SETTLE_FRAMES := 20

var _animated_items: Array[ShelfItem] = []


## chapter_01's `legacy` background bands, copied from level.tscn. Built with explicit rects rather
## than anchors because this scene's root is a Node2D, where anchor-based Control layout does not
## resolve against the viewport.
const BACKGROUND_WALL_COLOR := Color(0.78, 0.67, 0.55)
const BACKGROUND_PLAY_WALL_COLOR := Color(0.86, 0.77, 0.65)
const BACKGROUND_FLOOR_COLOR := Color(0.62, 0.25, 0.18)
const BACKGROUND_PLAY_WALL_TOP := 112.0
const BACKGROUND_FLOOR_HEIGHT := 156.0
const BACKGROUND_PLAY_WALL_BOTTOM_INSET := 176.0
const BACKGROUND_Z_INDEX := -100


func _ready() -> void:
	_build_background()
	for row in ROWS:
		_build_row(row)


func _build_background() -> void:
	var viewport_size := get_viewport_rect().size

	_add_background_band(
		Vector2.ZERO,
		viewport_size,
		BACKGROUND_WALL_COLOR
	)
	_add_background_band(
		Vector2(0.0, BACKGROUND_PLAY_WALL_TOP),
		Vector2(
			viewport_size.x,
			maxf(viewport_size.y - BACKGROUND_PLAY_WALL_TOP - BACKGROUND_PLAY_WALL_BOTTOM_INSET, 0.0)
		),
		BACKGROUND_PLAY_WALL_COLOR
	)
	_add_background_band(
		Vector2(0.0, viewport_size.y - BACKGROUND_FLOOR_HEIGHT),
		Vector2(viewport_size.x, BACKGROUND_FLOOR_HEIGHT),
		BACKGROUND_FLOOR_COLOR
	)


func _add_background_band(band_position: Vector2, band_size: Vector2, color: Color) -> void:
	var band := ColorRect.new()
	band.color = color
	band.position = band_position
	band.size = band_size
	band.z_index = BACKGROUND_Z_INDEX
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)

	var capture_path := _get_capture_path()
	if not capture_path.is_empty():
		_capture_and_quit(capture_path)


func _build_row(row: Dictionary) -> void:
	var row_y := float(row["y"])
	var lift := float(row["lift"])

	var label := Label.new()
	label.text = str(row["label"])
	label.position = Vector2(30.0, row_y - 210.0)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 0.92))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)

	var shelf := SHELF_SCENE.instantiate() as Node2D
	shelf.position = Vector2(SHELF_X, row_y)
	add_child(shelf)

	for index in PREVIEW_ITEM_TEXTURES.size():
		var slot := shelf.get_node_or_null(SLOT_NAMES[index]) as Node2D
		if slot == null:
			continue
		var item := _add_item(slot, SLOT_ITEM_POSITION, PREVIEW_ITEM_TEXTURES[index])
		if item != null:
			item.shadow_lift = lift

	# A fourth copy off the shelf, over bare background, cycling between the two shapes.
	var animated_host := Node2D.new()
	animated_host.position = Vector2(SHELF_X + 240.0, row_y - 40.0)
	add_child(animated_host)
	var animated := _add_item(animated_host, Vector2.ZERO, PREVIEW_ITEM_TEXTURES[0])
	if animated != null:
		animated.shadow_lift = lift
		if lift > 0.0:
			_animated_items.append(animated)


func _add_item(parent: Node2D, item_position: Vector2, texture_path: String) -> ShelfItem:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("Preview item texture missing: %s" % texture_path)
		return null

	var item := ITEM_SCENE.instantiate() as ShelfItem
	parent.add_child(item)
	item.position = item_position
	item.texture = texture
	item.input_pickable = false
	return item


func _process(_delta: float) -> void:
	if _animated_items.is_empty():
		return

	# 0 -> 1 -> 0, so the shadow repeatedly moves between its nearby soft and separated carried forms.
	var phase := fmod(Time.get_ticks_msec() / 1000.0, LIFT_CYCLE_SECONDS) / LIFT_CYCLE_SECONDS
	var eased := smoothstep(0.0, 1.0, 1.0 - absf(phase * 2.0 - 1.0))

	for item in _animated_items:
		if is_instance_valid(item):
			item.shadow_lift = eased


func _get_capture_path() -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find(CAPTURE_ARGUMENT)
	if index < 0 or index + 1 >= arguments.size():
		return ""
	return arguments[index + 1]


## Renders a few frames so shelves, items and shaders have all settled, then writes the viewport to
## disk and exits. Used to review the shadow without a human watching the window.
func _capture_and_quit(path: String) -> void:
	set_process(false)
	for i in CAPTURE_SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("Preview captured: %s" % path)
	else:
		push_error("Preview capture failed (%d): %s" % [error, path])
	get_tree().quit(0 if error == OK else 1)
