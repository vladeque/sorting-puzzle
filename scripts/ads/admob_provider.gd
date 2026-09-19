extends "res://scripts/ads/ad_provider.gd"
class_name AdMobProvider

signal _initialization_finished(result: Dictionary)
signal _consent_finished(result: Dictionary)
signal _privacy_options_finished(result: Dictionary)
signal _load_finished(format: StringName, placement: StringName, result: Dictionary)
signal _show_finished(format: StringName, placement: StringName, result: Dictionary)

const MobileAdsScript := preload("res://addons/admob/gdscript/src/api/MobileAds.gd")
const OnInitializationCompleteListenerScript := preload(
	"res://addons/admob/gdscript/src/api/listeners/OnInitializationCompleteListener.gd"
)
const AdRequestScript := preload("res://addons/admob/gdscript/src/api/core/AdRequest.gd")
const RewardedAdLoaderScript := preload("res://addons/admob/gdscript/src/api/RewardedAdLoader.gd")
const RewardedAdLoadCallbackScript := preload(
	"res://addons/admob/gdscript/src/api/listeners/RewardedAdLoadCallback.gd"
)
const InterstitialAdLoaderScript := preload(
	"res://addons/admob/gdscript/src/api/InterstitialAdLoader.gd"
)
const InterstitialAdLoadCallbackScript := preload(
	"res://addons/admob/gdscript/src/api/listeners/InterstitialAdLoadCallback.gd"
)
const FullScreenContentCallbackScript := preload(
	"res://addons/admob/gdscript/src/api/listeners/FullScreenContentCallback.gd"
)
const OnUserEarnedRewardListenerScript := preload(
	"res://addons/admob/gdscript/src/api/listeners/OnUserEarnedRewardListener.gd"
)
const ServerSideVerificationOptionsScript := preload(
	"res://addons/admob/gdscript/src/api/core/ServerSideVerificationOptions.gd"
)
const UserMessagingPlatformScript := preload(
	"res://addons/admob/gdscript/src/ump/api/UserMessagingPlatform.gd"
)
const ConsentInformationScript := preload(
	"res://addons/admob/gdscript/src/ump/api/ConsentInformation.gd"
)
const ConsentRequestParametersScript := preload(
	"res://addons/admob/gdscript/src/ump/core/ConsentRequestParameters.gd"
)

const ANDROID_REWARDED_TEST_ID := "ca-app-pub-3940256099942544/5224354917"
const ANDROID_INTERSTITIAL_TEST_ID := "ca-app-pub-3940256099942544/1033173712"
const IOS_REWARDED_TEST_ID := "ca-app-pub-3940256099942544/1712485313"
const IOS_INTERSTITIAL_TEST_ID := "ca-app-pub-3940256099942544/4411468910"

const ANDROID_REWARDED_SETTING := "application/config/admob_android_rewarded_ad_unit_id"
const ANDROID_REWARDED_LIFE_SETTING := "application/config/admob_android_rewarded_life_ad_unit_id"
const ANDROID_INTERSTITIAL_SETTING := "application/config/admob_android_interstitial_ad_unit_id"
const IOS_REWARDED_SETTING := "application/config/admob_ios_rewarded_ad_unit_id"
const IOS_REWARDED_LIFE_SETTING := "application/config/admob_ios_rewarded_life_ad_unit_id"
const IOS_INTERSTITIAL_SETTING := "application/config/admob_ios_interstitial_ad_unit_id"

var _initialized := false
var _consent_allows_ads := false
var _privacy_options_required := false
var _initialization_listener
var _consent_request
var _consent_form
var _rewarded_loaders := {}
var _interstitial_loader
var _rewarded_ads := {}
var _interstitial_ad
var _rewarded_load_pending := {}
var _interstitial_load_pending := false
var _show_pending := false
var _show_impression := false
var _reward_earned := false


func get_provider_name() -> String:
	return "admob"


