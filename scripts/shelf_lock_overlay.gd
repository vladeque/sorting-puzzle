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

const STANDARD_CHAIN_ARM_SCALE := Vector2(0.21, 0.21)
const COMPACT_CHAIN_ARM_SCALE := Vector2(0.085, 0.085)
const STANDARD_CHAIN_ARM_POSITION := Vector2(49, 17)
const COMPACT_CHAIN_ARM_POSITION := Vector2(19, 12)
const STANDARD_CHAIN_ARM_ROTATION := 0.32
const COMPACT_CHAIN_ARM_ROTATION := 0.52
const STANDARD_CHAIN_POSITION := Vector2(0, -17)
const COMPACT_CHAIN_POSITION := Vector2(0, -18)
const STANDARD_LOCK_POSITION := Vector2(0, -30)
const COMPACT_LOCK_POSITION := Vector2(0, -28)
const STANDARD_BADGE_POSITION := Vector2(0, -54)
const COMPACT_BADGE_POSITION := Vector2(0, -51)
const STANDARD_LOCK_SCALE := Vector2(1.08, 1.08)
const COMPACT_LOCK_SCALE := Vector2(0.76, 0.76)
const STANDARD_BADGE_SCALE := Vector2.ONE
const COMPACT_BADGE_SCALE := Vector2(0.74, 0.74)

const CHAIN_TENSION_DISTANCES := [3.0, -1.0, 0.0]
const CHAIN_TENSION_DURATIONS := [0.06, 0.06, 0.08]
const LOCK_SWING_ROTATIONS := [0.085, -0.065, 0.035, 0.0]
const LOCK_SWING_DURATIONS := [0.07, 0.08, 0.07, 0.08]
const BADGE_POP_SCALE := Vector2(1.22, 1.22)
const BADGE_POP_IN_SECONDS := 0.09
const BADGE_POP_OUT_SECONDS := 0.16
const UNLOCK_SHAKE_SECONDS := 0.14
const UNLOCK_RELEASE_SECONDS := 0.24
const STANDARD_UNLOCK_CHAIN_RETRACT := 18.0
const COMPACT_UNLOCK_CHAIN_RETRACT := 9.0
const UNLOCK_LOCK_DROP := Vector2(0, 34)
const UNLOCK_BADGE_LIFT := Vector2(0, -8)

@export var overlay_half_width := 104.0
@export var compact_layout := false

@onready var _shade := $Shade as Polygon2D
@onready var _chain_rig := $VisualRig/ChainRig as Node2D
@onready var _chain_top_left := $VisualRig/ChainRig/TopLeftArm as Sprite2D
@onready var _chain_top_right := $VisualRig/ChainRig/TopRightArm as Sprite2D
@onready var _chain_bottom_left := $VisualRig/ChainRig/BottomLeftArm as Sprite2D
@onready var _chain_bottom_right := $VisualRig/ChainRig/BottomRightArm as Sprite2D
@onready var _lock_rig := $VisualRig/LockRig as Node2D
@onready var _countdown_badge := $VisualRig/CountdownBadge as Node2D
@onready var _remaining_label := $VisualRig/CountdownBadge/RemainingLabel as Label

var _previous_remaining := -1
var _chain_base_position := Vector2.ZERO
var _chain_arms: Array[Sprite2D] = []
var _chain_arm_base_positions: Array[Vector2] = []
var _chain_arm_base_rotations: Array[float] = []
var _chain_arm_base_scales: Array[Vector2] = []
var _unlock_chain_retract_distance := STANDARD_UNLOCK_CHAIN_RETRACT
var _lock_base_position := Vector2.ZERO
var _lock_base_scale := Vector2.ONE
var _badge_base_position := Vector2.ZERO
var _badge_base_scale := Vector2.ONE


