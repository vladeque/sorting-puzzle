extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress := get_root().get_node("PlayerProgress")
	progress.reset_progress()
	var before := progress.get_ability_uses() as Dictionary
	progress.add_reward_chest_stars(1500)
	var after := progress.get_ability_uses() as Dictionary
	for ability in ["hammer", "shuffle", "highlight", "freezer"]:
		_check(int(after.get(ability, 0)) == int(before.get(ability, 0)) + 2,
			"Crossing two goals grants two %s uses" % ability)
	_check(progress.get_coins() == 625, "Crossing two goals grants both coin rewards")
	_check(int(progress.get_reward_chest_progress().get("goal_index", -1)) == 2,
		"Crossing two goals advances to the third goal")
	var repeated := progress.call("_normalize_reward_chest_progress", 6000, 4) as Dictionary
	_check(int(repeated.get("completed_cycles", 0)) == 2,
		"The final goal repeats twice")
	for ability in ["hammer", "shuffle", "highlight", "freezer"]:
		_check(int((repeated.get("ability_rewards", {}) as Dictionary).get(ability, 0)) == 2,
			"Repeated final goals grant two %s uses" % ability)
	var base := progress.call("_default_data") as Dictionary
	var current_version := str((progress.call("_campaign_provenance", 1) as Dictionary).get(
		"configuration_version", ""
	))
	var completion := {
		"operation_type": "campaign_completion",
		"payload": {
			"campaign_level": 1,
			"stars": 500,
			"configuration_version": current_version,
		},
	}
	var reconciled := progress.call("_apply_unacknowledged_operation", base, completion) as Dictionary
	var replayed := progress.call("_apply_unacknowledged_operation", reconciled, completion) as Dictionary
	for ability in ["hammer", "shuffle", "highlight", "freezer"]:
		_check(
			int((reconciled.get("ability_uses", {}) as Dictionary).get(ability, 0)) == 4,
			"Pending completion grants one %s use" % ability
		)
	_check(replayed.get("ability_uses", {}) == reconciled.get("ability_uses", {}),
		"Replaying the same completion does not duplicate ability rewards")
	var old_completion := completion.duplicate(true)
	(old_completion["payload"] as Dictionary)["configuration_version"] = "old_chest_policy"
	var old_reconciled := progress.call(
		"_apply_unacknowledged_operation", base, old_completion
	) as Dictionary
	_check(old_reconciled.get("ability_uses", {}) == base.get("ability_uses", {}),
		"Pending completions from an older configuration do not gain ability rewards")
	if _failures.is_empty():
		print("Reward chest ability grant tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
