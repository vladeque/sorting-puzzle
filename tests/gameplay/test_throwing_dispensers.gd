extends SceneTree

## Contract coverage for `gameplay_mode: "throwing_dispensers"`.
##
## The runtime guard exists so a malformed level fails closed instead of opening a board that cannot
## be played, so most of what is worth proving here is what the guard *rejects*. The mode's own
## runtime behavior -- throwing, the reserved slot, completion -- is verified in the same file as it
## lands.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Throwing dispenser verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_verify_known_modes()
	_verify_a_valid_level_passes()
	_verify_seed_shape_is_enforced()
	_verify_dispenser_shape_is_enforced()
	_verify_item_totals_must_be_triples()
	_verify_shelves_must_start_empty()
	_verify_other_modes_reject_dispenser_fields()
	_verify_exclusive_keys_are_rejected()
	_verify_seed_parsing()
	_finish()


## Both guards run on every level, so each has to recognise the other's mode rather than reporting a
## valid level as unknown.
func _verify_known_modes() -> void:
	_check(GameplayModes.is_known("classic"), "classic is a known mode.")
	_check(GameplayModes.is_known("collapsing_columns"), "collapsing_columns is a known mode.")
	_check(GameplayModes.is_known("throwing_dispensers"), "throwing_dispensers is a known mode.")
	_check(not GameplayModes.is_known("wat"), "An invented mode is not known.")
	_check(not GameplayModes.is_known(7), "A non-string mode is not known.")
	_check(
		CollapsingColumnRules.validate_config(_valid_config()).is_empty(),
		"The collapsing guard accepts a throwing_dispensers level instead of calling it unknown."
	)
	_check(
		not ThrowingDispenserRules.validate_config(
			{"gameplay_mode": "wat", "shelves": []}
		).is_empty(),
		"An unknown mode is rejected."
	)


func _verify_a_valid_level_passes() -> void:
	var errors := ThrowingDispenserRules.validate_config(_valid_config())
	_check(errors.is_empty(), "A valid level passes: %s" % ", ".join(errors))
	_check(
		ThrowingDispenserRules.is_throwing_dispensers(_valid_config()),
		"A valid level reports the mode."
	)
	_check(
		ThrowingDispenserRules.get_dispenser_configs(_valid_config()).size() == 2,
		"Both authored dispensers are read back."
	)


## A hand-edited seed is easy to get subtly wrong, and every one of these silently changes the
## scatter the level was tuned against.
func _verify_seed_shape_is_enforced() -> void:
	for bad_seed in ["", "52ad", "00000000000052AD", "0x00000000000052a", "zzzzzzzzzzzzzzzz"]:
		var config := _valid_config()
		config["throw_seed"] = bad_seed
		_check(
			not ThrowingDispenserRules.validate_config(config).is_empty(),
			"Seed '%s' is rejected." % bad_seed
		)

	var missing := _valid_config()
	missing.erase("throw_seed")
	_check(
		not ThrowingDispenserRules.validate_config(missing).is_empty(),
		"A missing seed is rejected."
	)


func _verify_dispenser_shape_is_enforced() -> void:
	var no_dispensers := _valid_config()
	no_dispensers["dispensers"] = []
	_check(
		not ThrowingDispenserRules.validate_config(no_dispensers).is_empty(),
		"An empty dispensers array is rejected."
	)

	var no_contents := _valid_config()
	no_contents["dispensers"] = [{"throw_count": 3, "contents": []}]
	_check(
		not ThrowingDispenserRules.validate_config(no_contents).is_empty(),
		"A dispenser with no contents is rejected."
	)

	# A hole has nothing to throw and, unlike a shelf slot, nothing can ever move into it.
	var null_content := _valid_config()
	null_content["dispensers"] = [{"throw_count": 3, "contents": ["apple", null, "apple"]}]
	_check(
		not ThrowingDispenserRules.validate_config(null_content).is_empty(),
		"A null entry in contents is rejected."
	)

	for bad_count in [0, -2, 1.5]:
		var config := _valid_config()
		config["dispensers"] = [{"throw_count": bad_count, "contents": ["a", "a", "a"]}]
		_check(
			not ThrowingDispenserRules.validate_config(config).is_empty(),
			"throw_count %s is rejected." % bad_count
		)

	# JSON has no integer type, so a whole float is a legitimate authored count.
	var float_count := _valid_config()
	float_count["dispensers"] = [{"throw_count": 3.0, "contents": ["a", "a", "a"]}]
	_check(
		ThrowingDispenserRules.validate_config(float_count).is_empty(),
		"A whole-number float throw_count is accepted."
	)


