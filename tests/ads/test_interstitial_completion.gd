extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const GATE_SCRIPT_PATH := "res://scripts/ads/interstitial_completion_gate.gd"

var _failures: Array[String] = []


class FakeAdService extends Node:
	var activation_baselines: Array[int] = []
	var completion_count := 0
	var preload_count := 0
	var request_count := 0
	var request_context := {}
	var activation_allowed := true

	func activate_interstitial_pacing(baseline: int) -> bool:
		activation_baselines.append(baseline)
		return activation_allowed

	func record_campaign_completion() -> bool:
		completion_count += 1
		return true

	func preload_interstitial() -> Dictionary:
		preload_count += 1
		return {"status": &"ready"}

	func request_interstitial(context: Dictionary) -> Dictionary:
		request_count += 1
		request_context = context.duplicate(true)
		await get_tree().process_frame
		return {"status": &"failed", "reason": "simulated_show_failure", "impression": false}


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Interstitial completion verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var service := FakeAdService.new()
	root.add_child(service)
	var gate_script := load(GATE_SCRIPT_PATH) as GDScript
	_check(gate_script != null, "The interstitial completion gate script loads.")
	if gate_script == null:
		_finish()
		return
	var gate: Node = gate_script.new()
	root.add_child(gate)
	gate.configure(service)

	var recorded: Dictionary = await gate.record_committed_completion(12)
	_check(bool(recorded.get("ok", false)), "A committed completion is accepted for pacing.")
	_check(
		service.activation_baselines == [11] and service.completion_count == 1,
		"First activation baselines historical progress and counts only the new completion."
	)
	_check(service.preload_count == 1, "A committed completion preloads at most one interstitial.")
	var duplicate: Dictionary = await gate.record_committed_completion(12)
	_check(
		not bool(duplicate.get("ok", false)) and service.completion_count == 1,
		"Duplicate completion callbacks cannot increment pacing twice."
	)

	var presentation: Dictionary = await gate.present_before_navigation()
	_check(
		presentation.get("status") == &"failed"
			and service.request_count == 1
			and bool(service.request_context.get("safe_transition", false)),
		"The completion-to-menu break makes one safe-transition request and returns failures."
	)
	await gate.present_before_navigation()
	_check(service.request_count == 1, "Repeated Continue input cannot present twice.")

	gate.queue_free()
	service.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("ADS-007 interstitial completion verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
