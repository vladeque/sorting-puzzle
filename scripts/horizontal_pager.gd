class_name HorizontalPager
extends Control

signal page_changed(index: int)

const SNAP_DURATION := 0.32
const MAX_OVERSCROLL_FRACTION := 0.08
const DOT_SIZE_OFF := 6.0
const DOT_SIZE_ON := 18.0
const DOT_COLOR_OFF := Color(1.0, 1.0, 1.0, 0.35)
const DOT_COLOR_ON := Color(1.0, 0.86, 0.35, 1.0)

@export var peek_width := 16.0
@export var drag_start_distance := 12.0
@export var commit_fraction := 0.28

@onready var _clip: Control = %Clip
@onready var _track: Control = %Track
@onready var _prev_arrow: Button = %PrevArrow
@onready var _next_arrow: Button = %NextArrow
@onready var _dots: HBoxContainer = %Dots

var _pages: Array[Control] = []
var _dot_rects: Array[ColorRect] = []
var _current_index := 0
var _page_width := 1.0
var _pressed := false
var _drag_active := false
var _press_position := Vector2.ZERO
var _track_start_x := 0.0
var _active_tween: Tween


func _ready() -> void:
	resized.connect(_apply_layout)
	_prev_arrow.pressed.connect(_go_prev)
	_next_arrow.pressed.connect(_go_next)
	_apply_layout()
	_update_arrows()


func add_page(page: Control) -> void:
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_track.add_child(page)
	_pages.append(page)
	_add_dot()
	_apply_layout()
	_update_arrows()
	_update_dots()


func go_to_page(index: int, animate: bool = true) -> void:
	if _pages.is_empty():
		return
	_current_index = clampi(index, 0, _pages.size() - 1)
	_snap_to_current(animate)
	_update_arrows()
	_update_dots()
	page_changed.emit(_current_index)


func get_current_page() -> int:
	return _current_index


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_begin_press(mouse_event.position)
		else:
			_end_press(mouse_event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if _pressed:
			_update_pointer_motion((event as InputEventMouseMotion).position)
			accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_press(touch_event.position)
		else:
			_end_press(touch_event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		if _pressed:
			_update_pointer_motion((event as InputEventScreenDrag).position)
			accept_event()


func _begin_press(position: Vector2) -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_pressed = true
	_drag_active = false
	_press_position = position
	_track_start_x = _track.position.x


func _update_pointer_motion(position: Vector2) -> void:
	if not _pressed:
		return
	if not _drag_active:
		if position.distance_to(_press_position) < drag_start_distance:
			return
		_drag_active = true
	var delta := position.x - _press_position.x
	var overscroll := _page_width * MAX_OVERSCROLL_FRACTION
	var maximum_x := peek_width + overscroll
	var minimum_x := peek_width - float(maxi(_pages.size() - 1, 0)) * _page_width - overscroll
	_track.position.x = clampf(_track_start_x + delta, minimum_x, maximum_x)


func _end_press(position: Vector2) -> void:
	if not _pressed:
		return
	_pressed = false
	if not _drag_active:
		return
	_drag_active = false

	var delta := position.x - _press_position.x
	var threshold := _page_width * commit_fraction
	if delta <= -threshold and _current_index < _pages.size() - 1:
		go_to_page(_current_index + 1)
	elif delta >= threshold and _current_index > 0:
		go_to_page(_current_index - 1)
	else:
		_snap_to_current(true)


func _go_prev() -> void:
	go_to_page(_current_index - 1)


func _go_next() -> void:
	go_to_page(_current_index + 1)


func _apply_layout() -> void:
	_page_width = maxf(size.x - peek_width * 2.0, 1.0)
	for page_index in _pages.size():
		var page := _pages[page_index]
		page.position = Vector2(float(page_index) * _page_width, 0.0)
		page.size = Vector2(_page_width, _clip.size.y)
	_snap_to_current(false)


func _snap_to_current(animate: bool) -> void:
	var target_x := peek_width - float(_current_index) * _page_width
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	if not animate:
		_track.position.x = target_x
		return
	_active_tween = create_tween()
	_active_tween.tween_property(_track, "position:x", target_x, SNAP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_arrows() -> void:
	_prev_arrow.visible = _current_index > 0
	_next_arrow.visible = _current_index < _pages.size() - 1


func _add_dot() -> void:
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(DOT_SIZE_OFF, DOT_SIZE_OFF)
	dot.color = DOT_COLOR_OFF
	_dots.add_child(dot)
	_dot_rects.append(dot)


func _update_dots() -> void:
	for dot_index in _dot_rects.size():
		var dot := _dot_rects[dot_index]
		var is_current := dot_index == _current_index
		dot.custom_minimum_size = Vector2(DOT_SIZE_ON if is_current else DOT_SIZE_OFF, DOT_SIZE_OFF)
		dot.color = DOT_COLOR_ON if is_current else DOT_COLOR_OFF
