extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const SETTINGS_SCENE_PATH := "res://scenes/ui/settings_menu.tscn"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Ad compliance settings verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var settings_scene := load(SETTINGS_SCENE_PATH) as PackedScene
	_check(settings_scene != null, "The settings scene loads.")
	if settings_scene == null:
		quit(1)
		return
	var menu := settings_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	var privacy_button := menu.find_child("AdPrivacyButton", true, false) as Button
	var report_button := menu.find_child("ReportAdButton", true, false) as Button
	_check(privacy_button != null and report_button != null, "Settings owns both ad compliance actions.")
	if privacy_button != null and report_button != null:
		menu.call("set_ad_compliance_actions", "Privacy Choices", true, true)
		_check(
			privacy_button.visible and privacy_button.text == "Privacy Choices" and report_button.visible,
			"The owner can expose consent choices and ad reporting without rebuilding the scene."
		)
		var emitted := {"privacy": false, "report": false}
		menu.connect("ad_privacy_requested", func() -> void: emitted["privacy"] = true)
		menu.connect("ad_report_requested", func() -> void: emitted["report"] = true)
		privacy_button.pressed.emit()
		report_button.pressed.emit()
		_check(
			bool(emitted.get("privacy", false)) and bool(emitted.get("report", false)),
			"Compliance buttons emit focused owner-level requests."
		)

	menu.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ADS-008 ad compliance settings verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
