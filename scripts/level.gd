extends Node2D

const SLOT_ITEM_POSITION := Vector2(0, -42)
const SLOT_COUNT := 3
const SLOT_POSITIONS := [Vector2(-56, 0), Vector2(0, 0), Vector2(56, 0)]
const BACK_LAYER_PREFIX := "ShelfLayer"
const FIRST_BACK_LAYER_INDEX := 1
const ABILITY_HAMMER := &"hammer"
const ABILITY_SHUFFLE := &"shuffle"
const ABILITY_HIGHLIGHT := &"highlight"
const ABILITY_EXTRA_SHELF := &"extra_shelf"
const HIGHLIGHT_DURATION_SECONDS := 15.0
const ITEM_SCENE := preload("res://scenes/item.tscn")
const ITEM_SPRITES_CONFIG := "res://configs/item_sprites.json"
const LEVEL_CONFIG_TEMPLATE := "res://configs/levels/level_%03d.json"
const DEFAULT_LEVEL_CONFIG := "res://configs/levels/level_001.json"

@export var slot_snap_distance := 86.0
@export var item_pick_size := Vector2(58, 92)
@export var drag_start_distance := 12.0
@export var back_layer_offset := Vector2(0, -18)
@export var back_layer_item_scale := 0.86
@export var back_layer_item_modulate := Color(0.42, 0.42, 0.42, 0.34)
@export var level_duration_seconds := 300.0
@export_range(1, 10, 1) var selected_level := 1

var _slots: Array[Node2D] = []
var _item_textures: Dictionary = {}
var _max_layer_count := 1
var _dragged_item: ShelfItem
var _origin_slot: Node2D
var _drag_offset := Vector2.ZERO
var _drag_layer: Node2D
var _timer_label: Label
var _level_label: Label
var _failure_panel: Control
var _ability_buttons: Dictionary = {}
var _ability_uses: Dictionary = {
	ABILITY_HAMMER: 3,
	ABILITY_SHUFFLE: 3,
	ABILITY_HIGHLIGHT: 3,
	ABILITY_EXTRA_SHELF: 1,
}
var _time_remaining := 0.0
var _level_failed := false
var _highlight_timer := 0.0
var _highlighted_items: Array[ShelfItem] = []
var _layout_preset := "grid_3x3"
var _extra_shelf_added := false
var _rng := RandomNumberGenerator.new()
var _pressed_item: ShelfItem
var _pressed_origin_slot: Node2D
var _press_position := Vector2.ZERO
var _selected_item: ShelfItem
var _selected_slot: Node2D


func _ready() -> void:
	_drag_layer = get_node("DragLayer") as Node2D
	_timer_label = get_node("UI/TimerLabel") as Label
	_level_label = get_node("UI/LevelLabel") as Label
	_failure_panel = get_node("UI/FailurePanel") as Control
	_failure_panel.visible = false
	_rng.randomize()
	_setup_ability_buttons()
	_load_item_textures()
	_apply_level_config(_load_level_config(selected_level))
	_collect_slots()
	_update_level_label()
	_update_timer_label()
	_update_ability_buttons()


func _process(delta: float) -> void:
	if _level_failed:
		return

	_time_remaining = maxf(_time_remaining - delta, 0.0)
	_update_timer_label()
	_update_highlight_timer(delta)

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


func _load_item_textures() -> void:
	_item_textures.clear()

	var config := _load_json_file(ITEM_SPRITES_CONFIG)
	var items := config.get("items", []) as Array
	for item_data in items:
		var item_config := item_data as Dictionary
		if item_config == null:
			continue

		var item_id := str(item_config.get("id", ""))
		var texture_path := str(item_config.get("texture", ""))
		if item_id.is_empty() or texture_path.is_empty():
			continue

		var texture := load(texture_path) as Texture2D
		if texture != null:
			_item_textures[item_id] = texture


func _load_level_config(level_number: int) -> Dictionary:
	var level_config_path := LEVEL_CONFIG_TEMPLATE % level_number
	if not FileAccess.file_exists(level_config_path):
		push_warning("Missing %s. Using %s." % [level_config_path, DEFAULT_LEVEL_CONFIG])
		level_config_path = DEFAULT_LEVEL_CONFIG

	return _load_json_file(level_config_path)