func _verify_item_totals_must_be_triples() -> void:
	var config := _valid_config()
	config["dispensers"] = [{"throw_count": 3, "contents": ["apple", "apple"]}]
	_check(
		not ThrowingDispenserRules.validate_config(config).is_empty(),
		"An item with a non-multiple-of-three count is rejected."
	)

	# The count is a whole-level total, so copies may be spread across dispensers.
	var split := _valid_config()
	split["dispensers"] = [
		{"throw_count": 3, "contents": ["apple", "apple"]},
		{"throw_count": 3, "contents": ["apple"]},
	]
	_check(
		ThrowingDispenserRules.validate_config(split).is_empty(),
		"A triple split across two dispensers is accepted."
	)


func _verify_shelves_must_start_empty() -> void:
	var config := _valid_config()
	config["shelves"] = [{"layers": [["apple", null, null]]}]
	_check(
		not ThrowingDispenserRules.validate_config(config).is_empty(),
		"An authored shelf item is rejected; every item begins in a dispenser."
	)

	var two_layers := _valid_config()
	two_layers["shelves"] = [{"layers": [[null, null, null], [null, null, null]]}]
	_check(
		not ThrowingDispenserRules.validate_config(two_layers).is_empty(),
		"A second shelf layer is rejected."
	)

	var locked := _valid_config()
	locked["shelves"] = [{"unlock_after_triples": 2, "layers": [[null, null, null]]}]
	_check(
		not ThrowingDispenserRules.validate_config(locked).is_empty(),
		"A locked shelf is rejected."
	)

	var dispenser_shelf := _valid_config()
	dispenser_shelf["shelves"] = [{"type": "dispenser", "layers": [[null, null, null]]}]
	_check(
		not ThrowingDispenserRules.validate_config(dispenser_shelf).is_empty(),
		"A dispenser *shelf* is rejected; it is a different object."
	)


## The guard runs on every level, so a classic or collapsing level carrying these fields has to be
## told they mean nothing there rather than having them quietly ignored.
func _verify_other_modes_reject_dispenser_fields() -> void:
	var classic := {
		"shelves": [{"layers": [["apple", "apple", "apple"]]}],
		"dispensers": [{"throw_count": 3, "contents": ["apple", "apple", "apple"]}],
	}
	_check(
		not ThrowingDispenserRules.validate_config(classic).is_empty(),
		"dispensers on a classic level is rejected."
	)

	var seeded := {"shelves": [{"layers": [["apple", "apple", "apple"]]}], "throw_seed": "00000000000052ad"}
	_check(
		not ThrowingDispenserRules.validate_config(seeded).is_empty(),
		"throw_seed on a classic level is rejected."
	)

	var plain_classic := {"shelves": [{"layers": [["apple", "apple", "apple"]]}]}
	_check(
		ThrowingDispenserRules.validate_config(plain_classic).is_empty(),
		"An ordinary classic level still passes the guard."
	)


func _verify_exclusive_keys_are_rejected() -> void:
	for exclusive_key in ["row_layouts", "column_layout"]:
		var config := _valid_config()
		config[exclusive_key] = [] if exclusive_key == "row_layouts" else {}
		_check(
			not ThrowingDispenserRules.validate_config(config).is_empty(),
			"%s is rejected in this mode." % exclusive_key
		)

	# `layout_preset` is how this mode places its empty board, so unlike the collapsing mode it is
	# expected rather than exclusive.
	_check(
		ThrowingDispenserRules.validate_config(_valid_config()).is_empty(),
		"layout_preset is allowed in this mode."
	)


## A retry has to reproduce the run exactly, so the seed must survive the round trip through config.
func _verify_seed_parsing() -> void:
	var config := _valid_config()
	config["throw_seed"] = "00000000000052ad"
	_check(ThrowingDispenserRules.get_throw_seed(config) == 0x52ad, "A seed parses to its hex value.")

	# The top half of the unsigned 64-bit range does not fit a signed int. It must wrap rather than
	# raise, because `String.hex_to_int()` refuses these values outright.
	config["throw_seed"] = "ffffffffffffffff"
	_check(ThrowingDispenserRules.get_throw_seed(config) == -1, "A full-range seed wraps instead of raising.")

	config["throw_seed"] = "8000000000000000"
	_check(
		ThrowingDispenserRules.get_throw_seed(config) == -9223372036854775808,
		"The first seed past the signed maximum wraps to the signed minimum."
	)


func _valid_config() -> Dictionary:
	return {
		"level": 21,
		"time_seconds": 300,
		"gameplay_mode": "throwing_dispensers",
		"layout_preset": "grid_3x4",
		"throw_seed": "00000000000052ad",
		"dispensers": [
			{"throw_count": 3, "contents": ["apple", "banana", "apple", "apple", "banana", "banana"]},
			{"throw_count": 2, "contents": ["cherry", "cherry", "cherry"]},
		],
		"shelves": [
			{"layers": [[null, null, null]]},
			{"layers": [[null, null, null]]},
			{"layers": [[null, null, null]]},
		],
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Throwing dispenser verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
