class_name Shelf
extends Node2D

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
const FLOOR_ONLY_HIDDEN_NODES := [
	"Shadow",
	"BackWall",
	"BackWallTopShade",
	"Ceiling",
	"TopCeilingCap",
	"RightColumnShadow",
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


func _ready() -> void:
	_apply_visual_variant()
	_apply_row_placement()


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


func get_row_placement() -> String:
	return _row_placement


func add_back_layer(layer_index: int, front_slots: Array[Node2D]) -> Array[Node2D]:
	var layer := Node2D.new()
	layer.name = get_back_layer_name(layer_index)
	layer.z_index = back_layer_z_index
	layer.visible = layer_index == FIRST_BACK_LAYER_INDEX
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
	var should_show := layer_index == FIRST_BACK_LAYER_INDEX
	layer.visible = should_show

	for layer_slot in layer.get_children():
		var slot := layer_slot as Node2D
		if slot == null:
			continue

		var item := _get_slot_item(slot)
		if item != null:
			item.modulate = back_layer_item_modulate if should_show else Color.TRANSPARENT


func configure_back_layer_item(item: ShelfItem, should_show: bool) -> void:
	item.z_index = back_layer_item_z_index
	item.modulate = back_layer_item_modulate if should_show else Color.TRANSPARENT
	item.input_pickable = false
	item.set_contact_shadow_enabled(false)
	item.visual_scale *= back_layer_item_scale

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true


func _add_layer_slot(layer: Node2D, front_slot: Node2D) -> Node2D:
	var layer_slot := Node2D.new()
	layer_slot.name = "Layer%s" % front_slot.name
	layer_slot.position = front_slot.position + back_layer_offset
	layer.add_child(layer_slot)

	return layer_slot


func _apply_visual_variant() -> void:
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


func _set_node_visible(node_name: String, should_show: bool) -> void:
	var node := get_node_or_null(node_name) as CanvasItem
	if node != null:
		node.visible = should_show


func _get_slot_item(slot: Node2D) -> ShelfItem:
	for child in slot.get_children():
		var item := child as ShelfItem
		if item != null and not item.is_queued_for_deletion():
			return item

	return null
