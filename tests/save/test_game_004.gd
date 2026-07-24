extends SceneTree

const Codec := preload("res://scripts/save/local_save_codec.gd")
const SessionStore := preload("res://scripts/save/secure_session_store.gd")
const SaveStore := preload("res://scripts/save/local_save_store.gd")
const SyncService := preload("res://scripts/save/save_sync_service.gd")
const GuestBootstrapService := preload("res://scripts/save/guest_session_bootstrap_service.gd")
const AccountCoordinator := preload("res://scripts/save/account_save_coordinator.gd")

class FakeGuestSession:
	extends RefCounted

	var device_id := "00000000-0000-4000-8000-000000000201"

	func get_installation_public_key_der_base64() -> String:
		var key_bytes := PackedByteArray()
		key_bytes.resize(91)
		return Marshalls.raw_to_base64(key_bytes)

	func get_device_id() -> String:
		return device_id

	func sign_installation_payload(payload: String) -> Dictionary:
		var signature := PackedByteArray()
		signature.resize(70)
		return {"ok": true, "signature": Marshalls.raw_to_base64(signature)}

class RecordingCoordinator:
	extends RefCounted

	var bind_calls := 0
	var last_player_id := ""

	func bind_registered_guest(player_id: String, session: Dictionary) -> Dictionary:
		bind_calls += 1
		last_player_id = player_id
		return {
			"ok": true,
			"snapshot": {},
			"preferences": {},
			"namespace": {"kind": "player", "player_id": player_id},
		}

	func get_store():
		return null

var _failures := PackedStringArray()
var _session


func _init() -> void:
	_session = SessionStore.new()
	_check(bool(_session.initialize().get("ok", false)), "installation identity initializes")
	_test_malformed_challenge_response_retries_without_terminal_state()
	_test_malformed_error_envelope_is_terminal_without_crash()
	_test_expired_challenge_restarts_without_terminal_state()
	_test_binding_mismatched_bootstrap_response_does_not_bind()
	_test_terminal_bootstrap_error_records_code_and_correlation_id()
	_test_malformed_refresh_response_is_terminal_and_preserves_session()
	_test_replayed_refresh_reuse_is_terminal_and_preserves_session()
	_test_binding_mismatched_refresh_response_is_terminal()
	_test_single_refresh_attempt_guard()
	_test_guest_restart_resumes_same_player_without_second_guest()

	if _failures.is_empty():
		print("GAME-004 tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_malformed_challenge_response_retries_without_terminal_state() -> void:
	var store = SaveStore.new(_session)
	store.open_namespace(_guest_namespace(), _snapshot(), _preferences())
	var registration := {
		"phase": "challenge",
		"request_id": Codec.create_uuid(),
		"idempotency_key": "",
		"payload": "{}",
		"retry_attempt": 0,
		"next_retry_unix": 0,
		"terminal_error": {},
	}
	var sync := store.get_sync_metadata()
	sync["guest_registration"] = registration
	store.persist_sync_metadata(sync)

	var service = GuestBootstrapService.new()
	service.set("_store", store)
	service.set("_request_store", store)
	service.set("_session_store", FakeGuestSession.new())
	service.set("_coordinator", RecordingCoordinator.new())

	var body := JSON.stringify({"meta": {"protocol_version": "1.1"}}).to_utf8_buffer()
	service.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), body)

	var updated := store.get_sync_metadata().get("guest_registration", {}) as Dictionary
	_check(int(updated.get("retry_attempt", 0)) == 1, "structurally malformed challenge response schedules a retry")
	_check(
		(updated.get("terminal_error", {}) as Dictionary).is_empty(),
		"structurally malformed challenge response is not terminal"
	)
	service.free()


func _test_malformed_error_envelope_is_terminal_without_crash() -> void:
	var store = SaveStore.new(_session)
	store.open_namespace(_guest_namespace(), _snapshot(), _preferences())
	var registration := {
		"phase": "bootstrap",
		"request_id": Codec.create_uuid(),
		"idempotency_key": Codec.create_uuid(),
		"payload": "{}",
		"challenge_expires_unix": 9999999999,
		"retry_attempt": 0,
		"next_retry_unix": 0,
		"terminal_error": {},
	}
	var sync := store.get_sync_metadata()
	sync["guest_registration"] = registration
	store.persist_sync_metadata(sync)

	var service = GuestBootstrapService.new()
	service.set("_store", store)
	service.set("_request_store", store)
	service.set("_session_store", FakeGuestSession.new())
	service.set("_coordinator", RecordingCoordinator.new())

	var body := JSON.stringify("unexpected-response-shape").to_utf8_buffer()
	service.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 400, PackedStringArray(), body)

	var terminal := (
		(store.get_sync_metadata().get("guest_registration", {}) as Dictionary).get("terminal_error", {}) as Dictionary
	)
	_check(
		str(terminal.get("code", "")) == "guest.registration_failed",
		"a non-envelope-shaped bootstrap response fails safely with a stable fallback error code"
	)
	service.free()


