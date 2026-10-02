extends Node
class_name BackendTransport

## GAME-007 shared authenticated transport for backend features outside the focused save services
## (GAME-004/005/006 own POST /v2/saves/* and guest bootstrap separately under scripts/save/).
## Owns bearer headers, envelopes, timeouts, response validation, retry classification, and one
## refresh/replay. Bodyless reads follow PROTOCOL_BOUNDARY.md's GET exception; ADS-003 protocol
## POSTs retain stable request/idempotency identities. GAME-012's account-deletion DELETE never
## refreshes and reports whether it may have been applied (see delete_json()). SaveSyncService
## behavior stays untouched.

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")

const SERVER_URL_SETTING := "application/config/backend_base_url"
const APP_VERSION_SETTING := "application/config/version"
const APP_BUILD_SETTING := "application/config/build_number"
const REFRESH_PROTOCOL_VERSION := "1.1"
const READ_PROTOCOL_VERSION := "1.0"
const REQUEST_TIMEOUT_SECONDS := 30.0

# "Eligible retries use full-jitter exponential backoff with bases 500 ms, 1 s, 2 s, and 4 s,
# capped at 30 seconds and four retry attempts per foreground operation." (PROTOCOL_BOUNDARY.md,
# Decision 9, "Client retry policy"). One initial try plus four retries.
const MAX_READ_ATTEMPTS := 5
const RETRY_BASE_MILLISECONDS := [500, 1000, 2000, 4000]
const RETRY_WALL_CLOCK_CAP_SECONDS := 30.0

const KNOWN_ERROR_CATEGORIES := [
	"authentication", "authorization", "validation", "conflict",
	"rate_limit", "dependency", "version", "internal", "unknown",
]

# Transport failures that end before any request byte is written. Every other failure (timeout,
# dropped connection, unreadable body) may follow a request the server already committed.
const PRE_SEND_TRANSPORT_FAILURES := [
	HTTPRequest.RESULT_CANT_RESOLVE,
	HTTPRequest.RESULT_CANT_CONNECT,
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
]
const DELETE_ACCEPTED_STATUS := 202
const OUTCOME_ACCEPTED := "accepted"
const OUTCOME_REJECTED := "rejected"
const OUTCOME_NOT_APPLIED := "not_applied"
const OUTCOME_UNCONFIRMED := "unconfirmed"

var _session_store
var _active_player_id_provider: Callable


func configure(session_store, active_player_id_provider: Callable) -> void:
	_session_store = session_store
	_active_player_id_provider = active_player_id_provider


func can_use_backend() -> bool:
	if _session_store == null or not _active_player_id_provider.is_valid():
		return false
	if str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).strip_edges().is_empty():
		return false
	return not _active_player_id().is_empty()


## Issues a bodyless authenticated v1 GET at `path` (e.g. "/v1/catalog"; must include any query
## string itself -- the transport never invents one) and returns a normalized result:
## `{"ok": true, "data": Dictionary, "meta": Dictionary}` on success, or
## `{"ok": false, "error": {"code", "category", "message", "retryable", "retry_after_seconds",
## "correlation_id", "http_status"}}` on a terminal failure. Retries network failures, `429`, and
## `502`/`503`/`504` up to MAX_READ_ATTEMPTS times with full-jitter backoff (`Retry-After` takes
## precedence over backoff); attempts exactly one refresh-and-replay on a `401`. Every other
## outcome (`400`/`403`/`404`/`409`/`413`/`415`/`426`/`500`, or a malformed envelope) is terminal
## and not retried automatically, matching the backend's read retry policy.
func get_json(path: String) -> Dictionary:
	if not can_use_backend():
		return _local_error("backend.unavailable", "dependency", false)
	var player_id := _active_player_id()
	var session_result: Dictionary = _session_store.load_session(player_id)
	if not bool(session_result.get("ok", false)):
		return _local_error("auth.session_missing", "authentication", false)
	var session := session_result.get("session", {}) as Dictionary
	if str(session.get("access_token", "")).is_empty():
		return _local_error("auth.session_missing", "authentication", false)
	return await _perform_read(path, player_id, session)


