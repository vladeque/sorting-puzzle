extends Node

## Persistent owner for entering a campaign level. It keeps the loading overlay alive while the
## outgoing scene is replaced, and only activates gameplay after the reveal has finished.

const LEVEL_SCENE_PATH := "res://level.tscn"
const LOADING_SCREEN_SCENE := preload("res://scenes/ui/level_loading_screen.tscn")

var _is_transitioning := false


func is_transitioning() -> bool:
	return _is_transitioning


func launch_level(
	level_number: int,
	launched_from_dev_mode: bool,
	return_menu_scene_path: String,
	launch_properties: Dictionary = {},
	source_scene: Node = null
) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_run_level_launch(
		level_number,
		launched_from_dev_mode,
		return_menu_scene_path,
		launch_properties,
		source_scene,
		false
	)


## Campaign start straight from app launch. There is no outgoing screen for the iris to close over,
## so the loading screen starts fully closed and only the mascot animates in.
func launch_level_at_startup(
	level_number: int,
	return_menu_scene_path: String,
	source_scene: Node = null
) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_run_level_launch(level_number, false, return_menu_scene_path, {}, source_scene, true)


func _run_level_launch(
	level_number: int,
	launched_from_dev_mode: bool,
	return_menu_scene_path: String,
	launch_properties: Dictionary,
	source_scene: Node,
	start_covered: bool
) -> void:
	var tree := get_tree()
	var outgoing_scene := source_scene if is_instance_valid(source_scene) else tree.current_scene
	var loading_screen := LOADING_SCREEN_SCENE.instantiate() as LevelLoadingScreen
	tree.root.add_child(loading_screen)
	if is_instance_valid(outgoing_scene):
		outgoing_scene.process_mode = Node.PROCESS_MODE_DISABLED

	var request_error := ResourceLoader.load_threaded_request(LEVEL_SCENE_PATH, "PackedScene", true)
	await loading_screen.play_cover(not start_covered)

	var packed_level: PackedScene
	if request_error == OK:
		var load_status := ResourceLoader.load_threaded_get_status(LEVEL_SCENE_PATH)
		while load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame
			load_status = ResourceLoader.load_threaded_get_status(LEVEL_SCENE_PATH)
		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			packed_level = ResourceLoader.load_threaded_get(LEVEL_SCENE_PATH) as PackedScene
	if packed_level == null:
		packed_level = load(LEVEL_SCENE_PATH) as PackedScene

	if packed_level == null:
		push_error("Could not load level scene: %s" % LEVEL_SCENE_PATH)
		if is_instance_valid(outgoing_scene):
			outgoing_scene.process_mode = Node.PROCESS_MODE_INHERIT
		await loading_screen.play_reveal()
		loading_screen.queue_free()
		_is_transitioning = false
		return

	var next_level := packed_level.instantiate()
	next_level.set("selected_level", level_number)
	next_level.set("launched_from_dev_mode", launched_from_dev_mode)
	next_level.set("return_menu_scene_path", return_menu_scene_path)
	for property_name in launch_properties:
		next_level.set(StringName(property_name), launch_properties[property_name])
	if next_level.has_method("prepare_for_loading_transition"):
		next_level.call("prepare_for_loading_transition")

	tree.root.add_child(next_level)
	tree.current_scene = next_level
	if is_instance_valid(outgoing_scene):
		outgoing_scene.queue_free()
	await tree.process_frame
	await tree.process_frame
	await loading_screen.play_reveal()
	if is_instance_valid(next_level) and next_level.has_method("activate_after_loading_transition"):
		next_level.call("activate_after_loading_transition")
	loading_screen.queue_free()
	_is_transitioning = false
