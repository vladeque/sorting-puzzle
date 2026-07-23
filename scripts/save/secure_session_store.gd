extends RefCounted
class_name SecureSessionStore

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")
const IDENTITY_PATH := "user://sorting_puzzle_installation.json"
const IDENTITY_TEMP_PATH := "user://sorting_puzzle_installation.tmp"
const IDENTITY_PREVIOUS_PATH := "user://sorting_puzzle_installation.previous.json"
const DEFAULT_BRIDGE := "SortingPuzzleSecureStoreBridge"
const BRIDGE_SETTING := "application/config/secure_storage_bridge_singleton"
const DEVELOPMENT_SIGNATURE_BYTES := 70

var _bridge: Object
var _public_identity := {}
var _development_sessions := {}


func initialize() -> Dictionary:
	_bridge = _find_bridge()
	_public_identity = _load_public_identity()
	if _public_identity.is_empty():
		_public_identity = {
			"format": "sorting-puzzle-installation/1",
			"installation_id": LocalSaveCodecScript.create_uuid(),
			"device_id": LocalSaveCodecScript.create_uuid(),
		}
		var save_result := _save_public_identity()
		if not bool(save_result.get("ok", false)):
			return save_result

	if _bridge != null and _bridge.has_method("ensure_installation_key"):
		var bridge_result = _bridge.call(
			"ensure_installation_key",
			str(_public_identity.get("installation_id", ""))
		)
		if bridge_result is Dictionary and not bool(bridge_result.get("ok", true)):
			return _error(str(bridge_result.get("error", "Secure installation key setup failed.")))
		if bridge_result is bool and not bridge_result:
			return _error("Secure installation key setup failed.")
		if _bridge.has_method("set_installation_id"):
			var set_result = _bridge.call("set_installation_id", get_installation_id())
			if set_result is bool and not set_result:
				return _error("Secure installation identity binding failed.")

	return _success({
		"installation_id": get_installation_id(),
		"device_id": get_device_id(),
		"secure_bridge_available": is_secure_bridge_available(),
	})


func get_installation_id() -> String:
	return str(_public_identity.get("installation_id", ""))


func get_device_id() -> String:
	return str(_public_identity.get("device_id", ""))


func is_secure_bridge_available() -> bool:
	return _bridge != null


func can_synchronize() -> bool:
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return false
	return (
		_bridge != null
		and _bridge.has_method("sign_save_operation_hash")
		and _bridge.has_method("sign_installation_payload")
	)


func get_installation_public_key_der_base64() -> String:
	if _bridge == null or not _bridge.has_method("get_installation_public_key_der"):
		return ""
	return str(_bridge.call("get_installation_public_key_der", get_installation_id()))


func sign_operation_hash(operation_hash: String) -> Dictionary:
	if not LocalSaveCodecScript.is_hash(operation_hash):
		return _error("Operation hash is invalid.")

	if _bridge != null and _bridge.has_method("sign_save_operation_hash"):
		var result = _bridge.call("sign_save_operation_hash", operation_hash)
		if result is Dictionary:
			if not bool(result.get("ok", false)):
				return _error(str(result.get("error", "Secure operation signing failed.")))
			var signature := str(result.get("signature", ""))
			if not signature.is_empty():
				return _success({"signature": signature, "development_only": false})
		elif result is String and not result.is_empty():
			return _success({"signature": result, "development_only": false})
		return _error("Secure operation signing returned no signature.")

	# A schema-shaped marker keeps desktop save/crash tests deterministic. Sync is disabled
	# without a mobile bridge, so this value is never presented as a production signature.
	var marker := PackedByteArray()
	marker.resize(DEVELOPMENT_SIGNATURE_BYTES)
	var seed := operation_hash.to_utf8_buffer()
	for index in range(marker.size()):
		marker[index] = seed[index % seed.size()]
	return _success({
		"signature": Marshalls.raw_to_base64(marker),
		"development_only": true,
	})


func sign_installation_payload(payload: String) -> Dictionary:
	if payload.is_empty():
		return _error("Installation proof payload is empty.")
	if _bridge == null or not _bridge.has_method("sign_installation_payload"):
		return _error("Secure installation proof signing is unavailable.")
	var result = _bridge.call("sign_installation_payload", payload)
	if result is Dictionary:
		if not bool(result.get("ok", false)):
			return _error(str(result.get("error", "Secure installation proof signing failed.")))
		var dictionary_signature := str(result.get("signature", ""))
		return (
			_success({"signature": dictionary_signature})
			if not dictionary_signature.is_empty()
			else _error("Secure installation proof signing returned no signature.")
		)
	if result is String and not result.is_empty():
		return _success({"signature": result})
	return _error("Secure installation proof signing returned no signature.")


