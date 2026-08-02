extends Node

const LEADERBOARD_SCENE := preload("res://scenes/ui/leaderboard_screen.tscn")
const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const TEST_RESOLUTIONS := [
	Vector2i(540, 960),
	Vector2i(720, 1280),
	Vector2i(1080, 1920),
	Vector2i(1080, 2400),
	Vector2i(1200, 1600),
]
const EXPECTED_REWARDS := [
	{
		"amount": "500",
		"texture": "res://assets/ui/shop_coin_offers/shop_coin_offer_tier_04.png",
	},
	{
		"amount": "300",
		"texture": "res://assets/ui/shop_coin_offers/shop_coin_offer_tier_03.png",
	},
	{
		"amount": "300",
		"texture": "res://assets/ui/shop_coin_offers/shop_coin_offer_tier_02.png",
	},
]

var _failures := []


func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error(
			"Leaderboard verification must run through scripts/tools/run_isolated_godot_test.ps1."
		)
		get_tree().quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	ProjectSettings.set_setting("application/config/leaderboard_provider", "mock")
	PlayerProgress.reset_progress()

	var leaderboard := LEADERBOARD_SCENE.instantiate() as Control
	get_tree().root.add_child(leaderboard)
	get_tree().current_scene = leaderboard
	await _wait_frames(5)

	_check(
		leaderboard.get_node_or_null("%RewardTiersLabel") == null,
		"The obsolete reward-tier summary label is still present."
	)
	var rows := leaderboard.get_node("%RowsContainer") as VBoxContainer
	_check(rows.get_child_count() == 50, "Expected 50 mock leaderboard rows.")
	_verify_weekly_rewards(rows)

	leaderboard.call("_select_scope", &"country")
	await _wait_frames(4)
	rows = leaderboard.get_node("%RowsContainer") as VBoxContainer
	for index in range(mini(3, rows.get_child_count())):
		_check(
			not (rows.get_child(index).get_node("%RankReward") as Control).visible,
			"Country rank %d incorrectly shows a Weekly reward." % (index + 1)
		)

	leaderboard.call("_select_scope", &"weekly")
	await _wait_frames(4)
	rows = leaderboard.get_node("%RowsContainer") as VBoxContainer
	for resolution in TEST_RESOLUTIONS:
		get_tree().root.size = resolution
		await _wait_frames(3)
		var logical_size := leaderboard.get_viewport_rect().size
		var content := leaderboard.get_node("%ContentMargin") as Control
		var navigation := leaderboard.get_node("%BottomNavigation") as Control
		_check(content.position.x >= 0.0, "Content escaped the left edge at %s." % resolution)
		_check(
			content.position.x + content.size.x <= logical_size.x + 1.0,
			"Content escaped the right edge at %s." % resolution
		)
		_check(
			navigation.position.y + navigation.size.y <= logical_size.y + 1.0,
			"Navigation escaped the bottom edge at %s." % resolution
		)
		for index in range(mini(3, rows.get_child_count())):
			var row := rows.get_child(index) as Control
			var reward := row.get_node("%RankReward") as Control
			var score_box := row.get_node("ContentMargin/Content/ScoreBox") as Control
			_check(reward.visible, "Weekly rank %d reward disappeared at %s." % [index + 1, resolution])
			_check(
				score_box.position.x + score_box.size.x <= row.size.x + 1.0,
				"Weekly rank %d row overflowed at %s." % [index + 1, resolution]
			)
		print("Leaderboard layout %s -> logical %s" % [resolution, logical_size])

	get_tree().root.size = Vector2i(720, 1280)
	await _wait_frames(3)
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		var screenshot_error := image.save_png("res://tmp/leaderboard_rank_rewards_720x1280.png")
		_check(screenshot_error == OK, "Could not save the leaderboard reward screenshot.")

	if _failures.is_empty():
		print("LEADERBOARD VERIFICATION PASSED")
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)


func _verify_weekly_rewards(rows: VBoxContainer) -> void:
	for index in EXPECTED_REWARDS.size():
		var row := rows.get_child(index) as Control
		var reward := row.get_node("%RankReward") as Control
		var coin_image := reward.get_node("%CoinImage") as TextureRect
		var amount_label := reward.get_node("%AmountLabel") as Label
		var expected := EXPECTED_REWARDS[index] as Dictionary
		_check(reward.visible, "Weekly rank %d reward is hidden." % (index + 1))
		_check(
			amount_label.text == str(expected.get("amount", "")),
			"Weekly rank %d reward amount is wrong." % (index + 1)
		)
		_check(coin_image.texture != null, "Weekly rank %d reward image is missing." % (index + 1))
		if coin_image.texture != null:
			_check(
				coin_image.texture.resource_path == str(expected.get("texture", "")),
				"Weekly rank %d uses the wrong coin-pile artwork." % (index + 1)
			)

	var fourth_reward := rows.get_child(3).get_node("%RankReward") as Control
	_check(not fourth_reward.visible, "Weekly rank 4 should not show a row reward section.")


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
