class_name ShelfLayerIndicator
extends Node2D

## Capacity-aware stock readout for a dispenser shelf. The exact remaining count reuses the ability
## bar's shared count-badge style, while one bright segment per remaining item makes both stock and
## total capacity readable without interpreting a continuous progress fraction. Owned by
## `scenes/dispenser_shelf.tscn`; matching, moves, and queue promotion stay outside this component.

const UIMotionScript := preload("res://scripts/ui_motion.gd")

const TRACK_SIZE := Vector2(100.0, 13.0)
const TRACK_PADDING := 1.0
const TRACK_CENTER := Vector2(0.0, 10.0)
const TRACK_CORNER_RADIUS := 7.5
const SEGMENT_GAP := 1.5
const SEGMENT_CORNER_RADIUS := 6.5
const SEGMENT_GLOSS_INSET := 3.0
const SEGMENT_GLOSS_HEIGHT := 2.5
const CORNER_SEGMENTS := 4

const TRACK_RIM_COLOR := Color(0.18, 0.11, 0.07, 0.98)
const TRACK_COLOR := Color(0.25, 0.22, 0.18, 1.0)
const SEGMENT_EMPTY_COLOR := Color(0.34, 0.31, 0.25, 1.0)
const SEGMENT_FILL_COLOR := Color(0.22, 0.88, 0.3, 1.0)
const SEGMENT_GLOSS_COLOR := Color(0.66, 1.0, 0.56, 0.92)

const SEGMENT_POP_SCALE := Vector2(1.1, 1.1)
const SEGMENT_DEPLETED_SCALE := Vector2(0.72, 0.72)
const SEGMENT_POP_SECONDS := 0.07
const SEGMENT_DEPLETE_SECONDS := 0.15
const COUNT_PULSE_SCALE := Vector2(1.22, 1.22)
const COUNT_PULSE_IN_SECONDS := 0.09
const COUNT_PULSE_OUT_SECONDS := 0.14
const SEGMENT_TWEEN_META := &"stock_segment_tween"
const COUNT_PULSE_TWEEN_META := &"stock_count_pulse_tween"

const COUNT_LABEL_NODE := "CountLabel"
const SEGMENTS_NODE := "Segments"

var _capacity := 0
var _remaining := 0

var _count_label: Label
var _segments_root: Node2D
var _segment_lights: Array[Node2D] = []


func _ready() -> void:
	_count_label = get_node_or_null(COUNT_LABEL_NODE) as Label
	_build_track()
	_build_segments_root()
	_rebuild_segments()
	if _count_label != null:
		move_child(_count_label, get_child_count() - 1)
	_apply_remaining(false, _remaining)


## Safe before the node enters the tree. Capacity determines how many discrete stock cells exist.
func configure(capacity: int, remaining: int) -> void:
	_capacity = maxi(capacity, 0)
	_remaining = clampi(remaining, 0, _capacity)
	if not is_node_ready():
		return

	_rebuild_segments()
	_apply_remaining(false, _remaining)


## A decrease pops and extinguishes each spent stock cell, then pulses the exact count. Increases
## and resets snap because the shipped dispenser queue only drains.
func set_remaining(remaining: int) -> void:
	var next_remaining := clampi(remaining, 0, _capacity)
	if next_remaining == _remaining:
		return

	var previous_remaining := _remaining
	_remaining = next_remaining
	if not is_node_ready():
		return

	_apply_remaining(next_remaining < previous_remaining, previous_remaining)


func get_remaining() -> int:
	return _remaining


func get_capacity() -> int:
	return _capacity


## Kept as a semantic query for callers that need the ratio; rendering is deliberately segmented.
func get_fill_fraction() -> float:
	return float(_remaining) / float(_capacity) if _capacity > 0 else 0.0


func get_segment_count() -> int:
	return _segment_lights.size()


func get_lit_segment_count() -> int:
	return mini(_remaining, _segment_lights.size())


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


func _build_segments_root() -> void:
	_segments_root = Node2D.new()
	_segments_root.name = SEGMENTS_NODE
	_segments_root.position = TRACK_CENTER
	_segments_root.z_index = 2
	add_child(_segments_root)


