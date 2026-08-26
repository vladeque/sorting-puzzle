extends SceneTree

## GAME-007 coverage for the shared authenticated read transport (scripts/backend/backend_transport.gd)
## and its closed protocol adapters (scripts/backend/backend_read_operations.gd).
##
## Two kinds of checks:
## 1. Fixture-driven adapter checks that feed the real backend contract fixtures from the sibling
##    ../sorting-puzzle-backend repository straight into BackendReadOperations.parse_*(), proving
##    the shared v1 success/error fixtures parse in Godot (the ticket's acceptance criterion) and
##    that unrecognized enum values are conservatively mapped to "unknown".
## 2. Transport-level checks that feed BackendTransport synthetic HTTPRequest outcomes through a
##    subclass overriding only the network-issuing seams (_send_get/_send_post/_wait_before_retry),
##    the same test-double pattern tests/save/test_game_006.gd uses for SaveSyncService: network
##    failure classification and retry-until-success, 429 Retry-After handling, terminal 4xx/5xx
##    handling, a full 401 -> refresh -> replay round trip, refresh-token-reuse/malformed-refresh
##    handling, and retry-budget exhaustion.

const BackendTransportScript := preload("res://scripts/backend/backend_transport.gd")
const BackendReadOperationsScript := preload("res://scripts/backend/backend_read_operations.gd")

const TEST_PLAYER_ID := "00000000-0000-4000-8000-000000000001"
const TEST_DEVICE_ID := "00000000-0000-4000-8000-000000000002"

var _failures := PackedStringArray()
var _fixtures_root := ""
var _created_transports := []


class FakeSessionStore:
	extends RefCounted
	var session := {
		"session_id": "00000000-0000-4000-8000-0000000000a1",
		"access_token": "initial-access-token",
		"access_token_expires_at": "2026-07-14T09:05:00.000Z",
		"refresh_token": "initial-refresh-token",
		"refresh_token_expires_at": "2026-08-14T09:00:00.000Z",
	}
	var store_calls := []
	var load_ok := true

	func load_session(_player_id: String) -> Dictionary:
		return {"ok": load_ok, "session": session.duplicate(true)}

	func get_device_id() -> String:
		return TEST_DEVICE_ID

	func store_session(player_id: String, new_session: Dictionary) -> Dictionary:
		store_calls.append({"player_id": player_id, "session": new_session.duplicate(true)})
		session = new_session.duplicate(true)
		return {"ok": true}


class FakeTransport:
	extends BackendTransportScript
	var get_queue := []
	var post_queue := []
	var get_calls := []
	var post_calls := []
	var wait_calls := []

	func _send_get(url: String, headers: PackedStringArray) -> Array:
		get_calls.append({"url": url, "headers": headers})
		if get_queue.is_empty():
			return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
		return get_queue.pop_front()

	func _send_post(url: String, headers: PackedStringArray, body: String) -> Array:
		post_calls.append({"url": url, "headers": headers, "body": body})
		if post_queue.is_empty():
			return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
		var entry = post_queue.pop_front()
		if entry is Callable:
			return (entry as Callable).call(url, headers, body)
		return entry

	func _wait_before_retry(attempt: int, retry_after_seconds: int) -> void:
		wait_calls.append({"attempt": attempt, "retry_after_seconds": retry_after_seconds})


func _init() -> void:
	_fixtures_root = ProjectSettings.globalize_path("res://").path_join(
		"../sorting-puzzle-backend/contracts/fixtures"
	).simplify_path()

	_run_adapter_fixture_tests()
	await _run_transport_tests()
	_finish()