## Issues an authenticated body-bearing POST using the standard client envelope. Mutations must
## supply a stable idempotency key; body-bearing reads (currently rewarded-ad status) omit it. The
## same request id, body, and idempotency key are retained across transient retries, and a 401 gets
## exactly one refresh-and-replay. Callers remain responsible for closed response-data validation.
func post_json(
	path: String,
	protocol_version: String,
	data: Dictionary,
	expected_state_version: int = -1,
	idempotency_key: String = "",
	retry_transient: bool = true
) -> Dictionary:
	if not can_use_backend():
		return _local_error("backend.unavailable", "dependency", false)
	if protocol_version.is_empty():
		return _local_error("request.protocol_version_missing", "validation", false)
	if expected_state_version >= 0 and idempotency_key.is_empty():
		return _local_error("request.idempotency_key_missing", "validation", false)
	var player_id := _active_player_id()
	var session_result: Dictionary = _session_store.load_session(player_id)
	if not bool(session_result.get("ok", false)):
		return _local_error("auth.session_missing", "authentication", false)
	var session := session_result.get("session", {}) as Dictionary
	if str(session.get("access_token", "")).is_empty():
		return _local_error("auth.session_missing", "authentication", false)
	return await _perform_post(
		path,
		protocol_version,
		data,
		expected_state_version,
		idempotency_key,
		retry_transient,
		player_id,
		session
	)


## GAME-012 account deletion (`DELETE /v1/player/account`; docs/ACCOUNT_DELETION_PLAN.md). Unlike
## post_json() this never refreshes: acceptance revokes the sending session, and only an exact
## replay under the original access token can still read the stored 202. `operation` is the
## caller's persisted identity: `request_id`, `idempotency_key`, `expected_state_version`, the
## `player_id`/`device_id`/`session_id` it is bound to, and `possibly_applied` from earlier calls.
## Nothing is sent when the active player, device, or stored session no longer matches the binding,
## because the original credential is then gone.
##
## Adds `outcome` and `possibly_applied` to the usual result. `outcome` is "accepted" (validated
## 202 envelope; the caller still validates `data`), "rejected" (a response that settles this
## operation as not applied, such as a version conflict), "not_applied" (no attempt in this or an
## earlier call can have been applied), or "unconfirmed" (an attempt may have been applied and
## nothing settled it).
## Retries follow the mutation policy: network failures, 429, and 500/502/503/504.
func delete_json(
	path: String,
	protocol_version: String,
	data: Dictionary,
	operation: Dictionary
) -> Dictionary:
	var possibly_applied := bool(operation.get("possibly_applied", false))
	if not can_use_backend():
		return _settle_delete(
			_local_error("backend.unavailable", "dependency", false), "", possibly_applied
		)
	if protocol_version.is_empty():
		return _settle_delete(
			_local_error("request.protocol_version_missing", "validation", false),
			"",
			possibly_applied
		)
	var expected_state_version = operation.get("expected_state_version")
	if (
		not LocalSaveCodecScript.is_uuid(operation.get("request_id"))
		or not LocalSaveCodecScript.is_uuid(operation.get("idempotency_key"))
		or not _is_integer(expected_state_version)
		or int(expected_state_version) < 0
	):
		return _settle_delete(
			_local_error("request.operation_invalid", "validation", false), "", possibly_applied
		)
	var player_id := _active_player_id()
	if (
		player_id != str(operation.get("player_id", ""))
		or _session_store.get_device_id() != str(operation.get("device_id", ""))
	):
		return _settle_delete(
			_local_error("auth.binding_changed", "authentication", false), "", possibly_applied
		)
	var session_result: Dictionary = _session_store.load_session(player_id)
	var session := session_result.get("session", {}) as Dictionary
	if (
		not bool(session_result.get("ok", false))
		or str(session.get("access_token", "")).is_empty()
	):
		return _settle_delete(
			_local_error("auth.session_missing", "authentication", false), "", possibly_applied
		)
	if str(session.get("session_id", "")) != str(operation.get("session_id", "")):
		return _settle_delete(
			_local_error("auth.binding_changed", "authentication", false), "", possibly_applied
		)
	return await _perform_delete(
		path,
		protocol_version,
		data,
		operation,
		session,
		possibly_applied
	)


