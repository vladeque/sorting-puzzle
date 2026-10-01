extends SceneTree

## Verifies the reward-chest opening sequence on its own and as the Main Menu drives it: tap and
## auto-open both open the chest, every coin and ability flight reports its landing, the displayed
## coin balance counts up to the saved balance, and nothing touches saved progress.
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ui/test_reward_chest_open_ceremony.gd

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const CEREMONY_SCENE_PATH := "res://scenes/ui/reward_chest_open_ceremony.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const FAST_TIMINGS := ["lift_duration", "reveal_hold", "return_duration"]
## Flight timings live on the shared reveal row (`%RewardPanel`).
const FAST_ROW_TIMINGS := [
	"reveal_pop_duration", "coin_scatter_duration", "coin_flight_duration", "ability_flight_duration",
]
const ALL_ABILITIES := {"hammer": 1, "shuffle": 1, "highlight": 1, "freezer": 1}
const FINISH_TIMEOUT_SECONDS := 6.0

var _failures: Array[String] = []
var _progress: Node
var _opened_count := 0
var _finished_count := 0
var _coin_arrivals: Array[Vector2i] = []
var _ability_arrivals: Array[StringName] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Reward chest ceremony verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_progress = root.get_node_or_null(^"PlayerProgress")
	if _progress == null:
		push_error("PlayerProgress autoload is required.")
		quit(1)
		return
	_progress.call("reset_progress")

	await _test_tap_opens_and_delivers_everything()
	await _test_auto_open_without_abilities()
	await _test_main_menu_flow()
	_finish()


func _test_tap_opens_and_delivers_everything() -> void:
	var coins_before: int = _progress.call("get_coins")
	var chest_before: Dictionary = _progress.call("get_reward_chest_progress")
	var ceremony := _make_ceremony(10.0)
	ceremony.call(
		"play",
		{"coins": 100, "abilities": ALL_ABILITIES},
		Rect2(20, 200, 116, 116),
		Vector2(420, 60),
		Vector2(360, 1000)
	)
	_check(ceremony.visible, "Playing shows the ceremony.")
	_check(
		ceremony.mouse_filter == Control.MOUSE_FILTER_STOP,
		"The ceremony swallows taps so nothing underneath can be pressed."
	)

	await create_timer(0.4).timeout
	_check(_opened_count == 0, "The chest waits for a tap before its auto-open delay.")
	_check(
		(ceremony.get_node("%TapHint") as Control).visible,
		"The tap prompt shows while the chest waits."
	)

	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	ceremony.call("_gui_input", tap)
	_check(_opened_count == 0, "A tap starts the opening squash before the lid bursts.")
	await create_timer(0.15).timeout
	_check(_opened_count == 1, "A tap opens the waiting chest.")

	await _await_finished(ceremony)
	_check(_finished_count == 1, "The ceremony finishes exactly once.")
	_check(not ceremony.visible, "The ceremony hides when it finishes.")
	_check(
		_coin_arrivals.size() == 5 and _coin_arrivals.back() == Vector2i(5, 5),
		"100 coins fly as five coins, the last reporting 5 of 5 (got %s)." % [_coin_arrivals]
	)
	_check(_ability_arrivals.size() == 4, "All four abilities land on the LEVEL button.")
	for ability_id in ["hammer", "shuffle", "highlight", "freezer"]:
		_check(
			_ability_arrivals.has(StringName(ability_id)),
			"The %s reward lands on the LEVEL button." % ability_id
		)
	await process_frame
	_check(
		(ceremony.get_node("%FlyerLayer") as Control).get_child_count() == 0,
		"Every flying reward is freed once it lands."
	)
	_check(
		int(_progress.call("get_coins")) == coins_before
			and _progress.call("get_reward_chest_progress") == chest_before,
		"The ceremony is presentation only and never changes saved progress."
	)
	await _free(ceremony)


func _test_auto_open_without_abilities() -> void:
	var ceremony := _make_ceremony(0.1)
	ceremony.call("play", {"coins": 900, "abilities": {}}, Rect2(20, 200, 116, 116),
		Vector2(420, 60), Vector2(360, 1000))
	await _await_finished(ceremony)
	_check(_opened_count == 1, "The chest opens on its own after the auto-open delay.")
	_check(
		_coin_arrivals.size() == 12,
		"A large coin reward is capped at twelve flying coins (got %d)." % _coin_arrivals.size()
	)
	_check(_ability_arrivals.is_empty(), "No ability flies when the goal grants none.")
	_check(
		not (ceremony.get_node("%RewardPanel").get_node("%HammerSlot") as Control).visible,
		"Absent ability rewards leave no slot in the reveal row."
	)
	await _free(ceremony)