func _finish() -> void:
	for transport in _created_transports:
		(transport as Node).free()
	if _failures.is_empty():
		print("GAME-007 backend transport/read-operation tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# ---------------------------------------------------------------------------
# Fixture-driven adapter checks
# ---------------------------------------------------------------------------

func _run_adapter_fixture_tests() -> void:
	_check_player_state_fixture()
	_check_player_devices_fixture()
	_check_catalog_fixture()
	_check_purchase_fixture()
	_check_purchase_refunded_fixture()
	_check_leaderboard_fixture()
	_check_error_fixtures()
	_check_unknown_enum_mapping()


func _check_player_state_fixture() -> void:
	var envelope = _load_fixture("v1/success/player-state.response.json")
	if envelope == null:
		return
	var result := BackendReadOperationsScript.parse_player_state((envelope as Dictionary).get("data"))
	_check(bool(result.get("ok", false)), "player-state fixture parses")
	_check(str(result.get("player_id", "")) == "00000000-0000-4000-8000-000000000001", "player-state player_id")
	_check(str(result.get("account_kind", "")) == "platform_verified", "player-state account_kind")
	_check(int((result.get("campaign") as Dictionary).get("current_level", -1)) == 4, "player-state campaign.current_level")
	_check(int((result.get("balances") as Dictionary).get("coins", -1)) == 525, "player-state balances.coins")
	_check(
		str((result.get("purchase_restriction") as Dictionary).get("status", "")) == "none",
		"player-state purchase_restriction.status"
	)
	_check(
		str((result.get("profile") as Dictionary).get("moderation_state", "")) == "active",
		"player-state profile.moderation_state"
	)
	_check(
		str((result.get("profile") as Dictionary).get("avatar_id", "")) == "avatar_cat",
		"player-state profile.avatar_id"
	)
	_check(
		str((result.get("profile") as Dictionary).get("avatar_frame_id", "")) == "frame_classic",
		"player-state profile.avatar_frame_id"
	)


func _check_player_devices_fixture() -> void:
	var envelope = _load_fixture("v1/success/player-devices.response.json")
	if envelope == null:
		return
	var result := BackendReadOperationsScript.parse_player_devices((envelope as Dictionary).get("data"))
	_check(bool(result.get("ok", false)), "player-devices fixture parses")
	var devices := result.get("devices", []) as Array
	_check(devices.size() == 2, "player-devices returns two devices")
	if devices.size() == 2:
		_check(str((devices[0] as Dictionary).get("platform", "")) == "android", "player-devices[0].platform")
		_check(bool((devices[0] as Dictionary).get("current", false)) == true, "player-devices[0].current")
		_check(str((devices[1] as Dictionary).get("platform", "")) == "ios", "player-devices[1].platform")


func _check_catalog_fixture() -> void:
	var envelope = _load_fixture("v1/success/catalog.response.json")
	if envelope == null:
		return
	var result := BackendReadOperationsScript.parse_catalog((envelope as Dictionary).get("data"))
	_check(bool(result.get("ok", false)), "catalog fixture parses")
	_check(str(result.get("catalog_version", "")) == "catalog-2026-07-14", "catalog.catalog_version")
	var offers := result.get("offers", []) as Array
	_check(offers.size() == 1, "catalog returns one offer")
	if offers.size() == 1:
		var offer := offers[0] as Dictionary
		_check(str(offer.get("type", "")) == "starter", "catalog offer type")
		_check(str(offer.get("limit_period", "")) == "lifetime", "catalog offer limit_period")
		_check(bool(offer.get("eligible", false)) == true, "catalog offer eligible")
		_check(int((offer.get("rewards") as Dictionary).get("coins", -1)) == 1000, "catalog offer rewards.coins")


func _check_purchase_fixture() -> void:
	var envelope = _load_fixture("v1/success/purchase.response.json")
	if envelope == null:
		return
	var result := BackendReadOperationsScript.parse_purchase((envelope as Dictionary).get("data"))
	_check(bool(result.get("ok", false)), "purchase fixture parses")
	_check(str(result.get("status", "")) == "granted", "purchase status")
	_check(bool(result.get("new_grant", false)) == true, "purchase new_grant")
	var grants := result.get("grants", []) as Array
	_check(grants.size() == 1, "purchase returns one grant")
	if grants.size() == 1:
		_check(str((grants[0] as Dictionary).get("source", "")) == "purchase", "purchase grant source")


func _check_purchase_refunded_fixture() -> void:
	var envelope = _load_fixture("v1/success/purchase-refunded.response.json")
	if envelope == null:
		return
	var result := BackendReadOperationsScript.parse_purchase((envelope as Dictionary).get("data"))
	_check(bool(result.get("ok", false)), "purchase-refunded fixture parses")
	_check(str(result.get("status", "")) == "refunded", "purchase-refunded status")
	_check(result.has("restriction"), "purchase-refunded includes restriction")
	if result.has("restriction"):
		_check(
			str((result.get("restriction") as Dictionary).get("status", "")) == "debt_outstanding",
			"purchase-refunded restriction.status"
		)


func _check_leaderboard_fixture() -> void:
	var envelope = _load_fixture("v1/success/leaderboard.response.json")
	if envelope == null:
		return
	var result := BackendReadOperationsScript.parse_leaderboard((envelope as Dictionary).get("data"))
	_check(bool(result.get("ok", false)), "leaderboard fixture parses")
	_check(str(result.get("scope", "")) == "weekly", "leaderboard scope")
	var entries := result.get("entries", []) as Array
	_check(entries.size() == 2, "leaderboard returns two entries")
	if not entries.is_empty():
		_check(
			str((entries[0] as Dictionary).get("avatar_frame_id", "")) == "frame_gold",
			"leaderboard entry exposes the remote avatar frame"
		)
	_check(result.has("current_player"), "leaderboard includes current_player")
	if result.has("current_player"):
		_check(
			bool((result.get("current_player") as Dictionary).get("is_current_player", false)) == true,
			"leaderboard current_player.is_current_player"
		)


func _check_error_fixtures() -> void:
	for name in ["rate-limited", "state-version-conflict"]:
		var envelope = _load_fixture("v1/error/%s.response.json" % name)
		if envelope == null:
			continue
		var transport := BackendTransportScript.new()
		_created_transports.append(transport)
		var result: Dictionary = transport.call("_envelope_error", envelope, 429 if name == "rate-limited" else 409)
		_check(not bool(result.get("ok", true)), "%s error fixture is not ok" % name)
		var error := result.get("error", {}) as Dictionary
		_check(not str(error.get("code", "")).is_empty(), "%s error fixture has a code" % name)
		_check(
			(BackendTransportScript.KNOWN_ERROR_CATEGORIES as Array).has(error.get("category", "")),
			"%s error fixture category is a known category" % name
		)
		_check(not str(error.get("correlation_id", "")).is_empty(), "%s error fixture keeps correlation_id" % name)


func _check_unknown_enum_mapping() -> void:
	var envelope = _load_fixture("v1/success/player-state.response.json")
	if envelope == null:
		return
	var mutated := (envelope as Dictionary).duplicate(true)
	var data := (mutated.get("data") as Dictionary).duplicate(true)
	data["account_kind"] = "some_future_account_kind"
	var profile := (data.get("profile") as Dictionary).duplicate(true)
	profile["moderation_state"] = "some_future_moderation_state"
	profile["avatar_frame_id"] = "some_future_avatar_frame"
	data["profile"] = profile
	var result := BackendReadOperationsScript.parse_player_state(data)
	_check(bool(result.get("ok", false)), "player-state with unrecognized enums still parses")
	_check(str(result.get("account_kind", "")) == "unknown", "unrecognized account_kind maps to unknown")
	_check(
		str((result.get("profile") as Dictionary).get("moderation_state", "")) == "unknown",
		"unrecognized moderation_state maps to unknown"
	)
	_check(
		str((result.get("profile") as Dictionary).get("avatar_frame_id", "")) == "unknown",
		"unrecognized avatar_frame_id maps to unknown"
	)


func _load_fixture(relative_path: String) -> Variant:
	var path := _fixtures_root.path_join(relative_path)
	if not FileAccess.file_exists(path):
		_check(false, "fixture is present: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check(false, "fixture opens: %s" % path)
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_check(false, "fixture is valid JSON: %s" % path)
		return null
	if not (parser.data is Dictionary):
		_check(false, "fixture root is an object: %s" % path)
		return null
	return parser.data


# ---------------------------------------------------------------------------
# Transport-level checks
# ---------------------------------------------------------------------------

func _run_transport_tests() -> void:
	await _check_network_failures_retry_then_succeed()
	await _check_rate_limit_honors_retry_after()
	await _check_retryable_dependency_status_codes()
	await _check_terminal_status_is_not_retried()
	await _check_read_retry_budget_is_exhausted()
	await _check_unauthenticated_response_refreshes_and_replays()
	await _check_second_401_after_refresh_is_terminal()
	await _check_refresh_transport_failure_is_terminal()
	await _check_malformed_refresh_response_is_terminal()
	await _check_unavailable_backend_short_circuits()


func _make_transport(session_store) -> FakeTransport:
	var original_url: String = ProjectSettings.get_setting("application/config/backend_base_url", "")
	if original_url.strip_edges().is_empty():
		ProjectSettings.set_setting("application/config/backend_base_url", "http://127.0.0.1:8080")
	var transport := FakeTransport.new()
	transport.configure(session_store, func(): return TEST_PLAYER_ID)
	_created_transports.append(transport)
	return transport


func _success_response(overrides: Dictionary = {}) -> Array:
	var envelope := {
		"meta": {
			"protocol_version": "1.0",
			"request_id": "00000000-0000-4000-8000-0000000000c1",
			"correlation_id": "00000000-0000-4000-8000-0000000000c1",
			"server_time": "2026-07-14T09:00:00.000Z",
		},
		"data": {"ok": true},
	}
	envelope.merge(overrides, true)
	return [HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer()]


func _error_response(code: int, error_code: String, retryable: bool, headers: PackedStringArray = PackedStringArray()) -> Array:
	var envelope := {
		"meta": {
			"protocol_version": "1.0",
			"request_id": "00000000-0000-4000-8000-0000000000c2",
			"correlation_id": "00000000-0000-4000-8000-0000000000c2",
			"server_time": "2026-07-14T09:00:00.000Z",
		},
		"error": {
			"code": error_code,
			"category": "rate_limit" if code == 429 else "dependency",
			"message": "synthetic test error",
			"retryable": retryable,
		},
	}
	return [HTTPRequest.RESULT_SUCCESS, code, headers, JSON.stringify(envelope).to_utf8_buffer()]


func _check_network_failures_retry_then_succeed() -> void:
	var transport := _make_transport(FakeSessionStore.new())
	transport.get_queue = [
		[HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray()],
		[HTTPRequest.RESULT_CONNECTION_ERROR, 0, PackedStringArray(), PackedByteArray()],
		_success_response(),
	]
	var result: Dictionary = await transport.get_json("/v1/player/state")
	_check(bool(result.get("ok", false)), "network failures retry and eventually succeed")
	_check(transport.get_calls.size() == 3, "network failure case issues exactly 3 GETs")
	_check(transport.wait_calls.size() == 2, "network failure case waits twice between 3 attempts")


func _check_rate_limit_honors_retry_after() -> void:
	var transport := _make_transport(FakeSessionStore.new())
	transport.get_queue = [
		_error_response(429, "rate_limit.exceeded", true, PackedStringArray(["Retry-After: 17"])),
		_success_response(),
	]
	var result: Dictionary = await transport.get_json("/v1/catalog")
	_check(bool(result.get("ok", false)), "429 retries and then succeeds")
	_check(transport.wait_calls.size() == 1, "429 case waits once")
	_check(int(transport.wait_calls[0].get("retry_after_seconds", -1)) == 17, "429 Retry-After is honored")


func _check_retryable_dependency_status_codes() -> void:
	for code in [502, 503, 504]:
		var transport := _make_transport(FakeSessionStore.new())
		transport.get_queue = [
			_error_response(code, "dependency.upstream_unavailable", true),
			_success_response(),
		]
		var result: Dictionary = await transport.get_json("/v1/catalog")
		_check(bool(result.get("ok", false)), "%d retries and then succeeds" % code)


func _check_terminal_status_is_not_retried() -> void:
	# Reads must not retry a 500 automatically -- PROTOCOL_BOUNDARY.md's client retry table marks
	# 500 retryable for mutations only (same idempotency key), never for reads.
	for entry in [
		{"code": 400, "error_code": "request.invalid"},
		{"code": 403, "error_code": "access.denied"},
		{"code": 404, "error_code": "resource.not_found"},
		{"code": 426, "error_code": "client.unsupported"},
		{"code": 500, "error_code": "internal.unexpected"},
	]:
		var transport := _make_transport(FakeSessionStore.new())
		transport.get_queue = [_error_response(int(entry.get("code")), str(entry.get("error_code")), false)]
		var result: Dictionary = await transport.get_json("/v1/catalog")
		_check(not bool(result.get("ok", true)), "%d is terminal" % int(entry.get("code")))
		_check(transport.get_calls.size() == 1, "%d is not retried" % int(entry.get("code")))
		_check(
			str((result.get("error", {}) as Dictionary).get("code", "")) == str(entry.get("error_code")),
			"%d preserves the server error code" % int(entry.get("code"))
		)


func _check_read_retry_budget_is_exhausted() -> void:
	var transport := _make_transport(FakeSessionStore.new())
	transport.get_queue = [
		[HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray()],
		[HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray()],
		[HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray()],
		[HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray()],
		[HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray()],
	]
	var result: Dictionary = await transport.get_json("/v1/catalog")
	_check(not bool(result.get("ok", true)), "exhausted retry budget is terminal")
	_check(transport.get_calls.size() == 5, "read retry budget is exactly one try plus four retries")


func _check_unauthenticated_response_refreshes_and_replays() -> void:
	var session_store := FakeSessionStore.new()
	var transport := _make_transport(session_store)
	transport.get_queue = [
		_error_response(401, "auth.token_expired", false),
		_success_response(),
	]
	transport.post_queue = [_refresh_success_response()]
	var result: Dictionary = await transport.get_json("/v1/player/state")
	_check(bool(result.get("ok", false)), "401 refreshes and replays successfully")
	_check(transport.get_calls.size() == 2, "401 case issues exactly 2 GETs (original + replay)")
	_check(transport.post_calls.size() == 1, "401 case issues exactly one refresh POST")
	_check(session_store.store_calls.size() == 1, "401 case stores the refreshed session")
	_check(
		str(session_store.session.get("access_token", "")) == "refreshed-access-token",
		"401 case adopts the refreshed access token"
	)


func _check_second_401_after_refresh_is_terminal() -> void:
	var session_store := FakeSessionStore.new()
	var transport := _make_transport(session_store)
	transport.get_queue = [
		_error_response(401, "auth.token_expired", false),
		_error_response(401, "auth.token_expired", false),
	]
	transport.post_queue = [_refresh_success_response()]
	var result: Dictionary = await transport.get_json("/v1/player/state")
	_check(not bool(result.get("ok", true)), "a second 401 after refresh is terminal")
	_check(transport.post_calls.size() == 1, "only one refresh is attempted per read")
	_check(transport.get_calls.size() == 2, "no third replay is attempted")


func _check_refresh_transport_failure_is_terminal() -> void:
	var transport := _make_transport(FakeSessionStore.new())
	transport.get_queue = [_error_response(401, "auth.token_expired", false)]
	transport.post_queue = [[HTTPRequest.RESULT_CONNECTION_ERROR, 0, PackedStringArray(), PackedByteArray()]]
	var result: Dictionary = await transport.get_json("/v1/player/state")
	_check(not bool(result.get("ok", true)), "an unknown refresh transport outcome is terminal")
	_check(
		str((result.get("error", {}) as Dictionary).get("code", "")) == "auth.refresh_result_unknown",
		"unknown refresh transport outcome uses auth.refresh_result_unknown"
	)


func _check_malformed_refresh_response_is_terminal() -> void:
	var transport := _make_transport(FakeSessionStore.new())
	transport.get_queue = [_error_response(401, "auth.token_expired", false)]
	var malformed := {
		"meta": {
			"protocol_version": "1.1",
			"request_id": "mismatched-request-id",
			"correlation_id": "00000000-0000-4000-8000-0000000000c3",
			"server_time": "2026-07-14T09:00:00.000Z",
		},
		"data": {"player_id": TEST_PLAYER_ID},
	}
	transport.post_queue = [
		[HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(malformed).to_utf8_buffer()],
	]
	var result: Dictionary = await transport.get_json("/v1/player/state")
	_check(not bool(result.get("ok", true)), "a malformed refresh response is terminal")
	_check(
		str((result.get("error", {}) as Dictionary).get("code", "")) == "auth.refresh_response_malformed",
		"malformed refresh response uses auth.refresh_response_malformed"
	)


func _check_unavailable_backend_short_circuits() -> void:
	var original_url: String = ProjectSettings.get_setting("application/config/backend_base_url", "")
	ProjectSettings.set_setting("application/config/backend_base_url", "")
	var transport := FakeTransport.new()
	_created_transports.append(transport)
	transport.configure(FakeSessionStore.new(), func(): return TEST_PLAYER_ID)
	var result: Dictionary = await transport.get_json("/v1/player/state")
	ProjectSettings.set_setting("application/config/backend_base_url", original_url)
	_check(not bool(result.get("ok", true)), "an empty backend_base_url short-circuits")
	_check(transport.get_calls.is_empty(), "an unavailable backend never issues a GET")


func _refresh_success_response() -> Callable:
	# The transport generates and validates a fresh request_id per refresh attempt, so the fake
	# response is built lazily from the actual outgoing request body, mirroring how a real server
	# echoes whatever request_id the client just sent.
	return func(_url: String, _headers: PackedStringArray, body: String) -> Array:
		var sent := JSON.parse_string(body) as Dictionary
		var sent_meta := sent.get("meta", {}) as Dictionary
		var envelope := {
			"meta": {
				"protocol_version": "1.1",
				"request_id": str(sent_meta.get("request_id", "")),
				"correlation_id": "00000000-0000-4000-8000-0000000000c4",
				"server_time": "2026-07-14T09:00:00.000Z",
			},
			"data": {
				"player_id": TEST_PLAYER_ID,
				"device_id": TEST_DEVICE_ID,
				"session_id": "00000000-0000-4000-8000-0000000000a2",
				"authentication_level": "guest",
				"tokens": {
					"access_token": "refreshed-access-token",
					"access_token_expires_at": "2026-07-14T09:10:00.000Z",
					"refresh_token": "refreshed-refresh-token",
					"refresh_token_expires_at": "2026-08-14T09:00:00.000Z",
				},
			},
		}
		return [HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer()]


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
