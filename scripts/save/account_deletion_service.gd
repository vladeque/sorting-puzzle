extends Node
class_name AccountDeletionService

## GAME-012 durable account-deletion state machine (docs/ACCOUNT_DELETION_PLAN.md). PlayerProgress
## owns it, so it outlives the Support screen and is consulted before any save storage opens.
##
## Account flow: preflight (suspend and drain sync, registration, and backend traffic; read the
## authoritative state version; make sure the access token has time left), persist the operation,
## send `DELETE /v1/player/account`, then on acceptance persist the receipt before any destructive
## cleanup. Local flow, for an installation that provably never registered: persist the operation
## and clean up without HTTP. Both end in `ready`, and nothing new starts until start_new_game().
##
## The host (PlayerProgress) provides:
## - `get_account_deletion_dependencies() -> Dictionary`: `session_store`, `coordinator`,
##   `transport`, `sync_service`, `bootstrap_service` (any may be null while storage is released);
## - `get_account_deletion_preserved_preferences() -> Dictionary`;
## - `release_progress_for_account_deletion()`: drop every reference to the old save;
## - `activate_progress_after_account_deletion(preferences) -> Dictionary`: fresh identity and save.

signal state_changed(state: Dictionary)
signal new_game_started

const AccountDeletionOperationsScript := preload("res://scripts/backend/account_deletion_operations.gd")
const AccountDeletionRecordStoreScript := preload("res://scripts/save/account_deletion_record_store.gd")
const AccountSaveCoordinatorScript := preload("res://scripts/save/account_save_coordinator.gd")
const BackendReadOperationsScript := preload("res://scripts/backend/backend_read_operations.gd")
const BackendCatalogCacheScript := preload("res://scripts/store/backend_catalog_cache.gd")
const BackendLeaderboardCacheScript := preload("res://scripts/leaderboards/backend_leaderboard_cache.gd")
const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")
const LocalSaveStoreScript := preload("res://scripts/save/local_save_store.gd")

const KIND_ACCOUNT := "account"
const KIND_LOCAL_DATA := "local_data"

## In memory only: no operation, or a preflight that has not persisted anything yet.
const PHASE_IDLE := "idle"
const PHASE_PREPARING := "preparing"
## Persisted phases.
const PHASE_SUBMITTING := "submitting"
const PHASE_RETRY_PENDING := "retry_pending"
const PHASE_UNCONFIRMED := "unconfirmed"
const PHASE_CLEANING := "cleaning"
const PHASE_READY := "ready"
const PHASE_ACTIVATING := "activating"
## Persisted only when a finished operation's record could not be removed; loads as idle.
const PHASE_ABANDONED := "abandoned"
## In memory: record files exist but none validates, so nothing may open the old save.
const PHASE_RECORD_CORRUPT := "record_corrupt"
const PERSISTED_PHASES := [
	PHASE_SUBMITTING, PHASE_RETRY_PENDING, PHASE_UNCONFIRMED,
	PHASE_CLEANING, PHASE_READY, PHASE_ACTIVATING, PHASE_ABANDONED,
]

const AVAILABILITY_ACCOUNT := "account"
const AVAILABILITY_LOCAL_DATA := "local_data"
const AVAILABILITY_REGISTRATION_PENDING := "registration_pending"
const AVAILABILITY_UNAVAILABLE := "unavailable"

const REASON_IN_PROGRESS := "in_progress"
const REASON_STORAGE := "storage"
const REASON_UNSUPPORTED_BUILD := "unsupported_build"
const REASON_SIGNED_OUT_ACCOUNT := "signed_out_account"
const REASON_ACCOUNT_CHANGED := "account_changed"
const REASON_NETWORK_BUSY := "network_busy"
const REASON_VERSION_CONFLICT := "version_conflict"

const LEGACY_SAVE_PATH := "user://player_progress.json"
## The access token lives five minutes; insisting on two of them leaves time for exact replays.
const MIN_TOKEN_SECONDS := 120
const MAX_CONFLICT_REBUILDS := 2
const NETWORK_IDLE_TIMEOUT_MSEC := 40000
## Unconfirmed outcomes that a later replay may still settle while the original token is valid.
const REPLAYABLE_REASONS := [
	AccountDeletionOperationsScript.REASON_OFFLINE,
	AccountDeletionOperationsScript.REASON_RATE_LIMITED,
	AccountDeletionOperationsScript.REASON_UNAVAILABLE,
]

