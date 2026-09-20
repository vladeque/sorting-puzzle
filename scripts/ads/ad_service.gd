extends Node
class_name AdServiceOwner

signal readiness_changed
signal request_started(request_id: int, format: StringName, placement: StringName)
signal request_finished(request_id: int, result: Dictionary)
signal privacy_options_requirement_changed(required: bool)

const AdPolicyScript := preload("res://scripts/ads/ad_policy.gd")
const AdProviderScript := preload("res://scripts/ads/ad_provider.gd")
const MockAdProviderScript := preload("res://scripts/ads/mock_ad_provider.gd")
const AdPacingStateScript := preload("res://scripts/ads/ad_pacing_state.gd")

const CONFIG_PATH := "res://configs/ads.json"
const PROVIDER_SETTING := "application/config/ad_provider"
const ALLOW_MOCK_SETTING := "application/config/ad_allow_mock_provider"
const PROVIDER_DISABLED := "disabled"
const PROVIDER_MOCK := "mock"
const PROVIDER_ADMOB := "admob"
const NATIVE_INTEGRATION_SETTING := "application/config/ad_native_integration_enabled"

var _policy := AdPolicyScript.new()
var _provider: RefCounted = AdProviderScript.new()
var _pacing_state := AdPacingStateScript.create_default()
var _initialized := false
var _consent_allows_ads := false
var _privacy_options_required := false
var _foreground := true
var _active_request_id := 0
var _next_request_id := 1
var _audio_snapshot: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var policy_result := _load_bundled_policy()
	if not bool(policy_result.get("ok", false)):
		push_warning("Ads remain disabled: %s" % policy_result.get("error", "invalid policy"))
	_load_pacing_state()
	_pacing_state = AdPacingStateScript.reset_session(_pacing_state)
	_persist_pacing_state()
	_provider = _create_provider()
	if _policy.is_provider_enabled():
		call_deferred("initialize")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_foreground = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_foreground = false
	elif what == NOTIFICATION_PREDELETE:
		_restore_audio_state()


func initialize() -> Dictionary:
	if not _policy.is_provider_enabled():
		return _result(AdProviderScript.STATUS_UNAVAILABLE, "provider_disabled")
	if _initialized:
		return _result(AdProviderScript.STATUS_READY)
	var initialization: Dictionary = await _provider.initialize()
	_initialized = initialization.get("status") == AdProviderScript.STATUS_READY
	if not _initialized:
		readiness_changed.emit()
		return initialization
	var consent: Dictionary = await refresh_consent()
	readiness_changed.emit()
	return consent if not _consent_allows_ads else initialization


func refresh_consent() -> Dictionary:
	if not _initialized:
		return _result(AdProviderScript.STATUS_UNAVAILABLE, "provider_not_initialized")
	var consent: Dictionary = await _provider.update_consent()
	_consent_allows_ads = bool(consent.get("allows_ads", false))
	var requirement_changed := (
		_privacy_options_required != bool(consent.get("privacy_options_required", false))
	)
	_privacy_options_required = bool(consent.get("privacy_options_required", false))
	if requirement_changed:
		privacy_options_requirement_changed.emit(_privacy_options_required)
	readiness_changed.emit()
	return consent


func show_privacy_options() -> Dictionary:
	if not _initialized or not _privacy_options_required:
		return _result(AdProviderScript.STATUS_UNAVAILABLE, "privacy_options_unavailable")
	var result: Dictionary = await _provider.show_privacy_options()
	if result.get("status") == AdProviderScript.STATUS_READY:
		await refresh_consent()
	return result


func preload_rewarded(placement: StringName, server_can_accept_claim: bool = true) -> Dictionary:
	var decision := _policy.rewarded_decision(
		placement,
		_initialized,
		_consent_allows_ads,
		server_can_accept_claim
	)
	if not bool(decision.get("eligible", false)):
		return _result(AdProviderScript.STATUS_UNAVAILABLE, String(decision.get("reason", "")))
	var result: Dictionary = await _provider.load_ad(AdProviderScript.FORMAT_REWARDED, placement)
	readiness_changed.emit()
	return result


func preload_interstitial() -> Dictionary:
	if not _policy.is_interstitial_enabled() or not _initialized or not _consent_allows_ads:
		return _result(AdProviderScript.STATUS_UNAVAILABLE, "interstitial_not_eligible")
	var result: Dictionary = await _provider.load_ad(AdProviderScript.FORMAT_INTERSTITIAL)
	readiness_changed.emit()
	return result


func is_interstitial_enabled() -> bool:
	return _policy.is_interstitial_enabled()