func _perform_post(
	path: String,
	protocol_version: String,
	data: Dictionary,
	expected_state_version: int,
	idempotency_key: String,
	retry_transient: bool,
	player_id: String,
	session: Dictionary
) -> Dictionary:
	var base_url := str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).trim_suffix("/")
	var request_id := LocalSaveCodecScript.create_uuid()
	var refreshed := false
	var attempt := 0
	var start_msec := Time.get_ticks_msec()
	while true:
		attempt += 1
		var correlation_id := LocalSaveCodecScript.create_uuid()
		var envelope := _post_envelope(
			protocol_version,
			request_id,
			session,
			data,
			expected_state_version
		)
		var headers := PackedStringArray([
			"Authorization: Bearer %s" % str(session.get("access_token", "")),
			"Content-Type: application/json",
			"X-Correlation-ID: %s" % correlation_id,
		])
		if not idempotency_key.is_empty():
			headers.append("Idempotency-Key: %s" % idempotency_key)
		var raw_response: Array = await _send_post(
			"%s%s" % [base_url, path],
			headers,
			JSON.stringify(envelope)
		)
		var classification := _classify_post_response(
			raw_response,
			protocol_version,
			request_id,
			not idempotency_key.is_empty()
		)
		match str(classification.get("kind", "")):
			"success":
				return classification.get("result")
			"needs_refresh":
				if refreshed:
					return classification.get("result")
				var refresh_result := await _refresh_session(session, player_id)
				if not bool(refresh_result.get("ok", false)):
					return refresh_result
				session = refresh_result.get("session", {}) as Dictionary
				refreshed = true
				attempt -= 1
			"retryable":
				if not retry_transient or attempt >= MAX_READ_ATTEMPTS:
					return classification.get("result")
				var elapsed_seconds := float(Time.get_ticks_msec() - start_msec) / 1000.0
				if elapsed_seconds >= RETRY_WALL_CLOCK_CAP_SECONDS:
					return classification.get("result")
				await _wait_before_retry(attempt, int(classification.get("retry_after_seconds", -1)))
			_:
				return classification.get("result")
	return _local_error("internal.unexpected", "internal", false)


func _post_envelope(
	protocol_version: String,
	request_id: String,
	session: Dictionary,
	data: Dictionary,
	expected_state_version: int
) -> Dictionary:
	var meta := {
		"protocol_version": protocol_version,
		"request_id": request_id,
		"device_id": _session_store.get_device_id(),
		"session_id": str(session.get("session_id", "")),
		"app": {
			"platform": "android" if OS.get_name() == "Android" else "ios",
			"version": str(ProjectSettings.get_setting(APP_VERSION_SETTING, "1.0.0")),
			"build": maxi(int(ProjectSettings.get_setting(APP_BUILD_SETTING, 1)), 1),
		},
		"locale": TranslationServer.get_locale().replace("_", "-"),
		"client_time": LocalSaveCodecScript.iso_timestamp(),
	}
	if expected_state_version >= 0:
		meta["expected_state_version"] = expected_state_version
	return {"meta": meta, "data": data.duplicate(true)}


