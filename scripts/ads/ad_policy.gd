extends RefCounted
class_name AdPolicy

const AdPacingStateScript := preload("res://scripts/ads/ad_pacing_state.gd")

const PLACEMENT_TIME_EXTENSION := &"time_extension"
const PLACEMENT_LIFE := &"life"
const PLACEMENT_ABILITY := &"ability"
const PLACEMENT_SHELF_UNLOCK := &"shelf_unlock"
const REWARDED_PLACEMENTS := [
	PLACEMENT_TIME_EXTENSION,
	PLACEMENT_LIFE,
	PLACEMENT_ABILITY,
	PLACEMENT_SHELF_UNLOCK,
]

const REASON_ELIGIBLE := &"eligible"
const REASON_POLICY_INVALID := &"policy_invalid"
const REASON_PROVIDER_DISABLED := &"provider_disabled"
const REASON_FORMAT_DISABLED := &"format_disabled"
const REASON_PLACEMENT_DISABLED := &"placement_disabled"
const REASON_PROVIDER_NOT_READY := &"provider_not_ready"
const REASON_CONSENT_REQUIRED := &"consent_required"
const REASON_SERVER_UNAVAILABLE := &"server_unavailable"
const REASON_NOT_FOREGROUND := &"not_foreground"
const REASON_UNSAFE_CONTEXT := &"unsafe_context"
const REASON_NOT_ACTIVATED := &"not_activated"
const REASON_ROLLOUT := &"rollout"
const REASON_COMPLETION_THRESHOLD := &"completion_threshold"
const REASON_COOLDOWN := &"cooldown"
const REASON_SESSION_CAP := &"session_cap"
const REASON_REWARDED_SUPPRESSION := &"rewarded_suppression"

const MAX_COMPLETED_LEVELS_PER_AD := 100
const MAX_FIRST_AD_THRESHOLD := 1000
const MAX_COOLDOWN_SECONDS := 24 * 60 * 60
const MAX_SESSION_CAP := 20
const MAX_REWARDED_SUPPRESSION_SECONDS := 24 * 60 * 60

var _config := {}
var _valid := false
var _error := "Policy has not been configured."


func configure(raw_config: Variant) -> bool:
	_valid = false
	_config.clear()
	_error = _validate(raw_config)
	if not _error.is_empty():
		return false
	_config = (raw_config as Dictionary).duplicate(true)
	_valid = true
	return true


func is_valid() -> bool:
	return _valid


func get_error() -> String:
	return _error


func get_config_version() -> String:
	return str(_config.get("config_version", "")) if _valid else ""


func is_provider_enabled() -> bool:
	return _valid and bool(_config.get("provider_enabled", false))


func is_interstitial_enabled() -> bool:
	if not is_provider_enabled():
		return false
	var interstitial := _config.get("interstitial", {}) as Dictionary
	return bool(interstitial.get("enabled", false)) and int(interstitial.get("rollout_percent", 0)) > 0


func rewarded_decision(
	placement: StringName,
	provider_ready: bool,
	consent_allows_ads: bool,
	server_can_accept_claim: bool = true
) -> Dictionary:
	if not _valid:
		return _decision(false, REASON_POLICY_INVALID)
	if placement not in REWARDED_PLACEMENTS:
		return _decision(false, REASON_PLACEMENT_DISABLED)
	if not bool(_config.get("provider_enabled", false)):
		return _decision(false, REASON_PROVIDER_DISABLED)
	var rewarded := _config.get("rewarded", {}) as Dictionary
	if not bool(rewarded.get("enabled", false)):
		return _decision(false, REASON_FORMAT_DISABLED)
	if not bool(rewarded.get("%s_enabled" % String(placement), false)):
		return _decision(false, REASON_PLACEMENT_DISABLED)
	if not consent_allows_ads:
		return _decision(false, REASON_CONSENT_REQUIRED)
	if not provider_ready:
		return _decision(false, REASON_PROVIDER_NOT_READY)
	if not server_can_accept_claim:
		return _decision(false, REASON_SERVER_UNAVAILABLE)
	return _decision(true, REASON_ELIGIBLE)


