extends SceneTree

## Focused verification for the standard shelf's image-backed light-oak frame. The scene keeps the
## original Polygon2D faces because their separate z-order and visibility rules are gameplay-facing;
## this test protects the texture assignments and UV orientation without involving dispensers.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const SHELF_SCENE_PATH := "res://scenes/shelf.tscn"
const ITEM_SCENE_PATH := "res://scenes/item.tscn"
const WOOD_TEXTURE_PATH := "res://assets/shelves/standard_shelf_light_oak.png"
const BACK_WALL_SHADOW_SHADER_PATH := "res://assets/shaders/shelf_back_wall_shadow.gdshader"
const LINEAR_SHADOW_SHADER_PATH := "res://assets/shaders/shelf_linear_shadow.gdshader"
const FLOOR_CORNER_SHADER_PATH := "res://assets/shaders/shelf_corner_shadow.gdshader"
const EXPECTED_INTERIOR_HEIGHT := Shelf.ORIGINAL_INTERIOR_HEIGHT * Shelf.INTERIOR_HEIGHT_SCALE
const EXPECTED_FLOOR_TOP := 16.0
const EXPECTED_SLOT_POSITIONS := [Vector2(-60, 15), Vector2(0, 15), Vector2(60, 15)]

const WALL_PATHS := [
	"PlacementVisuals/Left/LeftWall",
	"PlacementVisuals/Left/RightWall",
	"PlacementVisuals/Middle/LeftWall",
	"PlacementVisuals/Middle/RightWall",
	"PlacementVisuals/Right/LeftWall",
	"PlacementVisuals/Right/RightWall",
]
const HORIZONTAL_FACE_PATHS := [
	"PlacementVisuals/Left/TopCeilingCap/BackBoard",
	"PlacementVisuals/Middle/TopCeilingCap/BackBoard",
	"PlacementVisuals/Right/TopCeilingCap/BackBoard",
	"Ceiling",
	"FloorSurface",
	"FloorFrontLip",
]
const LEGACY_GRAIN_PATHS := [
	"PlacementVisuals/Left/TopCeilingCap/GrainTop",
	"PlacementVisuals/Middle/TopCeilingCap/GrainTop",
	"PlacementVisuals/Right/TopCeilingCap/GrainTop",
	"FloorGrainBack",
	"FloorGrainMiddle",
	"FloorGrainKnot",
	"FloorGrainFront",
]
const SOFT_CAST_SHADOW_PATHS := [
	"Shadow",
	"RightColumnShadow",
]
const LEGACY_EDGE_SHADOW_PATHS := [
	"PlacementVisuals/Left/LeftShadowEdge",
	"PlacementVisuals/Middle/LeftShadowEdge",
	"PlacementVisuals/Middle/RightShadowEdge",
	"PlacementVisuals/Right/RightShadowEdge",
]
const ITEM_SHADOW_UNDERLAY_PATHS := [
	"Shadow",
	"RightColumnShadow",
	"BackWallTopShade",
	"PlacementVisuals/Left/BackWallLeftShade",
	"PlacementVisuals/Middle/BackWallLeftShade",
	"PlacementVisuals/Right/BackWallLeftShade",
]
const SOFT_BACK_WALL_SHADOW_PATHS := [
	"BackWallTopShade",
	"PlacementVisuals/Left/BackWallLeftShade",
	"PlacementVisuals/Middle/BackWallLeftShade",
	"PlacementVisuals/Right/BackWallLeftShade",
]

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Standard shelf wood verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed_scene := load(SHELF_SCENE_PATH) as PackedScene
	var shelf := packed_scene.instantiate() if packed_scene != null else null
	_check(shelf != null, "The standard shelf scene should instantiate.")
	if shelf == null:
		_finish()
		return

	for node_path in WALL_PATHS:
		var wall := shelf.get_node_or_null(node_path) as Polygon2D
		_check_textured_face(wall, node_path)
		if wall != null and wall.uv.size() == wall.polygon.size():
			var across_width := wall.uv[1] - wall.uv[0]
			var along_height := wall.uv[2] - wall.uv[1]
			_check(
				absf(across_width.y) > absf(across_width.x)
				and absf(along_height.x) > absf(along_height.y),
				"%s should rotate the source's horizontal grain along the vertical support." % node_path
			)

	for node_path in HORIZONTAL_FACE_PATHS:
		var face := shelf.get_node_or_null(node_path) as Polygon2D
		_check_textured_face(face, node_path)
		if face != null and face.uv.size() == face.polygon.size():
			var along_width := face.uv[1] - face.uv[0]
			_check(
				absf(along_width.x) > absf(along_width.y),
				"%s should keep the source grain horizontal." % node_path
			)

	for node_path in LEGACY_GRAIN_PATHS:
		var grain := shelf.get_node_or_null(node_path) as CanvasItem
		_check(grain != null and not grain.visible, "%s should stay hidden behind image grain." % node_path)

	for node_path in SOFT_CAST_SHADOW_PATHS:
		var shadow := shelf.get_node_or_null(node_path) as Polygon2D
		var material := shadow.material as ShaderMaterial if shadow != null else null
		_check(
			material != null
				and material.shader != null
				and material.shader.resource_path == LINEAR_SHADOW_SHADER_PATH,
			"%s should use the background-independent linear shadow shader." % node_path
		)
		_check(shadow != null and shadow.uv.size() == shadow.polygon.size(),
			"%s should map its soft falloff across every polygon vertex." % node_path)
		_check(
			shadow != null and shadow.antialiased,
			"%s should antialias its soft outer edge." % node_path
		)

	for node_path in LEGACY_EDGE_SHADOW_PATHS:
		var edge := shelf.get_node_or_null(node_path) as Polygon2D
		_check(
			edge != null
				and edge.material == null
				and edge.z_index == 6
				and edge.color == Color(0.6, 0.35, 0.17, 1),
			"%s should retain its original opaque edge-shadow treatment." % node_path
		)

	for node_path in SOFT_BACK_WALL_SHADOW_PATHS:
		var shadow := shelf.get_node_or_null(node_path) as Polygon2D
		var material := shadow.material as ShaderMaterial if shadow != null else null
		_check(
			material != null
				and material.shader != null
				and material.shader.resource_path == BACK_WALL_SHADOW_SHADER_PATH,
			"%s should use the procedural soft-shadow shader." % node_path
		)

	var floor_corner := shelf.get_node_or_null("FloorSurface/Shade") as Polygon2D
	var floor_corner_material := floor_corner.material as ShaderMaterial if floor_corner != null else null
	_check(
		floor_corner_material != null
			and floor_corner_material.shader != null
			and floor_corner_material.shader.resource_path == FLOOR_CORNER_SHADER_PATH,
		"The floor corner should use a feathered two-axis occlusion shader."
	)
	_check_taller_frame_geometry(shelf)
	_check_exterior_shadow_partitioning(shelf)
	_check_item_shadow_layers_over_shelf_shadows(shelf)

	shelf.free()
	_finish()


