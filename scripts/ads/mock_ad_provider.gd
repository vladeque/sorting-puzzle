extends "res://scripts/ads/ad_provider.gd"
class_name MockAdProvider

var _initialized := false
var _consent_allows_ads := true
var _privacy_options_required := false
var _ready_formats := {}
var _outcomes := {
	FORMAT_REWARDED: [],
	FORMAT_INTERSTITIAL: [],
}
var _calls: Array[Dictionary] = []


func get_provider_name() -> String:
	return "mock"


func initialize() -> Dictionary:
	_calls.append({"method": "initialize"})
	await _next_frame()
	_initialized = true
	return _result(STATUS_READY)


func update_consent() -> Dictionary:
	_calls.append({"method": "update_consent"})
	await _next_frame()
	return {
		"status": STATUS_READY,
		"allows_ads": _consent_allows_ads,
		"privacy_options_required": _privacy_options_required,
		"reason": "",
	}


func show_privacy_options() -> Dictionary:
	_calls.append({"method": "show_privacy_options"})
	await _next_frame()
	if not _privacy_options_required:
		return _result(STATUS_UNAVAILABLE, "privacy_options_not_required")
	return _result(STATUS_READY)


func load_ad(format: StringName, placement: StringName = &"") -> Dictionary:
	_calls.append({"method": "load_ad", "format": format, "placement": placement})
	await _next_frame()
	if not _initialized or not _consent_allows_ads:
		return _result(STATUS_UNAVAILABLE, "mock_not_ready")
	_ready_formats[format] = true
	return _result(STATUS_READY)


func is_ad_ready(format: StringName, _placement: StringName = &"") -> bool:
	return _initialized and _consent_allows_ads and bool(_ready_formats.get(format, false))


func show_rewarded(placement: StringName, context: Dictionary) -> Dictionary:
	_calls.append({
		"method": "show_rewarded",
		"placement": placement,
		"context": context.duplicate(true),
	})
	return await _consume_outcome(FORMAT_REWARDED)


func show_interstitial(context: Dictionary) -> Dictionary:
	_calls.append({"method": "show_interstitial", "context": context.duplicate(true)})
	return await _consume_outcome(FORMAT_INTERSTITIAL)


func set_consent(allows_ads: bool, privacy_options_required: bool = false) -> void:
	_consent_allows_ads = allows_ads
	_privacy_options_required = privacy_options_required
	if not allows_ads:
		_ready_formats.clear()


func queue_outcome(format: StringName, outcome: Dictionary) -> void:
	if not _outcomes.has(format):
		return
	(_outcomes[format] as Array).append(outcome.duplicate(true))


func get_calls() -> Array[Dictionary]:
	return _calls.duplicate(true)


func clear_calls() -> void:
	_calls.clear()


func get_diagnostics() -> Dictionary:
	return {
		"provider": get_provider_name(),
		"initialized": _initialized,
		"consent_allows_ads": _consent_allows_ads,
		"privacy_options_required": _privacy_options_required,
		"rewarded_ready": is_ad_ready(FORMAT_REWARDED),
		"interstitial_ready": is_ad_ready(FORMAT_INTERSTITIAL),
	}


func _consume_outcome(format: StringName) -> Dictionary:
	if not is_ad_ready(format):
		await _next_frame()
		return _result(STATUS_UNAVAILABLE, "mock_ad_not_loaded")
	_ready_formats[format] = false
	var queue := _outcomes[format] as Array
	var outcome := (
		queue.pop_front() as Dictionary
		if not queue.is_empty()
		else _result(STATUS_DISMISSED, "mock_default_dismissal", true)
	)
	var delay_frames := clampi(int(outcome.get("delay_frames", 1)), 1, 120)
	for _index in range(delay_frames):
		await _next_frame()
	outcome.erase("delay_frames")
	if not outcome.has("impression"):
		outcome["impression"] = true
	return outcome