func is_rewarded_ready(placement: StringName, server_can_accept_claim: bool = true) -> bool:
	var decision := _policy.rewarded_decision(
		placement,
		_initialized and _provider.is_ad_ready(AdProviderScript.FORMAT_REWARDED, placement),
		_consent_allows_ads,
		server_can_accept_claim
	)
	return bool(decision.get("eligible", false))


func request_rewarded(
	placement: StringName,
	context: Dictionary = {},
	server_can_accept_claim: bool = true
) -> Dictionary:
	if _active_request_id != 0:
		return _result(AdProviderScript.STATUS_UNAVAILABLE, "ad_request_in_progress")
	var decision := _policy.rewarded_decision(
		placement,
		_initialized and _provider.is_ad_ready(AdProviderScript.FORMAT_REWARDED, placement),
		_consent_allows_ads,
		server_can_accept_claim
	)
	if not bool(decision.get("eligible", false)):
		return _result(AdProviderScript.STATUS_UNAVAILABLE, String(decision.get("reason", "")))

	var request_id := _begin_request(AdProviderScript.FORMAT_REWARDED, placement)
	var provider_result: Dictionary = await _provider.show_rewarded(placement, context)
	if bool(provider_result.get("impression", false)):
		_pacing_state = AdPacingStateScript.record_rewarded_impression(
			_pacing_state,
			int(Time.get_unix_time_from_system())
		)
		_persist_pacing_state()
	return _finish_request(request_id, provider_result)


func request_interstitial(context: Dictionary = {}) -> Dictionary:
	if _active_request_id != 0:
		return _result(AdProviderScript.STATUS_UNAVAILABLE, "ad_request_in_progress")
	var eligibility_context := _interstitial_context(context)
	eligibility_context["provider_ready"] = (
		_initialized and _provider.is_ad_ready(AdProviderScript.FORMAT_INTERSTITIAL)
	)
	eligibility_context["consent_allows_ads"] = _consent_allows_ads
	eligibility_context["foreground"] = _foreground
	var decision := _policy.interstitial_decision(
		_pacing_state,
		eligibility_context,
		int(Time.get_unix_time_from_system())
	)
	if not bool(decision.get("eligible", false)):
		return _result(AdProviderScript.STATUS_UNAVAILABLE, String(decision.get("reason", "")))

	var request_id := _begin_request(AdProviderScript.FORMAT_INTERSTITIAL, &"")
	var provider_result: Dictionary = await _provider.show_interstitial(context)
	if bool(provider_result.get("impression", false)):
		_pacing_state = AdPacingStateScript.record_interstitial_impression(
			_pacing_state,
			int(Time.get_unix_time_from_system())
		)
		_persist_pacing_state()
	return _finish_request(request_id, provider_result)


func activate_interstitial_pacing(total_completed_levels: int) -> bool:
	if not _policy.is_interstitial_enabled():
		return false
	var previous := _pacing_state
	_pacing_state = AdPacingStateScript.activate(
		_pacing_state,
		total_completed_levels,
		_policy.get_config_version()
	)
	return true if previous == _pacing_state else _persist_pacing_state()


func record_campaign_completion() -> bool:
	if not _policy.is_interstitial_enabled():
		return false
	var previous := _pacing_state
	_pacing_state = AdPacingStateScript.record_campaign_completion(_pacing_state)
	return previous != _pacing_state and _persist_pacing_state()


func get_interstitial_decision(context: Dictionary = {}) -> Dictionary:
	var eligibility_context := _interstitial_context(context)
	eligibility_context["provider_ready"] = (
		_initialized and _provider.is_ad_ready(AdProviderScript.FORMAT_INTERSTITIAL)
	)
	eligibility_context["consent_allows_ads"] = _consent_allows_ads
	eligibility_context["foreground"] = _foreground
	return _policy.interstitial_decision(
		_pacing_state,
		eligibility_context,
		int(Time.get_unix_time_from_system())
	)


func _interstitial_context(context: Dictionary) -> Dictionary:
	var eligibility_context := context.duplicate(true)
	# Rollout assignment is derived locally from the opaque active save namespace. Gameplay callers
	# cannot choose or forge a bucket, and no account/install identifier is sent to the provider.
	eligibility_context["rollout_bucket"] = _stable_rollout_bucket()
	return eligibility_context


func _stable_rollout_bucket() -> int:
	var player_progress := _find_player_progress() as Node
	if player_progress == null or not player_progress.has_method("get_active_save_namespace"):
		return -1
	var save_namespace := player_progress.call("get_active_save_namespace") as Dictionary
	var kind := str(save_namespace.get("kind", ""))
	var opaque_id := str(
		save_namespace.get(
			"player_id" if kind == "player" else "installation_id",
			""
		)
	)
	if kind.is_empty() or opaque_id.is_empty():
		return -1
	var digest := ("%s:%s" % [kind, opaque_id]).sha256_text()
	return digest.substr(0, 8).hex_to_int() % 100


