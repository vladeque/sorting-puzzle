extends Node

## GAME-003: local-only configuration path for the Android local-backend debug target.
##
## Registered as the first autoload in `project.godot`, ahead of `PlayerProgress`, so any override
## is applied before `SaveSyncService` reads `application/config/backend_base_url` or
## `application/config/save_sync_v2_enabled`.
##
## Reads the gitignored `res://local/backend_debug.cfg` (see `local/backend_debug.example.cfg` for
## the template) and, only in debug builds, overrides the committed empty/disabled project
## defaults for this run. A missing file, a non-debug export, or an invalid override all leave the
## committed release defaults untouched. On success it logs a single non-secret diagnostic line
## and fires a best-effort `/health/live` probe so `adb logcat` can confirm the emulator reaches
## the developer-hosted backend without ever printing tokens, signatures, or private key material.

const OVERRIDE_PATH := "res://local/backend_debug.cfg"
const BASE_URL_SETTING := "application/config/backend_base_url"
const SYNC_ENABLED_SETTING := "application/config/save_sync_v2_enabled"
const SECURE_BRIDGE_SINGLETON := "SortingPuzzleSecureStoreBridge"
const LOG_TAG := "[LocalBackendDebug]"
const HEALTH_PROBE_TIMEOUT_SECONDS := 5.0


func _ready() -> void:
	if not OS.is_debug_build():
		return
	if not FileAccess.file_exists(OVERRIDE_PATH):
		return

	var config := ConfigFile.new()
	if config.load(OVERRIDE_PATH) != OK:
		push_warning("%s Could not parse %s; committed defaults stay active." % [LOG_TAG, OVERRIDE_PATH])
		return

	var parsed := parse_override(config)
	if not bool(parsed.get("ok", false)):
		push_warning("%s %s Committed defaults stay active." % [LOG_TAG, str(parsed.get("error", ""))])
		return

	var base_url := str(parsed.get("base_url", ""))
	var sync_enabled := bool(parsed.get("sync_enabled", false))
	ProjectSettings.set_setting(BASE_URL_SETTING, base_url)
	ProjectSettings.set_setting(SYNC_ENABLED_SETTING, sync_enabled)
	print(
		"%s local override active: base_url=%s sync_enabled=%s (source: %s, never committed)"
		% [LOG_TAG, base_url, sync_enabled, OVERRIDE_PATH]
	)
	_run_health_probe(base_url)


## Pure validation of one [backend] section. Kept separate from _ready() so it can be unit tested
## (see tests/save/test_local_backend_debug_bootstrap.gd) without touching ProjectSettings, the
## filesystem, or the network.
static func parse_override(config: ConfigFile) -> Dictionary:
	if not config.has_section_key("backend", "base_url"):
		return {"ok": false, "error": "local/backend_debug.cfg is missing [backend] base_url."}
	var base_url := str(config.get_value("backend", "base_url", "")).strip_edges()
	if base_url.is_empty():
		return {"ok": false, "error": "local/backend_debug.cfg base_url is empty."}
	if not (base_url.begins_with("http://") or base_url.begins_with("https://")):
		return {
			"ok": false,
			"error": "local/backend_debug.cfg base_url must start with http:// or https://.",
		}

	var sync_enabled_value = config.get_value("backend", "sync_enabled", false)
	if not (sync_enabled_value is bool):
		return {"ok": false, "error": "local/backend_debug.cfg sync_enabled must be true or false."}

	return {"ok": true, "base_url": base_url, "sync_enabled": sync_enabled_value}


func _run_health_probe(base_url: String) -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = HEALTH_PROBE_TIMEOUT_SECONDS
	request.request_completed.connect(_on_health_probe_completed.bind(request))
	var health_url := "%s/health/live" % base_url.trim_suffix("/")
	var start_error := request.request(health_url)
	if start_error != OK:
		print(
			"%s health probe failed to start (error %d) for %s"
			% [LOG_TAG, start_error, health_url]
		)
		request.queue_free()


func _on_health_probe_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray,
	request: HTTPRequest
) -> void:
	print(
		"%s health probe result=%d response_code=%d secure_bridge_available=%s"
		% [
			LOG_TAG,
			result,
			response_code,
			Engine.has_singleton(SECURE_BRIDGE_SINGLETON),
		]
	)
	request.queue_free()
