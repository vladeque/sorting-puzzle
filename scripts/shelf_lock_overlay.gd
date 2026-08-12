class_name ShelfLockOverlay
extends Node2D

## Reusable visual owner for triple-gated shelves. `scripts/level.gd` supplies only the remaining
## clear count and the locked/unlocked state; this component owns its wall-attached chains, badge,
## lock, and all feedback motion.

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")

const CHAIN_TENSION_TWEEN_META := &"shelf_lock_chain_tension_tween"
const LOCK_SWING_TWEEN_META := &"shelf_lock_swing_tween"
const BADGE_POP_TWEEN_META := &"shelf_lock_badge_pop_tween"
const UNLOCK_TWEEN_META := &"shelf_lock_unlock_tween"

## Selected C2-7A has 6px of transparent horizontal padding on each side of its 512px canvas.
## Geometry uses the visible 500px span so authored endpoints meet walls and the lock shackle.
const CHAIN_ARM_VISIBLE_WIDTH := 500.0
const WALL_COVER_DEPTH := 8.0
const WALL_COVER_TOP := -89.0
const WALL_COVER_BOTTOM := 46.0
const STANDARD_CHAIN_THICKNESS_SCALE := 0.34
const COMPACT_CHAIN_THICKNESS_SCALE := 0.145
## X is a signed offset from the matching shelf side; Y is local to the overlay. These endpoints
## reproduce the authored standard-arm transforms while keeping the wall side responsive.
const STANDARD_WALL_ANCHORS_FROM_EDGE := [
	Vector2(-1.208509, -66.285566),
	Vector2(1.016543, -62.897603),
	Vector2(-4.908108, 25.033825),
	Vector2(3.035202, 33.254229),
]
const COMPACT_WALL_ANCHORS_FROM_EDGE := [
	Vector2(-4, -42),
	Vector2(4, -39),
	Vector2(-4, 4),
	Vector2(4, 7),
]
const STANDARD_LOCK_ANCHORS := [
	Vector2(-6.791499, -17.714434),
	Vector2(4.983449, -19.102397),
	Vector2(-7.091884, -13.033829),
	Vector2(6.964798, -13.254231),
]
const COMPACT_LOCK_ANCHORS := [
	Vector2(-2, -19),
	Vector2(2, -18),
	Vector2(-2, -15),
	Vector2(2, -16),
]

const STANDARD_LOCK_POSITION := Vector2(0, -30)
const COMPACT_LOCK_POSITION := Vector2(0, -28)
const STANDARD_BADGE_POSITION := Vector2(0, -44)
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
const UNLOCK_IMPACT_SECONDS := 0.14
const UNLOCK_RELEASE_SECONDS := 0.24
const UNLOCK_LOCK_DROP := Vector2(0, 34)
const UNLOCK_BADGE_LIFT := Vector2(0, -8)

@export var overlay_half_width := 104.0
@export var overlay_top := -81.0
@export var overlay_bottom := 46.0
@export var wall_cover_top := WALL_COVER_TOP
@export var wall_cover_bottom := WALL_COVER_BOTTOM
@export var compact_layout := false

@onready var _shade := $Shade as Polygon2D
@onready var _chain_rig := $VisualRig/ChainRig as Node2D
@onready var _chain_top_left := $VisualRig/ChainRig/TopLeftArm as Sprite2D
@onready var _chain_top_right := $VisualRig/ChainRig/TopRightArm as Sprite2D
@onready var _chain_bottom_left := $VisualRig/ChainRig/BottomLeftArm as Sprite2D
@onready var _chain_bottom_right := $VisualRig/ChainRig/BottomRightArm as Sprite2D
@onready var _left_wall_cover := $VisualRig/WallAttachmentCovers/Left as Polygon2D
@onready var _right_wall_cover := $VisualRig/WallAttachmentCovers/Right as Polygon2D
@onready var _lock_rig := $VisualRig/LockRig as Node2D
@onready var _countdown_badge := $VisualRig/CountdownBadge as Node2D
@onready var _remaining_label := $VisualRig/CountdownBadge/RemainingLabel as Label

var _previous_remaining := -1
var _chain_arms: Array[Sprite2D] = []
var _chain_wall_anchors: Array[Vector2] = []
var _chain_lock_anchors: Array[Vector2] = []
var _chain_attachment_center := Vector2.ZERO
var _chain_thickness_scale := STANDARD_CHAIN_THICKNESS_SCALE
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
	tween.tween_interval(UNLOCK_IMPACT_SECONDS)
	tween.tween_callback(_stop_feedback_tweens)
	tween.tween_callback(_reset_chain_geometry)
	tween.set_parallel(true)
	tween.tween_method(
		_set_chain_release_progress,
		0.0,
		1.0,
		UNLOCK_RELEASE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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
		Vector2(-overlay_half_width, overlay_top),
		Vector2(overlay_half_width, overlay_top),
		Vector2(overlay_half_width, overlay_bottom),
		Vector2(-overlay_half_width, overlay_bottom),
	])
	_apply_wall_attachment_covers()
	_configure_chain_anchors()
	_reset_chain_geometry()

	_lock_rig.position = COMPACT_LOCK_POSITION if compact_layout else STANDARD_LOCK_POSITION
	_lock_rig.scale = COMPACT_LOCK_SCALE if compact_layout else STANDARD_LOCK_SCALE
	_countdown_badge.position = COMPACT_BADGE_POSITION if compact_layout else STANDARD_BADGE_POSITION
	_countdown_badge.scale = COMPACT_BADGE_SCALE if compact_layout else STANDARD_BADGE_SCALE

	_lock_base_position = _lock_rig.position
	_lock_base_scale = _lock_rig.scale
	_badge_base_position = _countdown_badge.position
	_badge_base_scale = _countdown_badge.scale


