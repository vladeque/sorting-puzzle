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
const IDENTITY_DIAGNOSTICS_POLL_INTERVAL_SECONDS := 3.0


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
	_start_identity_diagnostics_timer()


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


## GAME-004: periodically surfaces PlayerProgress's non-secret identity/save-sync diagnostics
## (namespace kind, opaque player/device ids, generation, retry state, error codes, correlation
## id) via logcat so an emulator smoke check can prove real guest bootstrap, one-time rebind, and
## restart resumption without reading any secret storage on the device.
func _start_identity_diagnostics_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = IDENTITY_DIAGNOSTICS_POLL_INTERVAL_SECONDS
	timer.one_shot = false
	timer.timeout.connect(_log_identity_diagnostics)
	add_child(timer)
	timer.start()


func _log_identity_diagnostics() -> void:
	var progress := get_node_or_null("/root/PlayerProgress")
	if progress == null or not progress.has_method("get_local_save_diagnostics"):
		return
	var diagnostics: Dictionary = progress.get_local_save_diagnostics()
	if diagnostics.is_empty():
		return
	var save_namespace := diagnostics.get("namespace", {}) as Dictionary
	var registration := diagnostics.get("guest_registration", {}) as Dictionary
	var registration_terminal := registration.get("terminal_error", {}) as Dictionary
	var terminal_error := diagnostics.get("terminal_error", {}) as Dictionary
	var sync_gate := diagnostics.get("sync_gate", {}) as Dictionary
	print(
		(
			"%s identity diagnostics: namespace_kind=%s player_id=%s device_id=%s generation=%d "
			+ "guest_phase=%s guest_retry_attempt=%d guest_terminal_error=%s "
			+ "retry_attempt=%d terminal_error=%s last_correlation_id=%s "
			+ "gate_feature=%s gate_url=%s gate_can_sync=%s gate_key=%s gate_manifest=%s"
		) % [
			LOG_TAG,
			str(save_namespace.get("kind", "")),
			str(save_namespace.get("player_id", "")),
			str(diagnostics.get("device_id", "")),
			int(diagnostics.get("generation", 0)),
			str(registration.get("phase", "")),
			int(registration.get("retry_attempt", 0)),
			str(registration_terminal.get("code", "")),
			int(diagnostics.get("retry_attempt", 0)),
			str(terminal_error.get("code", "")),
			str(diagnostics.get("last_correlation_id", "")),
			bool(sync_gate.get("feature_enabled", false)),
			bool(sync_gate.get("backend_url_configured", false)),
			bool(sync_gate.get("can_synchronize", false)),
			bool(sync_gate.get("installation_public_key_present", false)),
			bool(sync_gate.get("content_manifest_valid", false)),
		]
	)
