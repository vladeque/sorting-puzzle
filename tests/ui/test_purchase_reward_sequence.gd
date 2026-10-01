extends SceneTree

## Verifies the purchase reward sequence on its own and as the Shop and Main Menu drive it: rewards
## pop in from the purchased offer, a tap only skips the hold once they have landed, every coin and
## booster flight reports its landing, the coin counters count up to the saved balance, the Shop's
## boosters land on the Home tab, and nothing in the sequence touches saved progress.
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ui/test_purchase_reward_sequence.gd

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const SEQUENCE_SCENE_PATH := "res://scenes/ui/purchase_reward_sequence.tscn"
const SHOP_SCENE_PATH := "res://scenes/ui/shop_screen.tscn"
const IN_LEVEL_SHOP_SCENE_PATH := "res://scenes/ui/in_level_shop_screen.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const FAST_TIMINGS := ["intro_duration", "outro_duration"]
const FAST_ROW_TIMINGS := [
	"reveal_pop_duration", "coin_scatter_duration", "coin_flight_duration", "ability_flight_duration",
]
const ALL_ABILITIES := {"hammer": 2, "shuffle": 1, "highlight": 1, "freezer": 1}
const FINISH_TIMEOUT_SECONDS := 6.0

var _failures: Array[String] = []
var _progress: Node
var _finished_count := 0
var _coin_arrivals: Array[Vector2i] = []
var _ability_arrivals: Array[StringName] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Purchase reward sequence verification must run through run_isolated_godot_test.ps1.")
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
	ProjectSettings.set_setting("application/config/mock_store_country", "US")
	_progress.call("reset_progress")

	await _test_reveal_waits_for_landing_then_delivers()
	await _test_nothing_to_show()
	await _test_shop_destination_purchase()
	await _test_in_level_shop_purchase()
	await _test_main_menu_defers_chest_opening()
	_finish()


func _test_reveal_waits_for_landing_then_delivers() -> void:
	# A slow pop shows where each reward starts before it settles into the row.
	var origin_probe := _make_sequence(10.0)
	var probe_row := origin_probe.get_node("%RewardRow") as Control
	probe_row.set("reveal_pop_duration", 20.0)
	probe_row.set("reveal_stagger", 0.0)
	origin_probe.call(
		"play",
		{"coins": 100, "abilities": {"hammer": 1}},
		{"coins": Rect2(40, 900, 80, 80), "hammer": Rect2(560, 1000, 60, 60)},
		Vector2(600, 60),
		Vector2(360, 1200)
	)
	await process_frame
	await process_frame
	_check(
		(probe_row.get_node("%CoinVisual") as Control).get_global_rect().get_center().distance_to(
			Vector2(80, 940)
		) < 40.0,
		"The coins start on the purchased offer's coin art."
	)
	_check(
		(probe_row.get_node("%HammerReward") as Control).get_global_rect().get_center().distance_to(
			Vector2(590, 1030)
		) < 40.0,
		"Each booster starts on its own icon on the purchased offer."
	)
	await _free(origin_probe)

	var coins_before: int = _progress.call("get_coins")
	var sequence := _make_sequence(10.0)
	var row := sequence.get_node("%RewardRow") as Control
	row.set("reveal_pop_duration", 0.3)
	sequence.call(
		"play",
		{"coins": 100, "abilities": ALL_ABILITIES},
		{"coins": Rect2(40, 900, 80, 80), "hammer": Rect2(200, 900, 60, 60)},
		Vector2(600, 60),
		Vector2(360, 1200)
	)
	_check(sequence.visible, "Playing shows the sequence.")
	_check(
		sequence.mouse_filter == Control.MOUSE_FILTER_STOP,
		"The sequence swallows taps so nothing underneath can be pressed."
	)
	_check(
		str(sequence.get_node("%Banner").call("get_text")) == "PURCHASE COMPLETE",
		"The ribbon confirms the purchase."
	)
	await process_frame
	await process_frame

	sequence.call("_gui_input", _make_tap())
	await process_frame
	_check(
		_coin_arrivals.is_empty() and bool(sequence.call("is_playing")),
		"A tap while rewards are still popping in does not launch the flights."
	)
	await create_timer(0.7).timeout
	_check(
		(sequence.get_node("%TapHint") as Control).visible,
		"The tap prompt appears once every reward has landed in the row."
	)
	_check(
		(row.get_node("%HammerReward").get("_count") as int) == 2,
		"The hammer chip shows the granted count."
	)
	sequence.call("_gui_input", _make_tap())
	await _await_finished()
	_check(_finished_count == 1, "The sequence finishes exactly once.")
	_check(not sequence.visible, "The sequence hides when it finishes.")
	_check(
		_coin_arrivals.size() == 5 and _coin_arrivals.back() == Vector2i(5, 5),
		"100 coins fly as five coins, the last reporting 5 of 5 (got %s)." % [_coin_arrivals]
	)
	_check(_ability_arrivals.size() == 4, "Each granted booster flies once (got %d)." % _ability_arrivals.size())
	await process_frame
	_check(
		(sequence.get_node("%FlyerLayer") as Control).get_child_count() == 0,
		"Every flying reward is freed once it lands."
	)
	_check(
		int(_progress.call("get_coins")) == coins_before,
		"The sequence is presentation only and never changes saved progress."
	)
	await _free(sequence)


