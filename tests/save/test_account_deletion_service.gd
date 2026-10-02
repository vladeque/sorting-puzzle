extends SceneTree

## GAME-012 batch 2 coverage for scripts/save/account_deletion_service.gd, its record store, and the
## PlayerProgress wiring around them (docs/ACCOUNT_DELETION_PLAN.md).
##
## Runs against the real PlayerProgress autoload in the isolated runner's private user:// directory.
## A fake secure-store bridge is registered as an Engine singleton, so sessions and keys survive the
## simulated restarts the way Keystore/Keychain entries do. Each restart frees the network services
## and installs a fresh fake BackendTransport, the way a new process would.

const Codec := preload("res://scripts/save/local_save_codec.gd")
const BackendTransportScript := preload("res://scripts/backend/backend_transport.gd")
const AccountDeletionOperationsScript := preload("res://scripts/backend/account_deletion_operations.gd")
const AccountDeletionRecordStoreScript := preload("res://scripts/save/account_deletion_record_store.gd")
const AccountDeletionServiceScript := preload("res://scripts/save/account_deletion_service.gd")
const SecureSessionStoreScript := preload("res://scripts/save/secure_session_store.gd")

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const BRIDGE_NAME := "AccountDeletionTestBridge"
const BRIDGE_SETTING := "application/config/secure_storage_bridge_singleton"
const BACKEND_URL_SETTING := "application/config/backend_base_url"
const BACKEND_URL := "http://127.0.0.1:8080"
const LEGACY_SAVE_PATH := "user://player_progress.json"
const SHOP_CACHE_PATH := "user://shop_catalog_backend_cache.json"
const LEADERBOARD_CACHE_PATH := "user://leaderboard_backend_cache.json"
const IDENTITY_PATHS := [
	"user://sorting_puzzle_installation.json",
	"user://sorting_puzzle_installation.tmp",
	"user://sorting_puzzle_installation.previous.json",
]
const ACTIVE_NAMESPACE_PATHS := ["user://active_save_namespace.json", "user://active_save_namespace.tmp"]
const SIGNATURE_70_BYTES := "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERQ=="

var _failures := PackedStringArray()
var _progress: Node
var _bridge: FakeBridge
var _transport: FakeTransport
var _progress_replaced_count := 0


class FakeBridge:
	extends RefCounted
	var keys := {}
	var sessions := {}
	var bound_installation_id := ""
	var destroy_fails := false
	var destroyed := []

	func reset() -> void:
		keys.clear()
		sessions.clear()
		bound_installation_id = ""
		destroy_fails = false
		destroyed.clear()

	func ensure_installation_key(installation_id: String) -> bool:
		keys[installation_id] = true
		return true

	func get_installation_public_key_der(installation_id: String) -> String:
		return "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE" if keys.has(installation_id) else ""

	func set_installation_id(installation_id: String) -> bool:
		bound_installation_id = installation_id
		return true

	# A DER ECDSA signature's length (70 bytes), which the save journal validates.
	func sign_save_operation_hash(_operation_hash: String) -> String:
		return SIGNATURE_70_BYTES

	func sign_installation_payload(_payload: String) -> String:
		return SIGNATURE_70_BYTES

	func store_player_session(player_id: String, session_json: String) -> bool:
		sessions[player_id] = session_json
		return true

	func load_player_session(player_id: String) -> String:
		return str(sessions.get(player_id, ""))

	func clear_player_session(player_id: String) -> bool:
		sessions.erase(player_id)
		return true

	func destroy_installation_key(installation_id: String) -> bool:
		if destroy_fails:
			return false
		keys.erase(installation_id)
		if bound_installation_id == installation_id:
			bound_installation_id = ""
		destroyed.append(installation_id)
		return true


