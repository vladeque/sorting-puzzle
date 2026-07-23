extends SceneTree

const Codec := preload("res://scripts/save/local_save_codec.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress = get_root().get_node_or_null("PlayerProgress")
	_check(progress != null, "PlayerProgress autoload is available")
	if progress == null:
		quit(1)
		return
	var player_id := Codec.create_uuid()
	_check(progress.switch_to_player(player_id), "isolated player namespace activates")
	progress.reset_progress()
	_check(progress.get_coins() == 300, "fresh local snapshot has coins")
	_check(progress.spend_coins(25), "coin spending commits")
	_check(progress.get_coins() == 275, "coin spending is immediate")
	_check(progress.spend_ability(&"hammer"), "ability spending commits")
	_check(int(progress.get_ability_uses().get("hammer", 0)) == 2, "ability spend is immediate")
	_check(progress.spend_life(1, "left"), "life loss and attempt commit")
	_check(progress.get_lives() == 4, "life loss is immediate")
	_check(progress.set_profile("avatar_bear", "Offline Player"), "profile edit commits")

	for level_number in range(1, 171):
		_check(progress.complete_level(level_number, 3), "offline completion %d commits" % level_number)
	_check(progress.get_current_level() == 171, "more than 100 consecutive completions are unrestricted")
	_check(progress.get_total_earned_stars() == 510, "lifetime stars update immediately")
	_check(progress.get_coins() >= 375, "reward chest coin grant is immediate")
	_check(progress.spend_coins(100), "offline-earned reward can be spent immediately")

	var diagnostics: Dictionary = progress.get_local_save_diagnostics()
	_check(int(diagnostics.get("journal_entries", 0)) >= 175, "facade mutations share the journal path")
	_check(
		int(diagnostics.get("journal_head_sequence", 0)) == int(diagnostics.get("journal_entries", 0)),
		"facade journal remains contiguous"
	)

	progress.load_progress()
	_check(progress.get_current_level() == 171, "facade snapshot survives restart load")
	_check(progress.get_player_name() == "Offline Player", "profile remains account-scoped")

	if _failures.is_empty():
		print("PlayerProgress GAME-001 facade tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
