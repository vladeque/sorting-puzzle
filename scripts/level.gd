extends Node2D

const SLOT_ITEM_POSITION := Vector2(0, -42)
const BACK_LAYER_NAME := "BackLayer"

@export var slot_snap_distance := 86.0
@export var item_pick_size := Vector2(58, 92)
@export var drag_start_distance := 12.0
@export var back_layer_offset := Vector2(0, -18)
@export var back_layer_item_scale := 0.86
@export var back_layer_item_modulate := Color(0.42, 0.42, 0.42, 0.34)

var _slots: Array[Node2D] = []
var _dragged_item: ShelfItem
var _origin_slot: Node2D
var _drag_offset := Vector2.ZERO
var _drag_layer: Node2D
var _pressed_item: ShelfItem
var _pressed_origin_slot: Node2D
var _press_position := Vector2.ZERO
var _selected_item: ShelfItem
var _selected_slot: Node2D


func _ready() -> void:
	_drag_layer = get_node("DragLayer") as Node2D
	_collect_slots()
	_build_back_layers()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		var pointer_position := get_global_mouse_position()
		if mouse_event.pressed:
			_handle_press_at(pointer_position)
		else:
			_handle_release_at(pointer_position)
	elif event is InputEventMouseMotion:
		_handle_motion_at(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		var pointer_position := _screen_position_to_global(touch_event.position)
		if touch_event.pressed:
			_handle_press_at(pointer_position)
		else:
			_handle_release_at(pointer_position)
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_handle_motion_at(_screen_position_to_global(drag_event.position))


func _collect_slots() -> void:
	_slots.clear()

	var shelves := get_node("Shelves")
	for shelf in shelves.get_children():
		for child in shelf.get_children():
			var slot := child as Node2D
			if slot != null and slot.name.begins_with("Slot"):
				_slots.append(slot)


func _build_back_layers() -> void:
	var shelves := get_node("Shelves")
	for shelf in shelves.get_children():
		var shelf_node := shelf as Node2D
		if shelf_node == null:
			continue

		var existing_back_layer := shelf_node.get_node_or_null(BACK_LAYER_NAME)
		if existing_back_layer != null:
			shelf_node.remove_child(existing_back_layer)
			existing_back_layer.free()

		var back_layer := Node2D.new()
		back_layer.name = BACK_LAYER_NAME
		back_layer.z_index = 4
		shelf_node.add_child(back_layer)

		for slot in _get_front_slots(shelf_node):
			_add_back_slot(back_layer, slot)


func _get_front_slots(shelf: Node) -> Array[Node2D]:
	var front_slots: Array[Node2D] = []
	for child in shelf.get_children():
		var slot := child as Node2D
		if slot != null and slot.name.begins_with("Slot"):
			front_slots.append(slot)

	return front_slots


func _add_back_slot(back_layer: Node2D, front_slot: Node2D) -> void:
	var back_slot := Node2D.new()
	back_slot.name = "Back%s" % front_slot.name
	back_slot.position = front_slot.position + back_layer_offset
	back_layer.add_child(back_slot)

	var front_item := _get_slot_item(front_slot)
	if front_item == null:
		return

	var back_item := front_item.duplicate() as ShelfItem
	back_item.name = "%sBackLayer" % front_item.name
	back_item.position = SLOT_ITEM_POSITION
	back_item.z_index = 0
	back_item.modulate = back_layer_item_modulate
	back_item.input_pickable = false
	back_item.visual_scale *= back_layer_item_scale
	back_slot.add_child(back_item)

	var collision := back_item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true


func _handle_press_at(pointer_global_position: Vector2) -> void:
	if _dragged_item != null:
		return

	var clicked_item := _find_item_at_position(pointer_global_position)
	if _selected_item != null:
		var target_slot := _find_clicked_slot(pointer_global_position, clicked_item)
		if target_slot != null:
			_move_item_to_slot(_selected_item, _selected_slot, target_slot)
			_clear_selected_item()
			get_viewport().set_input_as_handled()
			return

		_clear_selected_item()

	if clicked_item == null:
		return

	_pressed_item = clicked_item
	_pressed_origin_slot = clicked_item.get_parent() as Node2D
	_press_position = pointer_global_position
	get_viewport().set_input_as_handled()


func _handle_motion_at(pointer_global_position: Vector2) -> void:
	if _dragged_item != null:
		_move_active_drag(pointer_global_position)
		return

	if _pressed_item == null:
		return

	if pointer_global_position.distance_to(_press_position) < drag_start_distance:
		return

	_clear_selected_item()
	_begin_drag(_pressed_item, pointer_global_position)
	get_viewport().set_input_as_handled()


func _handle_release_at(pointer_global_position: Vector2) -> void:
	if _dragged_item != null:
		_finish_active_drag(pointer_global_position)
		_pressed_item = null
		_pressed_origin_slot = null
		return

	if _pressed_item == null:
		return

	if _pressed_item.get_parent() == _pressed_origin_slot:
		_set_selected_item(_pressed_item, _pressed_origin_slot)

	_pressed_item = null
	_pressed_origin_slot = null
	get_viewport().set_input_as_handled()


func _begin_drag(item: ShelfItem, pointer_global_position: Vector2) -> void:
	_dragged_item = item
	_origin_slot = item.get_parent() as Node2D
	_drag_offset = item.global_position - pointer_global_position
	item.reparent(_drag_layer, true)
	item.z_index = 100
	item.global_position = pointer_global_position + _drag_offset


func _move_active_drag(pointer_global_position: Vector2) -> void:
	if _dragged_item == null:
		return

	_dragged_item.global_position = pointer_global_position + _drag_offset
	get_viewport().set_input_as_handled()


func _finish_active_drag(pointer_global_position: Vector2) -> void:
	if _dragged_item == null:
		return

	var item := _dragged_item
	var target_slot := _find_nearest_slot(pointer_global_position)
	if target_slot == null:
		_place_item_in_slot(item, _origin_slot)
	elif target_slot == _origin_slot:
		_place_item_in_slot(item, _origin_slot)
	else:
		_move_item_to_slot(item, _origin_slot, target_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	get_viewport().set_input_as_handled()


func _move_item_to_slot(item: ShelfItem, origin_slot: Node2D, target_slot: Node2D) -> void:
	if item == null or origin_slot == null or target_slot == null:
		return

	if target_slot == origin_slot:
		_place_item_in_slot(item, origin_slot)
		return

	var shelves_to_check: Array[Node] = []
	_add_shelf_to_check(shelves_to_check, origin_slot)
	_add_shelf_to_check(shelves_to_check, target_slot)

	var target_item := _get_slot_item(target_slot)
	if target_item == null:
		_place_item_in_slot(item, target_slot)
	else:
		_place_item_in_slot(target_item, origin_slot)
		_place_item_in_slot(item, target_slot)

	_clear_matching_shelves(shelves_to_check)
	_promote_empty_front_layers(shelves_to_check)


func _find_item_at_position(pointer_global_position: Vector2) -> ShelfItem:
	for i in range(_slots.size() - 1, -1, -1):
		var item := _get_slot_item(_slots[i])
		if item == null:
			continue

		var item_rect := Rect2(item.global_position - item_pick_size * 0.5, item_pick_size)
		if item_rect.has_point(pointer_global_position):
			return item

	return null


func _find_clicked_slot(pointer_global_position: Vector2, clicked_item: ShelfItem) -> Node2D:
	if clicked_item != null:
		return clicked_item.get_parent() as Node2D

	return _find_nearest_slot(pointer_global_position)


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
		if item != null and not item.is_queued_for_deletion():
			return item

	return null


func _place_item_in_slot(item: ShelfItem, slot: Node2D) -> void:
	item.reparent(slot, true)
	item.position = SLOT_ITEM_POSITION
	item.z_index = 6


func _add_shelf_to_check(shelves_to_check: Array[Node], slot: Node2D) -> void:
	var shelf := slot.get_parent()
	if shelf != null and not shelves_to_check.has(shelf):
		shelves_to_check.append(shelf)


func _clear_matching_shelves(shelves_to_check: Array[Node]) -> void:
	for shelf in shelves_to_check:
		var shelf_items := _get_shelf_items(shelf)
		if shelf_items.size() != 3:
			continue

		var item_id := shelf_items[0].item_id
		if item_id == &"":
			continue

		if shelf_items.all(func(item: ShelfItem) -> bool: return item.item_id == item_id):
			for item in shelf_items:
				item.queue_free()

			if shelf_items.has(_selected_item):
				_clear_selected_item()


func _promote_empty_front_layers(shelves_to_check: Array[Node]) -> void:
	for shelf in shelves_to_check:
		var shelf_node := shelf as Node2D
		if shelf_node == null or not _front_layer_is_empty(shelf_node):
			continue

		_promote_back_layer(shelf_node)


func _front_layer_is_empty(shelf: Node) -> bool:
	for slot in _get_front_slots(shelf):
		if _get_slot_item(slot) != null:
			return false

	return true


func _promote_back_layer(shelf: Node2D) -> void:
	var back_layer := shelf.get_node_or_null(BACK_LAYER_NAME) as Node2D
	if back_layer == null:
		return

	for front_slot in _get_front_slots(shelf):
		var back_slot := back_layer.get_node_or_null("Back%s" % front_slot.name) as Node2D
		if back_slot == null:
			continue

		var back_item := _get_slot_item(back_slot)
		if back_item == null:
			continue

		_activate_back_layer_item(back_item)
		_place_item_in_slot(back_item, front_slot)

	shelf.remove_child(back_layer)
	back_layer.free()


func _activate_back_layer_item(item: ShelfItem) -> void:
	item.modulate = Color.WHITE
	item.input_pickable = true
	if back_layer_item_scale > 0.0:
		item.visual_scale /= back_layer_item_scale

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = false


func _get_shelf_items(shelf: Node) -> Array[ShelfItem]:
	var shelf_items: Array[ShelfItem] = []
	for child in shelf.get_children():
		var slot := child as Node2D
		if slot == null or not slot.name.begins_with("Slot"):
			continue

		var item := _get_slot_item(slot)
		if item != null:
			shelf_items.append(item)

	return shelf_items


func _screen_position_to_global(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _set_selected_item(item: ShelfItem, slot: Node2D) -> void:
	_clear_selected_item()
	_selected_item = item
	_selected_slot = slot
	_apply_item_selected(item, true)


func _clear_selected_item() -> void:
	if _selected_item != null and is_instance_valid(_selected_item):
		_apply_item_selected(_selected_item, false)

	_selected_item = null
	_selected_slot = null


func _apply_item_selected(item: ShelfItem, selected: bool) -> void:
	var sprite := item.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	sprite.modulate = Color(1.12, 1.12, 1.12, 1.0) if selected else Color.WHITE
