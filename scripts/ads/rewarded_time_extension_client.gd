extends Node
class_name RewardedTimeExtensionClient

## Authoritative owner for run-bound rewarded placements. ADS-003 uses time extension, ADS-005 adds
## one immediate ability use, and ADS-006 adds a selected locked-shelf unlock; they share this run so
## its life reservation and completion claim can contain the exact authorization set once.

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")

const PLACEMENT_TIME_EXTENSION := &"time_extension"
const PLACEMENT_ABILITY := &"ability"
const PLACEMENT_SHELF_UNLOCK := &"shelf_unlock"
const SUPPORTED_REWARDED_ABILITIES := [&"hammer", &"shuffle", &"highlight"]
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
var _pending_placement := StringName()
var _pending_ability_id := StringName()
var _pending_shelf_id := 0
var _time_authorization_id := ""
var _ability_authorization_id := ""
var _authorized_ability_id := StringName()
## Each configured locked shelf keeps its own rewarded route, so authorizations are kept per shelf
## id rather than as one per-attempt slot. Presence of an id is also what rejects a second claim for
## a shelf this attempt already unlocked.
var _shelf_authorization_ids: Dictionary = {}


func configure(transport, ad_service) -> void:
	_transport = transport
	_ad_service = ad_service


func can_offer() -> bool:
	return can_offer_time_extension()


func can_offer_time_extension() -> bool:
	var backend_ready: bool = (
		_transport != null
		and _transport.has_method("can_use_backend")
		and bool(_transport.call("can_use_backend"))
	)
	if not backend_ready or _busy or not _time_authorization_id.is_empty():
		return false
	if is_awaiting_verification():
		return _pending_placement == PLACEMENT_TIME_EXTENSION
	return (
		_ad_service != null
		and _ad_service.has_method("is_rewarded_ready")
		and bool(_ad_service.call("is_rewarded_ready", PLACEMENT_TIME_EXTENSION, true))
	)


func prepare() -> Dictionary:
	return await prepare_placement(PLACEMENT_TIME_EXTENSION)


func prepare_ability() -> Dictionary:
	return await prepare_placement(PLACEMENT_ABILITY)


func prepare_placement(placement: StringName) -> Dictionary:
	if _transport == null or not _transport.has_method("can_use_backend"):
		return _error("backend.unavailable")
	if not bool(_transport.call("can_use_backend")):
		return _error("backend.unavailable")
	if _ad_service == null or not _ad_service.has_method("preload_rewarded"):
		return _error("ads.unavailable")
	return await _ad_service.call("preload_rewarded", placement, true)


## Returns {ok=true, seconds=60, authorization_id=...} only after authoritative settlement.
## A pending SSV response is retained so a later tap reconciles the same intent without showing a
## second ad. Dismissed/failed provider outcomes never consume the gameplay slot.
func claim(level_number: int) -> Dictionary:
	if _busy:
		return _error("ad_request_in_progress")
	if not _time_authorization_id.is_empty():
		return _error("ad_reward.already_authorized")
	if is_awaiting_verification() and _pending_placement != PLACEMENT_TIME_EXTENSION:
		return _error("ad_reward.other_verification_pending")
	_busy = true

	var result: Dictionary
	if _awaiting_verification and not _intent_id.is_empty():
		result = await _poll_authorization()
	else:
		result = await _begin_and_show(level_number, PLACEMENT_TIME_EXTENSION)
	_busy = false
	return result


func can_offer_ability(ability_id: StringName) -> bool:
	if ability_id not in SUPPORTED_REWARDED_ABILITIES or not _ability_authorization_id.is_empty():
		return false
	var backend_ready: bool = (
		_transport != null
		and _transport.has_method("can_use_backend")
		and bool(_transport.call("can_use_backend"))
	)
	if not backend_ready or _busy:
		return false
	if is_awaiting_verification():
		return _pending_placement == PLACEMENT_ABILITY and _pending_ability_id == ability_id
	return (
		_ad_service != null
		and _ad_service.has_method("is_rewarded_ready")
		and bool(_ad_service.call("is_rewarded_ready", PLACEMENT_ABILITY, true))
	)


func claim_ability(level_number: int, ability_id: StringName) -> Dictionary:
	if ability_id not in SUPPORTED_REWARDED_ABILITIES:
		return _error("ad_reward.ability_unsupported")
	if _busy:
		return _error("ad_request_in_progress")
	if not _ability_authorization_id.is_empty():
		return _error("ad_reward.ability_already_authorized")
	if is_awaiting_verification() and (
		_pending_placement != PLACEMENT_ABILITY or _pending_ability_id != ability_id
	):
		return _error("ad_reward.other_verification_pending")
	_busy = true
	var result: Dictionary
	if is_awaiting_verification():
		result = await _poll_authorization()
	else:
		result = await _begin_and_show(level_number, PLACEMENT_ABILITY, ability_id)
	_busy = false
	return result


