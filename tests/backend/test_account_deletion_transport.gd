extends SceneTree

## GAME-012 batch 1 coverage for the account-deletion DELETE path in
## scripts/backend/backend_transport.gd and its closed adapter
## scripts/backend/account_deletion_operations.gd (docs/ACCOUNT_DELETION_PLAN.md).
##
## The canonical v1.3 goldens are read from client copies under
## tests/fixtures/account_deletion_v1_3/, because the isolated runner copies the project into
## %TEMP% where res://../sorting-puzzle-backend does not resolve. When the sibling repository is
## reachable (default sibling path, or its root as the single user argument) the copies must match
## it exactly.
##
## Transport checks feed synthetic HTTPRequest outcomes through a subclass that overrides only the
## network seams, as tests/backend/test_game_007.gd does: request shape and stable replay identity,
## no refresh on 401, pre-send vs ambiguous transport failures, 429/5xx retries, settled version
## conflicts, key reuse, malformed acceptance, carried-over possible application, and binding
## checks that refuse to send.

const BackendTransportScript := preload("res://scripts/backend/backend_transport.gd")
const AccountDeletionOperationsScript := preload("res://scripts/backend/account_deletion_operations.gd")
const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")

const FIXTURE_DIRECTORY := "res://tests/fixtures/account_deletion_v1_3"
const SIBLING_FIXTURE_SUBPATH := "contracts/fixtures/v1.3"
const FIXTURE_FILES := ["account-deletion.request.json", "account-deletion.response.json"]

const TEST_PLAYER_ID := "00000000-0000-4000-8000-000000000001"
const TEST_DEVICE_ID := "00000000-0000-4000-8000-000000000002"
const TEST_SESSION_ID := "00000000-0000-4000-8000-0000000000a1"
const OTHER_UUID := "00000000-0000-4000-8000-0000000000ff"

var _failures := PackedStringArray()
var _created_transports := []
var _active_player_id := TEST_PLAYER_ID


class FakeSessionStore:
	extends RefCounted
	var session := {
		"session_id": TEST_SESSION_ID,
		"access_token": "original-access-token",
		"access_token_expires_at": "2026-10-02T12:05:00.000Z",
		"refresh_token": "original-refresh-token",
		"refresh_token_expires_at": "2026-11-02T12:00:00.000Z",
	}
	var device_id := TEST_DEVICE_ID
	var store_calls := []
	var load_ok := true

	func load_session(_player_id: String) -> Dictionary:
		return {"ok": load_ok, "session": session.duplicate(true)}

	func get_device_id() -> String:
		return device_id

	func store_session(player_id: String, new_session: Dictionary) -> Dictionary:
		store_calls.append({"player_id": player_id, "session": new_session.duplicate(true)})
		return {"ok": true}


class FakeTransport:
	extends BackendTransportScript
	var delete_queue := []
	var delete_calls := []
	var post_calls := []
	var get_calls := []
	var wait_calls := []

	func _send_delete(url: String, headers: PackedStringArray, body: String) -> Array:
		delete_calls.append({"url": url, "headers": headers, "body": body})
		if delete_queue.is_empty():
			return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
		var entry = delete_queue.pop_front()
		if entry is Callable:
			return (entry as Callable).call(url, headers, body)
		return entry

	func _send_post(url: String, headers: PackedStringArray, body: String) -> Array:
		post_calls.append({"url": url, "headers": headers, "body": body})
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]

	func _send_get(url: String, headers: PackedStringArray) -> Array:
		get_calls.append({"url": url, "headers": headers})
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]

	func _wait_before_retry(attempt: int, retry_after_seconds: int) -> void:
		wait_calls.append({"attempt": attempt, "retry_after_seconds": retry_after_seconds})


