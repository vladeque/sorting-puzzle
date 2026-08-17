extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const PROFILE_MENU_SCENE_PATH := "res://scenes/ui/profile_menu.tscn"
const ProfileFrameCatalogScript := preload("res://scripts/profile_frame_catalog.gd")

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
	var choice_scroll := menu.get_node("%ChoiceScroll") as ScrollContainer
	var edit_name_button := menu.get_node("%EditNameButton") as Button
	var name_input := menu.get_node("%NameLineEdit") as LineEdit
	var profile_preview := menu.get_node("%ProfilePreview") as Control
	var preview_avatar_texture := profile_preview.get_node("%AvatarTexture") as TextureRect
	var preview_frame_texture := profile_preview.get_node("%FrameTexture") as TextureRect
	_check(grid.get_child_count() == 18, "Avatar tab shows all 18 avatars.")
	_check(edit_name_button.text.is_empty(), "Name edit no longer uses a text label.")
	_check(name_input.visible, "Player name is always displayed in a real input field.")
	_check(not name_input.editable, "Player name input begins in a locked display state.")
	_check(name_input.focus_mode == Control.FOCUS_NONE, "Locked name input does not take focus.")
	_check(
		edit_name_button.get_node_or_null("%PencilIcon") != null,
		"Name edit uses the compact code-drawn pencil icon."
	)
	_check(
		edit_name_button.custom_minimum_size == Vector2(52, 52),
		"Name edit pencil keeps a compact square touch target."
	)
	_check(
		choice_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
		"Avatar list stays scrollable without a visible scrollbar."
	)
	_check(
		not choice_scroll.get_v_scroll_bar().visible,
		"Avatar list does not render a vertical scroll indicator."
	)
	choice_scroll.scroll_vertical = 64
	await process_frame
	_check(choice_scroll.scroll_vertical > 0, "Hidden-indicator avatar list still scrolls.")
	_check(
		grid.size_flags_horizontal & Control.SIZE_EXPAND != 0,
		"Avatar grid expands across the available light panel width."
	)
	_check(preview_avatar_texture.texture != null, "Profile preview has a standalone avatar layer.")
	_check(preview_frame_texture.texture != null, "Profile preview has a standalone frame layer.")
	var avatar_material := preview_avatar_texture.material as ShaderMaterial
	_check(avatar_material != null, "Avatar preview uses the shared background-preserving shader.")
	var avatar_content_scale: float = avatar_material.get_shader_parameter("content_scale")
	var avatar_sharpen_strength: float = avatar_material.get_shader_parameter("sharpen_strength")
	_check(
		is_equal_approx(avatar_content_scale, 0.92),
		"Avatar content is scaled to 92% so more background remains visible."
	)
	_check(
		is_equal_approx(avatar_sharpen_strength, 0.35),
		"Scaled avatar content uses restrained detail sharpening."
	)
	_check(
		preview_avatar_texture.texture.resource_path != preview_frame_texture.texture.resource_path,
		"Avatar and frame layers use separate textures."
	)
	for frame_id in _progress.get_available_avatar_frame_ids():
		var texture_path := ProfileFrameCatalogScript.get_frame_texture_path(str(frame_id))
		_check(ResourceLoader.exists(texture_path, "Texture2D"), "Frame texture exists: %s" % frame_id)
	_check(
		str(menu.get("_selected_avatar_frame_id")) == "frame_classic",
		"Existing profiles begin with the classic frame."
	)
	menu.call("_switch_tab", &"frame")
	await process_frame
	_check(grid.get_child_count() == 9, "Frame tab shows all configured frames.")
	menu.call("_select_choice", "frame_plum")
	_check(
		preview_frame_texture.texture.resource_path.ends_with("frame_plum.png"),
		"Selecting a frame updates only the frame texture layer."
	)
	menu.call("_switch_tab", &"avatar")
	await process_frame
	menu.call("_select_choice", "avatar_penguin")
	menu.call("_begin_name_edit")
	_check(name_input.editable, "Pencil unlocks the player name input for editing.")
	_check(name_input.focus_mode == Control.FOCUS_ALL, "Editable name input accepts keyboard focus.")
	name_input.text = "Profile Tester"
	menu.call("_finish_name_edit", name_input.text)
	_check(not name_input.editable, "Submitting locks the player name input again.")
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
