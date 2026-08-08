extends Node2D

## Side-by-side harness for choosing between the two prototype item ground-shadow styles. Run this
## scene directly: it lays the same items out twice, once per style, on real shelves over the real
## level background, and animates the drag lift so the carried-item read can be judged too.
##
## Nothing here is part of the shipped game. Delete this scene, its script, and the losing half of
## ShelfItem.ShadowStyle once a style is chosen.

const ITEM_SCENE := preload("res://scenes/item.tscn")
const SHELF_SCENE := preload("res://scenes/shelf.tscn")

## Deliberately contrasting silhouettes: a tall narrow bottle, a squat wide tub, and an irregular
## shape with detail that a good shadow should simplify rather than copy.
const PREVIEW_ITEM_TEXTURES := [
	"res://assets/items/item_soda_bottle.png",
	"res://assets/items/item_ice_cream_tub_pink.png",
	"res://assets/items/item_cupcake.png",
]

const ROWS := [
	{"style": ShelfItem.ShadowStyle.CAST_PROJECTION, "label": "A - cast projection", "y": 300.0},
	{"style": ShelfItem.ShadowStyle.CONTACT_POOL, "label": "B - contact pool", "y": 620.0},
]

const SHELF_X := 360.0
const SLOT_NAMES := ["Slot01", "Slot02", "Slot03"]
const SLOT_ITEM_POSITION := Vector2(0.0, -32.0)

## The floating item repeats the drag lift so both styles can be judged while carried, not just at
## rest. Slow enough to actually watch.
const LIFT_CYCLE_SECONDS := 1.6
const FLOAT_HEIGHT := 90.0

var _floating_items: Array[ShelfItem] = []


func _ready() -> void:
	for row in ROWS:
		_build_row(row)


func _build_row(row: Dictionary) -> void:
	var row_y := float(row["y"])
	var style := int(row["style"])

	var label := Label.new()
	label.text = str(row["label"])
	label.position = Vector2(40.0, row_y - 190.0)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 1, 0.92))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)

	var shelf := SHELF_SCENE.instantiate() as Node2D
	shelf.position = Vector2(SHELF_X, row_y)
	add_child(shelf)

	for index in PREVIEW_ITEM_TEXTURES.size():
		var slot := shelf.get_node_or_null(SLOT_NAMES[index]) as Node2D
		if slot == null:
			continue
		_add_item(slot, SLOT_ITEM_POSITION, PREVIEW_ITEM_TEXTURES[index], style)

	# One more copy of the same item off the shelf, over bare background, cycling the drag lift.
	var floater_host := Node2D.new()
	floater_host.position = Vector2(SHELF_X + 240.0, row_y - 40.0)
	add_child(floater_host)
	var floater := _add_item(floater_host, Vector2.ZERO, PREVIEW_ITEM_TEXTURES[0], style)
	if floater != null:
		_floating_items.append(floater)


func _add_item(parent: Node2D, item_position: Vector2, texture_path: String, style: int) -> ShelfItem:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("Preview item texture missing: %s" % texture_path)
		return null

	var item := ITEM_SCENE.instantiate() as ShelfItem
	parent.add_child(item)
	item.position = item_position
	item.texture = texture
	item.shadow_style = style
	item.input_pickable = false
	return item


func _process(_delta: float) -> void:
	if _floating_items.is_empty():
		return

	# 0 -> 1 -> 0, so each item repeatedly rises off the board and settles back onto it.
	var phase := fmod(Time.get_ticks_msec() / 1000.0, LIFT_CYCLE_SECONDS) / LIFT_CYCLE_SECONDS
	var lift := 1.0 - absf(phase * 2.0 - 1.0)
	var eased := smoothstep(0.0, 1.0, lift)

	for item in _floating_items:
		if not is_instance_valid(item):
			continue
		item.shadow_lift = eased
		item.position.y = -FLOAT_HEIGHT * eased
