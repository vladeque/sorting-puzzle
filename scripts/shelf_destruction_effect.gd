class_name ShelfDestructionEffect
extends Node2D

## Lightweight, asset-free destruction accent for an emptied collapsing shelf.
##
## `CollapsingShelfColumn` owns the shared tween and lifetime. This node contributes the local
## break-apart motion plus deterministic wood chips and dust, so captures can advance the complete
## collapse through the column's one tween instead of racing an independent effect timeline.

const CHIP_STARTS := [
	Vector2(-96.0, 30.0), Vector2(-72.0, 40.0), Vector2(-46.0, 34.0),
	Vector2(-18.0, 41.0), Vector2(14.0, 35.0), Vector2(42.0, 40.0),
	Vector2(70.0, 33.0), Vector2(96.0, 39.0), Vector2(-106.0, -18.0),
	Vector2(106.0, -10.0),
]
const CHIP_VELOCITIES := [
	Vector2(-36.0, -54.0), Vector2(-24.0, -76.0), Vector2(-17.0, -48.0),
	Vector2(-7.0, -70.0), Vector2(9.0, -58.0), Vector2(18.0, -78.0),
	Vector2(27.0, -51.0), Vector2(38.0, -67.0), Vector2(-29.0, -38.0),
	Vector2(31.0, -43.0),
]
const CHIP_COLORS := [
	Color("c69158"), Color("e1b478"), Color("ad7440"), Color("d7a365"),
	Color("956036"), Color("edc58b"), Color("bb7f45"), Color("d49b5c"),
	Color("a66d3d"), Color("e4b97b"),
]
const DUST_OFFSETS := [-84.0, -58.0, -30.0, 0.0, 30.0, 58.0, 84.0]

var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