var _host: Object
var _record_store
var _record := {}
var _phase := PHASE_IDLE
var _busy := false
## The latest attempt that left the account intact: `reason`, `code`, `correlation_id`.
var _last_failure := {}
var _record_loaded := false
var _resumed := false


func configure(host: Object, record_store = null) -> void:
	_host = host
	_record_store = record_store if record_store != null else AccountDeletionRecordStoreScript.new()


## Reads the persisted record once per process. PlayerProgress calls this before it opens any save
## storage, then asks requires_released_storage() and has_unsettled_request() how to start. Every
## Main Menu open calls PlayerProgress.load_progress() again, so later calls only report the live
## state; re-reading could replace an operation that is mid-send.
func load_record() -> Dictionary:
	if _record_loaded:
		return get_state()
	_record_loaded = true
	_busy = false
	_last_failure = {}
	_record = {}
	var loaded: Dictionary = _record_store.load_record()
	if not bool(loaded.get("ok", false)):
		_phase = PHASE_RECORD_CORRUPT
		return get_state()
	_record = (loaded.get("record", {}) as Dictionary).duplicate(true)
	_phase = str(_record.get("phase", PHASE_IDLE)) if not _record.is_empty() else PHASE_IDLE
	if _phase == PHASE_ABANDONED:
		_record_store.clear_record()
		_record = {}
		_phase = PHASE_IDLE
	elif _phase != PHASE_IDLE and not PERSISTED_PHASES.has(_phase):
		_phase = PHASE_RECORD_CORRUPT
	elif bool(_record.get("send_in_progress", false)):
		# The process stopped while a send was in flight, and that send may have been applied.
		var operation := _operation()
		operation["possibly_applied"] = true
		_record["operation"] = operation
		_record["send_in_progress"] = false
	return get_state()


## True while gameplay and save writes must stay blocked: from preflight until a new game starts or
## the deletion settles as not applied.
func blocks_progress() -> bool:
	return _phase != PHASE_IDLE


## True when the old save must not be opened at all: cleanup has started, or the record is
## unreadable and nobody can tell whether it had.
func requires_released_storage() -> bool:
	return [PHASE_CLEANING, PHASE_READY, PHASE_ACTIVATING, PHASE_RECORD_CORRUPT].has(_phase)


## True when a request may have reached the server without a settled outcome. The old save stays
## intact but locked, with sync, refresh, and registration suspended.
func has_unsettled_request() -> bool:
	return [PHASE_SUBMITTING, PHASE_RETRY_PENDING, PHASE_UNCONFIRMED].has(_phase)


func get_state() -> Dictionary:
	var targets := _record.get("targets", {}) as Dictionary
	var last_error := _record.get("last_error", {}) as Dictionary
	return {
		"phase": _phase,
		"kind": str(_record.get("kind", "")),
		"busy": _busy,
		"blocks_progress": blocks_progress(),
		"receipt": (_record.get("receipt", {}) as Dictionary).duplicate(true),
		"cleanup_error": str(_record.get("cleanup_error", "")),
		"last_error": last_error.duplicate(true),
		"failure": _last_failure.duplicate(true),
		"support_reference": {
			"operation_id": str(_operation().get("request_id", "")),
			"correlation_id": str(last_error.get("correlation_id", "")),
			"player_id": str(targets.get("player_id", "")),
		},
	}


## Which deletion flow Support should offer: `{"kind": ..., "reason": ...}`. "account" needs the
## backend; "local_data" is for an installation guest that provably never registered;
## "registration_pending" means a registration may have created an account and must finish first.
func get_availability() -> Dictionary:
	if _phase != PHASE_IDLE:
		return _availability(AVAILABILITY_UNAVAILABLE, REASON_IN_PROGRESS)
	return _current_availability()