func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open config: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	var config := parsed as Dictionary
	if config == null:
		push_error("Config is not a JSON object: %s" % path)
		return {}

	return config


func _apply_level_config(config: Dictionary) -> void:
	level_duration_seconds = float(config.get("time_seconds", level_duration_seconds))
	_time_remaining = level_duration_seconds
	_max_layer_count = 1
	_extra_shelf_added = false
	_clear_ability_highlights()
	_reset_ability_uses()

	var shelves_config := config.get("shelves", []) as Array
	_layout_preset = str(config.get("layout_preset", "grid_3x3"))
	var shelf_positions := _get_layout_positions(_layout_preset, shelves_config.size())
	var shelves := get_node("Shelves") as Node2D
	_clear_shelves(shelves)

	for shelf_index in range(shelves_config.size()):
		var shelf_config := shelves_config[shelf_index] as Dictionary
		if shelf_config == null:
			continue

		var shelf := _add_shelf(shelves, shelf_index + 1, shelf_positions[shelf_index])
		var layers := shelf_config.get("layers", []) as Array
		_max_layer_count = maxi(_max_layer_count, layers.size())
		_add_configured_layers(shelf, layers)


func _clear_shelves(shelves: Node) -> void:
	for child in shelves.get_children():
		shelves.remove_child(child)
		child.free()


func _get_layout_positions(layout_preset: String, shelf_count: int) -> Array[Vector2]:
	var columns := 3
	var spacing := Vector2(210, 210)

	if layout_preset == "grid_2x3":
		columns = 2
	elif layout_preset == "grid_4x3":
		columns = 4
	elif layout_preset != "grid_3x3":
		push_warning("Unknown layout preset '%s'. Using grid_3x3." % layout_preset)

	var rows := ceili(float(shelf_count) / float(columns))
	var origin := Vector2(
		-(columns - 1) * spacing.x * 0.5,
		-(rows - 1) * spacing.y * 0.5
	)
	var positions: Array[Vector2] = []
	for shelf_index in range(shelf_count):
		var column := shelf_index % columns
		var row := shelf_index / columns
		positions.append(origin + Vector2(column * spacing.x, row * spacing.y))

	return positions


func _add_shelf(parent: Node2D, shelf_number: int, shelf_position: Vector2) -> Node2D:
	var shelf := Node2D.new()
	shelf.name = "Shelf%02d" % shelf_number
	shelf.position = shelf_position
	parent.add_child(shelf)

	_add_polygon(shelf, "Shadow", 0, Color(0.03, 0.025, 0.02, 0.34), PackedVector2Array([Vector2(-98, 9), Vector2(98, 9), Vector2(84, 34), Vector2(-84, 34)]))
	_add_polygon(shelf, "BackPanel", 1, Color(0.33, 0.21, 0.14, 1), PackedVector2Array([Vector2(-88, -76), Vector2(88, -76), Vector2(88, -20), Vector2(-88, -20)]))
	_add_polygon(shelf, "TopSurface", 2, Color(0.67, 0.43, 0.25, 1), PackedVector2Array([Vector2(-94, -26), Vector2(94, -26), Vector2(78, 4), Vector2(-78, 4)]))
	_add_polygon(shelf, "FrontLip", 3, Color(0.44, 0.27, 0.16, 1), PackedVector2Array([Vector2(-78, 4), Vector2(78, 4), Vector2(88, 28), Vector2(-88, 28)]))
	_add_highlight(shelf)

	for slot_index in range(SLOT_COUNT):
		_add_front_slot(shelf, slot_index)

	return shelf


func _add_polygon(parent: Node, node_name: String, z_index: int, color: Color, points: PackedVector2Array) -> void:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.z_index = z_index
	polygon.color = color
	polygon.polygon = points
	parent.add_child(polygon)


