extends Node2D

const SLOT_ITEM_POSITION := Vector2(0, -42)

@export var slot_snap_distance := 86.0

var _slots: Array[Node2D] = []
var _dragged_item: ShelfItem
var _origin_slot: Node2D
var _drag_offset := Vector2.ZERO
var _drag_layer: Node2D


func _ready() -> void:
	_drag_layer = get_node("DragLayer") as Node2D
	_collect_slots()
	_connect_items()


func _collect_slots() -> void:
	_slots.clear()

	var shelves := get_node("Shelves")
	for shelf in shelves.get_children():
		for child in shelf.get_children():
			var slot := child as Node2D
			if slot != null and slot.name.begins_with("Slot"):
				_slots.append(slot)


func _connect_items() -> void:
	for slot in _slots:
		var item := _get_slot_item(slot)
		if item != null:
			_connect_item(item)


func _connect_item(item: ShelfItem) -> void:
	if not item.drag_started.is_connected(_on_item_drag_started):
		item.drag_started.connect(_on_item_drag_started)
	if not item.drag_moved.is_connected(_on_item_drag_moved):
		item.drag_moved.connect(_on_item_drag_moved)
	if not item.drag_ended.is_connected(_on_item_drag_ended):
		item.drag_ended.connect(_on_item_drag_ended)


func _on_item_drag_started(item: ShelfItem, pointer_global_position: Vector2) -> void:
	if _dragged_item != null:
		item.cancel_drag()
		return

	_dragged_item = item
	_origin_slot = item.get_parent() as Node2D
	_drag_offset = item.global_position - pointer_global_position
	item.reparent(_drag_layer, true)
	item.z_index = 100
	item.global_position = pointer_global_position + _drag_offset


func _on_item_drag_moved(item: ShelfItem, pointer_global_position: Vector2) -> void:
	if item != _dragged_item:
		return

	item.global_position = pointer_global_position + _drag_offset


func _on_item_drag_ended(item: ShelfItem, pointer_global_position: Vector2) -> void:
	if item != _dragged_item:
		return

	var target_slot := _find_nearest_slot(pointer_global_position)
	if target_slot == null:
		_place_item_in_slot(item, _origin_slot)
	elif target_slot == _origin_slot:
		_place_item_in_slot(item, _origin_slot)
	else:
		var target_item := _get_slot_item(target_slot)
		if target_item == null:
			_place_item_in_slot(item, target_slot)
		else:
			_place_item_in_slot(target_item, _origin_slot)
			_place_item_in_slot(item, target_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO


func _find_nearest_slot(pointer_global_position: Vector2) -> Node2D:
	var nearest_slot: Node2D
	var nearest_distance := slot_snap_distance

	for slot in _slots:
		var marker := slot.get_node_or_null("ItemSlot%s" % slot.name.trim_prefix("Slot")) as Marker2D
		if marker == null:
			continue

		var distance := pointer_global_position.distance_to(marker.global_position)
		if distance <= nearest_distance:
			nearest_slot = slot
			nearest_distance = distance

	return nearest_slot


func _get_slot_item(slot: Node2D) -> ShelfItem:
	for child in slot.get_children():
		var item := child as ShelfItem
		if item != null:
			return item

	return null


func _place_item_in_slot(item: ShelfItem, slot: Node2D) -> void:
	item.reparent(slot, true)
	item.position = SLOT_ITEM_POSITION
	item.z_index = 6