func _current_availability() -> Dictionary:
	var dependencies := _dependencies()
	var coordinator = dependencies.get("coordinator")
	var session_store = dependencies.get("session_store")
	if coordinator == null or session_store == null or coordinator.get_store() == null:
		return _availability(AVAILABILITY_UNAVAILABLE, REASON_STORAGE)
	if not session_store.supports_installation_destruction():
		return _availability(AVAILABILITY_UNAVAILABLE, REASON_UNSUPPORTED_BUILD)
	var active_namespace: Dictionary = coordinator.get_active_namespace()
	if str(active_namespace.get("kind", "")) == "player":
		var transport = dependencies.get("transport")
		if transport == null or not transport.can_use_backend():
			return _availability(
				AVAILABILITY_UNAVAILABLE,
				AccountDeletionOperationsScript.REASON_NOT_CONFIGURED
			)
		return _availability(AVAILABILITY_ACCOUNT)
	var sync: Dictionary = coordinator.get_store().get_sync_metadata()
	var registration := sync.get("guest_registration", {}) as Dictionary
	# A sent bootstrap may have created an account even though no response arrived. Only a finished
	# registration can tell, and a fresh challenge for the same key resumes that same player.
	if str(registration.get("phase", "")) == "bootstrap":
		return _availability(AVAILABILITY_REGISTRATION_PENDING)
	if not str(sync.get("guest_rebound_player_id", "")).is_empty():
		return _availability(AVAILABILITY_UNAVAILABLE, REASON_SIGNED_OUT_ACCOUNT)
	return _availability(AVAILABILITY_LOCAL_DATA)


## Keeps sync, registration, and other backend traffic from starting. PlayerProgress calls it as
## soon as it configures those services while a deletion blocks progress.
func suspend_network() -> void:
	_suspend_network(true)


## The language and audio settings recorded when the deletion started, for the new game.
func get_preserved_preferences() -> Dictionary:
	return (_record.get("preserved_preferences", {}) as Dictionary).duplicate(true)


## Lets a pending guest registration finish so availability can become "account".
func request_registration_resolution() -> void:
	var bootstrap_service = _dependencies().get("bootstrap_service")
	if _phase == PHASE_IDLE and bootstrap_service != null:
		bootstrap_service.request_registration()


## Continues a persisted operation after startup, once per process: replays an unsettled send,
## finishes cleanup, or completes a new-game activation the player already chose. Later calls (from
## each Main Menu open) only report the state; the player retries explicitly from the modal.
func resume() -> void:
	if _resumed or _busy:
		state_changed.emit(get_state())
		return
	_resumed = true
	match _phase:
		PHASE_SUBMITTING, PHASE_RETRY_PENDING:
			await retry()
		PHASE_UNCONFIRMED:
			_suspend_network(true)
			state_changed.emit(get_state())
		PHASE_CLEANING:
			await retry()
		PHASE_ACTIVATING:
			start_new_game()
		_:
			state_changed.emit(get_state())


func request_account_deletion() -> Dictionary:
	if _busy or _phase != PHASE_IDLE:
		return _refusal(REASON_IN_PROGRESS)
	var availability := get_availability()
	if str(availability.get("kind", "")) != AVAILABILITY_ACCOUNT:
		return _refusal(_unavailable_reason(availability))
	_busy = true
	_last_failure = {}
	_set_phase(PHASE_PREPARING)
	_suspend_network(true)
	if not await _wait_for_network_idle():
		return _abandon_preflight(REASON_NETWORK_BUSY)
	availability = _current_availability()
	if str(availability.get("kind", "")) != AVAILABILITY_ACCOUNT:
		return _abandon_preflight(REASON_ACCOUNT_CHANGED)

	var dependencies := _dependencies()
	var transport = dependencies.get("transport")
	var state_version := await _read_state_version()
	if state_version < 0:
		return get_state()
	var prepared: Dictionary = await transport.prepare_session(MIN_TOKEN_SECONDS)
	if not bool(prepared.get("ok", false)):
		return _abandon_preflight_with_error(prepared.get("error", {}) as Dictionary)
	var session_store = dependencies.get("session_store")
	var coordinator = dependencies.get("coordinator")
	var operation := AccountDeletionOperationsScript.create_operation(
		coordinator.get_active_player_id(),
		session_store.get_device_id(),
		str((prepared.get("session", {}) as Dictionary).get("session_id", "")),
		state_version
	)
	var record := _new_record(KIND_ACCOUNT, PHASE_SUBMITTING)
	record["operation"] = operation
	if not _persist(record):
		return _abandon_preflight(REASON_STORAGE)
	_set_phase(PHASE_SUBMITTING)
	await _submit()
	_busy = false
	state_changed.emit(get_state())
	return get_state()


