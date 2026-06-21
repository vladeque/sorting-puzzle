extends Node2D

const SLOT_ITEM_POSITION := Vector2(0, -42)
const GENERATED_LAYER_PREFIX := "ShelfLayer"
const FIRST_GENERATED_LAYER := 2
const ITEM_TYPE_COUNT := 8
const ITEMS_PER_TYPE := 3

@export var slot_snap_distance := 86.0
@export var item_pick_size := Vector2(58, 92)
@export var drag_start_distance := 12.0
@export var back_layer_offset := Vector2(0, -18)
@export var back_layer_item_scale := 0.86
@export var back_layer_item_modulate := Color(0.42, 0.42, 0.42, 0.34)
@export_range(1, 20, 1) var shelf_layer_count := 2
@export var level_duration_seconds := 300.0

var _slots: Array[Node2D] = []
var _dragged_item: ShelfItem
var _origin_slot: Node2D
var _drag_offset := Vector2.ZERO
var _drag_layer: Node2D
var _timer_label: Label
var _failure_panel: Control
var _time_remaining := 0.0
var _level_failed := false
var _pressed_item: ShelfItem
var _pressed_origin_slot: Node2D
var _press_position := Vector2.ZERO
var _selected_item: ShelfItem
var _selected_slot: Node2D


func _ready() -> void:
	_drag_layer = get_node("DragLayer") as Node2D
	_timer_label = get_node("UI/TimerLabel") as Label
	_failure_panel = get_node("UI/FailurePanel") as Control
	_time_remaining = level_duration_seconds
	_failure_panel.visible = false
	_collect_slots()
	_build_back_layers()
	_update_timer_label()


func _process(delta: float) -> void:
	if _level_failed:
		return

	_time_remaining = maxf(_time_remaining - delta, 0.0)
	_update_timer_label()

	if _time_remaining <= 0.0:
		_fail_level()


func _input(event: InputEvent) -> void:
	if _level_failed:
		return

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
	var templates := _get_item_templates()
	for shelf in shelves.get_children():
		var shelf_node := shelf as Node2D
		if shelf_node == null:
			continue

		_clear_generated_layers(shelf_node)

	for layer_index in range(FIRST_GENERATED_LAYER, shelf_layer_count + 1):
		var layer_slots: Array[Node2D] = []
		for shelf in shelves.get_children():
			var shelf_node := shelf as Node2D
			if shelf_node == null:
				continue

			layer_slots.append_array(_add_generated_layer(shelf_node, layer_index))

		var layer_items := _build_layer_items(templates, layer_index)
		_shuffle_array(layer_slots)
		_shuffle_array(layer_items)

		var fill_count = mini(layer_slots.size(), layer_items.size())
		for i in range(fill_count):
			_add_layer_item(layer_slots[i], layer_items[i], layer_index == FIRST_GENERATED_LAYER)


func _clear_generated_layers(shelf: Node) -> void:
	for child in shelf.get_children():
		if child.name.begins_with(GENERATED_LAYER_PREFIX):
			shelf.remove_child(child)
			child.free()


func _add_generated_layer(shelf: Node2D, layer_index: int) -> Array[Node2D]:
	var layer := Node2D.new()
	layer.name = _get_generated_layer_name(layer_index)
	layer.z_index = 4
	layer.visible = layer_index == FIRST_GENERATED_LAYER
	shelf.add_child(layer)

	var layer_slots: Array[Node2D] = []
	for slot in _get_front_slots(shelf):
		layer_slots.append(_add_layer_slot(layer, slot))

	return layer_slots


func _get_generated_layer_name(layer_index: int) -> String:
	return "%s%02d" % [GENERATED_LAYER_PREFIX, layer_index]


func _get_front_slots(shelf: Node) -> Array[Node2D]:
	var front_slots: Array[Node2D] = []
	for child in shelf.get_children():
		var slot := child as Node2D
		if slot != null and slot.name.begins_with("Slot"):
			front_slots.append(slot)

	return front_slots


func _add_layer_slot(layer: Node2D, front_slot: Node2D) -> Node2D:
	var layer_slot := Node2D.new()
	layer_slot.name = "Layer%s" % front_slot.name
	layer_slot.position = front_slot.position + back_layer_offset
	layer.add_child(layer_slot)

	return layer_slot


