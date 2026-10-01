extends SceneTree

const ComboScoringRulesScript := preload("res://scripts/combo_scoring_rules.gd")

## combo -> [window_seconds, stars_per_triple], the table `configs/combo_scoring.json` ships.
const EXPECTED_TIERS := {
	1: [15.0, 1], 3: [15.0, 1],
	4: [10.0, 2], 6: [10.0, 2],
	7: [7.0, 3], 9: [7.0, 3],
	10: [5.0, 4], 14: [5.0, 4],
	15: [4.0, 5], 19: [4.0, 5],
	20: [3.0, 7], 50: [3.0, 7],
}

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_config_tiers()
	_test_invalid_tables_are_rejected()
	await _test_level_combo_scoring()
	if _failures.is_empty():
		print("Combo scoring tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_config_tiers() -> void:
	var rules: ComboScoringRules = ComboScoringRulesScript.load_from_config()
	var defaults: ComboScoringRules = ComboScoringRulesScript.new()
	_check(defaults.set_tiers(ComboScoringRulesScript.DEFAULT_TIERS).is_empty(), "built-in defaults are valid")
	for combo in EXPECTED_TIERS:
		var expected := EXPECTED_TIERS[combo] as Array
		_check(
			is_equal_approx(rules.get_window_seconds(combo), float(expected[0])),
			"×%d window is %ss (got %s)" % [combo, expected[0], rules.get_window_seconds(combo)]
		)
		_check(
			rules.get_stars_per_triple(combo) == int(expected[1]),
			"×%d earns %d stars per triple (got %d)" % [combo, expected[1], rules.get_stars_per_triple(combo)]
		)
		_check(
			is_equal_approx(defaults.get_window_seconds(combo), rules.get_window_seconds(combo))
			and defaults.get_stars_per_triple(combo) == rules.get_stars_per_triple(combo),
			"built-in defaults mirror the config at ×%d" % combo
		)


func _test_invalid_tables_are_rejected() -> void:
	var rules: ComboScoringRules = ComboScoringRulesScript.new()
	_check(rules.set_tiers([{"min_combo": 1, "window_seconds": 9.0, "stars_per_triple": 2}]).is_empty(), "a single tier is valid")
	var invalid_tables := {
		"empty table": [],
		"not an array": {"min_combo": 1},
		"first tier above ×1": [{"min_combo": 2, "window_seconds": 5.0, "stars_per_triple": 1}],
		"non-increasing tiers": [
			{"min_combo": 1, "window_seconds": 5.0, "stars_per_triple": 1},
			{"min_combo": 1, "window_seconds": 4.0, "stars_per_triple": 2},
		],
		"zero window": [{"min_combo": 1, "window_seconds": 0.0, "stars_per_triple": 1}],
		"negative stars": [{"min_combo": 1, "window_seconds": 5.0, "stars_per_triple": -1}],
	}
	for description in invalid_tables:
		_check(not rules.set_tiers(invalid_tables[description]).is_empty(), "%s is rejected" % description)
	_check(
		is_equal_approx(rules.get_window_seconds(12), 9.0) and rules.get_stars_per_triple(12) == 2,
		"a rejected table leaves the previous tiers in place"
	)


func _test_level_combo_scoring() -> void:
	var level = await _make_level()

	var chain_stars := 0
	for _triple in range(5):
		chain_stars += int(level.call("_extend_combo", 1))
	_check(chain_stars == 7, "a five-triple chain earns 1+1+1+2+2 = 7 stars (got %d)" % chain_stars)
	_check(int(level.get("_combo_count")) == 5, "the chain reaches ×5")
	_check(is_equal_approx(float(level.get("_combo_time_remaining")), 10.0), "×5 allows 10s for the next triple")

	level.call("_update_combo_timer", 9.9)
	_check(int(level.get("_combo_count")) == 5, "the combo survives just inside the tier window")
	_check(is_equal_approx(float(level.call("_get_combo_time_ratio")), 0.01), "the fill drains against the tier window")
	level.call("_update_combo_timer", 0.1)
	_check(int(level.get("_combo_count")) == 0, "the combo resets when the tier window runs out")

	var burst_stars := int(level.call("_extend_combo", 4))
	_check(burst_stars == 1 + 1 + 1 + 2, "one move clearing four triples scores each triple by its own tier (got %d)" % burst_stars)
	_check(int(level.get("_combo_count")) == 4, "the burst advances the combo once per triple")
	_check(is_equal_approx(float(level.call("_get_combo_time_ratio")), 1.0), "the fill refills to the new tier's window")

	level.set("_combo_count", 19)
	level.set("_combo_time_remaining", 1.0)
	_check(int(level.call("_extend_combo", 1)) == 7, "reaching ×20 earns 7 stars")
	_check(is_equal_approx(float(level.get("_combo_time_remaining")), 3.0), "×20 allows 3s for the next triple")

	level.queue_free()
	await process_frame


func _make_level():
	var level_scene := load("res://level.tscn") as PackedScene
	var level = level_scene.instantiate()
	# Dev mode keeps the ×20 combo milestone out of the save.
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 1)
	get_root().add_child(level)
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
