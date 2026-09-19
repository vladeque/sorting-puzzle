extends RefCounted
class_name AdPacingState

const SCHEMA_VERSION := 1


static func create_default() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"activation_baseline_total_completions": -1,
		"eligible_completions_since_interstitial": 0,
		"last_interstitial_impression_unix": 0,
		"session_interstitial_impressions": 0,
		"total_interstitial_impressions": 0,
		"last_rewarded_impression_unix": 0,
		"config_version": "",
	}


static func sanitize(raw_state: Variant) -> Dictionary:
	var sanitized := create_default()
	if not (raw_state is Dictionary):
		return sanitized
	var raw := raw_state as Dictionary
	if int(raw.get("schema_version", 0)) != SCHEMA_VERSION:
		return sanitized

	sanitized["activation_baseline_total_completions"] = maxi(
		int(raw.get("activation_baseline_total_completions", -1)),
		-1
	)
	sanitized["eligible_completions_since_interstitial"] = maxi(
		int(raw.get("eligible_completions_since_interstitial", 0)),
		0
	)
	sanitized["last_interstitial_impression_unix"] = maxi(
		int(raw.get("last_interstitial_impression_unix", 0)),
		0
	)
	sanitized["session_interstitial_impressions"] = maxi(
		int(raw.get("session_interstitial_impressions", 0)),
		0
	)
	sanitized["total_interstitial_impressions"] = maxi(
		int(raw.get("total_interstitial_impressions", 0)),
		0
	)
	sanitized["last_rewarded_impression_unix"] = maxi(
		int(raw.get("last_rewarded_impression_unix", 0)),
		0
	)
	sanitized["config_version"] = str(raw.get("config_version", "")).left(128)
	return sanitized


static func reset_session(raw_state: Variant) -> Dictionary:
	var state := sanitize(raw_state)
	state["session_interstitial_impressions"] = 0
	return state


static func activate(
	raw_state: Variant,
	total_completed_levels: int,
	config_version: String
) -> Dictionary:
	var state := sanitize(raw_state)
	if int(state["activation_baseline_total_completions"]) < 0:
		state["activation_baseline_total_completions"] = maxi(total_completed_levels, 0)
		state["eligible_completions_since_interstitial"] = 0
	state["config_version"] = config_version.left(128)
	return state


static func record_campaign_completion(raw_state: Variant) -> Dictionary:
	var state := sanitize(raw_state)
	if int(state["activation_baseline_total_completions"]) < 0:
		return state
	state["eligible_completions_since_interstitial"] = (
		int(state["eligible_completions_since_interstitial"]) + 1
	)
	return state


static func record_rewarded_impression(raw_state: Variant, now_unix: int) -> Dictionary:
	var state := sanitize(raw_state)
	state["last_rewarded_impression_unix"] = maxi(now_unix, 0)
	return state


static func record_interstitial_impression(raw_state: Variant, now_unix: int) -> Dictionary:
	var state := sanitize(raw_state)
	state["eligible_completions_since_interstitial"] = 0
	state["last_interstitial_impression_unix"] = maxi(now_unix, 0)
	state["session_interstitial_impressions"] = (
		int(state["session_interstitial_impressions"]) + 1
	)
	state["total_interstitial_impressions"] = int(state["total_interstitial_impressions"]) + 1
	return state
