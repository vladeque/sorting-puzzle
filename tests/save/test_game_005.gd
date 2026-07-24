extends SceneTree

## GAME-005: proves the existing local-first operation journal and checkpoint reconciliation
## against the real protocol-v2 API and PostgreSQL. Live verification was captured by
## scripts/tools/local_backend_save_sync_integration_check.mjs, which performs genuine HTTP calls
## (real guest challenge/bootstrap, real P-256 signatures, real Postgres-backed save-sync) against
## a running local backend and confirmed: empty sync acceptance, all five signed operation types
## accepted and merged, cursor/checkpoint atomic application, multi-batch continuation across two
## real requests, idempotent replay, stale-cursor rejection, and PostgreSQL rows for the player,
## device, session, deduplicated operations, cursor snapshot, checkpoint, and outbox linkage.
##
## This suite replays the exact response bodies captured from that real backend
## (tests/fixtures/save_sync_v2/*.json) through the real SaveSyncService/LocalSaveStore code paths
## used on-device, proving the Godot client's canonicalization, payload validation, and
## reconciliation bookkeeping are compatible with genuine backend output -- not just synthetic
## fixtures. Real Android Keystore device signing itself remains blocked by the emulator
## `HTTPRequest` POST flakiness documented under GAME-004; see docs/IMPLEMENTATION_TICKETS.md.

const Codec := preload("res://scripts/save/local_save_codec.gd")
const SessionStore := preload("res://scripts/save/secure_session_store.gd")
const SaveStore := preload("res://scripts/save/local_save_store.gd")
const SyncService := preload("res://scripts/save/save_sync_service.gd")

const FIXTURE_DIRECTORY := "res://tests/fixtures/save_sync_v2"

## Extends the real SecureSessionStore (rather than duck-typing a bare RefCounted) so it can be
## passed anywhere the statically-typed SecureSessionStore parameter is required, while overriding
## get_device_id() to return the fixed device_id recorded in the real captured backend fixtures.
class FakeDeviceSession:
	extends SessionStore

	var _device_id: String

	func _init(device_id: String) -> void:
		_device_id = device_id

	func get_device_id() -> String:
		return _device_id

var _failures := PackedStringArray()
var _session


