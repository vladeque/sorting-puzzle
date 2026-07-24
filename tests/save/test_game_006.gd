extends SceneTree

## GAME-006: hardens local save synchronization recovery. GAME-001/004/005 already implemented
## persisted-pending-request retry, the single-refresh-attempt guard, and cursor-mismatch parsing,
## but no existing test ever fed SaveSyncService a non-success HTTPRequest result (timeout,
## response loss, connection failure), drove a full 401-refresh-then-replay or cursor-conflict
## round trip, exercised the real (non-no-op) checkpoint mapper's overspend-clamp/no-rollback
## behavior, or asserted diagnostics never leak secrets. This suite closes those gaps using the
## same "call the private handler directly" idiom test_game_004.gd/test_game_005.gd already use,
## so it needs no live backend and never opens a real socket.

const Codec := preload("res://scripts/save/local_save_codec.gd")
const SessionStore := preload("res://scripts/save/secure_session_store.gd")
const SaveStore := preload("res://scripts/save/local_save_store.gd")
const SyncService := preload("res://scripts/save/save_sync_service.gd")

const FEATURE_SETTING := "application/config/save_sync_v2_enabled"
const SERVER_URL_SETTING := "application/config/backend_base_url"

## Overrides only the two methods that would otherwise open a real HTTPRequest socket
## (_send_pending_request, _request_remote_state), replicating the bookkeeping the real methods
## set so the rest of the real orchestration logic (_on_request_completed, _refresh_session_and_*,
## _apply_response, _apply_state_response, _schedule_retry, _can_sync/request_background_sync)
## runs unmodified and under test.
class RecordingSyncService:
	extends SyncService

	var send_calls := []
	var state_calls := []

	func _send_pending_request(pending: Dictionary, session: Dictionary) -> void:
		send_calls.append({"pending": pending.duplicate(true), "session": session.duplicate(true)})
		_busy = true
		_request_mode = "sync"
		_active_session = session.duplicate(true)
		_request_store = _store

	func _request_remote_state(session: Dictionary, after_refresh: bool = false) -> void:
		if not after_refresh:
			_state_refresh_attempted = false
		state_calls.append({"session": session.duplicate(true), "after_refresh": after_refresh})
		_busy = true
		_request_mode = "state"
		_active_session = session.duplicate(true)
		_request_store = _store

## Only overrides can_synchronize() so _can_sync()'s feature-flag/URL gates can be exercised on a
## desktop test runner without the Android/iOS bridge requirement getting in the way.
class FakeSyncableSession:
	extends SessionStore

	func can_synchronize() -> bool:
		return true