class FakeTransport:
	extends BackendTransportScript
	var get_queue := []
	var post_queue := []
	var delete_queue := []
	var get_calls := []
	var post_calls := []
	var delete_calls := []

	func _send_get(url: String, headers: PackedStringArray) -> Array:
		get_calls.append({"url": url, "headers": headers})
		return _next(get_queue, url, headers, "")

	func _send_post(url: String, headers: PackedStringArray, body: String) -> Array:
		post_calls.append({"url": url, "headers": headers, "body": body})
		return _next(post_queue, url, headers, body)

	func _send_delete(url: String, headers: PackedStringArray, body: String) -> Array:
		delete_calls.append({"url": url, "headers": headers, "body": body})
		return _next(delete_queue, url, headers, body)

	func _wait_before_retry(_attempt: int, _retry_after_seconds: int) -> void:
		pass

	func _next(queue: Array, url: String, headers: PackedStringArray, body: String) -> Array:
		if queue.is_empty():
			return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
		var entry = queue.pop_front()
		if entry is Callable:
			return (entry as Callable).call(url, headers, body)
		return entry


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Account deletion tests must run through scripts/tools/run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_progress = get_root().get_node_or_null("PlayerProgress")
	if _progress == null:
		push_error("PlayerProgress autoload is unavailable.")
		quit(1)
		return
	_progress.connect("progress_replaced", func(): _progress_replaced_count += 1)
	_bridge = FakeBridge.new()
	Engine.register_singleton(BRIDGE_NAME, _bridge)
	ProjectSettings.set_setting(BRIDGE_SETTING, BRIDGE_NAME)

	_check_record_store()
	await _check_local_data_deletion()
	await _check_registration_pending_and_signed_out_availability()
	await _check_account_deletion_accepted()
	await _check_lost_response_replays_after_restart()
	await _check_expired_credential_after_ambiguity_stays_locked()
	await _check_definite_rejection_returns_the_account()
	await _check_offline_preflight_sends_nothing()
	await _check_version_conflict_rebuilds_with_a_new_key()
	await _check_first_401_refreshes_once()
	await _check_process_death_during_send()
	await _check_cleanup_failure_resumes_after_restart()
	await _check_corrupt_record_fails_closed()
	await _check_activation_resumes_idempotently()
	await _check_unsupported_build_is_unavailable()

	Engine.unregister_singleton(BRIDGE_NAME)
	if _failures.is_empty():
		print("GAME-012 account deletion service tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# ---------------------------------------------------------------------------
# Record store
# ---------------------------------------------------------------------------

func _check_record_store() -> void:
	var directory := "user://account_deletion_record_test"
	var store := AccountDeletionRecordStoreScript.new(directory)
	store.clear_record()
	_check(
		bool(store.load_record().get("ok", false)) and (store.load_record().get("record", {}) as Dictionary).is_empty(),
		"an absent record loads as no deletion"
	)
	_check(bool(store.save_record({"phase": "submitting"}).get("ok", false)), "a record saves")
	_check(bool(store.save_record({"phase": "cleaning"}).get("ok", false)), "a second revision saves")
	_check(_record_phase(store) == "cleaning", "the newest revision loads")

	_write_text(directory.path_join("operation.json"), "{\"format\": \"torn")
	_check(_record_phase(store) == "submitting", "a torn current generation falls back to the previous one")

	store.clear_record()
	store.save_record({"phase": "submitting"})
	var newer := store.save_record({"phase": "ready"})
	# A crash after validating the temporary file but before promoting it.
	var current_text := FileAccess.get_file_as_string(directory.path_join("operation.json"))
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(directory.path_join("operation.json")),
		ProjectSettings.globalize_path(directory.path_join("operation.tmp"))
	)
	_write_text(directory.path_join("operation.json"), FileAccess.get_file_as_string(directory.path_join("operation.previous.json")))
	_check(
		bool(newer.get("ok", false)) and not current_text.is_empty() and _record_phase(store) == "ready",
		"a validated temporary generation newer than current wins"
	)

	store.clear_record()
	_write_text(directory.path_join("operation.json"), "garbage")
	var corrupt := store.load_record()
	_check(not bool(corrupt.get("ok", true)) and bool(corrupt.get("corrupt", false)), "unreadable record files fail closed")
	store.clear_record()
	_check(
		not bool(store.save_record({"phase": "ready", "fraction": 0.5}).get("ok", true)),
		"a record canonical JSON cannot hash is refused"
	)
	store.clear_record()


