extends SceneTree

## Runs the standalone reward-chest preview through one complete fill. The check observes the real
## production flyer/chest components and SfxManager event requests rather than duplicating timing.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const PREVIEW_SCENE := preload("res://scenes/testing/reward_chest_fill_preview.tscn")
const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")

var _failures: Array[String] = []
var _arrival_sound_count := 0


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Reward chest preview verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress := root.get_node_or_null(^"PlayerProgress")
	var sfx_manager := root.get_node_or_null(^"SfxManager")
	_check(progress != null, "PlayerProgress is available for the no-save assertion.")
	_check(sfx_manager != null, "SfxManager is available to observe arrival events.")
	if progress == null or sfx_manager == null:
		_finish()
		return

	var saved_progress_before: Dictionary = progress.call("get_reward_chest_progress")
	sfx_manager.call("set_muted", false)
	sfx_manager.connect("event_played", Callable(self, "_on_event_played"))

	var preview := PREVIEW_SCENE.instantiate() as Control
	preview.set("autoplay", false)
	root.add_child(preview)
	await process_frame
	await process_frame

	var flyer := preview.get_node("%StarFlyer") as Control
	preview.call("_play_fill")
	await flyer.animation_finished

	var chest_progress := preview.get_node("%RewardChest/Visual/ProgressTrack/ProgressBar") as ProgressBar
	_check(int(preview.get("_current_stars")) == 12, "One preview run receives all twelve stars.")
	_check(
		int(chest_progress.value) == 12 and int(chest_progress.max_value) == 12,
		"The production chest widget displays the completed local preview goal."
	)
	_check(
		_arrival_sound_count == 12,
		"Every accepted preview impact requests reward_chest_star_arrival once."
	)
	_check(
		progress.call("get_reward_chest_progress") == saved_progress_before,
		"Running the preview does not change saved reward-chest progress."
	)

	preview.queue_free()
	await process_frame
	_finish()


func _on_event_played(event_id: StringName, _context: Dictionary) -> void:
	if event_id == SfxCatalogScript.EVENT_REWARD_CHEST_STAR_ARRIVAL:
		_arrival_sound_count += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Reward chest fill preview verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