func request_local_data_deletion() -> Dictionary:
	if _busy or _phase != PHASE_IDLE:
		return _refusal(REASON_IN_PROGRESS)
	var availability := get_availability()
	if str(availability.get("kind", "")) != AVAILABILITY_LOCAL_DATA:
		return _refusal(_unavailable_reason(availability))
	_busy = true
	_last_failure = {}
	_set_phase(PHASE_PREPARING)
	_suspend_network(true)
	if not await _wait_for_network_idle():
		return _abandon_preflight(REASON_NETWORK_BUSY)
	# A registration that was in flight may have finished while we waited.
	availability = _current_availability()
	if str(availability.get("kind", "")) != AVAILABILITY_LOCAL_DATA:
		return _abandon_preflight(REASON_ACCOUNT_CHANGED)
	if not _persist(_new_record(KIND_LOCAL_DATA, PHASE_CLEANING)):
		return _abandon_preflight(REASON_STORAGE)
	_set_phase(PHASE_CLEANING)
	_run_cleanup()
	_busy = false
	state_changed.emit(get_state())
	return get_state()


## Replays an unsettled request with its original identity, or retries an unfinished cleanup.
func retry() -> Dictionary:
	if _busy:
		return _refusal(REASON_IN_PROGRESS)
	match _phase:
		PHASE_SUBMITTING, PHASE_RETRY_PENDING, PHASE_UNCONFIRMED:
			_busy = true
			_suspend_network(true)
			_set_phase(PHASE_SUBMITTING)
			await _submit()
			_busy = false
			state_changed.emit(get_state())
		PHASE_CLEANING:
			_busy = true
			_suspend_network(true)
			_run_cleanup()
			_busy = false
			state_changed.emit(get_state())
		_:
			return _refusal(REASON_IN_PROGRESS)
	return get_state()


## The player's explicit choice after a finished deletion: a fresh identity and initial progress.
func start_new_game() -> Dictionary:
	if _busy or (_phase != PHASE_READY and _phase != PHASE_ACTIVATING):
		return _refusal(REASON_IN_PROGRESS)
	_busy = true
	if _phase == PHASE_READY:
		var activating := _record.duplicate(true)
		activating["phase"] = PHASE_ACTIVATING
		if not _persist(activating):
			_busy = false
			_last_failure = {"reason": REASON_STORAGE, "code": "", "correlation_id": ""}
			state_changed.emit(get_state())
			return get_state()
		_set_phase(PHASE_ACTIVATING)
	var preferences := (_record.get("preserved_preferences", {}) as Dictionary).duplicate(true)
	var result: Dictionary = _host.call("activate_progress_after_account_deletion", preferences)
	if not bool(result.get("ok", false)):
		_busy = false
		_last_failure = {"reason": REASON_STORAGE, "code": "", "correlation_id": ""}
		state_changed.emit(get_state())
		return get_state()
	# If removing the record fails, the next launch repeats an idempotent activation.
	_record_store.clear_record()
	_record = {}
	_busy = false
	_set_phase(PHASE_IDLE)
	_resume_network()
	new_game_started.emit()
	return get_state()


