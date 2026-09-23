class_name ThrowingDispenser
extends Node2D

## One tappable dispenser mounted above the board. It holds an authored, ordered list of items and
## hands the next few out when the player taps it; `scripts/level.gd` decides where they land.
##
## Like `ShelfLockOverlay`'s `AD` plate, this reports *intent only*. A tap emits `throw_requested`
## and nothing else: whether a throw may happen at all depends on the board's free slots, on whether
## the level is paused or resolving, and on the reserved-slot rule, none of which a dispenser can
## see. `scripts/level.gd` answers the signal and calls `take()` if it decides to.
##
## Not to be confused with `DispenserShelf` (`"type": "dispenser"`), which is a narrow source-only
## *shelf* the player drags items off. The two never appear in the same level.

signal throw_requested

const POINTER_NONE := -2
const POINTER_MOUSE := -1

## Drawing bounds, used by the rack to lay dispensers out and by the level's responsive fit. Wider
## than the body so the count badge in the top-right corner stays on screen.
const VISUAL_BOUNDS := Rect2(-66.0, -62.0, 132.0, 118.0)

## The tap target. Deliberately the whole body rather than a small button: this is a touch game and
## the dispenser is the only thing to hit up here, so a generous rect costs nothing.
const TAP_RECT := Rect2(-56.0, -52.0, 112.0, 100.0)

const REFUSAL_SHAKE_OFFSET := 7.0
const REFUSAL_SHAKE_SECONDS := 0.32
const THROW_RECOIL_SECONDS := 0.16
const THROW_RECOIL_SCALE := Vector2(0.9, 1.12)

## Stock is data, not nodes, until it is thrown. An item that has not been handed out yet has no
## `ShelfItem`, which is what keeps `_get_all_items()`, Hammer, and Shuffle from reaching into a
## dispenser without any of them needing to know it exists.
var _contents: PackedStringArray = PackedStringArray()
var _throw_count := 1
var _tap_pointer_id := POINTER_NONE
var _input_enabled := true
var _body: Node2D
var _count_label: Label
var _mouth: Marker2D
var _refusal_tween: Tween
var _recoil_tween: Tween


func _ready() -> void:
	_body = get_node_or_null("Body") as Node2D
	_count_label = get_node_or_null("CountBadge/RemainingLabel") as Label
	_mouth = get_node_or_null("Mouth") as Marker2D
	set_process_input(_input_enabled)
	_refresh_count()


func configure(contents: PackedStringArray, throw_count: int) -> void:
	_contents = contents.duplicate()
	_throw_count = maxi(throw_count, 1)
	_refresh_count()


## How many items this dispenser would like to hand out per tap. The level clamps it to the room the
## board actually has; see `ThrowingDispenserRules.RESERVED_FREE_SLOTS`.
func get_throw_count() -> int:
	return _throw_count


func get_remaining_count() -> int:
	return _contents.size()


func is_empty() -> bool:
	return _contents.is_empty()


## Reads the next items without handing them out, so the level can look at what is coming before it
## has decided whether the throw is allowed.
func peek(count: int) -> PackedStringArray:
	var taken := PackedStringArray()
	for index in range(mini(maxi(count, 0), _contents.size())):
		taken.append(_contents[index])

	return taken


## Hands out the next `count` items for good. Called once per committed throw.
func take(count: int) -> PackedStringArray:
	var taken := peek(count)
	for _index in range(taken.size()):
		_contents.remove_at(0)

	_refresh_count()
	return taken


func get_mouth_global_position() -> Vector2:
	return _mouth.global_position if _mouth != null else global_position


func get_visual_bounds() -> Rect2:
	return VISUAL_BOUNDS


func get_tap_global_rect() -> Rect2:
	return get_global_transform() * TAP_RECT


## The level switches taps off while it is paused, resolving, or running an ability, the same way it
## already gates pointer input on the board.
func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_tap_pointer_id = POINTER_NONE
	set_process_input(enabled)


## A short squash on a committed throw. Fire-and-forget: the items are already on their way, and the
## level never waits on this.
func play_throw() -> void:
	if _body == null:
		return

	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	_body.scale = THROW_RECOIL_SCALE
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_body, "scale", Vector2.ONE, THROW_RECOIL_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A tap that cannot throw -- no room on the board, or nothing left to hand out. The shake is the
## whole feedback: refusing silently reads as a broken button.
func play_refused() -> void:
	if _body == null:
		return

	if _refusal_tween != null and _refusal_tween.is_valid():
		_refusal_tween.kill()
	_body.position.x = 0.0
	_refusal_tween = create_tween()
	var step := REFUSAL_SHAKE_SECONDS / 4.0
	_refusal_tween.tween_property(_body, "position:x", -REFUSAL_SHAKE_OFFSET, step)
	_refusal_tween.tween_property(_body, "position:x", REFUSAL_SHAKE_OFFSET, step)
	_refusal_tween.tween_property(_body, "position:x", -REFUSAL_SHAKE_OFFSET * 0.5, step)
	_refusal_tween.tween_property(_body, "position:x", 0.0, step)


func _input(event: InputEvent) -> void:
	if not _input_enabled or not is_visible_in_tree():
		return
	# Native touch and mouse are both handled below; their synthesized counterparts are duplicates.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.canceled:
			_tap_pointer_id = POINTER_NONE
		elif mouse_event.pressed:
			_begin_tap(get_global_mouse_position(), POINTER_MOUSE)
		else:
			_finish_tap(get_global_mouse_position(), POINTER_MOUSE)
	elif event is InputEventMouseMotion:
		_cancel_tap_outside(get_global_mouse_position(), POINTER_MOUSE)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		var touch_position := _screen_position_to_global(touch_event.position)
		if touch_event.canceled:
			if _tap_pointer_id == touch_event.index:
				_tap_pointer_id = POINTER_NONE
		elif touch_event.pressed:
			_begin_tap(touch_position, touch_event.index)
		else:
			_finish_tap(touch_position, touch_event.index)
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_cancel_tap_outside(_screen_position_to_global(drag_event.position), drag_event.index)


## Marking the press handled keeps it from also reaching the board underneath, where it would count
## as a click on empty space and deselect the item the player is carrying.
func _begin_tap(pointer_global_position: Vector2, pointer_id: int) -> void:
	if _tap_pointer_id != POINTER_NONE:
		return
	if not get_tap_global_rect().has_point(pointer_global_position):
		return

	_tap_pointer_id = pointer_id
	get_viewport().set_input_as_handled()


## A press that wanders off the dispenser before release is a cancelled tap, matching how every
## other button in the game behaves.
func _finish_tap(pointer_global_position: Vector2, pointer_id: int) -> void:
	if _tap_pointer_id != pointer_id:
		return

	_tap_pointer_id = POINTER_NONE
	if not get_tap_global_rect().has_point(pointer_global_position):
		return

	get_viewport().set_input_as_handled()
	throw_requested.emit()


func _cancel_tap_outside(pointer_global_position: Vector2, pointer_id: int) -> void:
	if _tap_pointer_id != pointer_id:
		return
	if not get_tap_global_rect().has_point(pointer_global_position):
		_tap_pointer_id = POINTER_NONE


func _screen_position_to_global(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _refresh_count() -> void:
	if _count_label != null:
		_count_label.text = str(_contents.size())
