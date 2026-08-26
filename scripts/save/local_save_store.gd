extends RefCounted
class_name LocalSaveStore

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")
const LOCAL_FORMAT := "sorting-puzzle-local-save/1"
const LOCAL_SCHEMA_VERSION := 1
const SAVE_ROOT := "user://save_v2"
const CURRENT_FILE := "current.json"
const PREVIOUS_FILE := "previous.json"
const TEMP_FILE := "pending.tmp"
const LEGACY_COPY_FILE := "legacy_v4.previous.json"
const RECENT_ACKNOWLEDGED_OPERATIONS := 100
const VALID_OPERATION_TYPES := [
	"campaign_completion",
	"campaign_attempt",
	"resource_spend",
	"life_purchase",
	"life_state",
	"profile_edit",
]

var _session_store: SecureSessionStore
var _namespace := {}
var _document := {}
var _directory := ""
var _test_interrupt_stage := ""


func _init(session_store: SecureSessionStore = null) -> void:
	_session_store = session_store


func open_namespace(
	save_namespace: Dictionary,
	initial_snapshot: Dictionary,
	initial_preferences: Dictionary,
	legacy_source_path: String = "",
	legacy_version: int = 0
) -> Dictionary:
	if not LocalSaveCodecScript.is_namespace(save_namespace):
		return _error("Save namespace is invalid.")
	if _session_store == null:
		return _error("Secure session store is not configured.")

	_namespace = save_namespace.duplicate(true)
	_directory = "%s/%s" % [SAVE_ROOT, LocalSaveCodecScript.namespace_key(_namespace)]
	var make_directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_directory)
	)
	if make_directory_error != OK:
		return _error("Could not create the local save namespace.")

	var recovered := _load_newest_valid_generation()
	if bool(recovered.get("ok", false)):
		_document = (recovered.get("document", {}) as Dictionary).duplicate(true)
		_mark_successful_restart()
		return _success({
			"snapshot": get_snapshot(),
			"preferences": get_preferences(),
			"recovered_from": recovered.get("source", CURRENT_FILE),
		})

	_document = _new_document(initial_snapshot, initial_preferences, legacy_version)
	var write_result := _write_generation(_document)
	if not bool(write_result.get("ok", false)):
		_document = {}
		return write_result
	if not legacy_source_path.is_empty() and FileAccess.file_exists(legacy_source_path):
		_copy_legacy_save(legacy_source_path)
	return _success({
		"snapshot": get_snapshot(),
		"preferences": get_preferences(),
		"migrated": legacy_version > 0,
	})


func get_snapshot() -> Dictionary:
	return (_document.get("snapshot", {}) as Dictionary).duplicate(true)


func get_preferences() -> Dictionary:
	return (_document.get("preferences", {}) as Dictionary).duplicate(true)


func get_journal() -> Array:
	return (_document.get("journal", []) as Array).duplicate(true)


func get_sync_metadata() -> Dictionary:
	return (_document.get("sync", {}) as Dictionary).duplicate(true)


func get_namespace() -> Dictionary:
	return _namespace.duplicate(true)


func get_generation() -> int:
	return int(_document.get("generation", 0))


func commit_snapshot(
	snapshot: Dictionary,
	preferences: Dictionary,
	operation_specs: Array = []
) -> Dictionary:
	if _document.is_empty():
		return _error("No local save namespace is open.")

	var next_document := _document.duplicate(true)
	next_document["generation"] = int(_document.get("generation", 0)) + 1
	next_document["updated_at"] = LocalSaveCodecScript.iso_timestamp()
	next_document["snapshot"] = snapshot.duplicate(true)
	next_document["preferences"] = preferences.duplicate(true)

	var journal := next_document.get("journal", []) as Array
	var sync := next_document.get("sync", {}) as Dictionary
	var created_operations := []
	for raw_spec in operation_specs:
		if not (raw_spec is Dictionary):
			return _error("Save operation specification is invalid.")
		var create_result := _create_operation(raw_spec as Dictionary, sync)
		if not bool(create_result.get("ok", false)):
			return create_result
		var operation := create_result.get("operation", {}) as Dictionary
		journal.append(operation)
		created_operations.append(operation)
		sync["journal_head_sequence"] = operation["device_sequence"]
		sync["journal_head_hash"] = operation["operation_hash"]

	next_document["journal"] = journal
	next_document["sync"] = sync
	var write_result := _write_generation(next_document)
	if not bool(write_result.get("ok", false)):
		return write_result
	_document = next_document
	return _success({"operations": created_operations})


