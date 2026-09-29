extends SceneTree

## Verifies the shop-awning modal header on every modal: the gameplay shell uses it by default, the
## main-menu popups and notice dialogs instance it directly, the canopy covers the plate by node
## order, the plate follows configure(), and long titles stay clear of the close button.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const PAUSE_SCENE_PATH := "res://scenes/pause_menu.tscn"
const LONG_TITLE := "LEAVING THE LEVEL"
const SHELL_SCENE_PATHS: Array[String] = [
	"res://scenes/pause_menu.tscn",
	"res://scenes/leave_confirmation_menu.tscn",
	"res://scenes/ability_purchase_menu.tscn",
	"res://scenes/ui/language_selection_modal.tscn",
	"res://scenes/ui/level_failure_screen.tscn",
	"res://scenes/ui/out_of_lives_menu.tscn",
	"res://scenes/ui/shelf_unlock_menu.tscn",
	"res://scenes/ui/starter_bundle_offer_modal.tscn",
	"res://scenes/ui/time_up_extension_modal.tscn",
]
const MENU_POPUP_TITLES := {
	"res://scenes/ui/settings_menu.tscn": "SETTINGS",
	"res://scenes/ui/profile_menu.tscn": "EDIT PROFILE",
	"res://scenes/ui/reward_chest_menu.tscn": "CHEST REWARDS",
}
const PURCHASE_DIALOG_PATH := "res://scenes/ui/shop_purchase_dialog.tscn"
const REWARD_DIALOG_PATH := "res://scenes/ui/leaderboard_reward_dialog.tscn"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Modal awning header verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_pause_uses_awning()
	await _test_shell_modals_use_awning()
	await _test_menu_popups_use_awning()
	await _test_notice_dialogs_use_awning()

	if _failures.is_empty():
		print("Modal awning header verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_pause_uses_awning() -> void:
	var pause := (load(PAUSE_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(pause)
	await process_frame

	var shell := pause.find_child("Shell", true, false) as Control
	var outer_panel := shell.find_child("OuterPanel", true, false) as Control
	var title_label := shell.find_child("TitleLabel", true, false) as Label
	var awning := shell.find_child("AwningHeader", true, false) as Control
	var plate := awning.find_child("TitlePlate", true, false) as Control
	var plate_label := awning.find_child("PlateLabel", true, false) as Label
	var close_button := shell.find_child("CloseButton", true, false) as Button

	_check(awning.visible and not title_label.visible, "Pause shows the awning instead of the plain title.")
	_check(plate_label.text == "PAUSE", "The awning plate carries the Pause title.")
	_check(
		is_equal_approx(plate.get_global_rect().get_center().x, outer_panel.get_global_rect().get_center().x),
		"The title plate is centered on the panel."
	)
	_check(
		awning.get_global_rect().position.y < outer_panel.get_global_rect().position.y,
		"The awning rail sits above the panel's top edge."
	)
	_check(
		close_button.get_index() > awning.get_index(),
		"The close button draws above the awning."
	)
	var canopy := awning.find_child("Canopy", true, false) as Control
	var rail := awning.find_child("Rail", true, false) as Control
	_check(
		plate.get_index() < canopy.get_index() and canopy.get_index() < rail.get_index(),
		"The canopy's scallops cover the plate's top edge and the rail covers the canopy."
	)
	_check(
		awning.z_index == 0 and plate.z_index == 0 and plate.z_as_relative,
		"Header layering comes from node order, not z_index, so later overlays still cover it."
	)
	_check(
		plate.get_global_rect().position.y < canopy.get_global_rect().position.y + 89.0,
		"The plate's top edge tucks behind the scallops."
	)
	for node in [awning, rail, canopy, plate]:
		_check(
			(node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%s must not swallow taps meant for the close button." % node.name
		)
	_check(
		is_equal_approx(close_button.anchor_left, 1.0)
			and is_equal_approx(close_button.offset_left, -28.0)
			and is_equal_approx(close_button.offset_top, -76.0),
		"The close button moves up onto the right end of the rail."
	)
	_check(
		close_button.get_global_rect().get_center().x > outer_panel.get_global_rect().end.x - 36.0,
		"The close button sits at the panel's top-right corner."
	)
	_check(
		close_button.get_global_rect().intersects(rail.get_global_rect()),
		"The close button sits on the rail."
	)

	shell.call("configure", LONG_TITLE, true)
	await process_frame
	var plate_rect := plate.get_global_rect()
	_check(plate_label.text == LONG_TITLE, "configure() updates the awning plate.")
	_check(
		not plate_rect.intersects(close_button.get_global_rect()),
		"A long title's plate stays clear of the close button."
	)
	_check(
		outer_panel.get_global_rect().encloses(plate_rect),
		"A long title's plate stays within the panel width."
	)

	pause.queue_free()
	await process_frame


## Every gameplay-shell modal now gets the awning by default, with its title mirrored onto the plate.
func _test_shell_modals_use_awning() -> void:
	for scene_path in SHELL_SCENE_PATHS:
		var modal := (load(scene_path) as PackedScene).instantiate() as Control
		root.add_child(modal)
		await process_frame

		var outer_panel := modal.find_child("OuterPanel", true, false) as Control
		var title_label := modal.find_child("TitleLabel", true, false) as Label
		var awning := modal.find_child("AwningHeader", true, false) as Control
		var plate := awning.find_child("TitlePlate", true, false) as Control
		var plate_label := awning.find_child("PlateLabel", true, false) as Label
		var close_button := modal.find_child("CloseButton", true, false) as Button
		_check(
			awning.visible and not title_label.visible,
			"%s shows the awning instead of the plain title." % scene_path
		)
		_check(
			plate_label.text == title_label.text and not plate_label.text.is_empty(),
			"%s mirrors its title onto the plate ('%s')." % [scene_path, plate_label.text]
		)
		_check(
			is_equal_approx(close_button.offset_left, -28.0) and is_equal_approx(close_button.offset_top, -76.0),
			"%s puts its close button on the rail's right end." % scene_path
		)
		var panel_rect := outer_panel.get_global_rect()
		var plate_rect := plate.get_global_rect()
		_check(
			panel_rect.position.x <= plate_rect.position.x and plate_rect.end.x <= panel_rect.end.x,
			"%s keeps its plate within the panel width." % scene_path
		)

		modal.queue_free()
		await process_frame


## The main-menu popups instance the same header directly in their own panels.
func _test_menu_popups_use_awning() -> void:
	for scene_path in MENU_POPUP_TITLES:
		var popup := (load(scene_path) as PackedScene).instantiate() as Control
		root.add_child(popup)
		await process_frame

		var awning := popup.find_child("AwningHeader", true, false) as Control
		var close_button := popup.find_child("CloseButton", true, false) as Button
		_check(awning != null and awning.visible, "%s shows the awning header." % scene_path)
		if awning == null:
			popup.queue_free()
			continue
		var plate_label := awning.find_child("PlateLabel", true, false) as Label
		_check(
			plate_label.text == MENU_POPUP_TITLES[scene_path],
			"%s titles its plate '%s' (got '%s')." % [scene_path, MENU_POPUP_TITLES[scene_path], plate_label.text]
		)
		_check(popup.find_child("TitleLabel", true, false) == null, "%s drops its old title label." % scene_path)
		_check(
			close_button.get_parent() == awning.get_parent() and close_button.get_index() > awning.get_index(),
			"%s draws its close button above the awning." % scene_path
		)
		_check(
			is_equal_approx(close_button.offset_left, -28.0) and is_equal_approx(close_button.offset_top, -76.0),
			"%s puts its close button on the rail's right end." % scene_path
		)
		_check(
			popup.get_viewport_rect().grow(-8.0).encloses(close_button.get_global_rect()),
			"%s keeps its close button at least 8px inside the %s viewport (button %s)."
				% [scene_path, popup.get_viewport_rect().size, close_button.get_global_rect()]
		)

		popup.queue_free()
		await process_frame


## The burgundy notice dialogs carry the awning in a header slot; long product titles shrink to fit.
func _test_notice_dialogs_use_awning() -> void:
	var purchase := (load(PURCHASE_DIALOG_PATH) as PackedScene).instantiate() as Control
	root.add_child(purchase)
	purchase.call("show_result", "Purchase unavailable", "The purchase could not be completed.")
	for _frame in range(3):
		await process_frame
	var panel := purchase.find_child("Panel", true, false) as Control
	var awning := purchase.find_child("AwningHeader", true, false) as Control
	var plate := awning.find_child("TitlePlate", true, false) as Control
	var plate_label := awning.find_child("PlateLabel", true, false) as Label
	_check(plate_label.text == "PURCHASE UNAVAILABLE", "The purchase dialog titles its plate.")
	_check(
		panel.get_global_rect().encloses(plate.get_global_rect()),
		"A long purchase title shrinks until its plate fits the dialog (font %d)."
			% plate_label.get_theme_font_size("font_size")
	)
	_check(
		is_equal_approx(awning.get_global_rect().position.x, panel.get_global_rect().position.x - 16.0),
		"The dialog's awning overhangs the panel by the same 16px as every other modal."
	)
	purchase.queue_free()

	var reward := (load(REWARD_DIALOG_PATH) as PackedScene).instantiate() as Control
	root.add_child(reward)
	reward.call("show_reward", 2, 300)
	await process_frame
	var reward_label := reward.find_child("PlateLabel", true, false) as Label
	_check(reward_label.text == "WEEKLY REWARD!", "The weekly reward dialog titles its plate.")
	reward.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
