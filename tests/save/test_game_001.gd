extends SceneTree

const Codec := preload("res://scripts/save/local_save_codec.gd")
const SessionStore := preload("res://scripts/save/secure_session_store.gd")
const SaveStore := preload("res://scripts/save/local_save_store.gd")
const SyncService := preload("res://scripts/save/save_sync_service.gd")
const GuestBootstrapService := preload("res://scripts/save/guest_session_bootstrap_service.gd")

class FakeGuestSession:
	extends RefCounted

	var signed_payload := ""
	var public_key := ""
	var device_id := "00000000-0000-4000-8000-000000000132"

	func _init() -> void:
		var key_bytes := PackedByteArray()
		key_bytes.resize(91)
		for index in range(key_bytes.size()):
			key_bytes[index] = index
		public_key = Marshalls.raw_to_base64(key_bytes)

	func get_installation_public_key_der_base64() -> String:
		return public_key

	func get_device_id() -> String:
		return device_id

	func sign_installation_payload(payload: String) -> Dictionary:
		signed_payload = payload
		var signature := PackedByteArray()
		signature.resize(70)
		return {"ok": true, "signature": Marshalls.raw_to_base64(signature)}

var _failures := PackedStringArray()
var _session


func _init() -> void:
	_session = SessionStore.new()
	_check(bool(_session.initialize().get("ok", false)), "installation identity initializes")
	_test_backend_fixture_hash()
	_test_guest_registration_proof_contract()
	_test_all_operation_types_and_recovery()
	_test_schema_rejection()
	_test_atomic_interruption_recovery()
	_test_checksum_and_hash_recovery()
	_test_migration_restart_and_compaction()
	_test_account_namespace_isolation_and_rebind()
	_test_unrestricted_offline_journal_and_batching()

	if _failures.is_empty():
		print("GAME-001 tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_backend_fixture_hash() -> void:
	var fixture_path := ProjectSettings.globalize_path(
		"res://../sorting-puzzle-backend/contracts/fixtures/v2/save-sync.request.json"
	)
	var file := FileAccess.open(fixture_path, FileAccess.READ)
	_check(file != null, "backend v2 fixture is available")
	if file == null:
		return
	var fixture = JSON.parse_string(file.get_as_text())
	_check(fixture is Dictionary, "backend v2 fixture parses")
	if not (fixture is Dictionary):
		return
	var operations := (fixture as Dictionary).get("data", {}).get("operations", []) as Array
	var operation := operations[0] as Dictionary
	_check(
		Codec.operation_hash(operation) == str(operation.get("operation_hash", "")),
		"Godot canonical operation hash matches the backend golden fixture"
	)


func _test_guest_registration_proof_contract() -> void:
	var fake_session := FakeGuestSession.new()
	var service = GuestBootstrapService.new()
	service.set("_session_store", fake_session)
	var challenge := {
		"challenge_id": "00000000-0000-4000-8000-000000000134",
		"nonce": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
		"expires_at": "2099-07-16T09:05:00.000Z",
	}
	var pending: Dictionary = service.call("_build_bootstrap_request", challenge)
	var envelope = JSON.parse_string(str(pending.get("payload", "")))
	_check(envelope is Dictionary, "guest bootstrap request serializes")
	if envelope is Dictionary:
		var meta := (envelope as Dictionary).get("meta", {}) as Dictionary
		var expected_payload := Codec.canonical_json([
			"guest-registration-proof/1",
			challenge["challenge_id"],
			challenge["nonce"],
			str(meta.get("request_id", "")),
			str(pending.get("idempotency_key", "")),
			fake_session.device_id,
			_sha256_bytes(Marshalls.base64_to_raw(fake_session.public_key)),
		])
		_check(
			fake_session.signed_payload == expected_payload,
			"guest proof signs the backend field order exactly"
		)
	service.free()


func _test_all_operation_types_and_recovery() -> void:
	var save_namespace := _guest_namespace()
	var store = SaveStore.new(_session)
	_check(
		bool(store.open_namespace(save_namespace, _snapshot(300), _preferences()).get("ok", false)),
		"new namespace opens"
	)
	var timestamp := Codec.iso_timestamp()
	var operations := [
		{
			"operation_type": "campaign_completion",
			"payload": _completion_payload(1, 3),
		},
		{
			"operation_type": "campaign_attempt",
			"payload": {
				"campaign_level": 2,
				"outcome": "failed",
				"configuration_version": "config-test",
				"level_version": "level-2-test",
				"rules_version": "rules-test",
			},
		},
		{
			"operation_type": "resource_spend",
			"payload": {"asset": "coins", "amount": 10, "reason": "gameplay"},
		},
		{
			"operation_type": "life_state",
			"payload": {
				"available_lives": 4,
				"maximum_lives": 5,
				"restore_interval_seconds": 3600,
				"next_restore_at": Codec.iso_timestamp(int(Time.get_unix_time_from_system()) + 3600),
				"observed_at": timestamp,
			},
		},
		{
			"operation_type": "profile_edit",
			"payload": {"display_name": "Fixture Player", "avatar_id": "avatar_cat"},
		},
	]
	var result: Dictionary = store.commit_snapshot(_snapshot(290), _preferences(), operations)
	_check(bool(result.get("ok", false)), "all five v2 operation types commit atomically")
	var journal: Array = store.get_journal()
	_check(journal.size() == 5, "all operation types are appended")
	var previous_hash = null
	for index in range(journal.size()):
		var operation := journal[index] as Dictionary
		_check(int(operation.get("device_sequence", 0)) == index + 1, "device sequence is contiguous")
		_check(operation.get("previous_operation_hash") == previous_hash, "operation hash chain is contiguous")
		_check(Codec.operation_hash(operation) == operation.get("operation_hash"), "operation hash validates")
		previous_hash = operation.get("operation_hash")

	var reopened = SaveStore.new(_session)
	var reopen_result: Dictionary = reopened.open_namespace(
		save_namespace,
		_snapshot(0),
		_preferences()
	)
	_check(bool(reopen_result.get("ok", false)), "valid generation reopens")
	_check(int((reopen_result.get("snapshot", {}) as Dictionary).get("coins", 0)) == 290, "snapshot survives restart")
	_check(reopened.get_journal().size() == 5, "journal survives restart")


func _test_schema_rejection() -> void:
	var store = SaveStore.new(_session)
	var save_namespace := _guest_namespace()
	store.open_namespace(save_namespace, _snapshot(10), _preferences())
	var bad_operation := {
		"operation_type": "resource_spend",
		"payload": {
			"asset": "coins",
			"amount": 1,
			"reason": "gameplay",
			"unexpected": true,
		},
	}
	var result: Dictionary = store.commit_snapshot(_snapshot(9), _preferences(), [bad_operation])
	_check(not bool(result.get("ok", false)), "closed operation payload rejects unknown fields")
	_check(store.get_journal().is_empty(), "rejected operation does not alter the journal")
	store.commit_snapshot(_snapshot(10), _preferences(), [
		{"operation_type": "profile_edit", "payload": {"display_name": "First"}},
		{"operation_type": "profile_edit", "payload": {"display_name": "Second"}},
	])
	var out_of_order := _read_json(_current_path(save_namespace))
	var journal := out_of_order.get("journal", []) as Array
	var first = journal[0]
	journal[0] = journal[1]
	journal[1] = first
	out_of_order["journal"] = journal
	out_of_order.erase("integrity")
	out_of_order["integrity"] = {"sha256": Codec.sha256_json(out_of_order)}
	_check(
		not bool(store.validate_document(out_of_order).get("ok", false)),
		"out-of-order operations are rejected even with a recomputed container checksum"
	)


func _test_atomic_interruption_recovery() -> void:
	for stage in [
		"after_temp_flush",
		"after_temp_validation",
		"after_previous_rotation",
		"after_current_promotion",
	]:
		var save_namespace := _guest_namespace()
		var store = SaveStore.new(_session)
		store.open_namespace(save_namespace, _snapshot(1), _preferences())
		store.set_test_interrupt_stage(stage)
		var interrupted: Dictionary = store.commit_snapshot(
			_snapshot(2),
			_preferences(),
			[{"operation_type": "resource_spend", "payload": {
				"asset": "coins",
				"amount": 1,
				"reason": "gameplay",
			}}]
		)
		_check(not bool(interrupted.get("ok", false)), "%s interruption is injected" % stage)
		var recovered = SaveStore.new(_session)
		var recovery: Dictionary = recovered.open_namespace(
			save_namespace,
			_snapshot(0),
			_preferences()
		)
		_check(bool(recovery.get("ok", false)), "%s leaves a recoverable generation" % stage)
		_check(
			int((recovery.get("snapshot", {}) as Dictionary).get("coins", 0)) == 2,
			"%s chooses the newest fully valid generation" % stage
		)


func _test_checksum_and_hash_recovery() -> void:
	var save_namespace := _guest_namespace()
	var store = SaveStore.new(_session)
	store.open_namespace(save_namespace, _snapshot(10), _preferences())
	store.commit_snapshot(_snapshot(9), _preferences(), [{
		"operation_type": "resource_spend",
		"payload": {"asset": "coins", "amount": 1, "reason": "gameplay"},
	}])
	var current_path := _current_path(save_namespace)
	var current := _read_json(current_path)
	current["snapshot"]["coins"] = 777
	_write_json(current_path, current)
	var recovered = SaveStore.new(_session)
	var checksum_recovery: Dictionary = recovered.open_namespace(
		save_namespace,
		_snapshot(0),
		_preferences()
	)
	_check(
		int((checksum_recovery.get("snapshot", {}) as Dictionary).get("coins", 0)) == 10,
		"checksum corruption recovers the previous generation"
	)

	var hash_namespace := _guest_namespace()
	var hash_store = SaveStore.new(_session)
	hash_store.open_namespace(hash_namespace, _snapshot(10), _preferences())
	hash_store.commit_snapshot(_snapshot(9), _preferences(), [{
		"operation_type": "resource_spend",
		"payload": {"asset": "coins", "amount": 1, "reason": "gameplay"},
	}])
	var hash_path := _current_path(hash_namespace)
	var hash_document := _read_json(hash_path)
	hash_document["journal"][0]["operation_hash"] = "0".repeat(64)
	var unsigned := hash_document.duplicate(true)
	unsigned.erase("integrity")
	hash_document["integrity"] = {"sha256": Codec.sha256_json(unsigned)}
	_write_json(hash_path, hash_document)
	var hash_recovered = SaveStore.new(_session)
	var hash_result: Dictionary = hash_recovered.open_namespace(
		hash_namespace,
		_snapshot(0),
		_preferences()
	)
	_check(
		int((hash_result.get("snapshot", {}) as Dictionary).get("coins", 0)) == 10,
		"operation-hash corruption recovers the previous generation"
	)


func _test_migration_restart_and_compaction() -> void:
	var save_namespace := _guest_namespace()
	var legacy_path := "user://game001_legacy_%s.json" % Codec.create_uuid()
	_write_json(legacy_path, {"version": 4, "coins": 42, "current_level": 7})
	var store = SaveStore.new(_session)
	var result: Dictionary = store.open_namespace(
		save_namespace,
		_snapshot(42),
		_preferences(),
		legacy_path,
		4
	)
	_check(bool(result.get("migrated", false)), "schema 4 migration is recorded")
	var legacy_copy := "%s/legacy_v4.previous.json" % _namespace_directory(save_namespace)
	_check(FileAccess.file_exists(legacy_copy), "read-only legacy previous-good copy is retained")
	var restarted = SaveStore.new(_session)
	restarted.open_namespace(save_namespace, _snapshot(0), _preferences())
	var migration := restarted.get_sync_metadata().get("migration", {}) as Dictionary
	_check(bool(migration.get("complete", false)), "migration completes only after a validated restart")

	var specs := []
	for index in range(125):
		specs.append({
			"operation_type": "resource_spend",
			"payload": {"asset": "coins", "amount": 1, "reason": "gameplay"},
		})
	restarted.commit_snapshot(_snapshot(0), _preferences(), specs)
	var journal := restarted.get_journal()
	var last := journal[-1] as Dictionary
	var cursor := {
		"device_id": _session.get_device_id(),
		"acknowledged_sequence": int(last.get("device_sequence", 0)),
		"acknowledged_hash": last.get("operation_hash"),
	}
	restarted.apply_reconciliation(_snapshot(0), cursor, {}, [])
	var compact_result: Dictionary = restarted.compact_journal()
	_check(bool(compact_result.get("ok", false)), "acknowledged journal compacts")
	_check(restarted.get_journal().size() == 100, "compaction retains recent acknowledged support history")


func _test_account_namespace_isolation_and_rebind() -> void:
	var player_a := Codec.create_uuid()
	var player_b := Codec.create_uuid()
	var store_a = SaveStore.new(_session)
	var store_b = SaveStore.new(_session)
	store_a.open_namespace({"kind": "player", "player_id": player_a}, _snapshot(111), _preferences())
	store_b.open_namespace({"kind": "player", "player_id": player_b}, _snapshot(222), _preferences())
	_check(int(store_a.get_snapshot().get("coins", 0)) == 111, "account A snapshot remains isolated")
	_check(int(store_b.get_snapshot().get("coins", 0)) == 222, "account B snapshot remains isolated")

	var guest_namespace := _guest_namespace()
	var guest_store = SaveStore.new(_session)
	guest_store.open_namespace(guest_namespace, _snapshot(333), _preferences())
	var first_player_id := Codec.create_uuid()
	var rebound: Dictionary = guest_store.rebind_guest_to_player(first_player_id)
	_check(bool(rebound.get("ok", false)), "installation guest can be rebound once")
	guest_store.commit_snapshot(_snapshot(444), _preferences())
	var second_rebind: Dictionary = guest_store.rebind_guest_to_player(Codec.create_uuid())
	_check(not bool(second_rebind.get("ok", false)), "rebound save cannot be rebound to another player")
	var original_guest = SaveStore.new(_session)
	original_guest.open_namespace(guest_namespace, _snapshot(0), _preferences())
	var resumed_rebind: Dictionary = original_guest.rebind_guest_to_player(first_player_id)
	_check(bool(resumed_rebind.get("ok", false)), "same guest rebind resumes its existing player namespace")
	_check(
		int(original_guest.get_snapshot().get("coins", 0)) == 444,
		"same guest rebind does not overwrite newer player progress"
	)
	original_guest = SaveStore.new(_session)
	original_guest.open_namespace(guest_namespace, _snapshot(0), _preferences())
	_check(
		not bool(original_guest.rebind_guest_to_player(Codec.create_uuid()).get("ok", false)),
		"original guest generation retains the one-time rebind marker"
	)


func _test_unrestricted_offline_journal_and_batching() -> void:
	var player_id := Codec.create_uuid()
	var save_namespace := {"kind": "player", "player_id": player_id}
	var store = SaveStore.new(_session)
	store.open_namespace(save_namespace, _snapshot(1000), _preferences())
	var operations := []
	for index in range(620):
		operations.append({
			"operation_type": "campaign_completion",
			"payload": _completion_payload(index + 1, posmod(index, 4)),
		})
	var result: Dictionary = store.commit_snapshot(_snapshot(1000), _preferences(), operations)
	_check(bool(result.get("ok", false)), "more than 100 consecutive offline completions persist")
	_check(store.get_journal().size() == 620, "offline play is not journal-count limited")

	var sync = SyncService.new()
	get_root().add_child(sync)
	sync.configure(store, _session, func(checkpoint, current, remaining): return current)
	var build_result: Dictionary = sync.call("_build_request", {
		"session_id": Codec.create_uuid(),
		"access_token": "test-token",
	})
	_check(bool(build_result.get("ok", false)), "sync batch builds")
	var pending := build_result.get("pending_request", {}) as Dictionary
	var envelope = JSON.parse_string(str(pending.get("payload", "")))
	var batch_operations := (envelope as Dictionary).get("data", {}).get("operations", []) as Array
	_check(batch_operations.size() == 500, "sync batch is capped at 500 operations")
	_check(
		str(pending.get("payload", "")).to_utf8_buffer().size() <= 1024 * 1024,
		"sync batch is capped at 1 MiB"
	)
	var sync_metadata := store.get_sync_metadata()
	sync_metadata["pending_request"] = pending.duplicate(true)
	var persist_result: Dictionary = store.persist_sync_metadata(sync_metadata)
	_check(bool(persist_result.get("ok", false)), "pending retry state persists")
	var reopened = SaveStore.new(_session)
	var reopen_result: Dictionary = reopened.open_namespace(save_namespace, _snapshot(0), _preferences())
	_check(bool(reopen_result.get("ok", false)), "pending retry namespace reopens")
	var reopened_pending := reopened.get_sync_metadata().get("pending_request", {}) as Dictionary
	_check(
		str(reopened_pending.get("payload", "")) == str(pending.get("payload", "")),
		"identical payload survives restart"
	)
	_check(
		str(reopened_pending.get("idempotency_key", "")) == str(pending.get("idempotency_key", "")),
		"identical idempotency key survives restart"
	)
	var reopened_sync = SyncService.new()
	get_root().add_child(reopened_sync)
	reopened_sync.configure(reopened, _session, func(checkpoint, current, remaining): return current)
	reopened_sync.call("_schedule_retry")
	var retry_metadata := reopened.get_sync_metadata()
	_check(int(retry_metadata.get("retry_attempt", 0)) == 1, "server outage backoff persists")
	_check(
		str((retry_metadata.get("pending_request", {}) as Dictionary).get("payload", ""))
		== str(pending.get("payload", "")),
		"server outage retains the identical pending payload"
	)

	var operation_500 := reopened.get_journal()[499] as Dictionary
	var response := {
		"meta": {
			"protocol_version": "2.0",
			"request_id": pending.get("request_id"),
		},
		"data": {
			"acknowledged_cursor": {
				"device_id": _session.get_device_id(),
				"acknowledged_sequence": 500,
				"acknowledged_hash": operation_500.get("operation_hash"),
			},
			"checkpoint": {
				"format": "save-checkpoint/2",
				"player_id": player_id,
			},
			"adjustments": [{
				"kind": "balance_floor",
				"asset": "coins",
				"adjusted_to": 0,
			}],
			"continuation": {
				"has_more": true,
				"next_device_sequence": 501,
				"maximum_operations_per_request": 500,
			},
		},
	}
	var apply_result: Dictionary = reopened_sync.call("_apply_response", response)
	_check(bool(apply_result.get("ok", false)), "valid checkpoint and cursor reconcile")
	_check(
		(reopened.get_sync_metadata().get("adjustments", []) as Array).size() == 1,
		"merge adjustments remain available for diagnostics"
	)
	_check(reopened.get_journal().size() == 220, "compaction retains 100 acknowledged plus pending operations")
	_check(
		not bool((reopened_sync.call("_apply_response", response) as Dictionary).get("ok", false)),
		"duplicate response cannot apply after its pending request is cleared"
	)
	var stale_cursor := {
		"device_id": _session.get_device_id(),
		"acknowledged_sequence": 499,
		"acknowledged_hash": (store.get_journal()[498] as Dictionary).get("operation_hash"),
	}
	_check(
		not bool(reopened.apply_reconciliation(_snapshot(0), stale_cursor, {}, []).get("ok", false)),
		"stale cursor is rejected"
	)
	_check(
		not bool((reopened_sync.call("_apply_response", {"meta": {}, "data": {}}) as Dictionary).get("ok", false)),
		"malformed sync response is rejected"
	)

	var continuation_result: Dictionary = reopened_sync.call("_build_request", {
		"session_id": Codec.create_uuid(),
		"access_token": "test-token",
	})
	var continuation_pending := continuation_result.get("pending_request", {}) as Dictionary
	var continuation_envelope = JSON.parse_string(str(continuation_pending.get("payload", "")))
	var continuation_operations := (
		(continuation_envelope as Dictionary).get("data", {}).get("operations", []) as Array
	)
	_check(continuation_operations.size() == 120, "remaining journal continues in a second batch")
	var continuation_sync := reopened.get_sync_metadata()
	continuation_sync["pending_request"] = continuation_pending
	reopened.persist_sync_metadata(continuation_sync)

	var refreshed_session_id := Codec.create_uuid()
	reopened_sync.set("_refresh_request_id", "00000000-0000-4000-8000-000000000141")
	var refresh_result: Dictionary = reopened_sync.call("_validate_and_store_refresh_response", {
		"meta": {
			"protocol_version": "1.1",
			"request_id": "00000000-0000-4000-8000-000000000141",
		},
		"data": {
			"player_id": player_id,
			"device_id": _session.get_device_id(),
			"session_id": refreshed_session_id,
			"authentication_level": "guest",
			"tokens": {
				"access_token": "rotated-access",
				"access_token_expires_at": "2099-01-01T00:00:00.000Z",
				"refresh_token": "rotated-refresh",
				"refresh_token_expires_at": "2099-02-01T00:00:00.000Z",
			},
		},
	})
	_check(bool(refresh_result.get("ok", false)), "valid token refresh response is accepted")
	var loaded_session: Dictionary = _session.load_session(player_id)
	_check(bool(loaded_session.get("ok", false)), "rotated session is stored securely")
	_check(
		str((loaded_session.get("session", {}) as Dictionary).get("session_id", ""))
		== refreshed_session_id,
		"validated refresh response replaces the session"
	)
	reopened_sync.queue_free()
	sync.queue_free()


func _completion_payload(level_number: int, stars: int) -> Dictionary:
	return {
		"campaign_level": level_number,
		"stars": clampi(stars, 0, 3),
		"configuration_version": "config-test",
		"level_version": "level-%d-test" % level_number,
		"rules_version": "rules-test",
	}


func _snapshot(coins: int) -> Dictionary:
	return {
		"version": 4,
		"current_level": 1,
		"highest_completed_level": 0,
		"coins": coins,
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


func _guest_namespace() -> Dictionary:
	return {"kind": "installation_guest", "installation_id": Codec.create_uuid()}


func _namespace_directory(save_namespace: Dictionary) -> String:
	return "user://save_v2/%s" % Codec.namespace_key(save_namespace)


func _current_path(save_namespace: Dictionary) -> String:
	return "%s/current.json" % _namespace_directory(save_namespace)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("Could not write test fixture: %s" % path)
		return
	file.store_string(JSON.stringify(value))
	file.flush()


func _sha256_bytes(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode()


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
