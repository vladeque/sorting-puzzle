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
	var unlock_toast := menu.get_node("%UnlockToast") as ToastMessage
	var edit_name_button := menu.get_node("%EditNameButton") as Button
	var pencil_icon := edit_name_button.get_node_or_null("%PencilIcon") as TextureRect
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
		pencil_icon != null and pencil_icon.texture != null,
		"Name edit uses the compact generated pencil texture."
	)
	_check(
		pencil_icon != null
		and pencil_icon.texture.resource_path == "res://assets/ui/pencil_icon.png",
		"Name edit uses the intended project pencil asset."
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
	var expected_avatar_position := (profile_preview.size - preview_avatar_texture.size) * 0.5
	_check(
		preview_avatar_texture.position.is_equal_approx(expected_avatar_position),
		"Avatar preview remains centered beneath its frame."
	)
	_check(
		is_equal_approx(preview_avatar_texture.position.x, 7.0)
		and is_equal_approx(preview_avatar_texture.position.y, 7.0),
		"Avatar preview overlaps the frame's inner rim without leaving a visible seam."
	)
	_check(
		preview_avatar_texture.texture.resource_path != preview_frame_texture.texture.resource_path,
		"Avatar and frame layers use separate textures."
	)
	for frame_id in ProfileFrameCatalogScript.get_available_frame_ids():
		var texture_path := ProfileFrameCatalogScript.get_frame_texture_path(str(frame_id))
		_check(ResourceLoader.exists(texture_path, "Texture2D"), "Frame texture exists: %s" % frame_id)
		var frame_texture := load(texture_path) as Texture2D
		if frame_texture == null:
			continue
		var frame_image := frame_texture.get_image()
		_check(frame_image.get_size() == Vector2i(256, 256),
			"Frame %s uses the shared 256 px canvas." % frame_id)
		if frame_image.get_size() != Vector2i(256, 256):
			continue
		for angle_degrees in range(0, 360, 15):
			var angle := deg_to_rad(float(angle_degrees))
			var point := Vector2(127.5, 127.5) + Vector2.from_angle(angle) * 92.0
			_check(frame_image.get_pixel(roundi(point.x), roundi(point.y)).a < 0.05,
				"Frame %s keeps the shared avatar opening clear at %d°." % [frame_id, angle_degrees])
	_check(
		str(menu.get("_selected_avatar_frame_id")) == "frame_classic",
		"Existing profiles begin with the classic frame."
	)
	menu.call("_switch_tab", &"frame")
	await process_frame
	_check(grid.get_child_count() == 19, "Frame tab shows standard and achievement frames.")
	_check(not _progress.get_available_avatar_frame_ids().has("frame_weekly_bronze"),
		"Weekly frames stay locked before an authoritative award.")
	var locked_requirements := {
		"frame_weekly_bronze": "top 3",
		"frame_weekly_silver": "top 2",
		"frame_weekly_gold": "1st",
		"frame_combo_20": "×20",
		"frame_combo_50": "×50",
		"frame_level_20": "level 20",
		"frame_level_50": "level 50",
		"frame_level_100": "level 100",
		"frame_level_200": "level 200",
		"frame_level_500": "level 500",
	}
	_check(not unlock_toast.visible, "The unlock toast starts hidden.")
	_check(unlock_toast.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The unlock toast never blocks taps on the picker.")
	for frame_id in locked_requirements:
		var tile := (menu.get("_choice_tiles") as Dictionary)[frame_id] as Button
		var tile_preview := tile.get_node("%ProfileAvatarView") as Control
		var lock_icon := tile.get_node("%LockIcon") as TextureRect
		_check(bool(tile.get("_is_locked")), "Unearned %s tile is locked." % frame_id)
		_check(tile.get_node_or_null("%LockedBadge") == null,
			"Unearned %s tile has no LOCKED text badge." % frame_id)
		_check(lock_icon.visible and lock_icon.texture != null,
			"Unearned %s tile shows a lock icon." % frame_id)
		_check(lock_icon.get_rect().get_center().is_equal_approx(tile.size * 0.5),
			"Unearned %s lock sits in the middle of the tile." % frame_id)
		_check(lock_icon.size.x < tile.size.x * 0.5, "Unearned %s lock stays small." % frame_id)
		_check((tile_preview.get_node("%AvatarTexture") as CanvasItem).self_modulate.r < 0.6,
			"Unearned %s tile darkens the avatar under the lock." % frame_id)
		_check((tile_preview.get_node("%FrameTexture") as CanvasItem).self_modulate == Color.WHITE
			and tile_preview.modulate == Color.WHITE,
			"Unearned %s tile keeps the frame art in full color." % frame_id)
		tile.pressed.emit()
		_check(unlock_toast.visible
			and unlock_toast.get_message().contains(str(locked_requirements[frame_id])),
			"Tapping %s explains its unlock requirement." % frame_id)
		_check(unlock_toast.get_message().length() <= 50,
			"The %s unlock explanation stays short." % frame_id)
		_check(str(menu.get("_selected_avatar_frame_id")) == "frame_classic",
			"Tapping %s does not select an unearned frame." % frame_id)
	var unlocked_tile := (menu.get("_choice_tiles") as Dictionary)["frame_classic"] as Button
	_check(not (unlocked_tile.get_node("%LockIcon") as Control).visible,
		"Earned frames show no lock icon.")
	var toast_band := unlock_toast.get_node("Band") as Control
	_check(absf(toast_band.get_global_rect().get_center().y - menu.size.y * 0.5) < 2.0,
		"The unlock toast appears in the middle of the screen.")
	_check(is_equal_approx(unlock_toast.display_seconds, 2.0),
		"The unlock toast is configured to disappear after two seconds.")
	await create_timer(1.5).timeout
	_check(unlock_toast.visible, "The unlock toast is still readable after 1.5 seconds.")
	await create_timer(0.8).timeout
	_check(not unlock_toast.visible, "The unlock toast disappears on its own after two seconds.")
	_check(not _progress.set_profile_customization(
		_progress.get_avatar_id(), "frame_weekly_gold", _progress.get_player_name()
	), "A locked gold frame cannot be saved.")
	var save_data := _progress.get("_data") as Dictionary
	for best_rank in [3, 2, 1]:
		save_data["weekly_frame_best_rank"] = best_rank
		menu.call("_rebuild_choice_grid")
		var unlocked: Array[String] = _progress.get_available_avatar_frame_ids()
		_check(unlocked.has("frame_weekly_bronze"), "Third place unlocks bronze.")
		_check(unlocked.has("frame_weekly_silver") == (best_rank <= 2),
			"Second place unlocks silver and bronze.")
		_check(unlocked.has("frame_weekly_gold") == (best_rank == 1),
			"First place unlocks all three frames.")
		for frame_id in locked_requirements:
			var tile := (menu.get("_choice_tiles") as Dictionary)[frame_id] as Button
			_check(bool(tile.get("_is_locked")) == not unlocked.has(frame_id),
				"%s tile reflects the earned rank %d." % [frame_id, best_rank])
	save_data["weekly_frame_best_rank"] = 0
	for combo_best in [20, 50]:
		save_data["combo_best"] = combo_best
		menu.call("_rebuild_choice_grid")
		var unlocked: Array[String] = _progress.get_available_avatar_frame_ids()
		_check(unlocked.has("frame_combo_20"), "A ×20 combo unlocks the first combo frame.")
		_check(unlocked.has("frame_combo_50") == (combo_best == 50),
			"A ×50 combo also unlocks the second combo frame.")
		for frame_id in ["frame_combo_20", "frame_combo_50"]:
			var tile := (menu.get("_choice_tiles") as Dictionary)[frame_id] as Button
			_check(bool(tile.get("_is_locked")) == not unlocked.has(frame_id),
				"%s tile reflects the best earned combo %d." % [frame_id, combo_best])
	save_data["combo_best"] = 0
	var level_requirements := [20, 50, 100, 200, 500]
	var completion_stars := save_data["completion_stars_by_level"] as Dictionary
	for level_number in level_requirements:
		completion_stars[str(level_number)] = 1
		menu.call("_rebuild_choice_grid")
		var unlocked: Array[String] = _progress.get_available_avatar_frame_ids()
		for required_level in level_requirements:
			var frame_id := "frame_level_%d" % required_level
			_check(unlocked.has(frame_id) == (required_level <= level_number),
				"Completing level %d unlocks the expected milestone frame." % level_number)
			var tile := (menu.get("_choice_tiles") as Dictionary)[frame_id] as Button
			_check(bool(tile.get("_is_locked")) == not unlocked.has(frame_id),
				"The level %d frame tile reflects completion progress." % required_level)
	completion_stars.clear()
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
