class_name ShelfLayerIndicator
extends Node2D

## Segmented readout for how many items a dispenser shelf still holds, the item currently on display
## included. Owned by `scenes/dispenser_shelf.tscn`; it knows nothing about matching, moves, or the
## level -- `scripts/level.gd` never talks to it directly, only to the shelf.
##
## The track is a fixed width with one socket per authored layer, so the sockets are generated rather
## than authored: their count comes from the level config (2-4) and their width depends on that
## count. Everything that does not vary -- the count badge's label -- stays authored in the scene.

const UIMotionScript := preload("res://scripts/ui_motion.gd")

const TRACK_SIZE := Vector2(80.0, 12.0)
const TRACK_PADDING := 2.0
const TRACK_CORNER_RADIUS := 6.0
const SOCKET_GAP := 3.0
const SOCKET_CORNER_RADIUS := 3.0
const SOCKET_GLOSS_INSET := Vector2(2.0, 2.0)
const SOCKET_GLOSS_HEIGHT := 3.0
const BADGE_CENTER := Vector2(0.0, -24.0)
const BADGE_RADIUS := 13.0
const BADGE_RIM_WIDTH := 3.0
const CIRCLE_SEGMENTS := 24
const CORNER_SEGMENTS := 3

const TRACK_COLOR := Color(0.22, 0.16, 0.11, 0.85)
const SOCKET_EMPTY_COLOR := Color(0.31, 0.25, 0.19)
const SOCKET_FILL_COLOR := Color(0.35, 0.78, 0.22)
const SOCKET_GLOSS_COLOR := Color(0.58, 0.9, 0.38)
const BADGE_COLOR := Color(0.78, 0.52, 0.29)
const BADGE_RIM_COLOR := Color(0.64, 0.39, 0.19)

const DEPLETE_SECONDS := 0.22
const DEPLETE_SCALE := Vector2(0.62, 0.34)
const BADGE_PULSE_SCALE := Vector2(1.28, 1.28)
const BADGE_PULSE_IN_SECONDS := 0.1
const BADGE_PULSE_OUT_SECONDS := 0.14
const DEPLETE_TWEEN_META := &"layer_indicator_deplete_tween"
const BADGE_PULSE_TWEEN_META := &"layer_indicator_badge_pulse_tween"

const SOCKETS_NODE := "Sockets"
const COUNT_LABEL_NODE := "CountLabel"
const SOCKET_FILL_NODE := "Fill"

var _capacity := 0
var _remaining := 0
var _sockets: Array[Node2D] = []
var _count_label: Label


func _ready() -> void:
	_count_label = get_node_or_null(COUNT_LABEL_NODE) as Label
	_build_track()
	_build_badge()
	_rebuild_sockets()
	_apply_remaining(false)


## `capacity` is how many sockets the track shows; `remaining` is how many are lit. Safe to call
## before the node enters the tree -- the geometry is rebuilt on `_ready()` either way.
func configure(capacity: int, remaining: int) -> void:
	_capacity = maxi(capacity, 0)
	_remaining = clampi(remaining, 0, _capacity)
	if not is_node_ready():
		return

	_rebuild_sockets()
	_apply_remaining(false)


## A decrease animates the socket that just emptied and pulses the badge; an increase or a reset
## snaps, because nothing in the game grows a dispenser back and a snap reads as "this is the state"
## rather than as a reward.
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


func _build_track() -> void:
	var track := Polygon2D.new()
	track.name = "TrackBacking"
	track.color = TRACK_COLOR
	track.polygon = _rounded_rect_points(
		Vector2(TRACK_SIZE.x + TRACK_PADDING * 2.0, TRACK_SIZE.y + TRACK_PADDING * 2.0),
		TRACK_CORNER_RADIUS
	)
	add_child(track)
	move_child(track, 0)


func _build_badge() -> void:
	var badge := Polygon2D.new()
	badge.name = "BadgeBase"
	badge.position = BADGE_CENTER
	badge.color = BADGE_COLOR
	badge.polygon = _circle_points(BADGE_RADIUS)
	add_child(badge)

	var rim := Line2D.new()
	rim.name = "BadgeRim"
	rim.position = BADGE_CENTER
	rim.width = BADGE_RIM_WIDTH
	rim.default_color = BADGE_RIM_COLOR
	rim.closed = true
	rim.points = _circle_points(BADGE_RADIUS - BADGE_RIM_WIDTH * 0.5)
	add_child(rim)

	if _count_label != null:
		move_child(_count_label, get_child_count() - 1)


