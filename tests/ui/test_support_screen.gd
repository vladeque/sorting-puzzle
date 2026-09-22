extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const SUPPORT_SCENE_PATH := "res://scenes/ui/support_screen.tscn"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Support-screen verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var support_scene := load(SUPPORT_SCENE_PATH) as PackedScene
	_check(support_scene != null, "The support scene loads.")
	if support_scene == null:
		quit(1)
		return
	var screen := support_scene.instantiate() as Control
	root.add_child(screen)
	await process_frame

	var faq_list := screen.get_node("%FaqList") as VBoxContainer
	var faq_items: Array[Control] = []
	for child in faq_list.get_children():
		if child is Control and child.has_method("set_expanded"):
			faq_items.append(child as Control)
	_check(faq_items.size() == 5, "Support authors five focused FAQ entries.")

	var contact_item := screen.get_node("%ContactSupportItem") as Control
	var report_item := screen.get_node("%ReportAdItem") as Control
	contact_item.call("set_expanded", true)
	_check(bool(contact_item.call("is_expanded")), "Contact Support expands on request.")
	report_item.call("set_expanded", true)
	_check(
		bool(report_item.call("is_expanded")) and not bool(contact_item.call("is_expanded")),
		"Expanding one FAQ collapses the previously open entry."
	)
	var report_text := str(report_item.get_node("%AnswerLabel").text)
	_check(
		report_text.contains("screenshot")
		and report_text.contains("approximate time")
		and report_text.contains("support@sortingpuzzle.example"),
		"The ad-report article explains what evidence to collect and where to send it."
	)
	var mailto := str(screen.call(
		"build_mailto_url",
		"support@sortingpuzzle.example",
		"Sorting Puzzle ad report",
		"Approximate time:"
	))
	_check(
		mailto.begins_with("mailto:support@sortingpuzzle.example?")
		and mailto.contains("Sorting%20Puzzle%20ad%20report"),
		"Contact actions build a safe prefilled mailto route."
	)
	_check(
		str(screen.call("build_mailto_url", "bad address", "x", "y")).is_empty(),
		"Invalid support-email settings fail closed."
	)

	screen.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Support-screen verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
