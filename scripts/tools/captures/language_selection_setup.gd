extends RefCounted

## Opens Settings and then its Language modal for deterministic stacked-overlay capture.


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("_open_settings_menu")
	await tree.create_timer(0.15).timeout
	var settings_menu := scene_root.get("_settings_menu") as Control
	if settings_menu == null:
		push_error("language_selection_setup could not open the settings menu.")
		return
	var language_button := settings_menu.find_child("LanguageButton", true, false) as Button
	if language_button == null:
		push_error("language_selection_setup could not find the Language button.")
		return
	language_button.pressed.emit()
	await tree.create_timer(0.4).timeout
