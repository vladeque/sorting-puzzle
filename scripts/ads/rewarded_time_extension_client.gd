extends Node
class_name RewardedTimeExtensionClient

## ADS-003's authoritative boundary. The SDK callback only starts status reconciliation; gameplay
## time is returned to Level after the backend has issued a run-bound authorization.

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")

const PLACEMENT := &"time_extension"
const RUN_PROTOCOL_VERSION := "1.0"
const COMPLETION_PROTOCOL_VERSION := "1.3"
const REWARD_PROTOCOL_VERSION := "1.4"
const POLICY_VERSION := "rewarded-ads/1"
const CLAIM_FORMAT_V1 := "sorting-puzzle-completion/1"
const CLAIM_FORMAT_V2 := "sorting-puzzle-completion/2"
const PROVIDER_STATUS_REWARDED := &"rewarded"
const VERIFIED_SECONDS := 60

var poll_attempt_limit := 8
var poll_delay_seconds := 0.5

var _transport
var _ad_service
var _busy := false
var _state_version := -1
var _run_id := ""
var _online_ticket_id := ""
var _intent_id := ""
var _awaiting_verification := false
var _authorization_id := ""


func configure(transport, ad_service) -> void:
	_transport = transport
	_ad_service = ad_service


func can_offer() -> bool:
	var backend_ready: bool = (
		_transport != null
		and _transport.has_method("can_use_backend")
		and bool(_transport.call("can_use_backend"))
	)
	if not backend_ready or _busy or not _authorization_id.is_empty():
		return false
	if is_awaiting_verification():
		return true
	return (
		_ad_service != null
		and _ad_service.has_method("is_rewarded_ready")
		and bool(_ad_service.call("is_rewarded_ready", PLACEMENT, true))
	)


func prepare() -> Dictionary:
	if _transport == null or not _transport.has_method("can_use_backend"):
		return _error("backend.unavailable")
	if not bool(_transport.call("can_use_backend")):
		return _error("backend.unavailable")
	if _ad_service == null or not _ad_service.has_method("preload_rewarded"):
		return _error("ads.unavailable")
	return await _ad_service.call("preload_rewarded", PLACEMENT, true)


## Returns {ok=true, seconds=60, authorization_id=...} only after authoritative settlement.
## A pending SSV response is retained so a later tap reconciles the same intent without showing a
## second ad. Dismissed/failed provider outcomes never consume the gameplay slot.
func claim(level_number: int) -> Dictionary:
	if _busy:
		return _error("ad_request_in_progress")
	if not _authorization_id.is_empty():
		return _error("ad_reward.already_authorized")
	_busy = true

	var result: Dictionary
	if _awaiting_verification and not _intent_id.is_empty():
		result = await _poll_authorization()
	else:
		result = await _begin_and_show(level_number)
	_busy = false
	return result


func has_active_run() -> bool:
	return not _run_id.is_empty() and not _online_ticket_id.is_empty()


func is_awaiting_verification() -> bool:
	return _awaiting_verification and not _intent_id.is_empty()


func settle_completed(stars: int) -> Dictionary:
	if not has_active_run():
		return _error("run.not_started")
	var protocol_version := REWARD_PROTOCOL_VERSION if not _authorization_id.is_empty() else COMPLETION_PROTOCOL_VERSION
	var claim := {
		"claim_format": CLAIM_FORMAT_V2 if not _authorization_id.is_empty() else CLAIM_FORMAT_V1,
		"outcome": "completed",
		"stars": maxi(stars, 0),
		# This compatibility run begins at the timeout boundary. Ability spends remain owned by the
		# existing local-first journal, so reporting them here would debit the same use twice.
		"abilities_used": {"hammer": 0, "shuffle": 0, "highlight": 0},
	}
	if not _authorization_id.is_empty():
		claim["rewarded_authorizations"] = [{
			"authorization_id": _authorization_id,
			"placement": String(PLACEMENT),
			"seconds": VERIFIED_SECONDS,
		}]
	var response: Dictionary = await _post_mutation(
		"/v1/runs/%s/complete" % _run_id,
		protocol_version,
		{
			"run_id": _run_id,
			"online_ticket_id": _online_ticket_id,
			"claim": claim,
		}
	)
	if not bool(response.get("ok", false)):
		return response
	var data := response.get("data", {}) as Dictionary
	if (
		str(data.get("run_id", "")) != _run_id
		or str(data.get("status", "")) != "accepted"
		or str(data.get("calculated_outcome", "")) != "completed"
		or int(data.get("calculated_stars", -1)) != maxi(stars, 0)
		or not (data.get("life_state") is Dictionary)
	):
		return _error("run.completion_response_malformed")
	var life_state := (data.get("life_state") as Dictionary).duplicate(true)
	_clear_run()
	return {"ok": true, "life_state": life_state}


