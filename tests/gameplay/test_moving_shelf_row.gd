extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const MOVING_ROW_SCENE_PATH := "res://scenes/moving_shelf_row.tscn"
const SHELF_SCENE_PATH := "res://scenes/shelf.tscn"
const MOVING_SHELF_SCENE_PATH := "res://scenes/moving_shelf.tscn"
const LEVEL_SCENE_PATH := "res://level.tscn"
const BACK_WALL_SHADOW_SHADER_PATH := "res://assets/shaders/shelf_back_wall_shadow.gdshader"
const LINEAR_SHADOW_SHADER_PATH := "res://assets/shaders/shelf_linear_shadow.gdshader"
const PREVIEW_ARGUMENT := "--moving-shelf-motion-preview"
const LAYOUT_DIRECTORY := "res://scenes/layouts"
const CELL_SIZE := Vector2(237.44, 143.1)
const CELL_STEP := Vector2(228.96, 144.902)
const BACK_WALL_TOP := 128.0
const BACK_WALL_BOTTOM_MARGIN := 224.0
const RESPONSIVE_VIEWPORTS := [
	Vector2(540, 960), Vector2(720, 1280), Vector2(1080, 1920),
	Vector2(1080, 2400), Vector2(1200, 1600),
]

var _failures: Array[String] = []