func _perform_delete(
	path: String,
	protocol_version: String,
	data: Dictionary,
	operation: Dictionary,
	session: Dictionary,
	possibly_applied: bool
) -> Dictionary:
	var base_url := str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).trim_suffix("/")
	var request_id := str(operation.get("request_id", ""))
	var attempt := 0
	var start_msec := Time.get_ticks_msec()
	while true:
		attempt += 1
		var envelope := _post_envelope(
			protocol_version,
			request_id,
			session,
			data,
			int(operation.get("expected_state_version", 0))
		)
		var headers := PackedStringArray([
			"Authorization: Bearer %s" % str(session.get("access_token", "")),
			"Content-Type: application/json",
			"X-Correlation-ID: %s" % LocalSaveCodecScript.create_uuid(),
			"Idempotency-Key: %s" % str(operation.get("idempotency_key", "")),
		])
		var raw_response: Array = await _send_delete(
			"%s%s" % [base_url, path],
			headers,
			JSON.stringify(envelope)
		)
		var classification := _classify_delete_response(raw_response, protocol_version, request_id)
		var result := classification.get("result", {}) as Dictionary
		match str(classification.get("kind", "")):
			"accepted":
				return _settle_delete(result, OUTCOME_ACCEPTED, true)
			"settled":
				return _settle_delete(result, OUTCOME_REJECTED, false)
			"rejected":
				# Only a stored per-key outcome settles a replay. Any other rejection after an attempt
				# that may have been applied (a 401 once the original token expires, for example)
				# cannot show that the earlier attempt failed.
				return _settle_delete(
					result,
					OUTCOME_UNCONFIRMED if possibly_applied else OUTCOME_REJECTED,
					possibly_applied
				)
			"unsettled":
				return _settle_delete(result, "", true)
			"retryable":
				possibly_applied = possibly_applied or bool(classification.get("possibly_applied", false))
				var elapsed_seconds := float(Time.get_ticks_msec() - start_msec) / 1000.0
				if attempt >= MAX_READ_ATTEMPTS or elapsed_seconds >= RETRY_WALL_CLOCK_CAP_SECONDS:
					return _settle_delete(result, "", possibly_applied)
				await _wait_before_retry(attempt, int(classification.get("retry_after_seconds", -1)))
	return _settle_delete(_local_error("internal.unexpected", "internal", false), "", possibly_applied)


## Classifies one DELETE attempt. "settled" is `409 state.version_conflict`: the backend stores the
## conflict against the idempotency key, and a replay of an applied key returns its stored 202, so
## the conflict proves no attempt under this key was applied. `409 idempotency.key_reused` means a
## different request owns the key, which settles nothing. "rejected" is any other terminal
## response, which proves only that this attempt was not applied.
func _classify_delete_response(
	raw_response: Array,
	protocol_version: String,
	request_id: String
) -> Dictionary:
	var transport_result := int(raw_response[0]) if raw_response.size() > 0 else HTTPRequest.RESULT_CANT_CONNECT
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"kind": "retryable",
			"result": _local_error("network.transport_failed", "dependency", true),
			"retry_after_seconds": -1,
			"possibly_applied": not PRE_SEND_TRANSPORT_FAILURES.has(transport_result),
		}
	var response_code := int(raw_response[1]) if raw_response.size() > 1 else 0
	var response_headers := raw_response[2] as PackedStringArray if raw_response.size() > 2 else PackedStringArray()
	var body := raw_response[3] as PackedByteArray if raw_response.size() > 3 else PackedByteArray()
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if response_code == DELETE_ACCEPTED_STATUS:
		var validated := _validate_post_success_envelope(parsed, protocol_version, request_id)
		return {
			"kind": "accepted" if bool(validated.get("ok", false)) else "unsettled",
			"result": validated,
		}
	if response_code >= 200 and response_code < 300:
		return {
			"kind": "unsettled",
			"result": _local_error("transport.malformed_response", "internal", false, response_code),
		}
	if response_code == 429:
		return {
			"kind": "retryable",
			"result": _envelope_error(parsed, response_code),
			"retry_after_seconds": _retry_after_seconds(response_headers),
			"possibly_applied": false,
		}
	if response_code == 500 or response_code == 502 or response_code == 503 or response_code == 504:
		return {
			"kind": "retryable",
			"result": _envelope_error(parsed, response_code),
			"retry_after_seconds": -1,
			"possibly_applied": true,
		}
	if response_code == 409:
		var conflict := _envelope_error(parsed, response_code)
		var conflict_code := str((conflict.get("error", {}) as Dictionary).get("code", ""))
		return {
			"kind": "settled" if conflict_code == "state.version_conflict" else "unsettled",
			"result": conflict,
		}
	return {"kind": "rejected", "result": _envelope_error(parsed, response_code)}


