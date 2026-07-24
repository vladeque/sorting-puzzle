extends Node
class_name GuestSessionBootstrapService

signal guest_registered(result: Dictionary)

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")
const PROTOCOL_VERSION := "1.1"
const PROOF_PAYLOAD_VERSION := "guest-registration-proof/1"
const REQUEST_TIMEOUT_SECONDS := 30.0
const SERVER_URL_SETTING := "application/config/backend_base_url"
const FEATURE_SETTING := "application/config/save_sync_v2_enabled"
const APP_VERSION_SETTING := "application/config/version"
const APP_BUILD_SETTING := "application/config/build_number"
const RETRY_DELAYS_MILLISECONDS := [500, 1000, 2000, 4000, 8000, 16000, 30000]

var _store
var _session_store
var _coordinator
var _http_request: HTTPRequest
var _retry_timer: Timer
var _busy := false
var _request_store
var _content_provenance_valid := true


func configure(store, session_store, coordinator, content_provenance_valid: bool = true) -> void:
	_store = store
	_session_store = session_store
	_coordinator = coordinator
	_content_provenance_valid = content_provenance_valid
	if _http_request == null:
		_http_request = HTTPRequest.new()
		_http_request.timeout = REQUEST_TIMEOUT_SECONDS
		_http_request.request_completed.connect(_on_request_completed)
		add_child(_http_request)
	if _retry_timer == null:
		_retry_timer = Timer.new()
		_retry_timer.one_shot = true
		_retry_timer.timeout.connect(request_registration)
		add_child(_retry_timer)
	_schedule_persisted_retry()


func replace_store(store) -> void:
	_store = store
	_busy = false
	_request_store = null
	if _http_request != null:
		_http_request.cancel_request()
	_schedule_persisted_retry()


func request_registration() -> void:
	if _busy or not _can_register():
		return
	var sync: Dictionary = _store.get_sync_metadata()
	var registration := sync.get("guest_registration", {}) as Dictionary
	if not (registration.get("terminal_error", {}) as Dictionary).is_empty():
		return
	var now_unix := int(Time.get_unix_time_from_system())
	if int(registration.get("next_retry_unix", 0)) > now_unix:
		_schedule_persisted_retry()
		return
	if (
		str(registration.get("phase", "")) == "bootstrap"
		and int(registration.get("challenge_expires_unix", 0)) <= now_unix
	):
		registration = {}
		sync["guest_registration"] = registration
		if not bool(_store.persist_sync_metadata(sync).get("ok", false)):
			return
	if registration.is_empty():
		registration = _build_challenge_request()
		sync["guest_registration"] = registration
		if not bool(_store.persist_sync_metadata(sync).get("ok", false)):
			return
	_send_registration_request(registration)


func _can_register() -> bool:
	if _store == null or _session_store == null or _coordinator == null:
		return false
	if not _content_provenance_valid:
		return false
	if str((_store.get_namespace() as Dictionary).get("kind", "")) != "installation_guest":
		return false
	if not bool(ProjectSettings.get_setting(FEATURE_SETTING, false)):
		return false
	if str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).strip_edges().is_empty():
		return false
	return (
		_session_store.can_synchronize()
		and not _session_store.get_installation_public_key_der_base64().is_empty()
	)


func _build_challenge_request() -> Dictionary:
	var request_id := LocalSaveCodecScript.create_uuid()
	var envelope := {
		"meta": _request_meta(request_id),
		"data": {
			"installation_key": {
				"algorithm": "ecdsa_p256_sha256",
				"public_key": _session_store.get_installation_public_key_der_base64(),
			},
			"device_model": _device_model(),
			"os_version": _os_version(),
		},
	}
	return {
		"phase": "challenge",
		"request_id": request_id,
		"idempotency_key": "",
		"payload": JSON.stringify(envelope),
		"retry_attempt": 0,
		"next_retry_unix": 0,
		"terminal_error": {},
	}


func _build_bootstrap_request(challenge: Dictionary) -> Dictionary:
	var request_id := LocalSaveCodecScript.create_uuid()
	var idempotency_key := LocalSaveCodecScript.create_uuid()
	var public_key: String = _session_store.get_installation_public_key_der_base64()
	var public_key_bytes: PackedByteArray = Marshalls.base64_to_raw(public_key)
	if public_key_bytes.is_empty():
		return {}
	var installation_key_hash := _sha256_bytes(public_key_bytes)
	var proof_payload := LocalSaveCodecScript.canonical_json([
		PROOF_PAYLOAD_VERSION,
		str(challenge.get("challenge_id", "")),
		str(challenge.get("nonce", "")),
		request_id,
		idempotency_key,
		_session_store.get_device_id(),
		installation_key_hash,
	])
	var signature_result: Dictionary = _session_store.sign_installation_payload(proof_payload)
	if not bool(signature_result.get("ok", false)):
		return {}
	var envelope := {
		"meta": _request_meta(request_id),
		"data": {
			"installation_key": {
				"algorithm": "ecdsa_p256_sha256",
				"public_key": public_key,
			},
			"challenge_id": str(challenge.get("challenge_id", "")),
			"nonce": str(challenge.get("nonce", "")),
			"signature": str(signature_result.get("signature", "")),
			"device_model": _device_model(),
			"os_version": _os_version(),
		},
	}
	return {
		"phase": "bootstrap",
		"request_id": request_id,
		"idempotency_key": idempotency_key,
		"payload": JSON.stringify(envelope),
		"challenge_expires_unix": LocalSaveCodecScript.unix_from_timestamp(
			challenge.get("expires_at")
		),
		"retry_attempt": 0,
		"next_retry_unix": 0,
		"terminal_error": {},
	}