func _test_nothing_to_show() -> void:
	var sequence := _make_sequence(0.05)
	sequence.call("play", {"coins": 0, "abilities": {}}, {}, Vector2.ZERO, Vector2.ZERO)
	_check(not sequence.visible, "A grant with nothing in it shows nothing.")
	await _await_finished()
	_check(_finished_count == 1, "An empty grant still reports finished, on the next frame.")

	_connect(sequence)
	sequence.call("play", {"abilities": {"freezer": 3}}, {}, Vector2.ZERO, Vector2(360, 1200))
	await _await_finished()
	_check(_coin_arrivals.is_empty(), "No coin flies for a booster-only grant.")
	_check(
		_ability_arrivals.size() == 1 and _ability_arrivals[0] == &"freezer",
		"Only the granted booster flies (got %s)." % [_ability_arrivals]
	)
	await _free(sequence)


func _test_shop_destination_purchase() -> void:
	_progress.call("reset_progress")
	var shop := (load(SHOP_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(shop)
	current_scene = shop
	await create_timer(0.3).timeout
	var sequence := shop.get_node("%PurchaseRewardSequence") as Control
	_speed_up(sequence, 0.05)
	_connect(sequence)
	var coin_widget := shop.get_node("%CoinBalance")
	var navigation := shop.get_node("%BottomNavigation")
	var coins_before: int = _progress.call("get_coins")

	shop.call("_purchase_offer", &"new_player_bundle")
	await _await_playing(sequence)
	var saved_coins: int = _progress.call("get_coins")
	_check(saved_coins == coins_before + 2500, "The Basic Bundle grants its coins before the reveal.")
	_check(bool(sequence.call("is_playing")), "A granted purchase plays the reward sequence.")
	_check(
		not (shop.get_node("%PurchaseDialog") as Control).visible,
		"The reward sequence replaces the purchase-complete dialog."
	)
	_check(
		int(coin_widget.get("_amount")) == coins_before,
		"The header counter holds back the purchased coins until they fly in."
	)
	_check(
		(sequence.get("_ability_target_global") as Vector2).distance_to(
			navigation.call("get_tab_icon_global_center", &"home") as Vector2
		) < 1.0,
		"Boosters fly to the Home tab."
	)
	shop.call("handle_back")
	_check(
		not bool(shop.get("_is_navigating")),
		"Back during the reveal skips its hold instead of leaving the Shop."
	)
	shop.call("_purchase_offer", &"coins_100")
	await _await_finished()
	_check(
		int(_progress.call("get_coins")) == saved_coins,
		"A purchase pressed during the reveal is ignored."
	)
	_check(
		int(coin_widget.get("_amount")) == saved_coins,
		"The header counter reaches the saved balance once every coin lands."
	)
	_check(_ability_arrivals.size() == 4, "All four bundle boosters land on Home.")
	_check(
		not bool(shop.get("_purchase_in_progress")),
		"The Shop accepts purchases again after the reveal."
	)

	shop.queue_free()
	current_scene = null
	await process_frame


func _test_in_level_shop_purchase() -> void:
	_progress.call("reset_progress")
	var shop := (load(IN_LEVEL_SHOP_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(shop)
	await process_frame
	shop.call("open")
	await create_timer(0.4).timeout
	var sequence := shop.get_node("%PurchaseRewardSequence") as Control
	_speed_up(sequence, 0.05)
	_connect(sequence)
	var close_requests := [0]
	shop.connect("close_requested", func() -> void: close_requests[0] += 1)

	shop.call("_purchase_offer", &"coins_100")
	await _await_playing(sequence)
	var close_button := shop.get_node("%OverlayCloseButton") as Button
	_check(close_button.disabled, "The overlay's close button stays locked during the reveal.")
	shop.call("_request_overlay_close")
	_check(close_requests[0] == 0, "The overlay cannot be closed out from under the reveal.")
	var target := sequence.get("_ability_target_global") as Vector2
	_check(
		target.y > shop.get_global_rect().end.y - 200.0,
		"Without a Home tab, boosters drop toward the level's ability bar at the bottom."
	)
	await _await_finished()
	_check(not close_button.disabled, "The overlay's close button unlocks after the reveal.")
	_check(_coin_arrivals.size() == 5, "The coin pack's coins fly into the overlay's counter.")

	shop.queue_free()
	await process_frame


func _test_main_menu_defers_chest_opening() -> void:
	_progress.call("reset_progress")
	var menu := (load(MAIN_MENU_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	var sequence := menu.get_node("%PurchaseRewardSequence") as Control
	var ceremony := menu.get_node("%RewardChestOpenCeremony") as Control
	for property in ["lift_duration", "auto_open_delay", "reveal_hold", "return_duration"]:
		ceremony.set(property, 0.04)
	for property in FAST_ROW_TIMINGS:
		ceremony.get_node("%RewardPanel").set(property, 0.04)
	var ceremony_finished := [false]
	ceremony.connect("finished", func() -> void: ceremony_finished[0] = true)
	_speed_up(sequence, 0.05)
	_connect(sequence)
	var saved_coins: int = _progress.call("get_coins")

	menu.set("_purchase_coin_holdback", 300)
	menu.set("_undisplayed_purchase_coins", 300)
	menu.call("_update_coin_balance")
	sequence.call("play", {"coins": 300, "abilities": {"hammer": 1}}, {}, Vector2(400, 60), Vector2(360, 1000))
	await _await_playing(sequence)
	menu.call("_queue_chest_ceremony_rewards", 0)
	menu.set("_chest_full_hold_goal", int(_progress.call("get_reward_chest_goal_at_index", 0)))
	menu.call("_on_reward_star_animation_finished")
	_check(not ceremony.visible, "A chest goal filled during a purchase reveal waits for it.")
	var ui_cancel := InputEventAction.new()
	ui_cancel.action = &"ui_cancel"
	ui_cancel.pressed = true
	menu.call("_unhandled_input", ui_cancel)
	_check(sequence.visible, "Back does not dismiss the purchase reveal.")

	await _await_finished()
	_check(ceremony.visible, "The chest opening plays once the purchase reveal finishes.")
	var coin_widget := menu.get_node("%TopStatusBar").get_node(
		"MainMenuTopStatus/CoinsWidget"
	).get_node("%CoinBalanceWidget")
	_check(
		int(coin_widget.get("_amount")) == saved_coins,
		"The Main Menu counter settles on the saved balance after the purchase reveal."
	)
	var deadline := Time.get_ticks_msec() + int(FINISH_TIMEOUT_SECONDS * 1000.0)
	while not ceremony_finished[0] and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(ceremony_finished[0], "The deferred chest opening plays through.")

	menu.queue_free()
	current_scene = null
	await process_frame
	_progress.call("reset_progress")


func _make_sequence(reveal_hold: float) -> Control:
	var sequence := (load(SEQUENCE_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(sequence)
	_speed_up(sequence, reveal_hold)
	_connect(sequence)
	return sequence


func _speed_up(sequence: Control, reveal_hold: float) -> void:
	for property in FAST_TIMINGS:
		sequence.set(property, 0.04)
	sequence.set("reveal_hold", reveal_hold)
	var row := sequence.get_node("%RewardRow")
	for property in FAST_ROW_TIMINGS:
		row.set(property, 0.04)
	row.set("coin_stagger", 0.01)
	row.set("ability_stagger", 0.01)
	row.set("reveal_stagger", 0.01)


func _connect(sequence: Control) -> void:
	_finished_count = 0
	_coin_arrivals.clear()
	_ability_arrivals.clear()
	if sequence.has_meta(&"_test_connected"):
		return
	sequence.set_meta(&"_test_connected", true)
	sequence.connect("finished", func() -> void: _finished_count += 1)
	sequence.connect(
		"coin_arrived",
		func(arrived: int, total: int) -> void: _coin_arrivals.append(Vector2i(arrived, total))
	)
	sequence.connect(
		"ability_arrived", func(ability_id: StringName) -> void: _ability_arrivals.append(ability_id)
	)


func _make_tap() -> InputEventMouseButton:
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	return tap


## Waits for the (mock) purchase to resolve and the sequence to start, without hanging the run.
func _await_playing(sequence: Control) -> void:
	var deadline := Time.get_ticks_msec() + int(FINISH_TIMEOUT_SECONDS * 1000.0)
	while not bool(sequence.call("is_playing")) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not bool(sequence.call("is_playing")):
		_failures.append("The purchase reward sequence did not start.")


## Waits for `finished` without hanging the run if the sequence stalls.
func _await_finished() -> void:
	var deadline := Time.get_ticks_msec() + int(FINISH_TIMEOUT_SECONDS * 1000.0)
	while _finished_count == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if _finished_count == 0:
		_failures.append("The sequence did not finish within %.1f seconds." % FINISH_TIMEOUT_SECONDS)


func _free(node: Node) -> void:
	node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Purchase reward sequence verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