func _init() -> void:
	var original_url: String = ProjectSettings.get_setting("application/config/backend_base_url", "")
	ProjectSettings.set_setting("application/config/backend_base_url", "http://127.0.0.1:8080")

	_check_fixture_copies_match_sibling()
	_check_receipt_validation()
	_check_failure_reasons()
	await _check_fixture_round_trip()
	await _check_never_refreshes_on_401()
	await _check_ambiguous_failures_then_accepted_replay_same_identity()
	await _check_ambiguous_failure_then_401_is_unconfirmed()
	await _check_pre_send_failures_are_not_applied()
	await _check_ambiguous_failures_exhaust_to_unconfirmed()
	await _check_rate_limit_honors_retry_after()
	await _check_rate_limit_exhaustion_is_not_applied()
	await _check_server_errors()
	await _check_version_conflict_settles_and_rebuilds()
	await _check_key_reuse_is_unconfirmed()
	await _check_malformed_acceptance_is_unconfirmed()
	await _check_prior_possible_application_carries_over()
	await _check_definitive_rejections()
	await _check_binding_changes_refuse_to_send()
	await _check_invalid_operation_refuses_to_send()
	await _check_unavailable_backend()

	ProjectSettings.set_setting("application/config/backend_base_url", original_url)
	_finish()


