extends SceneTree

## Focused verification for the standard shelf's image-backed light-oak frame. The scene keeps the
## original Polygon2D faces because their separate z-order and visibility rules are gameplay-facing;
## this test protects the texture assignments and UV orientation without involving dispensers.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const SHELF_SCENE_PATH := "res://scenes/shelf.tscn"
const WOOD_TEXTURE_PATH := "res://assets/shelves/standard_shelf_light_oak.png"

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

	shelf.free()
	_finish()


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
