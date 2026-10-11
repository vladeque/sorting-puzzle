extends Node
class_name SaveSyncService

signal reconciliation_applied

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")
const PROTOCOL_VERSION := "2.1"
const SUPPORTED_RESPONSE_PROTOCOL_VERSIONS := ["2.0", PROTOCOL_VERSION]
const MAX_OPERATIONS := 500
const MAX_REQUEST_BYTES := 1024 * 1024
const REQUEST_TIMEOUT_SECONDS := 30.0
const RETRY_BASE_MILLISECONDS := [500, 1000, 2000, 4000]
const RETRY_CAP_MILLISECONDS := 30000
const SERVER_URL_SETTING := "application/config/backend_base_url"
const FEATURE_SETTING := "application/config/save_sync_v2_enabled"
const APP_VERSION_SETTING := "application/config/version"
const APP_BUILD_SETTING := "application/config/build_number"

var _store: LocalSaveStore
var _session_store: SecureSessionStore
var _checkpoint_mapper: Callable
var _http_request: HTTPRequest
var _busy := false
var _retry_timer: Timer
var _request_mode := ""
var _active_session := {}
var _state_refresh_attempted := false
var _request_store
var _refresh_request_id := ""
var _content_provenance_valid := true
var _suspended := false


func configure(
	store: LocalSaveStore,
	session_store: SecureSessionStore,
	checkpoint_mapper: Callable,
	content_provenance_valid: bool = true
) -> void:
	# Reopening the same save must not orphan a request already in flight: the pending request
	# and refresh state were persisted before sending, so the new handle can process the response.
	# Dropping a refresh response would lose the rotated refresh token.
	if _busy and _is_same_save(_request_store, store):
		_request_store = store
	_store = store
	_session_store = session_store
	_checkpoint_mapper = checkpoint_mapper
	_content_provenance_valid = content_provenance_valid
	if _http_request == null:
		_http_request = HTTPRequest.new()
		_http_request.timeout = REQUEST_TIMEOUT_SECONDS
		_http_request.request_completed.connect(_on_request_completed)
		add_child(_http_request)
	if _retry_timer == null:
		_retry_timer = Timer.new()
		_retry_timer.one_shot = true
		_retry_timer.timeout.connect(request_background_sync)
		add_child(_retry_timer)
	_schedule_persisted_retry()


## True when both stores are handles on the same save namespace, as after PlayerProgress reopens
## the active save (the main menu and the Shop do this every time they open).
func _is_same_save(left, right) -> bool:
	return (
		left != null
		and right != null
		and left.has_method("get_namespace")
		and right.has_method("get_namespace")
		and left.get_namespace() == right.get_namespace()
	)


func replace_store(store: LocalSaveStore) -> void:
	_store = store
	_busy = false
	if _http_request != null:
		_http_request.cancel_request()
	_request_store = null
	_schedule_persisted_retry()


func notify_local_mutation() -> void:
	call_deferred("request_background_sync")


## GAME-012: while suspended no new sync, state read, or refresh starts, including persisted retry
## timers. A request already in flight still completes, so account deletion waits for is_busy() to
## clear instead of cancelling a refresh whose rotation the server may already have applied.
func set_suspended(suspended: bool) -> void:
	_suspended = suspended


func is_busy() -> bool:
	return _busy


func request_background_sync() -> void:
	if _busy or _suspended or not _can_sync():
		return
	var sync := _store.get_sync_metadata()
	if not (sync.get("terminal_error", {}) as Dictionary).is_empty():
		return
	var now_unix := int(Time.get_unix_time_from_system())
	if int(sync.get("next_retry_unix", 0)) > now_unix:
		_schedule_persisted_retry()
		return
	var session_result := _session_store.load_session(_active_player_id())
	if not bool(session_result.get("ok", false)):
		return
	var session := session_result.get("session", {}) as Dictionary
	var pending := sync.get("pending_request", {}) as Dictionary
	if pending.is_empty():
		var build_result := _build_request(session)
		if not bool(build_result.get("ok", false)):
			return
		pending = build_result.get("pending_request", {}) as Dictionary
		sync["pending_request"] = pending
		sync["retry_attempt"] = 0
		sync["next_retry_unix"] = 0
		if not bool(_store.persist_sync_metadata(sync).get("ok", false)):
			return
	if pending.is_empty():
		return
	_send_pending_request(pending, session)