func interstitial_decision(
	raw_state: Variant,
	context: Dictionary,
	now_unix: int
) -> Dictionary:
	if not _valid:
		return _decision(false, REASON_POLICY_INVALID)
	if not bool(_config.get("provider_enabled", false)):
		return _decision(false, REASON_PROVIDER_DISABLED)
	var interstitial := _config.get("interstitial", {}) as Dictionary
	if not bool(interstitial.get("enabled", false)):
		return _decision(false, REASON_FORMAT_DISABLED)
	if not bool(context.get("provider_ready", false)):
		return _decision(false, REASON_PROVIDER_NOT_READY)
	if not bool(context.get("consent_allows_ads", false)):
		return _decision(false, REASON_CONSENT_REQUIRED)
	if not bool(context.get("foreground", false)):
		return _decision(false, REASON_NOT_FOREGROUND)
	if not bool(context.get("safe_transition", false)):
		return _decision(false, REASON_UNSAFE_CONTEXT)

	var state := AdPacingStateScript.sanitize(raw_state)
	if int(state.get("activation_baseline_total_completions", -1)) < 0:
		return _decision(false, REASON_NOT_ACTIVATED)
	var rollout_percent := int(interstitial.get("rollout_percent", 0))
	var rollout_bucket := int(context.get("rollout_bucket", -1))
	if rollout_bucket < 0 or rollout_bucket > 99:
		return _decision(false, REASON_ROLLOUT)
	if rollout_bucket >= rollout_percent:
		return _decision(false, REASON_ROLLOUT)

	var completed_since := int(state.get("eligible_completions_since_interstitial", 0))
	var total_impressions := int(state.get("total_interstitial_impressions", 0))
	var required_completions := int(interstitial.get("completed_levels_per_ad", 0))
	if total_impressions == 0:
		required_completions = int(
			interstitial.get("minimum_completed_levels_before_first_ad", 0)
		)
	if completed_since < required_completions:
		return _decision(false, REASON_COMPLETION_THRESHOLD)

	var last_interstitial := int(state.get("last_interstitial_impression_unix", 0))
	var cooldown := int(interstitial.get("minimum_seconds_between_ads", 0))
	if last_interstitial > 0 and now_unix - last_interstitial < cooldown:
		return _decision(false, REASON_COOLDOWN)
	if (
		int(state.get("session_interstitial_impressions", 0))
		>= int(interstitial.get("maximum_ads_per_session", 0))
	):
		return _decision(false, REASON_SESSION_CAP)
	var last_rewarded := int(state.get("last_rewarded_impression_unix", 0))
	var suppression := int(interstitial.get("suppress_after_rewarded_seconds", 0))
	if last_rewarded > 0 and now_unix - last_rewarded < suppression:
		return _decision(false, REASON_REWARDED_SUPPRESSION)
	return _decision(true, REASON_ELIGIBLE)


func get_interstitial_config() -> Dictionary:
	return (
		(_config.get("interstitial", {}) as Dictionary).duplicate(true)
		if _valid
		else {}
	)


func _validate(raw_config: Variant) -> String:
	if not (raw_config is Dictionary):
		return "Ad policy root must be an object."
	var raw := raw_config as Dictionary
	if int(raw.get("schema_version", 0)) != 1:
		return "Unsupported ad policy schema version."
	var config_version := str(raw.get("config_version", "")).strip_edges()
	if config_version.is_empty() or config_version.length() > 128:
		return "Ad policy config_version is invalid."
	if not (raw.get("provider_enabled") is bool):
		return "Ad policy provider_enabled must be a boolean."
	if not (raw.get("rewarded") is Dictionary):
		return "Ad policy rewarded section must be an object."
	var rewarded := raw.get("rewarded", {}) as Dictionary
	for key in [
		"enabled",
		"time_extension_enabled",
		"life_enabled",
		"ability_enabled",
		"shelf_unlock_enabled",
	]:
		if not (rewarded.get(key) is bool):
			return "Ad policy rewarded.%s must be a boolean." % key

	if not (raw.get("interstitial") is Dictionary):
		return "Ad policy interstitial section must be an object."
	var interstitial := raw.get("interstitial", {}) as Dictionary
	if not (interstitial.get("enabled") is bool):
		return "Ad policy interstitial.enabled must be a boolean."
	var bounded_values := {
		"rollout_percent": [0, 100],
		"completed_levels_per_ad": [1, MAX_COMPLETED_LEVELS_PER_AD],
		"minimum_completed_levels_before_first_ad": [1, MAX_FIRST_AD_THRESHOLD],
		"minimum_seconds_between_ads": [1, MAX_COOLDOWN_SECONDS],
		"maximum_ads_per_session": [1, MAX_SESSION_CAP],
		"suppress_after_rewarded_seconds": [0, MAX_REWARDED_SUPPRESSION_SECONDS],
	}
	for key in bounded_values:
		if not (interstitial.get(key) is int or interstitial.get(key) is float):
			return "Ad policy interstitial.%s must be numeric." % key
		if float(interstitial.get(key)) != floorf(float(interstitial.get(key))):
			return "Ad policy interstitial.%s must be a whole number." % key
		var bounds := bounded_values[key] as Array
		var value := int(interstitial.get(key, -1))
		if value < int(bounds[0]) or value > int(bounds[1]):
			return "Ad policy interstitial.%s is outside its allowed range." % key
	return ""


func _decision(eligible: bool, reason: StringName) -> Dictionary:
	return {"eligible": eligible, "reason": reason}