func _check_exterior_shadow_partitioning(shelf: Shelf) -> void:
	var bottom_shadow := shelf.get_node_or_null("Shadow") as Polygon2D
	var right_shadow := shelf.get_node_or_null("RightColumnShadow") as Polygon2D
	shelf.set_exterior_shadow_connections(false, true, false, true)
	_check(
		bottom_shadow != null
			and is_equal_approx(bottom_shadow.polygon[1].x, 108.0)
			and is_equal_approx(bottom_shadow.polygon[2].x, 114.0),
		"A bottom cast should end at the midpoint of its shared strip on the right."
	)
	_check(
		right_shadow != null
			and is_equal_approx(right_shadow.polygon[1].y, 36.5)
			and is_equal_approx(right_shadow.polygon[2].y, 42.0),
		"A right cast should end at the midpoint of its shared strip below."
	)
	shelf.set_exterior_shadow_connections(true, false, true, false)
	_check(
		bottom_shadow != null
			and is_equal_approx(bottom_shadow.polygon[0].x, -108.0)
			and is_equal_approx(bottom_shadow.polygon[3].x, -102.0),
		"A bottom cast should begin at the midpoint of its shared strip on the left."
	)
	_check(
		right_shadow != null
			and is_equal_approx(right_shadow.polygon[0].y, -100.2)
			and is_equal_approx(right_shadow.polygon[3].y, -94.7),
		"A right cast should begin at the midpoint of its shared strip above."
	)
	shelf.set_exterior_shadow_connections(false, false, false, false)


func _check_taller_frame_geometry(shelf: Node) -> void:
	var back_wall := shelf.get_node_or_null("BackWall") as Polygon2D
	_check(back_wall != null, "The standard shelf should keep its back-wall polygon.")
	if back_wall != null:
		var minimum_y := back_wall.polygon[0].y
		var maximum_y := back_wall.polygon[0].y
		for point in back_wall.polygon:
			minimum_y = minf(minimum_y, point.y)
			maximum_y = maxf(maximum_y, point.y)
		_check(
			is_equal_approx(maximum_y - minimum_y, EXPECTED_INTERIOR_HEIGHT),
			"The standard shelf interior should be exactly 10% taller."
		)
		_check(
			is_equal_approx(maximum_y, EXPECTED_FLOOR_TOP),
			"The taller shelf should stay anchored to the existing floor."
		)

	for slot_index in range(EXPECTED_SLOT_POSITIONS.size()):
		var slot := shelf.get_node_or_null("Slot%02d" % (slot_index + 1)) as Node2D
		_check(
			slot != null and slot.position == EXPECTED_SLOT_POSITIONS[slot_index],
			"The taller frame should not move Slot%02d or its item." % (slot_index + 1)
		)


func _check_item_shadow_layers_over_shelf_shadows(shelf: Node) -> void:
	var item_scene := load(ITEM_SCENE_PATH) as PackedScene
	var item := item_scene.instantiate() if item_scene != null else null
	_check(item != null, "The item scene should instantiate for shadow-layer verification.")
	if item == null:
		return

	var item_shadow := item.get_node_or_null("Shadow") as CanvasItem
	_check(item_shadow != null, "The item should own a contact shadow.")
	if item_shadow != null:
		var item_shadow_z: int = (
			item.z_index + item_shadow.z_index if item_shadow.z_as_relative else item_shadow.z_index
		)
		for node_path in ITEM_SHADOW_UNDERLAY_PATHS:
			var shelf_shadow := shelf.get_node_or_null(node_path) as CanvasItem
			_check(
				shelf_shadow != null and shelf_shadow.z_index < item_shadow_z,
				"Item shadows should render above %s and darken their overlap." % node_path
			)

	item.free()


func _check_textured_face(face: Polygon2D, node_path: String) -> void:
	_check(face != null, "%s should remain a Polygon2D face." % node_path)
	if face == null:
		return

	_check(
		face.texture != null and face.texture.resource_path == WOOD_TEXTURE_PATH,
		"%s should use the selected standard shelf light-oak texture." % node_path
	)
	_check(
		face.uv.size() == face.polygon.size(),
		"%s should define one UV coordinate per polygon vertex." % node_path
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Standard shelf wood verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
