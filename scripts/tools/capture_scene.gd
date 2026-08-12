extends SceneTree

## Generic UI capture tool. Renders any scene at the project's responsive resolutions and writes one
## PNG per resolution so visual changes can be reviewed from pixels instead of from scene text.
##
## Run it through `scripts/tools/capture_ui.ps1`, which supplies the isolated project identity, the
## windowed Godot run this tool requires, and the ImageMagick contact sheet.
##
## Arguments arrive after the `--` separator as `--key value` or `--key=value`:
##   --scene        res:// path of the scene to capture (required)
##   --out          absolute directory for the generated PNGs (required)
##   --name         filename prefix (defaults to the scene's base name)
##   --resolutions  comma-separated `WIDTHxHEIGHT` list (defaults to DEFAULT_RESOLUTIONS)
##   --setup        res:// path of a setup script that prepares runtime state before capture
##   --settle       frames to wait after each resize before capturing (default SETTLE_FRAMES)
##   --background   HTML color painted behind the scene, for components that do not fill the screen
##   --position     `X,Y` canvas position for a Node2D root (defaults to the viewport center)
##   --zoom         canvas scale for the captured root, to make small components legible
##
## A setup script is any GDScript exposing `setup(scene_root: Node, tree: SceneTree) -> void`. It may
## await. Keep setup scripts in `scripts/tools/captures/`.
##
## Results go to `<out>/<name>_manifest.json` rather than stdout, because the windowed Godot binary
## on Windows is a GUI executable whose prints never reach the calling shell.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
## Mirrors the resolutions the responsive-UI convention in AGENTS.md requires layouts to support.
const DEFAULT_RESOLUTIONS := ["540x960", "720x1280", "1080x1920", "1080x2400", "1200x1600"]
const SETTLE_FRAMES := 6

var _failures: Array[String] = []
var _captures: Array[Dictionary] = []
var _manifest_path := ""


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Scene capture must run through scripts/tools/capture_ui.ps1.")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error(
			"Scene capture needs a windowed Godot run: a headless display server resolves the "
			+ "viewport texture to null. Use run_isolated_godot_test.ps1 -Windowed."
		)
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var options := _parse_arguments()
	var scene_path := str(options.get("scene", ""))
	var output_directory := str(options.get("out", ""))
	if scene_path.is_empty() or output_directory.is_empty():
		_failures.append("Scene capture requires both --scene and --out.")
		_finish()
		return

	var name_prefix := str(options.get("name", scene_path.get_file().get_basename()))
	_manifest_path = "%s/%s_manifest.json" % [output_directory, name_prefix]

	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		if not DirAccess.dir_exists_absolute(output_directory):
			_failures.append("Could not create the capture output directory: %s" % output_directory)
			_finish()
			return

	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		_failures.append("Could not load the scene to capture: %s" % scene_path)
		_finish()
		return

	var resolutions := _parse_resolutions(str(options.get("resolutions", "")))
	if resolutions.is_empty():
		_failures.append("Scene capture could not parse any --resolutions entry.")
		_finish()
		return

	if options.has("background"):
		_add_background(str(options["background"]))

	var scene_root := packed_scene.instantiate()
	root.add_child(scene_root)
	current_scene = scene_root
	await process_frame

	# A Control root is laid out by its own anchors against the resized window. A Node2D component
	# has no such layout, so place it where it stays on screen at every resolution.
	if scene_root is Node2D:
		(scene_root as Node2D).position = _resolve_node_2d_position(scene_root as Node2D, options)

	# A shelf-sized component occupies a small share of a phone-sized frame, which review images then
	# shrink further. Zoom keeps its detail readable without changing the layout being reviewed.
	var zoom_raw := str(options.get("zoom", ""))
	if not zoom_raw.is_empty() and scene_root is CanvasItem:
		var zoom := maxf(zoom_raw.to_float(), 0.01)
		(scene_root as CanvasItem).scale = Vector2(zoom, zoom)

	var setup_path := str(options.get("setup", ""))
	if not setup_path.is_empty():
		var setup_instance := _instantiate_setup(setup_path)
		if setup_instance == null:
			_finish()
			return
		await setup_instance.setup(scene_root, self)

	var settle_raw := str(options.get("settle", ""))
	var settle_frames := SETTLE_FRAMES if settle_raw.is_empty() else maxi(settle_raw.to_int(), 1)
	for resolution in resolutions:
		await _capture_resolution(resolution, output_directory, name_prefix, settle_frames)

	_finish()