func initialize() -> Dictionary:
	if not _is_native_supported():
		return _result(STATUS_UNAVAILABLE, "admob_native_plugin_unavailable")
	if _initialized:
		return _result(STATUS_READY)
	_initialization_listener = OnInitializationCompleteListenerScript.new()
	_initialization_listener.on_initialization_complete = func(_status) -> void:
		_initialized = true
		_initialization_finished.emit(_result(STATUS_READY))
	MobileAdsScript.initialize(_initialization_listener)
	return await _initialization_finished


func update_consent() -> Dictionary:
	if not _initialized:
		return _consent_result(STATUS_UNAVAILABLE, false, false, "provider_not_initialized")
	_consent_request = ConsentRequestParametersScript.new()
	_consent_request.tag_for_under_age_of_consent = false
	UserMessagingPlatformScript.consent_information.update(
		_consent_request,
		_on_consent_update_success,
		_on_consent_update_failure
	)
	return await _consent_finished


func show_privacy_options() -> Dictionary:
	if not _initialized or not _privacy_options_required:
		return _result(STATUS_UNAVAILABLE, "privacy_options_unavailable")
	UserMessagingPlatformScript.show_privacy_options_form(
		func(error) -> void:
			if error == null:
				_privacy_options_finished.emit(_result(STATUS_READY))
			else:
				_privacy_options_finished.emit(_error_result("privacy_options_failed", error))
	)
	return await _privacy_options_finished


func load_ad(format: StringName, placement: StringName = &"") -> Dictionary:
	if not _initialized or not _consent_allows_ads:
		return _result(STATUS_UNAVAILABLE, "admob_not_ready")
	if format not in [FORMAT_REWARDED, FORMAT_INTERSTITIAL]:
		return _result(STATUS_UNAVAILABLE, "unsupported_ad_format")
	var load_is_pending := (
		bool(_rewarded_load_pending.get(placement, false))
		if format == FORMAT_REWARDED
		else _interstitial_load_pending
	)
	if load_is_pending:
		return _result(STATUS_UNAVAILABLE, "ad_load_in_progress")
	var ad_unit_id := _get_ad_unit_id(format, placement)
	if ad_unit_id.is_empty():
		return _result(STATUS_UNAVAILABLE, "ad_unit_id_missing")

	var request = AdRequestScript.new()
	request.extras = {"npa": "1"}
	if format == FORMAT_REWARDED:
		if placement.is_empty():
			return _result(STATUS_UNAVAILABLE, "rewarded_placement_missing")
		_rewarded_load_pending[placement] = true
		var loader = RewardedAdLoaderScript.new()
		_rewarded_loaders[placement] = loader
		var callback = RewardedAdLoadCallbackScript.new()
		callback.on_ad_loaded = func(ad) -> void:
			_rewarded_ads[placement] = ad
			_complete_load(FORMAT_REWARDED, placement, _result(STATUS_READY))
		callback.on_ad_failed_to_load = func(error) -> void:
			_complete_load(FORMAT_REWARDED, placement, _error_result("rewarded_load_failed", error))
		loader.load(ad_unit_id, request, callback)
	else:
		_interstitial_load_pending = true
		_interstitial_loader = InterstitialAdLoaderScript.new()
		var callback = InterstitialAdLoadCallbackScript.new()
		callback.on_ad_loaded = func(ad) -> void:
			_interstitial_ad = ad
			_complete_load(FORMAT_INTERSTITIAL, &"", _result(STATUS_READY))
		callback.on_ad_failed_to_load = func(error) -> void:
			_complete_load(FORMAT_INTERSTITIAL, &"", _error_result("interstitial_load_failed", error))
		_interstitial_loader.load(ad_unit_id, request, callback)
	var completed = await _load_finished
	while completed[0] != format or completed[1] != placement:
		completed = await _load_finished
	return completed[2] as Dictionary


func is_ad_ready(format: StringName, placement: StringName = &"") -> bool:
	if not _initialized or not _consent_allows_ads:
		return false
	return _rewarded_ads.get(placement) != null if format == FORMAT_REWARDED else _interstitial_ad != null


