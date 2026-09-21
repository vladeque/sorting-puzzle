class_name Shelf
extends Node2D

## Cell footprint one shelf occupies in the level grid, before `SHELF_CELL_VISUAL_SCALE`.
## `scripts/level.gd` reads this as the authority for `SHELF_BASE_CELL_SIZE`.
const BASE_CELL_SIZE := Vector2(224, 135)
## Standard shelf art is floor-anchored. The frame grows upward by this delta; level row packing
## adds the scaled delta between rows so every opening remains visible instead of being overdrawn
## by the shelf above.
const ORIGINAL_INTERIOR_HEIGHT := 97.0
const INTERIOR_HEIGHT_SCALE := 1.1
const INTERIOR_HEIGHT_EXTENSION := ORIGINAL_INTERIOR_HEIGHT * (INTERIOR_HEIGHT_SCALE - 1.0)
## Highest point standard shelf art draws, before `SHELF_CELL_VISUAL_SCALE`: the top edge of the
## `TopCeilingCap/BackBoard` polygons in `scenes/shelf.tscn`. The art rises above the grid cell here,
## and `scripts/collapsing_shelf_board.gd` opens its clip window at this line so the top shelf's
## cap is never cut off.
const TOP_CEILING_CAP_TOP_Y := -112.7
const SLOT_COUNT := 3
const BACK_LAYER_PREFIX := "ShelfLayer"
const FIRST_BACK_LAYER_INDEX := 1
const VISUAL_VARIANT_META := &"visual_variant"
const ROW_PLACEMENT_META := &"row_placement"
const VISUAL_VARIANT_FULL := "full"
const VISUAL_VARIANT_FLOOR_ONLY := "floor_only"
const ROW_PLACEMENT_LEFT := "left"
const ROW_PLACEMENT_MIDDLE := "middle"
const ROW_PLACEMENT_RIGHT := "right"
const PLACEMENT_VISUALS_NODE := "PlacementVisuals"
const LEFT_PLACEMENT_NODE := "PlacementVisuals/Left"
const MIDDLE_PLACEMENT_NODE := "PlacementVisuals/Middle"
const RIGHT_PLACEMENT_NODE := "PlacementVisuals/Right"
const TOP_CEILING_CAP_NODE := "TopCeilingCap"
const COLLAPSING_VISUALS_NODE := "CollapsingVisuals"
const FLOOR_SURFACE_NODE := "FloorSurface"
const FLOOR_FRONT_LIP_NODE := "FloorFrontLip"
const FLOOR_CONTACT_SHADOW_NODE := "FloorContactShadow"
const BOTTOM_SHADOW_NODE := "Shadow"
const RIGHT_CAST_SHADOW_NODE := "RightColumnShadow"
const HORIZONTAL_VISUAL_SCALE_NODES := [
	"Shadow",
	"RightColumnShadow",
	"BackWall",
	"BackWallTopShade",
	"PlacementVisuals",
	"Ceiling",
	FLOOR_CONTACT_SHADOW_NODE,
	"FloorSurface",
	"FloorFrontLip",
	"FloorGrainBack",
	"FloorGrainMiddle",
	"FloorGrainKnot",
	"FloorGrainFront",
	"Highlight",
]
const FLOOR_ONLY_HIDDEN_NODES := [
	"BackWall",
	"BackWallTopShade",
	"Ceiling",
	"PlacementVisuals",
	"Highlight",
]

@export var back_layer_offset := Vector2(0, -10)
@export var back_layer_z_index := 7
@export var back_layer_item_z_index := 0
@export var back_layer_item_scale := 0.86
@export var back_layer_item_modulate := Color(0.376, 0.376, 0.376, 0.706)

var _visual_variant := VISUAL_VARIANT_FULL
var _row_placement := ROW_PLACEMENT_MIDDLE
var _should_show_top_ceiling_cap := false
var _collapsing_visuals_enabled := false
var _exterior_shadows_composited := false


func _ready() -> void:
	_apply_visual_variant()
	_apply_row_placement()
	_apply_collapsing_visuals()


## Shelf-type capabilities. `scripts/level.gd` branches on these instead of on the shelf's class, so
## a new shelf type only has to override what actually differs. `scenes/dispenser_shelf.tscn` is the
## first type that says no to any of them.


## Cell footprint this shelf type occupies, before `SHELF_CELL_VISUAL_SCALE`. Drives both row packing
## and the board bounds the responsive layout scales to fit.
func get_base_cell_size() -> Vector2:
	return BASE_CELL_SIZE


## Everything this shelf draws, relative to its own origin and before `SHELF_CELL_VISUAL_SCALE`.
## Usually the cell itself, but a shelf type may draw outside the footprint it occupies in the grid.
func get_visual_bounds() -> Rect2:
	return Rect2(-BASE_CELL_SIZE * 0.5, BASE_CELL_SIZE)


