extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const ClientScript := preload("res://scripts/ads/rewarded_time_extension_client.gd")
const RUN_ID := "00000000-0000-4000-8000-000000000301"
const TICKET_ID := "00000000-0000-4000-8000-000000000302"
const ABILITY_INTENT_ID := "00000000-0000-4000-8000-000000000303"
const ABILITY_AUTH_ID := "00000000-0000-4000-8000-000000000304"
const TIME_INTENT_ID := "00000000-0000-4000-8000-000000000305"
const TIME_AUTH_ID := "00000000-0000-4000-8000-000000000306"

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
			"data": {"campaign": {"current_level": 1}},
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
		push_error("Rewarded-ability verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_exact_ability_binding_and_shared_completion()
	await _test_pending_reconciliation_and_unsupported_ability()
	if _failures.is_empty():
		print("Rewarded-ability verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_exact_ability_binding_and_shared_completion() -> void:
	var transport := FakeTransport.new()
	var ads := FakeAdService.new()
	root.add_child(transport)
	root.add_child(ads)
	var client := ClientScript.new()
	root.add_child(client)
	client.configure(transport, ads)
	client.poll_attempt_limit = 1
	transport.responses = [
		_success(11, {"run_id": RUN_ID, "online_ticket_id": TICKET_ID, "campaign_level": 1}),
		_success(12, {"run_id": RUN_ID, "status": "started"}),
		_success(13, _intent(ABILITY_INTENT_ID, "ability", {"kind": "ability", "ability_id": "hammer", "uses": 1})),
		_success(14, _status(ABILITY_INTENT_ID, "ability", {"kind": "ability", "ability_id": "hammer", "uses": 1}, ABILITY_AUTH_ID)),
		_success(15, _intent(TIME_INTENT_ID, "time_extension", {"kind": "time_extension", "seconds": 60})),
		_success(16, _status(TIME_INTENT_ID, "time_extension", {"kind": "time_extension", "seconds": 60}, TIME_AUTH_ID)),
		_success(17, {
			"run_id": RUN_ID,
			"status": "accepted",
			"calculated_outcome": "completed",
			"calculated_stars": 4,
			"life_state": {"current": 5, "maximum": 5, "restore_interval_seconds": 3600},
		}),
	]

	var ability: Dictionary = await client.claim_ability(1, &"hammer")
	_check(bool(ability.get("ok", false)), "A settled matching ability authorization succeeds.")
	var intent_call := transport.calls[3] as Dictionary
	_check(
		(intent_call.get("data", {}) as Dictionary) == {
			"placement": "ability",
			"run_id": RUN_ID,
			"ability_id": "hammer",
		},
		"The ability intent binds the selected ability and current run exactly."
	)
	var time_claim: Dictionary = await client.claim(1)
	_check(bool(time_claim.get("ok", false)), "The same authoritative run can also receive time.")
	var start_calls := transport.calls.filter(func(call):
		return str((call as Dictionary).get("path", "")) == "/v1/runs/start"
	)
	_check(start_calls.size() == 1, "Ability and time share one run and one life reservation.")

	var completion: Dictionary = await client.settle_completed(4)
	_check(bool(completion.get("ok", false)), "The shared rewarded run completes successfully.")
	var completion_data := (transport.calls.back() as Dictionary).get("data", {}) as Dictionary
	var claim := completion_data.get("claim", {}) as Dictionary
	var authorizations := claim.get("rewarded_authorizations", []) as Array
	_check(
		str(claim.get("claim_format", "")) == "sorting-puzzle-completion/2"
			and int((claim.get("abilities_used", {}) as Dictionary).get("hammer", 0)) == 1
			and authorizations.size() == 2,
		"Completion reports one authorized immediate use and the exact two issued authorizations."
	)
	_check(
		StringName((ads.contexts[0] as Dictionary).get("placement", &"")) == &"ability"
			and str(((ads.contexts[0] as Dictionary).get("context", {}) as Dictionary).get("ssv_custom_data", "")).length() == 43,
		"The ability nonce is forwarded only to the ability placement."
	)
	_free_nodes([client, transport, ads])
	await process_frame


func _test_pending_reconciliation_and_unsupported_ability() -> void:
	var transport := FakeTransport.new()
	var ads := FakeAdService.new()
	root.add_child(transport)
	root.add_child(ads)
	var client := ClientScript.new()
	root.add_child(client)
	client.configure(transport, ads)
	client.poll_attempt_limit = 1
	transport.responses = [
		_success(11, {"run_id": RUN_ID, "online_ticket_id": TICKET_ID, "campaign_level": 1}),
		_success(12, {"run_id": RUN_ID, "status": "started"}),
		_success(13, _intent(ABILITY_INTENT_ID, "ability", {"kind": "ability", "ability_id": "shuffle", "uses": 1})),
		_success(13, _pending_status(ABILITY_INTENT_ID, "shuffle")),
	]
	var pending: Dictionary = await client.claim_ability(1, &"shuffle")
	_check(not bool(pending.get("ok", false)) and bool(pending.get("pending", false)), "Pending SSV grants no ability use.")
	transport.responses = [
		_success(14, _status(ABILITY_INTENT_ID, "ability", {"kind": "ability", "ability_id": "shuffle", "uses": 1}, ABILITY_AUTH_ID)),
	]
	var reconciled: Dictionary = await client.claim_ability(1, &"shuffle")
	_check(
		bool(reconciled.get("ok", false)) and ads.contexts.size() == 1,
		"Verify Reward polls the same ability intent without another presentation."
	)
	var calls_before := transport.calls.size()
	var unsupported: Dictionary = await client.claim_ability(1, &"freezer")
	_check(
		str((unsupported.get("error", {}) as Dictionary).get("code", "")) == "ad_reward.ability_unsupported"
			and transport.calls.size() == calls_before,
		"Freezer is rejected before transport because it is outside the approved backend enum."
	)
	_free_nodes([client, transport, ads])
	await process_frame


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


func _pending_status(intent_id: String, ability_id: String) -> Dictionary:
	return {
		"policy_version": "rewarded-ads/1",
		"intent_id": intent_id,
		"placement": "ability",
		"effect": {"kind": "ability", "ability_id": ability_id, "uses": 1},
		"status": "pending",
	}


func _success(state_version: int, data: Dictionary) -> Dictionary:
	return {"ok": true, "meta": {"state_version": state_version}, "data": data}


func _free_nodes(nodes: Array) -> void:
	for node in nodes:
		(node as Node).queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
