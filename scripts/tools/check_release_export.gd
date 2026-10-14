extends SceneTree

## Pre-export check for the "Android (Release)" preset. Run it before every release export:
##
##   & .\scripts\tools\run_isolated_godot_test.ps1 -Script scripts/tools/check_release_export.gd
##
## Exits 0 only when every rule in scripts/tools/release_export_check.gd passes.

const ReleaseExportCheckScript := preload("res://scripts/tools/release_export_check.gd")
const BackendEnvironmentScript := preload("res://scripts/backend/backend_environment.gd")
const ContentProvenanceManifestScript := preload("res://scripts/save/content_provenance_manifest.gd")
const StoreServiceScript := preload("res://scripts/store/store_service.gd")
const PRESETS_PATH := "res://export_presets.cfg"
const PRESET_NAME := "Android (Release)"
const SECURE_STORE_PLUGIN := "res://addons/sorting_puzzle_secure_store_bridge/plugin.cfg"
const SECURE_STORE_RELEASE_AAR := (
	"res://platform/android/secure-store-plugin/plugin/build/outputs/aar/"
	+ "SortingPuzzleSecureStoreBridge-release.aar"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presets := ConfigFile.new()
	if presets.load(PRESETS_PATH) != OK:
		_finish([{"name": "export presets", "ok": false, "detail": "could not read %s" % PRESETS_PATH}])
		return
	var section := ""
	for candidate in presets.get_sections():
		if not candidate.ends_with(".options") and str(presets.get_value(candidate, "name", "")) == PRESET_NAME:
			section = candidate
	if section.is_empty():
		_finish([{"name": "release preset", "ok": false, "detail": "no \"%s\" preset" % PRESET_NAME}])
		return

	var preset := {}
	for key in presets.get_section_keys(section):
		preset[key] = presets.get_value(section, key)
	var options := {}
	if presets.has_section(section + ".options"):
		for key in presets.get_section_keys(section + ".options"):
			options[key] = presets.get_value(section + ".options", key)

	var environments := BackendEnvironmentScript.load_config()
	var production := (environments.get("environments", {}) as Dictionary).get("production", {}) as Dictionary
	var manifest = ContentProvenanceManifestScript.new()
	var loaded: Dictionary = manifest.load_manifest_with_source_verification(
		str(production.get("content_provenance_path", ""))
	)
	var provenance := {
		"ok": bool(loaded.get("ok", false)),
		"environment": manifest.get_environment(),
		"error": str(loaded.get("error", "")),
	}

	var enabled_plugins := PackedStringArray(ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray()))
	var results: Array = ReleaseExportCheckScript.validate({
		"preset": preset,
		"options": options,
		"environments": environments,
		"project": {
			"version": ProjectSettings.get_setting("application/config/version", ""),
			"build_number": ProjectSettings.get_setting("application/config/build_number", 0),
			"support_email": ProjectSettings.get_setting("application/config/support_email", ""),
		},
		"provenance": provenance,
		"store_guard": StoreServiceScript.new().get("_real_money_enabled") != null,
		"secure_store": {
			"plugin_enabled": enabled_plugins.has(SECURE_STORE_PLUGIN),
			"release_aar_present": FileAccess.file_exists(SECURE_STORE_RELEASE_AAR),
		},
	})
	_finish(results)


func _finish(results: Array) -> void:
	var failed := 0
	for result in results:
		var entry := result as Dictionary
		if bool(entry.get("ok", false)):
			print("  ok  - %s" % entry.get("name", ""))
		else:
			failed += 1
			print("FAIL  - %s: %s" % [entry.get("name", ""), entry.get("detail", "")])
	if failed == 0:
		print("Release export check passed.")
		quit(0)
		return
	print("Release export check failed: %d rule(s)." % failed)
	quit(1)
