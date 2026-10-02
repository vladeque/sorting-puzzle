extends SceneTree

## GAME-012 batch 3 coverage for scenes/ui/account_deletion_modal.tscn against a fake deletion
## service: every view's text, actions, and closability; Cancel, Close, the close button, and
## `ui_cancel`; duplicate-tap protection while a request runs; locked states that never dismiss;
## support references; and the Start New Game handoff.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const MODAL_SCENE := "res://scenes/ui/account_deletion_modal.tscn"
const MODAL_SCRIPT_PATH := "res://scripts/account_deletion_modal.gd"

var _failures: Array[String] = []


class FakeService:
	extends Node
	signal state_changed(state: Dictionary)
	var state := {"phase": "idle", "kind": "", "busy": false, "failure": {}, "receipt": {}, "support_reference": {}}
	var availability := {"kind": "account", "reason": ""}
	var request_calls := 0
	var local_request_calls := 0
	var retry_calls := 0
	var new_game_calls := 0
	var resolution_calls := 0
	var hold_request := false
	var final_state := {}

	func get_state() -> Dictionary:
		return state.duplicate(true)

	func get_availability() -> Dictionary:
		return availability.duplicate(true)

	func set_state(next: Dictionary) -> void:
		state.merge(next, true)
		state_changed.emit(get_state())

	func request_account_deletion() -> Dictionary:
		request_calls += 1
		return await _run_request()

	func request_local_data_deletion() -> Dictionary:
		local_request_calls += 1
		return await _run_request()

	func retry() -> Dictionary:
		retry_calls += 1
		return await _run_request()

	func start_new_game() -> Dictionary:
		new_game_calls += 1
		set_state({"phase": "idle", "kind": ""})
		return get_state()

	func request_registration_resolution() -> void:
		resolution_calls += 1

	func _run_request() -> Dictionary:
		set_state({"phase": "preparing", "busy": true})
		while hold_request:
			await get_tree().process_frame
		var settled := {"busy": false}
		settled.merge(final_state, true)
		set_state(settled)
		return get_state()


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Account deletion modal tests must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _check_account_confirmation_and_cancel()
	await _check_local_confirmation_uses_the_local_flow()
	await _check_back_closes_a_confirmation()
	await _check_request_blocks_duplicates_and_dismissal()
	await _check_failure_view()
	await _check_locked_states()
	await _check_result_and_new_game()
	await _check_unavailable_views()
	_check_deadline_format()

	if _failures.is_empty():
		print("Account deletion modal verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_account_confirmation_and_cancel() -> void:
	var service := _service()
	var modal := await _open(service)
	var view: Dictionary = modal.get_view()
	_check(str(view.get("title", "")) == "DELETE ACCOUNT", "An account confirmation is titled Delete Account.")
	_check(str(view.get("primary_text", "")) == "Delete Account", "The confirm action is Delete Account.")
	_check(str(view.get("primary_role", "")) == "destructive", "The confirm action uses the destructive style.")
	_check(str(view.get("secondary_text", "")) == "Cancel", "The confirmation offers Cancel.")
	_check(str(view.get("body", "")).contains("can't undo"), "The confirmation says deletion is permanent.")
	_check(str(view.get("body", "")).contains("30 days"), "The confirmation states the removal window.")
	_check(modal.is_closable(), "A confirmation can be dismissed.")
	_check(_close_button(modal).visible, "A confirmation shows the close button.")
	var closed := [false]
	modal.closed.connect(func() -> void: closed[0] = true)
	_secondary(modal).pressed.emit()
	await _seconds(0.5)
	_check(closed[0], "Cancel closes the modal.")
	_check(service.request_calls == 0, "Cancel never requests deletion.")
	await _cleanup(service)


func _check_local_confirmation_uses_the_local_flow() -> void:
	var service := _service()
	service.availability = {"kind": "local_data", "reason": ""}
	service.final_state = {"phase": "ready", "kind": "local_data"}
	var modal := await _open(service)
	var view: Dictionary = modal.get_view()
	_check(str(view.get("title", "")) == "DELETE GAME DATA", "A local confirmation is titled Delete Game Data.")
	_check(str(view.get("primary_text", "")) == "Delete Data", "The local confirm action is Delete Data.")
	_check(str(view.get("body", "")).contains("never created an online account"), "The local confirmation explains its scope.")
	_primary(modal).pressed.emit()
	await _frames(3)
	_check(service.local_request_calls == 1 and service.request_calls == 0, "Local confirmation uses the local flow.")
	_check(str(modal.get_view().get("headline", "")) == "Your local game data was deleted.", "The local result is shown.")
	await _cleanup(service, modal)


func _check_back_closes_a_confirmation() -> void:
	var service := _service()
	var modal := await _open(service)
	var closed := [false]
	modal.closed.connect(func() -> void: closed[0] = true)
	_press_back()
	await _seconds(0.5)
	_check(closed[0], "Back closes a confirmation without deleting.")
	_check(service.request_calls == 0, "Back never requests deletion.")
	await _cleanup(service)


func _check_request_blocks_duplicates_and_dismissal() -> void:
	var service := _service()
	service.hold_request = true
	service.final_state = {"phase": "ready", "kind": "account", "receipt": {"complete_by": "2026-11-01T12:00:00.000Z"}}
	var modal := await _open(service)
	_primary(modal).pressed.emit()
	await _frames(2)
	_check(service.request_calls == 1, "Delete Account requests deletion once.")
	_check(str(modal.get_view().get("headline", "")) == "Deleting your account...", "A running request shows progress.")
	_check(not _primary(modal).visible and not _secondary(modal).visible, "Progress offers no actions.")
	_check(not modal.is_closable(), "A running request cannot be dismissed.")
	_check(not _close_button(modal).visible, "A running request hides the close button.")
	_primary(modal).pressed.emit()
	_press_back()
	await _frames(3)
	_check(service.request_calls == 1, "A duplicate tap does not send a second request.")
	_check(is_instance_valid(modal) and modal.is_inside_tree(), "Back does not close a running request.")
	service.hold_request = false
	await _frames(3)
	_check(str(modal.get_view().get("title", "")) == "DELETION ACCEPTED", "An accepted request shows its result.")
	await _cleanup(service, modal)


func _check_failure_view() -> void:
	var service := _service()
	service.final_state = {"phase": "idle", "failure": {"reason": "offline", "code": "network.transport_failed"}}
	var modal := await _open(service)
	_primary(modal).pressed.emit()
	await _frames(3)
	var view: Dictionary = modal.get_view()
	_check(str(view.get("title", "")) == "NOT DELETED", "A failed request says nothing was deleted.")
	_check(str(view.get("headline", "")) == "Connect to the internet to delete your account.", "Offline failures ask for a connection.")
	_check(str(view.get("primary_text", "")) == "Try Again" and str(view.get("primary_role", "")) == "positive", "A failure offers Try Again.")
	_check(modal.is_closable(), "A failure can be dismissed.")
	_primary(modal).pressed.emit()
	await _frames(3)
	_check(service.request_calls == 2, "Try Again requests deletion again.")
	await _cleanup(service, modal)

	var stale := _service()
	stale.state["failure"] = {"reason": "offline"}
	var reopened := await _open(stale)
	_check(str(reopened.get_view().get("title", "")) == "DELETE ACCOUNT", "An earlier failure is not shown when the modal reopens.")
	await _cleanup(stale, reopened)


func _check_locked_states() -> void:
	for entry in [
		{"phase": "retry_pending", "title": "NOT CONFIRMED", "primary": "Try Again"},
		{"phase": "unconfirmed", "title": "STATUS UNCONFIRMED", "primary": "Get Help"},
		{"phase": "cleaning", "title": "FINISHING UP", "primary": "Try Again"},
		{"phase": "record_corrupt", "title": "STATUS UNKNOWN", "primary": "Get Help"},
	]:
		var service := _service()
		service.state.merge({
			"phase": entry.get("phase"),
			"kind": "account",
			"support_reference": {"operation_id": "00000000-0000-4000-8000-000000006071"},
		}, true)
		var modal := await _open(service)
		var view: Dictionary = modal.get_view()
		var label := str(entry.get("phase"))
		_check(str(view.get("title", "")) == str(entry.get("title")), "%s shows its title." % label)
		_check(str(view.get("primary_text", "")) == str(entry.get("primary")), "%s offers %s." % [label, entry.get("primary")])
		_check(not modal.is_closable(), "%s cannot be dismissed." % label)
		_check(not _close_button(modal).visible, "%s hides the close button." % label)
		_press_back()
		await _seconds(0.5)
		_check(is_instance_valid(modal) and modal.is_inside_tree(), "Back does not leave %s." % label)
		if label == "unconfirmed":
			_check(
				str(view.get("headline", "")) == "Deletion status unconfirmed"
				and str(view.get("reference", "")).contains("00000000-0000-4000-8000-000000006071"),
				"An unconfirmed deletion shows the plan's headline and a support reference."
			)
		if label == "retry_pending":
			_primary(modal).pressed.emit()
			await _frames(3)
			_check(service.retry_calls == 1, "Try Again replays the pending request.")
		await _cleanup(service, modal)


func _check_result_and_new_game() -> void:
	var service := _service()
	service.state.merge({
		"phase": "ready",
		"kind": "account",
		"receipt": {"complete_by": "2026-11-01T12:00:00.000Z"},
	}, true)
	var modal := await _open(service)
	var view: Dictionary = modal.get_view()
	var deadline: String = (load(MODAL_SCRIPT_PATH) as GDScript).call("format_deadline", "2026-11-01T12:00:00.000Z")
	_check(str(view.get("headline", "")) == "Your account is no longer accessible.", "The result says access ended.")
	_check(
		str(view.get("body", "")) == "Your deletion request was accepted. Data removal is due by %s." % deadline,
		"The result states the acceptance and removal deadline without claiming removal is done."
	)
	_check(not modal.is_closable(), "The result cannot be dismissed into the deleted account.")
	var started := [false]
	modal.new_game_started.connect(func() -> void: started[0] = true)
	_primary(modal).pressed.emit()
	await _frames(2)
	_check(service.new_game_calls == 1, "Start New Game asks the service for a new game.")
	_check(started[0], "Start New Game hands off to the host once the new game is active.")
	await _cleanup(service, modal)


func _check_unavailable_views() -> void:
	var pending := _service()
	pending.availability = {"kind": "registration_pending", "reason": ""}
	var pending_modal := await _open(pending)
	_check(pending.resolution_calls == 1, "A pending registration is asked to finish.")
	_check(
		str(pending_modal.get_view().get("primary_text", "")) == "Close" and not _secondary(pending_modal).visible,
		"A pending registration offers only Close."
	)
	_check(pending_modal.is_closable(), "A pending registration can be dismissed.")
	await _cleanup(pending, pending_modal)

	var unsupported := _service()
	unsupported.availability = {"kind": "unavailable", "reason": "not_configured"}
	var unsupported_modal := await _open(unsupported)
	var view: Dictionary = unsupported_modal.get_view()
	_check(str(view.get("primary_text", "")) == "Get Help", "An unavailable build offers support.")
	_check(str(view.get("secondary_text", "")) == "Close", "An unavailable build can be closed.")
	await _cleanup(unsupported, unsupported_modal)


func _check_deadline_format() -> void:
	var formatted: String = (load(MODAL_SCRIPT_PATH) as GDScript).call("format_deadline", "2026-11-01T12:00:00.000Z")
	var pattern := RegEx.new()
	pattern.compile("^(October|November) \\d{1,2}, 2026$")
	_check(pattern.search(formatted) != null, "Deadlines read as a calendar date (got %s)." % formatted)
	_check(str((load(MODAL_SCRIPT_PATH) as GDScript).call("format_deadline", "not a time")).is_empty(), "An invalid deadline is omitted.")


func _service() -> FakeService:
	var service := FakeService.new()
	root.add_child(service)
	return service


func _open(service: FakeService) -> Control:
	var modal := (load(MODAL_SCENE) as PackedScene).instantiate() as Control
	modal.call("setup", service)
	root.add_child(modal)
	await _seconds(0.5)
	return modal


func _primary(modal: Control) -> Button:
	return modal.get_node("%PrimaryButton") as Button


func _secondary(modal: Control) -> Button:
	return modal.get_node("%SecondaryButton") as Button


func _close_button(modal: Control) -> Button:
	return modal.get_node("%Shell").get_node("%CloseButton") as Button


func _press_back() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	root.push_input(event)


func _cleanup(service: Node, modal: Node = null) -> void:
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	service.queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Real time, so the shell's open/close fades finish before a modal is freed.
func _seconds(duration: float) -> void:
	await create_timer(duration).timeout