func _capture_resolution(
	resolution: Vector2i, output_directory: String, name_prefix: String, settle_frames: int
) -> void:
	root.size = resolution
	for _frame in range(settle_frames):
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	if image == null:
		_failures.append("Viewport texture was empty at %dx%d." % [resolution.x, resolution.y])
		return

	# Measured from the image rather than from root.size: the window manager can refuse a size taller
	# than the desktop, and the project's stretch aspect can letterbox the render target well inside
	# the window. Either way the pixels are what the review is about, so report those.
	var actual_size := Vector2i(image.get_width(), image.get_height())

	var path := "%s/%s_%dx%d.png" % [output_directory, name_prefix, actual_size.x, actual_size.y]
	var save_error := image.save_png(path)
	if save_error != OK:
		_failures.append("Could not save %s (error %d)." % [path, save_error])
		return

	_captures.append({
		"path": path,
		"requested": "%dx%d" % [resolution.x, resolution.y],
		"actual": "%dx%d" % [actual_size.x, actual_size.y],
	})


func _resolve_node_2d_position(scene_root: Node2D, options: Dictionary) -> Vector2:
	if not options.has("position"):
		return scene_root.get_viewport_rect().size * 0.5
	var parts := str(options["position"]).split(",")
	if parts.size() != 2:
		_failures.append("Could not parse --position; expected `X,Y`.")
		return scene_root.position
	return Vector2(float(parts[0]), float(parts[1]))


## A missing or malformed setup script fails loudly instead of capturing an unprepared scene whose
## screenshots would merely look wrong.
func _instantiate_setup(setup_path: String) -> Object:
	var setup_script := load(setup_path) as GDScript
	if setup_script == null:
		_failures.append("Could not load the capture setup script: %s" % setup_path)
		return null
	var setup_instance = setup_script.new()
	if not setup_instance.has_method("setup"):
		_failures.append("Capture setup script %s does not define setup()." % setup_path)
		return null
	return setup_instance


func _add_background(color_code: String) -> void:
	var background := ColorRect.new()
	background.color = Color(color_code)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)


func _parse_resolutions(raw: String) -> Array[Vector2i]:
	var entries: Array = DEFAULT_RESOLUTIONS if raw.is_empty() else Array(raw.split(",", false))
	var resolutions: Array[Vector2i] = []
	for entry in entries:
		var parts := str(entry).strip_edges().split("x")
		if parts.size() != 2:
			_failures.append("Could not parse resolution `%s`; expected `WIDTHxHEIGHT`." % entry)
			continue
		var width := int(parts[0])
		var height := int(parts[1])
		if width <= 0 or height <= 0:
			_failures.append("Resolution `%s` must be positive." % entry)
			continue
		resolutions.append(Vector2i(width, height))
	return resolutions


func _parse_arguments() -> Dictionary:
	var options := {}
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		var token := str(arguments[index])
		if not token.begins_with("--"):
			_failures.append("Unexpected capture argument: %s" % token)
			index += 1
			continue
		var key := token.substr(2)
		var value := ""
		if key.contains("="):
			var split := key.split("=", true, 1)
			key = split[0]
			value = split[1]
		elif index + 1 < arguments.size() and not str(arguments[index + 1]).begins_with("--"):
			index += 1
			value = str(arguments[index])
		options[key] = value
		index += 1
	return options


func _finish() -> void:
	_write_manifest()
	if _failures.is_empty():
		print("SCENE CAPTURE PASSED")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _write_manifest() -> void:
	if _manifest_path.is_empty():
		return
	var manifest := {
		"captures": _captures,
		"failures": _failures,
	}
	var file := FileAccess.open(_manifest_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write the capture manifest: %s" % _manifest_path)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
