extends SceneTree

## ADS-006 authorization verification. Run through:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ads/test_rewarded_shelf_unlock.gd

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const ClientScript := preload("res://scripts/ads/rewarded_time_extension_client.gd")
const RUN_ID := "00000000-0000-4000-8000-000000000601"
const TICKET_ID := "00000000-0000-4000-8000-000000000602"
const SHELF_INTENT_ID := "00000000-0000-4000-8000-000000000603"
const SHELF_AUTH_ID := "00000000-0000-4000-8000-000000000604"
const OTHER_SHELF_INTENT_ID := "00000000-0000-4000-8000-000000000605"
const OTHER_SHELF_AUTH_ID := "00000000-0000-4000-8000-000000000606"
const ABILITY_INTENT_ID := "00000000-0000-4000-8000-000000000607"
const ABILITY_AUTH_ID := "00000000-0000-4000-8000-000000000608"

var _failures: Array[String] = []


class FakeTransport extends Node:
	var responses: Array[Dictionary] = []
	var calls: Array[Dictionary] = []

	func can_use_backend() -> bool:
		return true

	func get_json(path: String) -> Dictionary:
		calls.append({"method": "GET", "path": path})
		return {
			"ok": true,
			"meta": {"state_version": 10},
			"data": {"campaign": {"current_level": 3}},
		}

	func post_json(
		path: String,
		protocol_version: String,
		data: Dictionary,
		expected_state_version: int = -1,
		idempotency_key: String = "",
		retry_transient: bool = true
	) -> Dictionary:
		calls.append({
			"method": "POST",
			"path": path,
			"protocol_version": protocol_version,
			"data": data.duplicate(true),
			"expected_state_version": expected_state_version,
			"idempotency_key": idempotency_key,
			"retry_transient": retry_transient,
		})
		return responses.pop_front()