func persist_sync_metadata(sync_metadata: Dictionary) -> Dictionary:
	var next_document := _document.duplicate(true)
	next_document["generation"] = int(_document.get("generation", 0)) + 1
	next_document["updated_at"] = LocalSaveCodecScript.iso_timestamp()
	next_document["sync"] = sync_metadata.duplicate(true)
	var write_result := _write_generation(next_document)
	if not bool(write_result.get("ok", false)):
		return write_result
	_document = next_document
	return _success()


func apply_reconciliation(
	snapshot: Dictionary,
	acknowledged_cursor: Dictionary,
	checkpoint: Dictionary,
	adjustments: Array
) -> Dictionary:
	var sync := get_sync_metadata()
	if str(acknowledged_cursor.get("device_id", "")) != str(sync.get("device_id", "")):
		return _error("The checkpoint cursor belongs to another device.")
	var acknowledged_sequence := int(acknowledged_cursor.get("acknowledged_sequence", -1))
	if (
		acknowledged_sequence < int((sync.get("cursor", {}) as Dictionary).get("acknowledged_sequence", 0))
		or acknowledged_sequence > int(sync.get("journal_head_sequence", 0))
	):
		return _error("The checkpoint cursor is outside the local journal.")
	if (
		acknowledged_cursor.get("acknowledged_hash")
		!= _operation_hash_at_sequence(acknowledged_sequence, sync)
	):
		return _error("The checkpoint cursor hash does not match the local journal.")
	sync["cursor"] = acknowledged_cursor.duplicate(true)
	sync["last_checkpoint"] = checkpoint.duplicate(true)
	sync["adjustments"] = adjustments.duplicate(true)
	sync["pending_request"] = {}
	sync["retry_attempt"] = 0
	sync["next_retry_unix"] = 0
	sync["terminal_error"] = {}
	var next_document := _document.duplicate(true)
	next_document["generation"] = int(_document.get("generation", 0)) + 1
	next_document["updated_at"] = LocalSaveCodecScript.iso_timestamp()
	next_document["snapshot"] = snapshot.duplicate(true)
	next_document["sync"] = sync
	var write_result := _write_generation(next_document)
	if bool(write_result.get("ok", false)):
		_document = next_document
	return write_result


func rebind_guest_to_player(player_id: String) -> Dictionary:
	if str(_namespace.get("kind", "")) != "installation_guest":
		return _error("Only an installation guest save can be rebound.")
	if not LocalSaveCodecScript.is_uuid(player_id):
		return _error("Player id is invalid.")
	var sync := get_sync_metadata()
	var rebound_player_id := str(sync.get("guest_rebound_player_id", ""))
	if not rebound_player_id.is_empty():
		if rebound_player_id != player_id:
			return _error("This installation guest save was already rebound to another player.")
		var original_namespace := _namespace.duplicate(true)
		var original_directory := _directory
		_namespace = {"kind": "player", "player_id": player_id}
		_directory = "%s/%s" % [SAVE_ROOT, LocalSaveCodecScript.namespace_key(_namespace)]
		var existing_player := _load_newest_valid_generation()
		if bool(existing_player.get("ok", false)):
			_document = existing_player.get("document", {}) as Dictionary
			return _success({
				"snapshot": get_snapshot(),
				"preferences": get_preferences(),
				"namespace": get_namespace(),
			})
		_namespace = original_namespace
		_directory = original_directory
	else:
		sync["guest_rebound_player_id"] = player_id
		var marker_result := persist_sync_metadata(sync)
		if not bool(marker_result.get("ok", false)):
			return marker_result
		sync = get_sync_metadata()

	var player_namespace := {"kind": "player", "player_id": player_id}
	var original_namespace := _namespace.duplicate(true)
	var original_directory := _directory
	var next_document := _document.duplicate(true)
	next_document["namespace"] = player_namespace.duplicate(true)
	next_document["generation"] = int(_document.get("generation", 0)) + 1
	next_document["updated_at"] = LocalSaveCodecScript.iso_timestamp()
	sync["source_installation_guest"] = original_namespace.duplicate(true)
	next_document["sync"] = sync

	_namespace = player_namespace
	_directory = "%s/%s" % [SAVE_ROOT, LocalSaveCodecScript.namespace_key(_namespace)]
	var make_directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_directory)
	)
	if make_directory_error != OK:
		_namespace = original_namespace
		_directory = original_directory
		return _error("Could not create the rebound player namespace.")
	var result := _write_generation(next_document)
	if not bool(result.get("ok", false)):
		_namespace = original_namespace
		_directory = original_directory
		return result
	_document = next_document
	return _success({
		"snapshot": get_snapshot(),
		"preferences": get_preferences(),
		"namespace": get_namespace(),
	})


