class_name ShelfLockOverlay
extends Node2D

## Reusable visual owner for triple-gated shelves. `scripts/level.gd` supplies only the remaining
## clear count and the locked/unlocked state; this component owns its chain, badge, lock, and all
## feedback motion.

const UIMotionScript := preload("res://scripts/ui_motion.gd")

const CHAIN_SHAKE_TWEEN_META := &"shelf_lock_chain_shake_tween"
const LOCK_SWING_TWEEN_META := &"shelf_lock_swing_tween"
const BADGE_POP_TWEEN_META := &"shelf_lock_badge_pop_tween"
const UNLOCK_TWEEN_META := &"shelf_lock_unlock_tween"

const STANDARD_CHAIN_SCALE := Vector2(0.45, 0.45)
const COMPACT_CHAIN_SCALE := Vector2(0.20, 0.28)
const STANDARD_CHAIN_ROTATION := 0.34
const COMPACT_CHAIN_ROTATION := 0.48
const STANDARD_CHAIN_POSITION := Vector2(0, -17)
const COMPACT_CHAIN_POSITION := Vector2(0, -18)
const STANDARD_LOCK_POSITION := Vector2(0, -30)
const COMPACT_LOCK_POSITION := Vector2(0, -28)
const STANDARD_BADGE_POSITION := Vector2(0, -54)
const COMPACT_BADGE_POSITION := Vector2(0, -51)
const STANDARD_LOCK_SCALE := Vector2.ONE
const COMPACT_LOCK_SCALE := Vector2(0.72, 0.72)
const STANDARD_BADGE_SCALE := Vector2.ONE
const COMPACT_BADGE_SCALE := Vector2(0.74, 0.74)

const SHAKE_OFFSETS := [-3.0, 3.0, -2.0, 1.0, 0.0]
const SHAKE_DURATIONS := [0.045, 0.065, 0.055, 0.045, 0.04]
const LOCK_SWING_ROTATIONS := [0.085, -0.065, 0.035, 0.0]
const LOCK_SWING_DURATIONS := [0.07, 0.08, 0.07, 0.08]
const BADGE_POP_SCALE := Vector2(1.22, 1.22)
const BADGE_POP_IN_SECONDS := 0.09
const BADGE_POP_OUT_SECONDS := 0.16
const UNLOCK_SHAKE_SECONDS := 0.14
const UNLOCK_RELEASE_SECONDS := 0.24
const UNLOCK_CHAIN_RECOIL := Vector2(14, -5)
const UNLOCK_LOCK_DROP := Vector2(0, 34)
const UNLOCK_BADGE_LIFT := Vector2(0, -8)

@export var overlay_half_width := 104.0
@export var compact_layout := false

@onready var _shade := $Shade as Polygon2D
@onready var _chain_rig := $VisualRig/ChainRig as Node2D
@onready var _chain_back := $VisualRig/ChainRig/ChainBack as Sprite2D
@onready var _chain_front := $VisualRig/ChainRig/ChainFront as Sprite2D
@onready var _lock_rig := $VisualRig/LockRig as Node2D
@onready var _countdown_badge := $VisualRig/CountdownBadge as Node2D
@onready var _remaining_label := $VisualRig/CountdownBadge/RemainingLabel as Label

var _previous_remaining := -1
var _chain_base_position := Vector2.ZERO
var _lock_base_position := Vector2.ZERO
var _lock_base_scale := Vector2.ONE
var _badge_base_position := Vector2.ZERO
var _badge_base_scale := Vector2.ONE


func _ready() -> void:
	_apply_layout()
	_reset_animated_nodes()


## Shows a locked state and animates only genuine countdown decreases. Initial configuration and a
## reused overlay start cleanly without playing feedback from stale state.
func show_locked(remaining: int) -> void:
	var next_remaining := maxi(remaining, 0)
	var should_animate := visible and _previous_remaining >= 0 and next_remaining < _previous_remaining

	_stop_all_tweens()
	_reset_animated_nodes()
	visible = true
	_set_remaining_text(next_remaining)

	if should_animate:
		_play_decrement_feedback()

	_previous_remaining = next_remaining