class FakeAdService extends Node:
	var contexts: Array[Dictionary] = []

	func is_rewarded_ready(_placement: StringName, _server_can_accept_claim: bool) -> bool:
		return true

	func preload_rewarded(_placement: StringName, _server_can_accept_claim: bool) -> Dictionary:
		return {"status": &"ready"}

	func request_rewarded(
		placement: StringName,
		context: Dictionary,
		_server_can_accept_claim: bool
	) -> Dictionary:
		contexts.append({"placement": placement, "context": context.duplicate(true)})
		return {"status": &"rewarded", "impression": true}


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Rewarded shelf-unlock verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_exact_shelf_binding_and_completion_report()
	await _test_wrong_shelf_duplicate_and_pending_claims()
	if _failures.is_empty():
		print("Rewarded shelf-unlock verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## Each configured locked shelf keeps its own rewarded route, so two shelves can both settle on one
## run and the completion claim must carry both authorizations plus any other placement's.
func _test_exact_shelf_binding_and_completion_report() -> void:
	var transport := FakeTransport.new()
	var ads := FakeAdService.new()
	root.add_child(transport)
	root.add_child(ads)
	var client := ClientScript.new()
	root.add_child(client)
	client.configure(transport, ads)
	client.poll_attempt_limit = 1
	transport.responses = [
		_success(11, {"run_id": RUN_ID, "online_ticket_id": TICKET_ID, "campaign_level": 3}),
		_success(12, {"run_id": RUN_ID, "status": "started"}),
		_success(13, _intent(SHELF_INTENT_ID, "shelf_unlock", _shelf_effect(3))),
		_success(14, _status(SHELF_INTENT_ID, "shelf_unlock", _shelf_effect(3), SHELF_AUTH_ID)),
		_success(15, _intent(ABILITY_INTENT_ID, "ability", {"kind": "ability", "ability_id": "hammer", "uses": 1})),
		_success(16, _status(ABILITY_INTENT_ID, "ability", {"kind": "ability", "ability_id": "hammer", "uses": 1}, ABILITY_AUTH_ID)),
		_success(17, _intent(OTHER_SHELF_INTENT_ID, "shelf_unlock", _shelf_effect(9))),
		_success(18, _status(OTHER_SHELF_INTENT_ID, "shelf_unlock", _shelf_effect(9), OTHER_SHELF_AUTH_ID)),
		_success(19, {
			"run_id": RUN_ID,
			"status": "accepted",
			"calculated_outcome": "completed",
			"calculated_stars": 3,
			"life_state": {"current": 5, "maximum": 5, "restore_interval_seconds": 3600},
		}),
	]

	var unlock: Dictionary = await client.claim_shelf_unlock(3, 3)
	_check(
		bool(unlock.get("ok", false)) and int(unlock.get("shelf_id", 0)) == 3,
		"A settled matching shelf authorization returns the exact bound shelf."
	)
	var intent_call := transport.calls[3] as Dictionary
	_check(
		(intent_call.get("data", {}) as Dictionary) == {
			"placement": "shelf_unlock",
			"run_id": RUN_ID,
			"shelf_id": 3,
		},
		"The shelf intent binds the selected configured shelf and current run exactly."
	)
	_check(
		StringName((ads.contexts[0] as Dictionary).get("placement", &"")) == &"shelf_unlock"
			and str(((ads.contexts[0] as Dictionary).get("context", {}) as Dictionary).get("ssv_custom_data", "")).length() == 43,
		"Only the backend nonce reaches the shelf-unlock placement."
	)
	_check(
		client.is_shelf_unlock_authorized(3) and not client.is_shelf_unlock_authorized(9),
		"Only the settled shelf is recorded as authorized."
	)

	var ability: Dictionary = await client.claim_ability(3, &"hammer")
	var second_unlock: Dictionary = await client.claim_shelf_unlock(3, 9)
	_check(
		bool(ability.get("ok", false)) and bool(second_unlock.get("ok", false)),
		"A second locked shelf keeps its own rewarded route on the same run."
	)
	var start_calls := transport.calls.filter(func(call):
		return str((call as Dictionary).get("path", "")) == "/v1/runs/start"
	)
	_check(start_calls.size() == 1, "Every rewarded placement shares one run and life reservation.")

	var completion: Dictionary = await client.settle_completed(3)
	_check(bool(completion.get("ok", false)), "The shared rewarded run completes successfully.")
	var completion_data := (transport.calls.back() as Dictionary).get("data", {}) as Dictionary
	var claim := completion_data.get("claim", {}) as Dictionary
	var authorizations := claim.get("rewarded_authorizations", []) as Array
	_check(
		str(claim.get("claim_format", "")) == "sorting-puzzle-completion/2"
			and authorizations.size() == 3,
		"Completion reports the exact issued authorization set."
	)
	_check(
		authorizations.has({
			"authorization_id": SHELF_AUTH_ID,
			"placement": "shelf_unlock",
			"shelf_id": 3,
		}) and authorizations.has({
			"authorization_id": OTHER_SHELF_AUTH_ID,
			"placement": "shelf_unlock",
			"shelf_id": 9,
		}),
		"Both rewarded shelf unlocks are reported with their own shelf id and authorization."
	)
	_check(
		int((claim.get("abilities_used", {}) as Dictionary).get("hammer", 0)) == 1,
		"A rewarded shelf unlock does not change the reported ability usage."
	)
	_free_nodes([client, transport, ads])
	await process_frame


func _test_wrong_shelf_duplicate_and_pending_claims() -> void:
	var transport := FakeTransport.new()
	var ads := FakeAdService.new()
	root.add_child(transport)
	root.add_child(ads)
	var client := ClientScript.new()
	root.add_child(client)
	client.configure(transport, ads)
	client.poll_attempt_limit = 1

	var invalid: Dictionary = await client.claim_shelf_unlock(3, 0)
	_check(
		str((invalid.get("error", {}) as Dictionary).get("code", "")) == "ad_reward.shelf_unsupported"
			and transport.calls.is_empty(),
		"A shelf without a configured id is rejected before any transport call."
	)

	# A settled authorization naming a different shelf is a wrong-shelf grant, not a usable one.
	transport.responses = [
		_success(11, {"run_id": RUN_ID, "online_ticket_id": TICKET_ID, "campaign_level": 3}),
		_success(12, {"run_id": RUN_ID, "status": "started"}),
		_success(13, _intent(SHELF_INTENT_ID, "shelf_unlock", _shelf_effect(7))),
	]
	var mismatched: Dictionary = await client.claim_shelf_unlock(3, 4)
	_check(
		str((mismatched.get("error", {}) as Dictionary).get("code", "")) == "ad_reward.intent_response_malformed"
			and ads.contexts.is_empty(),
		"An intent bound to another shelf is refused before an ad is ever presented."
	)
	_check(
		not client.is_shelf_unlock_authorized(4) and not client.is_shelf_unlock_authorized(7),
		"A refused wrong-shelf intent authorizes nothing."
	)

	transport.responses = [
		_success(14, _intent(SHELF_INTENT_ID, "shelf_unlock", _shelf_effect(4))),
		_success(15, _pending_status(SHELF_INTENT_ID, 4)),
	]
	var pending: Dictionary = await client.claim_shelf_unlock(3, 4)
	_check(
		not bool(pending.get("ok", false)) and bool(pending.get("pending", false)),
		"Pending SSV unlocks nothing."
	)
	_check(
		client.is_awaiting_shelf_unlock_verification(4)
			and not client.is_awaiting_shelf_unlock_verification(5),
		"An unsettled claim stays bound to the shelf it was created for."
	)

	var calls_before := transport.calls.size()
	var other_shelf: Dictionary = await client.claim_shelf_unlock(3, 5)
	_check(
		str((other_shelf.get("error", {}) as Dictionary).get("code", "")) == "ad_reward.other_verification_pending"
			and transport.calls.size() == calls_before,
		"Only one shelf claim may be unsettled at a time."
	)

	transport.responses = [
		_success(16, _status(SHELF_INTENT_ID, "shelf_unlock", _shelf_effect(4), SHELF_AUTH_ID)),
	]
	var reconciled: Dictionary = await client.claim_shelf_unlock(3, 4)
	_check(
		bool(reconciled.get("ok", false)) and ads.contexts.size() == 1,
		"Verify Reward polls the same shelf intent without presenting a second ad."
	)

	calls_before = transport.calls.size()
	var duplicate: Dictionary = await client.claim_shelf_unlock(3, 4)
	_check(
		str((duplicate.get("error", {}) as Dictionary).get("code", "")) == "ad_reward.shelf_already_authorized"
			and transport.calls.size() == calls_before
			and ads.contexts.size() == 1,
		"A shelf already unlocked this attempt cannot be claimed again."
	)
	_free_nodes([client, transport, ads])
	await process_frame


func _shelf_effect(shelf_id: int) -> Dictionary:
	return {"kind": "shelf_unlock", "shelf_id": shelf_id}


func _intent(intent_id: String, placement: String, effect: Dictionary) -> Dictionary:
	return {
		"policy_version": "rewarded-ads/1",
		"intent_id": intent_id,
		"custom_data": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
		"placement": placement,
		"effect": effect,
		"status": "pending",
	}


func _status(intent_id: String, placement: String, effect: Dictionary, authorization_id: String) -> Dictionary:
	return {
		"policy_version": "rewarded-ads/1",
		"intent_id": intent_id,
		"placement": placement,
		"effect": effect,
		"status": "settled",
		"authorization_id": authorization_id,
	}


func _pending_status(intent_id: String, shelf_id: int) -> Dictionary:
	return {
		"policy_version": "rewarded-ads/1",
		"intent_id": intent_id,
		"placement": "shelf_unlock",
		"effect": _shelf_effect(shelf_id),
		"status": "pending",
	}


func _success(state_version: int, data: Dictionary) -> Dictionary:
	return {"ok": true, "meta": {"state_version": state_version}, "data": data}


func _free_nodes(nodes: Array) -> void:
	for node in nodes:
		(node as Node).queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % message)
