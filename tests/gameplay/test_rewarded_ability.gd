extends SceneTree

## ADS-005 gameplay integration verification. Run through:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/gameplay/test_rewarded_ability.gd

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const REWARDED_ABILITIES := [&"hammer", &"shuffle", &"highlight"]
const ABILITY_FREEZER := &"freezer"

var _failures: Array[String] = []
var _progress


class FakeRewardedAbilityClient extends Node:
	var claim_count := 0

	func prepare_ability() -> Dictionary:
		return {"status": &"ready"}

	func can_offer_ability(ability_id: StringName) -> bool:
		return ability_id in REWARDED_ABILITIES

	func is_awaiting_verification() -> bool:
		return false

	func is_awaiting_ability_verification(_ability_id: StringName) -> bool:
		return false

	func claim_ability(_level_number: int, ability_id: StringName) -> Dictionary:
		claim_count += 1
		await get_tree().process_frame
		await get_tree().process_frame
		return {
			"ok": true,
			"ability_id": ability_id,
			"uses": 1,
			"authorization_id": "00000000-0000-4000-8000-000000000401",
		}

	func has_active_run() -> bool:
		return false


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Rewarded-ability gameplay verification must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_progress = root.get_node_or_null(^"PlayerProgress")
	_check(_progress != null, "PlayerProgress autoload is available.")
	if _progress == null:
		quit(1)
		return
	await _test_authorized_use_is_immediate_and_free()
	await _test_freezer_remains_coin_only()
	if _failures.is_empty():
		print("Rewarded-ability gameplay verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_authorized_use_is_immediate_and_free() -> void:
	_progress.reset_progress()
	for ability_id in REWARDED_ABILITIES:
		while int(_progress.get_ability_uses().get(String(ability_id), 0)) > 0:
			_progress.spend_ability(ability_id)
	var coins_before: int = _progress.get_coins()
	var level = await _make_level(8)
	var original_client = level.get("_rewarded_time_extension_client")
	var fake := FakeRewardedAbilityClient.new()
	level.add_child(fake)
	level.set("_rewarded_time_extension_client", fake)
	if original_client != null:
		original_client.queue_free()

	var ability_id := StringName()
	for candidate in REWARDED_ABILITIES:
		if bool(level.call("_can_apply_ability", candidate)):
			ability_id = candidate
			break
	_check(ability_id != StringName(), "The fixture can apply a supported rewarded ability.")
	if ability_id == StringName():
		level.queue_free()
		await process_frame
		return
	level.call("_open_ability_purchase_menu", ability_id)
	await create_timer(0.25).timeout
	var purchase = level.get("_ability_purchase_overlay")
	var watch_ad := purchase.find_child("WatchAdButton", true, false) as Button
	_check(
		watch_ad.visible and not watch_ad.disabled and watch_ad.text == "Watch Ad",
		"A ready supported ability exposes the rewarded action."
	)
	_check(not bool(level.call("_is_ui_action_blocked")), "The fixture has finished modal transitions.")
	_check(bool(level.call("_can_apply_ability", ability_id)), "The selected ability remains applicable while paused.")

	level.call("_on_ability_purchase_ad_pressed")
	level.call("_on_ability_purchase_ad_pressed")
	level.call("_open_ability_purchase_menu", &"hammer")
	level.call("_on_ability_purchase_close_pressed")
	_check(fake.claim_count == 1, "Repeated input starts only one rewarded request (got %d)." % fake.claim_count)
	_check(
		StringName(level.get("_ability_purchase_pending_id")) == ability_id
			and purchase.visible,
		"The selected ability and modal cannot change while authorization is in flight."
	)

	await create_timer(0.25).timeout
	_check(_is_ability_active(level, ability_id), "The exact authorized ability is applied immediately.")
	_check(not purchase.visible, "Successful application closes the purchase modal.")
	_check(_progress.get_coins() == coins_before, "The rewarded path spends no coins.")
	_check(
		int(_progress.get_ability_uses().get(String(ability_id), -1)) == 0,
		"The rewarded path neither adds nor spends persistent inventory."
	)
	level.queue_free()
	await process_frame


func _test_freezer_remains_coin_only() -> void:
	var level = await _make_level(8)
	var original_client = level.get("_rewarded_time_extension_client")
	var fake := FakeRewardedAbilityClient.new()
	level.add_child(fake)
	level.set("_rewarded_time_extension_client", fake)
	if original_client != null:
		original_client.queue_free()
	level.call("_open_ability_purchase_menu", ABILITY_FREEZER)
	await create_timer(0.25).timeout
	var purchase = level.get("_ability_purchase_overlay")
	var watch_ad := purchase.find_child("WatchAdButton", true, false) as Button
	var buy_button := purchase.find_child("BuyButton", true, false) as Button
	_check(not watch_ad.visible, "Freezer has no rewarded route outside the backend ability enum.")
	_check(not buy_button.disabled, "Freezer keeps its existing coin-funded action.")
	level.queue_free()
	await process_frame


func _make_level(level_number: int):
	var scene := load("res://level.tscn") as PackedScene
	var level = scene.instantiate()
	_check(level.get_script() != null, "The level script compiles and attaches.")
	level.set("launched_from_dev_mode", false)
	level.set("selected_level", level_number)
	root.add_child(level)
	await _wait_frames(3)
	# This test owns the modal directly; bypass the unrelated entrance curtain used by full gameplay.
	level.set("_loading_transition_pending", false)
	return level


func _is_ability_active(level, ability_id: StringName) -> bool:
	match ability_id:
		&"hammer":
			return bool(level.get("_hammer_effect_active"))
		&"shuffle":
			return bool(level.get("_shuffle_effect_active"))
		&"highlight":
			return float(level.get("_highlight_timer")) > 0.0
	return false


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