func _request_meta(request_id: String) -> Dictionary:
	return {
		"protocol_version": PROTOCOL_VERSION,
		"request_id": request_id,
		"device_id": _session_store.get_device_id(),
		"app": {
			"platform": "android" if OS.get_name() == "Android" else "ios",
			"version": str(ProjectSettings.get_setting(APP_VERSION_SETTING, "1.0.0")),
			"build": maxi(int(ProjectSettings.get_setting(APP_BUILD_SETTING, 1)), 1),
		},
		"locale": TranslationServer.get_locale().replace("_", "-"),
		"client_time": LocalSaveCodecScript.iso_timestamp(),
	}


func _send_registration_request(registration: Dictionary) -> void:
	var phase := str(registration.get("phase", ""))
	if phase != "challenge" and phase != "bootstrap":
		_stop_terminal("guest.registration_state_invalid")
		return
	var base_url := str(ProjectSettings.get_setting(SERVER_URL_SETTING, "")).trim_suffix("/")
	var headers := PackedStringArray(["Content-Type: application/json"])
	if phase == "bootstrap":
		headers.append("Idempotency-Key: %s" % str(registration.get("idempotency_key", "")))
	_busy = true
	_request_store = _store
	var request_error := _http_request.request(
		"%s/v1/sessions/guest%s" % [base_url, "/challenge" if phase == "challenge" else ""],
		headers,
		HTTPClient.METHOD_POST,
		str(registration.get("payload", ""))
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
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_schedule_retry()
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	_record_response_diagnostics(response_code, parsed)
	if response_code == 429 or response_code >= 500:
		_schedule_retry(_retry_after_seconds(headers) if response_code == 429 else -1)
		return
	if response_code != 200 or not (parsed is Dictionary):
		if _response_error_code(parsed) == "auth.guest_challenge_expired":
			_restart_challenge()
		else:
			_stop_terminal(_response_error_code(parsed), _response_correlation_id(parsed))
		return
	var registration := (
		_store.get_sync_metadata().get("guest_registration", {}) as Dictionary
	)
	if str(registration.get("phase", "")) == "challenge":
		_handle_challenge_response(parsed as Dictionary, registration)
	else:
		_handle_bootstrap_response(parsed as Dictionary, registration)


func _handle_challenge_response(envelope: Dictionary, registration: Dictionary) -> void:
	var meta = envelope.get("meta")
	var data = envelope.get("data")
	if not (meta is Dictionary and data is Dictionary):
		_schedule_retry()
		return
	var response_meta := meta as Dictionary
	var challenge := data as Dictionary
	if (
		str(response_meta.get("protocol_version", "")) != PROTOCOL_VERSION
		or str(response_meta.get("request_id", "")) != str(registration.get("request_id", ""))
		or not LocalSaveCodecScript.is_uuid(challenge.get("challenge_id"))
		or not _is_base64url_nonce(str(challenge.get("nonce", "")))
		or str(challenge.get("signature_payload_version", "")) != PROOF_PAYLOAD_VERSION
		or LocalSaveCodecScript.unix_from_timestamp(challenge.get("expires_at")) <= int(Time.get_unix_time_from_system())
	):
		_schedule_retry()
		return
	var bootstrap := _build_bootstrap_request(challenge)
	if bootstrap.is_empty():
		_stop_terminal("guest.installation_proof_failed")
		return
	var sync: Dictionary = _store.get_sync_metadata()
	sync["guest_registration"] = bootstrap
	if not bool(_store.persist_sync_metadata(sync).get("ok", false)):
		return
	_send_registration_request(bootstrap)


func _handle_bootstrap_response(envelope: Dictionary, registration: Dictionary) -> void:
	var meta = envelope.get("meta")
	var data = envelope.get("data")
	if not (meta is Dictionary and data is Dictionary):
		_schedule_retry()
		return
	var response_meta := meta as Dictionary
	var response := data as Dictionary
	var tokens = response.get("tokens")
	if (
		str(response_meta.get("protocol_version", "")) != PROTOCOL_VERSION
		or str(response_meta.get("request_id", "")) != str(registration.get("request_id", ""))
		or not LocalSaveCodecScript.is_uuid(response.get("player_id"))
		or str(response.get("device_id", "")) != _session_store.get_device_id()
		or not LocalSaveCodecScript.is_uuid(response.get("session_id"))
		or str(response.get("authentication_level", "")) != "guest"
		or not (tokens is Dictionary)
	):
		_schedule_retry()
		return
	var token_data := tokens as Dictionary
	var session := {
		"session_id": str(response.get("session_id", "")),
		"authentication_level": str(response.get("authentication_level", "guest")),
		"access_token": str(token_data.get("access_token", "")),
		"access_token_expires_at": str(token_data.get("access_token_expires_at", "")),
		"refresh_token": str(token_data.get("refresh_token", "")),
		"refresh_token_expires_at": str(token_data.get("refresh_token_expires_at", "")),
	}
	if str(session.get("access_token", "")).is_empty() or str(session.get("refresh_token", "")).is_empty():
		_schedule_retry()
		return
	var bind_result: Dictionary = _coordinator.bind_registered_guest(
		str(response.get("player_id", "")),
		session
	)
	if not bool(bind_result.get("ok", false)):
		_stop_terminal("guest.local_rebind_failed", _response_correlation_id(envelope))
		return
	var player_store = _coordinator.get_store()
	_store = player_store
	_request_store = player_store
	var sync: Dictionary = player_store.get_sync_metadata()
	sync.erase("guest_registration")
	if not bool(player_store.persist_sync_metadata(sync).get("ok", false)):
		push_warning("Guest registration completed but retry metadata cleanup was deferred.")
	guest_registered.emit(bind_result)


func _restart_challenge() -> void:
	var sync: Dictionary = _store.get_sync_metadata()
	sync["guest_registration"] = {}
	if bool(_store.persist_sync_metadata(sync).get("ok", false)):
		call_deferred("request_registration")


func _schedule_retry(retry_after_seconds: int = -1) -> void:
	if _store == null:
		return
	var sync: Dictionary = _store.get_sync_metadata()
	var registration := sync.get("guest_registration", {}) as Dictionary
	var attempt := int(registration.get("retry_attempt", 0)) + 1
	var maximum_delay: int = RETRY_DELAYS_MILLISECONDS[
		mini(attempt - 1, RETRY_DELAYS_MILLISECONDS.size() - 1)
	]
	var delay_milliseconds := (
		retry_after_seconds * 1000
		if retry_after_seconds >= 0
		else randi_range(0, maximum_delay)
	)
	registration["retry_attempt"] = attempt
	registration["next_retry_unix"] = int(Time.get_unix_time_from_system()) + maxi(
		ceili(float(delay_milliseconds) / 1000.0),
		1
	)
	sync["guest_registration"] = registration
	if bool(_store.persist_sync_metadata(sync).get("ok", false)):
		_schedule_persisted_retry()


func _schedule_persisted_retry() -> void:
	if _retry_timer == null or _store == null:
		return
	var registration := (
		_store.get_sync_metadata().get("guest_registration", {}) as Dictionary
	)
	var retry_unix := int(registration.get("next_retry_unix", 0))
	if retry_unix <= 0:
		return
	_retry_timer.start(maxf(float(retry_unix - int(Time.get_unix_time_from_system())), 0.1))


func _stop_terminal(error_code: String, correlation_id: String = "") -> void:
	if _store == null:
		return
	var sync: Dictionary = _store.get_sync_metadata()
	var registration := sync.get("guest_registration", {}) as Dictionary
	registration["next_retry_unix"] = 0
	registration["terminal_error"] = {
		"code": error_code if not error_code.is_empty() else "guest.registration_failed",
		"correlation_id": correlation_id,
		"recorded_at": LocalSaveCodecScript.iso_timestamp(),
	}
	sync["guest_registration"] = registration
	_store.persist_sync_metadata(sync)


func _record_response_diagnostics(response_code: int, parsed: Variant) -> void:
	if _store == null:
		return
	var correlation_id := _response_correlation_id(parsed)
	if correlation_id.is_empty():
		return
	var sync: Dictionary = _store.get_sync_metadata()
	sync["identity_diagnostics"] = {
		"last_correlation_id": correlation_id,
		"last_response_code": response_code,
		"recorded_at": LocalSaveCodecScript.iso_timestamp(),
	}
	_store.persist_sync_metadata(sync)


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


func _retry_after_seconds(headers: PackedStringArray) -> int:
	for header in headers:
		var separator := header.find(":")
		if separator < 0:
			continue
		if header.left(separator).strip_edges().to_lower() == "retry-after":
			return maxi(int(header.substr(separator + 1).strip_edges()), 0)
	return -1


func _sha256_bytes(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value) != OK:
		return ""
	return context.finish().hex_encode()


func _device_model() -> String:
	var value := OS.get_model_name().strip_edges()
	return (value if not value.is_empty() else "unknown-device").left(128)


func _os_version() -> String:
	var value := OS.get_version().strip_edges()
	return (value if not value.is_empty() else "unknown-os").left(64)


func _is_base64url_nonce(value: String) -> bool:
	var pattern := RegEx.new()
	return pattern.compile("^[A-Za-z0-9_-]{43}$") == OK and pattern.search(value) != null
