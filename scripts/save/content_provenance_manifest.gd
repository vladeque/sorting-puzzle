extends RefCounted
class_name ContentProvenanceManifest

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")
const DEFAULT_PATH := "res://configs/backend/content_provenance.json"
const EXPECTED_SCHEMA_VERSION := "1.0.0"
const EXPECTED_SUPPORTED_LEVELS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const EXPECTED_EXCLUDED_LEVELS := []

var _valid := false
var _manifest_digest := ""
var _environment := ""
var _levels := {}
var _diagnostic := {}


## Runtime validation is export-stable: it verifies the packaged manifest's closed schema,
## self-digest, publication identity, and complete level mapping, but does not re-hash authored
## `.gd`/`.tscn` inputs because export templates compile/remap those files.
##
## Pre-export tooling must call `load_manifest_with_source_verification()` while the authored
## source tree is available. That remains the fail-closed gate for stale source/publication
## mappings.
func load_manifest(path: String = DEFAULT_PATH) -> Dictionary:
	return _load_manifest(path, false)


func load_manifest_with_source_verification(path: String = DEFAULT_PATH) -> Dictionary:
	return _load_manifest(path, true)


func _load_manifest(path: String, verify_source_files: bool) -> Dictionary:
	_reset()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("content_manifest.missing", "Bundled content provenance is unavailable.")
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _fail("content_manifest.parse_invalid", "Bundled content provenance is not valid JSON.")
	return load_document(parsed as Dictionary, verify_source_files)


func load_document(document: Dictionary, verify_source_files: bool = false) -> Dictionary:
	_reset()
	var structural_error := _validate_structure(document)
	if not structural_error.is_empty():
		return _fail("content_manifest.schema_invalid", structural_error)

	var digest := str(document.get("digest_sha256", ""))
	var hashable := document.duplicate(true)
	hashable.erase("digest_sha256")
	if LocalSaveCodecScript.sha256_json(hashable) != digest:
		return _fail("content_manifest.digest_mismatch", "Bundled content provenance digest differs.")

	var publication := document.get("publication", {}) as Dictionary
	var configuration_version := str(publication.get("configuration_version", ""))
	if configuration_version != "config_%s" % str(publication.get("digest_sha256", "")):
		return _fail(
			"content_manifest.provenance_invalid",
			"Bundled configuration identity does not match its immutable digest."
		)

	var supported := _integer_array(document.get("supported_campaign_levels", []))
	var excluded := _integer_array(document.get("excluded_campaign_levels", []))
	if supported != EXPECTED_SUPPORTED_LEVELS or excluded != EXPECTED_EXCLUDED_LEVELS:
		return _fail(
			"content_manifest.incomplete",
			"Bundled content provenance must support all Chapter 1 levels 1-10."
		)

	var mappings := {}
	for raw_level in document.get("levels", []) as Array:
		var level := raw_level as Dictionary
		var campaign_level := int(level.get("campaign_level", 0))
		if mappings.has(campaign_level):
			return _fail(
				"content_manifest.incomplete",
				"Bundled content provenance contains a duplicate campaign level."
			)
		if (
			not supported.has(campaign_level)
			or str(level.get("configuration_version", "")) != configuration_version
			or not LocalSaveCodecScript.is_opaque_id(level.get("level_version"))
			or not LocalSaveCodecScript.is_opaque_id(level.get("rules_version"))
		):
			return _fail(
				"content_manifest.provenance_invalid",
				"Bundled campaign provenance does not belong to one immutable publication."
			)
		mappings[campaign_level] = {
			"configuration_version": configuration_version,
			"level_version": str(level.get("level_version", "")),
			"rules_version": str(level.get("rules_version", "")),
		}
	if mappings.size() != supported.size():
		return _fail(
			"content_manifest.incomplete",
			"Bundled content provenance is missing a supported campaign level."
		)

	if verify_source_files:
		var source_result := _verify_source_files(document.get("source", {}) as Dictionary)
		if not bool(source_result.get("ok", false)):
			return source_result

	_valid = true
	_manifest_digest = digest
	_environment = str(document.get("environment", ""))
	_levels = mappings
	_diagnostic.clear()
	return {
		"ok": true,
		"digest_sha256": _manifest_digest,
		"environment": _environment,
		"supported_campaign_levels": supported,
	}


func is_valid() -> bool:
	return _valid


func get_level_provenance(campaign_level: int) -> Dictionary:
	if not _valid or not _levels.has(campaign_level):
		return {}
	return (_levels.get(campaign_level, {}) as Dictionary).duplicate(true)


func get_manifest_digest() -> String:
	return _manifest_digest