func _test_expired_challenge_restarts_without_terminal_state() -> void:
	var store = SaveStore.new(_session)
	store.open_namespace(_guest_namespace(), _snapshot(), _preferences())
	var registration := {
		"phase": "bootstrap",
		"request_id": Codec.create_uuid(),
		"idempotency_key": Codec.create_uuid(),
		"payload": "{}",
		"challenge_expires_unix": 9999999999,
		"retry_attempt": 2,
		"next_retry_unix": 0,
		"terminal_error": {},
	}
	var sync := store.get_sync_metadata()
	sync["guest_registration"] = registration
	store.persist_sync_metadata(sync)

	var service = GuestBootstrapService.new()
	service.set("_store", store)
	service.set("_request_store", store)
	service.set("_session_store", FakeGuestSession.new())
	service.set("_coordinator", RecordingCoordinator.new())

	var body := JSON.stringify({
		"error": {"code": "auth.guest_challenge_expired"},
		"meta": {"correlation_id": "00000000-0000-4000-8000-000000000901"},
	}).to_utf8_buffer()
	service.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 409, PackedStringArray(), body)

	var updated := store.get_sync_metadata().get("guest_registration", {}) as Dictionary
	_check(updated.is_empty(), "an expired challenge restarts the challenge/bootstrap cycle instead of going terminal")
	service.free()


func _test_binding_mismatched_bootstrap_response_does_not_bind() -> void:
	var store = SaveStore.new(_session)
	store.open_namespace(_guest_namespace(), _snapshot(), _preferences())
	var request_id := Codec.create_uuid()
	var registration := {
		"phase": "bootstrap",
		"request_id": request_id,
		"idempotency_key": Codec.create_uuid(),
		"payload": "{}",
		"challenge_expires_unix": 9999999999,
		"retry_attempt": 0,
		"next_retry_unix": 0,
		"terminal_error": {},
	}
	var sync := store.get_sync_metadata()
	sync["guest_registration"] = registration
	store.persist_sync_metadata(sync)

	var coordinator := RecordingCoordinator.new()
	var service = GuestBootstrapService.new()
	service.set("_store", store)
	service.set("_request_store", store)
	service.set("_session_store", FakeGuestSession.new())
	service.set("_coordinator", coordinator)

	var body := JSON.stringify({
		"meta": {
			"protocol_version": "1.1",
			"request_id": request_id,
			"correlation_id": Codec.create_uuid(),
		},
		"data": {
			"player_id": Codec.create_uuid(),
			"device_id": "00000000-0000-4000-8000-000000000999",
			"session_id": Codec.create_uuid(),
			"authentication_level": "guest",
			"tokens": {"access_token": "token", "refresh_token": "refresh"},
		},
	}).to_utf8_buffer()
	service.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), body)

	_check(coordinator.bind_calls == 0, "a device-binding-mismatched bootstrap response is never bound to a player")
	var updated := store.get_sync_metadata().get("guest_registration", {}) as Dictionary
	_check(
		int(updated.get("retry_attempt", 0)) == 1,
		"a device-binding-mismatched bootstrap response retries instead of accepting a foreign device"
	)
	service.free()


func _test_terminal_bootstrap_error_records_code_and_correlation_id() -> void:
	var store = SaveStore.new(_session)
	store.open_namespace(_guest_namespace(), _snapshot(), _preferences())
	var registration := {
		"phase": "bootstrap",
		"request_id": Codec.create_uuid(),
		"idempotency_key": Codec.create_uuid(),
		"payload": "{}",
		"challenge_expires_unix": 9999999999,
		"retry_attempt": 0,
		"next_retry_unix": 0,
		"terminal_error": {},
	}
	var sync := store.get_sync_metadata()
	sync["guest_registration"] = registration
	store.persist_sync_metadata(sync)

	var service = GuestBootstrapService.new()
	service.set("_store", store)
	service.set("_request_store", store)
	service.set("_session_store", FakeGuestSession.new())
	service.set("_coordinator", RecordingCoordinator.new())

	var correlation_id := "00000000-0000-4000-8000-000000000777"
	var body := JSON.stringify({
		"error": {"code": "guest.installation_conflict"},
		"meta": {"correlation_id": correlation_id},
	}).to_utf8_buffer()
	service.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 422, PackedStringArray(), body)

	var registration_after := store.get_sync_metadata().get("guest_registration", {}) as Dictionary
	var terminal := registration_after.get("terminal_error", {}) as Dictionary
	_check(
		str(terminal.get("code", "")) == "guest.installation_conflict",
		"a terminal bootstrap error records the server's stable error code"
	)
	_check(
		str(terminal.get("correlation_id", "")) == correlation_id,
		"a terminal bootstrap error records the server correlation id for support diagnostics"
	)
	var identity_diagnostics := store.get_sync_metadata().get("identity_diagnostics", {}) as Dictionary
	_check(
		str(identity_diagnostics.get("last_correlation_id", "")) == correlation_id,
		"identity diagnostics expose the last server correlation id non-secretly"
	)
	service.free()