func _apply_wall_attachment_covers() -> void:
	_left_wall_cover.polygon = PackedVector2Array([
		Vector2(-overlay_half_width - WALL_COVER_DEPTH, wall_cover_top),
		Vector2(-overlay_half_width, wall_cover_top),
		Vector2(-overlay_half_width, wall_cover_bottom),
		Vector2(-overlay_half_width - WALL_COVER_DEPTH, wall_cover_bottom),
	])
	_right_wall_cover.polygon = PackedVector2Array([
		Vector2(overlay_half_width, wall_cover_top),
		Vector2(overlay_half_width + WALL_COVER_DEPTH, wall_cover_top),
		Vector2(overlay_half_width + WALL_COVER_DEPTH, wall_cover_bottom),
		Vector2(overlay_half_width, wall_cover_bottom),
	])


func _configure_chain_anchors() -> void:
	var wall_anchors_from_edge := (
		COMPACT_WALL_ANCHORS_FROM_EDGE
		if compact_layout
		else STANDARD_WALL_ANCHORS_FROM_EDGE
	)
	var lock_anchors := COMPACT_LOCK_ANCHORS if compact_layout else STANDARD_LOCK_ANCHORS
	_chain_thickness_scale = (
		COMPACT_CHAIN_THICKNESS_SCALE if compact_layout else STANDARD_CHAIN_THICKNESS_SCALE
	)

	_chain_wall_anchors.clear()
	for anchor_from_edge in wall_anchors_from_edge:
		var side_x := -overlay_half_width if anchor_from_edge.x < 0.0 else overlay_half_width
		_chain_wall_anchors.append(Vector2(side_x + anchor_from_edge.x, anchor_from_edge.y))

	_chain_lock_anchors.clear()
	_chain_attachment_center = Vector2.ZERO
	for lock_anchor in lock_anchors:
		_chain_lock_anchors.append(lock_anchor)
		_chain_attachment_center += lock_anchor
	_chain_attachment_center /= float(_chain_lock_anchors.size())


func _set_remaining_text(remaining: int) -> void:
	_remaining_label.text = str(remaining)
	var available_width := (
		_remaining_label.offset_right
		- _remaining_label.offset_left
		- GameplayUIThemeScript.COUNT_BADGE_HORIZONTAL_PADDING
	)
	_remaining_label.add_theme_font_size_override(
		"font_size",
		GameplayUIThemeScript.fit_label_font_size(
			_remaining_label,
			available_width,
			GameplayUIThemeScript.COUNT_BADGE_MAX_FONT_SIZE,
			GameplayUIThemeScript.COUNT_BADGE_MIN_FONT_SIZE
		)
	)


func _play_decrement_feedback() -> void:
	var chain_tween := UIMotionScript.retween(_chain_rig, CHAIN_TENSION_TWEEN_META)
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
	UIMotionScript.stop_tween(_chain_rig, CHAIN_TENSION_TWEEN_META)
	UIMotionScript.stop_tween(_lock_rig, LOCK_SWING_TWEEN_META)
	UIMotionScript.stop_tween(_countdown_badge, BADGE_POP_TWEEN_META)


func _set_chain_tension(distance: float) -> void:
	for index in range(_chain_arms.size()):
		var base_lock_anchor := _chain_lock_anchors[index]
		var pull_direction := base_lock_anchor.direction_to(_chain_attachment_center)
		_apply_chain_arm_transform(
			index,
			base_lock_anchor + pull_direction * distance
		)


func _set_chain_release_progress(progress: float) -> void:
	var safe_progress := clampf(progress, 0.0, 1.0)
	for index in range(_chain_arms.size()):
		var inner_anchor := _chain_lock_anchors[index].lerp(
			_chain_wall_anchors[index],
			safe_progress
		)
		_apply_chain_arm_transform(index, inner_anchor)
		_chain_arms[index].modulate.a = 1.0 - safe_progress


func _reset_chain_geometry() -> void:
	for index in range(_chain_arms.size()):
		_apply_chain_arm_transform(index, _chain_lock_anchors[index])
		_chain_arms[index].modulate = Color.WHITE


func _apply_chain_arm_transform(index: int, inner_anchor: Vector2) -> void:
	var chain_arm := _chain_arms[index]
	var wall_anchor := _chain_wall_anchors[index]
	var first_endpoint := wall_anchor if wall_anchor.x < 0.0 else inner_anchor
	var second_endpoint := inner_anchor if wall_anchor.x < 0.0 else wall_anchor
	var direction := second_endpoint - first_endpoint
	var visible_length := direction.length()

	chain_arm.position = (wall_anchor + inner_anchor) * 0.5
	if visible_length > 0.001:
		chain_arm.rotation = direction.angle()
	chain_arm.scale = Vector2(
		visible_length / CHAIN_ARM_VISIBLE_WIDTH,
		_chain_thickness_scale
	)


func _reset_animated_nodes() -> void:
	modulate = Color.WHITE
	scale = Vector2.ONE
	_reset_chain_geometry()
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