func show_rewarded(placement: StringName, context: Dictionary) -> Dictionary:
	if _show_pending:
		return _result(STATUS_UNAVAILABLE, "ad_show_in_progress")
	if _rewarded_ads.get(placement) == null:
		return _result(STATUS_UNAVAILABLE, "rewarded_ad_not_loaded")
	_show_pending = true
	_show_impression = false
	_reward_earned = false
	var ad = _rewarded_ads.get(placement)
	_rewarded_ads.erase(placement)
	var ssv_custom_data := str(context.get("ssv_custom_data", ""))
	if not ssv_custom_data.is_empty():
		var verification_options = ServerSideVerificationOptionsScript.new()
		verification_options.custom_data = ssv_custom_data.left(128)
		verification_options.user_id = ""
		ad.set_server_side_verification_options(verification_options)
	ad.full_screen_content_callback = _full_screen_callback(FORMAT_REWARDED, placement, ad)
	var reward_listener = OnUserEarnedRewardListenerScript.new()
	reward_listener.on_user_earned_reward = func(_rewarded_item) -> void:
		_reward_earned = true
	ad.show(reward_listener)
	return await _await_show_result(FORMAT_REWARDED, placement)


func show_interstitial(_context: Dictionary) -> Dictionary:
	if _show_pending:
		return _result(STATUS_UNAVAILABLE, "ad_show_in_progress")
	if _interstitial_ad == null:
		return _result(STATUS_UNAVAILABLE, "interstitial_ad_not_loaded")
	_show_pending = true
	_show_impression = false
	_reward_earned = false
	var ad = _interstitial_ad
	_interstitial_ad = null
	ad.full_screen_content_callback = _full_screen_callback(FORMAT_INTERSTITIAL, &"", ad)
	ad.show()
	return await _await_show_result(FORMAT_INTERSTITIAL, &"")


func get_diagnostics() -> Dictionary:
	return {
		"provider": get_provider_name(),
		"initialized": _initialized,
		"consent_allows_ads": _consent_allows_ads,
		"privacy_options_required": _privacy_options_required,
		"rewarded_ready": not _rewarded_ads.is_empty(),
		"rewarded_ready_placements": _rewarded_ads.keys(),
		"interstitial_ready": is_ad_ready(FORMAT_INTERSTITIAL),
		"native_plugin_available": _is_native_supported(),
		"plugin_version": MobileAdsScript.get_version(),
	}


func _on_consent_update_success() -> void:
	_update_consent_flags()
	var status := UserMessagingPlatformScript.consent_information.get_consent_status()
	if (
		status == ConsentInformationScript.ConsentStatus.REQUIRED
		and UserMessagingPlatformScript.consent_information.get_is_consent_form_available()
	):
		UserMessagingPlatformScript.load_consent_form(
			_on_consent_form_loaded,
			_on_consent_form_load_failed
		)
		return
	_consent_finished.emit(_current_consent_result())


func _on_consent_form_loaded(form) -> void:
	_consent_form = form
	form.show(_on_consent_form_dismissed)


func _on_consent_form_load_failed(error) -> void:
	_consent_finished.emit(_consent_error_result("consent_form_load_failed", error))


func _on_consent_form_dismissed(error) -> void:
	_consent_form = null
	_update_consent_flags()
	if error == null:
		_consent_finished.emit(_current_consent_result())
	else:
		_consent_finished.emit(_consent_error_result("consent_form_failed", error))


func _on_consent_update_failure(error) -> void:
	_consent_allows_ads = false
	_update_privacy_options_requirement()
	_consent_finished.emit(_consent_error_result("consent_update_failed", error))


func _update_consent_flags() -> void:
	var status := UserMessagingPlatformScript.consent_information.get_consent_status()
	_consent_allows_ads = status in [
		ConsentInformationScript.ConsentStatus.NOT_REQUIRED,
		ConsentInformationScript.ConsentStatus.OBTAINED,
	]
	_update_privacy_options_requirement()


func _update_privacy_options_requirement() -> void:
	_privacy_options_required = (
		UserMessagingPlatformScript.consent_information.get_privacy_options_requirement_status()
		== ConsentInformationScript.PrivacyOptionsRequirementStatus.REQUIRED
	)


