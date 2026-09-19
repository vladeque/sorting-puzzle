extends SceneTree

## ADS-002 client-infrastructure verification. Run through:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ads/test_ad_infrastructure.gd

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const AdPolicyScript := preload("res://scripts/ads/ad_policy.gd")
const AdPacingStateScript := preload("res://scripts/ads/ad_pacing_state.gd")
const AdProviderScript := preload("res://scripts/ads/ad_provider.gd")
const MockAdProviderScript := preload("res://scripts/ads/mock_ad_provider.gd")
const AdServiceScript := preload("res://scripts/ads/ad_service.gd")
const AdMobProviderScript := preload("res://scripts/ads/admob_provider.gd")

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Ad infrastructure tests must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress := root.get_node_or_null(^"PlayerProgress")
	var autoload_service := root.get_node_or_null(^"AdService")
	_check(progress != null, "PlayerProgress is available for pacing persistence.")
	_check(autoload_service != null, "AdService is registered as a global owner.")
	if progress == null or autoload_service == null:
		_finish()
		return

	var bundled_diagnostics := autoload_service.call("get_diagnostics") as Dictionary
	_check(bool(bundled_diagnostics.get("policy_valid", false)), "Bundled ad policy is valid.")
	_check(
		bool(bundled_diagnostics.get("provider_enabled", false)),
		"Bundled policy enables the implemented rewarded-time placement."
	)
	_check(
		str(bundled_diagnostics.get("provider", "")) == "disabled",
		"The project defaults to the disabled provider."
	)
	var native_adapter := AdMobProviderScript.new()
	_check(
		native_adapter.get_provider_name() == "admob"
		and not bool(native_adapter.get_diagnostics().get("native_plugin_available", true)),
		"The vendored AdMob adapter parses but remains unavailable on desktop."
	)

	_test_policy_validation_and_rewarded_gates()
	_test_pacing_and_interstitial_gates()
	await _test_service_normalization_and_persistence(progress)
	await _test_rewarded_placement_inventory_is_isolated()
	_finish()


func _test_policy_validation_and_rewarded_gates() -> void:
	var policy := AdPolicyScript.new()
	var invalid := _enabled_policy()
	(invalid["interstitial"] as Dictionary)["maximum_ads_per_session"] = 0
	_check(not policy.configure(invalid), "Out-of-range pacing config fails closed.")
	_check(not policy.is_valid(), "Rejected config never leaves a valid policy behind.")

	_check(policy.configure(_enabled_policy()), "Approved policy shape validates.")
	var eligible := policy.rewarded_decision(
		AdPolicyScript.PLACEMENT_TIME_EXTENSION,
		true,
		true,
		true
	) as Dictionary
	_check(bool(eligible.get("eligible", false)), "Ready verified time extension is eligible.")
	var no_consent := policy.rewarded_decision(
		AdPolicyScript.PLACEMENT_TIME_EXTENSION,
		true,
		false,
		true
	) as Dictionary
	_check(
		no_consent.get("reason") == AdPolicyScript.REASON_CONSENT_REQUIRED,
		"Missing consent rejects a rewarded request with a bounded reason."
	)
	var no_server := policy.rewarded_decision(
		AdPolicyScript.PLACEMENT_LIFE,
		true,
		true,
		false
	) as Dictionary
	_check(
		no_server.get("reason") == AdPolicyScript.REASON_SERVER_UNAVAILABLE,
		"A server that cannot accept a claim prevents the ad from starting."
	)