func _init() -> void:
	var preview_mode := OS.get_cmdline_user_args().has(PREVIEW_ARGUMENT)
	if not preview_mode and not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Moving-shelf-row verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	if OS.get_cmdline_user_args().has(PREVIEW_ARGUMENT):
		await _run_preview()
		return

	var row_scene := load(MOVING_ROW_SCENE_PATH) as PackedScene
	var shelf_scene := load(MOVING_SHELF_SCENE_PATH) as PackedScene
	var row := row_scene.instantiate() as MovingShelfRow if row_scene != null else null
	var shelf := shelf_scene.instantiate() as Shelf if shelf_scene != null else null
	_check(row != null, "The moving shelf row scene should instantiate.")
	_check(shelf != null, "The single moving shelf scene should instantiate.")
	if row == null or shelf == null:
		_finish()
		return

	row.configure(3, CELL_STEP, CELL_SIZE, MovingShelfRow.MOTION_HORIZONTAL_WRAP, 0.0, 1)
	row.add_child(shelf)
	row.add_shelf(shelf)
	_check(
		shelf.get_visual_variant() == Shelf.VISUAL_VARIANT_FLOOR_ONLY
		and not shelf.get_node("BackWall").visible
		and shelf.get_node(Shelf.FLOOR_CONTACT_SHADOW_NODE).visible,
		"The independent moving shelf should open with its floor-only appearance."
	)
	var floor_contact_shadow := shelf.get_node(Shelf.FLOOR_CONTACT_SHADOW_NODE) as Polygon2D
	var floor_contact_material := floor_contact_shadow.material as ShaderMaterial
	_check(
		floor_contact_material != null
			and floor_contact_material.shader != null
			and floor_contact_material.shader.resource_path == LINEAR_SHADOW_SHADER_PATH,
		"The floor-only moving shelf should use a soft background-independent contact shadow."
	)
	shelf.set_visual_variant(Shelf.VISUAL_VARIANT_FULL)
	_check(
		shelf.get_node("BackWall").visible and not floor_contact_shadow.visible,
		"The optional full frame should replace the floor-only contact shadow."
	)
	_verify_soft_back_wall_shadows(shelf)
	shelf.set_visual_variant(Shelf.VISUAL_VARIANT_FLOOR_ONLY)

	var expected_width := CELL_SIZE.x - MovingShelfRow.SHELF_WIDTH_REDUCTION
	_check(
		is_equal_approx(row.shelf_cell_size.x, expected_width),
		"Moving shelves should use a cell that is exactly 15 px narrower."
	)
	_check(
		is_equal_approx(row.get_visible_size().x, CELL_STEP.x * 2.0 + expected_width),
		"The moving-row clipping window should follow the shortened shelf width."
	)
	_check(
		CELL_STEP.x > expected_width,
		"Shortened moving shelves should leave a visible gap instead of sharing an edge."
	)

	var expected_visual_scale := expected_width / CELL_SIZE.x
	for node_path in Shelf.HORIZONTAL_VISUAL_SCALE_NODES:
		var visual := shelf.get_node_or_null(node_path) as Node2D
		_check(visual != null, "%s should remain a moving-shelf visual node." % node_path)
		if visual != null and node_path != Shelf.FLOOR_FRONT_LIP_NODE:
			_check(
				is_equal_approx(visual.scale.x, expected_visual_scale),
				"%s should be shortened with the moving shelf body." % node_path
			)
		var polygon := visual as Polygon2D
		if polygon != null:
			_check(
				polygon.antialiased,
				"%s should antialias its moving outer edges." % node_path
			)

	var floor_surface := shelf.get_node_or_null(Shelf.FLOOR_SURFACE_NODE) as Polygon2D
	var floor_front_lip := shelf.get_node_or_null(Shelf.FLOOR_FRONT_LIP_NODE) as Polygon2D
	_check(floor_surface != null, "The moving shelf should keep its floor surface.")
	_check(floor_front_lip != null, "The moving shelf should keep its front lip.")
	if floor_surface != null and floor_front_lip != null:
		var surface_width := _get_polygon_width(floor_surface)
		var lip_width := _get_polygon_width(floor_front_lip)
		_check(
			is_equal_approx(surface_width, lip_width),
			"The moving shelf floor surface and front lip should finish at identical edges."
		)

	for slot_name in ["Slot01", "Slot02", "Slot03"]:
		var slot := shelf.get_node_or_null(slot_name) as Node2D
		_check(
			slot != null and is_equal_approx(slot.scale.x, 1.0),
			"%s and its item should keep their original proportions." % slot_name
		)

	row.speed_pixels_per_second = 60.0
	row.call("_physics_process", 1.0 / 60.0)
	_check(
		is_equal_approx(float(row.get("_motion_offset")), 1.0),
		"A fixed motion tick should advance the belt by speed multiplied by delta."
	)
	_check(
		is_equal_approx(float(row.call("_get_interpolated_motion_offset", 0.5)), 0.5),
		"Render motion should interpolate halfway between consecutive fixed-tick samples."
	)
	row.call("_layout_shelves", row.call("_get_interpolated_motion_offset", 0.5))
	_check(
		is_equal_approx(shelf.position.x, expected_width * 0.5 + 0.5),
		"The shelf should render at the interpolated subpixel position."
	)
	row.set_movement_paused(true)
	_check(
		is_equal_approx(
			float(row.get("_previous_motion_offset")),
			float(row.get("_motion_offset"))
		),
		"Pausing should collapse interpolation history so resume cannot jump."
	)
	_verify_authored_motion_speeds()
	_verify_taller_template_spacing()
	_verify_taller_staggered_column_spacing()
	_verify_full_background_travel()
	await _verify_responsive_moving_windows()
	await _verify_edge_item_pickup()
	await _verify_level_four_back_wall_centering()

	row.free()
	_finish()


func _verify_soft_back_wall_shadows(shelf: Shelf) -> void:
	for node_path in [
		"BackWallTopShade",
		"PlacementVisuals/Left/BackWallLeftShade",
		"PlacementVisuals/Middle/BackWallLeftShade",
		"PlacementVisuals/Right/BackWallLeftShade",
	]:
		var shadow := shelf.get_node_or_null(node_path) as Polygon2D
		var material := shadow.material as ShaderMaterial if shadow != null else null
		_check(
			material != null
				and material.shader != null
				and material.shader.resource_path == BACK_WALL_SHADOW_SHADER_PATH,
			"%s should retain the procedural soft-shadow shader." % node_path
		)


