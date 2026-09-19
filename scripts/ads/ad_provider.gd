extends RefCounted
class_name AdProvider

const FORMAT_REWARDED := &"rewarded"
const FORMAT_INTERSTITIAL := &"interstitial"

const STATUS_READY := &"ready"
const STATUS_REWARDED := &"rewarded"
const STATUS_DISMISSED := &"dismissed"
const STATUS_UNAVAILABLE := &"unavailable"
const STATUS_FAILED := &"failed"


func get_provider_name() -> String:
	return "disabled"


func initialize() -> Dictionary:
	await _next_frame()
	return _result(STATUS_UNAVAILABLE, "provider_disabled")


func update_consent() -> Dictionary:
	await _next_frame()
	return {
		"status": STATUS_UNAVAILABLE,
		"allows_ads": false,
		"privacy_options_required": false,
		"reason": "provider_disabled",
	}


func show_privacy_options() -> Dictionary:
	await _next_frame()
	return _result(STATUS_UNAVAILABLE, "privacy_options_unavailable")


func load_ad(_format: StringName, _placement: StringName = &"") -> Dictionary:
	await _next_frame()
	return _result(STATUS_UNAVAILABLE, "provider_disabled")


func is_ad_ready(_format: StringName, _placement: StringName = &"") -> bool:
	return false


func show_rewarded(_placement: StringName, _context: Dictionary) -> Dictionary:
	await _next_frame()
	return _result(STATUS_UNAVAILABLE, "provider_disabled")


func show_interstitial(_context: Dictionary) -> Dictionary:
	await _next_frame()
	return _result(STATUS_UNAVAILABLE, "provider_disabled")


func get_diagnostics() -> Dictionary:
	return {
		"provider": get_provider_name(),
		"initialized": false,
		"consent_allows_ads": false,
		"privacy_options_required": false,
	}


func _result(status: StringName, reason: String = "", impression: bool = false) -> Dictionary:
	return {
		"status": status,
		"reason": reason,
		"impression": impression,
	}


func _next_frame() -> void:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		await (main_loop as SceneTree).process_frame