func is_awaiting_ability_verification(ability_id: StringName) -> bool:
	return (
		is_awaiting_verification()
		and _pending_placement == PLACEMENT_ABILITY
		and _pending_ability_id == ability_id
	)


func prepare_shelf_unlock() -> Dictionary:
	return await prepare_placement(PLACEMENT_SHELF_UNLOCK)


## `shelf_id` is the shelf's position in the immutable level definition (1-based), not a node
## instance or screen position, so the authorization stays bound across relayouts and node churn.
func can_offer_shelf_unlock(shelf_id: int) -> bool:
	if shelf_id <= 0 or is_shelf_unlock_authorized(shelf_id):
		return false
	var backend_ready: bool = (
		_transport != null
		and _transport.has_method("can_use_backend")
		and bool(_transport.call("can_use_backend"))
	)
	if not backend_ready or _busy:
		return false
	if is_awaiting_verification():
		return _pending_placement == PLACEMENT_SHELF_UNLOCK and _pending_shelf_id == shelf_id
	return (
		_ad_service != null
		and _ad_service.has_method("is_rewarded_ready")
		and bool(_ad_service.call("is_rewarded_ready", PLACEMENT_SHELF_UNLOCK, true))
	)


## Returns {ok=true, shelf_id=..., authorization_id=...} only after authoritative settlement. An
## unsettled intent is retained so a later tap reconciles the same shelf's intent instead of showing
## a second ad, and a claim for a different shelf while one is pending is refused outright.
func claim_shelf_unlock(level_number: int, shelf_id: int) -> Dictionary:
	if shelf_id <= 0:
		return _error("ad_reward.shelf_unsupported")
	if _busy:
		return _error("ad_request_in_progress")
	if is_shelf_unlock_authorized(shelf_id):
		return _error("ad_reward.shelf_already_authorized")
	if is_awaiting_verification() and (
		_pending_placement != PLACEMENT_SHELF_UNLOCK or _pending_shelf_id != shelf_id
	):
		return _error("ad_reward.other_verification_pending")
	_busy = true
	var result: Dictionary
	if is_awaiting_verification():
		result = await _poll_authorization()
	else:
		result = await _begin_and_show(
			level_number,
			PLACEMENT_SHELF_UNLOCK,
			StringName(),
			shelf_id
		)
	_busy = false
	return result


func is_awaiting_shelf_unlock_verification(shelf_id: int) -> bool:
	return (
		is_awaiting_verification()
		and _pending_placement == PLACEMENT_SHELF_UNLOCK
		and _pending_shelf_id == shelf_id
	)


func is_shelf_unlock_authorized(shelf_id: int) -> bool:
	return _shelf_authorization_ids.has(shelf_id)


func has_active_run() -> bool:
	return not _run_id.is_empty() and not _online_ticket_id.is_empty()


func is_awaiting_verification() -> bool:
	return _awaiting_verification and not _intent_id.is_empty()


func settle_completed(stars: int) -> Dictionary:
	if not has_active_run():
		return _error("run.not_started")
	var has_reward_authorizations := (
		not _time_authorization_id.is_empty()
		or not _ability_authorization_id.is_empty()
		or not _shelf_authorization_ids.is_empty()
	)
	var protocol_version := REWARD_PROTOCOL_VERSION if has_reward_authorizations else COMPLETION_PROTOCOL_VERSION
	var abilities_used := {"hammer": 0, "shuffle": 0, "highlight": 0}
	if not _ability_authorization_id.is_empty():
		abilities_used[String(_authorized_ability_id)] = 1
	var claim := {
		"claim_format": CLAIM_FORMAT_V2 if has_reward_authorizations else CLAIM_FORMAT_V1,
		"outcome": "completed",
		"stars": maxi(stars, 0),
		# Only the rewarded use belongs to this online run. Inventory and coin-funded ability uses
		# remain owned by the existing local-first journal and must not be reported a second time.
		"abilities_used": abilities_used,
	}
	if has_reward_authorizations:
		var authorizations: Array[Dictionary] = []
		if not _time_authorization_id.is_empty():
			authorizations.append({
				"authorization_id": _time_authorization_id,
				"placement": String(PLACEMENT_TIME_EXTENSION),
				"seconds": VERIFIED_SECONDS,
			})
		if not _ability_authorization_id.is_empty():
			authorizations.append({
				"authorization_id": _ability_authorization_id,
				"placement": String(PLACEMENT_ABILITY),
				"ability_id": String(_authorized_ability_id),
			})
		# Reported in ascending shelf order so the proof carries a deterministic, replayable set of
		# rewarded shelf unlocks rather than dictionary insertion order.
		var unlocked_shelf_ids := _shelf_authorization_ids.keys()
		unlocked_shelf_ids.sort()
		for shelf_id in unlocked_shelf_ids:
			authorizations.append({
				"authorization_id": str(_shelf_authorization_ids[shelf_id]),
				"placement": String(PLACEMENT_SHELF_UNLOCK),
				"shelf_id": int(shelf_id),
			})
		claim["rewarded_authorizations"] = authorizations
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