## An empty `outcome` means nothing settled the operation, which is "unconfirmed" when an attempt may
## have been applied and "not_applied" otherwise.
func _settle_delete(result: Dictionary, outcome: String, possibly_applied: bool) -> Dictionary:
	var settled := result.duplicate(true)
	if outcome.is_empty():
		outcome = OUTCOME_UNCONFIRMED if possibly_applied else OUTCOME_NOT_APPLIED
	settled["outcome"] = outcome
	settled["possibly_applied"] = possibly_applied
	return settled


func _classify_post_response(
	raw_response: Array,
	protocol_version: String,
	request_id: String,
	is_mutation: bool
) -> Dictionary:
	var transport_result := int(raw_response[0]) if raw_response.size() > 0 else HTTPRequest.RESULT_CANT_CONNECT
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"kind": "retryable",
			"result": _local_error("network.transport_failed", "dependency", true),
			"retry_after_seconds": -1,
		}
	var response_code := int(raw_response[1]) if raw_response.size() > 1 else 0
	var response_headers := raw_response[2] as PackedStringArray if raw_response.size() > 2 else PackedStringArray()
	var body := raw_response[3] as PackedByteArray if raw_response.size() > 3 else PackedByteArray()
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if response_code == 200:
		var validated := _validate_post_success_envelope(parsed, protocol_version, request_id)
		return {"kind": "success" if bool(validated.get("ok", false)) else "terminal", "result": validated}
	if response_code == 401:
		return {"kind": "needs_refresh", "result": _envelope_error(parsed, response_code)}
	if response_code == 429:
		return {
			"kind": "retryable",
			"result": _envelope_error(parsed, response_code),
			"retry_after_seconds": _retry_after_seconds(response_headers),
		}
	if (
		(response_code == 500 and is_mutation)
		or response_code == 502
		or response_code == 503
		or response_code == 504
	):
		return {"kind": "retryable", "result": _envelope_error(parsed, response_code), "retry_after_seconds": -1}
	return {"kind": "terminal", "result": _envelope_error(parsed, response_code)}


func _validate_post_success_envelope(
	parsed: Variant,
	protocol_version: String,
	request_id: String
) -> Dictionary:
	if not (parsed is Dictionary):
		return _local_error("transport.malformed_response", "internal", false)
	var document := parsed as Dictionary
	var meta = document.get("meta")
	var data = document.get("data")
	if not (meta is Dictionary and data is Dictionary):
		return _local_error("transport.malformed_response", "internal", false)
	var response_meta := meta as Dictionary
	var state_version = response_meta.get("state_version")
	if (
		str(response_meta.get("protocol_version", "")) != protocol_version
		or str(response_meta.get("request_id", "")) != request_id
		or str(response_meta.get("correlation_id", "")).is_empty()
		or not LocalSaveCodecScript.is_timestamp(response_meta.get("server_time"))
		or not _is_integer(state_version)
		or int(state_version) < 0
	):
		return _local_error("transport.malformed_response", "internal", false)
	return {
		"ok": true,
		"data": (data as Dictionary).duplicate(true),
		"meta": (response_meta as Dictionary).duplicate(true),
	}


func _perform_read(path: String, player_id: String, session: Dictionary) -> Dictionary:
	var base_url := str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).trim_suffix("/")
	var refreshed := false
	var attempt := 0
	var start_msec := Time.get_ticks_msec()
	while true:
		attempt += 1
		var correlation_id := LocalSaveCodecScript.create_uuid()
		var headers := PackedStringArray([
			"Authorization: Bearer %s" % str(session.get("access_token", "")),
			"X-Correlation-ID: %s" % correlation_id,
		])
		var raw_response: Array = await _send_get("%s%s" % [base_url, path], headers)
		var classification := _classify_read_response(raw_response)
		match str(classification.get("kind", "")):
			"success":
				return classification.get("result")
			"needs_refresh":
				if refreshed:
					return classification.get("result")
				var refresh_result := await _refresh_session(session, player_id)
				if not bool(refresh_result.get("ok", false)):
					return refresh_result
				session = refresh_result.get("session", {}) as Dictionary
				refreshed = true
				attempt -= 1 # refresh-and-replay does not consume a read retry attempt
			"retryable":
				if attempt >= MAX_READ_ATTEMPTS:
					return classification.get("result")
				var elapsed_seconds := float(Time.get_ticks_msec() - start_msec) / 1000.0
				if elapsed_seconds >= RETRY_WALL_CLOCK_CAP_SECONDS:
					return classification.get("result")
				await _wait_before_retry(attempt, int(classification.get("retry_after_seconds", -1)))
			_:
				return classification.get("result")
	return _local_error("internal.unexpected", "internal", false)


