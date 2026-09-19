extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const ClientScript := preload("res://scripts/ads/rewarded_time_extension_client.gd")

const RUN_ID := "00000000-0000-4000-8000-000000000101"
const TICKET_ID := "00000000-0000-4000-8000-000000000102"
const INTENT_ID := "00000000-0000-4000-8000-000000000103"
const AUTHORIZATION_ID := "00000000-0000-4000-8000-000000000104"

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
			"data": {"campaign": {"current_level": 1, "highest_completed_level": 0}},
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
		if responses.is_empty():
			return {"ok": false, "error": {"code": "test.no_response"}}
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
		push_error("Rewarded time-extension verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_verified_claim_and_completion_binding()
	await _test_pending_and_dismissed_ads_never_grant_time()
	if _failures.is_empty():
		print("Rewarded time-extension verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_verified_claim_and_completion_binding() -> void:
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
		_success(11, {
			"run_id": RUN_ID,
			"online_ticket_id": TICKET_ID,
			"campaign_level": 1,
		}),
		_success(12, {"run_id": RUN_ID, "status": "started"}),
		_success(13, _intent()),
		_success(13, _status("pending")),
		_success(14, _status("settled", AUTHORIZATION_ID)),
		_success(15, {
			"run_id": RUN_ID,
			"status": "accepted",
			"calculated_outcome": "completed",
			"calculated_stars": 7,
			"life_state": {"current": 5, "maximum": 5, "restore_interval_seconds": 3600},
		}),
	]

	var claim: Dictionary = await client.claim(1)
	_check(bool(claim.get("ok", false)), "A settled server authorization grants the claim.")
	_check(int(claim.get("seconds", 0)) == 60, "The client accepts exactly the server-bound 60 seconds.")
	_check(
		str((ads.contexts[0] as Dictionary).get("ssv_custom_data", "")).length() == 43,
		"The opaque server nonce is passed to AdMob as SSV custom data."
	)
	var completion: Dictionary = await client.settle_completed(7)
	_check(bool(completion.get("ok", false)), "The authorized online run settles before local completion.")
	var completion_call := transport.calls.back() as Dictionary
	var completion_data := completion_call.get("data", {}) as Dictionary
	var completion_claim := completion_data.get("claim", {}) as Dictionary
	var authorizations := completion_claim.get("rewarded_authorizations", []) as Array
	_check(
		str(completion_call.get("protocol_version", "")) == "1.4"
			and str(completion_claim.get("claim_format", "")) == "sorting-puzzle-completion/2",
		"A rewarded completion uses protocol 1.4 and completion claim format 2."
	)
	_check(
		authorizations.size() == 1
			and str((authorizations[0] as Dictionary).get("authorization_id", "")) == AUTHORIZATION_ID
			and int((authorizations[0] as Dictionary).get("seconds", 0)) == 60,
		"Completion submits the exact verified time-extension authorization once."
	)
	_check(not client.has_active_run(), "Accepted completion clears the client run context.")
	client.queue_free()
	transport.queue_free()
	ads.queue_free()
	await process_frame


func _test_pending_and_dismissed_ads_never_grant_time() -> void:
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
		_success(13, _intent()),
		_success(13, _status("pending")),
	]
	var pending: Dictionary = await client.claim(1)
	_check(
		not bool(pending.get("ok", false)) and bool(pending.get("pending", false))
			and not pending.has("seconds"),
		"An SDK reward callback with pending SSV verification grants no gameplay time."
	)
	_check(client.is_awaiting_verification(), "A pending intent is retained for bounded reconciliation.")

	client.queue_free()
	transport.queue_free()
	ads.queue_free()
	await process_frame

	var dismissed_transport := FakeTransport.new()
	var dismissed_ads := FakeAdService.new()
	dismissed_ads.result = {"status": &"dismissed", "reason": "closed", "impression": true}
	root.add_child(dismissed_transport)
	root.add_child(dismissed_ads)
	var dismissed_client := ClientScript.new()
	root.add_child(dismissed_client)
	dismissed_client.configure(dismissed_transport, dismissed_ads)
	dismissed_transport.responses = [
		_success(11, {"run_id": RUN_ID, "online_ticket_id": TICKET_ID, "campaign_level": 1}),
		_success(12, {"run_id": RUN_ID, "status": "started"}),
		_success(13, _intent()),
		_success(14, {
			"run_id": RUN_ID,
			"status": "failed",
			"life_state": {
				"current": 4,
				"maximum": 5,
				"restore_interval_seconds": 3600,
				"next_restore_at": "2026-09-19T11:00:00.000Z",
			},
		}),
	]
	var dismissed: Dictionary = await dismissed_client.claim(1)
	_check(
		not bool(dismissed.get("ok", false)) and not dismissed.has("seconds"),
		"A dismissed ad grants no time and consumes no verified authorization."
	)
	var failed: Dictionary = await dismissed_client.settle_terminal("failed")
	_check(bool(failed.get("ok", false)), "A run opened for an ad is terminally settled on failure.")
	var terminal_call := dismissed_transport.calls.back() as Dictionary
	_check(
		str(terminal_call.get("path", "")) == "/v1/runs/%s/fail" % RUN_ID
			and str(terminal_call.get("protocol_version", "")) == "1.0",
		"Failure consumes the online life reservation through the canonical run endpoint."
	)
	dismissed_client.queue_free()
	dismissed_transport.queue_free()
	dismissed_ads.queue_free()
	await process_frame


func _success(state_version: int, data: Dictionary) -> Dictionary:
	return {"ok": true, "meta": {"state_version": state_version}, "data": data}


func _intent() -> Dictionary:
	return {
		"policy_version": "rewarded-ads/1",
		"intent_id": INTENT_ID,
		"custom_data": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
		"placement": "time_extension",
		"effect": {"kind": "time_extension", "seconds": 60},
		"status": "pending",
	}


func _status(status: String, authorization_id: String = "") -> Dictionary:
	var result := {
		"policy_version": "rewarded-ads/1",
		"intent_id": INTENT_ID,
		"placement": "time_extension",
		"effect": {"kind": "time_extension", "seconds": 60},
		"status": status,
	}
	if not authorization_id.is_empty():
		result["authorization_id"] = authorization_id
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
