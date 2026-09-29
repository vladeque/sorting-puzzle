extends SceneTree

## Verifies the opt-in shop-awning modal header: Pause selects it, other shell modals keep the plain
## title, the canopy covers the plate by node order, the plate follows configure(), and long titles
## stay clear of the close button.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const PAUSE_SCENE_PATH := "res://scenes/pause_menu.tscn"
const LEAVE_SCENE_PATH := "res://scenes/leave_confirmation_menu.tscn"
const LONG_TITLE := "LEAVING THE LEVEL"

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
	await _test_leave_keeps_plain_title()

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


func _test_leave_keeps_plain_title() -> void:
	var leave := (load(LEAVE_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(leave)
	await process_frame

	var title_label := leave.find_child("TitleLabel", true, false) as Label
	var awning := leave.find_child("AwningHeader", true, false) as Control
	var close_button := leave.find_child("CloseButton", true, false) as Button
	_check(title_label.visible and not awning.visible, "Leave Confirmation keeps the plain title.")
	_check(title_label.text == LONG_TITLE, "Leave Confirmation still titles its plain label.")
	_check(
		is_equal_approx(close_button.offset_left, -54.0) and is_equal_approx(close_button.offset_top, -18.0),
		"Plain-title modals keep the corner close-button placement."
	)

	leave.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