func _begin_and_show(
	level_number: int,
	placement: StringName,
	ability_id: StringName = StringName(),
	shelf_id: int = 0
) -> Dictionary:
	var started := await _ensure_started_run(level_number)
	if not bool(started.get("ok", false)):
		return started

	var binding := {"placement": String(placement), "run_id": _run_id}
	if placement == PLACEMENT_ABILITY:
		binding["ability_id"] = String(ability_id)
	elif placement == PLACEMENT_SHELF_UNLOCK:
		binding["shelf_id"] = shelf_id
	var intent: Dictionary = await _post_mutation(
		"/v1/ad-rewards/intents",
		REWARD_PROTOCOL_VERSION,
		binding
	)
	if not bool(intent.get("ok", false)):
		return intent
	var intent_data := intent.get("data", {}) as Dictionary
	var effect = intent_data.get("effect")
	var custom_data := str(intent_data.get("custom_data", ""))
	if (
		str(intent_data.get("policy_version", "")) != POLICY_VERSION
		or not LocalSaveCodecScript.is_uuid(intent_data.get("intent_id"))
		or str(intent_data.get("placement", "")) != String(placement)
		or str(intent_data.get("status", "")) != "pending"
		or custom_data.length() != 43
		or not (effect is Dictionary)
		or not _effect_matches(effect as Dictionary, placement, ability_id, shelf_id)
	):
		return _error("ad_reward.intent_response_malformed")
	_intent_id = str(intent_data.get("intent_id", ""))
	_pending_placement = placement
	_pending_ability_id = ability_id
	_pending_shelf_id = shelf_id

	var provider_result: Dictionary = await _ad_service.call(
		"request_rewarded",
		placement,
		{"ssv_custom_data": custom_data},
		true
	)
	if provider_result.get("status") != PROVIDER_STATUS_REWARDED:
		_clear_pending_intent()
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
				var authorization_id := str(data.get("authorization_id", ""))
				var placement := _pending_placement
				var ability_id := _pending_ability_id
				var shelf_id := _pending_shelf_id
				match placement:
					PLACEMENT_TIME_EXTENSION:
						_time_authorization_id = authorization_id
					PLACEMENT_SHELF_UNLOCK:
						_shelf_authorization_ids[shelf_id] = authorization_id
					_:
						_ability_authorization_id = authorization_id
						_authorized_ability_id = ability_id
				_clear_pending_intent()
				if placement == PLACEMENT_TIME_EXTENSION:
					return {
						"ok": true,
						"seconds": VERIFIED_SECONDS,
						"authorization_id": authorization_id,
					}
				if placement == PLACEMENT_SHELF_UNLOCK:
					return {
						"ok": true,
						"shelf_id": shelf_id,
						"authorization_id": authorization_id,
					}
				return {
					"ok": true,
					"ability_id": ability_id,
					"uses": 1,
					"authorization_id": authorization_id,
				}
			"rejected", "expired":
				_clear_pending_intent()
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
		or str(data.get("placement", "")) != String(_pending_placement)
		or not ["pending", "settled", "rejected", "expired"].has(str(data.get("status", "")))
		or not (effect is Dictionary)
		or not _effect_matches(
			effect as Dictionary,
			_pending_placement,
			_pending_ability_id,
			_pending_shelf_id
		)
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
	_clear_pending_intent()
	_time_authorization_id = ""
	_ability_authorization_id = ""
	_authorized_ability_id = StringName()
	_shelf_authorization_ids.clear()


func _clear_pending_intent() -> void:
	_intent_id = ""
	_awaiting_verification = false
	_pending_placement = StringName()
	_pending_ability_id = StringName()
	_pending_shelf_id = 0


func _effect_matches(
	effect: Dictionary,
	placement: StringName,
	ability_id: StringName,
	shelf_id: int = 0
) -> bool:
	if str(effect.get("kind", "")) != String(placement):
		return false
	if placement == PLACEMENT_TIME_EXTENSION:
		return int(effect.get("seconds", 0)) == VERIFIED_SECONDS
	if placement == PLACEMENT_ABILITY:
		return (
			str(effect.get("ability_id", "")) == String(ability_id)
			and int(effect.get("uses", 0)) == 1
		)
	if placement == PLACEMENT_SHELF_UNLOCK:
		# A settled authorization for another shelf is a wrong-shelf grant, not a usable one.
		return shelf_id > 0 and int(effect.get("shelf_id", 0)) == shelf_id
	return false


func _error(code: String, pending: bool = false) -> Dictionary:
	return {"ok": false, "error": {"code": code}, "pending": pending}