func compact_journal() -> Dictionary:
	var sync := get_sync_metadata()
	var cursor := sync.get("cursor", {}) as Dictionary
	var acknowledged_sequence := int(cursor.get("acknowledged_sequence", 0))
	var keep_after := maxi(acknowledged_sequence - RECENT_ACKNOWLEDGED_OPERATIONS, 0)
	if keep_after <= int(sync.get("journal_base_sequence", 0)):
		return _success()

	var journal := get_journal()
	var retained := []
	var base_hash = sync.get("journal_base_hash")
	for operation in journal:
		var sequence := int((operation as Dictionary).get("device_sequence", 0))
		if sequence <= keep_after:
			base_hash = (operation as Dictionary).get("operation_hash")
		else:
			retained.append(operation)

	var next_document := _document.duplicate(true)
	next_document["generation"] = int(_document.get("generation", 0)) + 1
	next_document["updated_at"] = LocalSaveCodecScript.iso_timestamp()
	next_document["journal"] = retained
	sync["journal_base_sequence"] = keep_after
	sync["journal_base_hash"] = base_hash
	next_document["sync"] = sync
	var result := _write_generation(next_document)
	if bool(result.get("ok", false)):
		_document = next_document
	return result


func _operation_hash_at_sequence(sequence: int, sync: Dictionary) -> Variant:
	if sequence == int(sync.get("journal_base_sequence", 0)):
		return sync.get("journal_base_hash")
	for operation in get_journal():
		if int((operation as Dictionary).get("device_sequence", 0)) == sequence:
			return (operation as Dictionary).get("operation_hash")
	return null


func set_test_interrupt_stage(stage: String) -> void:
	_test_interrupt_stage = stage


func validate_document(document: Dictionary) -> Dictionary:
	if str(document.get("format", "")) != LOCAL_FORMAT:
		return _error("Local save format is unsupported.")
	if int(document.get("schema_version", 0)) != LOCAL_SCHEMA_VERSION:
		return _error("Local save schema version is unsupported.")
	if not LocalSaveCodecScript.is_namespace(document.get("namespace")):
		return _error("Local save namespace is invalid.")
	if document.get("namespace") != _namespace:
		return _error("Local save namespace does not match the active account.")
	for partition in ["snapshot", "journal", "sync", "preferences", "integrity"]:
		if not document.has(partition):
			return _error("Local save partition is missing: %s." % partition)
	if not (document.get("snapshot") is Dictionary and document.get("journal") is Array):
		return _error("Local save snapshot or journal has an invalid type.")
	if not (document.get("sync") is Dictionary and document.get("preferences") is Dictionary):
		return _error("Local save sync metadata or preferences has an invalid type.")

	var integrity := document.get("integrity", {}) as Dictionary
	var unsigned := document.duplicate(true)
	unsigned.erase("integrity")
	var actual_hash := LocalSaveCodecScript.sha256_json(unsigned)
	if actual_hash.is_empty() or actual_hash != str(integrity.get("sha256", "")):
		return _error("Local save checksum failed.")

	var sync := document.get("sync", {}) as Dictionary
	if str(sync.get("device_id", "")) != _session_store.get_device_id():
		return _error("Local save device does not match this installation.")
	var expected_sequence := int(sync.get("journal_base_sequence", 0)) + 1
	var previous_hash = sync.get("journal_base_hash")
	var operation_ids := {}
	for raw_operation in document.get("journal", []) as Array:
		if not (raw_operation is Dictionary):
			return _error("Journal entry is invalid.")
		var operation := raw_operation as Dictionary
		var validation := _validate_operation(operation, expected_sequence, previous_hash)
		if not bool(validation.get("ok", false)):
			return validation
		var operation_id := str(operation.get("operation_id", ""))
		if operation_ids.has(operation_id):
			return _error("Journal contains a duplicate operation id.")
		operation_ids[operation_id] = true
		expected_sequence += 1
		previous_hash = operation.get("operation_hash")

	var head_sequence := int(sync.get("journal_head_sequence", 0))
	var head_hash = sync.get("journal_head_hash")
	if head_sequence != expected_sequence - 1 or head_hash != previous_hash:
		return _error("Journal head metadata does not match the operation chain.")
	var cursor := sync.get("cursor", {}) as Dictionary
	var cursor_sequence := int(cursor.get("acknowledged_sequence", 0))
	if (
		str(cursor.get("device_id", "")) != _session_store.get_device_id()
		or cursor_sequence < int(sync.get("journal_base_sequence", 0))
		or cursor_sequence > head_sequence
	):
		return _error("Acknowledged cursor is invalid.")
	return _success()