func _run_preview() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.size = Vector2i(720, 1280)
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level = level_scene.instantiate() if level_scene != null else null
	if level == null:
		push_error("The moving-shelf preview could not instantiate level.tscn.")
		quit(1)
		return

	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 8)
	level.set("_sound_effects_enabled", false)
	root.add_child(level)
	await create_timer(2.0).timeout
	level.queue_free()
	quit(0)


func _verify_full_background_travel() -> void:
	for axis in [0, 1]:
		for shelf_count in [2, 6]:
			var row := MovingShelfRow.new()
			var motion := (
				MovingShelfRow.MOTION_HORIZONTAL_WRAP if axis == 0
				else MovingShelfRow.MOTION_VERTICAL_WRAP
			)
			row.configure(3, CELL_STEP, CELL_SIZE, motion, 60.0, 1, Vector2(100, 200))
			for _index in range(shelf_count):
				var shelf := Node2D.new()
				row.add_child(shelf)
				row.add_shelf(shelf)
			var authored_bounds := row.get_layout_bounds()
			row.set_play_area(Rect2(-300, -400, 1500, 1800))
			_check(
				row.get_layout_bounds() == authored_bounds,
				"Expanding a belt must preserve its authored layout bounds."
			)
			_check(
				is_equal_approx(row.position[1 - axis], authored_bounds.position[1 - axis]),
				"Expanding a belt must preserve its lane across the motion axis."
			)
			var window_length := row.get_visible_size()[axis]
			var half_cell := row.shelf_cell_size[axis] * 0.5
			var first_shelf := row.get_child(0) as Node2D
			# A shelf must remain visible and selectable deep into the newly available background.
			row.call("_layout_shelves", window_length - half_cell * 2.0)
			_check(
				first_shelf.visible and row.is_shelf_inside_visible_window(first_shelf),
				"A shelf must travel through the expanded background before wrapping."
			)
			for motion_direction in [-1, 1]:
				row.set("_motion_offset", 0.0)
				row.direction = motion_direction
				row.call("_layout_shelves")
				var cycle: float = row.call("_get_cycle_length")
				for _tick in range(ceili(cycle * 2.0 / 7.0)):
					var previous := first_shelf.position[axis]
					row.call("_physics_process", 7.0 / 60.0)
					row.call("_layout_shelves")
					var current := first_shelf.position[axis]
					if absf(current - previous) > 7.1:
						_check(
							(previous >= window_length + half_cell - 7.1
								and current <= -half_cell + 7.1)
							or (current >= window_length + half_cell - 7.1
								and previous <= -half_cell + 7.1),
							"A shelf may wrap only after its full cell crosses a background edge."
						)
			row.free()


func _verify_responsive_moving_windows() -> void:
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level := level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 4)
	level.set("_sound_effects_enabled", false)
	root.add_child(level)
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for motion in [MovingShelfRow.MOTION_HORIZONTAL_WRAP, MovingShelfRow.MOTION_VERTICAL_WRAP]:
		var shelves_config: Array = []
		for _index in range(9):
			shelves_config.append({"layers": [[null, null, null]]})
		level.call("_apply_level_config", {
			"shelves": shelves_config,
			"row_layouts": [
				{"shelf_count": 3},
				{"shelf_count": 6, "visible_count": 3, "motion": {"type": motion, "speed": 60.0}},
			],
		})
		var shelves := level.get_node("Shelves") as Node2D
		var row := shelves.get_node("MovingShelfRow04") as MovingShelfRow
		var static_shelf := shelves.get_node("Shelf01") as Node2D
		_check(
			row.get_node("Shelf04").scene_file_path == MOVING_SHELF_SCENE_PATH
			and static_shelf.scene_file_path == SHELF_SCENE_PATH,
			"Moving and static shelves must instantiate their own independent visual scenes."
		)
		var authored_static_position := static_shelf.position
		var authored_bounds: Rect2 = level.call("_get_shelves_local_bounds")
		for viewport in RESPONSIVE_VIEWPORTS:
			for safe_margins in [Vector4.ZERO, Vector4(24, 40, 16, 32)]:
				level.call("_layout_shelves", viewport, safe_margins)
				var start := shelves.position + row.position * shelves.scale
				var end := start + row.size * shelves.scale
				if motion == MovingShelfRow.MOTION_HORIZONTAL_WRAP:
					_check(
						is_equal_approx(start.x, safe_margins.x)
						and is_equal_approx(end.x, viewport.x - safe_margins.z),
						"Horizontal belts must span the full safe background width at %s." % viewport
					)
				else:
					_check(
						is_equal_approx(start.y, BACK_WALL_TOP + safe_margins.y)
						and is_equal_approx(end.y, viewport.y - BACK_WALL_BOTTOM_MARGIN),
						"Vertical belts must span the full playable background height at %s." % viewport
					)
				var previous_position := shelves.position
				var previous_scale := shelves.scale
				for _pass in range(3):
					level.call("_layout_shelves", viewport, safe_margins)
				_check(
					shelves.position.is_equal_approx(previous_position)
					and shelves.scale.is_equal_approx(previous_scale),
					"Repeated responsive passes must not shrink or shift the board."
				)
				_check(
					static_shelf.position == authored_static_position
					and level.call("_get_shelves_local_bounds") == authored_bounds,
					"Expanded motion must not change static placement or authored board bounds."
				)
	level.queue_free()
	await process_frame