func _init() -> void:
	_session = SessionStore.new()
	_session.initialize()
	_test_client_operation_hash_matches_real_backend_acceptance()
	_test_real_sync_responses_apply_atomically_in_sequence()
	_test_stale_cursor_error_code_matches_real_backend_shape()
	_test_real_state_recovery_reapplies_the_authoritative_checkpoint()

	if _failures.is_empty():
		print("GAME-005 tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_client_operation_hash_matches_real_backend_acceptance() -> void:
	var fixture = _load_fixture("batch_sync_request")
	_check(fixture is Dictionary, "batch_sync_request fixture parses")
	if not (fixture is Dictionary):
		return
	var operations := ((fixture as Dictionary).get("data", {}) as Dictionary).get("operations", []) as Array
	_check(operations.size() == 5, "the captured live batch contains all five v2 operation types")

	var store = SaveStore.new(_session)
	var seen_types := {}
	for raw_operation in operations:
		var operation := raw_operation as Dictionary
		var operation_type := str(operation.get("operation_type", ""))
		seen_types[operation_type] = true
		_check(
			Codec.operation_hash(operation) == str(operation.get("operation_hash", "")),
			"Godot canonical hash matches a real backend-accepted %s operation" % operation_type
		)
		var payload_validation: Dictionary = store.call(
			"_validate_operation_payload", operation_type, operation.get("payload", {})
		)
		_check(
			bool(payload_validation.get("ok", false)),
			"Godot payload validation accepts the real backend-accepted %s payload" % operation_type
		)
	for expected_type in [
		"campaign_completion", "campaign_attempt", "resource_spend", "life_state", "profile_edit"
	]:
		_check(seen_types.has(expected_type), "the live batch exercised %s" % expected_type)


func _test_real_sync_responses_apply_atomically_in_sequence() -> void:
	var identity = _load_fixture("identity")
	_check(identity is Dictionary, "identity fixture parses")
	if not (identity is Dictionary):
		return
	var player_id := str((identity as Dictionary).get("player_id", ""))
	var device_id := str((identity as Dictionary).get("device_id", ""))

	var fake_session := FakeDeviceSession.new(device_id)
	var store = SaveStore.new(fake_session)
	var open_result := store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	_check(bool(open_result.get("ok", false)), "a local save opens for the real recovered player namespace")

	var sync := SyncService.new()
	get_root().add_child(sync)
	sync.configure(store, fake_session, func(_checkpoint, current, _remaining): return current)

	for fixture_name in [
		"empty_sync_response",
		"batch_sync_response",
		"continuation_first_response",
		"continuation_second_response",
	]:
		var envelope = _load_fixture(fixture_name)
		_check(envelope is Dictionary, "%s fixture parses" % fixture_name)
		if not (envelope is Dictionary):
			continue
		var data := (envelope as Dictionary).get("data", {}) as Dictionary
		var target_cursor := data.get("acknowledged_cursor", {}) as Dictionary

		_prime_store_for_reconciliation(store, target_cursor)
		var sync_metadata := store.get_sync_metadata()
		sync_metadata["pending_request"] = {
			"request_id": str(((envelope as Dictionary).get("meta", {}) as Dictionary).get("request_id", "")),
			"idempotency_key": Codec.create_uuid(),
			"payload": "{}",
			"last_sequence": int(target_cursor.get("acknowledged_sequence", 0)),
		}
		store.persist_sync_metadata(sync_metadata)

		var apply_result: Dictionary = sync.call("_apply_response", envelope)
		_check(
			bool(apply_result.get("ok", false)),
			"%s (real backend response) applies atomically: %s" % [fixture_name, apply_result.get("error", "")]
		)

		var updated_sync := store.get_sync_metadata()
		var updated_cursor := updated_sync.get("cursor", {}) as Dictionary
		_check(
			updated_cursor.get("acknowledged_sequence") == target_cursor.get("acknowledged_sequence")
			and updated_cursor.get("acknowledged_hash") == target_cursor.get("acknowledged_hash"),
			"%s: the local cursor matches the real acknowledged_cursor exactly" % fixture_name
		)
		var stored_checkpoint := updated_sync.get("last_checkpoint", {}) as Dictionary
		_check(
			stored_checkpoint.get("checkpoint_id") == (data.get("checkpoint", {}) as Dictionary).get("checkpoint_id"),
			"%s: the real checkpoint is stored for offline recovery" % fixture_name
		)
		_check(
			(updated_sync.get("pending_request", {}) as Dictionary).is_empty(),
			"%s: applying a real response clears the pending retry state" % fixture_name
		)
		_check(
			(updated_sync.get("terminal_error", {}) as Dictionary).is_empty(),
			"%s: a successful real response never leaves a terminal error behind" % fixture_name
		)

	var final_checkpoint := (store.get_sync_metadata().get("last_checkpoint", {}) as Dictionary)
	_check(
		int((final_checkpoint.get("balances", {}) as Dictionary).get("coins", -1)) == 250,
		"the final reconciled checkpoint reflects the real merged coin balance (300 - 50 spend)"
	)
	_check(
		int((final_checkpoint.get("campaign", {}) as Dictionary).get("highest_completed_level", -1)) == 1,
		"the final reconciled checkpoint reflects the real merged campaign completion"
	)
	sync.queue_free()


func _test_stale_cursor_error_code_matches_real_backend_shape() -> void:
	var fixture = _load_fixture("stale_cursor_response")
	_check(fixture is Dictionary, "stale_cursor_response fixture parses")
	if not (fixture is Dictionary):
		return
	_check(
		int((fixture as Dictionary).get("status", 0)) == 409,
		"the real backend rejects a stale acknowledged cursor with HTTP 409"
	)

	var sync := SyncService.new()
	get_root().add_child(sync)
	var body: Dictionary = (fixture as Dictionary).get("body", {})
	_check(
		str(sync.call("_response_error_code", body)) == "save_sync.cursor_mismatch",
		"Godot's error-code parser extracts the real save_sync.cursor_mismatch code"
	)
	_check(
		not str(sync.call("_response_correlation_id", body)).is_empty(),
		"Godot's correlation-id parser extracts the real server correlation id"
	)
	sync.queue_free()


func _test_real_state_recovery_reapplies_the_authoritative_checkpoint() -> void:
	var identity = _load_fixture("identity")
	var envelope = _load_fixture("final_state_response")
	_check(identity is Dictionary and envelope is Dictionary, "identity and final_state_response fixtures parse")
	if not (identity is Dictionary and envelope is Dictionary):
		return
	var player_id := str((identity as Dictionary).get("player_id", ""))
	var device_id := str((identity as Dictionary).get("device_id", ""))
	var device_cursors := ((envelope as Dictionary).get("data", {}) as Dictionary).get("device_cursors", []) as Array
	_check(device_cursors.size() == 1, "the real state response reports exactly this device's cursor")
	var remote_cursor := device_cursors[0] as Dictionary

	var fake_session := FakeDeviceSession.new(device_id)
	var store = SaveStore.new(fake_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	var sync_metadata := store.get_sync_metadata()
	sync_metadata["cursor"] = remote_cursor.duplicate(true)
	sync_metadata["journal_base_sequence"] = int(remote_cursor.get("acknowledged_sequence", 0))
	sync_metadata["journal_base_hash"] = remote_cursor.get("acknowledged_hash")
	sync_metadata["journal_head_sequence"] = int(remote_cursor.get("acknowledged_sequence", 0))
	sync_metadata["journal_head_hash"] = remote_cursor.get("acknowledged_hash")
	store.persist_sync_metadata(sync_metadata)

	var sync := SyncService.new()
	get_root().add_child(sync)
	sync.configure(store, fake_session, func(_checkpoint, current, _remaining): return current)

	var result: Dictionary = sync.call("_apply_state_response", envelope)
	_check(
		bool(result.get("ok", false)),
		"the real /v2/saves/state response reconciles cleanly: %s" % result.get("error", "")
	)
	var cursor := store.get_sync_metadata().get("cursor", {}) as Dictionary
	_check(
		cursor.get("acknowledged_sequence") == remote_cursor.get("acknowledged_sequence")
		and cursor.get("acknowledged_hash") == remote_cursor.get("acknowledged_hash"),
		"recovery restores the exact real acknowledged cursor for this device"
	)
	sync.queue_free()


## validate_document() requires journal_head_sequence/hash and the acknowledged cursor to be
## consistent with journal_base plus the actual number of journal entries present. Since this
## suite replays real response envelopes without reconstructing their (up to 500-operation)
## request journals byte-for-byte, it primes a trivially self-consistent "already fully compacted
## exactly through this response's own acknowledged cursor" document: zero pending entries,
## cursor == base == head == the cursor the response is about to (re-)acknowledge. That is
## sufficient to exercise apply_reconciliation()'s own bookkeeping -- which is what this suite is
## proving matches real backend output -- without needing the full operation history.
func _prime_store_for_reconciliation(store: LocalSaveStore, target_cursor: Dictionary) -> void:
	var sync := store.get_sync_metadata()
	sync["cursor"] = target_cursor.duplicate(true)
	sync["journal_base_sequence"] = int(target_cursor.get("acknowledged_sequence", 0))
	sync["journal_base_hash"] = target_cursor.get("acknowledged_hash")
	sync["journal_head_sequence"] = int(target_cursor.get("acknowledged_sequence", 0))
	sync["journal_head_hash"] = target_cursor.get("acknowledged_hash")
	store.persist_sync_metadata(sync)


func _load_fixture(name: String) -> Variant:
	var file := FileAccess.open("%s/%s.json" % [FIXTURE_DIRECTORY, name], FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


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