func _finish() -> void:
	for transport in _created_transports:
		(transport as Node).free()
	if _failures.is_empty():
		print("GAME-012 account deletion transport/adapter tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# ---------------------------------------------------------------------------
# Fixtures and adapter
# ---------------------------------------------------------------------------

func _check_fixture_copies_match_sibling() -> void:
	var arguments := OS.get_cmdline_user_args()
	var backend_root := (
		str(arguments[0])
		if arguments.size() == 1
		else ProjectSettings.globalize_path("res://../sorting-puzzle-backend").simplify_path()
	)
	var sibling_directory := backend_root.path_join(SIBLING_FIXTURE_SUBPATH)
	if not DirAccess.dir_exists_absolute(sibling_directory):
		print("Sibling backend fixtures not reachable at %s; using the client copies only." % sibling_directory)
		return
	for file_name in FIXTURE_FILES:
		var client_copy = _parse_json_file(FIXTURE_DIRECTORY.path_join(file_name))
		var canonical = _parse_json_file(sibling_directory.path_join(file_name))
		_check(
			client_copy != null
			and canonical != null
			and LocalSaveCodecScript.canonical_json(client_copy) == LocalSaveCodecScript.canonical_json(canonical),
			"client copy of %s matches the backend golden" % file_name
		)


func _check_receipt_validation() -> void:
	var meta := {"state_version": 8}
	var base := _fixture_response_data()
	var receipt := AccountDeletionOperationsScript.parse_receipt(base, meta)
	_check(bool(receipt.get("ok", false)), "the golden deletion data parses")

	var unknown_status := base.duplicate(true)
	unknown_status["status"] = "cancelled"
	unknown_status["future_field"] = {"nested": true}
	var unknown_receipt := AccountDeletionOperationsScript.parse_receipt(unknown_status, meta)
	_check(bool(unknown_receipt.get("ok", false)), "an unrecognized status and additive field still parse")
	_check(str(unknown_receipt.get("status", "")) == "unknown", "an unrecognized status maps to unknown")
	_check(not unknown_receipt.has("future_field"), "additive response fields are not exposed")

	for entry in [
		{"key": "kind", "value": "export", "label": "a non-deletion kind"},
		{"key": "status", "value": 3, "label": "a non-string status"},
		{"key": "request_id", "value": "not-a-uuid", "label": "an invalid request_id"},
		{"key": "created_at", "value": "yesterday", "label": "an invalid created_at"},
	]:
		var invalid := base.duplicate(true)
		invalid[str(entry.get("key"))] = entry.get("value")
		_check(
			not bool(AccountDeletionOperationsScript.parse_receipt(invalid, meta).get("ok", true)),
			"%s is rejected" % str(entry.get("label"))
		)
	var missing_deadline := base.duplicate(true)
	missing_deadline.erase("complete_by")
	_check(
		not bool(AccountDeletionOperationsScript.parse_receipt(missing_deadline, meta).get("ok", true)),
		"a missing complete_by is rejected"
	)
	_check(
		not bool(AccountDeletionOperationsScript.parse_receipt(base, {}).get("ok", true)),
		"a missing state_version is rejected"
	)


func _check_failure_reasons() -> void:
	var cases := [
		[{"code": "backend.unavailable", "category": "dependency"}, "not_configured"],
		[{"code": "network.transport_failed", "category": "dependency"}, "offline"],
		[{"code": "rate_limit.exceeded", "category": "rate_limit", "http_status": 429}, "rate_limited"],
		[{"code": "client.unsupported", "category": "version", "http_status": 426}, "unsupported_client"],
		[{"code": "auth.invalid", "category": "authentication", "http_status": 401}, "authentication"],
		[{"code": "dependency.account_deletion_unavailable", "category": "dependency", "http_status": 503}, "temporarily_unavailable"],
		[{"code": "request.invalid", "category": "validation", "http_status": 400}, "failed"],
	]
	for entry in cases:
		var error := entry[0] as Dictionary
		_check(
			AccountDeletionOperationsScript.failure_reason(error) == str(entry[1]),
			"%s maps to the %s reason" % [str(error.get("code")), str(entry[1])]
		)


func _check_fixture_round_trip() -> void:
	var request_golden := _parse_json_file(FIXTURE_DIRECTORY.path_join("account-deletion.request.json")) as Dictionary
	var response_golden := _parse_json_file(FIXTURE_DIRECTORY.path_join("account-deletion.response.json")) as Dictionary
	var golden_meta := request_golden.get("meta", {}) as Dictionary
	var operation := _operation()
	operation["request_id"] = str(golden_meta.get("request_id", ""))
	operation["expected_state_version"] = int(golden_meta.get("expected_state_version", -1))
	var transport := _make_transport()
	transport.delete_queue = [_raw(202, response_golden)]
	var result: Dictionary = await _delete(transport, operation)
	_check(str(result.get("outcome", "")) == "accepted", "the golden 202 response is accepted")
	_check(bool(result.get("possibly_applied", false)), "an accepted deletion is marked as applied")

	var sent := _sent_body(transport, 0)
	var sent_meta := sent.get("meta", {}) as Dictionary
	var golden_keys := golden_meta.keys()
	var sent_keys := sent_meta.keys()
	golden_keys.sort()
	sent_keys.sort()
	_check(sent_keys == golden_keys, "the request meta has exactly the golden request's keys")
	_check(
		LocalSaveCodecScript.canonical_json(sent.get("data")) == LocalSaveCodecScript.canonical_json(request_golden.get("data")),
		"the request data matches the golden confirmation"
	)
	_check(str(sent_meta.get("protocol_version", "")) == "1.3", "the request selects protocol 1.3")
	_check(str(sent_meta.get("request_id", "")) == str(operation.get("request_id")), "the request uses the operation's request id")
	_check(
		int(sent_meta.get("expected_state_version", -1)) == int(operation.get("expected_state_version")),
		"the request carries the operation's expected state version"
	)
	_check(str(sent_meta.get("device_id", "")) == TEST_DEVICE_ID, "the request binds the installation device")
	_check(str(sent_meta.get("session_id", "")) == TEST_SESSION_ID, "the request binds the original session")

	var call := transport.delete_calls[0] as Dictionary
	_check(str(call.get("url", "")) == "http://127.0.0.1:8080/v1/player/account", "the request targets DELETE /v1/player/account")
	var headers := call.get("headers", PackedStringArray()) as PackedStringArray
	_check(headers.has("Authorization: Bearer original-access-token"), "the request uses the original access token")
	_check(
		headers.has("Idempotency-Key: %s" % str(operation.get("idempotency_key"))),
		"the request sends the operation's idempotency key"
	)
	_check(headers.has("Content-Type: application/json"), "the request declares a JSON body")

	var interpreted := AccountDeletionOperationsScript.interpret_result(result)
	var receipt := interpreted.get("receipt", {}) as Dictionary
	var golden_data := response_golden.get("data", {}) as Dictionary
	_check(str(interpreted.get("outcome", "")) == "accepted", "the adapter accepts the golden response")
	_check(str(receipt.get("request_id", "")) == str(golden_data.get("request_id")), "the receipt keeps the deletion request id")
	_check(str(receipt.get("status", "")) == "pending", "the receipt keeps the pending status")
	_check(str(receipt.get("complete_by", "")) == str(golden_data.get("complete_by")), "the receipt keeps complete_by")
	_check(int(receipt.get("state_version", -1)) == 8, "the receipt keeps the authoritative state version")


# ---------------------------------------------------------------------------
# Transport
# ---------------------------------------------------------------------------

func _check_never_refreshes_on_401() -> void:
	var session_store := FakeSessionStore.new()
	var transport := _make_transport(session_store)
	transport.delete_queue = [_error_raw(401, "auth.invalid", "authentication")]
	var result: Dictionary = await _delete(transport, _operation())
	_check(str(result.get("outcome", "")) == "rejected", "a first-attempt 401 settles the deletion as rejected")
	_check(not bool(result.get("possibly_applied", true)), "a first-attempt 401 was not applied")
	_check(transport.delete_calls.size() == 1, "a 401 is not replayed")
	_check(transport.post_calls.is_empty(), "a 401 never triggers a session refresh")
	_check(session_store.store_calls.is_empty(), "a 401 never rotates the stored session")


func _check_ambiguous_failures_then_accepted_replay_same_identity() -> void:
	var transport := _make_transport()
	var operation := _operation()
	transport.delete_queue = [
		_failure_raw(HTTPRequest.RESULT_TIMEOUT),
		_failure_raw(HTTPRequest.RESULT_CONNECTION_ERROR),
		_accepted_echo(),
	]
	var result: Dictionary = await _delete(transport, operation)
	_check(str(result.get("outcome", "")) == "accepted", "ambiguous failures retry until accepted")
	_check(transport.delete_calls.size() == 3, "the replay issues exactly three DELETEs")
	_check(transport.wait_calls.size() == 2, "the replay waits between attempts")
	for index in range(transport.delete_calls.size()):
		var meta := _sent_body(transport, index).get("meta", {}) as Dictionary
		var headers := (transport.delete_calls[index] as Dictionary).get("headers", PackedStringArray()) as PackedStringArray
		_check(
			str(meta.get("request_id", "")) == str(operation.get("request_id"))
			and int(meta.get("expected_state_version", -1)) == int(operation.get("expected_state_version"))
			and headers.has("Idempotency-Key: %s" % str(operation.get("idempotency_key"))),
			"attempt %d replays the same request id, state version, and key" % (index + 1)
		)


func _check_ambiguous_failure_then_401_is_unconfirmed() -> void:
	var transport := _make_transport()
	transport.delete_queue = [
		_failure_raw(HTTPRequest.RESULT_TIMEOUT),
		_error_raw(401, "auth.invalid", "authentication"),
	]
	var result: Dictionary = await _delete(transport, _operation())
	_check(str(result.get("outcome", "")) == "unconfirmed", "a 401 after a possibly applied attempt is unconfirmed")
	_check(bool(result.get("possibly_applied", false)), "the timeout is recorded as possibly applied")
	_check(transport.post_calls.is_empty(), "an unconfirmed deletion never refreshes")


func _check_pre_send_failures_are_not_applied() -> void:
	var transport := _make_transport()
	transport.delete_queue = [
		_failure_raw(HTTPRequest.RESULT_CANT_RESOLVE),
		_failure_raw(HTTPRequest.RESULT_CANT_CONNECT),
		_failure_raw(HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR),
		_failure_raw(HTTPRequest.RESULT_CANT_CONNECT),
		_failure_raw(HTTPRequest.RESULT_CANT_CONNECT),
	]
	var result: Dictionary = await _delete(transport, _operation())
	_check(str(result.get("outcome", "")) == "not_applied", "failures before sending leave the deletion not applied")
	_check(not bool(result.get("possibly_applied", true)), "failures before sending are never possibly applied")
	_check(transport.delete_calls.size() == 5, "the mutation retry budget is one try plus four retries")
	var interpreted := AccountDeletionOperationsScript.interpret_result(result)
	_check(str(interpreted.get("reason", "")) == "offline", "failures before sending are reported as offline")


func _check_ambiguous_failures_exhaust_to_unconfirmed() -> void:
	var transport := _make_transport()
	transport.delete_queue = [
		_failure_raw(HTTPRequest.RESULT_CANT_CONNECT),
		_failure_raw(HTTPRequest.RESULT_TIMEOUT),
		_failure_raw(HTTPRequest.RESULT_CANT_CONNECT),
		_failure_raw(HTTPRequest.RESULT_CANT_CONNECT),
		_failure_raw(HTTPRequest.RESULT_CANT_CONNECT),
	]
	var result: Dictionary = await _delete(transport, _operation())
	_check(str(result.get("outcome", "")) == "unconfirmed", "one possibly delivered attempt makes exhaustion unconfirmed")


func _check_rate_limit_honors_retry_after() -> void:
	var transport := _make_transport()
	transport.delete_queue = [
		_error_raw(429, "rate_limit.exceeded", "rate_limit", PackedStringArray(["Retry-After: 7"])),
		_accepted_echo(),
	]
	var result: Dictionary = await _delete(transport, _operation())
	_check(str(result.get("outcome", "")) == "accepted", "a 429 retries and is then accepted")
	_check(
		transport.wait_calls.size() == 1 and int((transport.wait_calls[0] as Dictionary).get("retry_after_seconds", -1)) == 7,
		"a 429 honors Retry-After"
	)


func _check_rate_limit_exhaustion_is_not_applied() -> void:
	var transport := _make_transport()
	for index in range(5):
		transport.delete_queue.append(_error_raw(429, "rate_limit.exceeded", "rate_limit"))
	var result: Dictionary = await _delete(transport, _operation())
	_check(str(result.get("outcome", "")) == "not_applied", "rate-limited attempts were never applied")
	_check(
		str(AccountDeletionOperationsScript.interpret_result(result).get("reason", "")) == "rate_limited",
		"rate-limit exhaustion is reported as rate limited"
	)


func _check_server_errors() -> void:
	var retried := _make_transport()
	retried.delete_queue = [_error_raw(500, "internal.unexpected", "internal"), _accepted_echo()]
	var retried_result: Dictionary = await _delete(retried, _operation())
	_check(str(retried_result.get("outcome", "")) == "accepted", "a 500 is retried under the same key")

	for code in [502, 503, 504]:
		var transport := _make_transport()
		for index in range(5):
			transport.delete_queue.append(_error_raw(code, "dependency.unavailable", "dependency"))
		var result: Dictionary = await _delete(transport, _operation())
		_check(str(result.get("outcome", "")) == "unconfirmed", "%d exhaustion leaves the deletion unconfirmed" % code)
		_check(transport.delete_calls.size() == 5, "%d is retried within the mutation budget" % code)


func _check_version_conflict_settles_and_rebuilds() -> void:
	var transport := _make_transport()
	var operation := _operation()
	transport.delete_queue = [
		_failure_raw(HTTPRequest.RESULT_TIMEOUT),
		_error_raw(409, "state.version_conflict", "conflict", PackedStringArray(), {
			"action": "refresh_state",
			"current_state_version": 12,
		}),
	]
	var result: Dictionary = await _delete(transport, operation)
	_check(str(result.get("outcome", "")) == "rejected", "a version conflict settles the operation")
	_check(not bool(result.get("possibly_applied", true)), "a version conflict proves the key was not applied")
	var interpreted := AccountDeletionOperationsScript.interpret_result(result)
	_check(str(interpreted.get("outcome", "")) == "version_conflict", "the adapter reports a version conflict")
	_check(int(interpreted.get("current_state_version", -1)) == 12, "the conflict exposes the recovery state version")

	var rebuilt := AccountDeletionOperationsScript.rebuild_after_version_conflict(operation, 12)
	_check(int(rebuilt.get("expected_state_version", -1)) == 12, "the rebuilt operation uses the recovery version")
	_check(
		str(rebuilt.get("idempotency_key", "")) != str(operation.get("idempotency_key"))
		and LocalSaveCodecScript.is_uuid(rebuilt.get("idempotency_key")),
		"the rebuilt operation uses a new idempotency key"
	)
	_check(str(rebuilt.get("request_id", "")) != str(operation.get("request_id")), "the rebuilt operation uses a new request id")
	_check(
		str(rebuilt.get("player_id", "")) == TEST_PLAYER_ID
		and str(rebuilt.get("device_id", "")) == TEST_DEVICE_ID
		and str(rebuilt.get("session_id", "")) == TEST_SESSION_ID,
		"the rebuilt operation keeps the session binding"
	)
	_check(not bool(rebuilt.get("possibly_applied", true)), "the rebuilt operation starts unsent")

	var missing_recovery := _make_transport()
	missing_recovery.delete_queue = [_error_raw(409, "state.version_conflict", "conflict")]
	var missing_result := AccountDeletionOperationsScript.interpret_result(await _delete(missing_recovery, _operation()))
	_check(int(missing_result.get("current_state_version", 0)) == -1, "a conflict without recovery reports -1")


func _check_key_reuse_is_unconfirmed() -> void:
	var transport := _make_transport()
	transport.delete_queue = [_error_raw(409, "idempotency.key_reused", "conflict")]
	var result: Dictionary = await _delete(transport, _operation())
	_check(str(result.get("outcome", "")) == "unconfirmed", "a reused idempotency key settles nothing")


func _check_malformed_acceptance_is_unconfirmed() -> void:
	var mismatched := _make_transport()
	var response := _fixture_response_envelope()
	(response.get("meta") as Dictionary)["request_id"] = OTHER_UUID
	mismatched.delete_queue = [_raw(202, response)]
	var mismatched_result: Dictionary = await _delete(mismatched, _operation())
	_check(str(mismatched_result.get("outcome", "")) == "unconfirmed", "a 202 echoing another request id is unconfirmed")
	_check(mismatched.delete_calls.size() == 1, "a malformed 202 is not replayed automatically")

	var wrong_status := _make_transport()
	wrong_status.delete_queue = [_accepted_echo(200)]
	var wrong_status_result: Dictionary = await _delete(wrong_status, _operation())
	_check(str(wrong_status_result.get("outcome", "")) == "unconfirmed", "a 200 instead of 202 is unconfirmed")

	var bad_data := _make_transport()
	bad_data.delete_queue = [_accepted_echo(202, {"kind": "export"})]
	var bad_data_result := AccountDeletionOperationsScript.interpret_result(await _delete(bad_data, _operation()))
	_check(str(bad_data_result.get("outcome", "")) == "unconfirmed", "an accepted envelope with invalid data is unconfirmed")
	_check(bool(bad_data_result.get("possibly_applied", false)), "invalid accepted data is still possibly applied")


func _check_prior_possible_application_carries_over() -> void:
	for entry in [
		{"code": 401, "error_code": "auth.invalid", "category": "authentication"},
		{"code": 400, "error_code": "request.invalid", "category": "validation"},
	]:
		var transport := _make_transport()
		var operation := _operation()
		operation["possibly_applied"] = true
		transport.delete_queue = [
			_error_raw(int(entry.get("code")), str(entry.get("error_code")), str(entry.get("category"))),
		]
		var result: Dictionary = await _delete(transport, operation)
		_check(
			str(result.get("outcome", "")) == "unconfirmed",
			"a %d after an earlier possibly applied call is unconfirmed" % int(entry.get("code"))
		)

	var settled := _make_transport()
	var settled_operation := _operation()
	settled_operation["possibly_applied"] = true
	settled.delete_queue = [_error_raw(409, "state.version_conflict", "conflict")]
	var settled_result: Dictionary = await _delete(settled, settled_operation)
	_check(str(settled_result.get("outcome", "")) == "rejected", "a version conflict settles even an earlier possibly applied call")


func _check_definitive_rejections() -> void:
	for entry in [
		{"code": 400, "error_code": "request.invalid", "category": "validation", "reason": "failed"},
		{"code": 403, "error_code": "access.denied", "category": "authorization", "reason": "failed"},
		{"code": 426, "error_code": "client.unsupported", "category": "version", "reason": "unsupported_client"},
	]:
		var transport := _make_transport()
		transport.delete_queue = [
			_error_raw(int(entry.get("code")), str(entry.get("error_code")), str(entry.get("category"))),
		]
		var result: Dictionary = await _delete(transport, _operation())
		var interpreted := AccountDeletionOperationsScript.interpret_result(result)
		_check(str(interpreted.get("outcome", "")) == "rejected", "a first-attempt %d is rejected" % int(entry.get("code")))
		_check(
			str(interpreted.get("reason", "")) == str(entry.get("reason")),
			"a %d maps to the %s reason" % [int(entry.get("code")), str(entry.get("reason"))]
		)
		_check(transport.delete_calls.size() == 1, "a %d is not retried" % int(entry.get("code")))


func _check_binding_changes_refuse_to_send() -> void:
	var rotated_store := FakeSessionStore.new()
	rotated_store.session["session_id"] = OTHER_UUID
	var rotated := _make_transport(rotated_store)
	var rotated_result: Dictionary = await _delete(rotated, _operation())
	_check(rotated.delete_calls.is_empty(), "a rotated session never sends the deletion")
	_check(str(rotated_result.get("outcome", "")) == "not_applied", "an unsent operation is not applied")
	_check(
		str((rotated_result.get("error", {}) as Dictionary).get("code", "")) == "auth.binding_changed",
		"a rotated session reports auth.binding_changed"
	)

	var after_send := _make_transport(rotated_store)
	var after_send_operation := _operation()
	after_send_operation["possibly_applied"] = true
	var after_send_result: Dictionary = await _delete(after_send, after_send_operation)
	_check(
		str(after_send_result.get("outcome", "")) == "unconfirmed",
		"losing the original session after a possibly applied call is unconfirmed"
	)

	var other_device_store := FakeSessionStore.new()
	other_device_store.device_id = OTHER_UUID
	var other_device := _make_transport(other_device_store)
	await _delete(other_device, _operation())
	_check(other_device.delete_calls.is_empty(), "a changed device identity never sends the deletion")

	_active_player_id = OTHER_UUID
	var other_player := _make_transport()
	await _delete(other_player, _operation())
	_active_player_id = TEST_PLAYER_ID
	_check(other_player.delete_calls.is_empty(), "a different active player never sends the deletion")

	var missing_store := FakeSessionStore.new()
	missing_store.load_ok = false
	var missing := _make_transport(missing_store)
	var missing_result: Dictionary = await _delete(missing, _operation())
	_check(missing.delete_calls.is_empty(), "a missing session never sends the deletion")
	_check(
		str((missing_result.get("error", {}) as Dictionary).get("code", "")) == "auth.session_missing",
		"a missing session reports auth.session_missing"
	)


func _check_invalid_operation_refuses_to_send() -> void:
	for entry in [
		{"key": "idempotency_key", "value": "", "label": "a missing idempotency key"},
		{"key": "request_id", "value": "not-a-uuid", "label": "an invalid request id"},
		{"key": "expected_state_version", "value": -1, "label": "a negative state version"},
	]:
		var transport := _make_transport()
		var operation := _operation()
		operation[str(entry.get("key"))] = entry.get("value")
		var result: Dictionary = await _delete(transport, operation)
		_check(transport.delete_calls.is_empty(), "%s is never sent" % str(entry.get("label")))
		_check(
			str((result.get("error", {}) as Dictionary).get("code", "")) == "request.operation_invalid",
			"%s reports request.operation_invalid" % str(entry.get("label"))
		)


func _check_unavailable_backend() -> void:
	var transport := _make_transport()
	ProjectSettings.set_setting("application/config/backend_base_url", "")
	var result: Dictionary = await _delete(transport, _operation())
	ProjectSettings.set_setting("application/config/backend_base_url", "http://127.0.0.1:8080")
	_check(transport.delete_calls.is_empty(), "an unconfigured backend never sends the deletion")
	_check(str(result.get("outcome", "")) == "not_applied", "an unconfigured backend leaves the deletion not applied")
	_check(
		str(AccountDeletionOperationsScript.interpret_result(result).get("reason", "")) == "not_configured",
		"an unconfigured backend is reported as not configured"
	)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_transport(session_store: FakeSessionStore = null) -> FakeTransport:
	var transport := FakeTransport.new()
	transport.configure(
		session_store if session_store != null else FakeSessionStore.new(),
		func(): return _active_player_id
	)
	_created_transports.append(transport)
	return transport


func _operation() -> Dictionary:
	return AccountDeletionOperationsScript.create_operation(
		TEST_PLAYER_ID,
		TEST_DEVICE_ID,
		TEST_SESSION_ID,
		7
	)


func _delete(transport: FakeTransport, operation: Dictionary) -> Dictionary:
	return await transport.delete_json(
		AccountDeletionOperationsScript.PATH,
		AccountDeletionOperationsScript.PROTOCOL_VERSION,
		AccountDeletionOperationsScript.request_data(),
		operation
	)


func _sent_body(transport: FakeTransport, index: int) -> Dictionary:
	var parsed = JSON.parse_string(str((transport.delete_calls[index] as Dictionary).get("body", "")))
	return parsed as Dictionary if parsed is Dictionary else {}


func _fixture_response_envelope() -> Dictionary:
	var parsed = _parse_json_file(FIXTURE_DIRECTORY.path_join("account-deletion.response.json"))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _fixture_response_data() -> Dictionary:
	return (_fixture_response_envelope().get("data", {}) as Dictionary).duplicate(true)


## A golden 202 response built lazily from the outgoing request, so it echoes the request id the
## transport actually sent.
func _accepted_echo(status: int = 202, data_overrides: Dictionary = {}) -> Callable:
	return func(_url: String, _headers: PackedStringArray, body: String) -> Array:
		var sent := JSON.parse_string(body) as Dictionary
		var envelope := _fixture_response_envelope()
		(envelope.get("meta") as Dictionary)["request_id"] = str((sent.get("meta", {}) as Dictionary).get("request_id", ""))
		(envelope.get("data") as Dictionary).merge(data_overrides, true)
		return _raw(status, envelope)


func _raw(status: int, envelope: Dictionary, headers: PackedStringArray = PackedStringArray()) -> Array:
	return [HTTPRequest.RESULT_SUCCESS, status, headers, JSON.stringify(envelope).to_utf8_buffer()]


func _failure_raw(result_code: int) -> Array:
	return [result_code, 0, PackedStringArray(), PackedByteArray()]


func _error_raw(
	status: int,
	code: String,
	category: String,
	headers: PackedStringArray = PackedStringArray(),
	recovery: Dictionary = {}
) -> Array:
	var error := {
		"code": code,
		"category": category,
		"message": "synthetic test error",
		"retryable": status == 429 or status >= 500,
	}
	if not recovery.is_empty():
		error["recovery"] = recovery
	return _raw(status, {
		"meta": {
			"protocol_version": "1.3",
			"request_id": OTHER_UUID,
			"correlation_id": "00000000-0000-4000-8000-0000000000c2",
			"server_time": "2026-10-02T12:00:00.000Z",
		},
		"error": error,
	}, headers)


func _parse_json_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("FAILED: could not open %s" % path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_failures.append("FAILED: %s is not a JSON object" % path)
		return null
	return parsed


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