func _build_layer_items(templates: Array[ShelfItem], layer_index: int) -> Array[ShelfItem]:
	var layer_items: Array[ShelfItem] = []
	if templates.size() < ITEM_TYPE_COUNT:
		push_warning("Shelf layers expected %s item types, found %s." % [ITEM_TYPE_COUNT, templates.size()])

	var type_count = mini(ITEM_TYPE_COUNT, templates.size())
	for i in range(type_count):
		for repeat in range(ITEMS_PER_TYPE):
			var template := templates[i]
			var layer_item := template.duplicate() as ShelfItem
			layer_item.name = "%sLayer%sItem%s" % [template.name, layer_index, repeat + 1]
			layer_items.append(layer_item)

	return layer_items


func _get_item_templates() -> Array[ShelfItem]:
	var templates: Array[ShelfItem] = []
	var seen_item_ids: Array[StringName] = []
	for slot in _slots:
		var item := _get_slot_item(slot)
		if item == null or seen_item_ids.has(item.item_id):
			continue

		templates.append(item)
		seen_item_ids.append(item.item_id)

	return templates


func _add_layer_item(layer_slot: Node2D, layer_item: ShelfItem, should_show: bool) -> void:
	layer_item.position = SLOT_ITEM_POSITION
	layer_item.z_index = 0
	layer_item.modulate = back_layer_item_modulate if should_show else Color.TRANSPARENT
	layer_item.input_pickable = false
	layer_item.visual_scale *= back_layer_item_scale
	layer_slot.add_child(layer_item)

	var collision := layer_item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true


func _shuffle_array(items: Array) -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()

	for i in range(items.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, i)
		var current_item = items[i]
		items[i] = items[swap_index]
		items[swap_index] = current_item


func _update_timer_label() -> void:
	var remaining_seconds := ceili(_time_remaining)
	var minutes := remaining_seconds / 60
	var seconds := remaining_seconds % 60
	_timer_label.text = "%02d:%02d" % [minutes, seconds]


func _fail_level() -> void:
	_level_failed = true
	_clear_selected_item()

	if _dragged_item != null and _origin_slot != null:
		_place_item_in_slot(_dragged_item, _origin_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	_pressed_item = null
	_pressed_origin_slot = null
	_failure_panel.visible = true


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
		if shelf_node == null:
			continue

		while _front_layer_is_empty(shelf_node) and _promote_back_layer(shelf_node):
			pass


func _front_layer_is_empty(shelf: Node) -> bool:
	for slot in _get_front_slots(shelf):
		if _get_slot_item(slot) != null:
			return false

	return true


func _promote_back_layer(shelf: Node2D) -> bool:
	var next_layer := shelf.get_node_or_null(_get_generated_layer_name(FIRST_GENERATED_LAYER)) as Node2D
	if next_layer == null:
		return false

	for front_slot in _get_front_slots(shelf):
		var layer_slot := next_layer.get_node_or_null("Layer%s" % front_slot.name) as Node2D
		if layer_slot == null:
			continue

		var layer_item := _get_slot_item(layer_slot)
		if layer_item == null:
			continue

		_activate_back_layer_item(layer_item)
		_place_item_in_slot(layer_item, front_slot)

	shelf.remove_child(next_layer)
	next_layer.free()
	_advance_generated_layers(shelf)
	return true


func _advance_generated_layers(shelf: Node2D) -> void:
	for layer_index in range(FIRST_GENERATED_LAYER + 1, shelf_layer_count + 1):
		var layer := shelf.get_node_or_null(_get_generated_layer_name(layer_index)) as Node2D
		if layer == null:
			continue

		layer.name = _get_generated_layer_name(layer_index - 1)
		_configure_generated_layer(layer, layer_index - 1)


func _configure_generated_layer(layer: Node2D, layer_index: int) -> void:
	var should_show := layer_index == FIRST_GENERATED_LAYER
	layer.visible = should_show

	for layer_slot in layer.get_children():
		var slot := layer_slot as Node2D
		if slot == null:
			continue

		var item := _get_slot_item(slot)
		if item != null:
			item.modulate = back_layer_item_modulate if should_show else Color.TRANSPARENT


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
