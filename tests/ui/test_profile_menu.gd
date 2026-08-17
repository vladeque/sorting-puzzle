extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const PROFILE_MENU_SCENE_PATH := "res://scenes/ui/profile_menu.tscn"

var _failures: Array[String] = []
var _progress: Node


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Profile menu tests must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_progress = root.get_node_or_null("PlayerProgress")
	_check(_progress != null, "PlayerProgress autoload is available.")
	if _progress == null:
		quit(1)
		return
	_progress.reset_progress()
	var profile_scene := load(PROFILE_MENU_SCENE_PATH) as PackedScene
	var menu := profile_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame

	var grid := menu.get_node("%ChoiceGrid") as GridContainer
	_check(grid.get_child_count() == 18, "Avatar tab shows all 18 avatars.")
	_check(
		str(menu.get("_selected_avatar_frame_id")) == "frame_classic",
		"Existing profiles begin with the classic frame."
	)
	menu.call("_switch_tab", &"frame")
	await process_frame
	_check(grid.get_child_count() == 9, "Frame tab shows all configured frames.")
	menu.call("_select_choice", "frame_plum")
	menu.call("_switch_tab", &"avatar")
	await process_frame
	menu.call("_select_choice", "avatar_penguin")
	menu.call("_begin_name_edit")
	var name_input := menu.get_node("%NameLineEdit") as LineEdit
	name_input.text = "Profile Tester"
	menu.call("_finish_name_edit", name_input.text)
	var saved_customization: Array = []
	menu.connect("profile_saved", func(avatar_id: String, frame_id: String) -> void:
		saved_customization.assign([avatar_id, frame_id])
	)
	menu.call("_save_selection")
	_check(_progress.get_avatar_id() == "avatar_penguin", "Save commits the selected avatar.")
	_check(_progress.get_avatar_frame_id() == "frame_plum", "Save commits the selected frame.")
	_check(_progress.get_player_name() == "Profile Tester", "Save commits the edited name.")
	_check(
		saved_customization == ["avatar_penguin", "frame_plum"],
		"Save emits the complete profile customization."
	)
	await _wait_frames(60)

	var discard_menu := profile_scene.instantiate() as Control
	root.add_child(discard_menu)
	await process_frame
	discard_menu.call("_select_choice", "avatar_bear")
	discard_menu.call("close")
	await _wait_frames(60)
	_check(_progress.get_avatar_id() == "avatar_penguin", "Close discards pending avatar changes.")

	if _failures.is_empty():
		print("Profile menu tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