# ---------------------------------------------------------------------------
# Local-only flow
# ---------------------------------------------------------------------------

func _check_local_data_deletion() -> void:
	await _reset_world()
	var service = _service()
	var old_installation_id := _installation_id()
	_check(_availability_kind() == "local_data", "a never-registered installation offers local data deletion")
	_check(_progress.spend_coins(50), "the guest can play before deletion")
	_check(_progress.set_locale("de"), "the language can be changed")
	_check(_progress.set_setting_disabled(&"music", true), "music can be switched off")
	_write_text(LEGACY_SAVE_PATH, "{\"version\": 4, \"coins\": 9999}")
	_write_text(SHOP_CACHE_PATH, "{}")
	_write_text(LEADERBOARD_CACHE_PATH, "{}")
	var unrelated := {"kind": "player", "player_id": Codec.create_uuid()}
	_write_text(_namespace_directory(unrelated).path_join("current.json"), "{}")
	var guest_namespace := {"kind": "installation_guest", "installation_id": old_installation_id}

	var state: Dictionary = await service.request_local_data_deletion()
	_check(str(state.get("phase", "")) == "ready", "local data deletion finishes ready for a new game")
	_check(str(state.get("kind", "")) == "local_data", "the record keeps the local-data kind")
	_check(not _dir_exists(_namespace_directory(guest_namespace)), "the guest save is removed")
	_check(not FileAccess.file_exists(LEGACY_SAVE_PATH), "the legacy save that could restore progress is removed")
	_check(not _any_exists(ACTIVE_NAMESPACE_PATHS), "the active namespace pointer is removed")
	_check(not _any_exists(IDENTITY_PATHS), "the public installation identity is removed")
	_check(
		not FileAccess.file_exists(SHOP_CACHE_PATH) and not FileAccess.file_exists(LEADERBOARD_CACHE_PATH),
		"account-dependent caches are removed"
	)
	_check(_dir_exists(_namespace_directory(unrelated)), "an unrelated namespace is untouched")
	_check(_bridge.destroyed.has(old_installation_id), "the installation key is destroyed")
	_check(_progress.is_account_deletion_blocking(), "progress stays blocked until a new game")
	_check(not _progress.spend_coins(1), "save writes are refused after deletion")
	_check(_progress.get_locale() == "de", "the released in-memory state keeps the language")

	await _restart()
	_check(str(_service().get_state().get("phase", "")) == "ready", "a restart keeps the ready result")
	_check(not _any_exists(IDENTITY_PATHS), "a restart before a new game creates no identity")
	_check(not _dir_exists(_namespace_directory(guest_namespace)), "a restart does not recreate the deleted save")
	_check(not FileAccess.file_exists(LEGACY_SAVE_PATH), "a restart does not restore legacy progress")

	var replaced_before := _progress_replaced_count
	var started: Dictionary = _service().start_new_game()
	_check(str(started.get("phase", "")) == "idle", "starting a new game finishes the deletion")
	_check(not _progress.is_account_deletion_blocking(), "a new game unblocks progress")
	_check(_progress_replaced_count == replaced_before + 1, "a new game announces replaced progress")
	_check(_installation_id() != old_installation_id and Codec.is_uuid(_installation_id()), "a new game has a new installation id")
	_check(_progress.get_coins() == 300, "a new game starts from initial coins")
	_check(_progress.get_locale() == "de", "a new game keeps the device language")
	_check(_progress.is_setting_disabled(&"music"), "a new game keeps the audio settings")
	_check(_record_on_disk().is_empty(), "the deletion record is removed")
	_check(_progress.spend_coins(10), "the new game can save")