## Number of front slots, and therefore the width of every layer in this shelf's level config.
func get_slot_count() -> int:
	return SLOT_COUNT


## Whether the player may drop a carried item onto this shelf. A shelf that says no is still a valid
## place to pick items up from -- taking and placing are separate permissions.
func accepts_dropped_items() -> bool:
	return true


## Whether a full front layer of identical items clears as a triple.
func forms_triples() -> bool:
	return true


## Whether abilities may destroy this shelf's items (hammer) or rewrite their identities (shuffle).
## Read-only abilities such as highlight ignore this and treat every shelf alike.
func allows_ability_modification() -> bool:
	return true


## Whether the first back layer is previewed behind the front items as dimmed art. A shelf type that
## says no keeps its queue hidden until each item is actually promoted.
func shows_back_layer_preview() -> bool:
	return true


func set_visual_variant(visual_variant: String) -> void:
	match visual_variant:
		VISUAL_VARIANT_FULL, VISUAL_VARIANT_FLOOR_ONLY:
			_visual_variant = visual_variant
		_:
			_visual_variant = VISUAL_VARIANT_FULL
			push_warning("Unknown shelf visual_variant '%s'. Using full shelf." % visual_variant)

	set_meta(VISUAL_VARIANT_META, _visual_variant)
	_apply_visual_variant()
	_apply_row_placement()
	_apply_top_ceiling_cap_visibility()
	_apply_collapsing_visuals()


func get_visual_variant() -> String:
	return _visual_variant


func set_row_placement(row_placement: String) -> void:
	match row_placement:
		ROW_PLACEMENT_LEFT, ROW_PLACEMENT_MIDDLE, ROW_PLACEMENT_RIGHT:
			_row_placement = row_placement
		_:
			_row_placement = ROW_PLACEMENT_MIDDLE
			push_warning("Unknown shelf row_placement '%s'. Using middle shelf." % row_placement)

	set_meta(ROW_PLACEMENT_META, _row_placement)
	_apply_row_placement()
	_apply_top_ceiling_cap_visibility()


func get_row_placement() -> String:
	return _row_placement


## Gameplay mirrors exterior casts into one level-owned CanvasGroup. Keeping the authored nodes in
## the shelf makes standalone previews and destruction effects stable while avoiding a second draw.
func set_exterior_shadows_composited(should_composite: bool) -> void:
	_exterior_shadows_composited = should_composite
	_apply_exterior_shadow_visibility()


func should_show_exterior_shadows() -> bool:
	return _visual_variant == VISUAL_VARIANT_FULL and not _collapsing_visuals_enabled


## Collapsing-column levels reuse the standard shelf interaction geometry but give each cell a
## darker wooden cabinet back and inset shading. Basic shelves leave this scene-authored layer
## hidden.
func set_collapsing_visuals_enabled(should_enable: bool) -> void:
	_collapsing_visuals_enabled = should_enable
	_apply_collapsing_visuals()


## Moving rows can shorten the shelf body without squeezing item art, slot positions, or hit areas.
func set_horizontal_visual_scale(horizontal_scale: float) -> void:
	var safe_scale := maxf(horizontal_scale, 0.01)
	for node_path in HORIZONTAL_VISUAL_SCALE_NODES:
		var visual := get_node_or_null(node_path) as Node2D
		if visual != null:
			visual.scale.x = safe_scale
			var polygon := visual as Polygon2D
			if polygon != null:
				polygon.antialiased = true

	# The authored front lip is wider than the floor so static shelves can interlock. Moving shelves
	# are independent cells, so trim that extra overhang and finish both faces at the same edges.
	var floor_surface := get_node_or_null(FLOOR_SURFACE_NODE) as Polygon2D
	var floor_front_lip := get_node_or_null(FLOOR_FRONT_LIP_NODE) as Polygon2D
	if floor_surface != null and floor_front_lip != null:
		var surface_width := _get_polygon_horizontal_span(floor_surface.polygon) * safe_scale
		var lip_width := _get_polygon_horizontal_span(floor_front_lip.polygon)
		if lip_width > 0.0:
			floor_front_lip.scale.x = surface_width / lip_width


func set_top_ceiling_cap_visible(should_show: bool) -> void:
	_should_show_top_ceiling_cap = should_show
	_apply_top_ceiling_cap_visibility()


func add_back_layer(layer_index: int, front_slots: Array[Node2D]) -> Array[Node2D]:
	var layer := Node2D.new()
	layer.name = get_back_layer_name(layer_index)
	layer.z_index = back_layer_z_index
	layer.visible = _is_previewed_back_layer(layer_index)
	add_child(layer)

	var layer_slots: Array[Node2D] = []
	for front_slot in front_slots:
		layer_slots.append(_add_layer_slot(layer, front_slot))

	return layer_slots