## The owning level makes the shelf interactable before calling this method. The visual release is
## deliberately fire-and-forget so chain motion can never delay gameplay availability.
func play_unlock() -> void:
	if not visible:
		return

	_stop_all_tweens()
	_reset_animated_nodes()
	_set_remaining_text(0)
	_previous_remaining = 0
	_play_decrement_feedback()

	var tween := UIMotionScript.retween(self, UNLOCK_TWEEN_META)
	tween.tween_interval(UNLOCK_SHAKE_SECONDS)
	tween.tween_callback(_stop_feedback_tweens)
	tween.set_parallel(true)
	tween.tween_property(
		_chain_back,
		"position",
		-UNLOCK_CHAIN_RECOIL,
		UNLOCK_RELEASE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		_chain_front,
		"position",
		UNLOCK_CHAIN_RECOIL,
		UNLOCK_RELEASE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_chain_back, "modulate:a", 0.0, UNLOCK_RELEASE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_chain_front, "modulate:a", 0.0, UNLOCK_RELEASE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(
		_lock_rig,
		"position",
		_lock_base_position + UNLOCK_LOCK_DROP,
		UNLOCK_RELEASE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_lock_rig, "rotation", 0.16, UNLOCK_RELEASE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_lock_rig, "modulate:a", 0.0, UNLOCK_RELEASE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(
		_countdown_badge,
		"position",
		_badge_base_position + UNLOCK_BADGE_LIFT,
		UNLOCK_RELEASE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_countdown_badge, "modulate:a", 0.0, UNLOCK_RELEASE_SECONDS * 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_shade, "modulate:a", 0.0, UNLOCK_RELEASE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(_finish_unlock)


func reset_visual_state() -> void:
	_stop_all_tweens()
	_reset_animated_nodes()
	_previous_remaining = -1


func _apply_layout() -> void:
	_shade.polygon = PackedVector2Array([
		Vector2(-overlay_half_width, -81),
		Vector2(overlay_half_width, -81),
		Vector2(overlay_half_width, 46),
		Vector2(-overlay_half_width, 46),
	])

	var chain_scale := COMPACT_CHAIN_SCALE if compact_layout else STANDARD_CHAIN_SCALE
	var chain_rotation := COMPACT_CHAIN_ROTATION if compact_layout else STANDARD_CHAIN_ROTATION
	_chain_rig.position = COMPACT_CHAIN_POSITION if compact_layout else STANDARD_CHAIN_POSITION
	_chain_back.scale = chain_scale
	_chain_back.rotation = -chain_rotation
	_chain_front.scale = chain_scale
	_chain_front.rotation = chain_rotation

	_lock_rig.position = COMPACT_LOCK_POSITION if compact_layout else STANDARD_LOCK_POSITION
	_lock_rig.scale = COMPACT_LOCK_SCALE if compact_layout else STANDARD_LOCK_SCALE
	_countdown_badge.position = COMPACT_BADGE_POSITION if compact_layout else STANDARD_BADGE_POSITION
	_countdown_badge.scale = COMPACT_BADGE_SCALE if compact_layout else STANDARD_BADGE_SCALE

	_chain_base_position = _chain_rig.position
	_lock_base_position = _lock_rig.position
	_lock_base_scale = _lock_rig.scale
	_badge_base_position = _countdown_badge.position
	_badge_base_scale = _countdown_badge.scale


func _set_remaining_text(remaining: int) -> void:
	var remaining_text := str(remaining)
	_remaining_label.text = remaining_text

	var font_size := 26
	if remaining_text.length() >= 3:
		font_size = 17
	elif remaining_text.length() == 2:
		font_size = 22
	_remaining_label.add_theme_font_size_override("font_size", font_size)


func _play_decrement_feedback() -> void:
	var chain_tween := UIMotionScript.retween(_chain_rig, CHAIN_SHAKE_TWEEN_META)
	for index in range(SHAKE_OFFSETS.size()):
		chain_tween.tween_property(
			_chain_rig,
			"position:x",
			_chain_base_position.x + SHAKE_OFFSETS[index],
			SHAKE_DURATIONS[index]
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var lock_tween := UIMotionScript.retween(_lock_rig, LOCK_SWING_TWEEN_META)
	for index in range(LOCK_SWING_ROTATIONS.size()):
		lock_tween.tween_property(
			_lock_rig,
			"rotation",
			LOCK_SWING_ROTATIONS[index],
			LOCK_SWING_DURATIONS[index]
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var badge_tween := UIMotionScript.retween(_countdown_badge, BADGE_POP_TWEEN_META)
	badge_tween.tween_property(
		_countdown_badge,
		"scale",
		_badge_base_scale * BADGE_POP_SCALE,
		BADGE_POP_IN_SECONDS
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	badge_tween.tween_property(
		_countdown_badge,
		"scale",
		_badge_base_scale,
		BADGE_POP_OUT_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _stop_all_tweens() -> void:
	UIMotionScript.stop_tween(self, UNLOCK_TWEEN_META)
	_stop_feedback_tweens()


func _stop_feedback_tweens() -> void:
	UIMotionScript.stop_tween(_chain_rig, CHAIN_SHAKE_TWEEN_META)
	UIMotionScript.stop_tween(_lock_rig, LOCK_SWING_TWEEN_META)
	UIMotionScript.stop_tween(_countdown_badge, BADGE_POP_TWEEN_META)


func _reset_animated_nodes() -> void:
	modulate = Color.WHITE
	scale = Vector2.ONE
	_chain_rig.position = _chain_base_position
	_chain_back.position = Vector2.ZERO
	_chain_back.modulate = Color.WHITE
	_chain_front.position = Vector2.ZERO
	_chain_front.modulate = Color.WHITE
	_lock_rig.position = _lock_base_position
	_lock_rig.rotation = 0.0
	_lock_rig.scale = _lock_base_scale
	_lock_rig.modulate = Color.WHITE
	_countdown_badge.position = _badge_base_position
	_countdown_badge.scale = _badge_base_scale
	_countdown_badge.modulate = Color.WHITE
	_shade.modulate = Color.WHITE


func _finish_unlock() -> void:
	visible = false
	_reset_animated_nodes()
	_previous_remaining = -1