func _check_registration_pending_and_signed_out_availability() -> void:
	await _reset_world()
	var store = _progress.get("_local_store")
	var sync: Dictionary = store.get_sync_metadata()
	sync["guest_registration"] = {"phase": "bootstrap", "request_id": Codec.create_uuid()}
	store.persist_sync_metadata(sync)
	_check(_availability_kind() == "registration_pending", "an unresolved bootstrap must finish before deletion")
	var refused: Dictionary = await _service().request_local_data_deletion()
	_check(str(refused.get("refused", "")) != "", "local deletion is refused while a bootstrap is unresolved")
	_check(_dir_exists(_namespace_directory(_progress.get_active_save_namespace())), "a refused deletion keeps the save")

	sync = store.get_sync_metadata()
	sync["guest_registration"] = {}
	sync["guest_rebound_player_id"] = Codec.create_uuid()
	store.persist_sync_metadata(sync)
	var availability: Dictionary = _service().get_availability()
	_check(
		str(availability.get("kind", "")) == "unavailable"
		and str(availability.get("reason", "")) == "signed_out_account",
		"a signed-out account is never deleted as local data"
	)


# ---------------------------------------------------------------------------
# Account flow
# ---------------------------------------------------------------------------

func _check_account_deletion_accepted() -> void:
	await _reset_world()
	var guest_namespace: Dictionary = _progress.get_active_save_namespace()
	var old_installation_id := _installation_id()
	var player_id := _register_player()
	_check(_availability_kind() == "account", "a registered player offers account deletion")
	_write_text(LEGACY_SAVE_PATH, "{\"version\": 4}")
	_transport.get_queue = [_player_state_response(7)]
	_transport.delete_queue = [_accepted_echo()]

	var state: Dictionary = await _service().request_account_deletion()
	_check(str(state.get("phase", "")) == "ready", "an accepted deletion finishes ready for a new game")
	var receipt := state.get("receipt", {}) as Dictionary
	_check(str(receipt.get("complete_by", "")) == "2026-11-01T12:00:00.000Z", "the receipt keeps the completion deadline")
	_check(_transport.delete_calls.size() == 1, "exactly one deletion request is sent")
	var meta := _sent_meta(0)
	_check(int(meta.get("expected_state_version", -1)) == 7, "the request uses the authoritative state version")
	_check(str(meta.get("session_id", "")) == "00000000-0000-4000-8000-0000000000a1", "the request binds the current session")
	_check(_transport.post_calls.is_empty(), "a fresh token is not refreshed")
	_check(not _dir_exists(_namespace_directory({"kind": "player", "player_id": player_id})), "the player save is removed")
	_check(not _dir_exists(_namespace_directory(guest_namespace)), "the rebound guest save is removed")
	_check(not FileAccess.file_exists(LEGACY_SAVE_PATH), "the legacy save is removed")
	_check(not _bridge.sessions.has(player_id), "the deleted player's secure session is removed")
	_check(_bridge.destroyed.has(old_installation_id), "the installation key is destroyed")
	var suspended: Dictionary = await _transport.get_json("/v1/catalog")
	_check(
		str((suspended.get("error", {}) as Dictionary).get("code", "")) == "account.deletion_in_progress",
		"other backend reads are refused after acceptance"
	)
	_check(not _progress.switch_to_player(Codec.create_uuid()), "account switching is refused after acceptance")
	var started: Dictionary = _service().start_new_game()
	_check(str(started.get("phase", "")) == "idle", "a new game follows an accepted deletion")
	_check(str(_progress.get_active_save_namespace().get("kind", "")) == "installation_guest", "the new game is a fresh guest")