func _submit() -> void:
	var transport = _dependencies().get("transport")
	while true:
		var operation := _operation()
		var sending := _record.duplicate(true)
		sending["send_in_progress"] = true
		if transport == null or not _persist(sending):
			_settle_unsent(REASON_STORAGE)
			return
		var result: Dictionary = await transport.delete_json(
			AccountDeletionOperationsScript.PATH,
			AccountDeletionOperationsScript.PROTOCOL_VERSION,
			AccountDeletionOperationsScript.request_data(),
			operation
		)
		var interpreted := AccountDeletionOperationsScript.interpret_result(result)
		var reason := str(interpreted.get("reason", ""))
		operation["possibly_applied"] = bool(interpreted.get("possibly_applied", false))
		_record["operation"] = operation
		_record["send_in_progress"] = false
		_record["last_error"] = _safe_error(interpreted.get("error", {}) as Dictionary, reason)
		match str(interpreted.get("outcome", "")):
			AccountDeletionOperationsScript.OUTCOME_ACCEPTED:
				_record["receipt"] = interpreted.get("receipt", {})
				_record["last_error"] = {}
				var cleaning := _record.duplicate(true)
				cleaning["phase"] = PHASE_CLEANING
				if not _persist(cleaning):
					# Never destroy anything before the receipt is durable. Retry persists it first.
					_record["phase"] = PHASE_CLEANING
					_record["cleanup_error"] = REASON_STORAGE
					_record["receipt_unsaved"] = true
					_set_phase(PHASE_CLEANING)
					return
				_set_phase(PHASE_CLEANING)
				_run_cleanup()
				return
			AccountDeletionOperationsScript.OUTCOME_VERSION_CONFLICT:
				var rebuilds := int(_record.get("conflict_rebuilds", 0))
				if rebuilds >= MAX_CONFLICT_REBUILDS:
					_finish_not_applied(REASON_VERSION_CONFLICT, interpreted.get("error", {}) as Dictionary)
					return
				var current_version := int(interpreted.get("current_state_version", -1))
				if current_version < 0:
					current_version = await _read_state_version(false)
					if current_version < 0:
						_finish_not_applied(REASON_VERSION_CONFLICT, interpreted.get("error", {}) as Dictionary)
						return
				_record["operation"] = AccountDeletionOperationsScript.rebuild_after_version_conflict(
					operation,
					current_version
				)
				_record["conflict_rebuilds"] = rebuilds + 1
			AccountDeletionOperationsScript.OUTCOME_REJECTED:
				# Nothing was applied, so one refresh is safe. This covers a device clock that made
				# an expired token look fresh during preflight.
				if (
					reason == AccountDeletionOperationsScript.REASON_AUTHENTICATION
					and not bool(operation.get("possibly_applied", false))
					and not bool(_record.get("auth_refreshed", false))
				):
					var prepared: Dictionary = await transport.prepare_session(MIN_TOKEN_SECONDS, true)
					if bool(prepared.get("ok", false)):
						operation["session_id"] = str(
							(prepared.get("session", {}) as Dictionary).get("session_id", "")
						)
						_record["operation"] = operation
						_record["auth_refreshed"] = true
						continue
				_finish_not_applied(reason, interpreted.get("error", {}) as Dictionary)
				return
			AccountDeletionOperationsScript.OUTCOME_NOT_APPLIED:
				_finish_not_applied(reason, interpreted.get("error", {}) as Dictionary)
				return
			_:
				var phase := PHASE_RETRY_PENDING if REPLAYABLE_REASONS.has(reason) else PHASE_UNCONFIRMED
				var unsettled := _record.duplicate(true)
				unsettled["phase"] = phase
				# If this write fails, the stored "send in progress" flag still forces a replay.
				_persist(unsettled)
				_record["phase"] = phase
				_set_phase(phase)
				return


## Removes the deleted account's local data. Every step is idempotent and runs even after an
## earlier one fails, and the record keeps `ready` from being reached until all of them succeed.
func _run_cleanup() -> void:
	if bool(_record.get("receipt_unsaved", false)):
		var cleaning := _record.duplicate(true)
		cleaning.erase("receipt_unsaved")
		cleaning["phase"] = PHASE_CLEANING
		if not _persist(cleaning):
			_record["cleanup_error"] = REASON_STORAGE
			_set_phase(PHASE_CLEANING)
			return
	_host.call("release_progress_for_account_deletion")
	var targets := _record.get("targets", {}) as Dictionary
	var errors := PackedStringArray()
	var session_store = _dependencies().get("session_store")
	if session_store == null:
		errors.append("Secure session store is unavailable.")
	else:
		var player_id := str(targets.get("player_id", ""))
		if LocalSaveCodecScript.is_uuid(player_id):
			_collect_error(errors, session_store.clear_session(player_id))
		_collect_error(
			errors,
			session_store.destroy_installation_identity(str(targets.get("installation_id", "")))
		)
	for raw_namespace in targets.get("namespaces", []) as Array:
		_collect_error(errors, LocalSaveStoreScript.erase_namespace(raw_namespace as Dictionary))
	_collect_error(errors, _remove_file(LEGACY_SAVE_PATH))
	_collect_error(errors, AccountSaveCoordinatorScript.clear_active_namespace())
	_collect_error(errors, _remove_file(BackendCatalogCacheScript.DEFAULT_CACHE_PATH))
	_collect_error(errors, _remove_file(BackendLeaderboardCacheScript.DEFAULT_CACHE_PATH))

	var next := _record.duplicate(true)
	next["cleanup_error"] = errors[0] if not errors.is_empty() else ""
	next["phase"] = PHASE_CLEANING if not errors.is_empty() else PHASE_READY
	if not _persist(next):
		_record["cleanup_error"] = REASON_STORAGE
		_set_phase(PHASE_CLEANING)
		return
	_set_phase(str(next.get("phase", PHASE_CLEANING)))