func store_session(player_id: String, session: Dictionary) -> Dictionary:
	if not LocalSaveCodecScript.is_uuid(player_id):
		return _error("Player id is invalid.")
	if _bridge != null and _bridge.has_method("store_player_session"):
		var result = _bridge.call("store_player_session", player_id, JSON.stringify(session))
		return _normalize_bridge_result(result, "Secure session write failed.")
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		return _error("A secure storage bridge is required on mobile.")
	_development_sessions[player_id] = session.duplicate(true)
	return _success()


func load_session(player_id: String) -> Dictionary:
	if _bridge != null and _bridge.has_method("load_player_session"):
		var result = _bridge.call("load_player_session", player_id)
		if result is Dictionary and bool(result.get("ok", false)):
			var session = result.get("session", result.get("data", {}))
			if session is Dictionary:
				return _success({"session": (session as Dictionary).duplicate(true)})
			return _error("Secure session read returned invalid data.")
		if result is String and not result.is_empty():
			var parsed = JSON.parse_string(result)
			if parsed is Dictionary:
				return _success({"session": (parsed as Dictionary).duplicate(true)})
			return _error("Secure session read returned invalid JSON.")
	if _development_sessions.has(player_id):
		return _success({"session": (_development_sessions[player_id] as Dictionary).duplicate(true)})
	return _error("No secure session is available for this player.")


func clear_session(player_id: String) -> Dictionary:
	if _bridge != null and _bridge.has_method("clear_player_session"):
		return _normalize_bridge_result(
			_bridge.call("clear_player_session", player_id),
			"Secure session removal failed."
		)
	_development_sessions.erase(player_id)
	return _success()


func refresh_session(player_id: String) -> Dictionary:
	if _bridge == null or not _bridge.has_method("refresh_player_session"):
		return _error("Secure session refresh is unavailable.")
	var result = _bridge.call("refresh_player_session", player_id)
	if not (result is Dictionary) or not bool(result.get("ok", false)):
		return _error(
			str(result.get("error", "Secure session refresh failed."))
			if result is Dictionary
			else "Secure session refresh failed."
		)
	var session = result.get("session", result.get("data", {}))
	if not (session is Dictionary):
		return _error("Secure session refresh returned invalid data.")
	return _success({"session": (session as Dictionary).duplicate(true)})


func _find_bridge() -> Object:
	var candidates := PackedStringArray()
	var configured := str(ProjectSettings.get_setting(BRIDGE_SETTING, ""))
	if not configured.is_empty():
		candidates.append(configured)
	candidates.append(DEFAULT_BRIDGE)
	for singleton_name in candidates:
		if Engine.has_singleton(singleton_name):
			return Engine.get_singleton(singleton_name)
	return null


func _load_public_identity() -> Dictionary:
	for path in [IDENTITY_PATH, IDENTITY_TEMP_PATH, IDENTITY_PREVIOUS_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if not (parsed is Dictionary):
			continue
		var data := parsed as Dictionary
		if (
			str(data.get("format", "")) == "sorting-puzzle-installation/1"
			and LocalSaveCodecScript.is_uuid(data.get("installation_id"))
			and LocalSaveCodecScript.is_uuid(data.get("device_id"))
		):
			return data
	return {}


func _save_public_identity() -> Dictionary:
	var file := FileAccess.open(IDENTITY_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return _error("Could not persist public installation identity.")
	file.store_string(JSON.stringify(_public_identity))
	file.flush()
	file = null

	if FileAccess.file_exists(IDENTITY_PREVIOUS_PATH):
		var remove_error := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(IDENTITY_PREVIOUS_PATH)
		)
		if remove_error != OK:
			return _error("Could not rotate public installation identity.")
	if FileAccess.file_exists(IDENTITY_PATH):
		var rotate_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(IDENTITY_PATH),
			ProjectSettings.globalize_path(IDENTITY_PREVIOUS_PATH)
		)
		if rotate_error != OK:
			return _error("Could not preserve public installation identity.")
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(IDENTITY_TEMP_PATH),
		ProjectSettings.globalize_path(IDENTITY_PATH)
	)
	if rename_error != OK:
		return _error("Could not finalize public installation identity.")
	return _success()


func _normalize_bridge_result(result: Variant, fallback_error: String) -> Dictionary:
	if result == null:
		return _success()
	if result is bool:
		return _success() if result else _error(fallback_error)
	if result is Dictionary:
		return _success() if bool(result.get("ok", false)) else _error(str(result.get("error", fallback_error)))
	return _success()


func _success(data: Dictionary = {}) -> Dictionary:
	var result := {"ok": true, "error": ""}
	result.merge(data, true)
	return result


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
