class_name ShelfLayerIndicator
extends Node2D

## Compact stock readout for a dispenser shelf. The exact remaining count sits in the shelf's dark
## front fascia, while the attached green track shows the same state at a glance. Owned by
## `scenes/dispenser_shelf.tscn`; matching, moves, and queue promotion stay outside this component.
##
## Capacity is authored per dispenser (2-4 items). It sets the denominator of the continuous fill,
## not a number of visual sockets, so every dispenser keeps one stable silhouette.

const UIMotionScript := preload("res://scripts/ui_motion.gd")

const TRACK_SIZE := Vector2(80.0, 10.0)
const TRACK_PADDING := 2.0
const TRACK_CORNER_RADIUS := 7.0
const TRACK_CENTER := Vector2(0.0, -2.0)
const FILL_CORNER_RADIUS := 5.0
const FILL_GLOSS_INSET := Vector2(3.0, 1.5)
const FILL_GLOSS_HEIGHT := 2.5
const CORNER_SEGMENTS := 4

const TRACK_RIM_COLOR := Color(0.19, 0.13, 0.09, 0.96)
const TRACK_COLOR := Color(0.29, 0.25, 0.2, 1.0)
const FILL_COLOR := Color(0.28, 0.78, 0.3, 1.0)
const FILL_GLOSS_COLOR := Color(0.58, 0.94, 0.5, 0.9)

const DEPLETE_SECONDS := 0.22
const COUNT_PULSE_SCALE := Vector2(1.22, 1.22)
const COUNT_PULSE_IN_SECONDS := 0.09
const COUNT_PULSE_OUT_SECONDS := 0.14
const FILL_TWEEN_META := &"layer_indicator_fill_tween"
const COUNT_PULSE_TWEEN_META := &"layer_indicator_count_pulse_tween"

const COUNT_LABEL_NODE := "CountLabel"
const FILL_NODE := "Fill"

var _capacity := 0
var _remaining := 0
var _displayed_fraction := 0.0:
	set(value):
		_displayed_fraction = clampf(value, 0.0, 1.0)
		if is_node_ready():
			_update_fill_geometry()

var _count_label: Label
var _fill_root: Node2D
var _fill_body: Polygon2D
var _fill_gloss: Polygon2D


func _ready() -> void:
	_count_label = get_node_or_null(COUNT_LABEL_NODE) as Label
	_build_track()
	_build_fill()
	_apply_remaining(false)


## Safe before the node enters the tree. The shelf calls this once with its authored item count.
func configure(capacity: int, remaining: int) -> void:
	_capacity = maxi(capacity, 0)
	_remaining = clampi(remaining, 0, _capacity)
	if not is_node_ready():
		return

	_apply_remaining(false)


## A decrease contracts the right edge toward the left and pulses the exact count. Increases and
## resets snap because the shipped dispenser queue only drains.
func set_remaining(remaining: int) -> void:
	var next_remaining := clampi(remaining, 0, _capacity)
	if next_remaining == _remaining:
		return

	var did_decrease := next_remaining < _remaining
	_remaining = next_remaining
	if not is_node_ready():
		return

	_apply_remaining(did_decrease)


func get_remaining() -> int:
	return _remaining


func get_capacity() -> int:
	return _capacity


func get_fill_fraction() -> float:
	return _displayed_fraction


func _build_track() -> void:
	var rim := Polygon2D.new()
	rim.name = "TrackBacking"
	rim.position = TRACK_CENTER
	rim.color = TRACK_RIM_COLOR
	rim.polygon = _rounded_rect_points(
		TRACK_SIZE + Vector2.ONE * TRACK_PADDING * 2.0,
		TRACK_CORNER_RADIUS
	)
	add_child(rim)
	move_child(rim, 0)

	var track := Polygon2D.new()
	track.name = "TrackInset"
	track.position = TRACK_CENTER
	track.z_index = 1
	track.color = TRACK_COLOR
	track.polygon = _rounded_rect_points(TRACK_SIZE, TRACK_SIZE.y * 0.5)
	add_child(track)
	move_child(track, 1)


