extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const ClientScript := preload("res://scripts/ads/rewarded_life_client.gd")
const INTENT_ID := "00000000-0000-4000-8000-000000000201"

var _failures: Array[String] = []


class FakeTransport extends Node:
	var responses: Array[Dictionary] = []
	var calls: Array[Dictionary] = []

	func can_use_backend() -> bool:
		return true

	func get_json(path: String) -> Dictionary:
		calls.append({"method": "GET", "path": path})
		return responses.pop_front()

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
	var result := {"status": &"rewarded", "impression": true}
	var contexts: Array[Dictionary] = []

	func is_rewarded_ready(_placement: StringName, _server_can_accept_claim: bool) -> bool:
		return true

	func preload_rewarded(_placement: StringName, _server_can_accept_claim: bool) -> Dictionary:
		return {"status": &"ready"}

	func request_rewarded(
		_placement: StringName,
		context: Dictionary,
		_server_can_accept_claim: bool
	) -> Dictionary:
		contexts.append(context.duplicate(true))
		return result.duplicate(true)


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Rewarded-life verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_settled_life_uses_authoritative_state()
	await _test_pending_and_dismissed_ads_never_grant()
	await _test_full_life_state_stops_before_intent()
	if _failures.is_empty():
		print("Rewarded-life verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_settled_life_uses_authoritative_state() -> void:
	var transport := FakeTransport.new()
	var ads := FakeAdService.new()
	root.add_child(transport)
	root.add_child(ads)
	var client := ClientScript.new()
	root.add_child(client)
	client.configure(transport, ads)
	client.poll_attempt_limit = 2
	client.poll_delay_seconds = 0.01
	transport.responses = [
		_state(10, 0),
		_success(11, _intent()),
		_success(11, _status("pending")),
		_success(12, _status("settled", _life_state(1))),
	]

	var claim: Dictionary = await client.claim()
	_check(bool(claim.get("ok", false)), "A settled life intent returns an authoritative grant.")
	_check(
		int((claim.get("life_state", {}) as Dictionary).get("current", 0)) == 1,
		"The client returns the settled authoritative life balance."
	)
	var intent_call := transport.calls[1] as Dictionary
	_check(
		str(intent_call.get("protocol_version", "")) == "1.4"
			and (intent_call.get("data", {}) as Dictionary) == {"placement": "life"}
			and int(intent_call.get("expected_state_version", -1)) == 10,
		"Intent creation sends only the closed life binding and expected state version."
	)
	_check(
		str((ads.contexts[0] as Dictionary).get("ssv_custom_data", "")).length() == 43,
		"The opaque backend nonce is the only SSV data passed to the provider."
	)
	_free_nodes([client, transport, ads])
	await process_frame


func _test_pending_and_dismissed_ads_never_grant() -> void:
	var transport := FakeTransport.new()
	var ads := FakeAdService.new()
	root.add_child(transport)
	root.add_child(ads)
	var client := ClientScript.new()
	root.add_child(client)
	client.configure(transport, ads)
	client.poll_attempt_limit = 1
	transport.responses = [_state(20, 0), _success(21, _intent()), _success(21, _status("pending"))]
	var pending: Dictionary = await client.claim()
	_check(
		not bool(pending.get("ok", false)) and bool(pending.get("pending", false))
			and not pending.has("life_state"),
		"A provider reward with pending SSV settlement grants no life."
	)
	_check(client.is_awaiting_verification(), "Pending settlement retains the intent for Verify Reward.")
	transport.responses = [_success(22, _status("settled", _life_state(1)))]
	var reconciled: Dictionary = await client.claim()
	_check(bool(reconciled.get("ok", false)) and ads.contexts.size() == 1, "Retry polls the same intent without showing another ad.")
	_free_nodes([client, transport, ads])
	await process_frame

	var dismissed_transport := FakeTransport.new()
	var dismissed_ads := FakeAdService.new()
	dismissed_ads.result = {"status": &"dismissed", "reason": "closed", "impression": true}
	root.add_child(dismissed_transport)
	root.add_child(dismissed_ads)
	var dismissed_client := ClientScript.new()
	root.add_child(dismissed_client)
	dismissed_client.configure(dismissed_transport, dismissed_ads)
	dismissed_transport.responses = [_state(30, 0), _success(31, _intent())]
	var dismissed: Dictionary = await dismissed_client.claim()
	_check(
		not bool(dismissed.get("ok", false)) and not dismissed.has("life_state"),
		"A dismissed ad never returns a life state."
	)
	_free_nodes([dismissed_client, dismissed_transport, dismissed_ads])
	await process_frame


func _test_full_life_state_stops_before_intent() -> void:
	var transport := FakeTransport.new()
	var ads := FakeAdService.new()
	root.add_child(transport)
	root.add_child(ads)
	var client := ClientScript.new()
	root.add_child(client)
	client.configure(transport, ads)
	transport.responses = [_state(40, 5)]
	var claim: Dictionary = await client.claim()
	_check(
		str((claim.get("error", {}) as Dictionary).get("code", "")) == "life.already_full"
			and transport.calls.size() == 1
			and ads.contexts.is_empty(),
		"A full authoritative life state creates no intent and shows no ad."
	)
	_free_nodes([client, transport, ads])
	await process_frame


func _state(version: int, current: int) -> Dictionary:
	return _success(version, {"life_state": _life_state(current)})


func _life_state(current: int) -> Dictionary:
	return {
		"current": current,
		"maximum": 5,
		"restore_interval_seconds": 3600,
		"next_restore_at": "2026-09-20T12:00:00.000Z",
	}


func _intent() -> Dictionary:
	return {
		"policy_version": "rewarded-ads/1",
		"intent_id": INTENT_ID,
		"custom_data": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
		"placement": "life",
		"effect": {"kind": "life", "lives": 1},
		"status": "pending",
	}


func _status(status: String, life_state: Dictionary = {}) -> Dictionary:
	var result := {
		"policy_version": "rewarded-ads/1",
		"intent_id": INTENT_ID,
		"placement": "life",
		"effect": {"kind": "life", "lives": 1},
		"status": status,
	}
	if not life_state.is_empty():
		result["life_state"] = life_state
	return result


func _success(state_version: int, data: Dictionary) -> Dictionary:
	return {"ok": true, "meta": {"state_version": state_version}, "data": data}


func _free_nodes(nodes: Array) -> void:
	for node in nodes:
		(node as Node).queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