func _check_lost_response_replays_after_restart() -> void:
	await _reset_world()
	var player_id := _register_player()
	_transport.get_queue = [_player_state_response(7)]
	for index in range(5):
		_transport.delete_queue.append(_failure(HTTPRequest.RESULT_TIMEOUT))
	var state: Dictionary = await _service().request_account_deletion()
	_check(str(state.get("phase", "")) == "retry_pending", "a lost response leaves the deletion retry pending")
	var first_key := _sent_header(0, "Idempotency-Key")
	var record := _record_on_disk()
	_check(str(record.get("phase", "")) == "retry_pending", "the retry-pending phase is durable")
	_check(bool((record.get("operation", {}) as Dictionary).get("possibly_applied", false)), "the operation is recorded as possibly applied")
	_check(_dir_exists(_namespace_directory({"kind": "player", "player_id": player_id})), "the old save stays intact while unsettled")
	_check(not _progress.spend_coins(1), "save writes are refused while unsettled")

	await _restart(func(transport: FakeTransport) -> void:
		transport.delete_queue = [_accepted_echo()]
	)
	_check(str(_service().get_state().get("phase", "")) == "ready", "the restart replay settles the deletion")
	_check(_transport.get_calls.is_empty(), "the replay does not read a new state version")
	_check(_sent_header(0, "Idempotency-Key") == first_key, "the replay reuses the original idempotency key")


func _check_expired_credential_after_ambiguity_stays_locked() -> void:
	await _reset_world()
	var player_id := _register_player()
	_transport.get_queue = [_player_state_response(7)]
	_transport.delete_queue = [_failure(HTTPRequest.RESULT_TIMEOUT), _error(401, "auth.invalid", "authentication")]
	var state: Dictionary = await _service().request_account_deletion()
	_check(str(state.get("phase", "")) == "unconfirmed", "a 401 after a lost response is unconfirmed")
	_check(_transport.post_calls.is_empty(), "an unconfirmed deletion never refreshes the session")
	_check(_dir_exists(_namespace_directory({"kind": "player", "player_id": player_id})), "an unconfirmed deletion keeps the old save")
	_check(_bridge.sessions.has(player_id), "an unconfirmed deletion keeps the old session")
	_check(
		not str((state.get("support_reference", {}) as Dictionary).get("operation_id", "")).is_empty(),
		"an unconfirmed deletion offers a support reference"
	)

	await _restart()
	_check(str(_service().get_state().get("phase", "")) == "unconfirmed", "a restart keeps the deletion unconfirmed")
	_check(_transport.delete_calls.is_empty(), "a restart does not resend an unconfirmed deletion")
	_check(_progress.is_account_deletion_blocking(), "an unconfirmed deletion keeps the account locked")
	var sync_service = _progress.get("_sync_service")
	_check(bool(sync_service.get("_suspended")), "sync stays suspended for an unconfirmed deletion")
	_check(_availability_kind() == "unavailable", "no second deletion can start while one is unconfirmed")


func _check_definite_rejection_returns_the_account() -> void:
	await _reset_world()
	var player_id := _register_player()
	_transport.get_queue = [_player_state_response(7)]
	_transport.delete_queue = [_error(403, "access.denied", "authorization")]
	var state: Dictionary = await _service().request_account_deletion()
	_check(str(state.get("phase", "")) == "idle", "a definite rejection returns to normal play")
	_check(str((state.get("failure", {}) as Dictionary).get("reason", "")) == "failed", "a definite rejection reports a failure")
	_check(_record_on_disk().is_empty(), "a definite rejection leaves no record")
	_check(_dir_exists(_namespace_directory({"kind": "player", "player_id": player_id})), "a definite rejection keeps the save")
	_check(_progress.spend_coins(1), "a definite rejection allows saving again")
	_check(not bool(_transport.get("_suspended")), "a definite rejection resumes backend traffic")


func _check_offline_preflight_sends_nothing() -> void:
	await _reset_world()
	_register_player()
	var state: Dictionary = await _service().request_account_deletion()
	_check(str(state.get("phase", "")) == "idle", "an offline preflight returns to normal play")
	_check(str((state.get("failure", {}) as Dictionary).get("reason", "")) == "offline", "an offline preflight reports offline")
	_check(_transport.delete_calls.is_empty(), "an offline preflight never sends the deletion")
	_check(_record_on_disk().is_empty(), "an offline preflight leaves no record")


