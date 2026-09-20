extends Node

## ADS-007's level-scoped boundary. A committed campaign completion is counted once, then the
## completion screen may make one best-effort presentation request while leaving for the menu.
## Provider dismissal, no-fill, policy denial, and show failure are all terminal results; Level
## always continues navigation after this owner returns.

var _ad_service
var _completion_recorded := false
var _presentation_started := false


func configure(ad_service) -> void:
	_ad_service = ad_service


func reset_attempt() -> void:
	_completion_recorded = false
	_presentation_started = false


func record_committed_completion(total_completed_levels: int) -> Dictionary:
	if _completion_recorded:
		return _result(false, "completion_already_recorded")
	_completion_recorded = true
	if _ad_service == null:
		return _result(false, "ad_service_unavailable")

	# On the first enabled build, baseline all historical completions and count only the completion
	# that was just committed. activate_interstitial_pacing() is idempotent after that first call.
	var baseline := maxi(total_completed_levels - 1, 0)
	if not bool(_ad_service.call("activate_interstitial_pacing", baseline)):
		return _result(false, "interstitial_not_activated")
	if not bool(_ad_service.call("record_campaign_completion")):
		return _result(false, "completion_not_recorded")

	var preload_result: Dictionary = await _ad_service.call("preload_interstitial")
	return {
		"ok": true,
		"counted": true,
		"preload_status": preload_result.get("status", &"unavailable"),
		"preload_reason": str(preload_result.get("reason", "")),
	}


func present_before_navigation() -> Dictionary:
	if _presentation_started:
		return _result(false, "presentation_already_started")
	_presentation_started = true
	if not _completion_recorded:
		return _result(false, "completion_not_recorded")
	if _ad_service == null:
		return _result(false, "ad_service_unavailable")
	return await _ad_service.call("request_interstitial", {
		"safe_transition": true,
		"trigger": "committed_campaign_completion",
	})


func is_presenting() -> bool:
	return _presentation_started


func _result(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": reason, "impression": false}