func _new_document(
	initial_snapshot: Dictionary,
	initial_preferences: Dictionary,
	legacy_version: int
) -> Dictionary:
	var device_id := _session_store.get_device_id()
	var migration := {
		"legacy_schema_version": legacy_version,
		"validation_restarts": 0,
		"complete": legacy_version <= 0,
	}
	return {
		"format": LOCAL_FORMAT,
		"schema_version": LOCAL_SCHEMA_VERSION,
		"namespace": _namespace.duplicate(true),
		"generation": 1,
		"created_at": LocalSaveCodecScript.iso_timestamp(),
		"updated_at": LocalSaveCodecScript.iso_timestamp(),
		"snapshot": initial_snapshot.duplicate(true),
		"journal": [],
		"sync": {
			"device_id": device_id,
			"cursor": {
				"device_id": device_id,
				"acknowledged_sequence": 0,
				"acknowledged_hash": null,
			},
			"journal_base_sequence": 0,
			"journal_base_hash": null,
			"journal_head_sequence": 0,
			"journal_head_hash": null,
			"pending_request": {},
			"retry_attempt": 0,
			"next_retry_unix": 0,
			"terminal_error": {},
			"last_checkpoint": {},
			"adjustments": [],
			"migration": migration,
		},
		"preferences": initial_preferences.duplicate(true),
	}


func _create_operation(spec: Dictionary, sync: Dictionary) -> Dictionary:
	var operation_type := str(spec.get("operation_type", ""))
	var payload = spec.get("payload")
	if not VALID_OPERATION_TYPES.has(operation_type) or not (payload is Dictionary):
		return _error("Save operation type or payload is invalid.")
	var sequence := int(sync.get("journal_head_sequence", 0)) + 1
	var operation := {
		"format": LocalSaveCodecScript.OPERATION_FORMAT,
		"operation_id": LocalSaveCodecScript.create_uuid(),
		"device_id": _session_store.get_device_id(),
		"device_sequence": sequence,
		"operation_type": operation_type,
		"occurred_at": str(spec.get("occurred_at", LocalSaveCodecScript.iso_timestamp())),
		"previous_operation_hash": sync.get("journal_head_hash"),
		"payload": (payload as Dictionary).duplicate(true),
	}
	var operation_hash := LocalSaveCodecScript.operation_hash(operation)
	if operation_hash.is_empty():
		return _error("Save operation could not be canonicalized.")
	var signature_result := _session_store.sign_operation_hash(operation_hash)
	if not bool(signature_result.get("ok", false)):
		return signature_result
	operation["operation_hash"] = operation_hash
	operation["signature"] = str(signature_result.get("signature", ""))
	if bool(signature_result.get("development_only", false)):
		operation["signature"] = str(signature_result.get("signature", ""))
	return _success({"operation": operation})


func _validate_operation(
	operation: Dictionary,
	expected_sequence: int,
	previous_hash: Variant
) -> Dictionary:
	var required_keys := [
		"format",
		"operation_id",
		"device_id",
		"device_sequence",
		"operation_type",
		"occurred_at",
		"previous_operation_hash",
		"payload",
		"operation_hash",
		"signature",
	]
	if operation.size() != required_keys.size():
		return _error("Journal operation has unknown or missing fields.")
	for key in required_keys:
		if not operation.has(key):
			return _error("Journal operation is missing %s." % key)
	if (
		str(operation.get("format", "")) != LocalSaveCodecScript.OPERATION_FORMAT
		or not LocalSaveCodecScript.is_uuid(operation.get("operation_id"))
		or str(operation.get("device_id", "")) != _session_store.get_device_id()
		or int(operation.get("device_sequence", 0)) != expected_sequence
		or not VALID_OPERATION_TYPES.has(str(operation.get("operation_type", "")))
		or not LocalSaveCodecScript.is_timestamp(operation.get("occurred_at"))
		or operation.get("previous_operation_hash") != previous_hash
		or not (operation.get("payload") is Dictionary)
	):
		return _error("Journal operation shape or chain is invalid.")
	var payload_validation := _validate_operation_payload(
		str(operation.get("operation_type", "")),
		operation.get("payload", {}) as Dictionary
	)
	if not bool(payload_validation.get("ok", false)):
		return payload_validation
	var expected_hash := LocalSaveCodecScript.operation_hash(operation)
	if expected_hash != str(operation.get("operation_hash", "")):
		return _error("Journal operation hash failed.")
	var signature := str(operation.get("signature", ""))
	if signature.length() < 92 or signature.length() > 96:
		return _error("Journal operation signature encoding is invalid.")
	return _success()