func _rebuild_segments() -> void:
	if _segments_root == null:
		return

	for child in _segments_root.get_children():
		_segments_root.remove_child(child)
		child.free()
	_segment_lights.clear()

	if _capacity <= 0:
		return

	var total_gap := SEGMENT_GAP * float(maxi(_capacity - 1, 0))
	var segment_width := (TRACK_SIZE.x - total_gap) / float(_capacity)
	var segment_size := Vector2(segment_width, TRACK_SIZE.y)
	var first_x := -TRACK_SIZE.x * 0.5 + segment_width * 0.5

	for index in range(_capacity):
		var segment := Node2D.new()
		segment.name = "Segment%02d" % (index + 1)
		segment.position = Vector2(first_x + float(index) * (segment_width + SEGMENT_GAP), 0.0)
		_segments_root.add_child(segment)

		var empty_cell := Polygon2D.new()
		empty_cell.name = "Empty"
		empty_cell.color = SEGMENT_EMPTY_COLOR
		empty_cell.polygon = _segment_rect_points(segment_size, index, _capacity)
		segment.add_child(empty_cell)

		var light := Node2D.new()
		light.name = "Light"
		light.z_index = 1
		segment.add_child(light)
		_segment_lights.append(light)

		var body := Polygon2D.new()
		body.name = "Body"
		body.color = SEGMENT_FILL_COLOR
		body.polygon = _segment_rect_points(segment_size, index, _capacity)
		light.add_child(body)

		var gloss_width := maxf(segment_width - SEGMENT_GLOSS_INSET * 2.0, 1.0)
		var gloss := Polygon2D.new()
		gloss.name = "Gloss"
		gloss.z_index = 1
		gloss.position = Vector2(0.0, -segment_size.y * 0.5 + 2.25)
		gloss.color = SEGMENT_GLOSS_COLOR
		gloss.polygon = _rounded_rect_points(
			Vector2(gloss_width, SEGMENT_GLOSS_HEIGHT),
			SEGMENT_GLOSS_HEIGHT * 0.5
		)
		light.add_child(gloss)


func _apply_remaining(should_animate: bool, previous_remaining: int) -> void:
	for index in range(_segment_lights.size()):
		var light := _segment_lights[index]
		var should_be_lit := index < _remaining
		var was_lit := index < previous_remaining
		if should_animate and was_lit and not should_be_lit:
			_animate_segment_deplete(light)
		else:
			_set_segment_lit(light, should_be_lit)

	_update_count_label(should_animate)


func _set_segment_lit(segment: Node2D, is_lit: bool) -> void:
	UIMotionScript.stop_tween(segment, SEGMENT_TWEEN_META)
	segment.visible = is_lit
	segment.scale = Vector2.ONE
	segment.modulate = Color.WHITE


func _animate_segment_deplete(segment: Node2D) -> void:
	UIMotionScript.stop_tween(segment, SEGMENT_TWEEN_META)
	segment.visible = true
	segment.scale = Vector2.ONE
	segment.modulate = Color.WHITE

	var tween := UIMotionScript.retween(segment, SEGMENT_TWEEN_META)
	tween.tween_property(
		segment,
		"scale",
		SEGMENT_POP_SCALE,
		SEGMENT_POP_SECONDS
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(
		segment,
		"scale",
		SEGMENT_DEPLETED_SCALE,
		SEGMENT_DEPLETE_SECONDS
	).set_delay(SEGMENT_POP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		segment,
		"modulate:a",
		0.0,
		SEGMENT_DEPLETE_SECONDS
	).set_delay(SEGMENT_POP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(_finish_segment_deplete.bind(segment))


func _finish_segment_deplete(segment: Node2D) -> void:
	if not is_instance_valid(segment):
		return
	segment.visible = false
	segment.scale = Vector2.ONE
	segment.modulate = Color.WHITE


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


func _segment_rect_points(size: Vector2, index: int, capacity: int) -> PackedVector2Array:
	var round_left := index == 0
	var round_right := index == capacity - 1
	var corner_radii := [
		SEGMENT_CORNER_RADIUS if round_right else 0.0,
		SEGMENT_CORNER_RADIUS if round_right else 0.0,
		SEGMENT_CORNER_RADIUS if round_left else 0.0,
		SEGMENT_CORNER_RADIUS if round_left else 0.0,
	]
	return _rounded_rect_points_with_corner_radii(size, corner_radii)


func _rounded_rect_points_with_corner_radii(
	size: Vector2, corner_radii: Array
) -> PackedVector2Array:
	var half := size * 0.5
	var centers := [
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
		Vector2(-half.x, -half.y),
	]
	var points := PackedVector2Array()
	for corner_index in range(centers.size()):
		var radius := minf(float(corner_radii[corner_index]), minf(half.x, half.y))
		if radius <= 0.0:
			points.append(centers[corner_index])
			continue

		var base_corner := centers[corner_index] as Vector2
		var corner_center: Vector2 = base_corner + Vector2(
			-radius if corner_index == 0 or corner_index == 1 else radius,
			radius if corner_index == 0 or corner_index == 3 else -radius
		)
		var start_angle := -TAU * 0.25 + float(corner_index) * TAU * 0.25
		for step in range(CORNER_SEGMENTS + 1):
			var angle := start_angle + TAU * 0.25 * float(step) / float(CORNER_SEGMENTS)
			points.append(corner_center + Vector2(cos(angle), sin(angle)) * radius)
	return points


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
			var angle := start_angle + TAU * 0.25 * float(step) / float(CORNER_SEGMENTS)
			points.append(center + Vector2(cos(angle), sin(angle)) * corner_radius)

	return points