## Adds every visual change to the column-owned parallel tween. The shelf is already logically
## removed, so its child transforms do not need restoration after this one-shot animation.
func add_to_tween(tween: Tween, shelf: Shelf, duration: float, break_direction: float) -> void:
	if tween == null or shelf == null or duration <= 0.0:
		return

	progress = 0.0
	tween.tween_property(self, "progress", 1.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var original_scale := shelf.scale
	var anticipation_duration := duration * 0.32
	var break_duration := duration - anticipation_duration
	tween.tween_property(
		shelf, "scale", original_scale * Vector2(1.025, 0.94), anticipation_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		shelf, "scale", original_scale * Vector2(0.98, 0.80), break_duration
	).set_delay(anticipation_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		shelf, "rotation", break_direction * 0.012, duration * 0.68
	).set_delay(duration * 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		shelf, "modulate:a", 0.0, duration * 0.52
	).set_delay(duration * 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_add_piece_motion(tween, shelf, duration, break_direction)


func _add_piece_motion(
	tween: Tween, shelf: Shelf, duration: float, break_direction: float
) -> void:
	var break_delay := duration * 0.20
	var piece_duration := duration * 0.72
	var placement_name := shelf.get_row_placement().capitalize()
	var left_wall := shelf.get_node_or_null(
		"PlacementVisuals/%s/LeftWall" % placement_name
	) as Node2D
	var right_wall := shelf.get_node_or_null(
		"PlacementVisuals/%s/RightWall" % placement_name
	) as Node2D
	_add_node_offset(tween, left_wall, Vector2(-11.0, 5.0), -0.045, break_delay, piece_duration)
	_add_node_offset(tween, right_wall, Vector2(11.0, 5.0), 0.045, break_delay, piece_duration)

	var back_wall := shelf.get_node_or_null("BackWall") as Node2D
	var back_wall_shade := shelf.get_node_or_null("BackWallTopShade") as Node2D
	for panel in [back_wall, back_wall_shade]:
		if panel == null:
			continue
		tween.tween_property(
			panel, "scale", panel.scale * Vector2(0.96, 0.58), piece_duration
		).set_delay(break_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(
			panel, "position", panel.position + Vector2(0.0, 13.0), piece_duration
		).set_delay(break_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var floor_surface := shelf.get_node_or_null("FloorSurface") as Node2D
	var floor_lip := shelf.get_node_or_null("FloorFrontLip") as Node2D
	for plank in [floor_surface, floor_lip]:
		_add_node_offset(
			tween,
			plank,
			Vector2(break_direction * 3.0, 14.0),
			break_direction * 0.035,
			break_delay,
			piece_duration
		)

	var ceiling := shelf.get_node_or_null("Ceiling") as Node2D
	_add_node_offset(
		tween,
		ceiling,
		Vector2(-break_direction * 4.0, -5.0),
		-break_direction * 0.026,
		break_delay,
		piece_duration
	)

	for shadow_path in ["Shadow", "RightColumnShadow"]:
		var shadow := shelf.get_node_or_null(shadow_path) as CanvasItem
		if shadow != null:
			tween.tween_property(
				shadow, "modulate:a", 0.0, duration * 0.46
			).set_delay(duration * 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _add_node_offset(
	tween: Tween,
	node: Node2D,
	offset: Vector2,
	rotation_offset: float,
	delay: float,
	duration: float
) -> void:
	if node == null:
		return
	tween.tween_property(node, "position", node.position + offset, duration) \
		.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "rotation", node.rotation + rotation_offset, duration) \
		.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _draw() -> void:
	if progress <= 0.0:
		return

	_draw_snap_line()
	_draw_dust()
	_draw_wood_chips()


func _draw_snap_line() -> void:
	var pulse := sin(clampf(progress / 0.36, 0.0, 1.0) * PI)
	if pulse <= 0.001:
		return
	var color := Color(1.0, 0.88, 0.62, pulse * 0.74)
	draw_line(Vector2(-98.0, 36.0), Vector2(98.0, 36.0), color, 4.0, true)


func _draw_dust() -> void:
	var dust_progress := clampf((progress - 0.16) / 0.84, 0.0, 1.0)
	if dust_progress <= 0.0:
		return
	var alpha := (1.0 - dust_progress) * 0.24
	for dust_index in range(DUST_OFFSETS.size()):
		var side := -1.0 if dust_index % 2 == 0 else 1.0
		var center := Vector2(
			DUST_OFFSETS[dust_index] + side * dust_progress * 9.0,
			39.0 - dust_progress * (5.0 + float(dust_index % 3) * 3.0)
		)
		var radius := lerpf(5.0, 17.0 + float(dust_index % 2) * 3.0, dust_progress)
		draw_circle(center, radius, Color(0.78, 0.70, 0.59, alpha))


func _draw_wood_chips() -> void:
	var chip_progress := clampf((progress - 0.18) / 0.82, 0.0, 1.0)
	if chip_progress <= 0.0:
		return
	var alpha := 1.0 - smoothstep(0.62, 1.0, chip_progress)
	for chip_index in range(CHIP_STARTS.size()):
		var start: Vector2 = CHIP_STARTS[chip_index]
		var velocity: Vector2 = CHIP_VELOCITIES[chip_index]
		var chip_position := (
			start
			+ velocity * chip_progress
			+ Vector2(0.0, 102.0 * chip_progress * chip_progress)
		)
		var angle := (float(chip_index % 5) - 2.0) * 0.72 * chip_progress
		var half_size := Vector2(5.0 + float(chip_index % 3), 2.2 + float(chip_index % 2))
		var points := PackedVector2Array([
			chip_position + Vector2(-half_size.x, -half_size.y).rotated(angle),
			chip_position + Vector2(half_size.x, -half_size.y).rotated(angle),
			chip_position + Vector2(half_size.x * 0.72, half_size.y).rotated(angle),
			chip_position + Vector2(-half_size.x * 0.72, half_size.y).rotated(angle),
		])
		var color: Color = CHIP_COLORS[chip_index]
		color.a = alpha * 0.94
		draw_colored_polygon(points, color)