func _check_version_conflict_rebuilds_with_a_new_key() -> void:
	await _reset_world()
	_register_player()
	_transport.get_queue = [_player_state_response(7)]
	_transport.delete_queue = [
		_error(409, "state.version_conflict", "conflict", {"action": "refresh_state", "current_state_version": 9}),
		_accepted_echo(),
	]
	var state: Dictionary = await _service().request_account_deletion()
	_check(str(state.get("phase", "")) == "ready", "a version conflict is rebuilt and accepted")
	_check(_transport.delete_calls.size() == 2, "the rebuilt request is sent once")
	_check(int(_sent_meta(1).get("expected_state_version", -1)) == 9, "the rebuilt request uses the recovery version")
	_check(_sent_header(0, "Idempotency-Key") != _sent_header(1, "Idempotency-Key"), "the rebuilt request uses a new key")


func _check_first_401_refreshes_once() -> void:
	await _reset_world()
	var player_id := _register_player()
	_transport.get_queue = [_player_state_response(7)]
	_transport.delete_queue = [_error(401, "auth.invalid", "authentication"), _accepted_echo()]
	_transport.post_queue = [_refresh_response(player_id)]
	var state: Dictionary = await _service().request_account_deletion()
	_check(str(state.get("phase", "")) == "ready", "a first-attempt 401 refreshes once and is then accepted")
	_check(_transport.post_calls.size() == 1, "exactly one refresh is made")
	_check(
		str(_sent_meta(1).get("session_id", "")) == "00000000-0000-4000-8000-0000000000b2",
		"the resent request binds the refreshed session"
	)


func _check_process_death_during_send() -> void:
	await _reset_world()
	var player_id := _register_player()
	var record_store := AccountDeletionRecordStoreScript.new()
	var operation := AccountDeletionOperationsScript.create_operation(
		player_id,
		_progress.get("_session_store").get_device_id(),
		"00000000-0000-4000-8000-0000000000a1",
		7
	)
	record_store.save_record({
		"kind": "account",
		"phase": "submitting",
		"targets": {
			"player_id": player_id,
			"installation_id": _installation_id(),
			"device_id": _progress.get("_session_store").get_device_id(),
			"namespaces": [_progress.get_active_save_namespace()],
		},
		"operation": operation,
		"send_in_progress": true,
		"preserved_preferences": {},
	})
	await _restart(func(transport: FakeTransport) -> void:
		transport.delete_queue = [_error(401, "auth.invalid", "authentication")]
	)
	_check(
		str(_service().get_state().get("phase", "")) == "unconfirmed",
		"a send interrupted by process death is treated as possibly applied"
	)
	_check(_transport.post_calls.is_empty(), "a possibly applied deletion is never refreshed after restart")


func _check_cleanup_failure_resumes_after_restart() -> void:
	await _reset_world()
	var player_id := _register_player()
	_bridge.destroy_fails = true
	_transport.get_queue = [_player_state_response(7)]
	_transport.delete_queue = [_accepted_echo()]
	var state: Dictionary = await _service().request_account_deletion()
	_check(str(state.get("phase", "")) == "cleaning", "a failed cleanup step stays in cleaning")
	_check(not str(state.get("cleanup_error", "")).is_empty(), "a failed cleanup step is reported")
	_check(not _dir_exists(_namespace_directory({"kind": "player", "player_id": player_id})), "the other cleanup steps still run")
	_check(not (_record_on_disk().get("receipt", {}) as Dictionary).is_empty(), "the receipt is durable before cleanup")

	_bridge.destroy_fails = false
	await _restart()
	_check(str(_service().get_state().get("phase", "")) == "ready", "a restart finishes the cleanup")
	_check(not _any_exists(IDENTITY_PATHS), "the finished cleanup creates no new identity")


func _check_corrupt_record_fails_closed() -> void:
	await _reset_world()
	var guest_namespace: Dictionary = _progress.get_active_save_namespace()
	_write_text("user://account_deletion/operation.json", "{\"phase\": ")
	await _restart()
	_check(str(_service().get_state().get("phase", "")) == "record_corrupt", "an unreadable record fails closed")
	_check(_progress.is_account_deletion_blocking(), "an unreadable record blocks progress")
	_check(_dir_exists(_namespace_directory(guest_namespace)), "an unreadable record does not delete the save")
	_check(not _progress.spend_coins(1), "an unreadable record blocks save writes")


