extends SceneTree

## GAME-003 coverage for the local-only backend debug override parser. Only the pure
## `parse_override()` validator is exercised here; `_ready()`'s OS.is_debug_build() gate, the
## ProjectSettings override, and the network health probe are exercised on-device (see
## platform/android/secure-store-plugin/README.md and scripts/tools/android_local_backend_smoke_check.ps1).

const BootstrapScript := preload("res://scripts/save/local_backend_debug_bootstrap.gd")
const TEMP_PATH := "user://test_local_backend_debug_override.cfg"

var _failures := PackedStringArray()


func _init() -> void:
	var bootstrap_script: Script = BootstrapScript
	if not bootstrap_script.can_instantiate():
		push_error("Local backend debug bootstrap script could not be instantiated.")
		quit(1)
		return

	_check_valid_override()
	_check_missing_base_url()
	_check_empty_base_url()
	_check_invalid_scheme()
	_check_non_bool_sync_enabled()
	_check_sync_disabled_is_accepted()

	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))

	if _failures.is_empty():
		print("Local backend debug bootstrap tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _config_from(text: String) -> ConfigFile:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.flush()
	file = null
	var config := ConfigFile.new()
	config.load(TEMP_PATH)
	return config


func _check_valid_override() -> void:
	var config := _config_from(
		"[backend]\nbase_url=\"http://127.0.0.1:8080\"\nsync_enabled=true\n"
	)
	var result := BootstrapScript.parse_override(config)
	_check(bool(result.get("ok", false)), "valid override parses")
	_check(str(result.get("base_url", "")) == "http://127.0.0.1:8080", "valid override keeps base_url")
	_check(bool(result.get("sync_enabled", false)) == true, "valid override keeps sync_enabled true")


func _check_missing_base_url() -> void:
	var config := _config_from("[backend]\nsync_enabled=true\n")
	var result := BootstrapScript.parse_override(config)
	_check(not bool(result.get("ok", true)), "missing base_url is rejected")


func _check_empty_base_url() -> void:
	var config := _config_from("[backend]\nbase_url=\"\"\nsync_enabled=false\n")
	var result := BootstrapScript.parse_override(config)
	_check(not bool(result.get("ok", true)), "empty base_url is rejected")


func _check_invalid_scheme() -> void:
	var config := _config_from("[backend]\nbase_url=\"127.0.0.1:8080\"\nsync_enabled=false\n")
	var result := BootstrapScript.parse_override(config)
	_check(not bool(result.get("ok", true)), "base_url without http:// or https:// is rejected")


func _check_non_bool_sync_enabled() -> void:
	var config := _config_from(
		"[backend]\nbase_url=\"http://127.0.0.1:8080\"\nsync_enabled=\"true\"\n"
	)
	var result := BootstrapScript.parse_override(config)
	_check(not bool(result.get("ok", true)), "non-boolean sync_enabled is rejected")


func _check_sync_disabled_is_accepted() -> void:
	var config := _config_from(
		"[backend]\nbase_url=\"http://10.0.2.2:8080\"\nsync_enabled=false\n"
	)
	var result := BootstrapScript.parse_override(config)
	_check(bool(result.get("ok", false)), "sync_enabled=false with the 10.0.2.2 fallback parses")
	_check(bool(result.get("sync_enabled", true)) == false, "sync_enabled false is preserved")


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