func _add_highlight(parent: Node) -> void:
	var highlight := Line2D.new()
	highlight.name = "Highlight"
	highlight.z_index = 4
	highlight.points = PackedVector2Array([Vector2(-76, -21), Vector2(76, -21)])
	highlight.width = 2.0
	highlight.default_color = Color(0.86, 0.61, 0.36, 0.72)
	parent.add_child(highlight)


func _add_front_slot(shelf: Node2D, slot_index: int) -> Node2D:
	var slot_number := slot_index + 1
	var slot := Node2D.new()
	slot.name = "Slot%02d" % slot_number
	slot.position = SLOT_POSITIONS[slot_index]
	shelf.add_child(slot)

	_add_polygon(slot, "SlotGuide", 5, Color(0.25, 0.74, 0.82, 0.22), PackedVector2Array([Vector2(-26, -76), Vector2(26, -76), Vector2(22, -8), Vector2(-22, -8)]))

	var marker := Marker2D.new()
	marker.name = "ItemSlot%02d" % slot_number
	marker.position = SLOT_ITEM_POSITION
	slot.add_child(marker)

	return slot


func _add_configured_layers(shelf: Node2D, layers: Array) -> void:
	for layer_index in range(layers.size()):
		var item_ids := layers[layer_index] as Array
		if item_ids == null:
			push_warning("%s layer %s is not an array." % [shelf.name, layer_index + 1])
			continue

		if item_ids.size() != SLOT_COUNT:
			push_warning("%s layer %s expected %s slots, found %s." % [shelf.name, layer_index + 1, SLOT_COUNT, item_ids.size()])

		var layer_slots := _get_front_slots(shelf) if layer_index == 0 else _add_back_layer(shelf, layer_index)
		var fill_count = mini(SLOT_COUNT, item_ids.size())
		for slot_index in range(fill_count):
			_add_configured_item(layer_slots[slot_index], item_ids[slot_index], layer_index, slot_index)


func _add_back_layer(shelf: Node2D, layer_index: int) -> Array[Node2D]:
	var layer := Node2D.new()
	layer.name = _get_back_layer_name(layer_index)
	layer.z_index = 4
	layer.visible = layer_index == FIRST_BACK_LAYER_INDEX
	shelf.add_child(layer)

	var layer_slots: Array[Node2D] = []
	for front_slot in _get_front_slots(shelf):
		layer_slots.append(_add_layer_slot(layer, front_slot))

	return layer_slots


func _add_configured_item(slot: Node2D, item_value, layer_index: int, slot_index: int) -> void:
	if item_value == null:
		return

	var item_id := str(item_value)
	if item_id.is_empty():
		return

	var item := ITEM_SCENE.instantiate() as ShelfItem
	item.name = "Item%sL%sS%s" % [item_id.to_pascal_case(), layer_index + 1, slot_index + 1]
	item.item_id = StringName(item_id)
	item.texture = _item_textures.get(item_id)
	if item.texture == null:
		push_warning("No texture configured for item '%s'." % item_id)

	item.position = SLOT_ITEM_POSITION
	slot.add_child(item)

	if layer_index > 0:
		_configure_back_layer_item(item, layer_index == FIRST_BACK_LAYER_INDEX)


func _collect_slots() -> void:
	_slots.clear()

	var shelves := get_node("Shelves")
	for shelf in shelves.get_children():
		for child in shelf.get_children():
			var slot := child as Node2D
			if slot != null and slot.name.begins_with("Slot"):
				_slots.append(slot)


func _get_back_layer_name(layer_index: int) -> String:
	return "%s%02d" % [BACK_LAYER_PREFIX, layer_index + 1]


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


func _configure_back_layer_item(item: ShelfItem, should_show: bool) -> void:
	item.z_index = 0
	item.modulate = back_layer_item_modulate if should_show else Color.TRANSPARENT
	item.input_pickable = false
	item.visual_scale *= back_layer_item_scale

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true


func _update_timer_label() -> void:
	var remaining_seconds := ceili(_time_remaining)
	var minutes := remaining_seconds / 60
	var seconds := remaining_seconds % 60
	_timer_label.text = "%02d:%02d" % [minutes, seconds]