func _can_sync() -> bool:
	if _store == null or _session_store == null:
		return false
	if not _content_provenance_valid:
		return false
	if not bool(ProjectSettings.get_setting(FEATURE_SETTING, false)):
		return false
	if str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).strip_edges().is_empty():
		return false
	if not _session_store.can_synchronize():
		return false
	return not _active_player_id().is_empty()


func _build_request(session: Dictionary) -> Dictionary:
	if (
		not LocalSaveCodecScript.is_uuid(session.get("session_id"))
		or str(session.get("access_token", "")).is_empty()
	):
		return _error("The secure player session is incomplete.")
	var sync := _store.get_sync_metadata()
	var cursor := sync.get("cursor", {}) as Dictionary
	var acknowledged_sequence := int(cursor.get("acknowledged_sequence", 0))
	var operations := []
	for raw_operation in _store.get_journal():
		var operation := raw_operation as Dictionary
		if int(operation.get("device_sequence", 0)) > acknowledged_sequence:
			operations.append(operation)
		if operations.size() >= MAX_OPERATIONS:
			break
	if operations.is_empty():
		return _success({"pending_request": {}})

	var request_id := LocalSaveCodecScript.create_uuid()
	var envelope := {
		"meta": {
			"protocol_version": PROTOCOL_VERSION,
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
		"data": {
			"source_namespace": _store.get_namespace(),
			"cursor": cursor,
			"journal_head_sequence": int(sync.get("journal_head_sequence", 0)),
			"operations": operations,
		},
	}
	var payload := JSON.stringify(envelope)
	while payload.to_utf8_buffer().size() > MAX_REQUEST_BYTES and operations.size() > 1:
		operations.pop_back()
		envelope["data"]["operations"] = operations
		payload = JSON.stringify(envelope)
	if payload.to_utf8_buffer().size() > MAX_REQUEST_BYTES:
		return _error("The next save operation exceeds the v2 request limit.")
	return _success({"pending_request": {
		"idempotency_key": LocalSaveCodecScript.create_uuid(),
		"request_id": request_id,
		"payload": payload,
		"first_sequence": int((operations[0] as Dictionary).get("device_sequence", 0)),
		"last_sequence": int((operations[-1] as Dictionary).get("device_sequence", 0)),
	}})


func _send_pending_request(pending: Dictionary, session: Dictionary) -> void:
	var base_url := str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).trim_suffix("/")
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % str(session.get("access_token", "")),
		"Content-Type: application/json",
		"Idempotency-Key: %s" % str(pending.get("idempotency_key", "")),
	])
	_busy = true
	_request_mode = "sync"
	_active_session = session.duplicate(true)
	_request_store = _store
	var request_error := _http_request.request(
		"%s/v2/saves/sync" % base_url,
		headers,
		HTTPClient.METHOD_POST,
		str(pending.get("payload", ""))
	)
	if request_error != OK:
		_busy = false
		_schedule_retry()


func _on_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_busy = false
	if _request_store != _store:
		# The response belongs to a save that is no longer active. Re-evaluate the active save
		# instead of leaving its pending sync waiting for a response that never arrives.
		request_background_sync.call_deferred()
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		if _request_mode.begins_with("refresh_"):
			# Refresh tokens rotate on use. After an unknown transport outcome, replaying the
			# credential could trigger the backend's reuse/theft response and revoke the family.
			_stop_terminal_retry("auth.refresh_result_unknown")
		else:
			_schedule_retry()
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	_record_response_diagnostics(parsed)
	if _request_mode.begins_with("refresh_"):
		_handle_refresh_response(response_code, parsed)
		return
	if _request_mode == "state":
		_handle_state_response(response_code, headers, parsed)
		return
	if response_code == 401:
		_refresh_session_and_replay()
		return
	if response_code == 409 and _response_error_code(parsed) == "save_sync.cursor_mismatch":
		_request_remote_state(_active_session)
		return
	if response_code == 429 or response_code >= 500:
		_schedule_retry(_retry_after_seconds(headers) if response_code == 429 else -1)
		return
	if response_code != 200 or not (parsed is Dictionary):
		_stop_terminal_retry(_response_error_code(parsed), _response_correlation_id(parsed))
		return
	var apply_result := _apply_response(parsed as Dictionary)
	if not bool(apply_result.get("ok", false)):
		_schedule_retry()
		return
	reconciliation_applied.emit()
	call_deferred("request_background_sync")


