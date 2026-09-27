class_name GameplayTipOverlay
extends Control

## Screen-space view for one first-time gameplay tip: a demonstrating hand and an optional message
## bubble (docs/GAMEPLAY_TIPS.md).
##
## It knows nothing about shelves or dispensers. `scripts/level.gd` decides which tip applies, hands
## over screen points every frame through `update_move()` / `update_tap()`, suspends it whenever
## anything else owns the screen, and calls `finish()` when the player does the taught action. This
## script owns only timing and presentation: the start and reshow delays, restarting the loop when its
## anchors move, and keeping the bubble clear of the hand.
##
## Every node here ignores the pointer. Board and dispenser input run in the level's `_input()`, ahead
## of GUI, so the player can always act straight through the tip.

enum Mode { NONE, MOVE, TAP }

## Anchors that move less than this keep the running loop instead of restarting it.
const ANCHOR_RESTART_DISTANCE := 3.0
const HAND_SCALE_RESTART_RATIO := 0.02

@export var bubble_gap := 14.0

var _hand: TutorialHand
var _bubble: GameplayTipBubble
var _active := false
var _suspended := true
var _playing := false
var _has_played := false
var _delay_remaining := 0.0
var _start_delay := 0.0
var _reshow_delay := 0.0

var _mode := Mode.NONE
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _ghost_texture: Texture2D
var _ghost_scale := Vector2.ONE
var _hand_scale := 1.0
var _bubble_center_x := 0.0
var _bubble_bounds := Rect2()

var _playing_mode := Mode.NONE
var _playing_from := Vector2.ZERO
var _playing_to := Vector2.ZERO
var _playing_hand_scale := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand = get_node("Hand") as TutorialHand
	_bubble = get_node("Bubble") as GameplayTipBubble


func _process(delta: float) -> void:
	if not _active or _suspended or _mode == Mode.NONE:
		return

	if _playing:
		if _anchors_moved():
			_start_animation()
		elif _bubble.visible:
			_place_bubble()
		return

	_delay_remaining -= delta
	if _delay_remaining <= 0.0:
		_start_animation()


## Starts a new tip. It stays hidden until the level supplies anchors, unsuspends it, and the start
## delay has run.
func begin(start_delay: float, reshow_delay: float, message: String = "") -> void:
	clear()
	_active = true
	_start_delay = maxf(start_delay, 0.0)
	_reshow_delay = maxf(reshow_delay, 0.0)
	_delay_remaining = _start_delay
	_bubble.set_message(message)


## Drops the tip at once, without a fade: used when the board is rebuilt.
func clear() -> void:
	_active = false
	_suspended = true
	_playing = false
	_has_played = false
	_mode = Mode.NONE
	_playing_mode = Mode.NONE
	_hand.stop()
	_bubble.hide_bubble(false)
	_bubble.set_message("")


## The taught action happened: fade out and never come back for this tip.
func finish() -> void:
	if not _active:
		return

	_active = false
	_playing = false
	_hand.fade_away()
	if _bubble.visible:
		_bubble.hide_bubble(true)


func is_active() -> bool:
	return _active


func is_showing() -> bool:
	return _playing and _hand.visible


func get_hand() -> TutorialHand:
	return _hand


func get_bubble() -> GameplayTipBubble:
	return _bubble


## Suspended tips hide at once and come back `reshow_delay` after the level is idle again (or
## `start_delay`, if they had not appeared yet).
func set_suspended(suspended: bool) -> void:
	if suspended == _suspended:
		return

	_suspended = suspended
	if not suspended or not _active:
		return

	_playing = false
	_hand.stop()
	_bubble.hide_bubble(false)
	_delay_remaining = _reshow_delay if _has_played else _start_delay


## Demonstrates dragging an item from `from` to `to` (both in this overlay's coordinates).
func update_move(
	from: Vector2, to: Vector2, ghost_texture: Texture2D, ghost_scale: Vector2, hand_scale: float
) -> void:
	_mode = Mode.MOVE
	_from = from
	_to = to
	_ghost_texture = ghost_texture
	_ghost_scale = ghost_scale
	_hand_scale = hand_scale


## Demonstrates tapping `target`. The bubble, if the tip has a message, is centred on
## `bubble_center_x` below the hand and kept inside `bubble_bounds`.
func update_tap(target: Vector2, hand_scale: float, bubble_center_x: float, bubble_bounds: Rect2) -> void:
	_mode = Mode.TAP
	_from = target
	_to = target
	_hand_scale = hand_scale
	_bubble_center_x = bubble_center_x
	_bubble_bounds = bubble_bounds


## Holds the running hand loop `seconds` in, for stable captures.
func hold_at(seconds: float) -> void:
	_hand.hold_at(seconds)


func _start_animation() -> void:
	_playing = true
	_has_played = true
	_playing_mode = _mode
	_playing_from = _from
	_playing_to = _to
	_playing_hand_scale = _hand_scale
	_hand.hand_scale = _hand_scale
	if _mode == Mode.MOVE:
		_hand.play_drag_loop(_from, _to, _ghost_texture, _ghost_scale)
	else:
		_hand.play_tap_loop(_from)

	if _bubble.has_message():
		_place_bubble()
		_bubble.show_bubble()


func _anchors_moved() -> bool:
	return (
		_mode != _playing_mode
		or _from.distance_to(_playing_from) > ANCHOR_RESTART_DISTANCE
		or _to.distance_to(_playing_to) > ANCHOR_RESTART_DISTANCE
		or absf(_hand_scale - _playing_hand_scale) > _playing_hand_scale * HAND_SCALE_RESTART_RATIO
	)


## The tail points straight up at the target; the panel sits below everything the hand covers
## during its gesture.
func _place_bubble() -> void:
	var hand_rect := Rect2(
		_playing_from + (_hand.artwork_texel_rect.position - _hand.fingertip_texel) * _hand_scale,
		_hand.artwork_texel_rect.size * _hand_scale
	)
	var covered := hand_rect.merge(Rect2(hand_rect.position + (_playing_to - _playing_from), hand_rect.size))
	var bounds := _bubble_bounds
	if not bounds.has_area():
		bounds = Rect2(Vector2.ZERO, size)
	var center_x := _bubble_center_x if _bubble_bounds.has_area() else _playing_from.x
	_bubble.place(Vector2(_playing_from.x, covered.end.y + bubble_gap), center_x, bounds)
