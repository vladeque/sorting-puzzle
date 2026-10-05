class_name HorizontalPager
extends Control

signal page_changed(index: int)

const SNAP_DURATION := 0.32
const MAX_OVERSCROLL_FRACTION := 0.08
const DOT_SIZE_OFF := 6.0
const DOT_SIZE_ON := 18.0
const DOT_STYLE_INACTIVE := preload("res://assets/themes/style_box_pager_dot_inactive.tres")
const DOT_STYLE_ACTIVE := preload("res://assets/themes/style_box_pager_dot_active.tres")
const DestinationScreenLayoutScript := preload("res://scripts/destination_screen_layout.gd")
## Authored offsets for %PrevArrow, %NextArrow, and %Dots before any additional device safe-area
## inset is applied through set_safe_margins().
const PREV_ARROW_BASE_OFFSET_LEFT := 2.0
const PREV_ARROW_BASE_OFFSET_RIGHT := 62.0
const NEXT_ARROW_BASE_OFFSET_LEFT := -62.0
const NEXT_ARROW_BASE_OFFSET_RIGHT := -2.0
const DOTS_BASE_OFFSET_TOP := -18.0
const DOTS_BASE_OFFSET_BOTTOM := -10.0

@export var peek_width := 16.0
@export var drag_start_distance := 12.0
@export var commit_fraction := 0.28

@onready var _clip: Control = %Clip
@onready var _track: Control = %Track
@onready var _prev_arrow: Button = %PrevArrow
@onready var _next_arrow: Button = %NextArrow
@onready var _dots: HBoxContainer = %Dots

var _pages: Array[Control] = []
var _dot_rects: Array[Panel] = []
var _current_index := 0
var _page_width := 1.0
var _pressed := false
var _drag_active := false
var _press_position := Vector2.ZERO
var _track_start_x := 0.0
var _active_tween: Tween
var _safe_margins := Vector4.ZERO


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


## Insets %PrevArrow/%NextArrow/%Dots by the given device safe-area margin (left/top/right/bottom)
## on top of their authored offsets. %Clip/%Track and the pages themselves are left untouched, so
## full-bleed page content (such as a chapter cover's background art) is unaffected. Defaults to
## Vector4.ZERO, a no-op, so every other consumer of this generic pager is unaffected unless it
## opts in.
func set_safe_margins(margins: Vector4) -> void:
	_safe_margins = margins
	margins = DestinationScreenLayoutScript.logical_safe_margins(self, margins)
	_prev_arrow.offset_left = PREV_ARROW_BASE_OFFSET_LEFT + margins.x
	_prev_arrow.offset_right = PREV_ARROW_BASE_OFFSET_RIGHT + margins.x
	_next_arrow.offset_left = NEXT_ARROW_BASE_OFFSET_LEFT - margins.z
	_next_arrow.offset_right = NEXT_ARROW_BASE_OFFSET_RIGHT - margins.z
	_dots.offset_top = DOTS_BASE_OFFSET_TOP - margins.w
	_dots.offset_bottom = DOTS_BASE_OFFSET_BOTTOM - margins.w


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
	var last_x := peek_width - _direction_sign() * float(maxi(_pages.size() - 1, 0)) * _page_width
	var maximum_x := maxf(peek_width, last_x) + overscroll
	var minimum_x := minf(peek_width, last_x) - overscroll
	_track.position.x = clampf(_track_start_x + delta, minimum_x, maximum_x)


func _end_press(position: Vector2) -> void:
	if not _pressed:
		return
	_pressed = false
	if not _drag_active:
		return
	_drag_active = false

	var delta := (position.x - _press_position.x) * _direction_sign()
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
	_pressed = false
	_drag_active = false
	_page_width = maxf(size.x - peek_width * 2.0, 1.0)
	for page_index in _pages.size():
		var page := _pages[page_index]
		page.size = Vector2(_page_width, _clip.size.y)
		page.position = Vector2(_direction_sign() * float(page_index) * _page_width, 0.0)
	_snap_to_current(false)
	_prev_arrow.text_direction = Control.TEXT_DIRECTION_LTR
	_next_arrow.text_direction = Control.TEXT_DIRECTION_LTR
	_prev_arrow.text = ">" if is_layout_rtl() else "<"
	_next_arrow.text = "<" if is_layout_rtl() else ">"
	set_safe_margins(_safe_margins)


func _direction_sign() -> float:
	return -1.0 if is_layout_rtl() else 1.0


func _notification(what: int) -> void:
	if what in [NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_LAYOUT_DIRECTION_CHANGED] and is_node_ready():
		_apply_layout.call_deferred()


func _snap_to_current(animate: bool) -> void:
	var target_x := peek_width - _direction_sign() * float(_current_index) * _page_width
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
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(DOT_SIZE_OFF, DOT_SIZE_OFF)
	dot.add_theme_stylebox_override("panel", DOT_STYLE_INACTIVE)
	_dots.add_child(dot)
	_dot_rects.append(dot)


func _update_dots() -> void:
	for dot_index in _dot_rects.size():
		var dot := _dot_rects[dot_index]
		var is_current := dot_index == _current_index
		dot.custom_minimum_size = Vector2(DOT_SIZE_ON if is_current else DOT_SIZE_OFF, DOT_SIZE_OFF)
		dot.add_theme_stylebox_override("panel", DOT_STYLE_ACTIVE if is_current else DOT_STYLE_INACTIVE)