func _test_pacing_and_interstitial_gates() -> void:
	var policy := AdPolicyScript.new()
	_check(policy.configure(_enabled_policy()), "Interstitial policy validates.")
	var state := AdPacingStateScript.create_default()
	var context := {
		"provider_ready": true,
		"consent_allows_ads": true,
		"foreground": true,
		"safe_transition": true,
		"rollout_bucket": 0,
	}
	var not_activated := policy.interstitial_decision(state, context, 1000) as Dictionary
	_check(
		not_activated.get("reason") == AdPolicyScript.REASON_NOT_ACTIVATED,
		"Historical completions cannot trigger before an activation baseline exists."
	)
	var invalid_bucket_context := context.duplicate(true)
	invalid_bucket_context["rollout_bucket"] = -1
	var invalid_bucket_state := AdPacingStateScript.activate(state, 0, "test-enabled-1")
	for _index in range(5):
		invalid_bucket_state = AdPacingStateScript.record_campaign_completion(invalid_bucket_state)
	_check(
		(policy.interstitial_decision(invalid_bucket_state, invalid_bucket_context, 1000) as Dictionary).get(
			"reason"
		) == AdPolicyScript.REASON_ROLLOUT,
		"A malformed rollout assignment fails closed."
	)

	state = AdPacingStateScript.activate(state, 37, "test-enabled-1")
	_check(
		int(state.get("activation_baseline_total_completions", -1)) == 37
		and int(state.get("eligible_completions_since_interstitial", -1)) == 0,
		"Activation stores the current total without backfilling old completions."
	)
	for _index in range(4):
		state = AdPacingStateScript.record_campaign_completion(state)
	var below_first := policy.interstitial_decision(state, context, 1000) as Dictionary
	_check(
		below_first.get("reason") == AdPolicyScript.REASON_COMPLETION_THRESHOLD,
		"The first interstitial waits for five new completions."
	)
	state = AdPacingStateScript.record_campaign_completion(state)
	_check(
		bool((policy.interstitial_decision(state, context, 1000) as Dictionary).get("eligible", false)),
		"The fifth new completion reaches the approved first-ad threshold."
	)

	state = AdPacingStateScript.record_interstitial_impression(state, 1000)
	_check(
		int(state.get("eligible_completions_since_interstitial", -1)) == 0,
		"Only an impression resets the completion counter."
	)
	for _index in range(3):
		state = AdPacingStateScript.record_campaign_completion(state)
	var cooldown := policy.interstitial_decision(state, context, 1500) as Dictionary
	_check(
		cooldown.get("reason") == AdPolicyScript.REASON_COOLDOWN,
		"The ten-minute cooldown suppresses an otherwise due ad."
	)
	_check(
		bool((policy.interstitial_decision(state, context, 1600) as Dictionary).get("eligible", false)),
		"Three completions are sufficient once the cooldown expires."
	)

	state = AdPacingStateScript.record_rewarded_impression(state, 1590)
	var suppressed := policy.interstitial_decision(state, context, 1600) as Dictionary
	_check(
		suppressed.get("reason") == AdPolicyScript.REASON_REWARDED_SUPPRESSION,
		"A recent rewarded impression suppresses an interstitial."
	)
	state["last_rewarded_impression_unix"] = 0
	state["session_interstitial_impressions"] = 2
	var capped := policy.interstitial_decision(state, context, 1600) as Dictionary
	_check(
		capped.get("reason") == AdPolicyScript.REASON_SESSION_CAP,
		"The approved two-impression session cap is enforced."
	)
	state["session_interstitial_impressions"] = 0
	context["rollout_bucket"] = 5
	var outside_rollout := policy.interstitial_decision(state, context, 1600) as Dictionary
	_check(
		outside_rollout.get("reason") == AdPolicyScript.REASON_ROLLOUT,
		"A bucket outside the initial five-percent rollout is ineligible."
	)


