extends SceneTree

## ADS-006 gameplay integration verification. Run through:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/gameplay/test_rewarded_shelf_unlock.gd

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
## Level 3 authors one locked shelf; level 4 authors two with different requirements, which is what
## proves an unlock touches only the shelf it was bound to.
const SINGLE_LOCK_LEVEL := 3
const TWO_LOCK_LEVEL := 4

var _failures: Array[String] = []


## Deterministic stand-in for the authoritative claim. `outcome` decides what a claim settles as, so
## dismissal/failure can be exercised against the same level fixture as a verified unlock.
class FakeShelfUnlockClient extends Node:
	enum Outcome { SETTLED, FAILED, PENDING, WRONG_SHELF }

	var outcome: Outcome = Outcome.SETTLED
	var claim_count := 0
	var claimed_shelf_ids: Array[int] = []
	var authorized_shelf_ids: Array[int] = []

	func prepare_shelf_unlock() -> Dictionary:
		return {"status": &"ready"}

	func can_offer_shelf_unlock(shelf_id: int) -> bool:
		return shelf_id > 0 and not authorized_shelf_ids.has(shelf_id)

	func is_awaiting_verification() -> bool:
		return false

	func is_awaiting_shelf_unlock_verification(_shelf_id: int) -> bool:
		return false

	func is_shelf_unlock_authorized(shelf_id: int) -> bool:
		return authorized_shelf_ids.has(shelf_id)

	func claim_shelf_unlock(_level_number: int, shelf_id: int) -> Dictionary:
		claim_count += 1
		claimed_shelf_ids.append(shelf_id)
		await get_tree().process_frame
		await get_tree().process_frame
		match outcome:
			Outcome.FAILED:
				return {"ok": false, "error": {"code": "ads.dismissed"}, "pending": false}
			Outcome.PENDING:
				return {"ok": false, "error": {"code": "ad_reward.verification_pending"}, "pending": true}
			Outcome.WRONG_SHELF:
				return {
					"ok": true,
					"shelf_id": shelf_id + 1,
					"authorization_id": "00000000-0000-4000-8000-000000000611",
				}
			_:
				authorized_shelf_ids.append(shelf_id)
				return {
					"ok": true,
					"shelf_id": shelf_id,
					"authorization_id": "00000000-0000-4000-8000-000000000610",
				}

	func has_active_run() -> bool:
		return false


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Rewarded shelf-unlock gameplay verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_tap_opens_confirmation_without_starting_an_ad()
	await _test_verified_unlock_releases_only_the_bound_shelf()
	await _test_dismissed_and_wrong_shelf_claims_leave_the_shelf_locked()
	if _failures.is_empty():
		print("Rewarded shelf-unlock gameplay verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_tap_opens_confirmation_without_starting_an_ad() -> void:
	var level = await _make_level(SINGLE_LOCK_LEVEL)
	var fake := _install_fake_client(level)
	var shelf := _find_locked_shelf(level)
	if shelf == null:
		_fail("Level %d should provide a locked shelf." % SINGLE_LOCK_LEVEL)
		await _free_level(level)
		return

	var overlay := shelf.get_node("LockedOverlay") as ShelfLockOverlay
	level.call("_refresh_shelf_unlock_offers")
	_check(
		overlay.is_ad_unlock_available(),
		"A locked shelf with a ready placement offers its AD plate."
	)
	_check(
		overlay.get_ad_plate_global_rect().has_area(),
		"The AD plate exposes a real hit area derived from the lock rig."
	)

	overlay.unlock_requested.emit()
	await create_timer(0.3).timeout
	var modal = level.get("_shelf_unlock_overlay")
	_check(
		modal.visible and fake.claim_count == 0,
		"A plate tap opens the confirmation modal and starts no ad by itself."
	)
	_check(
		int(level.get("_shelf_unlock_pending_id")) == int(level.call("_get_shelf_config_id", shelf)),
		"The confirmation is bound to the tapped shelf's configured id."
	)
	_check(bool(level.get("_level_paused")), "Gameplay pauses while the confirmation is open.")
	_check(
		not overlay.is_ad_unlock_available(),
		"Every plate is withdrawn while a claim is bound, so only one shelf can be pending."
	)

	var button := modal.find_child("RewardedAdButton", true, false) as Button
	_check(
		button.visible and not button.disabled and button.text == ShelfUnlockMenu.READY_LABEL,
		"A ready offer states both the ad and the exact reward."
	)

	level.call("_on_shelf_unlock_close_pressed")
	await create_timer(0.3).timeout
	_check(
		not modal.visible
			and int(level.get("_shelf_unlock_pending_id")) == 0
			and fake.claim_count == 0,
		"Closing the confirmation grants nothing and requests no ad."
	)
	_check(
		bool(level.call("_is_shelf_locked", shelf)) and not bool(level.get("_level_paused")),
		"A dismissed confirmation leaves the shelf locked and resumes gameplay."
	)
	# Nothing re-offers the plate explicitly; closing the confirmation has to restore it on its own.
	_check(
		overlay.is_ad_unlock_available(),
		"Closing the confirmation restores the shelf's plate without another explicit refresh."
	)
	await _free_level(level)


func _test_verified_unlock_releases_only_the_bound_shelf() -> void:
	var level = await _make_level(TWO_LOCK_LEVEL)
	var fake := _install_fake_client(level)
	var locked_shelves := _find_locked_shelves(level)
	if locked_shelves.size() < 2:
		_fail("Level %d should provide two locked shelves." % TWO_LOCK_LEVEL)
		await _free_level(level)
		return

	var target := locked_shelves[0]
	var other := locked_shelves[1]
	var target_id := int(level.call("_get_shelf_config_id", target))
	var other_requirement := int(level.call("_get_shelf_unlock_requirement", other))
	var other_remaining := _get_remaining_text(other)
	var triples_before := int(level.get("_triples_cleared"))
	var stars_before := int(level.get("_stars"))

	level.call("_open_shelf_unlock_menu", target)
	await create_timer(0.3).timeout
	level.call("_on_shelf_unlock_ad_requested")
	level.call("_on_shelf_unlock_ad_requested")
	await create_timer(0.6).timeout

	_check(fake.claim_count == 1, "Repeated taps start only one claim (got %d)." % fake.claim_count)
	_check(
		fake.claimed_shelf_ids.size() == 1 and fake.claimed_shelf_ids[0] == target_id,
		"The claim is bound to the selected configured shelf id."
	)
	_check(
		not bool(level.call("_is_shelf_locked", target)),
		"A verified authorization unlocks the shelf it was bound to."
	)
	_check(
		bool(level.call("_is_shelf_locked", other)),
		"The other locked shelf is untouched by another shelf's rewarded unlock."
	)
	_check(
		int(level.call("_get_shelf_unlock_requirement", other)) == other_requirement
			and _get_remaining_text(other) == other_remaining,
		"The other shelf's configured requirement and visible countdown do not move."
	)
	_check(
		int(level.get("_triples_cleared")) == triples_before
			and int(level.get("_stars")) == stars_before,
		"A rewarded unlock adds no cleared triples, stars, or combo."
	)
	_check(
		_items_are_pickable(level, target),
		"The unlocked shelf's items become interactable immediately."
	)
	var modal = level.get("_shelf_unlock_overlay")
	_check(
		int(level.get("_shelf_unlock_pending_id")) == 0 and not bool(level.get("_level_paused")),
		"A verified unlock closes the confirmation and resumes gameplay."
	)

	# The same shelf may not be sold twice in one attempt, and its plate is gone with its lock.
	var target_overlay := target.get_node("LockedOverlay") as ShelfLockOverlay
	_check(
		not target_overlay.is_ad_unlock_available()
			and not bool(level.call("_is_rewarded_shelf_unlock_available", target_id)),
		"An unlocked shelf keeps no further rewarded route this attempt."
	)
	level.call("_on_shelf_unlock_requested", target)
	await process_frame
	_check(
		not modal.visible and fake.claim_count == 1,
		"An already unlocked shelf cannot reopen the confirmation."
	)

	# Every other locked shelf must retain its own rewarded path while it remains locked, and get it
	# back from the unlock flow itself rather than from an explicit refresh.
	var other_overlay := other.get_node("LockedOverlay") as ShelfLockOverlay
	_check(
		other_overlay.is_ad_unlock_available(),
		"Remaining locked shelves keep their own rewarded path (no attempt-wide cap)."
	)
	await _free_level(level)


func _test_dismissed_and_wrong_shelf_claims_leave_the_shelf_locked() -> void:
	for outcome in [
		FakeShelfUnlockClient.Outcome.FAILED,
		FakeShelfUnlockClient.Outcome.WRONG_SHELF,
	]:
		var level = await _make_level(SINGLE_LOCK_LEVEL)
		var fake := _install_fake_client(level)
		fake.outcome = outcome
		var shelf := _find_locked_shelf(level)
		if shelf == null:
			_fail("Level %d should provide a locked shelf." % SINGLE_LOCK_LEVEL)
			await _free_level(level)
			return

		var remaining_before := _get_remaining_text(shelf)
		var triples_before := int(level.get("_triples_cleared"))
		level.call("_open_shelf_unlock_menu", shelf)
		await create_timer(0.3).timeout
		level.call("_on_shelf_unlock_ad_requested")
		await create_timer(0.6).timeout

		var modal = level.get("_shelf_unlock_overlay")
		var button := modal.find_child("RewardedAdButton", true, false) as Button
		_check(
			bool(level.call("_is_shelf_locked", shelf))
				and _get_remaining_text(shelf) == remaining_before
				and int(level.get("_triples_cleared")) == triples_before,
			"Outcome %d leaves the shelf locked with the same visible clear count." % outcome
		)
		_check(
			modal.visible and button.text == "Try Again",
			"Outcome %d keeps the modal open with an honest retryable state." % outcome
		)
		_check(
			not _items_are_pickable(level, shelf),
			"Outcome %d never makes the locked shelf's items interactable." % outcome
		)
		await _free_level(level)


func _make_level(level_number: int):
	var scene := load("res://level.tscn") as PackedScene
	var level = scene.instantiate()
	_check(level.get_script() != null, "The level script compiles and attaches.")
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", level_number)
	root.add_child(level)
	await _wait_frames(3)
	# This test drives the modal directly; bypass the unrelated entrance curtain.
	level.set("_loading_transition_pending", false)
	level.set("_sound_effects_enabled", false)
	return level


func _install_fake_client(level) -> FakeShelfUnlockClient:
	var original = level.get("_rewarded_time_extension_client")
	var fake := FakeShelfUnlockClient.new()
	level.add_child(fake)
	level.set("_rewarded_time_extension_client", fake)
	if original != null:
		original.queue_free()
	return fake


func _find_locked_shelf(level) -> Node2D:
	var locked := _find_locked_shelves(level)
	return null if locked.is_empty() else locked[0]


func _find_locked_shelves(level) -> Array[Node2D]:
	var locked: Array[Node2D] = []
	for shelf in level.call("_get_all_shelves"):
		if bool(level.call("_is_shelf_locked", shelf)):
			locked.append(shelf as Node2D)
	return locked


func _get_remaining_text(shelf: Node2D) -> String:
	var label := shelf.get_node("LockedOverlay/VisualRig/CountdownBadge/RemainingLabel") as Label
	return label.text


func _items_are_pickable(level, shelf: Node2D) -> bool:
	var items: Array = level.call("_get_shelf_items", shelf)
	if items.is_empty():
		return false
	for item in items:
		if item != null and bool(item.get("input_pickable")):
			return true
	return false


func _free_level(level) -> void:
	level.queue_free()
	await _wait_frames(2)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _fail(description: String) -> void:
	_failures.append("FAILED: %s" % description)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_fail(description)