func _classify_read_response(raw_response: Array) -> Dictionary:
	var transport_result := int(raw_response[0]) if raw_response.size() > 0 else HTTPRequest.RESULT_CANT_CONNECT
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"kind": "retryable",
			"result": _local_error("network.transport_failed", "dependency", true),
			"retry_after_seconds": -1,
		}
	var response_code := int(raw_response[1]) if raw_response.size() > 1 else 0
	var response_headers := raw_response[2] as PackedStringArray if raw_response.size() > 2 else PackedStringArray()
	var body := raw_response[3] as PackedByteArray if raw_response.size() > 3 else PackedByteArray()
	var parsed = JSON.parse_string(body.get_string_from_utf8())

	if response_code == 200:
		var validated := _validate_success_envelope(parsed)
		return {"kind": "terminal" if not bool(validated.get("ok", false)) else "success", "result": validated}
	if response_code == 401:
		return {"kind": "needs_refresh", "result": _envelope_error(parsed, response_code)}
	if response_code == 429:
		var retry_after := _retry_after_seconds(response_headers)
		return {
			"kind": "retryable",
			"result": _envelope_error(parsed, response_code),
			"retry_after_seconds": retry_after,
		}
	if response_code == 502 or response_code == 503 or response_code == 504:
		return {"kind": "retryable", "result": _envelope_error(parsed, response_code), "retry_after_seconds": -1}
	return {"kind": "terminal", "result": _envelope_error(parsed, response_code)}


func _wait_before_retry(attempt: int, retry_after_seconds: int) -> void:
	var delay_seconds: float
	if retry_after_seconds >= 0:
		delay_seconds = float(retry_after_seconds)
	else:
		var base_index := mini(attempt - 1, RETRY_BASE_MILLISECONDS.size() - 1)
		var maximum_delay: int = RETRY_BASE_MILLISECONDS[base_index]
		delay_seconds = float(randi_range(0, maximum_delay)) / 1000.0
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(maxf(delay_seconds, 0.01)).timeout


func _refresh_session(session: Dictionary, player_id: String) -> Dictionary:
	if str(session.get("refresh_token", "")).is_empty():
		return _local_error("auth.refresh_token_missing", "authentication", false)
	var request_id := LocalSaveCodecScript.create_uuid()
	var envelope := {
		"meta": {
			"protocol_version": REFRESH_PROTOCOL_VERSION,
			"request_id": request_id,
			"device_id": _session_store.get_device_id(),
			"session_id": str(session.get("session_id", "")),
			"app": {
				"platform": "android" if OS.get_name() == "Android" else "ios",
				"version": str(ProjectSettings.get_setting(APP_VERSION_SETTING, "1.0.0")),
				"build": maxi(int(ProjectSettings.get_setting(APP_BUILD_SETTING, 1)), 1),
			},
			"locale": TranslationServer.get_locale().replace("_", "-"),
			"client_time": LocalSaveCodecScript.iso_timestamp(),
		},
		"data": {"refresh_token": str(session.get("refresh_token", ""))},
	}
	var base_url := str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).trim_suffix("/")
	var raw_response: Array = await _send_post(
		"%s/v1/sessions/refresh" % base_url,
		PackedStringArray(["Content-Type: application/json"]),
		JSON.stringify(envelope)
	)
	var transport_result := int(raw_response[0]) if raw_response.size() > 0 else HTTPRequest.RESULT_CANT_CONNECT
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		# Refresh tokens rotate on use. After an unknown transport outcome, replaying the
		# credential could trigger the backend's reuse/theft response and revoke the family, so
		# this is treated as terminal rather than retried -- mirrors SaveSyncService.
		return _local_error("auth.refresh_result_unknown", "authentication", false)
	var response_code := int(raw_response[1]) if raw_response.size() > 1 else 0
	var body := raw_response[3] as PackedByteArray if raw_response.size() > 3 else PackedByteArray()
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if response_code != 200 or not (parsed is Dictionary):
		return _envelope_error(parsed, response_code)
	return _validate_and_store_refresh_response(parsed as Dictionary, request_id, player_id)