func _test_service_normalization_and_persistence(progress: Node) -> void:
	progress.call("reset_progress")
	var journal_before := (progress.get("_local_store").get_journal() as Array).size()
	var provider := MockAdProviderScript.new()
	var service := AdServiceScript.new()
	_check(
		service.configure_for_testing(_enabled_policy(), provider),
		"The service accepts an injected valid test policy and provider."
	)
	var initialization: Dictionary = await service.initialize()
	_check(
		initialization.get("status") == AdProviderScript.STATUS_READY,
		"The mock provider initializes only after the enabled policy requests it."
	)
	var loaded: Dictionary = await service.preload_rewarded(
		AdPolicyScript.PLACEMENT_TIME_EXTENSION,
		true
	)
	_check(loaded.get("status") == AdProviderScript.STATUS_READY, "A rewarded test ad preloads.")
	var master_bus_index := AudioServer.get_bus_index(&"Master")
	var original_master_mute := AudioServer.is_bus_mute(master_bus_index)
	var original_master_volume := AudioServer.get_bus_volume_db(master_bus_index)
	var during_request := {}
	service.request_started.connect(
		func(_request_id: int, _format: StringName, _placement: StringName) -> void:
			during_request["busy"] = service.is_busy()
			call_deferred("_capture_nested_rewarded_request", service, during_request)
			AudioServer.set_bus_mute(master_bus_index, not original_master_mute)
			AudioServer.set_bus_volume_db(master_bus_index, original_master_volume - 6.0),
		CONNECT_ONE_SHOT
	)
	provider.queue_outcome(AdProviderScript.FORMAT_REWARDED, {
		"status": AdProviderScript.STATUS_REWARDED,
		"reason": "",
		"impression": true,
		"delay_frames": 3,
	})
	var rewarded: Dictionary = await service.request_rewarded(
		AdPolicyScript.PLACEMENT_TIME_EXTENSION,
		{"attempt_id": "opaque-test-attempt"},
		true
	)
	_check(
		rewarded.get("status") == AdProviderScript.STATUS_REWARDED,
		"The service normalizes a provider-earned callback to REWARDED."
	)
	_check(
		not rewarded.has("seconds") and not rewarded.has("reward"),
		"The client service returns no client-authored gameplay reward."
	)
	var nested_result := during_request.get("nested_result", {}) as Dictionary
	_check(
		bool(during_request.get("busy", false))
		and nested_result.get("reason") == "ad_request_in_progress",
		"A second request is rejected while a full-screen request is active."
	)
	_check(
		AudioServer.is_bus_mute(master_bus_index) == original_master_mute
		and is_equal_approx(
			AudioServer.get_bus_volume_db(master_bus_index),
			original_master_volume
		),
		"Full-screen completion restores the pre-ad audio bus state."
	)
	var persisted := progress.call("get_ad_pacing_state") as Dictionary
	_check(
		int(persisted.get("last_rewarded_impression_unix", 0)) > 0,
		"A rewarded impression persists its interstitial-suppression timestamp."
	)
	var journal_after := (progress.get("_local_store").get_journal() as Array).size()
	_check(
		journal_after == journal_before,
		"Pacing persistence creates no authoritative backend journal operation."
	)

	progress.call("load_progress")
	var reloaded := progress.call("get_ad_pacing_state") as Dictionary
	_check(
		int(reloaded.get("last_rewarded_impression_unix", 0))
		== int(persisted.get("last_rewarded_impression_unix", -1)),
		"Ad pacing survives a local save reload."
	)

	var denied_calls_before := provider.get_calls().size()
	var denied: Dictionary = await service.request_rewarded(
		AdPolicyScript.PLACEMENT_LIFE,
		{},
		false
	)
	_check(
		denied.get("status") == AdProviderScript.STATUS_UNAVAILABLE
		and denied.get("reason") == String(AdPolicyScript.REASON_PROVIDER_NOT_READY),
		"An unloaded placement fails before presentation."
	)
	_check(
		provider.get_calls().size() == denied_calls_before,
		"An ineligible request never reaches provider presentation."
	)
	service.free()


func _capture_nested_rewarded_request(service: Node, result_holder: Dictionary) -> void:
	result_holder["nested_result"] = await service.request_rewarded(
		AdPolicyScript.PLACEMENT_TIME_EXTENSION,
		{},
		true
	)


func _test_rewarded_placement_inventory_is_isolated() -> void:
	var provider := MockAdProviderScript.new()
	await provider.initialize()
	await provider.update_consent()
	await provider.load_ad(AdProviderScript.FORMAT_REWARDED, AdPolicyScript.PLACEMENT_TIME_EXTENSION)
	await provider.load_ad(AdProviderScript.FORMAT_REWARDED, AdPolicyScript.PLACEMENT_LIFE)
	provider.queue_outcome(AdProviderScript.FORMAT_REWARDED, {
		"status": AdProviderScript.STATUS_DISMISSED,
		"reason": "test",
	})
	await provider.show_rewarded(AdPolicyScript.PLACEMENT_TIME_EXTENSION, {})
	_check(
		not provider.is_ad_ready(
			AdProviderScript.FORMAT_REWARDED,
			AdPolicyScript.PLACEMENT_TIME_EXTENSION
		)
			and provider.is_ad_ready(
				AdProviderScript.FORMAT_REWARDED,
				AdPolicyScript.PLACEMENT_LIFE
			),
		"Consuming one rewarded placement does not consume another placement's loaded ad."
	)


func _enabled_policy() -> Dictionary:
	return {
		"schema_version": 1,
		"config_version": "test-enabled-1",
		"provider_enabled": true,
		"rewarded": {
			"enabled": true,
			"time_extension_enabled": true,
			"life_enabled": true,
			"ability_enabled": true,
			"shelf_unlock_enabled": true,
		},
		"interstitial": {
			"enabled": true,
			"rollout_percent": 5,
			"completed_levels_per_ad": 3,
			"minimum_completed_levels_before_first_ad": 5,
			"minimum_seconds_between_ads": 600,
			"maximum_ads_per_session": 2,
			"suppress_after_rewarded_seconds": 300,
		},
	}


func _finish() -> void:
	if _failures.is_empty():
		print("ADS-002 ad infrastructure verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
