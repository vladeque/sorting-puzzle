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

	if _bridge != null:
		var bridge_result = _bridge.call(
			"ensure_installation_key",
			str(_public_identity.get("installation_id", ""))
		)
		if bridge_result is Dictionary and not bool(bridge_result.get("ok", true)):
			return _error(str(bridge_result.get("error", "Secure installation key setup failed.")))
		if (bridge_result is bool and not bridge_result) or bridge_result == null:
			return _error("Secure installation key setup failed.")
		var set_result = _bridge.call("set_installation_id", get_installation_id())
		if (set_result is bool and not set_result) or set_result == null:
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
	return _bridge != null


func get_installation_public_key_der_base64() -> String:
	if _bridge == null:
		return ""
	return str(_bridge.call("get_installation_public_key_der", get_installation_id()))


func sign_operation_hash(operation_hash: String) -> Dictionary:
	if not LocalSaveCodecScript.is_hash(operation_hash):
		return _error("Operation hash is invalid.")

	if _bridge != null:
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
	if _bridge == null:
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
	if _bridge != null:
		var result = _bridge.call("store_player_session", player_id, JSON.stringify(session))
		return _normalize_bridge_result(result, "Secure session write failed.")
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		return _error("A secure storage bridge is required on mobile.")
	_development_sessions[player_id] = session.duplicate(true)
	return _success()


func load_session(player_id: String) -> Dictionary:
	if _bridge != null:
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
	var bridge := _resolved_bridge()
	if bridge != null:
		return _normalize_bridge_result(
			bridge.call("clear_player_session", player_id),
			"Secure session removal failed."
		)
	_development_sessions.erase(player_id)
	return _success()


## GAME-012: whether this build can destroy the installation signing key after an account
## deletion. Desktop development builds keep no key, so they qualify without a bridge.
func supports_installation_destruction() -> bool:
	var bridge := _resolved_bridge()
	if bridge != null:
		return bridge.has_method("destroy_installation_key")
	return OS.get_name() != "Android" and OS.get_name() != "iOS"


## GAME-012: destroys the signing key and native installation binding for `installation_id`, then
## removes the public identity files that name it. Idempotent, and it never creates a replacement:
## initialize() does that when the player explicitly starts a new game. A file naming a different
## valid installation is left alone. Works without initialize(), so restart recovery can finish a
## cleanup without first generating a new identity.
func destroy_installation_identity(installation_id: String) -> Dictionary:
	if not LocalSaveCodecScript.is_uuid(installation_id):
		return _error("Installation id is invalid.")
	var bridge := _resolved_bridge()
	if bridge != null:
		if not bridge.has_method("destroy_installation_key"):
			return _error("This build cannot remove the secure installation key.")
		var result := _normalize_bridge_result(
			bridge.call("destroy_installation_key", installation_id),
			"Secure installation key removal failed."
		)
		if not bool(result.get("ok", false)):
			return result
	elif OS.get_name() == "Android" or OS.get_name() == "iOS":
		return _error("A secure storage bridge is required on mobile.")
	for path in [IDENTITY_PATH, IDENTITY_TEMP_PATH, IDENTITY_PREVIOUS_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var named_installation := _installation_id_in_file(path)
		if not named_installation.is_empty() and named_installation != installation_id:
			continue
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			return _error("Could not remove the public installation identity.")
	if get_installation_id() == installation_id:
		_public_identity = {}
	return _success()


func _resolved_bridge() -> Object:
	return _bridge if _bridge != null else _find_bridge()


## The valid installation id a public identity file names, or "" for a missing, torn, or invalid
## file.
func _installation_id_in_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return ""
	var installation_id = (parsed as Dictionary).get("installation_id")
	return str(installation_id) if LocalSaveCodecScript.is_uuid(installation_id) else ""


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
