extends SceneTree

## The Main Menu and the Shop call PlayerProgress.ensure_progress_loaded() every time they open. It
## must keep the save that is already open, so the save and registration services never get a new
## store mid-request, while load_progress() keeps its full reload for restart-style callers.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

var _failures := PackedStringArray()


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Progress screen-open tests must run through scripts/tools/run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress = get_root().get_node_or_null("PlayerProgress")
	_check(progress != null, "PlayerProgress autoload is available")
	if progress == null:
		quit(1)
		return

	var opened = progress.get("_local_store")
	_check(opened != null, "the save is open after startup")
	var registration = progress.get("_guest_bootstrap_service")
	var sync = progress.get("_sync_service")

	progress.ensure_progress_loaded()
	progress.ensure_progress_loaded()
	_check(is_same(progress.get("_local_store"), opened), "screen opens keep the save that is already open")
	_check(
		is_same(registration.get("_store"), opened) and is_same(sync.get("_store"), opened),
		"screen opens never hand the registration and sync services a new store"
	)

	progress.load_progress()
	var reloaded = progress.get("_local_store")
	_check(
		reloaded != null and not is_same(reloaded, opened),
		"load_progress() still reopens the save for restart-style callers"
	)

	progress.set("_local_store", null)
	progress.ensure_progress_loaded()
	_check(progress.get("_local_store") != null, "a screen open opens the save when none is open")

	if _failures.is_empty():
		print("Progress screen-open tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