func _request_remote_state(session: Dictionary, after_refresh: bool = false) -> void:
	if not after_refresh:
		_state_refresh_attempted = false
	var base_url := str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).trim_suffix("/")
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % str(session.get("access_token", "")),
	])
	_busy = true
	_request_mode = "state"
	_active_session = session.duplicate(true)
	_request_store = _store
	var request_error := _http_request.request(
		"%s/v2/saves/state" % base_url,
		headers,
		HTTPClient.METHOD_GET
	)
	if request_error != OK:
		_busy = false
		_schedule_retry()


func _handle_state_response(
	response_code: int,
	headers: PackedStringArray,
	parsed: Variant
) -> void:
	if response_code == 401:
		_refresh_session_and_read_state()
		return
	if response_code == 429 or response_code >= 500:
		_schedule_retry(_retry_after_seconds(headers) if response_code == 429 else -1)
		return
	if response_code != 200 or not (parsed is Dictionary):
		_stop_terminal_retry(_response_error_code(parsed), _response_correlation_id(parsed))
		return
	var result := _apply_state_response(parsed as Dictionary)
	if not bool(result.get("ok", false)):
		_schedule_retry()
		return
	reconciliation_applied.emit()
	call_deferred("request_background_sync")


func _apply_state_response(envelope: Dictionary) -> Dictionary:
	if not (envelope.get("meta") is Dictionary and envelope.get("data") is Dictionary):
		return _error("Save state response envelope is malformed.")
	var meta := envelope.get("meta", {}) as Dictionary
	var data := envelope.get("data", {}) as Dictionary
	if (
		not SUPPORTED_RESPONSE_PROTOCOL_VERSIONS.has(str(meta.get("protocol_version", "")))
		or not (data.get("checkpoint") is Dictionary)
		or not (data.get("device_cursors") is Array)
		or not (data.get("capabilities") is Dictionary)
	):
		return _error("Save state response is malformed.")
	var capabilities := data.get("capabilities", {}) as Dictionary
	if (
		not bool(capabilities.get("unrestricted_offline_play", false))
		or int(capabilities.get("maximum_operations_per_request", 0)) != MAX_OPERATIONS
		or int(capabilities.get("maximum_request_bytes", 0)) != MAX_REQUEST_BYTES
	):
		return _error("The server does not advertise the required v2 save capability.")
	var checkpoint := data.get("checkpoint", {}) as Dictionary
	if (
		str(checkpoint.get("format", "")) != "save-checkpoint/2"
		or str(checkpoint.get("player_id", "")) != _active_player_id()
	):
		return _error("Save state checkpoint belongs to another player.")
	var remote_cursor := {}
	for raw_cursor in data.get("device_cursors", []) as Array:
		if (
			raw_cursor is Dictionary
			and str((raw_cursor as Dictionary).get("device_id", "")) == _session_store.get_device_id()
		):
			remote_cursor = (raw_cursor as Dictionary).duplicate(true)
			break
	if remote_cursor.is_empty():
		remote_cursor = {
			"device_id": _session_store.get_device_id(),
			"acknowledged_sequence": 0,
			"acknowledged_hash": null,
		}
	var remaining := []
	for operation in _store.get_journal():
		if int((operation as Dictionary).get("device_sequence", 0)) > int(remote_cursor.get("acknowledged_sequence", 0)):
			remaining.append(operation)
	var mapped_snapshot = _checkpoint_mapper.call(
		checkpoint.duplicate(true),
		_store.get_snapshot(),
		remaining
	)
	if not (mapped_snapshot is Dictionary):
		return _error("Checkpoint mapper rejected the restored state.")
	return _store.apply_reconciliation(
		mapped_snapshot as Dictionary,
		remote_cursor,
		checkpoint,
		[]
	)


func _refresh_session_and_replay() -> void:
	var sync := _store.get_sync_metadata()
	var pending := sync.get("pending_request", {}) as Dictionary
	if bool(pending.get("refresh_attempted", false)):
		_stop_terminal_retry("auth.session_refresh_failed")
		return
	if str(_active_session.get("refresh_token", "")).is_empty():
		_stop_terminal_retry("auth.refresh_token_missing")
		return
	pending["refresh_attempted"] = true
	sync["pending_request"] = pending
	if not bool(_store.persist_sync_metadata(sync).get("ok", false)):
		return
	_request_session_refresh(_active_session, "sync")


func _refresh_session_and_read_state() -> void:
	if _state_refresh_attempted:
		_stop_terminal_retry("auth.session_refresh_failed")
		return
	if str(_active_session.get("refresh_token", "")).is_empty():
		_stop_terminal_retry("auth.refresh_token_missing")
		return
	_state_refresh_attempted = true
	_request_session_refresh(_active_session, "state")