func _check_activation_resumes_idempotently() -> void:
	await _reset_world()
	await _service().request_local_data_deletion()
	var record_store := AccountDeletionRecordStoreScript.new()
	var record: Dictionary = record_store.load_record().get("record", {})
	record["phase"] = "activating"
	record_store.save_record(record)
	# The process died after the new identity and save were created but before the record cleared.
	_check(bool(_progress.activate_progress_after_account_deletion({}).get("ok", false)), "activation creates the new game")
	var new_installation_id := _installation_id()
	await _restart()
	_check(str(_service().get_state().get("phase", "")) == "idle", "a restart completes an interrupted activation")
	_check(_installation_id() == new_installation_id, "the completed activation reuses the identity it created")
	_check(_record_on_disk().is_empty(), "the completed activation removes the record")


func _check_unsupported_build_is_unavailable() -> void:
	await _reset_world()
	var limited := RefCounted.new()
	Engine.register_singleton("AccountDeletionLimitedBridge", limited)
	ProjectSettings.set_setting(BRIDGE_SETTING, "AccountDeletionLimitedBridge")
	var store := SecureSessionStoreScript.new()
	_check(not store.supports_installation_destruction(), "a bridge without key destruction is unsupported")
	Engine.unregister_singleton("AccountDeletionLimitedBridge")
	ProjectSettings.set_setting(BRIDGE_SETTING, BRIDGE_NAME)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _reset_world() -> void:
	_bridge.reset()
	_remove_tree("user://save_v2")
	for path in IDENTITY_PATHS + ACTIVE_NAMESPACE_PATHS + [LEGACY_SAVE_PATH, SHOP_CACHE_PATH, LEADERBOARD_CACHE_PATH]:
		_remove_file(path)
	AccountDeletionRecordStoreScript.new().clear_record()
	ProjectSettings.set_setting(BACKEND_URL_SETTING, "")
	await _restart()


## Mimics a new process: fresh network services, transport, deletion service, identity, and save.
func _restart(configure_transport: Callable = Callable()) -> void:
	for property in ["_sync_service", "_guest_bootstrap_service", "_backend_transport", "_account_deletion_service"]:
		var node = _progress.get(property)
		if node is Node:
			(node as Node).free()
		_progress.set(property, null)
	_progress.set("_session_store", null)
	_progress.set("_account_coordinator", null)
	_progress.set("_local_store", null)
	_transport = FakeTransport.new()
	_progress.add_child(_transport)
	_progress.set("_backend_transport", _transport)
	if configure_transport.is_valid():
		configure_transport.call(_transport)
	_progress.load_progress()
	for frame in range(5):
		await process_frame
	var guard := 0
	while _service() != null and bool(_service().get_state().get("busy", false)) and guard < 300:
		guard += 1
		await process_frame


func _register_player() -> String:
	ProjectSettings.set_setting(BACKEND_URL_SETTING, BACKEND_URL)
	var player_id := Codec.create_uuid()
	_check(_progress.spend_coins(20), "the guest records progress before registering")
	_check(
		_progress.bind_registered_guest(player_id, {
			"session_id": "00000000-0000-4000-8000-0000000000a1",
			"authentication_level": "guest",
			"access_token": "original-access-token",
			"access_token_expires_at": Codec.iso_timestamp(int(Time.get_unix_time_from_system()) + 300),
			"refresh_token": "original-refresh-token",
			"refresh_token_expires_at": Codec.iso_timestamp(int(Time.get_unix_time_from_system()) + 86400),
		}),
		"the guest binds to a registered player"
	)
	return player_id


func _service():
	return _progress.get_account_deletion_service()


func _availability_kind() -> String:
	return str(_service().get_availability().get("kind", ""))


func _installation_id() -> String:
	var store = _progress.get("_session_store")
	return store.get_installation_id() if store != null else ""


func _record_phase(store) -> String:
	return str((store.load_record().get("record", {}) as Dictionary).get("phase", ""))


