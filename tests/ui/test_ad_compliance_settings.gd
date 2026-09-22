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
	var support_button := menu.find_child("SupportButton", true, false) as Button
	var language_button := menu.find_child("LanguageButton", true, false) as Button
	var privacy_button := menu.find_child("AdPrivacyButton", true, false) as Button
	var diagnostics_label := menu.find_child("DiagnosticsLabel", true, false) as Label
	_check(
		support_button != null and language_button != null and privacy_button != null,
		"Settings retains Support and Language alongside the policy-driven privacy action."
	)
	if support_button != null and language_button != null and privacy_button != null:
		menu.call("set_ad_compliance_actions", "Privacy Choices", true)
		_check(
			privacy_button.visible and privacy_button.text == "Privacy Choices",
			"The owner can expose consent choices without rebuilding the scene."
		)
		var emitted := {"privacy": false, "support": false}
		menu.connect("support_requested", func() -> void: emitted["support"] = true)
		menu.connect("ad_privacy_requested", func() -> void: emitted["privacy"] = true)
		support_button.pressed.emit()
		privacy_button.pressed.emit()
		_check(
			bool(emitted.get("privacy", false)) and bool(emitted.get("support", false)),
			"Settings emits focused support and privacy requests."
		)
	_check(diagnostics_label != null, "Settings owns a diagnostics footer.")
	if diagnostics_label != null:
		var expected_version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
		var expected_build := maxi(int(ProjectSettings.get_setting("application/config/build_number", 1)), 1)
		_check(
			diagnostics_label.text.contains("Version %s • Build %d" % [expected_version, expected_build]),
			"The diagnostics footer reports the configured version and build."
		)
		_check(
			diagnostics_label.text.contains("Platform: %s" % OS.get_name())
				and diagnostics_label.text.contains("User: "),
			"The diagnostics footer reports the platform and a user identifier."
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