func _new_record(kind: String, phase: String) -> Dictionary:
	return {
		"kind": kind,
		"phase": phase,
		"created_at": LocalSaveCodecScript.iso_timestamp(),
		"targets": _cleanup_targets(kind),
		"operation": {},
		"send_in_progress": false,
		"conflict_rebuilds": 0,
		"auth_refreshed": false,
		"receipt": {},
		"last_error": {},
		"cleanup_error": "",
		"preserved_preferences": _host.call("get_account_deletion_preserved_preferences"),
	}


## The deleted account's player id, installation identity, and every namespace that can hold its
## progress: the active one, this installation's guest fallback, and the guest namespace it was
## rebound from. Nothing else is ever removed.
func _cleanup_targets(kind: String) -> Dictionary:
	var dependencies := _dependencies()
	var coordinator = dependencies.get("coordinator")
	var session_store = dependencies.get("session_store")
	var installation_id: String = session_store.get_installation_id()
	var namespaces := []
	_append_namespace(namespaces, coordinator.get_active_namespace())
	_append_namespace(namespaces, {"kind": "installation_guest", "installation_id": installation_id})
	var store = coordinator.get_store()
	if store != null:
		_append_namespace(namespaces, store.get_sync_metadata().get("source_installation_guest", {}))
	return {
		"player_id": coordinator.get_active_player_id() if kind == KIND_ACCOUNT else "",
		"installation_id": installation_id,
		"device_id": session_store.get_device_id(),
		"namespaces": namespaces,
	}


func _append_namespace(namespaces: Array, candidate: Variant) -> void:
	if not LocalSaveCodecScript.is_namespace(candidate):
		return
	for existing in namespaces:
		if LocalSaveCodecScript.namespace_key(existing) == LocalSaveCodecScript.namespace_key(candidate):
			return
	namespaces.append((candidate as Dictionary).duplicate(true))


## Reads the authoritative state version while the rest of the backend traffic is suspended. On
## failure during preflight it abandons the deletion, which was not sent, and returns -1.
func _read_state_version(abandon_on_failure: bool = true) -> int:
	var transport = _dependencies().get("transport")
	var state: Dictionary = await transport.get_json(BackendReadOperationsScript.player_state_path(), true)
	var meta := state.get("meta", {}) as Dictionary
	if bool(state.get("ok", false)) and int(meta.get("state_version", -1)) >= 0:
		return int(meta.get("state_version", -1))
	if abandon_on_failure:
		var error := state.get("error", {}) as Dictionary
		if bool(state.get("ok", false)):
			error = {"code": "transport.malformed_response", "category": "internal"}
		_abandon_preflight_with_error(error)
	return -1


## A send that could not even be recorded. Without an earlier possibly applied attempt the account
## is untouched; otherwise the stored record still forces a replay on the next attempt.
func _settle_unsent(reason: String) -> void:
	if not bool(_operation().get("possibly_applied", false)):
		_finish_not_applied(reason, {})
		return
	_last_failure = {"reason": reason, "code": "", "correlation_id": ""}
	_record["phase"] = PHASE_RETRY_PENDING
	_set_phase(PHASE_RETRY_PENDING)


