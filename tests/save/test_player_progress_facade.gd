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
	_check(
		bool(diagnostics.get("content_manifest_valid", false)),
		"generated content provenance enables the synchronization gate"
	)
	_check(
		str(diagnostics.get("content_manifest_digest", "")).length() == 64,
		"content provenance exposes a non-secret diagnostic digest"
	)
	var journal = progress.get("_local_store").get_journal()
	var campaign_operations := []
	for raw_operation in journal:
		var operation := raw_operation as Dictionary
		if str(operation.get("operation_type", "")).begins_with("campaign_"):
			campaign_operations.append(operation)
	_check(campaign_operations.size() == 9, "only published levels produce campaign journal entries")
	for raw_operation in campaign_operations:
		var payload := (raw_operation as Dictionary).get("payload", {}) as Dictionary
		var campaign_level := int(payload.get("campaign_level", 0))
		_check(campaign_level >= 1 and campaign_level <= 8, "campaign operation is integration-ready")
		_check(
			str(payload.get("configuration_version", "")).begins_with("config_"),
			"campaign operation uses canonical configuration provenance"
		)
		_check(
			not str(payload.get("level_version", "")).contains("-client-"),
			"campaign operation does not invent a synthetic level version"
		)
	_check(
		int(diagnostics.get("journal_head_sequence", 0)) == int(diagnostics.get("journal_entries", 0)),
		"facade journal remains contiguous"
	)
	_check(
		str((diagnostics.get("content_diagnostic", {}) as Dictionary).get("code", ""))
		== "content_manifest.level_unsupported",
		"unsupported campaign levels remain local with a stable diagnostic"
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