func _verify_edge_item_pickup() -> void:
	var level := (load(LEVEL_SCENE_PATH) as PackedScene).instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 4)
	level.set("_sound_effects_enabled", false)
	level.set("item_move_duration_seconds", 0.0)
	root.add_child(level)
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for motion in [MovingShelfRow.MOTION_HORIZONTAL_WRAP, MovingShelfRow.MOTION_VERTICAL_WRAP]:
		level.call("_apply_level_config", {
			"shelves": [
				{"layers": [["milk_carton", null, null]]},
				{"layers": [[null, null, null]]},
			],
			"row_layouts": [
				{"shelf_count": 1},
				{"shelf_count": 1, "visible_count": 1, "motion": {"type": motion, "speed": 60}},
			],
		})
		level.call("_collect_slots")
		var shelves := level.get_node("Shelves") as Node2D
		var source_slot := shelves.get_node("Shelf01/Slot01") as Node2D
		var item := level.call("_get_slot_item", source_slot) as ShelfItem
		var row := shelves.get_node("MovingShelfRow02") as MovingShelfRow
		var shelf := row.get_node("Shelf02") as Node2D
		var axis := 0 if motion == MovingShelfRow.MOTION_HORIZONTAL_WRAP else 1
		for viewport in RESPONSIVE_VIEWPORTS:
			level.call("_layout_shelves", viewport, Vector4.ZERO)
			for edge in [-1, 1]:
				# The shelf center is already offscreen, but the inward item is still visible.
				var center := -10.0 if edge < 0 else row.get_visible_size()[axis] + 10.0
				row.call("_layout_shelves", center - row.shelf_cell_size[axis] * 0.5)
				var slot_name := "Slot02" if axis == 1 else ("Slot03" if edge < 0 else "Slot01")
				var slot := shelf.get_node(slot_name) as Node2D
				level.call("_place_item_in_slot", item, slot)
				var window := row.get_global_transform() * Rect2(Vector2.ZERO, row.get_visible_size())
				var pick_size: Vector2 = level.get("item_pick_size") * shelves.scale.x
				var item_rect := Rect2(item.global_position - pick_size * 0.5, pick_size)
				var visible_pick := item_rect.intersection(window)
				_check(visible_pick.has_area(), "Edge fixture must leave part of the item visible.")
				var pointer := visible_pick.get_center()
				_check(
					level.call("_find_item_at_position", pointer) == item,
					"A placed item must remain pickable after the shelf center crosses edge %s/%s at %s."
						% [motion, edge, viewport]
				)
				level.call("_handle_press_at", pointer)
				level.call("_handle_release_at", pointer)
				level.call("_clear_drag_drop_selection_if_unavailable")
				_check(level.get("_selected_item") == item, "A visible edge item must stay tap-selected.")
				level.call("_clear_selected_item")
				level.call("_handle_press_at", pointer)
				level.call("_handle_motion_at", pointer + Vector2(20, 0))
				_check(level.get("_dragged_item") == item, "A visible edge item must start dragging.")
				level.call("_handle_release_at", pointer)
				# The release may choose a nearby static slot; restore this fixture's edge placement.
				level.call("_place_item_in_slot", item, slot)
				# Neither the clipped part of an item nor a hidden neighboring slot is interactive.
				var clipped_pointer := item_rect.get_center()
				clipped_pointer[axis] = window.position[axis] - 1.0 if edge < 0 else window.end[axis] + 1.0
				_check(
					level.call("_find_item_at_position", clipped_pointer) == null,
					"Picking must not reach through the clipping boundary."
				)
				_check(
					not level.call("_is_slot_drop_target_at_position", slot, clipped_pointer),
					"Drop snapping must not reach through the clipping boundary."
				)
				if axis == 0:
					_check(
						level.call("_find_free_slot_on_target_shelf", slot, null) == null,
						"An occupied edge slot must not redirect a drop into hidden neighboring slots."
					)
				for shelf_slot in level.call("_get_front_slots", shelf):
					var marker := level.call("_get_slot_marker", shelf_slot) as Marker2D
					if not window.has_point(marker.global_position):
						_check(
							not level.call("_is_slot_drop_target_eligible", shelf_slot),
							"Hidden slot centers must not accept drops."
						)
				level.call("_set_selected_item", item, slot)
				row.call("_layout_shelves", -row.shelf_cell_size[axis])
				level.call("_clear_drag_drop_selection_if_unavailable")
				_check(
					level.get("_selected_item") == null
					and level.call("_find_item_at_position", item.global_position) == null,
					"A fully hidden shelf must clear selection and reject pickup at %s/%s/%s."
						% [motion, edge, viewport]
				)
				level.call("_place_item_in_slot", item, source_slot)
	level.queue_free()
	await process_frame


