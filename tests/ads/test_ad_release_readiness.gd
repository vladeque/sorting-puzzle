extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const Readiness := preload("res://scripts/ads/ad_release_readiness.gd")

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Ad release-readiness verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var bundled := Readiness.evaluate(
		_read_json("res://configs/ad_release_evidence.json"),
		{},
		_read_json("res://configs/ads.json")
	)
	_check(
		not bool(bundled.get("ready", true)) and not (bundled.get("blockers", []) as Array).is_empty(),
		"The committed release remains honestly blocked while external evidence and IDs are absent."
	)

	var ready := Readiness.evaluate(_complete_evidence(), _complete_runtime(), _initial_policy())
	_check(bool(ready.get("ready", false)), "A complete initial-release evidence set passes.")
	var unsafe_policy := _initial_policy()
	(unsafe_policy["interstitial"] as Dictionary)["enabled"] = true
	(unsafe_policy["interstitial"] as Dictionary)["rollout_percent"] = 5
	var unsafe := Readiness.evaluate(_complete_evidence(), _complete_runtime(), unsafe_policy)
	_check(
		not bool(unsafe.get("ready", true)),
		"Initial-release readiness rejects enabled automatic interstitials."
	)

	if _failures.is_empty():
		print("ADS-008 release-readiness verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _complete_evidence() -> Dictionary:
	var approvals := {}
	for approval_id in Readiness.REQUIRED_APPROVALS:
		approvals[approval_id] = {"complete": true, "evidence": "ticket://approved/%s" % approval_id}
	return {
		"schema_version": 1,
		"release_phase": "initial",
		"audience_treatment": "general_3_plus",
		"ad_personalization": "non_personalized",
		"att_requested_for_ads": false,
		"approvals": approvals,
	}


func _complete_runtime() -> Dictionary:
	var runtime := {
		"provider": "admob",
		"native_integration_enabled": true,
		"privacy_policy_url": "https://example.invalid/privacy",
		"ad_report_url": "https://example.invalid/report-ad",
	}
	for setting_id in [
		"android_application_id", "ios_application_id",
		"android_time_extension_ad_unit_id", "android_life_ad_unit_id",
		"android_ability_ad_unit_id", "android_shelf_unlock_ad_unit_id",
		"android_interstitial_ad_unit_id", "ios_time_extension_ad_unit_id",
		"ios_life_ad_unit_id", "ios_ability_ad_unit_id",
		"ios_shelf_unlock_ad_unit_id", "ios_interstitial_ad_unit_id",
	]:
		runtime[setting_id] = "injected-%s" % setting_id
	return runtime


func _initial_policy() -> Dictionary:
	return {
		"schema_version": 1,
		"config_version": "initial-release-test-1",
		"provider_enabled": true,
		"rewarded": {
			"enabled": true,
			"time_extension_enabled": true,
			"life_enabled": true,
			"ability_enabled": true,
			"shelf_unlock_enabled": true,
		},
		"interstitial": {
			"enabled": false,
			"rollout_percent": 0,
			"completed_levels_per_ad": 3,
			"minimum_completed_levels_before_first_ad": 5,
			"minimum_seconds_between_ads": 600,
			"maximum_ads_per_session": 2,
			"suppress_after_rewarded_seconds": 300,
		},
	}


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file != null else null


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