func get_environment() -> String:
	return _environment


func get_diagnostic() -> Dictionary:
	return _diagnostic.duplicate(true)


func _validate_structure(document: Dictionary) -> String:
	if not _has_exact_keys(document, [
		"digest_sha256",
		"environment",
		"excluded_campaign_levels",
		"levels",
		"publication",
		"schema_version",
		"source",
		"supported_campaign_levels",
	]):
		return "Bundled content provenance has unexpected or missing fields."
	if (
		str(document.get("schema_version", "")) != EXPECTED_SCHEMA_VERSION
		or str(document.get("environment", "")) not in ["development", "production", "test"]
		or not LocalSaveCodecScript.is_hash(document.get("digest_sha256"))
		or not (document.get("supported_campaign_levels") is Array)
		or not (document.get("excluded_campaign_levels") is Array)
		or not (document.get("levels") is Array)
		or not (document.get("publication") is Dictionary)
		or not (document.get("source") is Dictionary)
	):
		return "Bundled content provenance fields have invalid types or values."

	var publication := document.get("publication", {}) as Dictionary
	if (
		not _has_exact_keys(publication, [
			"configuration_version",
			"digest_sha256",
			"source_candidate_sha256",
		])
		or not LocalSaveCodecScript.is_opaque_id(publication.get("configuration_version"))
		or not LocalSaveCodecScript.is_hash(publication.get("digest_sha256"))
		or not LocalSaveCodecScript.is_hash(publication.get("source_candidate_sha256"))
	):
		return "Bundled publication identity is invalid."

	var source := document.get("source", {}) as Dictionary
	if (
		not _has_exact_keys(source, ["commit", "files", "repository"])
		or str(source.get("repository", "")) != "sorting-puzzle"
		or not _is_git_commit(source.get("commit"))
		or not (source.get("files") is Array)
		or (source.get("files", []) as Array).is_empty()
	):
		return "Bundled publication source descriptor is invalid."
	for raw_file in source.get("files", []) as Array:
		if not (raw_file is Dictionary):
			return "Bundled publication source file is invalid."
		var source_file := raw_file as Dictionary
		var relative_path := str(source_file.get("path", ""))
		if (
			not _has_exact_keys(source_file, ["path", "sha256"])
			or relative_path.is_empty()
			or relative_path.begins_with("/")
			or relative_path.begins_with("\\")
			or relative_path.contains("..")
			or not LocalSaveCodecScript.is_hash(source_file.get("sha256"))
		):
			return "Bundled publication source file is invalid."

	for raw_level in document.get("levels", []) as Array:
		if (
			not (raw_level is Dictionary)
			or not _has_exact_keys(raw_level as Dictionary, [
				"campaign_level",
				"configuration_version",
				"level_version",
				"rules_version",
			])
			or not _is_integer((raw_level as Dictionary).get("campaign_level"))
		):
			return "Bundled campaign provenance entry is invalid."
	return ""


func _verify_source_files(source: Dictionary) -> Dictionary:
	for raw_file in source.get("files", []) as Array:
		var source_file := raw_file as Dictionary
		var resource_path := "res://%s" % str(source_file.get("path", ""))
		if (
			not FileAccess.file_exists(resource_path)
			or FileAccess.get_sha256(resource_path) != str(source_file.get("sha256", ""))
		):
			return _fail(
				"content_manifest.source_stale",
				"Bundled content provenance does not match the packaged campaign sources."
			)
	return {"ok": true}


func _integer_array(value: Variant) -> Array:
	if not (value is Array):
		return []
	var result := []
	for entry in value as Array:
		if not _is_integer(entry):
			return []
		result.append(int(entry))
	return result


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	var actual := PackedStringArray()
	for key in value.keys():
		actual.append(str(key))
	actual.sort()
	var expected_keys := PackedStringArray()
	for key in expected:
		expected_keys.append(str(key))
	expected_keys.sort()
	return actual == expected_keys


func _is_git_commit(value: Variant) -> bool:
	var text := str(value)
	if text.length() != 40:
		return false
	for character in text:
		if character not in "0123456789abcdef":
			return false
	return true


func _is_integer(value: Variant) -> bool:
	return (
		value is int
		or (value is float and is_finite(float(value)) and float(value) == floor(float(value)))
	)


func _fail(code: String, message: String) -> Dictionary:
	_valid = false
	_manifest_digest = ""
	_environment = ""
	_levels.clear()
	_diagnostic = {"code": code, "message": message}
	return {"ok": false, "code": code, "error": message}


func _reset() -> void:
	_valid = false
	_manifest_digest = ""
	_environment = ""
	_levels.clear()
	_diagnostic.clear()