## The deletion was not applied: forget the operation and give the account back.
func _finish_not_applied(reason: String, error: Dictionary) -> void:
	_last_failure = {
		"reason": reason,
		"code": str(error.get("code", "")),
		"correlation_id": str(error.get("correlation_id", "")),
	}
	if not bool(_record_store.clear_record().get("ok", false)):
		# A stale record must never replay a deletion the player was told did not happen.
		var abandoned := _record.duplicate(true)
		abandoned["phase"] = PHASE_ABANDONED
		if not _persist(abandoned):
			_last_failure["reason"] = REASON_STORAGE
			_record["phase"] = PHASE_UNCONFIRMED
			_set_phase(PHASE_UNCONFIRMED)
			return
	_record = {}
	_set_phase(PHASE_IDLE)
	_resume_network()


func _abandon_preflight(reason: String) -> Dictionary:
	return _abandon_preflight_with_error({}, reason)


func _abandon_preflight_with_error(error: Dictionary, reason: String = "") -> Dictionary:
	_last_failure = {
		"reason": reason if not reason.is_empty() else AccountDeletionOperationsScript.failure_reason(error),
		"code": str(error.get("code", "")),
		"correlation_id": str(error.get("correlation_id", "")),
	}
	_record = {}
	_busy = false
	_set_phase(PHASE_IDLE)
	_resume_network()
	return get_state()


func _refusal(reason: String) -> Dictionary:
	var state := get_state()
	state["refused"] = reason
	return state


func _suspend_network(suspended: bool) -> void:
	var dependencies := _dependencies()
	for key in ["transport", "sync_service", "bootstrap_service"]:
		var service = dependencies.get(key)
		if service != null:
			service.set_suspended(suspended)


func _resume_network() -> void:
	_suspend_network(false)
	var dependencies := _dependencies()
	var sync_service = dependencies.get("sync_service")
	if sync_service != null:
		sync_service.request_background_sync()
	var bootstrap_service = dependencies.get("bootstrap_service")
	if bootstrap_service != null:
		bootstrap_service.request_registration()


## Waits for sync, registration, and backend requests that started before suspension. Cancelling
## them instead could hide a session rotation the server already applied.
func _wait_for_network_idle() -> bool:
	var deadline := Time.get_ticks_msec() + NETWORK_IDLE_TIMEOUT_MSEC
	while _network_busy():
		if Time.get_ticks_msec() >= deadline:
			return false
		await get_tree().process_frame
	return true


func _network_busy() -> bool:
	var dependencies := _dependencies()
	for key in ["transport", "sync_service", "bootstrap_service"]:
		var service = dependencies.get(key)
		if service != null and service.is_busy():
			return true
	return false


func _persist(record: Dictionary) -> bool:
	var result: Dictionary = _record_store.save_record(record)
	if not bool(result.get("ok", false)):
		return false
	_record = (result.get("record", {}) as Dictionary).duplicate(true)
	return true


func _set_phase(phase: String) -> void:
	_phase = phase
	state_changed.emit(get_state())


func _operation() -> Dictionary:
	return (_record.get("operation", {}) as Dictionary).duplicate(true)


func _dependencies() -> Dictionary:
	if _host == null:
		return {}
	return _host.call("get_account_deletion_dependencies") as Dictionary


func _availability(kind: String, reason: String = "") -> Dictionary:
	return {"kind": kind, "reason": reason}


## Why a flow other than the available one was refused: the unavailability reason, or the flow that
## applies instead (for example "registration_pending").
func _unavailable_reason(availability: Dictionary) -> String:
	var reason := str(availability.get("reason", ""))
	return reason if not reason.is_empty() else str(availability.get("kind", AVAILABILITY_UNAVAILABLE))


## Keeps only what support needs: never a token, payload, or server message.
func _safe_error(error: Dictionary, reason: String) -> Dictionary:
	if error.is_empty():
		return {}
	return {
		"code": str(error.get("code", "")),
		"reason": reason,
		"http_status": int(error.get("http_status", 0)),
		"correlation_id": str(error.get("correlation_id", "")),
	}


func _collect_error(errors: PackedStringArray, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		errors.append(str(result.get("error", "Cleanup step failed.")))


func _remove_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "error": ""}
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
		return {"ok": false, "error": "Could not remove %s." % path.get_file()}
	return {"ok": true, "error": ""}