func _test_malformed_refresh_response_is_terminal_and_preserves_session() -> void:
	var player_id := Codec.create_uuid()
	var store = SaveStore.new(_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	var original_session := _refresh_test_session()
	_session.store_session(player_id, original_session)

	var sync_service = SyncService.new()
	get_root().add_child(sync_service)
	sync_service.configure(store, _session, func(checkpoint, current, remaining): return current)
	sync_service.set("_store", store)
	sync_service.set("_request_store", store)
	sync_service.set("_request_mode", "refresh_sync")
	sync_service.set("_active_session", original_session.duplicate(true))
	sync_service.set("_refresh_request_id", "00000000-0000-4000-8000-000000000801")

	var body := JSON.stringify({"meta": {"protocol_version": "1.1"}}).to_utf8_buffer()
	sync_service.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), body)

	var terminal := store.get_sync_metadata().get("terminal_error", {}) as Dictionary
	_check(
		str(terminal.get("code", "")) == "auth.refresh_response_malformed",
		"a structurally malformed refresh response is terminal with a stable error code"
	)
	var loaded: Dictionary = _session.load_session(player_id)
	_check(
		str((loaded.get("session", {}) as Dictionary).get("access_token", "")) == "original-access",
		"a malformed refresh response never overwrites the stored session"
	)
	sync_service.queue_free()


func _test_replayed_refresh_reuse_is_terminal_and_preserves_session() -> void:
	var player_id := Codec.create_uuid()
	var store = SaveStore.new(_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	var original_session := _refresh_test_session()
	_session.store_session(player_id, original_session)

	var sync_service = SyncService.new()
	get_root().add_child(sync_service)
	sync_service.configure(store, _session, func(checkpoint, current, remaining): return current)
	sync_service.set("_store", store)
	sync_service.set("_request_store", store)
	sync_service.set("_request_mode", "refresh_sync")
	sync_service.set("_active_session", original_session.duplicate(true))

	var correlation_id := "00000000-0000-4000-8000-000000000803"
	var body := JSON.stringify({
		"error": {"code": "auth.refresh_reuse_detected"},
		"meta": {"correlation_id": correlation_id},
	}).to_utf8_buffer()
	sync_service.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 401, PackedStringArray(), body)

	var terminal := store.get_sync_metadata().get("terminal_error", {}) as Dictionary
	_check(
		str(terminal.get("code", "")) == "auth.refresh_reuse_detected",
		"a replayed/reused refresh credential surfaces the server's reuse-detection error instead of retrying"
	)
	_check(
		str(terminal.get("correlation_id", "")) == correlation_id,
		"reuse-detection terminal state records the server correlation id"
	)
	_check(
		int(store.get_sync_metadata().get("retry_attempt", 0)) == 0,
		"reuse detection does not schedule a background retry that could replay the rotated credential"
	)
	var loaded: Dictionary = _session.load_session(player_id)
	_check(
		str((loaded.get("session", {}) as Dictionary).get("access_token", "")) == "original-access",
		"reuse detection never overwrites the stored session with an unverified response"
	)
	sync_service.queue_free()


func _test_binding_mismatched_refresh_response_is_terminal() -> void:
	var player_id := Codec.create_uuid()
	var store = SaveStore.new(_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	var original_session := _refresh_test_session()
	_session.store_session(player_id, original_session)

	var sync_service = SyncService.new()
	get_root().add_child(sync_service)
	sync_service.configure(store, _session, func(checkpoint, current, remaining): return current)
	sync_service.set("_store", store)
	sync_service.set("_request_store", store)
	sync_service.set("_request_mode", "refresh_sync")
	sync_service.set("_active_session", original_session.duplicate(true))
	var request_id := "00000000-0000-4000-8000-000000000802"
	sync_service.set("_refresh_request_id", request_id)

	var body := JSON.stringify({
		"meta": {
			"protocol_version": "1.1",
			"request_id": request_id,
			"correlation_id": Codec.create_uuid(),
		},
		"data": {
			"player_id": player_id,
			"device_id": "00000000-0000-4000-8000-000000000999",
			"session_id": Codec.create_uuid(),
			"authentication_level": "guest",
			"tokens": {"access_token": "rotated", "refresh_token": "rotated-refresh"},
		},
	}).to_utf8_buffer()
	sync_service.call("_on_request_completed", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), body)

	var terminal := store.get_sync_metadata().get("terminal_error", {}) as Dictionary
	_check(
		str(terminal.get("code", "")) == "auth.refresh_response_malformed",
		"a refresh response bound to a different device is rejected instead of accepted"
	)
	var loaded: Dictionary = _session.load_session(player_id)
	_check(
		str((loaded.get("session", {}) as Dictionary).get("access_token", "")) == "original-access",
		"a device-binding-mismatched refresh response never overwrites the stored session"
	)
	sync_service.queue_free()


