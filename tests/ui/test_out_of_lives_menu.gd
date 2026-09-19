extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const TEST_RESOLUTIONS := [
	Vector2(540, 960),
	Vector2(720, 1280),
	Vector2(1080, 1920),
	Vector2(1080, 2400),
	Vector2(1200, 1600),
]

var _failures: Array[String] = []


class FakeRewardedLifeClient extends RefCounted:
	var claim_count := 0
	var result := {
		"ok": true,
		"life_state": {
			"current": 1,
			"maximum": 5,
			"restore_interval_seconds": 3600,
			"next_restore_at": "2026-09-20T12:00:00.000Z",
		},
	}

	func can_offer() -> bool:
		return true

	func is_awaiting_verification() -> bool:
		return false

	func claim() -> Dictionary:
		claim_count += 1
		return result.duplicate(true)


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Out-of-lives verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress = root.get_node_or_null("PlayerProgress")
	_check(progress != null, "PlayerProgress autoload is available.")
	if progress == null:
		quit(1)
		return

	await _test_modal_and_successful_purchase(progress)
	await _test_insufficient_coins_open_shop(progress)
	await _test_lives_widget_at_full_lives(progress)
	await _test_lives_widget_purchase_stays_in_menu(progress)
	await _test_rewarded_life_resumes_pending_launch_once(progress)

	if _failures.is_empty():
		print("Out-of-lives menu verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_modal_and_successful_purchase(progress) -> void:
	progress.reset_progress()
	var grant: Dictionary = progress.apply_shop_purchase(
		"out-of-lives-test-coins",
		{"coins": 700}
	)
	_check(bool(grant.get("ok", false)), "Test setup grants enough coins for one life.")
	_drain_lives(progress)
	var starting_coins: int = progress.get_coins()

	var menu := await _open_main_menu()
	var level_button := menu.get_node("%LevelButton") as Button
	_check(not level_button.disabled, "The level button remains enabled at zero lives.")
	_check(level_button.text == "LEVEL 1", "The zero-lives level button keeps its level label.")
	level_button.emit_signal("pressed")
	await _wait_seconds(0.3)

	var modal := menu.get_node("%OutOfLivesMenu") as Control
	_check(modal.visible, "Pressing the level button at zero lives opens the modal.")
	_check(modal.z_index > level_button.z_index, "The modal renders above the level action.")
	_check(
		modal.find_child("TitleLabel", true, false).text == "OUT OF LIVES",
		"The modal uses the approved Out of Lives title."
	)
	var heart := modal.find_child("HeartIcon", true, false) as TextureRect
	_check(
		heart.texture != null
			and heart.texture.resource_path == "res://assets/ui/main_menu_lives.png",
		"The modal reuses the Main Menu lives art."
	)
	_check(
		modal.get_node("%LifeCountLabel").text == "0",
		"The heart displays a zero life count."
	)
	_check(
		modal.get_node("%PriceLabel").text == "500",
		"The purchase action displays the configured 500-coin price."
	)
	var rewarded_ad := modal.get_node("%RewardedAdButton") as Button
	_check(
		rewarded_ad.visible and rewarded_ad.disabled and rewarded_ad.text == "Watch Ad",
		"The rewarded-life action fails closed when the provider is unavailable."
	)
	_check(modal.has_signal("rewarded_ad_requested"), "The modal owns a dedicated rewarded-ad intent signal.")
	modal.call("set_rewarded_action_state", &"loading", false)
	_check(rewarded_ad.disabled and rewarded_ad.text == "Loading...", "The modal exposes an explicit loading state.")
	modal.call("set_rewarded_action_state", &"error", true)
	_check(
		not rewarded_ad.disabled
			and rewarded_ad.text == "Try Again"
			and (modal.get_node("%RewardStatusLabel") as Label).visible,
		"The modal exposes a retryable error state with player-facing feedback."
	)
	modal.call("set_rewarded_action_state", &"unavailable", false)

	var shell := modal.get_node("%Shell")
	var outer := shell.get_node("%OuterPanel") as Control
	for viewport_size in TEST_RESOLUTIONS:
		modal.call("apply_safe_layout", Vector4(18, 32, 18, 28), viewport_size)
		var outer_rect := outer.get_global_rect()
		_check(
			outer_rect.position.x >= 18.0
				and outer_rect.position.y >= 32.0
				and outer_rect.end.x <= viewport_size.x - 18.0
				and outer_rect.end.y <= viewport_size.y - 28.0,
			"The modal stays inside safe bounds at %s." % viewport_size
		)

	var purchase_button := modal.get_node("%PurchaseButton") as Button
	purchase_button.emit_signal("pressed")
	await _wait_for_level_transition(menu)
	_check(current_scene != menu, "A successful purchase launches the originally requested level.")
	_check(progress.get_lives() == 1, "A successful purchase grants exactly one life.")
	_check(
		progress.get_coins() == starting_coins - 500,
		"A successful purchase spends exactly the configured 500 coins."
	)
	var journal := progress.get("_local_store").get_journal() as Array
	var purchase_operations := journal.filter(func(operation):
		return str((operation as Dictionary).get("operation_type", "")) == "life_purchase"
	)
	_check(purchase_operations.size() == 1, "The purchase persists one atomic journal operation.")
	if purchase_operations.size() == 1:
		var payload := (purchase_operations[0] as Dictionary).get("payload", {}) as Dictionary
		_check(
			int(payload.get("coin_price", 0)) == 500
				and int(payload.get("lives_granted", 0)) == 1
				and int(payload.get("available_lives", 0)) == 1,
			"The atomic journal operation records the matching coin price and life state."
		)
	if current_scene != null:
		current_scene.queue_free()
	await process_frame


func _test_insufficient_coins_open_shop(progress) -> void:
	progress.reset_progress()
	_drain_lives(progress)
	var starting_coins: int = progress.get_coins()
	var menu := await _open_main_menu()
	(menu.get_node("%LevelButton") as Button).emit_signal("pressed")
	await _wait_seconds(0.3)
	var modal := menu.get_node("%OutOfLivesMenu") as Control
	(modal.get_node("%PurchaseButton") as Button).emit_signal("pressed")
	await _wait_seconds(0.2)
	_check(
		current_scene != menu and current_scene.name == "ShopScreen",
		"An unaffordable purchase opens the Shop."
	)
	_check(progress.get_lives() == 0, "An unaffordable purchase does not grant a life.")
	_check(progress.get_coins() == starting_coins, "An unaffordable purchase does not spend coins.")
	if current_scene != null:
		current_scene.queue_free()
	await process_frame


func _test_lives_widget_at_full_lives(progress) -> void:
	progress.reset_progress()
	var starting_coins: int = progress.get_coins()
	_check(
		progress.get_lives() == progress.get_max_lives(),
		"Test setup starts the full-lives case at the life cap."
	)

	var menu := await _open_main_menu()
	var lives_widget := menu.get_node(
		"TopStatusBar/MainMenuTopStatus/LivesWidget"
	) as Button
	_check(lives_widget != null, "The top status lives widget is a pressable button.")
	if lives_widget == null:
		if current_scene != null:
			current_scene.queue_free()
		await process_frame
		return

	lives_widget.emit_signal("pressed")
	await _wait_seconds(0.3)

	var modal := menu.get_node("%OutOfLivesMenu") as Control
	_check(modal.visible, "Pressing the lives widget at full lives opens the lives modal.")
	_check(
		modal.find_child("TitleLabel", true, false).text == "LIVES FULL",
		"The full-lives modal is titled LIVES FULL."
	)
	_check(
		modal.get_node("%LifeCountLabel").text == str(progress.get_max_lives()),
		"The full-lives modal shows the capped life count."
	)
	_check(
		not (modal.get_node("%TimerCenter") as Control).visible,
		"The full-lives modal hides the next-life countdown."
	)
	_check(
		(modal.get_node("%MessageCenter") as Control).visible
			and (modal.get_node("%FullLivesLabel") as Label).text
				== "Your lives are full! Play a level to spend them.",
		"The full-lives modal explains that lives are spent by playing levels."
	)
	var got_it := modal.get_node("%GotItButton") as Button
	_check(
		got_it.visible
			and not got_it.disabled
			and got_it.text == "Got it"
			and not (modal.get_node("%PurchaseButton") as Button).visible
			and not (modal.get_node("%RewardedAdButton") as Button).visible,
		"The full-lives modal offers a single enabled Got it action and no purchase."
	)

	got_it.emit_signal("pressed")
	await _wait_seconds(0.4)
	_check(not modal.visible, "Got it closes the full-lives modal.")
	_check(current_scene == menu, "Got it leaves the player on the Main Menu.")
	_check(
		progress.get_lives() == progress.get_max_lives()
			and progress.get_coins() == starting_coins,
		"Got it spends nothing and grants nothing."
	)
	if current_scene != null:
		current_scene.queue_free()
	await process_frame


func _test_lives_widget_purchase_stays_in_menu(progress) -> void:
	progress.reset_progress()
	var grant: Dictionary = progress.apply_shop_purchase(
		"lives-widget-test-coins",
		{"coins": 700}
	)
	_check(bool(grant.get("ok", false)), "Test setup grants enough coins for one life.")
	_check(progress.spend_life(), "Test setup spends one life below the cap.")
	var starting_coins: int = progress.get_coins()
	var starting_lives: int = progress.get_lives()

	var menu := await _open_main_menu()
	var lives_widget := menu.get_node("TopStatusBar/MainMenuTopStatus/LivesWidget") as Button
	lives_widget.emit_signal("pressed")
	await _wait_seconds(0.3)

	var modal := menu.get_node("%OutOfLivesMenu") as Control
	_check(modal.visible, "Pressing the lives widget below the cap opens the lives modal.")
	_check(
		modal.find_child("TitleLabel", true, false).text == "GET MORE LIVES",
		"The below-cap modal opened from the widget is titled GET MORE LIVES."
	)
	var purchase_button := modal.get_node("%PurchaseButton") as Button
	_check(
		(modal.get_node("%TimerCenter") as Control).visible
			and not (modal.get_node("%MessageCenter") as Control).visible
			and purchase_button.visible
			and not (modal.get_node("%GotItButton") as Button).visible,
		"The below-cap modal keeps the countdown and the coin-price purchase action."
	)

	purchase_button.emit_signal("pressed")
	await _wait_seconds(0.4)
	_check(
		current_scene == menu,
		"A purchase from the lives widget never launches a level."
	)
	_check(not modal.visible, "A purchase from the lives widget closes the modal.")
	_check(
		progress.get_lives() == starting_lives + 1,
		"A purchase from the lives widget grants exactly one life."
	)
	_check(
		progress.get_coins() == starting_coins - 500,
		"A purchase from the lives widget spends exactly the configured 500 coins."
	)
	if current_scene != null:
		current_scene.queue_free()
	await process_frame


func _test_rewarded_life_resumes_pending_launch_once(progress) -> void:
	progress.reset_progress()
	_drain_lives(progress)
	var starting_coins: int = progress.get_coins()
	var starting_life_purchase_count := _count_life_purchase_operations(progress)
	var menu := await _open_main_menu()
	var old_client = menu.get("_rewarded_life_client")
	var fake_client := FakeRewardedLifeClient.new()
	menu.set("_rewarded_life_client", fake_client)
	if old_client != null:
		old_client.queue_free()
	menu.call("_refresh_out_of_lives_offer")

	(menu.get_node("%LevelButton") as Button).emit_signal("pressed")
	await _wait_seconds(0.3)
	var modal := menu.get_node("%OutOfLivesMenu") as Control
	var rewarded_button := modal.get_node("%RewardedAdButton") as Button
	_check(
		rewarded_button.visible and not rewarded_button.disabled,
		"A ready rewarded-life client enables Watch Ad."
	)
	rewarded_button.emit_signal("pressed")
	await _wait_for_level_transition(menu)
	_check(current_scene != menu, "A verified rewarded life resumes the interrupted launch.")
	_check(fake_client.claim_count == 1, "The pending launch requests and consumes one verified grant.")
	_check(progress.get_lives() == 1, "The authoritative rewarded state is mirrored locally.")
	_check(progress.get_coins() == starting_coins, "The rewarded route spends no coins.")
	_check(
		_count_life_purchase_operations(progress) == starting_life_purchase_count,
		"The server-settled grant creates no local life-purchase journal entry."
	)
	if current_scene != null:
		current_scene.queue_free()
	await process_frame


func _open_main_menu() -> Control:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for _frame in range(5):
		await process_frame
	return menu


func _drain_lives(progress) -> void:
	while progress.get_lives() > 0:
		_check(progress.spend_life(), "Test setup spends one life.")


func _count_life_purchase_operations(progress) -> int:
	var journal := progress.get("_local_store").get_journal() as Array
	return journal.filter(func(operation):
		return str((operation as Dictionary).get("operation_type", "")) == "life_purchase"
	).size()


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
