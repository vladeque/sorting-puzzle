extends RefCounted

## Opens the main-menu settings modal and exposes both ADS-008 compliance actions for responsive
## screenshot review. Production visibility remains driven by UMP and configured HTTPS URLs.


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("_open_settings_menu")
	await tree.create_timer(0.25).timeout
	var settings_menu: Node = scene_root.get("_settings_menu") as Node
	if settings_menu == null:
		push_error("ad_compliance_settings_setup could not open the settings menu.")
		return
	settings_menu.call("set_ad_compliance_actions", "Privacy Choices", true, true)
	for _frame in range(2):
		await tree.process_frame
