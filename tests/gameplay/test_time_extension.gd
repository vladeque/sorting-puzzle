extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"
const TEST_LEVEL := 1

var _failures: Array[String] = []
var _progress
var _level_scene: PackedScene


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Time-extension verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_progress = root.get_node_or_null("PlayerProgress")
	_level_scene = load(LEVEL_SCENE_PATH) as PackedScene
	_check(_progress != null, "PlayerProgress autoload is available.")
	_check(_level_scene != null, "The level scene loads for time-extension verification.")
	if _progress == null or _level_scene == null:
		quit(1)
		return

	await _test_timeout_offer_and_decline()
	await _test_coin_extension_and_second_timeout()
	await _test_insufficient_coins_shop_round_trip()

	if _failures.is_empty():
		print("Time-extension verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_timeout_offer_and_decline() -> void:
	_progress.reset_progress()
	var starting_lives: int = _progress.get_lives()
	var level := await _open_campaign_level()
	level.set("_time_remaining", 0.0)
	level.call("_handle_level_time_expired")
	await _wait_seconds(0.3)

	var modal = level.get("_time_up_extension_overlay")
	var failure = level.get("_failure_screen")
	var coin_button := modal.get_node("%CoinButton") as Button
	var ad_button := modal.get_node("%WatchAdButton") as Button
	_check(modal.visible, "Timeout opens the time-extension modal before Failure.")
	_check(not failure.visible and not bool(level.get("_level_failed")), "The offer is recoverable, not terminal.")
	_check(bool(level.get("_level_paused")), "Gameplay stays paused while the timeout offer is open.")
	_check(_progress.get_lives() == starting_lives, "Opening the offer does not spend a life.")
	_check(
		(modal.get_node("%ExtensionLabel") as Label).text == "+01:00",
		"The modal shows the configured one-minute grant."
	)
	_check(
		(modal.get_node("%PriceLabel") as Label).text == "500" and not coin_button.disabled,
		"The coin action shows the configured 500-coin price."
	)
	_check(
		ad_button.visible and ad_button.disabled and ad_button.text.contains("Coming Soon"),
		"The production ad option remains visible, disabled, and explicit."
	)

	(modal.find_child("CloseButton", true, false) as Button).pressed.emit()
	await _wait_seconds(0.55)
	_check(bool(level.get("_level_failed")) and failure.visible, "Declining proceeds to Failure.")
	_check(_progress.get_lives() == starting_lives - 1, "Declining spends exactly one life.")
	await _free_current_scene()


func _test_coin_extension_and_second_timeout() -> void:
	_progress.reset_progress()
	var grant: Dictionary = _progress.apply_shop_purchase(
		"time-extension-test-coins",
		{"coins": 700}
	)
	_check(bool(grant.get("ok", false)), "Test setup grants enough extension coins.")
	var starting_coins: int = _progress.get_coins()
	var starting_lives: int = _progress.get_lives()
	var level := await _open_campaign_level()
	level.set("_time_remaining", 0.0)
	level.call("_handle_level_time_expired")
	await _wait_seconds(0.3)

	level.call("_on_time_extension_coin_requested")
	level.call("_on_time_extension_coin_requested")
	await _wait_seconds(0.45)
	_check(
		_progress.get_coins() == starting_coins - 500,
		"A rapid repeat request spends the 500-coin price exactly once."
	)
	_check(
		is_equal_approx(float(level.get("_time_remaining")), 60.0),
		"A successful purchase grants exactly 60 seconds."
	)
	_check(
		int(level.get("_coin_time_extensions_used")) == 1
			and not bool(level.get("_time_extension_offer_active"))
			and not bool(level.get("_level_paused")),
		"The successful extension consumes the coin slot and resumes gameplay."
	)
	_check(_progress.get_lives() == starting_lives, "Continuing does not spend a life.")

	var time_extension_spends := 0
	for raw_operation in _progress.get("_local_store").get_journal() as Array:
		var operation := raw_operation as Dictionary
		var payload := operation.get("payload", {}) as Dictionary
		if (
			str(operation.get("operation_type", "")) == "resource_spend"
			and str(payload.get("asset", "")) == "coins"
			and str(payload.get("reason", "")) == "time_extension"
		):
			time_extension_spends += 1
	_check(time_extension_spends == 1, "The offline journal records one time_extension spend reason.")

	level.set("_time_remaining", 0.0)
	level.call("_handle_level_time_expired")
	await _wait_seconds(0.35)
	_check(
		bool(level.get("_level_failed")) and level.get("_failure_screen").visible,
		"With the coin slot consumed and ads unsupported, the next timeout fails immediately."
	)
	_check(_progress.get_lives() == starting_lives - 1, "The terminal second timeout spends one life.")
	await _free_current_scene()


func _test_insufficient_coins_shop_round_trip() -> void:
	_progress.reset_progress()
	var starting_coins: int = _progress.get_coins()
	var starting_lives: int = _progress.get_lives()
	var level := await _open_campaign_level()
	level.set("_time_remaining", 0.0)
	level.call("_handle_level_time_expired")
	await _wait_seconds(0.3)
	level.call("_on_time_extension_coin_requested")
	await _wait_seconds(0.35)

	var modal = level.get("_time_up_extension_overlay")
	var shop = level.get("_in_level_shop_overlay")
	_check(shop.visible and modal.visible, "Insufficient coins opens Shop above the paused offer.")
	_check(
		level.get("_in_level_shop_return_destination") == &"time_extension",
		"The Shop records the timeout modal as its return destination."
	)
	_check(
		_progress.get_coins() == starting_coins
			and int(level.get("_coin_time_extensions_used")) == 0,
		"Opening Shop neither spends coins nor consumes the extension slot."
	)

	level.call("_on_in_level_shop_close_requested")
	await _wait_seconds(0.45)
	_check(not shop.visible and modal.visible, "Closing Shop restores the same timeout offer.")
	_check(
		bool(level.get("_time_extension_offer_active")) and bool(level.get("_level_paused")),
		"Returning from Shop preserves the paused recoverable timeout state."
	)
	_check(_progress.get_lives() == starting_lives, "The Shop round trip does not spend a life.")
	await _free_current_scene()


func _open_campaign_level() -> Node:
	var level := _level_scene.instantiate()
	level.set("selected_level", TEST_LEVEL)
	level.set("launched_from_dev_mode", false)
	level.set("return_menu_scene_path", "res://scenes/main_menu.tscn")
	root.add_child(level)
	current_scene = level
	await process_frame
	return level


func _free_current_scene() -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