func get_back_layer(layer_index: int) -> Node2D:
	return get_node_or_null(get_back_layer_name(layer_index)) as Node2D


func get_back_layer_name(layer_index: int) -> String:
	return "%s%02d" % [BACK_LAYER_PREFIX, layer_index + 1]


func configure_back_layer(layer: Node2D, layer_index: int) -> void:
	var should_show := _is_previewed_back_layer(layer_index)
	layer.visible = should_show

	for layer_slot in layer.get_children():
		var slot := layer_slot as Node2D
		if slot == null:
			continue

		var item := _get_slot_item(slot)
		if item != null:
			item.is_in_back_layer = true
			item.modulate = back_layer_item_modulate if should_show else Color.TRANSPARENT


func configure_back_layer_item(item: ShelfItem, should_show: bool) -> void:
	var is_previewed := should_show and shows_back_layer_preview()
	item.is_in_back_layer = true
	item.z_index = back_layer_item_z_index
	item.modulate = back_layer_item_modulate if is_previewed else Color.TRANSPARENT
	item.input_pickable = false
	item.set_contact_shadow_enabled(false)
	item.visual_scale *= back_layer_item_scale

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true


func _is_previewed_back_layer(layer_index: int) -> bool:
	return layer_index == FIRST_BACK_LAYER_INDEX and shows_back_layer_preview()


func _add_layer_slot(layer: Node2D, front_slot: Node2D) -> Node2D:
	var layer_slot := Node2D.new()
	layer_slot.name = "Layer%s" % front_slot.name
	layer_slot.position = front_slot.position + back_layer_offset
	layer.add_child(layer_slot)

	return layer_slot


func _apply_visual_variant() -> void:
	_apply_exterior_shadow_visibility()
	if _visual_variant != VISUAL_VARIANT_FLOOR_ONLY:
		return

	for node_name in FLOOR_ONLY_HIDDEN_NODES:
		_set_node_visible(node_name, false)


func _apply_row_placement() -> void:
	if _visual_variant != VISUAL_VARIANT_FULL:
		_set_node_visible(PLACEMENT_VISUALS_NODE, false)
		return

	_set_node_visible(PLACEMENT_VISUALS_NODE, true)
	_set_node_visible(LEFT_PLACEMENT_NODE, _row_placement == ROW_PLACEMENT_LEFT)
	_set_node_visible(MIDDLE_PLACEMENT_NODE, _row_placement == ROW_PLACEMENT_MIDDLE)
	_set_node_visible(RIGHT_PLACEMENT_NODE, _row_placement == ROW_PLACEMENT_RIGHT)


func _apply_top_ceiling_cap_visibility() -> void:
	var should_show := _should_show_top_ceiling_cap and _visual_variant == VISUAL_VARIANT_FULL
	_set_node_visible(TOP_CEILING_CAP_NODE, should_show)
	for placement_node in [LEFT_PLACEMENT_NODE, MIDDLE_PLACEMENT_NODE, RIGHT_PLACEMENT_NODE]:
		_set_node_visible("%s/%s" % [placement_node, TOP_CEILING_CAP_NODE], should_show)


func _apply_collapsing_visuals() -> void:
	var show_collapsing_visuals := (
		_collapsing_visuals_enabled and _visual_variant == VISUAL_VARIANT_FULL
	)
	_set_node_visible(COLLAPSING_VISUALS_NODE, show_collapsing_visuals)
	# A collapsing board owns one exterior cast shadow for the complete cabinet.
	_apply_exterior_shadow_visibility()
	_apply_top_ceiling_cap_visibility()


func _apply_exterior_shadow_visibility() -> void:
	var should_draw_locally := should_show_exterior_shadows() and not _exterior_shadows_composited
	_set_node_visible(BOTTOM_SHADOW_NODE, should_draw_locally)
	_set_node_visible(RIGHT_CAST_SHADOW_NODE, should_draw_locally)


func _set_node_visible(node_name: String, should_show: bool) -> void:
	var node := get_node_or_null(node_name) as CanvasItem
	if node != null:
		node.visible = should_show


func _get_polygon_horizontal_span(points: PackedVector2Array) -> float:
	if points.is_empty():
		return 0.0

	var minimum_x := points[0].x
	var maximum_x := points[0].x
	for point in points:
		minimum_x = minf(minimum_x, point.x)
		maximum_x = maxf(maximum_x, point.x)

	return maximum_x - minimum_x


func _get_slot_item(slot: Node2D) -> ShelfItem:
	for child in slot.get_children():
		var item := child as ShelfItem
		if item != null and not item.is_queued_for_deletion():
			return item

	return null