func _request_session_refresh(session: Dictionary, replay_mode: String) -> void:
	var request_id := LocalSaveCodecScript.create_uuid()
	_refresh_request_id = request_id
	var envelope := {
		"meta": {
			"protocol_version": "1.1",
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
		"data": {
			"refresh_token": str(session.get("refresh_token", "")),
		},
	}
	var base_url := str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).trim_suffix("/")
	_busy = true
	_request_mode = "refresh_%s" % replay_mode
	_active_session = session.duplicate(true)
	_request_store = _store
	var request_error := _http_request.request(
		"%s/v1/sessions/refresh" % base_url,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(envelope)
	)
	if request_error != OK:
		_busy = false
		_schedule_retry()


func _handle_refresh_response(response_code: int, parsed: Variant) -> void:
	var replay_mode := _request_mode.trim_prefix("refresh_")
	if response_code == 429 or response_code >= 500:
		_stop_terminal_retry("auth.session_refresh_failed")
		return
	if response_code != 200 or not (parsed is Dictionary):
		_stop_terminal_retry(_response_error_code(parsed), _response_correlation_id(parsed))
		return
	var refresh_result := _validate_and_store_refresh_response(parsed as Dictionary)
	if not bool(refresh_result.get("ok", false)):
		_stop_terminal_retry(
			str(refresh_result.get("error_code", "auth.refresh_response_malformed")),
			_response_correlation_id(parsed)
		)
		return
	var refreshed_session := refresh_result.get("session", {}) as Dictionary
	if replay_mode == "state":
		_request_remote_state(refreshed_session, true)
	else:
		var pending := _store.get_sync_metadata().get("pending_request", {}) as Dictionary
		_send_pending_request(pending, refreshed_session)


func _validate_and_store_refresh_response(document: Dictionary) -> Dictionary:
	var meta = document.get("meta")
	var data = document.get("data")
	if not (meta is Dictionary and data is Dictionary):
		return _error_code("auth.refresh_response_malformed")
	var response_meta := meta as Dictionary
	if (
		str(response_meta.get("protocol_version", "")) != "1.1"
		or str(response_meta.get("request_id", "")) != _refresh_request_id
	):
		return _error_code("auth.refresh_response_malformed")
	var response := data as Dictionary
	var tokens = response.get("tokens")
	if (
		str(response.get("player_id", "")) != _active_player_id()
		or str(response.get("device_id", "")) != _session_store.get_device_id()
		or not LocalSaveCodecScript.is_uuid(response.get("session_id"))
		or not (tokens is Dictionary)
	):
		return _error_code("auth.refresh_response_malformed")
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
		return _error_code("auth.refresh_response_malformed")
	var store_result := _session_store.store_session(_active_player_id(), refreshed_session)
	if not bool(store_result.get("ok", false)):
		return _error_code("auth.secure_session_write_failed")
	return _success({"session": refreshed_session})


func _response_error_code(parsed: Variant) -> String:
	if not (parsed is Dictionary):
		return ""
	var document := parsed as Dictionary
	var error = document.get("error")
	if error is Dictionary:
		return str((error as Dictionary).get("code", ""))
	return str(document.get("code", ""))


func _response_correlation_id(parsed: Variant) -> String:
	if not (parsed is Dictionary):
		return ""
	var meta = (parsed as Dictionary).get("meta")
	if not (meta is Dictionary):
		return ""
	return str((meta as Dictionary).get("correlation_id", ""))