func _test_single_refresh_attempt_guard() -> void:
	var player_id := Codec.create_uuid()
	var store = SaveStore.new(_session)
	store.open_namespace({"kind": "player", "player_id": player_id}, _snapshot(), _preferences())
	var sync := store.get_sync_metadata()
	sync["pending_request"] = {
		"idempotency_key": Codec.create_uuid(),
		"request_id": Codec.create_uuid(),
		"payload": "{}",
		"first_sequence": 1,
		"last_sequence": 1,
		"refresh_attempted": true,
	}
	store.persist_sync_metadata(sync)

	var sync_service = SyncService.new()
	get_root().add_child(sync_service)
	sync_service.configure(store, _session, func(checkpoint, current, remaining): return current)
	sync_service.set("_store", store)
	sync_service.set(
		"_active_session",
		{"session_id": Codec.create_uuid(), "access_token": "access", "refresh_token": "refresh"}
	)

	sync_service.call("_refresh_session_and_replay")

	var terminal := store.get_sync_metadata().get("terminal_error", {}) as Dictionary
	_check(
		str(terminal.get("code", "")) == "auth.session_refresh_failed",
		"a pending request that already attempted one refresh is never replayed with a second refresh"
	)
	sync_service.queue_free()


func _test_guest_restart_resumes_same_player_without_second_guest() -> void:
	_reset_active_namespace_file()
	_reset_namespace_directory(
		{"kind": "installation_guest", "installation_id": _session.get_installation_id()}
	)
	var coordinator_a := AccountCoordinator.new(_session)
	var initial_open: Dictionary = coordinator_a.initialize(_snapshot(), _preferences())
	_check(bool(initial_open.get("ok", false)), "first launch opens local-first progress")
	_check(
		str(coordinator_a.get_active_namespace().get("kind", "")) == "installation_guest",
		"first launch starts from the installation guest namespace"
	)

	var player_id := Codec.create_uuid()
	var bind_result: Dictionary = coordinator_a.bind_registered_guest(player_id, _refresh_test_session())
	_check(
		bool(bind_result.get("ok", false)),
		"a completed guest bootstrap rebinds the installation guest to the returned player"
	)

	var coordinator_b := AccountCoordinator.new(_session)
	var resumed_open: Dictionary = coordinator_b.initialize(_snapshot(), _preferences())
	_check(bool(resumed_open.get("ok", false)), "killing and restarting the app reopens local-first progress")
	var resumed_namespace := coordinator_b.get_active_namespace()
	_check(
		str(resumed_namespace.get("kind", "")) == "player"
		and str(resumed_namespace.get("player_id", "")) == player_id,
		"killing and restarting the app resumes the same player session"
	)
	_check(
		int(coordinator_b.get_store().get_generation()) == int(coordinator_a.get_store().get_generation()),
		"process restart does not create a second guest or a competing save generation"
	)
	_reset_active_namespace_file()
	_reset_namespace_directory(
		{"kind": "installation_guest", "installation_id": _session.get_installation_id()}
	)
	_reset_namespace_directory({"kind": "player", "player_id": player_id})


func _refresh_test_session() -> Dictionary:
	return {
		"session_id": Codec.create_uuid(),
		"authentication_level": "guest",
		"access_token": "original-access",
		"access_token_expires_at": "2020-01-01T00:00:00.000Z",
		"refresh_token": "original-refresh",
		"refresh_token_expires_at": "2099-01-01T00:00:00.000Z",
	}


func _reset_active_namespace_file() -> void:
	for path in ["user://active_save_namespace.json", "user://active_save_namespace.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _reset_namespace_directory(save_namespace: Dictionary) -> void:
	var directory_path := "user://save_v2/%s" % Codec.namespace_key(save_namespace)
	var absolute_path := ProjectSettings.globalize_path(directory_path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			DirAccess.remove_absolute("%s/%s" % [absolute_path, entry])
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


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


func _guest_namespace() -> Dictionary:
	return {"kind": "installation_guest", "installation_id": Codec.create_uuid()}


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