func _ready() -> void:
	_chain_arms.append(_chain_top_left)
	_chain_arms.append(_chain_top_right)
	_chain_arms.append(_chain_bottom_left)
	_chain_arms.append(_chain_bottom_right)
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
	tween.tween_callback(_reset_chain_arm_positions)
	tween.set_parallel(true)
	for index in range(_chain_arms.size()):
		var chain_arm := _chain_arms[index]
		var outward_direction := _chain_arm_base_positions[index].normalized()
		tween.tween_property(
			chain_arm,
			"position",
			_chain_arm_base_positions[index] + outward_direction * _unlock_chain_retract_distance,
			UNLOCK_RELEASE_SECONDS
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(chain_arm, "modulate:a", 0.0, UNLOCK_RELEASE_SECONDS) \
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

	var chain_scale := COMPACT_CHAIN_ARM_SCALE if compact_layout else STANDARD_CHAIN_ARM_SCALE
	var chain_position := (
		COMPACT_CHAIN_ARM_POSITION if compact_layout else STANDARD_CHAIN_ARM_POSITION
	)
	var chain_rotation := (
		COMPACT_CHAIN_ARM_ROTATION if compact_layout else STANDARD_CHAIN_ARM_ROTATION
	)
	_chain_rig.position = COMPACT_CHAIN_POSITION if compact_layout else STANDARD_CHAIN_POSITION
	_chain_top_left.position = Vector2(-chain_position.x, -chain_position.y)
	_chain_top_left.rotation = chain_rotation
	_chain_top_right.position = Vector2(chain_position.x, -chain_position.y)
	_chain_top_right.rotation = -chain_rotation
	_chain_bottom_left.position = Vector2(-chain_position.x, chain_position.y)
	_chain_bottom_left.rotation = -chain_rotation
	_chain_bottom_right.position = chain_position
	_chain_bottom_right.rotation = chain_rotation
	for chain_arm in _chain_arms:
		chain_arm.scale = chain_scale
	_unlock_chain_retract_distance = (
		COMPACT_UNLOCK_CHAIN_RETRACT if compact_layout else STANDARD_UNLOCK_CHAIN_RETRACT
	)

	_lock_rig.position = COMPACT_LOCK_POSITION if compact_layout else STANDARD_LOCK_POSITION
	_lock_rig.scale = COMPACT_LOCK_SCALE if compact_layout else STANDARD_LOCK_SCALE
	_countdown_badge.position = COMPACT_BADGE_POSITION if compact_layout else STANDARD_BADGE_POSITION
	_countdown_badge.scale = COMPACT_BADGE_SCALE if compact_layout else STANDARD_BADGE_SCALE

	_chain_base_position = _chain_rig.position
	_chain_arm_base_positions.clear()
	_chain_arm_base_rotations.clear()
	_chain_arm_base_scales.clear()
	for chain_arm in _chain_arms:
		_chain_arm_base_positions.append(chain_arm.position)
		_chain_arm_base_rotations.append(chain_arm.rotation)
		_chain_arm_base_scales.append(chain_arm.scale)
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
	for index in range(CHAIN_TENSION_DISTANCES.size()):
		chain_tween.tween_method(
			_set_chain_tension,
			0.0 if index == 0 else CHAIN_TENSION_DISTANCES[index - 1],
			CHAIN_TENSION_DISTANCES[index],
			CHAIN_TENSION_DURATIONS[index]
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


func _set_chain_tension(distance: float) -> void:
	for index in range(_chain_arms.size()):
		var inward_direction := -_chain_arm_base_positions[index].normalized()
		_chain_arms[index].position = (
			_chain_arm_base_positions[index] + inward_direction * distance
		)


func _reset_chain_arm_positions() -> void:
	for index in range(_chain_arms.size()):
		_chain_arms[index].position = _chain_arm_base_positions[index]


func _reset_animated_nodes() -> void:
	modulate = Color.WHITE
	scale = Vector2.ONE
	_chain_rig.position = _chain_base_position
	for index in range(_chain_arms.size()):
		var chain_arm := _chain_arms[index]
		chain_arm.position = _chain_arm_base_positions[index]
		chain_arm.rotation = _chain_arm_base_rotations[index]
		chain_arm.scale = _chain_arm_base_scales[index]
		chain_arm.modulate = Color.WHITE
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