func _apply_response(envelope: Dictionary) -> Dictionary:
	if not (envelope.get("meta") is Dictionary and envelope.get("data") is Dictionary):
		return _error("Save sync response envelope is malformed.")
	var meta := envelope.get("meta", {}) as Dictionary
	var data := envelope.get("data", {}) as Dictionary
	var sync := _store.get_sync_metadata()
	var pending := sync.get("pending_request", {}) as Dictionary
	if (
		not SUPPORTED_RESPONSE_PROTOCOL_VERSIONS.has(str(meta.get("protocol_version", "")))
		or str(meta.get("request_id", "")) != str(pending.get("request_id", ""))
		or not (data.get("acknowledged_cursor") is Dictionary)
		or not (data.get("checkpoint") is Dictionary)
		or not (data.get("adjustments") is Array)
		or not (data.get("continuation") is Dictionary)
	):
		return _error("Save sync response does not match the pending request.")
	var cursor := data.get("acknowledged_cursor", {}) as Dictionary
	var checkpoint := data.get("checkpoint", {}) as Dictionary
	if (
		str(cursor.get("device_id", "")) != _session_store.get_device_id()
		or int(cursor.get("acknowledged_sequence", 0)) < int(pending.get("last_sequence", 0))
		or str(checkpoint.get("format", "")) != "save-checkpoint/2"
		or str(checkpoint.get("player_id", "")) != _active_player_id()
	):
		return _error("Save sync cursor or checkpoint is invalid.")
	var remaining := []
	for operation in _store.get_journal():
		if int((operation as Dictionary).get("device_sequence", 0)) > int(cursor.get("acknowledged_sequence", 0)):
			remaining.append(operation)
	var mapped_snapshot = _checkpoint_mapper.call(
		checkpoint.duplicate(true),
		_store.get_snapshot(),
		remaining
	)
	if not (mapped_snapshot is Dictionary):
		return _error("Checkpoint mapper rejected the server response.")
	var result := _store.apply_reconciliation(
		mapped_snapshot as Dictionary,
		cursor,
		checkpoint,
		data.get("adjustments", []) as Array
	)
	if bool(result.get("ok", false)):
		_store.compact_journal()
	return result


func _schedule_retry(retry_after_seconds: int = -1) -> void:
	if _store == null:
		return
	var sync := _store.get_sync_metadata()
	var attempt := int(sync.get("retry_attempt", 0)) + 1
	var base_index := mini(attempt - 1, RETRY_BASE_MILLISECONDS.size() - 1)
	var maximum_delay: int = RETRY_BASE_MILLISECONDS[base_index]
	if attempt > RETRY_BASE_MILLISECONDS.size():
		maximum_delay = mini(
			RETRY_BASE_MILLISECONDS[-1] * (1 << mini(attempt - RETRY_BASE_MILLISECONDS.size(), 3)),
			RETRY_CAP_MILLISECONDS
		)
	var delay_milliseconds := (
		retry_after_seconds * 1000
		if retry_after_seconds >= 0
		else randi_range(0, maximum_delay)
	)
	sync["retry_attempt"] = attempt
	sync["next_retry_unix"] = int(Time.get_unix_time_from_system()) + maxi(
		ceili(float(delay_milliseconds) / 1000.0),
		1
	)
	if bool(_store.persist_sync_metadata(sync).get("ok", false)):
		_schedule_persisted_retry()


func _retry_after_seconds(headers: PackedStringArray) -> int:
	for header in headers:
		var separator := header.find(":")
		if separator < 0:
			continue
		if header.left(separator).strip_edges().to_lower() == "retry-after":
			return maxi(int(header.substr(separator + 1).strip_edges()), 0)
	return -1


func _schedule_persisted_retry() -> void:
	if _retry_timer == null or _store == null or not _retry_timer.is_inside_tree():
		return
	var retry_unix := int(_store.get_sync_metadata().get("next_retry_unix", 0))
	if retry_unix <= 0:
		return
	_retry_timer.start(maxf(float(retry_unix - int(Time.get_unix_time_from_system())), 0.1))


func _stop_terminal_retry(error_code: String = "save_sync.terminal", correlation_id: String = "") -> void:
	var sync := _store.get_sync_metadata()
	sync["next_retry_unix"] = 0
	sync["terminal_error"] = {
		"code": error_code if not error_code.is_empty() else "save_sync.terminal",
		"correlation_id": correlation_id,
		"recorded_at": LocalSaveCodecScript.iso_timestamp(),
	}
	_store.persist_sync_metadata(sync)


func _record_response_diagnostics(parsed: Variant) -> void:
	if _store == null:
		return
	var correlation_id := _response_correlation_id(parsed)
	if correlation_id.is_empty():
		return
	var sync := _store.get_sync_metadata()
	sync["last_correlation_id"] = correlation_id
	_store.persist_sync_metadata(sync)


func _active_player_id() -> String:
	var save_namespace := _store.get_namespace()
	return str(save_namespace.get("player_id", "")) if str(save_namespace.get("kind", "")) == "player" else ""


func _success(data: Dictionary = {}) -> Dictionary:
	var response := {"ok": true, "error": ""}
	response.merge(data, true)
	return response


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}


func _error_code(code: String) -> Dictionary:
	return {"ok": false, "error": code, "error_code": code}
