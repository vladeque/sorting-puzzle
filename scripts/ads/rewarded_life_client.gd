extends Node
class_name RewardedLifeClient

## Authoritative rewarded-life boundary. The SDK reward callback never changes local lives; this
## client returns a life state only after the backend has settled the matching SSV intent.

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")

const PLACEMENT := &"life"
const REWARD_PROTOCOL_VERSION := "1.4"
const POLICY_VERSION := "rewarded-ads/1"
const PROVIDER_STATUS_REWARDED := &"rewarded"
const VERIFIED_LIVES := 1

var poll_attempt_limit := 8
var poll_delay_seconds := 0.5

var _transport
var _ad_service
var _busy := false
var _state_version := -1
var _intent_id := ""
var _awaiting_verification := false


func configure(transport, ad_service) -> void:
	_transport = transport
	_ad_service = ad_service


func can_offer() -> bool:
	var backend_ready: bool = (
		_transport != null
		and _transport.has_method("can_use_backend")
		and bool(_transport.call("can_use_backend"))
	)
	if not backend_ready or _busy:
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


func is_awaiting_verification() -> bool:
	return _awaiting_verification and not _intent_id.is_empty()


## Returns {ok=true, life_state=...} only after authoritative settlement. A pending SSV response
## retains the same intent for a later Verify Reward tap and never shows a second ad.
func claim() -> Dictionary:
	if _busy:
		return _error("ad_request_in_progress")
	_busy = true
	var result: Dictionary
	if is_awaiting_verification():
		result = await _poll_settlement()
	else:
		result = await _begin_and_show()
	_busy = false
	return result


func _begin_and_show() -> Dictionary:
	var state: Dictionary = await _transport.call("get_json", "/v1/player/state")
	if not bool(state.get("ok", false)):
		return state
	var state_data := state.get("data", {}) as Dictionary
	var life_state = state_data.get("life_state")
	_state_version = int((state.get("meta", {}) as Dictionary).get("state_version", -1))
	if _state_version < 0 or not _is_valid_life_state(life_state):
		return _error("life.state_unavailable")
	if int((life_state as Dictionary).get("current", 0)) >= int((life_state as Dictionary).get("maximum", 0)):
		return _error("life.already_full")

	var intent: Dictionary = await _post_intent()
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
		or int((effect as Dictionary).get("lives", 0)) != VERIFIED_LIVES
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
	return await _poll_settlement()


func _post_intent() -> Dictionary:
	for attempt in range(2):
		var response: Dictionary = await _transport.call(
			"post_json",
			"/v1/ad-rewards/intents",
			REWARD_PROTOCOL_VERSION,
			{"placement": String(PLACEMENT)},
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
		if attempt == 0 and str(error.get("code", "")) == "state.version_conflict" and current_version >= 0:
			_state_version = current_version
			continue
		return response
	return _error("state.version_conflict")


func _poll_settlement() -> Dictionary:
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
				var authoritative_life_state := (data.get("life_state") as Dictionary).duplicate(true)
				_intent_id = ""
				_awaiting_verification = false
				return {"ok": true, "life_state": authoritative_life_state}
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
	var status := str(data.get("status", ""))
	if (
		str(data.get("policy_version", "")) != POLICY_VERSION
		or str(data.get("intent_id", "")) != _intent_id
		or str(data.get("placement", "")) != String(PLACEMENT)
		or not ["pending", "settled", "rejected", "expired"].has(status)
		or not (effect is Dictionary)
		or str((effect as Dictionary).get("kind", "")) != String(PLACEMENT)
		or int((effect as Dictionary).get("lives", 0)) != VERIFIED_LIVES
	):
		return _error("ad_reward.status_response_malformed")
	if status == "settled" and not _is_valid_life_state(data.get("life_state")):
		return _error("ad_reward.status_response_malformed")
	return {"ok": true}


func _is_valid_life_state(value) -> bool:
	if not (value is Dictionary):
		return false
	var life_state := value as Dictionary
	var current := int(life_state.get("current", -1))
	var maximum := int(life_state.get("maximum", -1))
	var restore_interval := int(life_state.get("restore_interval_seconds", -1))
	return current >= 0 and maximum > 0 and current <= maximum and restore_interval > 0


func _update_state_version(response: Dictionary) -> void:
	var version := int((response.get("meta", {}) as Dictionary).get("state_version", -1))
	if version >= 0:
		_state_version = version


func _wait_for_poll() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.create_timer(maxf(poll_delay_seconds, 0.01)).timeout


func _error(code: String, pending: bool = false) -> Dictionary:
	return {"ok": false, "error": {"code": code}, "pending": pending}