var _failures := PackedStringArray()
var _session


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_session = SessionStore.new()
	_check(bool(_session.initialize().get("ok", false)), "installation identity initializes")

	_test_transport_and_server_faults_persist_identical_pending_request()
	_test_app_kill_and_restart_replays_identical_pending_request()
	_test_single_refresh_then_replay_uses_identical_pending_request()
	_test_unknown_refresh_transport_outcome_is_terminal_and_preserves_credential()
	_test_refresh_endpoint_429_and_5xx_are_terminal_not_retried()
	_test_cursor_conflict_fetches_remote_state_and_reconciles_before_retry()
	_test_disabling_sync_never_blocks_local_play_and_reenabling_drains_journal()
	_test_overspend_adjustment_clamps_without_rolling_back_campaign()
	_test_diagnostics_never_expose_secrets()

	if _failures.is_empty():
		print("GAME-006 tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_transport_and_server_faults_persist_identical_pending_request() -> void:
	var player_id := Codec.create_uuid()
	var store = SaveStore.new(_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	store.commit_snapshot(_snapshot(), _preferences(), [{
		"operation_type": "resource_spend",
		"payload": {"asset": "coins", "amount": 50, "reason": "gameplay"},
	}])

	var sync = SyncService.new()
	get_root().add_child(sync)
	sync.configure(store, _session, func(_checkpoint, current, _remaining): return current)
	var session := {"session_id": Codec.create_uuid(), "access_token": "test-token", "refresh_token": "test-refresh"}
	var build_result: Dictionary = sync.call("_build_request", session)
	_check(bool(build_result.get("ok", false)), "an initial sync batch builds")
	var pending := build_result.get("pending_request", {}) as Dictionary
	var sync_metadata := store.get_sync_metadata()
	sync_metadata["pending_request"] = pending.duplicate(true)
	store.persist_sync_metadata(sync_metadata)

	sync.set("_store", store)
	sync.set("_request_store", store)
	sync.set("_request_mode", "sync")
	sync.set("_active_session", session)

	var faults := [
		{"result": HTTPRequest.RESULT_TIMEOUT, "code": 0, "headers": PackedStringArray(), "label": "a request timeout"},
		{"result": HTTPRequest.RESULT_CONNECTION_ERROR, "code": 0, "headers": PackedStringArray(), "label": "response loss (connection error)"},
		{"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "headers": PackedStringArray(), "label": "an API restart (connection refused)"},
		{"result": HTTPRequest.RESULT_SUCCESS, "code": 503, "headers": PackedStringArray(), "label": "a database outage (503)"},
		{"result": HTTPRequest.RESULT_SUCCESS, "code": 500, "headers": PackedStringArray(), "label": "a retryable 5xx"},
		{"result": HTTPRequest.RESULT_SUCCESS, "code": 429, "headers": PackedStringArray(["Retry-After: 17"]), "label": "a 429 with Retry-After"},
	]
	for fault in faults:
		var reset_metadata := store.get_sync_metadata()
		reset_metadata["retry_attempt"] = 0
		reset_metadata["next_retry_unix"] = 0
		store.persist_sync_metadata(reset_metadata)

		var body := (
			"{}".to_utf8_buffer() if fault["result"] == HTTPRequest.RESULT_SUCCESS else PackedByteArray()
		)
		sync.call("_on_request_completed", fault["result"], fault["code"], fault["headers"], body)

		var after := store.get_sync_metadata()
		var after_pending := after.get("pending_request", {}) as Dictionary
		_check(
			str(after_pending.get("idempotency_key", "")) == str(pending.get("idempotency_key", ""))
			and str(after_pending.get("payload", "")) == str(pending.get("payload", "")),
			"%s persists retry state and keeps the identical payload/idempotency tuple" % fault["label"]
		)
		_check(
			(after.get("terminal_error", {}) as Dictionary).is_empty(),
			"%s never goes terminal" % fault["label"]
		)
		_check(
			int(after.get("retry_attempt", 0)) == 1 and int(after.get("next_retry_unix", 0)) > 0,
			"%s schedules exactly one retry attempt" % fault["label"]
		)
		if fault["code"] == 429:
			var now_unix := int(Time.get_unix_time_from_system())
			var retry_unix := int(after.get("next_retry_unix", 0))
			_check(
				retry_unix >= now_unix + 17 and retry_unix <= now_unix + 18,
				"a 429 honors the server's Retry-After delay exactly"
			)
	sync.queue_free()


func _test_app_kill_and_restart_replays_identical_pending_request() -> void:
	var player_id := Codec.create_uuid()
	var save_namespace := {"kind": "player", "player_id": player_id}
	var store = SaveStore.new(_session)
	store.open_namespace(save_namespace, _snapshot(), _preferences())
	store.commit_snapshot(_snapshot(), _preferences(), [{
		"operation_type": "resource_spend",
		"payload": {"asset": "coins", "amount": 25, "reason": "shop"},
	}])

	var sync = SyncService.new()
	get_root().add_child(sync)
	sync.configure(store, _session, func(_checkpoint, current, _remaining): return current)
	var session := {"session_id": Codec.create_uuid(), "access_token": "test-token", "refresh_token": "test-refresh"}
	var build_result: Dictionary = sync.call("_build_request", session)
	var pending := build_result.get("pending_request", {}) as Dictionary
	var sync_metadata := store.get_sync_metadata()
	sync_metadata["pending_request"] = pending.duplicate(true)
	store.persist_sync_metadata(sync_metadata)
	sync.queue_free()

	# App kill after the request was sent but before any response arrived: a fresh process reopens
	# the same on-disk namespace instead of reusing the in-memory store/service.
	var reopened_store = SaveStore.new(_session)
	var reopen_result: Dictionary = reopened_store.open_namespace(save_namespace, _snapshot(), _preferences())
	_check(bool(reopen_result.get("ok", false)), "the namespace reopens after a simulated app kill")
	var reopened_pending := reopened_store.get_sync_metadata().get("pending_request", {}) as Dictionary
	_check(
		str(reopened_pending.get("idempotency_key", "")) == str(pending.get("idempotency_key", ""))
		and str(reopened_pending.get("payload", "")) == str(pending.get("payload", "")),
		"the pending request survives an app kill with an identical payload/idempotency tuple"
	)

	var reopened_sync = SyncService.new()
	get_root().add_child(reopened_sync)
	reopened_sync.configure(reopened_store, _session, func(_checkpoint, current, _remaining): return current)
	reopened_sync.call("_schedule_retry")
	var retried := reopened_store.get_sync_metadata()
	_check(
		str((retried.get("pending_request", {}) as Dictionary).get("idempotency_key", ""))
		== str(pending.get("idempotency_key", "")),
		"restart-then-retry still replays the identical pending request instead of rebuilding one"
	)
	reopened_sync.queue_free()


func _test_single_refresh_then_replay_uses_identical_pending_request() -> void:
	var player_id := Codec.create_uuid()
	var store = SaveStore.new(_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	store.commit_snapshot(_snapshot(), _preferences(), [{
		"operation_type": "resource_spend",
		"payload": {"asset": "coins", "amount": 10, "reason": "ability_use"},
	}])

	var sync = RecordingSyncService.new()
	get_root().add_child(sync)
	sync.configure(store, _session, func(_checkpoint, current, _remaining): return current)
	var original_session := {
		"session_id": Codec.create_uuid(),
		"access_token": "expiring-access",
		"refresh_token": "original-refresh",
	}
	var build_result: Dictionary = sync.call("_build_request", original_session)
	var pending := build_result.get("pending_request", {}) as Dictionary
	var sync_metadata := store.get_sync_metadata()
	sync_metadata["pending_request"] = pending.duplicate(true)
	store.persist_sync_metadata(sync_metadata)

	sync.set("_store", store)
	sync.set("_request_store", store)
	sync.set("_request_mode", "sync")
	sync.set("_active_session", original_session)

	sync.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 401, PackedStringArray(), "{}".to_utf8_buffer())
	_check(
		bool((store.get_sync_metadata().get("pending_request", {}) as Dictionary).get("refresh_attempted", false)),
		"a 401 marks the pending request as having attempted one refresh"
	)
	_check(str(sync.get("_request_mode")) == "refresh_sync", "a 401 begins a refresh, not a second refresh")

	var refresh_request_id := str(sync.get("_refresh_request_id"))
	var refreshed_player_id := player_id
	var refresh_body := JSON.stringify({
		"meta": {"protocol_version": "1.1", "request_id": refresh_request_id, "correlation_id": Codec.create_uuid()},
		"data": {
			"player_id": refreshed_player_id,
			"device_id": _session.get_device_id(),
			"session_id": Codec.create_uuid(),
			"authentication_level": "player",
			"tokens": {
				"access_token": "rotated-access",
				"access_token_expires_at": "2099-01-01T00:00:00.000Z",
				"refresh_token": "rotated-refresh",
				"refresh_token_expires_at": "2099-01-01T00:00:00.000Z",
			},
		},
	}).to_utf8_buffer()
	sync.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), refresh_body)

	_check(sync.send_calls.size() == 1, "a successful refresh replays the sync request exactly once")
	if sync.send_calls.size() == 1:
		var replay := sync.send_calls[0] as Dictionary
		var replayed_pending := replay.get("pending", {}) as Dictionary
		_check(
			str(replayed_pending.get("idempotency_key", "")) == str(pending.get("idempotency_key", ""))
			and str(replayed_pending.get("payload", "")) == str(pending.get("payload", "")),
			"the post-refresh replay uses the identical payload/idempotency tuple, not a rebuilt request"
		)
		var replay_session := replay.get("session", {}) as Dictionary
		_check(
			str(replay_session.get("access_token", "")) == "rotated-access",
			"the post-refresh replay uses the newly rotated access token"
		)
	var loaded: Dictionary = _session.load_session(player_id)
	_check(
		str((loaded.get("session", {}) as Dictionary).get("access_token", "")) == "rotated-access",
		"the rotated session is persisted for subsequent requests"
	)
	sync.queue_free()


func _test_unknown_refresh_transport_outcome_is_terminal_and_preserves_credential() -> void:
	var player_id := Codec.create_uuid()
	var store = SaveStore.new(_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	var original_session := {
		"session_id": Codec.create_uuid(),
		"access_token": "original-access",
		"refresh_token": "original-refresh",
	}
	_session.store_session(player_id, original_session)

	var sync = SyncService.new()
	get_root().add_child(sync)
	sync.configure(store, _session, func(_checkpoint, current, _remaining): return current)
	sync.set("_store", store)
	sync.set("_request_store", store)
	sync.set("_request_mode", "refresh_sync")
	sync.set("_active_session", original_session)

	# The refresh POST itself times out / the response is lost. Refresh tokens are single-use, so
	# an unknown transport outcome must not be retried (it might already have rotated server-side).
	for fault_result in [HTTPRequest.RESULT_TIMEOUT, HTTPRequest.RESULT_CONNECTION_ERROR]:
		var reset := store.get_sync_metadata()
		reset["terminal_error"] = {}
		reset["retry_attempt"] = 0
		reset["next_retry_unix"] = 0
		store.persist_sync_metadata(reset)

		sync.call("_on_request_completed", fault_result, 0, PackedStringArray(), PackedByteArray())

		var after := store.get_sync_metadata()
		var terminal := after.get("terminal_error", {}) as Dictionary
		_check(
			str(terminal.get("code", "")) == "auth.refresh_result_unknown",
			"an unknown refresh transport outcome (%d) is terminal instead of retried" % fault_result
		)
		_check(
			int(after.get("retry_attempt", 0)) == 0 and int(after.get("next_retry_unix", 0)) == 0,
			"an unknown refresh transport outcome (%d) never schedules a retry that could replay the credential" % fault_result
		)

	var loaded: Dictionary = _session.load_session(player_id)
	_check(
		str((loaded.get("session", {}) as Dictionary).get("access_token", "")) == "original-access"
		and str((loaded.get("session", {}) as Dictionary).get("refresh_token", "")) == "original-refresh",
		"an unknown refresh transport outcome never overwrites or reuses the stored credential"
	)
	sync.queue_free()


func _test_refresh_endpoint_429_and_5xx_are_terminal_not_retried() -> void:
	# By design this differs from the /v2/saves/sync retry policy: a refresh token is single-use,
	# so blindly retrying an ambiguous refresh response risks a reuse/theft response from the
	# backend. A 429/5xx on refresh is therefore a non-secret terminal diagnostic, not a retry.
	var player_id := Codec.create_uuid()
	var store = SaveStore.new(_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	var original_session := {
		"session_id": Codec.create_uuid(),
		"access_token": "original-access",
		"refresh_token": "original-refresh",
	}
	_session.store_session(player_id, original_session)

	var sync = SyncService.new()
	get_root().add_child(sync)
	sync.configure(store, _session, func(_checkpoint, current, _remaining): return current)
	sync.set("_store", store)
	sync.set("_request_store", store)
	sync.set("_active_session", original_session)

	for response_code in [429, 503]:
		var reset := store.get_sync_metadata()
		reset["terminal_error"] = {}
		reset["retry_attempt"] = 0
		reset["next_retry_unix"] = 0
		store.persist_sync_metadata(reset)
		sync.set("_request_mode", "refresh_sync")

		sync.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, response_code, PackedStringArray(), "{}".to_utf8_buffer())

		var after := store.get_sync_metadata()
		_check(
			str((after.get("terminal_error", {}) as Dictionary).get("code", "")) == "auth.session_refresh_failed",
			"a refresh endpoint %d is terminal rather than silently retried" % response_code
		)
		_check(
			int(after.get("retry_attempt", 0)) == 0,
			"a refresh endpoint %d never schedules a background retry" % response_code
		)
	sync.queue_free()


func _test_cursor_conflict_fetches_remote_state_and_reconciles_before_retry() -> void:
	var player_id := Codec.create_uuid()
	var device_id: String = _session.get_device_id()
	var store = SaveStore.new(_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	store.commit_snapshot(_snapshot(), _preferences(), [{
		"operation_type": "resource_spend",
		"payload": {"asset": "coins", "amount": 30, "reason": "gameplay"},
	}])

	var sync = RecordingSyncService.new()
	get_root().add_child(sync)
	sync.configure(store, _session, func(_checkpoint, current, _remaining): return current)
	var session := {"session_id": Codec.create_uuid(), "access_token": "test-token", "refresh_token": "test-refresh"}
	var build_result: Dictionary = sync.call("_build_request", session)
	var pending := build_result.get("pending_request", {}) as Dictionary
	var sync_metadata := store.get_sync_metadata()
	sync_metadata["pending_request"] = pending.duplicate(true)
	store.persist_sync_metadata(sync_metadata)

	sync.set("_store", store)
	sync.set("_request_store", store)
	sync.set("_request_mode", "sync")
	sync.set("_active_session", session)

	var conflict_body := JSON.stringify({
		"error": {"code": "save_sync.cursor_mismatch"},
		"meta": {"correlation_id": Codec.create_uuid()},
	}).to_utf8_buffer()
	sync.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 409, PackedStringArray(), conflict_body)

	_check(sync.state_calls.size() == 1, "a cursor-mismatch fetches the remote save state instead of retrying blindly")
	_check(sync.send_calls.is_empty(), "a cursor-mismatch never resends the stale request before reconciling")
	_check(
		not (store.get_sync_metadata().get("pending_request", {}) as Dictionary).is_empty(),
		"the stale pending request is preserved while remote state is fetched"
	)

	# GDScript lambdas capture outer locals by value, so a plain bool wouldn't observe the emit;
	# capture a mutable Array instead so the signal handler's write is visible after the call.
	var reconciled := []
	sync.reconciliation_applied.connect(func(): reconciled.append(true))

	var operation_1 := store.get_journal()[0] as Dictionary
	var state_body := {
		"meta": {"protocol_version": "2.0"},
		"data": {
			"checkpoint": {
				"format": "save-checkpoint/2",
				"player_id": player_id,
				"balances": {"coins": 270},
			},
			"device_cursors": [{
				"device_id": device_id,
				"acknowledged_sequence": 1,
				"acknowledged_hash": operation_1.get("operation_hash"),
			}],
			"capabilities": {
				"unrestricted_offline_play": true,
				"maximum_operations_per_request": 500,
				"maximum_request_bytes": 1024 * 1024,
			},
		},
	}
	sync.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(state_body).to_utf8_buffer())

	_check(not reconciled.is_empty(), "a resolved cursor conflict reconciles the fetched checkpoint before any retry")
	var after_state := store.get_sync_metadata()
	_check(
		(after_state.get("pending_request", {}) as Dictionary).is_empty(),
		"reconciling the fetched state clears the stale pending request"
	)
	_check(
		(after_state.get("terminal_error", {}) as Dictionary).is_empty(),
		"a resolved cursor conflict never leaves a terminal error behind"
	)
	_check(
		int((after_state.get("cursor", {}) as Dictionary).get("acknowledged_sequence", -1)) == 1,
		"reconciliation adopts the remote-confirmed cursor"
	)
	sync.queue_free()


func _test_disabling_sync_never_blocks_local_play_and_reenabling_drains_journal() -> void:
	var original_feature: bool = ProjectSettings.get_setting(FEATURE_SETTING, false)
	var original_url: String = ProjectSettings.get_setting(SERVER_URL_SETTING, "")

	var player_id := Codec.create_uuid()
	var store = SaveStore.new(_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())

	var session_store := FakeSyncableSession.new()
	session_store.initialize()
	session_store.store_session(player_id, {
		"session_id": Codec.create_uuid(),
		"access_token": "test-token",
		"refresh_token": "test-refresh",
	})

	var sync = RecordingSyncService.new()
	get_root().add_child(sync)
	sync.configure(store, session_store, func(_checkpoint, current, _remaining): return current)

	ProjectSettings.set_setting(FEATURE_SETTING, false)
	ProjectSettings.set_setting(SERVER_URL_SETTING, "")

	var spend_result: Dictionary = store.commit_snapshot(_snapshot(), _preferences(), [{
		"operation_type": "resource_spend",
		"payload": {"asset": "coins", "amount": 40, "reason": "gameplay"},
	}])
	_check(bool(spend_result.get("ok", false)), "a local spend commits while v2 synchronization is disabled")
	var completion_result: Dictionary = store.commit_snapshot(_snapshot(), _preferences(), [{
		"operation_type": "campaign_completion",
		"payload": {
			"campaign_level": 1,
			"stars": 3,
			"configuration_version": "config_dev",
			"level_version": "level_dev",
			"rules_version": "rules_dev",
		},
	}])
	_check(bool(completion_result.get("ok", false)), "a local level completion commits while v2 synchronization is disabled")

	sync.request_background_sync()
	_check(sync.send_calls.is_empty(), "no synchronization attempt is made while the feature flag is disabled")
	_check(
		(store.get_sync_metadata().get("pending_request", {}) as Dictionary).is_empty(),
		"no pending request is built while the feature flag is disabled"
	)

	ProjectSettings.set_setting(FEATURE_SETTING, true)
	ProjectSettings.set_setting(SERVER_URL_SETTING, "https://backend.example.invalid")
	sync.request_background_sync()

	_check(sync.send_calls.size() == 1, "re-enabling the feature flag drains the accumulated journal in one request")
	if sync.send_calls.size() == 1:
		var drained := (sync.send_calls[0] as Dictionary).get("pending", {}) as Dictionary
		_check(
			int(drained.get("first_sequence", -1)) == 1 and int(drained.get("last_sequence", -1)) == 2,
			"the drained request covers both operations queued while synchronization was disabled"
		)

	ProjectSettings.set_setting(FEATURE_SETTING, original_feature)
	ProjectSettings.set_setting(SERVER_URL_SETTING, original_url)
	sync.queue_free()


func _test_overspend_adjustment_clamps_without_rolling_back_campaign() -> void:
	var progress = get_root().get_node_or_null("PlayerProgress")
	_check(progress != null, "PlayerProgress autoload is available")
	if progress == null:
		return

	var current_snapshot := {
		"version": 4,
		"current_level": 6,
		"highest_completed_level": 5,
		"coins": 500,
		"lives": 5,
		"next_life_restore_unix": 0,
		"ability_uses": {"hammer": 3, "shuffle": 3, "highlight": 3},
		"processed_shop_purchase_ids": [],
		"avatar_id": "avatar_cat",
		"player_name": "test_player",
		"reward_chest_stars": 0,
		"reward_chest_goal_index": 0,
		"reward_chest_completed_cycles": 0,
		"total_earned_stars": 0,
		"weekly_earned_stars": 0,
		"leaderboard_week_start_unix": 0,
	}
	# The server accepted an overspend past the authoritative balance and clamped it to zero
	# rather than rejecting the whole batch; campaign progress it also accepted is unaffected.
	var checkpoint := {
		"campaign": {"current_level": 6, "highest_completed_level": 5},
		"balances": {"coins": 0},
		"abilities": {"hammer": 3, "shuffle": 3, "highlight": 3},
		"lives": {"available_lives": 5, "next_restore_at": null},
		"reward_chest": {"stars": 0, "goal_index": 0, "completed_cycles": 0},
		"leaderboards": {"lifetime_stars": 15, "weekly_stars": 15, "weekly_period_start": null},
		"profile": {"avatar_id": "avatar_cat", "display_name": "test_player", "moderation_state": "active"},
	}
	var mapped = progress.call("_map_checkpoint_to_snapshot", checkpoint, current_snapshot, [])
	_check(
		int(mapped.get("coins", -1)) == 0,
		"an overspend adjustment clamps the affected asset to the server-confirmed balance"
	)
	_check(
		int(mapped.get("highest_completed_level", -1)) == 5 and int(mapped.get("current_level", -1)) == 6,
		"an overspend clamp does not roll back campaign levels the server already accepted"
	)

	# A still-unacknowledged local operation replays on top of the clamped checkpoint: a further
	# overspend floors at zero instead of going negative, while a pending completion still advances.
	var remaining := [
		{
			"operation_type": "resource_spend",
			"payload": {"asset": "coins", "amount": 999, "reason": "gameplay"},
		},
		{
			"operation_type": "campaign_completion",
			"payload": {"campaign_level": 6, "stars": 2},
		},
	]
	var mapped_with_remaining = progress.call("_map_checkpoint_to_snapshot", checkpoint, current_snapshot, remaining)
	_check(
		int(mapped_with_remaining.get("coins", -1)) == 0,
		"replaying a further local overspend on top of a clamped checkpoint floors at zero, never negative"
	)
	_check(
		int(mapped_with_remaining.get("highest_completed_level", -1)) == 6,
		"a still-unacknowledged completion still advances progress on top of a clamped checkpoint"
	)


func _test_diagnostics_never_expose_secrets() -> void:
	var progress = get_root().get_node_or_null("PlayerProgress")
	_check(progress != null, "PlayerProgress autoload is available")
	if progress == null:
		return

	var player_id := Codec.create_uuid()
	_check(progress.switch_to_player(player_id), "an isolated player namespace activates for the diagnostics test")

	var secret_access_token := "leak-check-access-token-should-never-appear-93f7"
	var secret_refresh_token := "leak-check-refresh-token-should-never-appear-71ba"
	var secret_signature := "leak-check-signature-should-never-appear-a52c"
	var secret_payload_marker := "leak-check-request-body-should-never-appear-c410"

	var session_store = progress.get("_session_store")
	session_store.store_session(player_id, {
		"session_id": Codec.create_uuid(),
		"access_token": secret_access_token,
		"refresh_token": secret_refresh_token,
	})

	var store = progress.get("_local_store")
	var sync: Dictionary = store.get_sync_metadata()
	var correlation_id := "00000000-0000-4000-8000-000000000999"
	sync["terminal_error"] = {
		"code": "save_sync.terminal",
		"correlation_id": correlation_id,
		"recorded_at": Codec.iso_timestamp(),
	}
	sync["last_correlation_id"] = correlation_id
	sync["adjustments"] = [{"kind": "balance_floor", "asset": "coins", "adjusted_to": 0, "signature": secret_signature}]
	sync["pending_request"] = {
		"idempotency_key": Codec.create_uuid(),
		"request_id": Codec.create_uuid(),
		"payload": JSON.stringify({"data": {"marker": secret_payload_marker}}),
		"first_sequence": 1,
		"last_sequence": 1,
	}
	store.persist_sync_metadata(sync)

	var diagnostics: Dictionary = progress.get_local_save_diagnostics()
	_check(
		str((diagnostics.get("terminal_error", {}) as Dictionary).get("correlation_id", "")) == correlation_id,
		"diagnostics expose the stable terminal error correlation id"
	)
	_check(
		str(diagnostics.get("last_correlation_id", "")) == correlation_id,
		"diagnostics expose the stable last-response correlation id"
	)
	_check(
		int(diagnostics.get("merge_adjustment_count", -1)) == 1,
		"diagnostics expose an adjustment count without the raw adjustment payload"
	)

	var serialized := JSON.stringify(diagnostics)
	_check(not serialized.contains(secret_access_token), "diagnostics never leak the raw access token")
	_check(not serialized.contains(secret_refresh_token), "diagnostics never leak the raw refresh token")
	_check(not serialized.contains(secret_signature), "diagnostics never leak a raw adjustment signature")
	_check(not serialized.contains(secret_payload_marker), "diagnostics never leak the raw pending request body")
	_check(not serialized.contains("access_token"), "diagnostics never expose an access_token field")
	_check(not serialized.contains("refresh_token"), "diagnostics never expose a refresh_token field")
	_check(not serialized.contains("signature"), "diagnostics never expose a signature field")


func _snapshot() -> Dictionary:
	return {
		"version": 4,
		"current_level": 1,
		"highest_completed_level": 0,
		"coins": 300,
		"lives": 5,
		"next_life_restore_unix": 0,
		"ability_uses": {"hammer": 3, "shuffle": 3, "highlight": 3},
		"processed_shop_purchase_ids": [],
		"avatar_id": "avatar_cat",
		"player_name": "test_player",
		"reward_chest_stars": 0,
		"reward_chest_goal_index": 0,
		"reward_chest_completed_cycles": 0,
		"total_earned_stars": 0,
		"weekly_earned_stars": 0,
		"leaderboard_week_start_unix": 0,
	}


func _preferences() -> Dictionary:
	return {
		"settings_disabled": {
			"music": false,
			"sound_effects": false,
			"vibration": false,
		},
	}


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
