extends Node

## DEV-CODE-004: selects an exported build's backend environment from the closed
## `configs/backend/environments.json`.
##
## Registered as the first autoload, ahead of `LocalBackendDebugBootstrap` and `PlayerProgress`, so
## the selection is applied before anything reads the backend settings. An export preset selects an
## environment with exactly one `backend_<name>` custom feature tag (the release preset uses
## `backend_production`). With no tag, as in the editor, tests, and the local-backend debug preset,
## the committed project defaults stay active: no backend URL, sync off, local catalog, and mock
## leaderboards. Two tags, an unknown name, or an invalid entry select nothing, so local,
## development, and production values can never be combined. The file holds no secrets.

const CONFIG_PATH := "res://configs/backend/environments.json"
const CONFIG_SCHEMA := "sorting-puzzle-backend-environments/1"
const FEATURE_PREFIX := "backend_"
const ENVIRONMENT_SETTING := "application/config/backend_environment"
const PROVENANCE_PATH_SETTING := "application/config/content_provenance_path"
const DEFAULT_PROVENANCE_PATH := "res://configs/backend/content_provenance.json"
const ENVIRONMENT_NAMES := ["development", "production"]
const SHOP_CATALOG_SOURCES := ["local", "backend"]
const LEADERBOARD_PROVIDERS := ["mock", "backend"]
const STORE_PROVIDERS := ["mock"]
const LOCAL_HOSTS := ["localhost", "127.0.0.1", "10.0.2.2", "[::1]"]


func _ready() -> void:
	var features := []
	for environment_name in ENVIRONMENT_NAMES:
		if OS.has_feature(FEATURE_PREFIX + environment_name):
			features.append(FEATURE_PREFIX + environment_name)
	if features.is_empty():
		return
	var selection := resolve(features, load_config())
	if not bool(selection.get("ok", false)):
		push_error("Backend environment not applied: %s" % str(selection.get("error", "")))
		return
	apply(selection)


## Reads the committed configuration; an unreadable file resolves to an empty document, which
## `resolve()` then rejects.
static func load_config(path: String = CONFIG_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


## Pure selection and validation, kept free of ProjectSettings and the filesystem for tests.
## `features` holds the build's `backend_<name>` tags. Returns {ok, environment, settings} or
## {ok: false, error}.
static func resolve(features: Array, config: Dictionary) -> Dictionary:
	if features.size() != 1:
		return {"ok": false, "error": "exactly one backend_<environment> feature tag must select the environment"}
	var tag := str(features[0])
	var environment_name := tag.trim_prefix(FEATURE_PREFIX)
	if not tag.begins_with(FEATURE_PREFIX) or not ENVIRONMENT_NAMES.has(environment_name):
		return {"ok": false, "error": "%s is not a known backend environment tag" % tag}
	if str(config.get("schema", "")) != CONFIG_SCHEMA:
		return {"ok": false, "error": "%s must declare schema %s" % [CONFIG_PATH, CONFIG_SCHEMA]}
	var environments = config.get("environments")
	if not (environments is Dictionary) or not ((environments as Dictionary).get(environment_name) is Dictionary):
		return {"ok": false, "error": "%s has no %s environment" % [CONFIG_PATH, environment_name]}
	var entry := (environments as Dictionary).get(environment_name) as Dictionary
	var entry_error := validate_entry(entry)
	if not entry_error.is_empty():
		return {"ok": false, "error": "%s %s: %s" % [CONFIG_PATH, environment_name, entry_error]}
	return {"ok": true, "environment": environment_name, "settings": entry.duplicate(true)}


static func validate_entry(entry: Dictionary) -> String:
	var origin := str(entry.get("api_origin", ""))
	if not origin.begins_with("https://") or origin.length() <= "https://".length():
		return "api_origin must be an https:// origin"
	var host := origin.trim_prefix("https://")
	if host.contains("/") or host.contains("?") or host.contains("#"):
		return "api_origin must be an origin without a path"
	if LOCAL_HOSTS.has(host.get_slice(":", 0)) or host.begins_with("["):
		return "api_origin must not point at a local development host"
	if not str(entry.get("android_package", "")).contains("."):
		return "android_package must be a reverse-DNS package name"
	if not (entry.get("save_sync_v2_enabled") is bool):
		return "save_sync_v2_enabled must be true or false"
	if not SHOP_CATALOG_SOURCES.has(str(entry.get("shop_catalog_source", ""))):
		return "shop_catalog_source must be one of %s" % [SHOP_CATALOG_SOURCES]
	if not LEADERBOARD_PROVIDERS.has(str(entry.get("leaderboard_provider", ""))):
		return "leaderboard_provider must be one of %s" % [LEADERBOARD_PROVIDERS]
	if not STORE_PROVIDERS.has(str(entry.get("store_provider", ""))):
		return "store_provider must be one of %s" % [STORE_PROVIDERS]
	if not str(entry.get("content_provenance_path", "")).begins_with("res://configs/backend/"):
		return "content_provenance_path must be a res://configs/backend/ file"
	return ""


static func apply(selection: Dictionary) -> void:
	var settings := selection.get("settings", {}) as Dictionary
	ProjectSettings.set_setting(ENVIRONMENT_SETTING, str(selection.get("environment", "")))
	ProjectSettings.set_setting("application/config/backend_base_url", str(settings.get("api_origin", "")))
	ProjectSettings.set_setting(
		"application/config/save_sync_v2_enabled",
		bool(settings.get("save_sync_v2_enabled", false))
	)
	ProjectSettings.set_setting(
		"application/config/shop_catalog_source",
		str(settings.get("shop_catalog_source", "local"))
	)
	ProjectSettings.set_setting(
		"application/config/leaderboard_provider",
		str(settings.get("leaderboard_provider", "mock"))
	)
	ProjectSettings.set_setting("application/config/store_provider", str(settings.get("store_provider", "mock")))
	ProjectSettings.set_setting(PROVENANCE_PATH_SETTING, str(settings.get("content_provenance_path", "")))