func _verify_authored_motion_speeds() -> void:
	for file_name in DirAccess.get_files_at(LAYOUT_DIRECTORY):
		if not file_name.ends_with(".tscn"):
			continue

		var scene_path := "%s/%s" % [LAYOUT_DIRECTORY, file_name]
		var packed_scene := load(scene_path) as PackedScene
		var layout := packed_scene.instantiate() if packed_scene != null else null
		_check(layout != null, "%s should remain loadable." % scene_path)
		if layout == null:
			continue

		for child in layout.get_children():
			var moving_row := child as ShelfLayoutRow
			if moving_row == null:
				continue
			_check(
				is_equal_approx(
					moving_row.speed_pixels_per_second,
					ShelfLayoutRow.DEFAULT_SMOOTH_SPEED
				),
				"%s/%s should use the smooth 60 px/s campaign cadence."
					% [file_name, child.name]
			)

		layout.free()


func _verify_taller_template_spacing() -> void:
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var layout_scene := load("%s/layout_grid_3x3.tscn" % LAYOUT_DIRECTORY) as PackedScene
	var level := level_scene.instantiate() if level_scene != null else null
	var layout := layout_scene.instantiate() if layout_scene != null else null
	_check(level != null and layout != null, "The 3x3 layout should load for row-spacing verification.")
	if level == null or layout == null:
		if level != null:
			level.free()
		if layout != null:
			layout.free()
		return

	var shelves_config: Array = []
	for _index in range(9):
		shelves_config.append({"layers": [[null, null, null]]})
	var positions := level.call("_get_layout_template_node_positions", layout, shelves_config) as Dictionary
	var top_marker := layout.get_node("Shelf01") as Marker2D
	var middle_marker := layout.get_node("Shelf04") as Marker2D
	var bottom_marker := layout.get_node("Shelf07") as Marker2D
	var top_position: Vector2 = positions.get(top_marker.get_instance_id(), Vector2.ZERO)
	var middle_position: Vector2 = positions.get(middle_marker.get_instance_id(), Vector2.ZERO)
	var bottom_position: Vector2 = positions.get(bottom_marker.get_instance_id(), Vector2.ZERO)
	_check(
		is_equal_approx(middle_position.y - top_position.y, CELL_STEP.y)
		and is_equal_approx(bottom_position.y - middle_position.y, CELL_STEP.y),
		"Every authored shelf row should receive the taller 144.902 px runtime step."
	)
	_check(
		is_equal_approx(middle_position.y, 0.0),
		"Expanding template rows should preserve the layout's vertical center."
	)

	level.free()
	layout.free()