func _validate_operation_payload(operation_type: String, payload: Dictionary) -> Dictionary:
	match operation_type:
		"campaign_completion":
			if not _has_exact_keys(payload, [
				"campaign_level",
				"stars",
				"configuration_version",
				"level_version",
				"rules_version",
			]):
				return _error("Campaign completion payload fields are invalid.")
			if (
				int(payload.get("campaign_level", 0)) <= 0
				or int(payload.get("stars", -1)) < 0
				or not _has_valid_provenance(payload)
			):
				return _error("Campaign completion payload values are invalid.")
		"campaign_attempt":
			if not _has_exact_keys(payload, [
				"campaign_level",
				"outcome",
				"configuration_version",
				"level_version",
				"rules_version",
			]):
				return _error("Campaign attempt payload fields are invalid.")
			if (
				int(payload.get("campaign_level", 0)) <= 0
				or not ["failed", "left"].has(str(payload.get("outcome", "")))
				or not _has_valid_provenance(payload)
			):
				return _error("Campaign attempt payload values are invalid.")
		"resource_spend":
			if not _has_exact_keys(payload, ["asset", "amount", "reason"]):
				return _error("Resource-spend payload fields are invalid.")
			if (
				not ["coins", "hammer", "shuffle", "highlight", "freezer"].has(str(payload.get("asset", "")))
				or int(payload.get("amount", 0)) <= 0
				or not ["ability_use", "gameplay", "shop", "time_extension"].has(
					str(payload.get("reason", ""))
				)
			):
				return _error("Resource-spend payload values are invalid.")
		"life_purchase":
			if not _has_exact_keys(payload, [
				"configuration_version",
				"coin_price",
				"lives_granted",
				"available_lives",
				"maximum_lives",
				"restore_interval_seconds",
				"next_restore_at",
				"observed_at",
			]):
				return _error("Life-purchase payload fields are invalid.")
			var purchased_available := int(payload.get("available_lives", -1))
			var purchased_maximum := int(payload.get("maximum_lives", 0))
			var purchased_next_restore = payload.get("next_restore_at")
			if (
				not LocalSaveCodecScript.is_opaque_id(payload.get("configuration_version"))
				or int(payload.get("coin_price", 0)) <= 0
				or int(payload.get("lives_granted", 0)) != 1
				or purchased_available < 1
				or purchased_maximum <= 0
				or purchased_available > purchased_maximum
				or int(payload.get("restore_interval_seconds", 0)) <= 0
				or not (
					purchased_next_restore == null
					or LocalSaveCodecScript.is_timestamp(purchased_next_restore)
				)
				or not LocalSaveCodecScript.is_timestamp(payload.get("observed_at"))
			):
				return _error("Life-purchase payload values are invalid.")
		"life_state":
			if not _has_exact_keys(payload, [
				"available_lives",
				"maximum_lives",
				"restore_interval_seconds",
				"next_restore_at",
				"observed_at",
			]):
				return _error("Life-state payload fields are invalid.")
			var available := int(payload.get("available_lives", -1))
			var maximum := int(payload.get("maximum_lives", 0))
			var next_restore = payload.get("next_restore_at")
			if (
				available < 0
				or maximum <= 0
				or available > maximum
				or int(payload.get("restore_interval_seconds", 0)) <= 0
				or not (next_restore == null or LocalSaveCodecScript.is_timestamp(next_restore))
				or not LocalSaveCodecScript.is_timestamp(payload.get("observed_at"))
			):
				return _error("Life-state payload values are invalid.")
		"profile_edit":
			if payload.is_empty() or payload.size() > 3:
				return _error("Profile-edit payload fields are invalid.")
			for key in payload.keys():
				if not ["display_name", "avatar_id", "avatar_frame_id"].has(str(key)):
					return _error("Profile-edit payload contains an unknown field.")
			if payload.has("display_name"):
				var display_name := str(payload.get("display_name", ""))
				if display_name.is_empty() or display_name.length() > 24:
					return _error("Profile display name is invalid.")
			if payload.has("avatar_id") and not LocalSaveCodecScript.is_opaque_id(payload.get("avatar_id")):
				return _error("Profile avatar id is invalid.")
			if (
				payload.has("avatar_frame_id")
				and not LocalSaveCodecScript.is_opaque_id(payload.get("avatar_frame_id"))
			):
				return _error("Profile avatar frame id is invalid.")
	return _success()


