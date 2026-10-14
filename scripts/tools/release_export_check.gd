extends RefCounted
class_name ReleaseExportCheck

## Release-safety step 2.4 (d) of the Google Play testing plan and the DEV-CODE-004 export
## validation: the pure rules behind scripts/tools/check_release_export.gd, kept free of the
## filesystem so tests can drive every rule. `validate()` returns one result per rule:
## {name, ok, detail}.
##
## Input keys: `preset` (name, platform, custom_features, exclude_filter), `options` (the preset's
## options section), `environments` (configs/backend/environments.json), `project` (version,
## build_number, support_email), `provenance` (ok, environment, error for the production manifest),
## `store_guard` (whether StoreService carries the release guard), and `secure_store`
## (plugin_enabled, release_aar_present for the SortingPuzzleSecureStoreBridge export plugin).

const BackendEnvironmentScript := preload("res://scripts/backend/backend_environment.gd")
const RELEASE_ENVIRONMENT := "production"
const REQUIRED_EXCLUSIONS := ["local/*", "tests/*"]


static func validate(input: Dictionary) -> Array:
	var results := []
	var preset := input.get("preset", {}) as Dictionary
	var options := input.get("options", {}) as Dictionary
	var project := input.get("project", {}) as Dictionary
	var provenance := input.get("provenance", {}) as Dictionary

	results.append(_rule(
		"Android platform",
		str(preset.get("platform", "")) == "Android",
		"the release preset must target Android"
	))

	var tags := []
	for feature in str(preset.get("custom_features", "")).split(",", false):
		if feature.strip_edges().begins_with(BackendEnvironmentScript.FEATURE_PREFIX):
			tags.append(feature.strip_edges())
	var tag_ok: bool = tags == [BackendEnvironmentScript.FEATURE_PREFIX + RELEASE_ENVIRONMENT]
	results.append(_rule(
		"production environment tag",
		tag_ok,
		"custom_features must contain exactly backend_production, found %s" % [tags]
	))

	var environments := input.get("environments", {}) as Dictionary
	var selection: Dictionary = BackendEnvironmentScript.resolve(
		[BackendEnvironmentScript.FEATURE_PREFIX + RELEASE_ENVIRONMENT],
		environments
	)
	results.append(_rule(
		"production environment valid",
		bool(selection.get("ok", false)),
		str(selection.get("error", ""))
	))
	var settings := selection.get("settings", {}) as Dictionary
	var development := (environments.get("environments", {}) as Dictionary).get("development", {}) as Dictionary
	results.append(_rule(
		"production origin is not development",
		not str(settings.get("api_origin", "")).is_empty()
		and str(settings.get("api_origin", "")) != str(development.get("api_origin", "")),
		"the production api_origin must differ from the development one"
	))
	results.append(_rule(
		"package name",
		not str(settings.get("android_package", "")).is_empty()
		and str(options.get("package/unique_name", "")) == str(settings.get("android_package", "")),
		"package/unique_name %s must equal the production android_package %s" % [
			options.get("package/unique_name", ""),
			settings.get("android_package", ""),
		]
	))

	var exclusions := []
	for pattern in str(preset.get("exclude_filter", "")).split(",", false):
		exclusions.append(pattern.strip_edges())
	var missing := []
	for required in REQUIRED_EXCLUSIONS:
		if not exclusions.has(required):
			missing.append(required)
	results.append(_rule(
		"local and test files excluded",
		missing.is_empty(),
		"exclude_filter must contain %s" % [missing]
	))
	var secure_store := input.get("secure_store", {}) as Dictionary
	results.append(_rule(
		"release secure-store bridge",
		bool(secure_store.get("plugin_enabled", false))
		and bool(secure_store.get("release_aar_present", false)),
		"enable the SortingPuzzleSecureStoreBridge plugin and build its release AAR with "
		+ "./gradlew :plugin:assembleRelease; without it the build has no session storage"
	))
	results.append(_rule(
		"Internet permission",
		options.get("permissions/internet", false) == true,
		"permissions/internet must be true; release builds get no INTERNET from the secure-store AAR"
	))
	results.append(_rule(
		"no debug command-line arguments",
		str(options.get("command_line/extra_args", "")).strip_edges().is_empty(),
		"command_line/extra_args must be empty in release"
	))
	results.append(_rule(
		"Play bundle format",
		options.get("gradle_build/use_gradle_build", false) == true
		and int(options.get("gradle_build/export_format", 0)) == 1,
		"the release preset must use a Gradle build that exports an AAB (export_format 1)"
	))
	results.append(_rule(
		"signed",
		options.get("package/signed", false) == true,
		"package/signed must be true"
	))
	results.append(_rule(
		"version matches the project",
		int(options.get("version/code", 0)) == int(project.get("build_number", -1))
		and str(options.get("version/name", "")) == str(project.get("version", "")),
		"version/code %s and version/name %s must equal build_number %s and version %s" % [
			options.get("version/code", ""),
			options.get("version/name", ""),
			project.get("build_number", ""),
			project.get("version", ""),
		]
	))

	var support_email := str(project.get("support_email", "")).strip_edges()
	results.append(_rule(
		"real support email",
		support_email.contains("@") and not support_email.contains("example"),
		"application/config/support_email %s is a placeholder" % support_email
	))
	results.append(_rule(
		"no purchases through the mock store",
		str(settings.get("store_provider", "")) != "mock" or bool(input.get("store_guard", false)),
		"the mock store provider ships only with StoreService's release guard"
	))
	results.append(_rule(
		"production content provenance",
		bool(provenance.get("ok", false))
		and str(provenance.get("environment", "")) == RELEASE_ENVIRONMENT,
		"the production manifest must load and be for production: %s" % (
			str(provenance.get("error", "")) if not bool(provenance.get("ok", false))
			else "it is for %s" % str(provenance.get("environment", ""))
		)
	))
	return results


static func _rule(name: String, ok: bool, detail: String) -> Dictionary:
	return {"name": name, "ok": ok, "detail": "" if ok else detail}
