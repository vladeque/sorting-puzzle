extends SceneTree

const Codec := preload("res://scripts/save/local_save_codec.gd")
const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

var _failures := PackedStringArray()


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error(
			"PlayerProgress facade tests must run through scripts/tools/run_isolated_godot_test.ps1."
		)
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
	var player_id := Codec.create_uuid()
	_check(progress.switch_to_player(player_id), "isolated player namespace activates")
	progress.reset_progress()
	var migrated_v4 := progress.call("_sanitize_data", {
		"version": 4,
		"ability_uses": {"hammer": 7, "shuffle": 6, "highlight": 5},
	}) as Dictionary
	var migrated_uses := migrated_v4.get("ability_uses", {}) as Dictionary
	_check(int(migrated_v4.get("version", 0)) == 9, "schema-4 snapshots migrate to schema 9")
	_check(int(migrated_uses.get("freezer", 0)) == 3, "schema-4 migration grants exactly three freezers")
	var sanitized_v5 := progress.call("_sanitize_data", {
		"version": 5,
		"ability_uses": {"hammer": 3, "shuffle": 3, "highlight": 3, "freezer": 8},
	}) as Dictionary
	_check(
		int((sanitized_v5.get("ability_uses", {}) as Dictionary).get("freezer", 0)) == 8,
		"schema-5 to schema-6 migration never repeats the freezer grant"
	)
	_check(
		(sanitized_v5.get("purchased_shop_offer_ids", []) as Array).is_empty(),
		"schema-5 to schema-7 migration starts with no locally purchased offers"
	)
	var migrated_v7 := progress.call("_sanitize_data", {
		"version": 7,
		"avatar_id": "avatar_bear",
	}) as Dictionary
	_check(
		str(migrated_v7.get("avatar_frame_id", "")) == "frame_classic",
		"schema-7 profiles receive the classic avatar frame"
	)
	var schema_8_frame_migration := progress.call("_schema_migration_operations", {
		"version": 8,
		"avatar_frame_id": "frame_leaf",
	}) as Array
	_check(schema_8_frame_migration.size() == 1, "schema-8 non-default frames backfill exactly once")
	if schema_8_frame_migration.size() == 1:
		_check(
			str(((schema_8_frame_migration[0] as Dictionary).get("payload", {}) as Dictionary).get(
				"avatar_frame_id",
				""
			)) == "frame_leaf",
			"schema-8 frame migration journals the preserved selection"
		)
	_check(
		(progress.call("_schema_migration_operations", {
			"version": 8,
			"avatar_frame_id": "frame_classic",
		}) as Array).is_empty(),
		"schema-8 default frames do not overwrite a remote explicit selection"
	)
	var migrated_campaign := progress.call("_sanitize_data", {
		"version": 6,
		"current_level": 8,
		"highest_completed_level": 7,
	}) as Dictionary
	_check(
		(migrated_campaign.get("completion_stars_by_level", {}) as Dictionary).size() == 7,
		"schema-6 campaign cursor migrates to seven explicit completions"
	)
	_check(progress.get_coins() == 300, "fresh local snapshot has coins")
	_check(progress.spend_coins(25), "coin spending commits")
	_check(progress.get_coins() == 275, "coin spending is immediate")
	_check(progress.spend_ability(&"hammer"), "ability spending commits")
	_check(int(progress.get_ability_uses().get("hammer", 0)) == 2, "ability spend is immediate")
	_check(progress.spend_ability(&"freezer"), "offline freezer spending commits")
	_check(int(progress.get_ability_uses().get("freezer", 0)) == 2, "freezer spend is immediate")
	_check(not progress.spend_ability(&"unknown"), "unknown ability spending is rejected")
	_check(progress.spend_life(1, "left"), "life loss and attempt commit")
	_check(progress.get_lives() == 4, "life loss is immediate")
	_check(
		progress.set_profile_customization("avatar_bear", "frame_leaf", "Offline Player"),
		"profile customization commits"
	)
	_check(progress.get_avatar_frame_id() == "frame_leaf", "avatar frame selection is immediate")
	_check(
		not progress.set_profile_customization("avatar_bear", "frame_unknown", "Offline Player"),
		"unknown avatar frames are rejected"
	)
	var offer_claim := progress.apply_shop_purchase(
		"facade-new-player-bundle",
		{},
		"new_player_bundle"
	) as Dictionary
	_check(bool(offer_claim.get("applied", false)), "shop offer claim commits")
	_check(
		progress.has_purchased_shop_offer(&"new_player_bundle"),
		"purchased shop offer is available to catalog eligibility"
	)

	_check(progress.get_selected_chapter_id() == "chapter_01", "Chapter 1 is initially selected")
	_check(not progress.select_chapter("chapter_02"), "locked Chapter 2 cannot be selected")
	for level_number in range(1, 11):
		_check(progress.complete_level(level_number, 3), "offline completion %d commits" % level_number)
	_check(not progress.complete_level(1, 3), "completed levels cannot be replayed")
	_check(not progress.complete_level(11, 3), "unconfigured levels cannot be completed")
	_check(progress.get_current_level() == 11, "legacy campaign cursor follows contiguous completions")
	_check(progress.get_total_earned_stars() == 30, "lifetime stars update immediately")
	var chapter_one_progress := progress.get_chapter_progress("chapter_01") as Dictionary
	var chapter_two_progress := progress.get_chapter_progress("chapter_02") as Dictionary
	_check(bool(chapter_one_progress.get("complete", false)), "Chapter 1 is complete at current content end")
	_check(
		int(chapter_two_progress.get("previous_completed_levels", 0)) == 10
		and int(chapter_two_progress.get("required_completed_levels", 0)) == 25
		and not bool(chapter_two_progress.get("unlocked", true)),
		"Chapter 2 remains locked at 10 of 25 required completions"
	)
	_check(progress.get_coins() == 275, "chapter completion does not invent an early chest reward")
	_check(progress.spend_coins(100), "saved coins remain spendable after chapter completion")

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
	var profile_operations := []
	var campaign_operations := []
	for raw_operation in journal:
		var operation := raw_operation as Dictionary
		if str(operation.get("operation_type", "")) == "profile_edit":
			profile_operations.append(operation)
		if str(operation.get("operation_type", "")).begins_with("campaign_"):
			campaign_operations.append(operation)
	_check(profile_operations.size() == 1, "public name, avatar, and frame share one profile-edit operation")
	if not profile_operations.is_empty():
		var profile_payload := (profile_operations[0] as Dictionary).get("payload", {}) as Dictionary
		_check(
			str(profile_payload.get("avatar_frame_id", "")) == "frame_leaf",
			"combined profile edit synchronizes the selected avatar frame"
		)
	_check(
		progress.set_profile_customization("avatar_bear", "frame_ruby", "Offline Player"),
		"frame-only profile customization commits"
	)
	var updated_journal = progress.get("_local_store").get_journal()
	var frame_only_operation := updated_journal[updated_journal.size() - 1] as Dictionary
	_check(
		str(frame_only_operation.get("operation_type", "")) == "profile_edit"
		and (frame_only_operation.get("payload", {}) as Dictionary) == {
			"avatar_frame_id": "frame_ruby",
		},
		"frame-only customization produces a frame-only profile edit"
	)
	_check(campaign_operations.size() == 11, "all Chapter 1 campaign mutations are journaled")
	for raw_operation in campaign_operations:
		var payload := (raw_operation as Dictionary).get("payload", {}) as Dictionary
		var campaign_level := int(payload.get("campaign_level", 0))
		_check(campaign_level >= 1 and campaign_level <= 10, "campaign operation is integration-ready")
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
		(diagnostics.get("content_diagnostic", {}) as Dictionary).is_empty(),
		"all configured Chapter 1 levels have publishable provenance"
	)

	progress.load_progress()
	_check(progress.get_current_level() == 11, "facade snapshot survives restart load")
	_check(progress.get_completed_level_stars().size() == 10, "completion history survives restart")
	_check(progress.get_player_name() == "Offline Player", "profile remains account-scoped")
	_check(progress.get_avatar_frame_id() == "frame_ruby", "avatar frame survives restart load")
	_check(
		progress.has_purchased_shop_offer(&"new_player_bundle"),
		"purchased shop offer survives restart load"
	)
	_check(
		int(progress.get_ability_uses().get("freezer", 0)) == 2,
		"freezer spend survives restart without refund or duplication"
	)

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