func _has_valid_provenance(payload: Dictionary) -> bool:
	return (
		LocalSaveCodecScript.is_opaque_id(payload.get("configuration_version"))
		and LocalSaveCodecScript.is_opaque_id(payload.get("level_version"))
		and LocalSaveCodecScript.is_opaque_id(payload.get("rules_version"))
	)


func _has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not value.has(key):
			return false
	return true


func _write_generation(document: Dictionary) -> Dictionary:
	var persistable := document.duplicate(true)
	persistable.erase("integrity")
	persistable["integrity"] = {"sha256": LocalSaveCodecScript.sha256_json(persistable)}
	var temp_path := _path(TEMP_FILE)
	var current_path := _path(CURRENT_FILE)
	var previous_path := _path(PREVIOUS_FILE)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _error("Could not open the temporary local save.")
	file.store_string(JSON.stringify(persistable))
	file.flush()
	file = null
	if _test_interrupt_stage == "after_temp_flush":
		return _error("Simulated interruption after temporary save flush.")

	var parsed_temp := _read_document(temp_path)
	var validation := validate_document(parsed_temp)
	if not bool(validation.get("ok", false)):
		return _error("Temporary local save validation failed: %s" % validation.get("error", ""))
	if _test_interrupt_stage == "after_temp_validation":
		return _error("Simulated interruption after temporary save validation.")

	if FileAccess.file_exists(previous_path):
		var remove_previous_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(previous_path))
		if remove_previous_error != OK:
			return _error("Could not rotate the previous local save.")
	if FileAccess.file_exists(current_path):
		var rotate_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(current_path),
			ProjectSettings.globalize_path(previous_path)
		)
		if rotate_error != OK:
			return _error("Could not preserve the previous local save.")
	if _test_interrupt_stage == "after_previous_rotation":
		return _error("Simulated interruption after previous-save rotation.")

	var promote_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(current_path)
	)
	if promote_error != OK:
		return _error("Could not promote the new local save generation.")
	if _test_interrupt_stage == "after_current_promotion":
		return _error("Simulated interruption after local-save promotion.")
	return _success()


func _load_newest_valid_generation() -> Dictionary:
	var candidates := []
	for file_name in [CURRENT_FILE, PREVIOUS_FILE, TEMP_FILE]:
		var path := _path(file_name)
		if not FileAccess.file_exists(path):
			continue
		var candidate := _read_document(path)
		if candidate.is_empty():
			continue
		if bool(validate_document(candidate).get("ok", false)):
			candidates.append({"source": file_name, "document": candidate})
	if candidates.is_empty():
		return _error("No valid local save generation exists.")
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_generation := int((left.get("document", {}) as Dictionary).get("generation", 0))
		var right_generation := int((right.get("document", {}) as Dictionary).get("generation", 0))
		if left_generation == right_generation:
			return str(left.get("source", "")) == CURRENT_FILE
		return left_generation > right_generation
	)
	return _success(candidates[0])


func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _mark_successful_restart() -> void:
	var sync := get_sync_metadata()
	var migration := sync.get("migration", {}) as Dictionary
	if bool(migration.get("complete", true)):
		return
	migration["validation_restarts"] = int(migration.get("validation_restarts", 0)) + 1
	migration["complete"] = int(migration.get("validation_restarts", 0)) >= 1
	sync["migration"] = migration
	persist_sync_metadata(sync)


func _copy_legacy_save(source_path: String) -> void:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return
	var target_path := _path(LEGACY_COPY_FILE)
	if FileAccess.file_exists(target_path):
		return
	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		return
	target.store_buffer(source.get_buffer(source.get_length()))
	target.flush()


func _path(file_name: String) -> String:
	return "%s/%s" % [_directory, file_name]


func _success(data: Dictionary = {}) -> Dictionary:
	var result := {"ok": true, "error": ""}
	result.merge(data, true)
	return result


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