func settle_terminal(outcome: String) -> Dictionary:
	if not has_active_run():
		return _error("run.not_started")
	var command := "fail" if outcome == "failed" else "abandon"
	var response: Dictionary = await _post_mutation(
		"/v1/runs/%s/%s" % [_run_id, command],
		RUN_PROTOCOL_VERSION,
		{"online_ticket_id": _online_ticket_id}
	)
	if not bool(response.get("ok", false)):
		return response
	var data := response.get("data", {}) as Dictionary
	var expected_status := "failed" if command == "fail" else "abandoned"
	if (
		str(data.get("run_id", "")) != _run_id
		or str(data.get("status", "")) != expected_status
		or not (data.get("life_state") is Dictionary)
	):
		return _error("run.terminal_response_malformed")
	var life_state := (data.get("life_state") as Dictionary).duplicate(true)
	_clear_run()
	return {"ok": true, "life_state": life_state}


func _begin_and_show(level_number: int) -> Dictionary:
	var started := await _ensure_started_run(level_number)
	if not bool(started.get("ok", false)):
		return started

	var intent: Dictionary = await _post_mutation(
		"/v1/ad-rewards/intents",
		REWARD_PROTOCOL_VERSION,
		{"placement": String(PLACEMENT), "run_id": _run_id}
	)
	if not bool(intent.get("ok", false)):
		return intent
	var intent_data := intent.get("data", {}) as Dictionary
	var effect = intent_data.get("effect")
	var custom_data := str(intent_data.get("custom_data", ""))
	if (
		str(intent_data.get("policy_version", "")) != POLICY_VERSION
		or not LocalSaveCodecScript.is_uuid(intent_data.get("intent_id"))
		or str(intent_data.get("placement", "")) != String(PLACEMENT)
		or str(intent_data.get("status", "")) != "pending"
		or custom_data.length() != 43
		or not (effect is Dictionary)
		or str((effect as Dictionary).get("kind", "")) != String(PLACEMENT)
		or int((effect as Dictionary).get("seconds", 0)) != VERIFIED_SECONDS
	):
		return _error("ad_reward.intent_response_malformed")
	_intent_id = str(intent_data.get("intent_id", ""))

	var provider_result: Dictionary = await _ad_service.call(
		"request_rewarded",
		PLACEMENT,
		{"ssv_custom_data": custom_data},
		true
	)
	if provider_result.get("status") != PROVIDER_STATUS_REWARDED:
		_intent_id = ""
		_awaiting_verification = false
		return _error("ads.%s" % str(provider_result.get("reason", "not_rewarded")))

	_awaiting_verification = true
	return await _poll_authorization()


func _ensure_started_run(level_number: int) -> Dictionary:
	if has_active_run():
		return {"ok": true}
	var state: Dictionary = await _transport.call("get_json", "/v1/player/state")
	if not bool(state.get("ok", false)):
		return state
	var state_data := state.get("data", {}) as Dictionary
	var campaign = state_data.get("campaign")
	_state_version = int((state.get("meta", {}) as Dictionary).get("state_version", -1))
	if (
		_state_version < 0
		or not (campaign is Dictionary)
		or int((campaign as Dictionary).get("current_level", 0)) != level_number
	):
		return _error("run.campaign_state_unavailable")

	var start: Dictionary = await _post_mutation(
		"/v1/runs/start",
		RUN_PROTOCOL_VERSION,
		{"campaign_level": level_number}
	)
	if not bool(start.get("ok", false)):
		return start
	var start_data := start.get("data", {}) as Dictionary
	if (
		not LocalSaveCodecScript.is_uuid(start_data.get("run_id"))
		or not LocalSaveCodecScript.is_uuid(start_data.get("online_ticket_id"))
		or int(start_data.get("campaign_level", 0)) != level_number
	):
		return _error("run.start_response_malformed")
	_run_id = str(start_data.get("run_id", ""))
	_online_ticket_id = str(start_data.get("online_ticket_id", ""))

	var first_action: Dictionary = await _post_mutation(
		"/v1/runs/%s/first-action" % _run_id,
		RUN_PROTOCOL_VERSION,
		{"online_ticket_id": _online_ticket_id}
	)
	if not bool(first_action.get("ok", false)):
		_clear_run()
		return first_action
	var action_data := first_action.get("data", {}) as Dictionary
	if str(action_data.get("run_id", "")) != _run_id or str(action_data.get("status", "")) != "started":
		_clear_run()
		return _error("run.first_action_response_malformed")
	return {"ok": true}


