extends RefCounted
class_name AdReleaseReadiness

## ADS-008 fail-closed release audit. This validator does not pretend repository checks can approve
## store declarations or physical devices: every external gate needs a completed flag and a useful
## evidence reference before an ads-enabled release can be declared ready.

const REQUIRED_APPROVALS := [
	"license_and_security_review",
	"privacy_policy_review",
	"google_play_disclosures",
	"app_store_privacy_details",
	"android_physical_device",
	"ios_archive_and_device",
]
const AdPolicyScript := preload("res://scripts/ads/ad_policy.gd")


static func evaluate(evidence: Variant, runtime: Dictionary, policy: Variant) -> Dictionary:
	var blockers: Array[String] = []
	if not (evidence is Dictionary):
		return _result(["Release evidence file is not an object."])
	var document := evidence as Dictionary
	if int(document.get("schema_version", 0)) != 1:
		blockers.append("Release evidence schema_version must be 1.")
	if str(document.get("release_phase", "")) != "initial":
		blockers.append("This checklist only approves the initial release phase.")
	if str(document.get("audience_treatment", "")) != "general_3_plus":
		blockers.append("Audience treatment is not the approved general 3+ baseline.")
	if str(document.get("ad_personalization", "")) != "non_personalized":
		blockers.append("Initial-release ads must remain non-personalized.")
	if bool(document.get("att_requested_for_ads", true)):
		blockers.append("ATT must not be requested solely for the initial ads configuration.")

	var approvals = document.get("approvals")
	if not (approvals is Dictionary):
		blockers.append("Release approvals must be an object.")
	else:
		for approval_id in REQUIRED_APPROVALS:
			var approval = (approvals as Dictionary).get(approval_id)
			if not (approval is Dictionary):
				blockers.append("Missing approval: %s." % approval_id)
				continue
			if not bool((approval as Dictionary).get("complete", false)):
				blockers.append("Approval is incomplete: %s." % approval_id)
			elif str((approval as Dictionary).get("evidence", "")).strip_edges().length() < 8:
				blockers.append("Approval evidence is missing: %s." % approval_id)

	if not (policy is Dictionary):
		blockers.append("Ad policy is missing or invalid.")
	else:
		var policy_validator := AdPolicyScript.new()
		if not policy_validator.configure(policy):
			blockers.append("Ad policy is invalid: %s" % policy_validator.get_error())
		if not bool((policy as Dictionary).get("provider_enabled", false)):
			blockers.append("Ad policy provider is disabled.")
		var rewarded := (policy as Dictionary).get("rewarded", {}) as Dictionary
		if not bool(rewarded.get("enabled", false)):
			blockers.append("Rewarded ads are globally disabled.")
		for placement in ["time_extension", "life", "ability", "shelf_unlock"]:
			if not bool(rewarded.get("%s_enabled" % placement, false)):
				blockers.append("Rewarded placement is disabled: %s." % placement)
		var interstitial := (policy as Dictionary).get("interstitial", {}) as Dictionary
		if bool(interstitial.get("enabled", true)) or int(interstitial.get("rollout_percent", -1)) != 0:
			blockers.append("Initial-release interstitials must be disabled with zero rollout.")

	if str(runtime.get("provider", "")) != "admob":
		blockers.append("Release provider must be admob.")
	if not bool(runtime.get("native_integration_enabled", false)):
		blockers.append("Native ad integration is disabled.")
	if not _is_https_url(str(runtime.get("privacy_policy_url", ""))):
		blockers.append("A valid HTTPS in-app privacy-policy URL is required.")
	if not _is_release_support_email(str(runtime.get("support_email", ""))):
		blockers.append("A non-placeholder support email is required for inappropriate-ad reports.")
	for setting_id in [
		"android_application_id",
		"ios_application_id",
		"android_time_extension_ad_unit_id",
		"android_life_ad_unit_id",
		"android_ability_ad_unit_id",
		"android_shelf_unlock_ad_unit_id",
		"android_interstitial_ad_unit_id",
		"ios_time_extension_ad_unit_id",
		"ios_life_ad_unit_id",
		"ios_ability_ad_unit_id",
		"ios_shelf_unlock_ad_unit_id",
		"ios_interstitial_ad_unit_id",
	]:
		if str(runtime.get(setting_id, "")).strip_edges().is_empty():
			blockers.append("Missing injected release identifier: %s." % setting_id)

	return _result(blockers)


static func _is_https_url(value: String) -> bool:
	var url := value.strip_edges()
	return url.begins_with("https://") and url.length() <= 2048


static func _is_release_support_email(value: String) -> bool:
	var email := value.strip_edges().to_lower()
	if email.is_empty() or email.length() > 254 or email.contains(" ") or email.count("@") != 1:
		return false
	var parts := email.split("@", false, 1)
	if parts.size() != 2 or parts[0].is_empty() or not parts[1].contains("."):
		return false
	return not (
		parts[1].ends_with(".example")
		or parts[1].ends_with(".invalid")
		or parts[1].ends_with(".test")
		or parts[1] == "example.com"
	)


static func _result(blockers: Array[String]) -> Dictionary:
	return {"ready": blockers.is_empty(), "blockers": blockers}