func _build_fill() -> void:
	_fill_root = Node2D.new()
	_fill_root.name = FILL_NODE
	_fill_root.position = TRACK_CENTER
	_fill_root.z_index = 2
	add_child(_fill_root)

	_fill_body = Polygon2D.new()
	_fill_body.name = "Body"
	_fill_body.color = FILL_COLOR
	_fill_root.add_child(_fill_body)

	_fill_gloss = Polygon2D.new()
	_fill_gloss.name = "Gloss"
	_fill_gloss.z_index = 1
	_fill_gloss.color = FILL_GLOSS_COLOR
	_fill_root.add_child(_fill_gloss)

	if _count_label != null:
		move_child(_count_label, get_child_count() - 1)


func _apply_remaining(should_animate: bool) -> void:
	var target_fraction := (
		float(_remaining) / float(_capacity)
		if _capacity > 0
		else 0.0
	)

	if should_animate:
		var tween := UIMotionScript.retween(self, FILL_TWEEN_META)
		tween.tween_property(
			self,
			"_displayed_fraction",
			target_fraction,
			DEPLETE_SECONDS
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		UIMotionScript.stop_tween(self, FILL_TWEEN_META)
		_displayed_fraction = target_fraction

	_update_count_label(should_animate)


func _update_fill_geometry() -> void:
	if _fill_root == null or _fill_body == null or _fill_gloss == null:
		return

	var fill_width := TRACK_SIZE.x * _displayed_fraction
	_fill_root.visible = fill_width > 0.01
	if not _fill_root.visible:
		return

	var left_edge := -TRACK_SIZE.x * 0.5
	var fill_size := Vector2(fill_width, TRACK_SIZE.y)
	_fill_body.position = Vector2(left_edge + fill_width * 0.5, 0.0)
	_fill_body.polygon = _rounded_rect_points(fill_size, FILL_CORNER_RADIUS)

	var gloss_width := maxf(fill_width - FILL_GLOSS_INSET.x * 2.0, 0.75)
	var gloss_size := Vector2(gloss_width, FILL_GLOSS_HEIGHT)
	_fill_gloss.position = Vector2(
		left_edge + FILL_GLOSS_INSET.x + gloss_width * 0.5,
		-TRACK_SIZE.y * 0.5 + FILL_GLOSS_INSET.y + FILL_GLOSS_HEIGHT * 0.5
	)
	_fill_gloss.polygon = _rounded_rect_points(gloss_size, FILL_GLOSS_HEIGHT * 0.5)


func _update_count_label(should_pulse: bool) -> void:
	if _count_label == null:
		return

	_count_label.text = str(_remaining)
	UIMotionScript.stop_tween(_count_label, COUNT_PULSE_TWEEN_META)
	_count_label.scale = Vector2.ONE
	if not should_pulse:
		return

	_count_label.pivot_offset = _count_label.size * 0.5
	var tween := UIMotionScript.retween(_count_label, COUNT_PULSE_TWEEN_META)
	tween.tween_property(
		_count_label,
		"scale",
		COUNT_PULSE_SCALE,
		COUNT_PULSE_IN_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		_count_label,
		"scale",
		Vector2.ONE,
		COUNT_PULSE_OUT_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _rounded_rect_points(size: Vector2, radius: float) -> PackedVector2Array:
	var half := size * 0.5
	var corner_radius := minf(radius, minf(half.x, half.y))
	if corner_radius <= 0.0:
		return PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		])

	var points := PackedVector2Array()
	var corner_centers := [
		Vector2(half.x - corner_radius, -half.y + corner_radius),
		Vector2(half.x - corner_radius, half.y - corner_radius),
		Vector2(-half.x + corner_radius, half.y - corner_radius),
		Vector2(-half.x + corner_radius, -half.y + corner_radius),
	]

	for corner_index in range(corner_centers.size()):
		var center := corner_centers[corner_index] as Vector2
		var start_angle := -TAU * 0.25 + float(corner_index) * TAU * 0.25
		for step in range(CORNER_SEGMENTS + 1):
			var angle := (
				start_angle
				+ TAU * 0.25 * float(step) / float(CORNER_SEGMENTS)
			)
			points.append(center + Vector2(cos(angle), sin(angle)) * corner_radius)

	return points