func _poll_authorization() -> Dictionary:
	for attempt in range(maxi(poll_attempt_limit, 1)):
		var response: Dictionary = await _transport.call(
			"post_json",
			"/v1/ad-rewards/intents/%s/status" % _intent_id,
			REWARD_PROTOCOL_VERSION,
			{},
			-1,
			"",
			true
		)
		if not bool(response.get("ok", false)):
			return response
		_update_state_version(response)
		var data := response.get("data", {}) as Dictionary
		var validation := _validate_status_data(data)
		if not bool(validation.get("ok", false)):
			return validation
		match str(data.get("status", "")):
			"settled":
				_authorization_id = str(data.get("authorization_id", ""))
				_awaiting_verification = false
				return {
					"ok": true,
					"seconds": VERIFIED_SECONDS,
					"authorization_id": _authorization_id,
				}
			"rejected", "expired":
				_intent_id = ""
				_awaiting_verification = false
				return _error("ad_reward.%s" % str(data.get("status", "")))
			"pending":
				if attempt + 1 < maxi(poll_attempt_limit, 1):
					await _wait_for_poll()
	return _error("ad_reward.verification_pending", true)


func _validate_status_data(data: Dictionary) -> Dictionary:
	var effect = data.get("effect")
	if (
		str(data.get("policy_version", "")) != POLICY_VERSION
		or str(data.get("intent_id", "")) != _intent_id
		or str(data.get("placement", "")) != String(PLACEMENT)
		or not ["pending", "settled", "rejected", "expired"].has(str(data.get("status", "")))
		or not (effect is Dictionary)
		or str((effect as Dictionary).get("kind", "")) != String(PLACEMENT)
		or int((effect as Dictionary).get("seconds", 0)) != VERIFIED_SECONDS
	):
		return _error("ad_reward.status_response_malformed")
	if str(data.get("status", "")) == "settled" and not LocalSaveCodecScript.is_uuid(data.get("authorization_id")):
		return _error("ad_reward.status_response_malformed")
	return {"ok": true}


func _post_mutation(path: String, protocol_version: String, data: Dictionary) -> Dictionary:
	if _state_version < 0:
		return _error("state.version_unavailable")
	for attempt in range(2):
		var response: Dictionary = await _transport.call(
			"post_json",
			path,
			protocol_version,
			data,
			_state_version,
			LocalSaveCodecScript.create_uuid(),
			true
		)
		if bool(response.get("ok", false)):
			_update_state_version(response)
			return response
		var error := response.get("error", {}) as Dictionary
		var recovery := error.get("recovery", {}) as Dictionary
		var current_version := int(recovery.get("current_state_version", -1))
		if (
			attempt == 0
			and str(error.get("code", "")) == "state.version_conflict"
			and current_version >= 0
		):
			_state_version = current_version
			continue
		return response
	return _error("state.version_conflict")


func _update_state_version(response: Dictionary) -> void:
	var meta := response.get("meta", {}) as Dictionary
	var version := int(meta.get("state_version", -1))
	if version >= 0:
		_state_version = version


func _wait_for_poll() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.create_timer(maxf(poll_delay_seconds, 0.01)).timeout


func _clear_run() -> void:
	_state_version = -1
	_run_id = ""
	_online_ticket_id = ""
	_intent_id = ""
	_awaiting_verification = false
	_authorization_id = ""


func _error(code: String, pending: bool = false) -> Dictionary:
	return {"ok": false, "error": {"code": code}, "pending": pending}