func is_busy() -> bool:
	return _active_request_id != 0


func is_privacy_options_required() -> bool:
	return _privacy_options_required


func get_diagnostics() -> Dictionary:
	return {
		"policy_valid": _policy.is_valid(),
		"policy_error": _policy.get_error(),
		"config_version": _policy.get_config_version(),
		"provider_enabled": _policy.is_provider_enabled(),
		"provider": _provider.get_provider_name(),
		"initialized": _initialized,
		"consent_allows_ads": _consent_allows_ads,
		"privacy_options_required": _privacy_options_required,
		"rollout_bucket": _stable_rollout_bucket(),
		"busy": is_busy(),
		"pacing_state": _pacing_state.duplicate(true),
		"provider_diagnostics": _provider.get_diagnostics(),
	}


func configure_for_testing(raw_policy: Dictionary, provider: RefCounted, pacing_state: Dictionary = {}) -> bool:
	if not _policy.configure(raw_policy):
		return false
	_provider = provider
	_pacing_state = AdPacingStateScript.sanitize(pacing_state)
	_initialized = false
	_consent_allows_ads = false
	_privacy_options_required = false
	_active_request_id = 0
	return true


func _load_bundled_policy() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {"ok": false, "error": "Bundled ad policy is missing."}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Bundled ad policy could not be opened."}
	var parsed = JSON.parse_string(file.get_as_text())
	if not _policy.configure(parsed):
		return {"ok": false, "error": _policy.get_error()}
	return {"ok": true}


func _create_provider() -> RefCounted:
	var provider_id := str(ProjectSettings.get_setting(PROVIDER_SETTING, PROVIDER_DISABLED)).to_lower()
	if provider_id == PROVIDER_MOCK:
		var mock_allowed := bool(ProjectSettings.get_setting(ALLOW_MOCK_SETTING, false))
		if OS.is_debug_build() and mock_allowed:
			return MockAdProviderScript.new()
		push_warning("Mock ads were requested without the debug-only allow switch; ads stay disabled.")
	elif provider_id == PROVIDER_ADMOB:
		if not bool(ProjectSettings.get_setting(NATIVE_INTEGRATION_SETTING, false)):
			push_warning("AdMob was requested without the compiled integration switch; ads stay disabled.")
			return AdProviderScript.new()
		var provider_script = load("res://scripts/ads/admob_provider.gd")
		if provider_script != null:
			return provider_script.new()
		push_warning("The AdMob adapter could not be loaded; ads stay disabled.")
	elif provider_id != PROVIDER_DISABLED:
		push_warning("Unsupported ad provider '%s'; ads stay disabled." % provider_id)
	return AdProviderScript.new()


func _load_pacing_state() -> void:
	var player_progress := _find_player_progress() as Node
	if player_progress != null and player_progress.has_method("get_ad_pacing_state"):
		_pacing_state = AdPacingStateScript.sanitize(
			player_progress.call("get_ad_pacing_state")
		)


func _persist_pacing_state() -> bool:
	var player_progress := _find_player_progress() as Node
	if player_progress == null or not player_progress.has_method("set_ad_pacing_state"):
		return false
	return bool(player_progress.call("set_ad_pacing_state", _pacing_state))


func _find_player_progress():
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	return (main_loop as SceneTree).root.get_node_or_null(^"PlayerProgress")


func _begin_request(format: StringName, placement: StringName) -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	_active_request_id = request_id
	_capture_audio_state()
	request_started.emit(request_id, format, placement)
	return request_id


func _finish_request(request_id: int, provider_result: Dictionary) -> Dictionary:
	var result := provider_result.duplicate(true)
	result["request_id"] = request_id
	_active_request_id = 0
	_restore_audio_state()
	request_finished.emit(request_id, result.duplicate(true))
	readiness_changed.emit()
	return result


func _capture_audio_state() -> void:
	_audio_snapshot.clear()
	for bus_index in range(AudioServer.bus_count):
		_audio_snapshot.append({
			"name": AudioServer.get_bus_name(bus_index),
			"mute": AudioServer.is_bus_mute(bus_index),
			"volume_db": AudioServer.get_bus_volume_db(bus_index),
		})


func _restore_audio_state() -> void:
	for bus_state in _audio_snapshot:
		var bus_index := AudioServer.get_bus_index(StringName(bus_state.get("name", "")))
		if bus_index < 0:
			continue
		AudioServer.set_bus_mute(bus_index, bool(bus_state.get("mute", false)))
		AudioServer.set_bus_volume_db(bus_index, float(bus_state.get("volume_db", 0.0)))
	_audio_snapshot.clear()


func _result(status: StringName, reason: String = "") -> Dictionary:
	return {"status": status, "reason": reason, "impression": false}