func _record_on_disk() -> Dictionary:
	return AccountDeletionRecordStoreScript.new().load_record().get("record", {}) as Dictionary


func _sent_meta(index: int) -> Dictionary:
	var body = JSON.parse_string(str((_transport.delete_calls[index] as Dictionary).get("body", "")))
	return ((body as Dictionary).get("meta", {}) as Dictionary) if body is Dictionary else {}


func _sent_header(index: int, name: String) -> String:
	for header in (_transport.delete_calls[index] as Dictionary).get("headers", PackedStringArray()):
		if str(header).begins_with("%s: " % name):
			return str(header).trim_prefix("%s: " % name)
	return ""


func _player_state_response(state_version: int) -> Array:
	var correlation_id := Codec.create_uuid()
	return _raw(200, {
		"meta": {
			"protocol_version": "1.0",
			"request_id": correlation_id,
			"correlation_id": correlation_id,
			"server_time": "2026-10-02T12:00:00.000Z",
			"state_version": state_version,
		},
		"data": {},
	})


func _accepted_echo() -> Callable:
	return func(_url: String, _headers: PackedStringArray, body: String) -> Array:
		var sent := JSON.parse_string(body) as Dictionary
		return _raw(202, {
			"meta": {
				"protocol_version": "1.3",
				"request_id": str((sent.get("meta", {}) as Dictionary).get("request_id", "")),
				"correlation_id": "00000000-0000-4000-8000-000000006074",
				"server_time": "2026-10-02T12:00:00.000Z",
				"state_version": 8,
			},
			"data": {
				"request_id": "00000000-0000-4000-8000-000000006075",
				"kind": "deletion",
				"status": "pending",
				"created_at": "2026-10-02T12:00:00.000Z",
				"updated_at": "2026-10-02T12:00:00.000Z",
				"complete_by": "2026-11-01T12:00:00.000Z",
			},
		})


func _refresh_response(player_id: String) -> Callable:
	return func(_url: String, _headers: PackedStringArray, body: String) -> Array:
		var sent := JSON.parse_string(body) as Dictionary
		return _raw(200, {
			"meta": {
				"protocol_version": "1.1",
				"request_id": str((sent.get("meta", {}) as Dictionary).get("request_id", "")),
				"correlation_id": Codec.create_uuid(),
				"server_time": "2026-10-02T12:00:00.000Z",
			},
			"data": {
				"player_id": player_id,
				"device_id": _progress.get("_session_store").get_device_id(),
				"session_id": "00000000-0000-4000-8000-0000000000b2",
				"authentication_level": "guest",
				"tokens": {
					"access_token": "refreshed-access-token",
					"access_token_expires_at": Codec.iso_timestamp(int(Time.get_unix_time_from_system()) + 300),
					"refresh_token": "refreshed-refresh-token",
					"refresh_token_expires_at": Codec.iso_timestamp(int(Time.get_unix_time_from_system()) + 86400),
				},
			},
		})


func _error(status: int, code: String, category: String, recovery: Dictionary = {}) -> Array:
	var error := {"code": code, "category": category, "message": "synthetic", "retryable": false}
	if not recovery.is_empty():
		error["recovery"] = recovery
	return _raw(status, {
		"meta": {
			"protocol_version": "1.3",
			"request_id": Codec.create_uuid(),
			"correlation_id": Codec.create_uuid(),
			"server_time": "2026-10-02T12:00:00.000Z",
		},
		"error": error,
	})


func _failure(result_code: int) -> Array:
	return [result_code, 0, PackedStringArray(), PackedByteArray()]


func _raw(status: int, envelope: Dictionary) -> Array:
	return [HTTPRequest.RESULT_SUCCESS, status, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer()]


func _namespace_directory(save_namespace: Dictionary) -> String:
	return "user://save_v2/%s" % Codec.namespace_key(save_namespace)


func _dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))


func _any_exists(paths: Array) -> bool:
	for path in paths:
		if FileAccess.file_exists(str(path)):
			return true
	return false


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	for file_name in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