func _verify_taller_staggered_column_spacing() -> void:
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var layout_scene := load(
		"%s/layout_staggered_columns_4_5_4.tscn" % LAYOUT_DIRECTORY
	) as PackedScene
	var level := level_scene.instantiate() if level_scene != null else null
	var layout := layout_scene.instantiate() if layout_scene != null else null
	_check(
		level != null and layout != null,
		"The Level 4 staggered-column layout should load for row-spacing verification."
	)
	if level == null or layout == null:
		if level != null:
			level.free()
		if layout != null:
			layout.free()
		return

	var shelves_config: Array = []
	for _index in range(13):
		shelves_config.append({"layers": [[null, null, null]]})
	var positions := level.call(
		"_get_layout_template_node_positions",
		layout,
		shelves_config
	) as Dictionary
	var left_top := layout.get_node("Shelf01") as Marker2D
	var left_next := layout.get_node("Shelf02") as Marker2D
	var center_top := layout.get_node("Shelf05") as Marker2D
	var resolved_left_top: Vector2 = positions.get(left_top.get_instance_id(), Vector2.ZERO)
	var resolved_left_next: Vector2 = positions.get(left_next.get_instance_id(), Vector2.ZERO)
	var resolved_center_top: Vector2 = positions.get(center_top.get_instance_id(), Vector2.ZERO)
	_check(
		is_equal_approx(resolved_left_next.y - resolved_left_top.y, CELL_STEP.y),
		"Level 4 shelves in one column should keep the interlocked 144.902 px row step."
	)
	_check(
		is_equal_approx(
			resolved_left_top.y - resolved_center_top.y,
			CELL_STEP.y * 0.5
		),
		"Level 4's interleaved center column should keep an exact half-row stagger."
	)
	_check(
		is_equal_approx(
			resolved_center_top.y,
			-CELL_STEP.y * 2.0
		),
		"Level 4's five-shelf center column should remain centered around y = 0."
	)

	level.free()
	layout.free()


func _verify_level_four_back_wall_centering() -> void:
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level := level_scene.instantiate() if level_scene != null else null
	_check(level != null, "Level 4 should instantiate for responsive wall-centering verification.")
	if level == null:
		return

	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 4)
	level.set("_sound_effects_enabled", false)
	root.add_child(level)
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED

	var shelves := level.get_node("Shelves") as Node2D
	var shelf_bounds := level.call("_get_shelves_local_bounds") as Rect2
	var scaled_bounds_center_y := (
		(shelf_bounds.position.y + shelf_bounds.size.y * 0.5) * shelves.scale.y
	)
	var resolved_center_y := shelves.position.y + scaled_bounds_center_y
	var viewport_height: float = level.get_viewport_rect().size.y
	var expected_center_y: float = (
		BACK_WALL_TOP + viewport_height - BACK_WALL_BOTTOM_MARGIN
	) * 0.5
	_check(
		is_equal_approx(resolved_center_y, expected_center_y),
		"Level 4's shelf bounds should center on the visible back wall."
	)

	level.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_polygon_width(polygon: Polygon2D) -> float:
	var points := polygon.polygon
	if points.is_empty():
		return 0.0

	var minimum_x := points[0].x
	var maximum_x := points[0].x
	for point in points:
		minimum_x = minf(minimum_x, point.x)
		maximum_x = maxf(maximum_x, point.x)

	return (maximum_x - minimum_x) * absf(polygon.scale.x)


func _finish() -> void:
	if _failures.is_empty():
		print("Moving shelf row verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
