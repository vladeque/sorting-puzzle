extends SceneTree

const Codec := preload("res://scripts/save/local_save_codec.gd")
const SaveStore := preload("res://scripts/save/local_save_store.gd")
const SyncService := preload("res://scripts/save/save_sync_service.gd")

const ABILITY_HIGHLIGHT := &"highlight"
const ABILITY_FREEZER := &"freezer"

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_freezer_runtime_semantics()
	_test_freezer_crash_recovery()
	await _test_paid_use_and_persistence()
	await _test_responsive_ability_bar()
	if _failures.is_empty():
		print("GAME-011 Freezer tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_freezer_runtime_semantics() -> void:
	var level = await _make_level(true, 8)
	var ability_bar := level.get("_ability_bar") as AbilityBar
	var freezer_button := ability_bar.get_ability_button(ABILITY_FREEZER)
	level.set("_time_remaining", 120.0)
	level.set("_has_player_started_timer", false)
	level.set("_combo_count", 2)
	level.set("_combo_time_remaining", 8.0)
	level.set("_highlight_timer", 15.0)

	var starting_uses := int((level.get("_ability_uses") as Dictionary).get(ABILITY_FREEZER, 0))
	_check(
		bool(level.call("_apply_ability_from_button", ABILITY_FREEZER)),
		"Freezer activates before the first move"
	)
	_check(bool(level.get("_has_player_started_timer")), "Freezer is the first meaningful action")
	_check(
		int((level.get("_ability_uses") as Dictionary).get(ABILITY_FREEZER, 0)) == starting_uses - 1,
		"successful activation spends exactly one use after preflight"
	)
	_check(
		not bool(level.call("_apply_ability_from_button", ABILITY_FREEZER)),
		"Freezer cannot stack or refresh while active"
	)
	_check(
		int((level.get("_ability_uses") as Dictionary).get(ABILITY_FREEZER, 0)) == starting_uses - 1,
		"repeated activation spends nothing"
	)
	_check(
		bool(level.call("_apply_ability_from_button", ABILITY_HIGHLIGHT)),
		"non-blocking Freezer does not prevent another ability"
	)

	level.call("_process", 5.0)
	_check(is_equal_approx(float(level.get("_time_remaining")), 120.0), "countdown is fully suppressed")
	_check(is_equal_approx(float(level.get("_freezer_time_remaining")), 25.0), "Freezer uses active gameplay delta")
	_check(is_equal_approx(float(level.get("_combo_time_remaining")), 3.0), "combo timer continues during Freezer")
	_check(is_equal_approx(float(level.get("_highlight_timer")), 10.0), "Lantern timer continues during Freezer")

	var moving_rows := level.call("_get_all_moving_shelf_rows") as Array
	_check(not moving_rows.is_empty(), "moving-row fixture is available")
	if not moving_rows.is_empty():
		var moving_row := moving_rows[0] as MovingShelfRow
		var movement_before := float(moving_row.get("_motion_offset"))
		moving_row.call("_process", 2.0)
		_check(
			not is_equal_approx(float(moving_row.get("_motion_offset")), movement_before),
			"moving shelves continue during Freezer"
		)

	level.set("_freezer_time_remaining", 2.0)
	level.set("_time_remaining", 100.0)
	level.call("_process", 5.0)
	_check(is_equal_approx(float(level.get("_time_remaining")), 97.0), "only the exact frozen portion of a delta is suppressed")
	_check(not bool(level.call("_is_freezer_active")), "Freezer expires without an extra frame")
	_check(not freezer_button.disabled, "Freezer button is enabled again after expiry")

	_check(
		bool(level.call("_apply_ability_from_button", ABILITY_FREEZER)),
		"Freezer can be activated again after expiry"
	)
	_check(
		int((level.get("_ability_uses") as Dictionary).get(ABILITY_FREEZER, 0)) == starting_uses - 2,
		"reactivation spends exactly one additional use"
	)
	level.set("_level_paused", true)
	var paused_remaining := float(level.get("_freezer_time_remaining"))
	level.call("_process", 6.0)
	_check(
		is_equal_approx(float(level.get("_freezer_time_remaining")), paused_remaining),
		"pause suspends the Freezer window"
	)
	level.set("_level_paused", false)
	level.call("_notification", Node.NOTIFICATION_APPLICATION_PAUSED)
	level.call("_process", 6.0)
	_check(
		is_equal_approx(float(level.get("_freezer_time_remaining")), paused_remaining),
		"app interruption suspends the Freezer window"
	)
	level.call("_notification", Node.NOTIFICATION_APPLICATION_RESUMED)
	level.call("_process", 1.5)
	_check(
		is_equal_approx(float(level.get("_freezer_time_remaining")), paused_remaining - 1.5),
		"Freezer resumes from its exact remaining duration"
	)

	level.call("_open_ability_purchase_menu", &"hammer")
	var purchase_paused_remaining := float(level.get("_freezer_time_remaining"))
	level.call("_process", 4.0)
	_check(
		is_equal_approx(float(level.get("_freezer_time_remaining")), purchase_paused_remaining),
		"ability purchase UI suspends the Freezer window"
	)
	level.call("_close_ability_purchase_menu")

	level.call("_fail_level")
	_check(not bool(level.call("_is_freezer_active")), "failure clears Freezer state")
	level.queue_free()
	await process_frame

	var completed_level = await _make_level(true, 1)
	completed_level.call("_use_freezer")
	completed_level.call("_complete_level")
	_check(not bool(completed_level.call("_is_freezer_active")), "completion clears Freezer state")
	completed_level.queue_free()
	await process_frame


func _test_paid_use_and_persistence() -> void:
	var progress = get_root().get_node_or_null("PlayerProgress")
	_check(progress != null, "PlayerProgress autoload is available")
	if progress == null:
		return
	var player_id := Codec.create_uuid()
	_check(progress.switch_to_player(player_id), "isolated Freezer player namespace activates")
	progress.reset_progress()
	for _index in range(3):
		_check(progress.spend_ability(ABILITY_FREEZER), "saved Freezer use can be spent offline")
	_check(
		int(progress.get_ability_uses().get("freezer", -1)) == 0,
		"fixture reaches zero Freezer inventory"
	)

	var level = await _make_level(false, 1)
	# This test normally disables Level processing for deterministic ability assertions. Re-enable it
	# while exercising the real modal fade so the production input gate can reach its stable state.
	level.process_mode = Node.PROCESS_MODE_INHERIT
	level.call("_open_ability_purchase_menu", ABILITY_FREEZER)
	await create_timer(0.35).timeout
	level.call("_on_ability_purchase_buy_pressed")
	await create_timer(0.35).timeout
	_check(bool(level.call("_is_freezer_active")), "zero-use coin purchase activates Freezer")
	_check(progress.get_coins() == 200, "zero-use Freezer costs exactly 100 coins")
	_check(
		int(progress.get_ability_uses().get("freezer", -1)) == 0,
		"paid immediate use does not add saved inventory"
	)

	level.call("_open_ability_purchase_menu", ABILITY_FREEZER)
	await create_timer(0.35).timeout
	level.call("_on_ability_purchase_buy_pressed")
	_check(progress.get_coins() == 200, "active Freezer rejects a paid refresh without spending")

	level.call("_clear_freezer")
	_check(progress.spend_coins(150), "fixture reduces balance below the Freezer price")
	level.call("_open_ability_purchase_menu", ABILITY_FREEZER)
	await create_timer(0.35).timeout
	var buy_button := level.get("_ability_purchase_overlay").find_child("BuyButton", true, false) as Button
	_check(not buy_button.disabled, "unaffordable ability price remains actionable")
	level.call("_on_ability_purchase_buy_pressed")
	await create_timer(0.35).timeout
	_check(progress.get_coins() == 50, "insufficient-coins attempt spends nothing")
	_check(not bool(level.call("_is_freezer_active")), "insufficient coins do not activate Freezer")
	var in_level_shop = level.get("_in_level_shop_overlay")
	_check(bool(in_level_shop.visible), "insufficient coins open the in-level Shop")
	var hammer_uses_label := level.get_node("UI/AbilityBar/ButtonRow/HammerButton/UsesLabel") as Label
	_check(
		in_level_shop.z_index > hammer_uses_label.z_index,
		"in-level Shop renders above gameplay ability counters"
	)
	_check(
		not bool((in_level_shop.get_node("%BottomNavigation") as Control).visible),
		"in-level Shop hides BottomNavigation"
	)
	_check(
		bool((in_level_shop.get_node("%OverlayCloseButton") as Control).visible),
		"in-level Shop shows its X close button"
	)
	_check(
		bool(level.get("_ability_purchase_overlay").visible),
		"Ability Purchase remains beneath the in-level Shop"
	)
	in_level_shop.call("_purchase_offer", &"coins_100")
	await create_timer(0.35).timeout
	_check(progress.get_coins() == 150, "in-level Shop coin purchase updates the saved balance")
	var purchase_dialog := in_level_shop.get_node("%PurchaseDialog") as Control
	_check(purchase_dialog.visible, "in-level Shop shows the shared purchase result dialog")
	purchase_dialog.call("close")
	await create_timer(0.25).timeout
	level.call("_on_in_level_shop_close_requested")
	await create_timer(0.35).timeout
	_check(not bool(in_level_shop.visible), "closing the in-level Shop hides it")
	_check(
		bool(level.get("_ability_purchase_overlay").visible),
		"closing the in-level Shop returns to Ability Purchase"
	)
	level.call("_on_ability_purchase_buy_pressed")
	await create_timer(0.35).timeout
	_check(bool(level.call("_is_freezer_active")), "refilled coins allow the pending paid ability")
	_check(progress.get_coins() == 50, "refilled paid ability spends its configured price exactly once")

	progress.load_progress()
	_check(progress.get_coins() == 50, "paid-use coin spend survives restart")
	_check(
		int(progress.get_ability_uses().get("freezer", -1)) == 0,
		"restart neither refunds nor duplicates Freezer inventory"
	)
	var journal := progress.get("_local_store").get_journal() as Array
	var freezer_spends := 0
	for raw_operation in journal:
		var operation := raw_operation as Dictionary
		var payload := operation.get("payload", {}) as Dictionary
		if (
			str(operation.get("operation_type", "")) == "resource_spend"
			and str(payload.get("asset", "")) == "freezer"
		):
			freezer_spends += 1
	_check(freezer_spends == 3, "offline Freezer uses are journaled exactly once each")

	var sync := SyncService.new()
	get_root().add_child(sync)
	sync.configure(
		progress.get("_local_store"),
		progress.get("_session_store"),
		func(_checkpoint, current, _remaining): return current
	)
	var request_result := sync.call("_build_request", {
		"session_id": Codec.create_uuid(),
		"access_token": "test-token",
	}) as Dictionary
	_check(bool(request_result.get("ok", false)), "v2.1 request builds with Freezer spends")
	var pending := request_result.get("pending_request", {}) as Dictionary
	var envelope = JSON.parse_string(str(pending.get("payload", "")))
	_check(
		envelope is Dictionary
		and str((envelope as Dictionary).get("meta", {}).get("protocol_version", "")) == "2.1",
		"Freezer journal uses protocol v2.1"
	)
	sync.queue_free()

	var current_snapshot := progress.get("_data").duplicate(true) as Dictionary
	current_snapshot["ability_uses"]["freezer"] = 2
	var v21_checkpoint := _checkpoint_with_abilities({
		"hammer": 3,
		"shuffle": 3,
		"highlight": 3,
		"freezer": 5,
	})
	var remaining_freezer_spend := [{
		"operation_type": "resource_spend",
		"payload": {"asset": "freezer", "amount": 1, "reason": "ability_use"},
	}]
	var mapped_v21 := progress.call(
		"_map_checkpoint_to_snapshot",
		v21_checkpoint,
		current_snapshot,
		remaining_freezer_spend
	) as Dictionary
	_check(
		int((mapped_v21.get("ability_uses", {}) as Dictionary).get("freezer", -1)) == 4,
		"v2.1 checkpoint reconciliation replays an unacknowledged Freezer spend"
	)
	var v20_checkpoint := _checkpoint_with_abilities({
		"hammer": 3,
		"shuffle": 3,
		"highlight": 3,
	})
	var mapped_v20 := progress.call(
		"_map_checkpoint_to_snapshot",
		v20_checkpoint,
		current_snapshot,
		remaining_freezer_spend
	) as Dictionary
	_check(
		int((mapped_v20.get("ability_uses", {}) as Dictionary).get("freezer", -1)) == 1,
		"supported v2.0 checkpoint preserves local Freezer state before replay"
	)

	var grant_result := progress.apply_shop_purchase("game-011-starter", {
		"coins": 1000,
		"abilities": {"hammer": 3, "shuffle": 3, "highlight": 3, "freezer": 3},
	}) as Dictionary
	_check(bool(grant_result.get("applied", false)), "new starter bundle grant applies")
	_check(
		int(progress.get_ability_uses().get("freezer", -1)) == 3,
		"new starter bundle grants three Freezers"
	)
	var replay_grant := progress.apply_shop_purchase("game-011-starter", {
		"coins": 1000,
		"abilities": {"hammer": 3, "shuffle": 3, "highlight": 3, "freezer": 3},
	}) as Dictionary
	_check(not bool(replay_grant.get("applied", true)), "starter transaction replay is idempotent")

	level.queue_free()
	await process_frame


func _test_freezer_crash_recovery() -> void:
	var progress = get_root().get_node_or_null("PlayerProgress")
	if progress == null:
		_check(false, "PlayerProgress is available for crash recovery")
		return
	var session_store = progress.get("_session_store")
	var save_namespace := {"kind": "player", "player_id": Codec.create_uuid()}
	var snapshot := {
		"version": 5,
		"ability_uses": {"hammer": 3, "shuffle": 3, "highlight": 3, "freezer": 3},
	}
	var preferences := {"settings_disabled": {}}
	var store = SaveStore.new(session_store)
	_check(
		bool(store.open_namespace(save_namespace, snapshot, preferences).get("ok", false)),
		"Freezer crash fixture opens"
	)
	var spent_snapshot := snapshot.duplicate(true)
	spent_snapshot["ability_uses"]["freezer"] = 2
	store.set("_test_interrupt_stage", "after_current_promotion")
	var interrupted := store.commit_snapshot(spent_snapshot, preferences, [{
		"operation_type": "resource_spend",
		"payload": {"asset": "freezer", "amount": 1, "reason": "ability_use"},
	}]) as Dictionary
	_check(not bool(interrupted.get("ok", true)), "simulated crash interrupts commit acknowledgement")

	var recovered = SaveStore.new(session_store)
	var recovery_result := recovered.open_namespace(save_namespace, snapshot, preferences) as Dictionary
	_check(bool(recovery_result.get("ok", false)), "promoted Freezer generation recovers after crash")
	_check(
		int(
			((recovery_result.get("snapshot", {}) as Dictionary).get(
				"ability_uses",
				{}
			) as Dictionary).get("freezer", -1)
		) == 2,
		"crash recovery keeps the successful Freezer spend"
	)
	_check(recovered.get_journal().size() == 1, "crash recovery keeps one Freezer operation")

	var restarted = SaveStore.new(session_store)
	var restart_result := restarted.open_namespace(save_namespace, snapshot, preferences) as Dictionary
	_check(bool(restart_result.get("ok", false)), "recovered Freezer namespace restarts")
	_check(
		int(
			((restart_result.get("snapshot", {}) as Dictionary).get(
				"ability_uses",
				{}
			) as Dictionary).get("freezer", -1)
		) == 2,
		"second restart neither refunds nor duplicates the recovered spend"
	)
	_check(restarted.get_journal().size() == 1, "second restart still has one Freezer operation")


func _test_responsive_ability_bar() -> void:
	var level = await _make_level(true, 1)
	var viewport_sizes := [
		Vector2i(540, 960),
		Vector2i(720, 1280),
		Vector2i(1080, 1920),
		Vector2i(1080, 2400),
		Vector2i(900, 1200),
	]
	for viewport_size in viewport_sizes:
		get_root().content_scale_size = viewport_size
		get_root().size = viewport_size
		level.call("_apply_responsive_layout")
		await process_frame
		var bar := level.get_node("UI/AbilityBar") as AbilityBar
		var previous_right := -INF
		for ability_id in [&"hammer", &"shuffle", &"highlight", &"freezer"]:
			var button := bar.get_ability_button(ability_id)
			var button_rect := button.get_global_rect()
			_check(
				button_rect.size.x >= 82.0 and button_rect.size.y >= 82.0,
				"%s keeps large touch targets at %s" % [ability_id, viewport_size]
			)
			_check(
				button_rect.position.x >= 0.0
				and button_rect.end.x <= float(viewport_size.x),
				"%s stays inside the %s viewport (%s)" % [ability_id, viewport_size, button_rect]
			)
			_check(
				button_rect.position.x >= previous_right,
				"%s does not overlap the previous ability at %s" % [ability_id, viewport_size]
			)
			previous_right = button_rect.end.x
	level.queue_free()
	await process_frame


func _make_level(dev_mode: bool, level_number: int):
	var level_scene := load("res://level.tscn") as PackedScene
	var level = level_scene.instantiate()
	level.set("launched_from_dev_mode", dev_mode)
	level.set("selected_level", level_number)
	get_root().add_child(level)
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func _checkpoint_with_abilities(abilities: Dictionary) -> Dictionary:
	return {
		"campaign": {"current_level": 1, "highest_completed_level": 0},
		"balances": {"coins": 50},
		"abilities": abilities,
		"lives": {"available_lives": 5, "next_restore_at": null},
		"reward_chest": {"stars": 0, "goal_index": 0, "completed_cycles": 0},
		"leaderboards": {"lifetime_stars": 0, "weekly_stars": 0, "weekly_period_start": null},
		"profile": {
			"avatar_id": "avatar_cat",
			"display_name": "game_011",
			"moderation_state": "active",
		},
	}


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