func _update_level_label() -> void:
	_level_label.text = "Level %d" % selected_level


func _fail_level() -> void:
	_level_failed = true
	_clear_selected_item()
	_update_ability_buttons()

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
		if not _move_item_to_slot(item, _origin_slot, target_slot):
			_place_item_in_slot(item, _origin_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	get_viewport().set_input_as_handled()


func _move_item_to_slot(item: ShelfItem, origin_slot: Node2D, target_slot: Node2D) -> bool:
	if item == null or origin_slot == null or target_slot == null:
		return false

	if target_slot == origin_slot:
		_place_item_in_slot(item, origin_slot)
		return true

	if _get_slot_item(target_slot) != null:
		return false

	var shelves_to_check: Array[Node] = []
	_add_shelf_to_check(shelves_to_check, origin_slot)
	_add_shelf_to_check(shelves_to_check, target_slot)

	_place_item_in_slot(item, target_slot)

	_clear_matching_shelves(shelves_to_check)
	_promote_empty_front_layers(shelves_to_check)
	_refresh_ability_highlights()
	return true


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
		return null

	return _find_nearest_empty_slot(pointer_global_position)


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


func _find_nearest_empty_slot(pointer_global_position: Vector2) -> Node2D:
	var nearest_slot: Node2D
	var nearest_distance := slot_snap_distance

	for slot in _slots:
		if _get_slot_item(slot) != null:
			continue

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
	_apply_item_visual_state(item)


func _add_shelf_to_check(shelves_to_check: Array[Node], slot: Node2D) -> void:
	var shelf := _get_owning_shelf(slot)
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

			for item in shelf_items:
				_highlighted_items.erase(item)


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
	var next_layer := shelf.get_node_or_null(_get_back_layer_name(FIRST_BACK_LAYER_INDEX)) as Node2D
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
	_advance_back_layers(shelf)
	return true


func _advance_back_layers(shelf: Node2D) -> void:
	for layer_index in range(FIRST_BACK_LAYER_INDEX + 1, _max_layer_count):
		var layer := shelf.get_node_or_null(_get_back_layer_name(layer_index)) as Node2D
		if layer == null:
			continue

		layer.name = _get_back_layer_name(layer_index - 1)
		_configure_back_layer(layer, layer_index - 1)


func _configure_back_layer(layer: Node2D, layer_index: int) -> void:
	var should_show := layer_index == FIRST_BACK_LAYER_INDEX
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
	_apply_item_visual_state(item)


func _clear_selected_item() -> void:
	var previous_item := _selected_item

	_selected_item = null
	_selected_slot = null

	if previous_item != null and is_instance_valid(previous_item):
		_apply_item_visual_state(previous_item)


func _apply_item_visual_state(item: ShelfItem) -> void:
	var sprite := item.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	var is_selected := item == _selected_item
	var is_highlighted := _highlighted_items.has(item)
	if is_selected and is_highlighted:
		sprite.modulate = Color(1.24, 1.14, 0.54, 1.0)
	elif is_selected:
		sprite.modulate = Color(1.12, 1.12, 1.12, 1.0)
	elif is_highlighted:
		sprite.modulate = Color(1.0, 0.88, 0.24, 1.0)
	else:
		sprite.modulate = Color.WHITE


func _setup_ability_buttons() -> void:
	_register_ability_button(ABILITY_HAMMER, "UI/AbilityBar/HBoxContainer/HammerButton")
	_register_ability_button(ABILITY_SHUFFLE, "UI/AbilityBar/HBoxContainer/ShuffleButton")
	_register_ability_button(ABILITY_HIGHLIGHT, "UI/AbilityBar/HBoxContainer/HighlightButton")
	_register_ability_button(ABILITY_EXTRA_SHELF, "UI/AbilityBar/HBoxContainer/ShelfButton")


func _register_ability_button(ability_id: StringName, button_path: NodePath) -> void:
	var button := get_node_or_null(button_path) as Button
	if button == null:
		push_warning("Missing ability button: %s" % button_path)
		return

	_ability_buttons[ability_id] = button
	button.pressed.connect(_on_ability_button_pressed.bind(ability_id))


func _on_ability_button_pressed(ability_id: StringName) -> void:
	if _level_failed or int(_ability_uses.get(ability_id, 0)) <= 0:
		return

	_cancel_active_interaction()

	var did_apply := false
	match ability_id:
		ABILITY_HAMMER:
			did_apply = _use_hammer()
		ABILITY_SHUFFLE:
			did_apply = _use_shuffle()
		ABILITY_HIGHLIGHT:
			did_apply = _use_highlight()
		ABILITY_EXTRA_SHELF:
			did_apply = _use_extra_shelf()

	if not did_apply:
		return

	_ability_uses[ability_id] = int(_ability_uses.get(ability_id, 0)) - 1
	_update_ability_buttons()


func _cancel_active_interaction() -> void:
	_clear_selected_item()

	if _dragged_item != null and _origin_slot != null:
		_place_item_in_slot(_dragged_item, _origin_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	_pressed_item = null
	_pressed_origin_slot = null


func _use_hammer() -> bool:
	var items_by_type := {}
	for item in _get_visible_items():
		if item.item_id == &"":
			continue

		if not items_by_type.has(item.item_id):
			items_by_type[item.item_id] = []

		items_by_type[item.item_id].append(item)

	var candidate_ids: Array[StringName] = []
	for item_id in items_by_type.keys():
		var typed_items := items_by_type[item_id] as Array
		if typed_items.size() >= SLOT_COUNT:
			candidate_ids.append(item_id)

	if candidate_ids.is_empty():
		return false

	var chosen_id := candidate_ids[_rng.randi_range(0, candidate_ids.size() - 1)]
	var chosen_items := items_by_type[chosen_id] as Array
	_shuffle_array(chosen_items)

	var items_to_destroy: Array[ShelfItem] = []
	for item_index in range(SLOT_COUNT):
		items_to_destroy.append(chosen_items[item_index])

	_destroy_items(items_to_destroy)
	return true


func _use_shuffle() -> bool:
	var items := _get_all_items()
	if items.size() < 2:
		return false

	var item_ids: Array[StringName] = []
	for item in items:
		item_ids.append(item.item_id)

	_shuffle_array(item_ids)
	for item_index in range(items.size()):
		var item := items[item_index]
		var item_id := item_ids[item_index]
		item.item_id = item_id
		item.texture = _item_textures.get(String(item_id))
		_apply_item_visual_state(item)

	var shelves_to_check := _get_all_shelves()
	_clear_matching_shelves(shelves_to_check)
	_promote_empty_front_layers(shelves_to_check)
	_refresh_ability_highlights()
	return true


func _use_highlight() -> bool:
	var items_to_highlight := _find_immediate_triple_items()
	if items_to_highlight.is_empty():
		return false

	_clear_ability_highlights()
	_highlighted_items = items_to_highlight
	_highlight_timer = HIGHLIGHT_DURATION_SECONDS
	for item in _highlighted_items:
		_apply_item_visual_state(item)

	return true


func _use_extra_shelf() -> bool:
	if _extra_shelf_added:
		return false

	var shelves := get_node("Shelves") as Node2D
	var shelf_position := _get_extra_shelf_position(shelves)
	_add_shelf(shelves, shelves.get_child_count() + 1, shelf_position)
	_collect_slots()
	_extra_shelf_added = true
	return true


func _destroy_items(items_to_destroy: Array[ShelfItem]) -> void:
	var shelves_to_check: Array[Node] = []
	for item in items_to_destroy:
		if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
			continue

		var item_slot := item.get_parent() as Node2D
		if item_slot != null:
			_add_shelf_to_check(shelves_to_check, item_slot)

		_highlighted_items.erase(item)
		if item == _selected_item:
			_clear_selected_item()

		item.queue_free()

	_promote_empty_front_layers(shelves_to_check)
	_refresh_ability_highlights()


func _find_immediate_triple_items() -> Array[ShelfItem]:
	var visible_counts := {}
	for item in _get_visible_items():
		if not visible_counts.has(item.item_id):
			visible_counts[item.item_id] = 0

		visible_counts[item.item_id] = int(visible_counts[item.item_id]) + 1

	var triplable_ids := {}
	for shelf in _get_all_shelves():
		var shelf_items := _get_shelf_items(shelf)
		if shelf_items.size() != SLOT_COUNT - 1:
			continue

		var first_id := shelf_items[0].item_id
		if first_id == &"" or int(visible_counts.get(first_id, 0)) < SLOT_COUNT:
			continue

		if shelf_items.all(func(item: ShelfItem) -> bool: return item.item_id == first_id):
			triplable_ids[first_id] = true

	if triplable_ids.is_empty():
		return []

	var highlighted: Array[ShelfItem] = []
	for item in _get_visible_items():
		if triplable_ids.has(item.item_id):
			highlighted.append(item)

	return highlighted


func _update_highlight_timer(delta: float) -> void:
	if _highlight_timer <= 0.0:
		return

	_highlight_timer = maxf(_highlight_timer - delta, 0.0)
	if _highlight_timer <= 0.0:
		_clear_ability_highlights()


func _refresh_ability_highlights() -> void:
	if _highlight_timer <= 0.0:
		return

	var previous_items := _highlighted_items.duplicate()
	_highlighted_items = _find_immediate_triple_items()
	for item in previous_items:
		if item != null and is_instance_valid(item):
			_apply_item_visual_state(item)

	for item in _highlighted_items:
		if item != null and is_instance_valid(item):
			_apply_item_visual_state(item)


func _clear_ability_highlights() -> void:
	var previous_items := _highlighted_items.duplicate()
	_highlighted_items.clear()
	_highlight_timer = 0.0

	for item in previous_items:
		if item != null and is_instance_valid(item):
			_apply_item_visual_state(item)


func _update_ability_buttons() -> void:
	_update_ability_button(ABILITY_HAMMER, "Hammer")
	_update_ability_button(ABILITY_SHUFFLE, "Shuffle")
	_update_ability_button(ABILITY_HIGHLIGHT, "Find")
	_update_ability_button(ABILITY_EXTRA_SHELF, "Shelf")


func _reset_ability_uses() -> void:
	_ability_uses = {
		ABILITY_HAMMER: 3,
		ABILITY_SHUFFLE: 3,
		ABILITY_HIGHLIGHT: 3,
		ABILITY_EXTRA_SHELF: 1,
	}


func _update_ability_button(ability_id: StringName, label: String) -> void:
	var button := _ability_buttons.get(ability_id) as Button
	if button == null:
		return

	var uses_left := int(_ability_uses.get(ability_id, 0))
	button.text = "%s\n%d" % [label, uses_left]
	button.disabled = _level_failed or uses_left <= 0


func _get_all_shelves() -> Array[Node]:
	var shelves: Array[Node] = []
	for child in get_node("Shelves").get_children():
		shelves.append(child)

	return shelves


func _get_all_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for shelf in _get_all_shelves():
		_collect_items_recursive(shelf, items)

	return items


func _get_visible_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for shelf in _get_all_shelves():
		for item in _get_shelf_items(shelf):
			items.append(item)

	return items


func _collect_items_recursive(node: Node, items: Array[ShelfItem]) -> void:
	for child in node.get_children():
		var item := child as ShelfItem
		if item != null:
			if not item.is_queued_for_deletion():
				items.append(item)
			continue

		_collect_items_recursive(child, items)


func _get_owning_shelf(node: Node) -> Node:
	var current := node
	var shelves := get_node("Shelves")
	while current != null:
		if current.get_parent() == shelves:
			return current

		current = current.get_parent()

	return null


func _get_extra_shelf_position(shelves: Node2D) -> Vector2:
	var max_y := 0.0
	for child in shelves.get_children():
		var shelf := child as Node2D
		if shelf != null:
			max_y = maxf(max_y, shelf.position.y)

	return Vector2(0, max_y + 210.0)


func _shuffle_array(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temp = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temp
