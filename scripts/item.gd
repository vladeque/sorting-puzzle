@tool
class_name ShelfItem
extends Area2D

signal drag_started(item: ShelfItem, pointer_global_position: Vector2)
signal drag_moved(item: ShelfItem, pointer_global_position: Vector2)
signal drag_ended(item: ShelfItem, pointer_global_position: Vector2)

@export var item_id: StringName = &""

@export var texture: Texture2D:
	set(value):
		texture = value
		_apply_texture()

@export_range(0.1, 2.0, 0.01) var visual_scale: float = 0.34:
	set(value):
		visual_scale = value
		_apply_visual_scale()

var _is_dragging := false


func _ready() -> void:
	_apply_texture()
	_apply_visual_scale()


func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_start_drag(get_global_mouse_position(), viewport)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_start_drag(_screen_position_to_global(touch_event.position), viewport)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _is_dragging:
		return

	if event is InputEventMouseMotion:
		drag_moved.emit(self, get_global_mouse_position())
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		drag_moved.emit(self, _screen_position_to_global(drag_event.position))
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_drag(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if not touch_event.pressed:
			_finish_drag(_screen_position_to_global(touch_event.position))


func cancel_drag() -> void:
	_is_dragging = false


func _apply_texture() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	sprite.texture = texture


func _apply_visual_scale() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	sprite.scale = Vector2.ONE * visual_scale


func _start_drag(pointer_global_position: Vector2, viewport: Viewport) -> void:
	_is_dragging = true
	drag_started.emit(self, pointer_global_position)
	viewport.set_input_as_handled()


func _finish_drag(pointer_global_position: Vector2) -> void:
	_is_dragging = false
	drag_ended.emit(self, pointer_global_position)


func _screen_position_to_global(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position
