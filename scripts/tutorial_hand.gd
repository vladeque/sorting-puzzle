class_name TutorialHand
extends Node2D

## A pointing glove that demonstrates one gesture on a loop: a tap, or a drag that carries a
## translucent copy of the item being moved.
##
## The node's origin is the fingertip. Placing the node puts the fingertip on the target, and the
## press scales the hand around that point, so it reads as the finger pushing down. A Node2D never
## receives GUI input, so the player can always act through the hand.
##
## Geometry lives in exported texel values rather than constants so replacing
## `assets/ui/tips/tutorial_hand.png` does not change code.

const MOTION_TWEEN_META := &"_tutorial_hand_motion_tween"
const FADE_TWEEN_META := &"_tutorial_hand_fade_tween"

## Fingertip in hand-texture pixels: the centre of the rounded tip just inside its outline.
@export var fingertip_texel := Vector2(75, 44)
## Visible artwork bounds in hand-texture pixels (alpha above 5%), used to keep other UI clear of it.
@export var artwork_texel_rect := Rect2(47, 38, 162, 180)
@export_range(0.5, 1.0, 0.01) var press_scale := 0.86
@export_range(0.0, 1.0, 0.01) var ghost_alpha := 0.72
@export var ripple_color := Color(1.0, 1.0, 1.0, 0.95)
@export var ripple_outline_color := Color(0.086, 0.125, 0.298, 0.55)
## Ripple radii and stroke in hand-texture pixels, so they scale with the hand.
@export var ripple_start_radius := 18.0
@export var ripple_end_radius := 70.0
@export var ripple_width := 7.0
@export_group("Timing")
@export var fade_seconds := 0.22
@export var press_seconds := 0.12
@export var release_seconds := 0.16
@export var tap_ripple_seconds := 0.5
@export var tap_rest_seconds := 0.62
@export var drag_travel_seconds := 0.78
@export var drag_rest_seconds := 0.45

var hand_scale := 1.0:
	set(value):
		hand_scale = maxf(value, 0.01)
		_apply_press()
		queue_redraw()

## 0 at rest, 1 fully pressed. A property so a tween can drive it.
var press_amount := 0.0:
	set(value):
		press_amount = value
		_apply_press()

## Below 0 the ripple is hidden; 0..1 runs it from start to end radius while it fades.
var ripple_progress := -1.0:
	set(value):
		ripple_progress = value
		queue_redraw()

var _hand_pivot: Node2D
var _hand_sprite: Sprite2D
var _ghost: Sprite2D


func _ready() -> void:
	_hand_pivot = get_node("Hand") as Node2D
	_hand_sprite = get_node("Hand/Sprite") as Sprite2D
	_ghost = get_node("Ghost") as Sprite2D
	_hand_sprite.centered = false
	_hand_sprite.position = -fingertip_texel
	_ghost.visible = false
	visible = false
	_apply_press()


func _draw() -> void:
	if ripple_progress < 0.0 or ripple_progress >= 1.0:
		return

	var eased := 1.0 - pow(1.0 - ripple_progress, 2.0)
	var radius := lerpf(ripple_start_radius, ripple_end_radius, eased) * hand_scale
	var fade := 1.0 - ripple_progress
	var width := ripple_width * hand_scale
	var outline := ripple_outline_color
	outline.a *= fade
	var fill := ripple_color
	fill.a *= fade
	# A thin dark rim under the white stroke keeps the ring visible on pale wall and glass alike.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, outline, width + 3.0 * hand_scale, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, fill, width, true)


## Taps `target` (a point in the parent's coordinates) on a loop until `stop()`.
func play_tap_loop(target: Vector2) -> void:
	_reset_pose()
	position = target
	modulate.a = 0.0
	visible = true
	var fade := UIMotion.retween(self, FADE_TWEEN_META)
	fade.tween_property(self, "modulate:a", 1.0, fade_seconds)
	var tween := UIMotion.retween(self, MOTION_TWEEN_META).set_loops()
	tween.tween_property(self, "press_amount", 1.0, press_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The ripple ends at progress 1, which `_draw()` treats as hidden until the next press.
	tween.tween_property(self, "ripple_progress", 1.0, tap_ripple_seconds).from(0.0)
	tween.parallel().tween_property(self, "press_amount", 0.0, release_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(tap_rest_seconds)


## Drags from `from` to `to` (points in the parent's coordinates) on a loop until `stop()`. The ghost
## is drawn at `ghost_scale` independent of the hand, so it matches the item on the board.
func play_drag_loop(from: Vector2, to: Vector2, ghost_texture: Texture2D, ghost_scale: Vector2) -> void:
	_reset_pose()
	UIMotion.stop_tween(self, FADE_TWEEN_META)
	_ghost.texture = ghost_texture
	_ghost.scale = ghost_scale
	_ghost.visible = ghost_texture != null
	position = from
	modulate.a = 0.0
	visible = true
	var tween := UIMotion.retween(self, MOTION_TWEEN_META).set_loops()
	tween.tween_callback(func() -> void:
		position = from
		_ghost.modulate.a = 0.0
	)
	tween.tween_property(self, "modulate:a", 1.0, fade_seconds)
	tween.tween_property(self, "press_amount", 1.0, press_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_ghost, "modulate:a", ghost_alpha, press_seconds)
	tween.tween_property(self, "position", to, drag_travel_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "press_amount", 0.0, release_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_ghost, "modulate:a", 0.0, release_seconds)
	tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
	tween.tween_interval(drag_rest_seconds)


## Hides the hand at once and stops every loop.
func stop() -> void:
	UIMotion.stop_tween(self, MOTION_TWEEN_META)
	UIMotion.stop_tween(self, FADE_TWEEN_META)
	_reset_pose()
	visible = false


## Fades out and stops. Used when the taught action happens, so the hand does not vanish mid-frame.
func fade_away() -> void:
	if not visible:
		return

	UIMotion.stop_tween(self, MOTION_TWEEN_META)
	var tween := UIMotion.retween(self, FADE_TWEEN_META)
	tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
	tween.tween_callback(stop)


## Advances the running loop by `seconds` and holds it there. Captures use this to show a stable
## mid-gesture frame instead of whatever the clock happened to reach.
func hold_at(seconds: float) -> void:
	for meta_key in [FADE_TWEEN_META, MOTION_TWEEN_META]:
		if not has_meta(meta_key):
			continue
		var tween := get_meta(meta_key) as Tween
		if tween != null and tween.is_valid():
			tween.pause()
			tween.custom_step(seconds)


## The hand's visible artwork at rest, in the parent's coordinates.
func get_artwork_rect() -> Rect2:
	return Rect2(
		position + (artwork_texel_rect.position - fingertip_texel) * hand_scale,
		artwork_texel_rect.size * hand_scale
	)


func _reset_pose() -> void:
	press_amount = 0.0
	ripple_progress = -1.0
	modulate.a = 1.0
	if _ghost != null:
		_ghost.visible = false
		_ghost.modulate.a = 0.0


func _apply_press() -> void:
	if _hand_pivot == null:
		return

	_hand_pivot.scale = Vector2.ONE * hand_scale * lerpf(1.0, press_scale, press_amount)
