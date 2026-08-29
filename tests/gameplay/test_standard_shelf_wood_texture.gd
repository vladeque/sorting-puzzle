extends SceneTree

## Focused verification for the standard shelf's image-backed light-oak frame. The scene keeps the
## original Polygon2D faces because their separate z-order and visibility rules are gameplay-facing;
## this test protects the texture assignments and UV orientation without involving dispensers.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const SHELF_SCENE_PATH := "res://scenes/shelf.tscn"
const ITEM_SCENE_PATH := "res://scenes/item.tscn"
const WOOD_TEXTURE_PATH := "res://assets/shelves/standard_shelf_light_oak.png"
const ORIGINAL_INTERIOR_HEIGHT := 97.0
const EXPECTED_INTERIOR_HEIGHT := ORIGINAL_INTERIOR_HEIGHT * 1.1
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
const NON_COMPOUNDING_SHADOW_PATHS := [
	"Shadow",
	"RightColumnShadow",
	"BackWallTopShade",
	"PlacementVisuals/Left/BackWallLeftShade",
	"PlacementVisuals/Left/LeftShadowEdge",
	"PlacementVisuals/Middle/BackWallLeftShade",
	"PlacementVisuals/Middle/LeftShadowEdge",
	"PlacementVisuals/Middle/RightShadowEdge",
	"PlacementVisuals/Right/BackWallLeftShade",
	"PlacementVisuals/Right/RightShadowEdge",
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

	for node_path in NON_COMPOUNDING_SHADOW_PATHS:
		var shadow := shelf.get_node_or_null(node_path) as Polygon2D
		_check(shadow != null, "%s should remain a shelf shadow polygon." % node_path)
		_check(
			shadow != null and is_equal_approx(shadow.color.a, 1.0),
			"%s should stay opaque so overlapping shelves cannot compound." % node_path
		)

	_check_taller_frame_geometry(shelf)
	_check_item_shadow_layers_over_shelf_shadows(shelf)

	shelf.free()
	_finish()


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
		for node_path in NON_COMPOUNDING_SHADOW_PATHS:
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
