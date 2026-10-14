extends SceneTree

## DEV-CODE-004 coverage: backend environment selection from configs/backend/environments.json,
## the release export check rules, and the content provenance environment guard.

const BackendEnvironmentScript := preload("res://scripts/backend/backend_environment.gd")
const ReleaseExportCheckScript := preload("res://scripts/tools/release_export_check.gd")
const ContentProvenanceManifestScript := preload("res://scripts/save/content_provenance_manifest.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_check_environment_selection()
	_check_release_export_rules()
	_check_provenance_environment_guard()
	if _failures.is_empty():
		print("Backend environment tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_environment_selection() -> void:
	var config := BackendEnvironmentScript.load_config()
	var production: Dictionary = BackendEnvironmentScript.resolve(["backend_production"], config)
	_check(bool(production.get("ok", false)), "the committed production environment is valid")
	var settings := production.get("settings", {}) as Dictionary
	_check(
		str(settings.get("api_origin", "")) == "https://sorting-puzzle-api-82809416429.europe-west3.run.app",
		"production uses the production Cloud Run origin"
	)
	_check(bool(settings.get("save_sync_v2_enabled", false)), "production turns cloud save on")
	_check(
		str(settings.get("shop_catalog_source", "")) == "backend"
		and str(settings.get("leaderboard_provider", "")) == "backend",
		"production reads the Shop catalog and leaderboards from the backend"
	)
	_check(
		bool(BackendEnvironmentScript.resolve(["backend_development"], config).get("ok", false)),
		"the committed development environment is valid"
	)

	_check(
		not bool(BackendEnvironmentScript.resolve([], config).get("ok", true)),
		"no environment tag selects nothing"
	)
	_check(
		not bool(BackendEnvironmentScript.resolve(["backend_development", "backend_production"], config).get("ok", true)),
		"two environment tags never combine"
	)
	_check(
		not bool(BackendEnvironmentScript.resolve(["backend_staging"], config).get("ok", true)),
		"an unknown environment tag selects nothing"
	)
	_check(
		not bool(BackendEnvironmentScript.resolve(["backend_production"], {}).get("ok", true)),
		"a missing configuration selects nothing"
	)
	for bad_origin in [
		"http://sorting-puzzle-api-82809416429.europe-west3.run.app",
		"https://127.0.0.1:8080",
		"https://10.0.2.2",
		"https://example.run.app/v1",
		"https://",
	]:
		var bad := config.duplicate(true)
		((bad.get("environments") as Dictionary).get("production") as Dictionary)["api_origin"] = bad_origin
		_check(
			not bool(BackendEnvironmentScript.resolve(["backend_production"], bad).get("ok", true)),
			"the production origin %s is refused" % bad_origin
		)
	var keys := [
		"application/config/backend_environment",
		"application/config/backend_base_url",
		"application/config/save_sync_v2_enabled",
		"application/config/shop_catalog_source",
		"application/config/leaderboard_provider",
		"application/config/store_provider",
		"application/config/content_provenance_path",
	]
	var originals := {}
	for key in keys:
		originals[key] = ProjectSettings.get_setting(key, null)
	BackendEnvironmentScript.apply(production)
	_check(
		ProjectSettings.get_setting("application/config/backend_environment") == "production"
		and ProjectSettings.get_setting("application/config/backend_base_url") == settings.get("api_origin")
		and ProjectSettings.get_setting("application/config/save_sync_v2_enabled") == true
		and ProjectSettings.get_setting("application/config/shop_catalog_source") == "backend"
		and ProjectSettings.get_setting("application/config/leaderboard_provider") == "backend"
		and ProjectSettings.get_setting("application/config/store_provider") == "mock"
		and ProjectSettings.get_setting("application/config/content_provenance_path")
			== "res://configs/backend/content_provenance.production.json",
		"applying production sets every backend setting together"
	)
	for key in keys:
		ProjectSettings.set_setting(key, originals[key])

	var unknown_store := config.duplicate(true)
	((unknown_store.get("environments") as Dictionary).get("production") as Dictionary)["store_provider"] = "google_play"
	_check(
		not bool(BackendEnvironmentScript.resolve(["backend_production"], unknown_store).get("ok", true)),
		"a store provider the game does not implement is refused"
	)


func _check_release_export_rules() -> void:
	var valid := _valid_export_input()
	_check(_failed_rules(valid).is_empty(), "a correct release preset passes every rule: %s" % [_failed_rules(valid)])

	var cases := [
		["package name", func(input): input["options"]["package/unique_name"] = "com.sortingpuzzle.game"],
		["production environment tag", func(input): input["preset"]["custom_features"] = ""],
		["production environment tag", func(input): input["preset"]["custom_features"] = "backend_production,backend_development"],
		["local and test files excluded", func(input): input["preset"]["exclude_filter"] = "tests/*"],
		["Internet permission", func(input): input["options"]["permissions/internet"] = false],
		["release secure-store bridge", func(input): input["secure_store"]["release_aar_present"] = false],
		["release secure-store bridge", func(input): input["secure_store"]["plugin_enabled"] = false],
		["no debug command-line arguments", func(input): input["options"]["command_line/extra_args"] = "--rendering-method gl_compatibility"],
		["Play bundle format", func(input): input["options"]["gradle_build/export_format"] = 0],
		["signed", func(input): input["options"]["package/signed"] = false],
		["version matches the project", func(input): input["options"]["version/code"] = 2],
		["real support email", func(input): input["project"]["support_email"] = "support@sortingpuzzle.example"],
		["no purchases through the mock store", func(input): input["store_guard"] = false],
		["production content provenance", func(input): input["provenance"] = {"ok": true, "environment": "development", "error": ""}],
		["production content provenance", func(input): input["provenance"] = {"ok": false, "environment": "", "error": "missing"}],
		["production origin is not development", func(input):
			var production := (input["environments"]["environments"] as Dictionary)["production"] as Dictionary
			production["api_origin"] = (input["environments"]["environments"] as Dictionary)["development"]["api_origin"]],
	]
	for case in cases:
		var input := _valid_export_input()
		(case[1] as Callable).call(input)
		_check(
			_failed_rules(input).has(str(case[0])),
			"the release check catches a broken \"%s\" rule" % str(case[0])
		)


func _check_provenance_environment_guard() -> void:
	var manifest = ContentProvenanceManifestScript.new()
	var loaded: Dictionary = manifest.load_manifest()
	_check(bool(loaded.get("ok", false)), "the committed development manifest loads")
	_check(bool(manifest.require_environment("").get("ok", false)), "a build without an environment accepts it")
	_check(
		bool(manifest.require_environment("development").get("ok", false)),
		"a development build accepts the development manifest"
	)
	var mismatch: Dictionary = manifest.require_environment("production")
	_check(
		not bool(mismatch.get("ok", true))
		and str(mismatch.get("code", "")) == "content_manifest.environment_mismatch"
		and not manifest.is_valid(),
		"a production build refuses the development manifest, which disables sync"
	)


func _valid_export_input() -> Dictionary:
	return {
		"preset": {
			"name": "Android (Release)",
			"platform": "Android",
			"custom_features": "backend_production",
			"exclude_filter": "local/*, tests/*, tmp/*, build/*, docs/*",
		},
		"options": {
			"command_line/extra_args": "",
			"gradle_build/use_gradle_build": true,
			"gradle_build/export_format": 1,
			"version/code": 7,
			"version/name": "1.2.0",
			"package/unique_name": "com.vbrus.sortingpuzzle",
			"package/signed": true,
			"permissions/internet": true,
		},
		"environments": BackendEnvironmentScript.load_config(),
		"project": {"version": "1.2.0", "build_number": 7, "support_email": "support@vbrus.dev"},
		"provenance": {"ok": true, "environment": "production", "error": ""},
		"store_guard": true,
		"secure_store": {"plugin_enabled": true, "release_aar_present": true},
	}


func _failed_rules(input: Dictionary) -> Array:
	var failed := []
	for result in ReleaseExportCheckScript.validate(input):
		if not bool((result as Dictionary).get("ok", false)):
			failed.append(str((result as Dictionary).get("name", "")))
	return failed


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
