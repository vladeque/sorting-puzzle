extends RefCounted
class_name AccountSaveCoordinator

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")
const LocalSaveStoreScript := preload("res://scripts/save/local_save_store.gd")
const ACTIVE_NAMESPACE_PATH := "user://active_save_namespace.json"
const ACTIVE_NAMESPACE_TEMP_PATH := "user://active_save_namespace.tmp"

var _session_store: SecureSessionStore
var _store: LocalSaveStore
var _guest_bootstrap_snapshot := {}
var _new_identity_snapshot := {}
var _initial_preferences := {}
var _legacy_path := ""
var _legacy_version := 0


func _init(session_store: SecureSessionStore = null) -> void:
	_session_store = session_store


func initialize(
	initial_snapshot: Dictionary,
	initial_preferences: Dictionary,
	legacy_path: String = "",
	legacy_version: int = 0,
	new_identity_snapshot: Dictionary = {}
) -> Dictionary:
	if _session_store == null:
		return _error("Secure session store is not configured.")
	_guest_bootstrap_snapshot = initial_snapshot.duplicate(true)
	_new_identity_snapshot = (
		new_identity_snapshot.duplicate(true)
		if not new_identity_snapshot.is_empty()
		else initial_snapshot.duplicate(true)
	)
	_initial_preferences = initial_preferences.duplicate(true)
	_legacy_path = legacy_path
	_legacy_version = legacy_version

	var active_namespace := _load_active_namespace()
	if active_namespace.is_empty():
		active_namespace = {
			"kind": "installation_guest",
			"installation_id": _session_store.get_installation_id(),
		}
	var is_installation_guest := (
		str(active_namespace.get("kind", "")) == "installation_guest"
		and str(active_namespace.get("installation_id", "")) == _session_store.get_installation_id()
	)
	return _activate(active_namespace, is_installation_guest)


func get_store() -> LocalSaveStore:
	return _store


func get_active_namespace() -> Dictionary:
	return _store.get_namespace() if _store != null else {}


func get_active_player_id() -> String:
	var active_namespace := get_active_namespace()
	return str(active_namespace.get("player_id", "")) if str(active_namespace.get("kind", "")) == "player" else ""


func bind_registered_guest(player_id: String, session: Dictionary) -> Dictionary:
	if _store == null:
		return _error("No save namespace is active.")
	var store_result := _session_store.store_session(player_id, session)
	if not bool(store_result.get("ok", false)):
		return store_result
	var rebind_result := _store.rebind_guest_to_player(player_id)
	if not bool(rebind_result.get("ok", false)):
		return rebind_result
	var persist_result := _save_active_namespace(_store.get_namespace())
	if not bool(persist_result.get("ok", false)):
		return persist_result
	return _success({
		"snapshot": _store.get_snapshot(),
		"preferences": _store.get_preferences(),
		"namespace": _store.get_namespace(),
	})


func switch_to_player(
	player_id: String,
	session: Dictionary = {},
	remote_checkpoint: Dictionary = {}
) -> Dictionary:
	if not LocalSaveCodecScript.is_uuid(player_id):
		return _error("Player id is invalid.")
	if not session.is_empty():
		var session_result := _session_store.store_session(player_id, session)
		if not bool(session_result.get("ok", false)):
			return session_result
	var result := _activate({"kind": "player", "player_id": player_id})
	if not bool(result.get("ok", false)):
		return result
	if not remote_checkpoint.is_empty() and int(_store.get_sync_metadata().get("journal_head_sequence", 0)) == 0:
		result["remote_checkpoint"] = remote_checkpoint.duplicate(true)
	return result


func switch_to_installation_guest() -> Dictionary:
	return _activate({
		"kind": "installation_guest",
		"installation_id": _session_store.get_installation_id(),
	})


func sign_out() -> Dictionary:
	return switch_to_installation_guest()


## GAME-012: drops the open store before account-deletion cleanup removes its files, so nothing
## writes a generation back into a namespace being deleted.
func release_store() -> void:
	_store = null


## GAME-012: removes the persisted active-namespace pointer. The next initialize() then opens the
## installation guest of whatever installation identity exists at that point.
static func clear_active_namespace() -> Dictionary:
	for path in [ACTIVE_NAMESPACE_PATH, ACTIVE_NAMESPACE_TEMP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			return {"ok": false, "error": "Could not remove the active save namespace."}
	return {"ok": true, "error": ""}


func _activate(save_namespace: Dictionary, allow_legacy: bool = false) -> Dictionary:
	if not LocalSaveCodecScript.is_namespace(save_namespace):
		return _error("Save namespace is invalid.")
	var next_store := LocalSaveStoreScript.new(_session_store)
	var bootstrap_snapshot := (
		_guest_bootstrap_snapshot
		if allow_legacy
		else _new_identity_snapshot
	)
	var result := next_store.open_namespace(
		save_namespace,
		bootstrap_snapshot,
		_initial_preferences,
		_legacy_path if allow_legacy else "",
		_legacy_version if allow_legacy else 0
	)
	if not bool(result.get("ok", false)):
		return result
	var persist_result := _save_active_namespace(save_namespace)
	if not bool(persist_result.get("ok", false)):
		return persist_result
	_store = next_store
	result["namespace"] = save_namespace.duplicate(true)
	return result


func _load_active_namespace() -> Dictionary:
	for path in [ACTIVE_NAMESPACE_PATH, ACTIVE_NAMESPACE_TEMP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and LocalSaveCodecScript.is_namespace(parsed):
			return parsed as Dictionary
	return {}


func _save_active_namespace(save_namespace: Dictionary) -> Dictionary:
	var file := FileAccess.open(ACTIVE_NAMESPACE_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return _error("Could not persist the active save namespace.")
	file.store_string(JSON.stringify(save_namespace))
	file.flush()
	file = null
	if FileAccess.file_exists(ACTIVE_NAMESPACE_PATH):
		var remove_error := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(ACTIVE_NAMESPACE_PATH)
		)
		if remove_error != OK:
			return _error("Could not replace the active save namespace.")
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(ACTIVE_NAMESPACE_TEMP_PATH),
		ProjectSettings.globalize_path(ACTIVE_NAMESPACE_PATH)
	)
	if rename_error != OK:
		return _error("Could not finalize the active save namespace.")
	return _success()


func _success(data: Dictionary = {}) -> Dictionary:
	var result := {"ok": true, "error": ""}
	result.merge(data, true)
	return result


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
