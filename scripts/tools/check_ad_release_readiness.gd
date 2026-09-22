extends SceneTree

const Readiness := preload("res://scripts/ads/ad_release_readiness.gd")
const EVIDENCE_PATH := "res://configs/ad_release_evidence.json"
const POLICY_PATH := "res://configs/ads.json"


func _init() -> void:
	var evidence = _read_json(EVIDENCE_PATH)
	var policy = _read_json(POLICY_PATH)
	var runtime := {
		"provider": str(ProjectSettings.get_setting("application/config/ad_provider", "disabled")),
		"native_integration_enabled": bool(ProjectSettings.get_setting(
			"application/config/ad_native_integration_enabled", false
		)),
		"privacy_policy_url": str(ProjectSettings.get_setting(
			"application/config/ad_privacy_policy_url", ""
		)),
		"support_email": str(ProjectSettings.get_setting(
			"application/config/support_email", ""
		)),
		"android_application_id": str(ProjectSettings.get_setting(
			"admob/general/android/app_id", ""
		)),
		"ios_application_id": str(ProjectSettings.get_setting("admob/general/ios/app_id", "")),
		"android_time_extension_ad_unit_id": _setting("admob_android_rewarded_ad_unit_id"),
		"android_life_ad_unit_id": _setting("admob_android_rewarded_life_ad_unit_id"),
		"android_ability_ad_unit_id": _setting("admob_android_rewarded_ability_ad_unit_id"),
		"android_shelf_unlock_ad_unit_id": _setting("admob_android_rewarded_shelf_unlock_ad_unit_id"),
		"android_interstitial_ad_unit_id": _setting("admob_android_interstitial_ad_unit_id"),
		"ios_time_extension_ad_unit_id": _setting("admob_ios_rewarded_ad_unit_id"),
		"ios_life_ad_unit_id": _setting("admob_ios_rewarded_life_ad_unit_id"),
		"ios_ability_ad_unit_id": _setting("admob_ios_rewarded_ability_ad_unit_id"),
		"ios_shelf_unlock_ad_unit_id": _setting("admob_ios_rewarded_shelf_unlock_ad_unit_id"),
		"ios_interstitial_ad_unit_id": _setting("admob_ios_interstitial_ad_unit_id"),
	}
	var result := Readiness.evaluate(evidence, runtime, policy)
	if bool(result.get("ready", false)):
		print("ADS-008 release readiness passed.")
		quit(0)
		return
	print("ADS-008 release readiness BLOCKED:")
	for blocker in result.get("blockers", []) as Array:
		print("- %s" % blocker)
	quit(1)


func _setting(name: String) -> String:
	return str(ProjectSettings.get_setting("application/config/%s" % name, ""))


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file != null else null
