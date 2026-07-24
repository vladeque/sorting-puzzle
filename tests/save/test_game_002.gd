extends SceneTree

const Codec := preload("res://scripts/save/local_save_codec.gd")
const GuestBootstrapService := preload("res://scripts/save/guest_session_bootstrap_service.gd")
const LocalSaveStoreScript := preload("res://scripts/save/local_save_store.gd")
const SaveSyncService := preload("res://scripts/save/save_sync_service.gd")
const SecureSessionStoreScript := preload("res://scripts/save/secure_session_store.gd")
const ContentProvenanceManifestScript := preload(
	"res://scripts/save/content_provenance_manifest.gd"
)

var _failures := PackedStringArray()


func _init() -> void:
	var manifest = ContentProvenanceManifestScript.new()
	var result: Dictionary = manifest.load_manifest()
	_check(bool(result.get("ok", false)), "generated manifest loads with source verification")
	_check(manifest.is_valid(), "generated manifest is integration-ready")
	_check(
		str(result.get("digest_sha256", "")).length() == 64,
		"generated manifest exposes its non-secret digest"
	)

	for campaign_level in range(1, 9):
		var provenance: Dictionary = manifest.get_level_provenance(campaign_level)
		_check(provenance.size() == 3, "level %d has one exact provenance mapping" % campaign_level)
		_check(
			Codec.is_opaque_id(provenance.get("configuration_version")),
			"level %d configuration version is opaque" % campaign_level
		)
		_check(
			Codec.is_opaque_id(provenance.get("level_version")),
			"level %d level version is opaque" % campaign_level
		)
		_check(
			Codec.is_opaque_id(provenance.get("rules_version")),
			"level %d rules version is opaque" % campaign_level
		)
	_check(manifest.get_level_provenance(9).is_empty(), "level 9 is not integration-ready")
	_check(manifest.get_level_provenance(10).is_empty(), "level 10 is not integration-ready")

	var source_document := _read_manifest()
	var digest_mismatch := source_document.duplicate(true)
	digest_mismatch["digest_sha256"] = "0".repeat(64)
	var invalid = ContentProvenanceManifestScript.new()
	var invalid_result: Dictionary = invalid.load_document(digest_mismatch)
	_check(not bool(invalid_result.get("ok", false)), "digest mismatch is rejected")
	_check(
		str(invalid_result.get("code", "")) == "content_manifest.digest_mismatch",
		"digest mismatch has a stable non-secret diagnostic"
	)

	var incomplete := source_document.duplicate(true)
	(incomplete.get("levels", []) as Array).pop_back()
	var incomplete_hashable := incomplete.duplicate(true)
	incomplete_hashable.erase("digest_sha256")
	incomplete["digest_sha256"] = Codec.sha256_json(incomplete_hashable)
	var incomplete_manifest = ContentProvenanceManifestScript.new()
	var incomplete_result: Dictionary = incomplete_manifest.load_document(incomplete)
	_check(not bool(incomplete_result.get("ok", false)), "incomplete mapping is rejected")
	_check(
		str(incomplete_result.get("code", "")) == "content_manifest.incomplete",
		"incomplete mapping has a stable non-secret diagnostic"
	)

	var stale := source_document.duplicate(true)
	var stale_files := ((stale.get("source", {}) as Dictionary).get("files", []) as Array)
	(stale_files[0] as Dictionary)["sha256"] = "0".repeat(64)
	var stale_hashable := stale.duplicate(true)
	stale_hashable.erase("digest_sha256")
	stale["digest_sha256"] = Codec.sha256_json(stale_hashable)
	var stale_manifest = ContentProvenanceManifestScript.new()
	var stale_result: Dictionary = stale_manifest.load_document(stale, true)
	_check(not bool(stale_result.get("ok", false)), "stale source mapping is rejected")
	_check(
		str(stale_result.get("code", "")) == "content_manifest.source_stale",
		"stale source mapping has a stable non-secret diagnostic"
	)
	_test_invalid_provenance_network_gates()

	if _failures.is_empty():
		print("GAME-002 content provenance tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _read_manifest() -> Dictionary:
	var file := FileAccess.open(
		ContentProvenanceManifestScript.DEFAULT_PATH,
		FileAccess.READ
	)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _test_invalid_provenance_network_gates() -> void:
	var store = LocalSaveStoreScript.new()
	var session_store = SecureSessionStoreScript.new()
	var sync_service = SaveSyncService.new()
	sync_service.configure(store, session_store, Callable(), false)
	_check(
		not bool(sync_service.call("_can_sync")),
		"invalid content provenance disables save synchronization"
	)
	sync_service.free()

	var guest_service = GuestBootstrapService.new()
	guest_service.configure(store, session_store, RefCounted.new(), false)
	_check(
		not bool(guest_service.call("_can_register")),
		"invalid content provenance disables guest registration"
	)
	guest_service.free()


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
