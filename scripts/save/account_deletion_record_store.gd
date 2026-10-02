extends RefCounted
class_name AccountDeletionRecordStore

## GAME-012 durable account-deletion operation record (docs/ACCOUNT_DELETION_PLAN.md). It lives
## outside every save namespace, so cleanup can delete those namespaces and still remember what it
## is doing. Writes use the local save store's pattern: a validated temporary file, then
## current -> previous rotation and promotion. Each generation carries a SHA-256 integrity hash and
## a revision, and loading picks the newest valid one, so a torn write falls back to the previous
## state instead of unlocking a deleting account. When files exist but none is valid, load_record()
## reports `corrupt` and the caller must stay locked.
##
## The record holds only public identifiers, phases, the deletion receipt, and safe diagnostics.
## Credentials stay in SecureSessionStore.

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")

const FORMAT := "sorting-puzzle-account-deletion/1"
const DEFAULT_DIRECTORY := "user://account_deletion"
const CURRENT_FILE := "operation.json"
const PREVIOUS_FILE := "operation.previous.json"
const TEMP_FILE := "operation.tmp"

var _directory: String


func _init(directory: String = DEFAULT_DIRECTORY) -> void:
	_directory = directory


## Returns `{"ok": true, "record": Dictionary}` with an empty record when no deletion is in
## progress, or `{"ok": false, "corrupt": true, ...}` when record files exist but none validates.
func load_record() -> Dictionary:
	var found_file := false
	var best := {}
	for file_name in [CURRENT_FILE, PREVIOUS_FILE, TEMP_FILE]:
		var path := _path(file_name)
		if not FileAccess.file_exists(path):
			continue
		found_file = true
		var candidate := _read_valid(path)
		if candidate.is_empty():
			continue
		if best.is_empty() or int(candidate.get("revision", 0)) > int(best.get("revision", 0)):
			best = candidate
	if best.is_empty():
		if found_file:
			return {"ok": false, "corrupt": true, "error": "The account deletion record is unreadable."}
		return {"ok": true, "corrupt": false, "error": "", "record": {}}
	best.erase("integrity")
	return {"ok": true, "corrupt": false, "error": "", "record": best}


## Persists `record` as the next revision and returns the stored copy in `record`.
func save_record(record: Dictionary) -> Dictionary:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))
	if directory_error != OK:
		return _error("Could not create the account deletion record directory.")
	var latest := load_record()
	var revision := int((latest.get("record", {}) as Dictionary).get("revision", 0))
	var document := record.duplicate(true)
	document.erase("integrity")
	document["format"] = FORMAT
	document["revision"] = maxi(revision, int(record.get("revision", 0))) + 1
	document["updated_at"] = LocalSaveCodecScript.iso_timestamp()
	var digest := LocalSaveCodecScript.sha256_json(document)
	if digest.is_empty():
		return _error("The account deletion record has a value canonical JSON cannot encode.")
	var persistable := document.duplicate(true)
	persistable["integrity"] = {"sha256": digest}

	var temp_path := _path(TEMP_FILE)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _error("Could not open the temporary account deletion record.")
	file.store_string(JSON.stringify(persistable))
	file.flush()
	file = null
	if _read_valid(temp_path).is_empty():
		return _error("The temporary account deletion record did not validate.")

	var current_path := _path(CURRENT_FILE)
	var previous_path := _path(PREVIOUS_FILE)
	if FileAccess.file_exists(previous_path):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(previous_path)) != OK:
			return _error("Could not rotate the previous account deletion record.")
	if FileAccess.file_exists(current_path):
		if DirAccess.rename_absolute(
			ProjectSettings.globalize_path(current_path),
			ProjectSettings.globalize_path(previous_path)
		) != OK:
			return _error("Could not preserve the previous account deletion record.")
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(current_path)
	) != OK:
		return _error("Could not promote the account deletion record.")
	return {"ok": true, "error": "", "record": document}


## Removes every generation. Called only once the operation is finished: not applied, or a new game
## has been activated.
func clear_record() -> Dictionary:
	for file_name in [TEMP_FILE, CURRENT_FILE, PREVIOUS_FILE]:
		var path := _path(file_name)
		if FileAccess.file_exists(path):
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
				return _error("Could not remove the account deletion record.")
	var absolute_directory := ProjectSettings.globalize_path(_directory)
	if DirAccess.dir_exists_absolute(absolute_directory):
		DirAccess.remove_absolute(absolute_directory)
	return {"ok": true, "error": ""}


func _read_valid(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	var document := parsed as Dictionary
	var integrity = document.get("integrity")
	if not (integrity is Dictionary) or str(document.get("format", "")) != FORMAT:
		return {}
	var unsigned := document.duplicate(true)
	unsigned.erase("integrity")
	var digest := LocalSaveCodecScript.sha256_json(unsigned)
	if digest.is_empty() or str((integrity as Dictionary).get("sha256", "")) != digest:
		return {}
	return document


func _path(file_name: String) -> String:
	return _directory.path_join(file_name)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
