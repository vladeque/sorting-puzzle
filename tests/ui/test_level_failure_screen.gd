extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"
const TEST_LEVEL := 2

var _failures: Array[String] = []
var _progress
var _level_scene: PackedScene


class FakeRewardedLifeClient extends RefCounted:
	var claim_count := 0

	func can_offer() -> bool:
		return true

	func is_awaiting_verification() -> bool:
		return false

	func claim() -> Dictionary:
		claim_count += 1
		return {
			"ok": true,
			"life_state": {
				"current": 1,
				"maximum": 5,
				"restore_interval_seconds": 3600,
				"next_restore_at": Time.get_datetime_string_from_unix_time(
					int(Time.get_unix_time_from_system()) + 3600
				) + ".000Z",
			},
		}


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Level failure verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	# These assertions verify the English baseline regardless of the device locale.
	TranslationServer.set_locale("en")
	await process_frame
	_progress = root.get_node_or_null("PlayerProgress")
	_level_scene = load(LEVEL_SCENE_PATH) as PackedScene
	_check(_progress != null, "PlayerProgress autoload is available.")
	_check(_level_scene != null, "The level scene loads for failure verification.")
	if _progress == null or _level_scene == null:
		quit(1)
		return

	await _test_retry_with_available_life()
	await _test_zero_lives_close_returns_to_menu()
	await _test_zero_lives_purchase_restarts_level()
	await _test_failed_purchase_returns_to_menu()
	await _test_rewarded_life_restarts_failed_level_once()

	if _failures.is_empty():
		print("Level failure verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_retry_with_available_life() -> void:
	_progress.reset_progress()
	var starting_lives: int = _progress.get_lives()
	var level := await _open_campaign_level()
	level.call("_fail_level")
	await _wait_seconds(0.35)
	_check(
		_progress.get_lives() == starting_lives - 1,
		"Failing the run spends exactly one campaign life before Retry."
	)

	var failure = level.get("_failure_screen")
	(failure.get_node("%RetryButton") as Button).pressed.emit()
	await _wait_for_level_transition(level)
	var restarted := current_scene
	_check(restarted != null and restarted != level, "Retry replaces the failed run with a fresh level scene.")
	_check(
		int(restarted.get("selected_level")) == TEST_LEVEL
			and not bool(restarted.get("launched_from_dev_mode")),
		"Immediate Retry preserves the campaign level and launch mode."
	)
	_check(
		not bool(restarted.get("_loading_transition_pending")),
		"Retry activates gameplay only after the loading reveal completes."
	)
	_check(
		_progress.get_lives() == starting_lives - 1,
		"Starting the retry does not spend another life before its outcome."
	)
	await _free_current_scene()


func _test_zero_lives_close_returns_to_menu() -> void:
	_progress.reset_progress()
	_drain_to_one_life()
	var level := await _open_campaign_level()
	level.call("_fail_level")
	await _wait_seconds(0.35)
	_check(_progress.get_lives() == 0, "The last life is consumed by the failed run.")

	var failure = level.get("_failure_screen")
	(failure.get_node("%RetryButton") as Button).pressed.emit()
	await _wait_seconds(0.35)
	var lives_modal = level.get("_out_of_lives_overlay")
	_check(lives_modal.visible, "Retry at zero lives opens OutOfLivesMenu.")
	_check(not failure.visible, "OutOfLivesMenu replaces the Failure modal instead of stacking two X buttons.")
	_check(
		lives_modal.find_child("TitleLabel", true, false).text == "OUT OF LIVES",
		"The retry recovery modal shows the zero-lives state."
	)

	(lives_modal.find_child("CloseButton", true, false) as Button).pressed.emit()
	await _wait_seconds(0.3)
	_check(
		current_scene != null and current_scene != level and current_scene.name == "ProductionMainMenu",
		"Declining the life offer returns the player to the configured main menu."
	)
	await _free_current_scene()


func _test_zero_lives_purchase_restarts_level() -> void:
	_progress.reset_progress()
	var grant: Dictionary = _progress.apply_shop_purchase(
		"failure-retry-life-purchase-coins",
		{"coins": 700}
	)
	_check(bool(grant.get("ok", false)), "Test setup grants enough coins for a retry life.")
	_drain_to_one_life()
	var starting_coins: int = _progress.get_coins()
	var level := await _open_campaign_level()
	level.set("return_menu_scene_path", "res://scenes/main_menu_testing.tscn")
	level.call("_fail_level")
	await _wait_seconds(0.35)

	var failure = level.get("_failure_screen")
	(failure.get_node("%RetryButton") as Button).pressed.emit()
	await _wait_seconds(0.35)
	var lives_modal = level.get("_out_of_lives_overlay")
	(lives_modal.get_node("%PurchaseButton") as Button).pressed.emit()
	await _wait_for_level_transition(level)

	var restarted := current_scene
	_check(restarted != null and restarted != level, "Buying a retry life starts a fresh level scene.")
	_check(
		int(restarted.get("selected_level")) == TEST_LEVEL
			and str(restarted.get("return_menu_scene_path")) == "res://scenes/main_menu_testing.tscn",
		"Purchased Retry preserves the level number and originating menu route."
	)
	_check(_progress.get_lives() == 1, "The purchase grants exactly one life for the new attempt.")
	_check(
		_progress.get_coins() == starting_coins - _progress.get_life_purchase_coin_price(),
		"The purchased retry spends exactly the configured life price."
	)
	await _free_current_scene()


func _test_failed_purchase_returns_to_menu() -> void:
	_progress.reset_progress()
	_drain_to_one_life()
	var starting_coins: int = _progress.get_coins()
	var level := await _open_campaign_level()
	level.call("_fail_level")
	await _wait_seconds(0.35)
	var failure = level.get("_failure_screen")
	(failure.get_node("%RetryButton") as Button).pressed.emit()
	await _wait_seconds(0.35)
	var lives_modal = level.get("_out_of_lives_overlay")
	(lives_modal.get_node("%PurchaseButton") as Button).pressed.emit()
	await _wait_seconds(0.3)

	_check(
		current_scene != null and current_scene != level and current_scene.name == "ProductionMainMenu",
		"An unaffordable retry purchase returns the player to the main menu."
	)
	_check(
		_progress.get_lives() == 0 and _progress.get_coins() == starting_coins,
		"A failed retry purchase changes neither lives nor coins."
	)
	await _free_current_scene()


func _test_rewarded_life_restarts_failed_level_once() -> void:
	_progress.reset_progress()
	_drain_to_one_life()
	var starting_coins: int = _progress.get_coins()
	var level := await _open_campaign_level()
	var old_client = level.get("_rewarded_life_client")
	var fake_client := FakeRewardedLifeClient.new()
	level.set("_rewarded_life_client", fake_client)
	if old_client != null:
		old_client.queue_free()
	level.call("_fail_level")
	await _wait_seconds(0.35)
	var failure = level.get("_failure_screen")
	(failure.get_node("%RetryButton") as Button).pressed.emit()
	await _wait_seconds(0.35)
	var lives_modal = level.get("_out_of_lives_overlay")
	level.call("_refresh_retry_out_of_lives_offer")
	var rewarded_button := lives_modal.get_node("%RewardedAdButton") as Button
	_check(not rewarded_button.disabled, "A ready rewarded-life client enables failed-level recovery.")
	rewarded_button.pressed.emit()
	await _wait_for_level_transition(level)
	var restarted := current_scene
	_check(restarted != null and restarted != level, "A verified rewarded life restarts the failed level.")
	_check(fake_client.claim_count == 1, "Failed-level recovery consumes one verified grant.")
	_check(_progress.get_lives() == 1, "The retry mirrors the authoritative rewarded life state.")
	_check(_progress.get_coins() == starting_coins, "Rewarded retry spends no coins.")
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


func _drain_to_one_life() -> void:
	while _progress.get_lives() > 1:
		_check(_progress.spend_life(), "Test setup can drain lives to one.")


func _free_current_scene() -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _wait_for_level_transition(previous_scene: Node, timeout_seconds := 4.0) -> void:
	var transition := root.get_node_or_null("LevelTransition")
	_check(transition != null, "LevelTransition autoload is available.")
	if transition == null:
		return
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while (
		current_scene == previous_scene
		and not bool(transition.call("is_transitioning"))
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	while bool(transition.call("is_transitioning")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not bool(transition.call("is_transitioning")), "Level transition finishes before timeout.")
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
