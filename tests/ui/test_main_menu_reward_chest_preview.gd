extends SceneTree

## Runs the Main Menu reward-chest preview through one full fill and opening. The checks observe the
## real production menu inside the preview rather than duplicating its timing.
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ui/test_main_menu_reward_chest_preview.gd

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const PREVIEW_SCENE_PATH := "res://scenes/testing/main_menu_reward_chest_preview.tscn"
const FAST_TIMINGS := [
	"lift_duration", "auto_open_delay", "reveal_pop_duration", "reveal_hold",
	"coin_scatter_duration", "coin_flight_duration", "ability_flight_duration", "return_duration",
]
const RUN_TIMEOUT_SECONDS := 10.0

var _failures: Array[String] = []
var _star_arrivals := 0


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Main Menu reward chest preview verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress := root.get_node_or_null(^"PlayerProgress")
	if progress == null:
		push_error("PlayerProgress autoload is required.")
		quit(1)
		return
	progress.call("reset_progress")

	var saved_coins: int = progress.call("get_coins")
	var saved_chest: Dictionary = progress.call("get_reward_chest_progress")
	var saved_abilities: Dictionary = progress.call("get_ability_uses")

	var preview := (load(PREVIEW_SCENE_PATH) as PackedScene).instantiate() as Control
	preview.set("autoplay", false)
	root.add_child(preview)
	current_scene = preview
	await process_frame
	await process_frame

	var menu := preview.get_node("%MainMenu") as Control
	var ceremony := menu.get_node("%RewardChestOpenCeremony") as Control
	for property in FAST_TIMINGS:
		ceremony.set(property, 0.05)
	var replay_button := preview.get_node("%ReplayButton") as Button
	var chest_bar := menu.get_node("%RewardChest").get_node("%ProgressBar") as ProgressBar
	menu.get_node("%RewardStarFlyer").connect("star_arrived", func() -> void: _star_arrivals += 1)

	preview.call("play_preview")
	_check(bool(preview.call("is_playing")), "Play starts the preview.")
	_check(replay_button.disabled, "Replay is disabled while the preview plays.")
	preview.call("play_preview")

	var deadline := Time.get_ticks_msec() + int(RUN_TIMEOUT_SECONDS * 1000.0)
	var saw_ceremony := false
	while bool(preview.call("is_playing")) and Time.get_ticks_msec() < deadline:
		saw_ceremony = saw_ceremony or ceremony.visible
		await process_frame
	_check(not bool(preview.call("is_playing")), "The preview finishes within %.0f seconds." % RUN_TIMEOUT_SECONDS)
	_check(saw_ceremony, "The filled chest plays the opening sequence.")
	_check(not replay_button.disabled, "Replay is available again once the opening finishes.")
	_check(
		_star_arrivals == int(preview.get("stars_per_run")),
		"Every star in the run lands on the chest (%d arrivals)." % _star_arrivals
	)

	await create_timer(0.6).timeout
	var next_goal: int = progress.call("get_reward_chest_goal_at_index", 1)
	_check(
		int(chest_bar.value) == int(preview.get("overflow_stars"))
			and int(chest_bar.max_value) == next_goal,
		"The chest refills to the preview's carry-over on the next goal."
	)
	var coin_widget := menu.get_node("%TopStatusBar").get_node(
		"MainMenuTopStatus/CoinsWidget"
	).get_node("%CoinBalanceWidget")
	_check(
		int(coin_widget.get("_amount")) == saved_coins,
		"The coin counter settles on the unchanged saved balance."
	)
	_check(
		int(progress.call("get_coins")) == saved_coins
			and progress.call("get_reward_chest_progress") == saved_chest
			and progress.call("get_ability_uses") == saved_abilities,
		"Running the preview never changes saved progress."
	)

	preview.queue_free()
	current_scene = null
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Main Menu reward chest preview verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