func _validate_and_store_refresh_response(
	document: Dictionary,
	sent_request_id: String,
	player_id: String
) -> Dictionary:
	var meta = document.get("meta")
	var data = document.get("data")
	if not (meta is Dictionary and data is Dictionary):
		return _local_error("auth.refresh_response_malformed", "authentication", false)
	var response_meta := meta as Dictionary
	if (
		str(response_meta.get("protocol_version", "")) != REFRESH_PROTOCOL_VERSION
		or str(response_meta.get("request_id", "")) != sent_request_id
	):
		return _local_error("auth.refresh_response_malformed", "authentication", false)
	var response := data as Dictionary
	var tokens = response.get("tokens")
	if (
		str(response.get("player_id", "")) != player_id
		or str(response.get("device_id", "")) != _session_store.get_device_id()
		or not LocalSaveCodecScript.is_uuid(response.get("session_id"))
		or not (tokens is Dictionary)
	):
		return _local_error("auth.refresh_response_malformed", "authentication", false)
	var token_data := tokens as Dictionary
	var refreshed_session := {
		"session_id": str(response.get("session_id", "")),
		"authentication_level": str(response.get("authentication_level", "")),
		"access_token": str(token_data.get("access_token", "")),
		"access_token_expires_at": str(token_data.get("access_token_expires_at", "")),
		"refresh_token": str(token_data.get("refresh_token", "")),
		"refresh_token_expires_at": str(token_data.get("refresh_token_expires_at", "")),
	}
	if (
		str(refreshed_session.get("access_token", "")).is_empty()
		or str(refreshed_session.get("refresh_token", "")).is_empty()
	):
		return _local_error("auth.refresh_response_malformed", "authentication", false)
	var store_result: Dictionary = _session_store.store_session(player_id, refreshed_session)
	if not bool(store_result.get("ok", false)):
		return _local_error("auth.secure_session_write_failed", "internal", false)
	return {"ok": true, "session": refreshed_session}


## Validates a bodyless-GET success envelope. Per PROTOCOL_BOUNDARY.md's "bodyless GET exception",
## these reads select protocol 1.0 and echo the final correlation id as `request_id` because there
## is no client request envelope to echo. Only the keys this transport/its callers need are read,
## so additive response fields are ignored by construction.
func _validate_success_envelope(parsed: Variant) -> Dictionary:
	if not (parsed is Dictionary):
		return _local_error("transport.malformed_response", "internal", false)
	var document := parsed as Dictionary
	var meta = document.get("meta")
	var data = document.get("data")
	if not (meta is Dictionary and data is Dictionary):
		return _local_error("transport.malformed_response", "internal", false)
	var response_meta := meta as Dictionary
	var correlation_id := str(response_meta.get("correlation_id", ""))
	if (
		str(response_meta.get("protocol_version", "")) != READ_PROTOCOL_VERSION
		or correlation_id.is_empty()
		or str(response_meta.get("request_id", "")) != correlation_id
		or not LocalSaveCodecScript.is_timestamp(response_meta.get("server_time"))
	):
		return _local_error("transport.malformed_response", "internal", false)
	var state_version = response_meta.get("state_version")
	return {
		"ok": true,
		"data": data as Dictionary,
		"meta": {
			"protocol_version": str(response_meta.get("protocol_version", "")),
			"correlation_id": correlation_id,
			"server_time": str(response_meta.get("server_time", "")),
			"state_version": int(state_version) if _is_integer(state_version) else -1,
		},
	}


