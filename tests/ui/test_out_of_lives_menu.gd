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
	var coming_soon := modal.get_node("%ComingSoonButton") as Button
	_check(
		coming_soon.visible and coming_soon.disabled and coming_soon.text == "Coming Soon",
		"The Coming Soon action remains visible and disabled."
	)

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
	await _wait_seconds(0.4)
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


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