func _current_consent_result() -> Dictionary:
	return _consent_result(
		STATUS_READY if _consent_allows_ads else STATUS_UNAVAILABLE,
		_consent_allows_ads,
		_privacy_options_required,
		"" if _consent_allows_ads else "consent_required"
	)


func _consent_error_result(reason: String, error) -> Dictionary:
	var result := _consent_result(
		STATUS_FAILED,
		false,
		_privacy_options_required,
		reason
	)
	_append_safe_error(result, error)
	return result


func _consent_result(
	status: StringName,
	allows_ads: bool,
	privacy_options_required: bool,
	reason: String
) -> Dictionary:
	return {
		"status": status,
		"allows_ads": allows_ads,
		"privacy_options_required": privacy_options_required,
		"reason": reason,
	}


func _full_screen_callback(format: StringName, placement: StringName, ad) -> Variant:
	var callback = FullScreenContentCallbackScript.new()
	callback.on_ad_impression = func() -> void:
		_show_impression = true
	callback.on_ad_dismissed_full_screen_content = func() -> void:
		_complete_show(
			format,
			placement,
			ad,
			_result(
				STATUS_REWARDED if format == FORMAT_REWARDED and _reward_earned else STATUS_DISMISSED,
				"",
				_show_impression
			)
		)
	callback.on_ad_failed_to_show_full_screen_content = func(error) -> void:
		var result := _error_result("ad_show_failed", error)
		result["impression"] = _show_impression
		_complete_show(format, placement, ad, result)
	return callback


func _complete_load(format: StringName, placement: StringName, result: Dictionary) -> void:
	if format == FORMAT_REWARDED:
		_rewarded_load_pending[placement] = false
		_rewarded_loaders.erase(placement)
	else:
		_interstitial_load_pending = false
	_load_finished.emit(format, placement, result)


func _complete_show(format: StringName, placement: StringName, ad, result: Dictionary) -> void:
	if not _show_pending:
		return
	_show_pending = false
	if ad != null and ad.has_method("destroy"):
		ad.destroy()
	_show_finished.emit(format, placement, result)


func _await_show_result(format: StringName, placement: StringName) -> Dictionary:
	var completed = await _show_finished
	while completed[0] != format or completed[1] != placement:
		completed = await _show_finished
	return completed[2] as Dictionary


func _get_ad_unit_id(format: StringName, placement: StringName = &"") -> String:
	if OS.is_debug_build():
		if OS.get_name() == "iOS":
			return IOS_REWARDED_TEST_ID if format == FORMAT_REWARDED else IOS_INTERSTITIAL_TEST_ID
		return (
			ANDROID_REWARDED_TEST_ID
			if format == FORMAT_REWARDED
			else ANDROID_INTERSTITIAL_TEST_ID
		)
	var setting := ""
	if OS.get_name() == "Android":
		if format == FORMAT_REWARDED:
			setting = (
				ANDROID_REWARDED_LIFE_SETTING
				if placement == &"life"
				else ANDROID_REWARDED_SETTING
			)
		else:
			setting = ANDROID_INTERSTITIAL_SETTING
	elif OS.get_name() == "iOS":
		if format == FORMAT_REWARDED:
			setting = IOS_REWARDED_LIFE_SETTING if placement == &"life" else IOS_REWARDED_SETTING
		else:
			setting = IOS_INTERSTITIAL_SETTING
	return str(ProjectSettings.get_setting(setting, "")).strip_edges() if not setting.is_empty() else ""


func _is_native_supported() -> bool:
	if OS.get_name() not in ["Android", "iOS"]:
		return false
	return Engine.has_singleton("PoingGodotAdMob")


func _error_result(reason: String, error) -> Dictionary:
	var result := _result(STATUS_FAILED, reason)
	_append_safe_error(result, error)
	return result


func _append_safe_error(result: Dictionary, error) -> void:
	if error == null:
		return
	var code = error.get("code") if error.has_method("get") else null
	var domain = error.get("domain") if error.has_method("get") else null
	if code != null:
		result["error_code"] = int(code)
	if domain != null:
		result["error_domain"] = str(domain).left(128)
