class_name Shelf
extends Node2D

const BACK_LAYER_PREFIX := "ShelfLayer"
const FIRST_BACK_LAYER_INDEX := 1

@export var back_layer_offset := Vector2(0, -10)
@export var back_layer_z_index := 7
@export var back_layer_item_z_index := 0
@export var back_layer_item_scale := 0.86
@export var back_layer_item_modulate := Color(0.376, 0.376, 0.376, 0.706)


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


func _get_slot_item(slot: Node2D) -> ShelfItem:
	for child in slot.get_children():
		var item := child as ShelfItem
		if item != null and not item.is_queued_for_deletion():
			return item

	return null