func _test_main_menu_flow() -> void:
	_progress.call("reset_progress")
	var goal: int = _progress.call("get_reward_chest_goal_at_index", 0)
	var goal_coins: int = _progress.call("get_reward_chest_goal_coin_reward_at_index", 0)
	_progress.call("add_reward_chest_stars", goal - 2)
	var pending := {"amount": 4, "start_stars": goal - 2, "start_goal_index": 0}
	_progress.call("add_reward_chest_stars", 4)
	var saved_coins: int = _progress.call("get_coins")

	var menu := (load(MAIN_MENU_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	var ceremony := menu.get_node("%RewardChestOpenCeremony") as Control
	_speed_up(ceremony, 0.1)
	_connect(ceremony)
	var chest := menu.get_node("%RewardChest") as Control
	var chest_bar := chest.get_node("%ProgressBar") as ProgressBar
	var coin_shortcut := menu.get_node("%TopStatusBar").get_node("MainMenuTopStatus/CoinsWidget")
	var coin_widget := coin_shortcut.get_node("%CoinBalanceWidget")

	menu.call("_prepare_pending_reward_animation", pending)
	_check(
		int(coin_widget.get("_amount")) == saved_coins - goal_coins,
		"The counter holds back the chest's coins until they fly in."
	)
	for _star in range(4):
		menu.call("_on_reward_star_arrived")
	_check(
		int(chest_bar.value) == goal and int(chest_bar.max_value) == goal,
		"The chest widget stays full after the filling star instead of wrapping to the next goal."
	)
	_check(not ceremony.visible, "The opening waits for the star flight to finish.")

	menu.call("_on_reward_star_animation_finished")
	_check(ceremony.visible, "The finished star flight starts the opening.")
	_check(
		is_zero_approx((chest.get_node("Visual/ChestIcon") as Control).modulate.a),
		"The small chest icon hides while its large copy is out."
	)
	var ui_cancel := InputEventAction.new()
	ui_cancel.action = &"ui_cancel"
	ui_cancel.pressed = true
	menu.call("_unhandled_input", ui_cancel)
	_check(ceremony.visible, "Back does not dismiss the opening underneath it.")

	await _await_finished(ceremony)
	_check(
		int(coin_widget.get("_amount")) == saved_coins,
		"The counter reaches the saved balance once every coin lands."
	)
	_check(
		is_equal_approx((chest.get_node("Visual/ChestIcon") as Control).modulate.a, 1.0),
		"The small chest icon returns when the opening ends."
	)
	await create_timer(0.6).timeout
	var saved_chest: Dictionary = _progress.call("get_reward_chest_progress")
	_check(
		int(chest_bar.value) == int(saved_chest.get("stars", -1))
			and int(chest_bar.max_value) == int(saved_chest.get("goal", -1)),
		"The widget refills to the next goal's carried-over stars."
	)
	_check(
		int(_progress.call("get_coins")) == saved_coins,
		"The opening never changes the saved balance."
	)

	menu.queue_free()
	current_scene = null
	await process_frame
	_progress.call("reset_progress")


func _make_ceremony(auto_open_delay: float) -> Control:
	var ceremony := (load(CEREMONY_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(ceremony)
	_speed_up(ceremony, auto_open_delay)
	_connect(ceremony)
	return ceremony


func _speed_up(ceremony: Control, auto_open_delay: float) -> void:
	for property in FAST_TIMINGS:
		ceremony.set(property, 0.04)
	var row := ceremony.get_node("%RewardPanel")
	for property in FAST_ROW_TIMINGS:
		row.set(property, 0.04)
	row.set("coin_stagger", 0.01)
	row.set("ability_stagger", 0.01)
	row.set("reveal_stagger", 0.01)
	ceremony.set("shake_pause", 0.02)
	ceremony.set("auto_open_delay", auto_open_delay)


func _connect(ceremony: Control) -> void:
	_opened_count = 0
	_finished_count = 0
	_coin_arrivals.clear()
	_ability_arrivals.clear()
	ceremony.connect("opened", func() -> void: _opened_count += 1)
	ceremony.connect("finished", func() -> void: _finished_count += 1)
	ceremony.connect(
		"coin_arrived",
		func(arrived: int, total: int) -> void: _coin_arrivals.append(Vector2i(arrived, total))
	)
	ceremony.connect(
		"ability_arrived", func(ability_id: StringName) -> void: _ability_arrivals.append(ability_id)
	)


## Waits for `finished` without hanging the run if the sequence stalls.
func _await_finished(ceremony: Control) -> void:
	var deadline := Time.get_ticks_msec() + int(FINISH_TIMEOUT_SECONDS * 1000.0)
	while _finished_count == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if _finished_count == 0:
		_failures.append("The ceremony did not finish within %.1f seconds." % FINISH_TIMEOUT_SECONDS)


func _free(node: Node) -> void:
	node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Reward chest ceremony verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