func _rebuild_sockets() -> void:
	var sockets_root := get_node_or_null(SOCKETS_NODE) as Node2D
	if sockets_root == null:
		sockets_root = Node2D.new()
		sockets_root.name = SOCKETS_NODE
		add_child(sockets_root)

	for child in sockets_root.get_children():
		sockets_root.remove_child(child)
		child.free()

	_sockets.clear()
	if _capacity <= 0:
		return

	var total_gap := SOCKET_GAP * float(_capacity - 1)
	var socket_width := maxf((TRACK_SIZE.x - total_gap) / float(_capacity), 1.0)
	var socket_size := Vector2(socket_width, TRACK_SIZE.y)
	var origin_x := -TRACK_SIZE.x * 0.5 + socket_width * 0.5

	for index in range(_capacity):
		var socket := Node2D.new()
		socket.name = "Socket%02d" % (index + 1)
		socket.position = Vector2(origin_x + float(index) * (socket_width + SOCKET_GAP), 0.0)
		sockets_root.add_child(socket)

		var empty := Polygon2D.new()
		empty.name = "Empty"
		empty.color = SOCKET_EMPTY_COLOR
		empty.polygon = _rounded_rect_points(socket_size, SOCKET_CORNER_RADIUS)
		socket.add_child(empty)

		var fill := Node2D.new()
		fill.name = SOCKET_FILL_NODE
		socket.add_child(fill)

		var fill_body := Polygon2D.new()
		fill_body.name = "Body"
		fill_body.color = SOCKET_FILL_COLOR
		fill_body.polygon = _rounded_rect_points(socket_size, SOCKET_CORNER_RADIUS)
		fill.add_child(fill_body)

		var gloss_size := Vector2(
			maxf(socket_size.x - SOCKET_GLOSS_INSET.x * 2.0, 1.0),
			SOCKET_GLOSS_HEIGHT
		)
		var gloss := Polygon2D.new()
		gloss.name = "Gloss"
		gloss.position = Vector2(0.0, -socket_size.y * 0.5 + SOCKET_GLOSS_INSET.y + gloss_size.y * 0.5)
		gloss.color = SOCKET_GLOSS_COLOR
		gloss.polygon = _rounded_rect_points(gloss_size, gloss_size.y * 0.5)
		fill.add_child(gloss)

		_sockets.append(socket)


func _apply_remaining(should_animate: bool) -> void:
	for index in range(_sockets.size()):
		var fill := _get_socket_fill(index)
		if fill == null:
			continue

		if index < _remaining:
			_reset_socket_fill(fill, true)
			continue

		# Only the socket that just emptied animates. Any socket beyond it was already dark, and
		# replaying its exit would read as several items leaving at once.
		if should_animate and index == _remaining:
			_play_socket_deplete(fill)
			continue

		_reset_socket_fill(fill, false)

	_update_count_label(should_animate)


func _reset_socket_fill(fill: Node2D, is_lit: bool) -> void:
	UIMotionScript.stop_tween(fill, DEPLETE_TWEEN_META)
	fill.visible = is_lit
	fill.modulate = Color.WHITE
	fill.scale = Vector2.ONE


func _play_socket_deplete(fill: Node2D) -> void:
	fill.visible = true
	fill.modulate = Color.WHITE
	fill.scale = Vector2.ONE

	var tween := UIMotionScript.retween(fill, DEPLETE_TWEEN_META)
	tween.set_parallel(true)
	tween.tween_property(fill, "modulate:a", 0.0, DEPLETE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(fill, "scale", DEPLETE_SCALE, DEPLETE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		fill.visible = false
		fill.modulate = Color.WHITE
		fill.scale = Vector2.ONE
	)


func _update_count_label(should_pulse: bool) -> void:
	if _count_label == null:
		return

	_count_label.text = str(_remaining)
	if not should_pulse:
		return

	_count_label.pivot_offset = _count_label.size * 0.5
	_count_label.scale = Vector2.ONE

	var tween := UIMotionScript.retween(_count_label, BADGE_PULSE_TWEEN_META)
	tween.tween_property(_count_label, "scale", BADGE_PULSE_SCALE, BADGE_PULSE_IN_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_count_label, "scale", Vector2.ONE, BADGE_PULSE_OUT_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _get_socket_fill(index: int) -> Node2D:
	if index < 0 or index >= _sockets.size():
		return null

	var socket := _sockets[index]
	if socket == null or not is_instance_valid(socket):
		return null

	return socket.get_node_or_null(SOCKET_FILL_NODE) as Node2D


## Corner-rounded rectangle centered on the node's own origin, so scaling a socket shrinks it toward
## its own middle rather than sliding it along the track.
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


func _circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(CIRCLE_SEGMENTS):
		var angle := TAU * float(index) / float(CIRCLE_SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	return points