func _envelope_error(parsed: Variant, http_status: int) -> Dictionary:
	if not (parsed is Dictionary):
		return _local_error("transport.malformed_response", "internal", false, http_status)
	var document := parsed as Dictionary
	var error = document.get("error")
	var meta = document.get("meta")
	var correlation_id := ""
	if meta is Dictionary:
		correlation_id = str((meta as Dictionary).get("correlation_id", ""))
	if not (error is Dictionary):
		return _local_error("transport.malformed_response", "internal", false, http_status, correlation_id)
	var protocol_error := error as Dictionary
	var code := str(protocol_error.get("code", ""))
	var category := _normalize_category(protocol_error.get("category"))
	if code.is_empty():
		return _local_error("transport.malformed_response", "internal", false, http_status, correlation_id)
	var retry_after = protocol_error.get("retry_after_seconds")
	var result := {
		"ok": false,
		"error": {
			"code": code,
			"category": category,
			"message": str(protocol_error.get("message", "")),
			"retryable": bool(protocol_error.get("retryable", false)),
			"retry_after_seconds": int(retry_after) if _is_integer(retry_after) else -1,
			"correlation_id": correlation_id,
			"http_status": http_status,
		},
	}
	if protocol_error.get("recovery") is Dictionary:
		(result.get("error") as Dictionary)["recovery"] = (
			protocol_error.get("recovery") as Dictionary
		).duplicate(true)
	return result


func _normalize_category(value: Variant) -> String:
	var text := str(value)
	return text if KNOWN_ERROR_CATEGORIES.has(text) else "unknown"


func _retry_after_seconds(headers: PackedStringArray) -> int:
	for header in headers:
		var separator := header.find(":")
		if separator < 0:
			continue
		if header.left(separator).strip_edges().to_lower() == "retry-after":
			return maxi(int(header.substr(separator + 1).strip_edges()), 0)
	return -1


func _active_player_id() -> String:
	if not _active_player_id_provider.is_valid():
		return ""
	return str(_active_player_id_provider.call())


func _local_error(
	code: String,
	category: String,
	retryable: bool,
	http_status: int = 0,
	correlation_id: String = ""
) -> Dictionary:
	return {
		"ok": false,
		"error": {
			"code": code,
			"category": _normalize_category(category),
			"message": "",
			"retryable": retryable,
			"retry_after_seconds": -1,
			"correlation_id": correlation_id,
			"http_status": http_status,
		},
	}


func _is_integer(value: Variant) -> bool:
	return (
		value is int
		or (value is float and is_finite(float(value)) and float(value) == floor(float(value)))
	)


## Overridable network seams so tests can fake transport outcomes without opening a real socket
## (same seam pattern as SaveSyncService/GuestSessionBootstrapService test doubles).
func _send_get(url: String, headers: PackedStringArray) -> Array:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(http)
	var request_error := http.request(url, headers, HTTPClient.METHOD_GET)
	if request_error != OK:
		http.queue_free()
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	var response: Array = await http.request_completed
	http.queue_free()
	return response


func _send_post(url: String, headers: PackedStringArray, body: String) -> Array:
	return await _send_with_body(HTTPClient.METHOD_POST, url, headers, body)


func _send_delete(url: String, headers: PackedStringArray, body: String) -> Array:
	return await _send_with_body(HTTPClient.METHOD_DELETE, url, headers, body)


func _send_with_body(
	method: HTTPClient.Method,
	url: String,
	headers: PackedStringArray,
	body: String
) -> Array:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(http)
	# A failed request() call returns before any byte is written, so it reports CANT_CONNECT, which
	# delete_json() treats as never sent.
	var request_error := http.request(url, headers, method, body)
	if request_error != OK:
		http.queue_free()
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	var response: Array = await http.request_completed
	http.queue_free()
	return response
