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

	await _verify_a_level_builds_an_empty_board_and_a_rack()
	await _verify_a_throw_lands_the_configured_count()
	await _verify_the_same_seed_reproduces_the_same_scatter()
	await _verify_a_throw_never_takes_the_last_free_slot()
	await _verify_a_throw_that_completes_a_triple_clears_it()
	await _verify_completion_waits_for_dispenser_stock()
	await _verify_the_rack_is_inside_the_fitted_board()
	await _verify_the_preview_fixture_builds()
	await _verify_a_classic_level_is_unaffected()
	await _verify_the_preview_scene_builds_the_fixture()
	_finish()


func _verify_a_level_builds_an_empty_board_and_a_rack() -> void:
	var level := await _make_level(_runtime_config())
	var rack := _level_rack(level)
	_check(String(level.get("_level_config_error")).is_empty(), "A valid level passes the runtime guard.")
	_check(rack != null, "A throwing level builds a ThrowingDispenserRack under Shelves.")
	_check(_board_item_count(level) == 0, "The board opens with no items on it.")
	if rack != null:
		_check(rack.get_dispensers().size() == 2, "Both authored dispensers are built.")
		_check(rack.get_remaining_count() == 12, "The rack reports every authored item as stock.")
	await _dispose(level)


func _verify_a_throw_lands_the_configured_count() -> void:
	var level := await _make_level(_runtime_config())
	var rack := _level_rack(level)
	var dispenser: ThrowingDispenser = rack.get_dispensers()[0]
	await _throw(level, dispenser)
	_check(_board_item_count(level) == 3, "A throw lands exactly throw_count items.")
	_check(dispenser.get_remaining_count() == 3, "A throw takes its items out of the dispenser.")

	await _throw(level, dispenser)
	_check(dispenser.get_remaining_count() == 0, "A second throw empties the dispenser.")
	# A tap on an empty dispenser must not reach into the next one or throw nothing forever.
	await _throw(level, dispenser)
	_check(dispenser.get_remaining_count() == 0, "An empty dispenser stays empty when tapped again.")
	await _dispose(level)


## The authored seed is what makes a retry replay the same run, so two builds of the same level must
## scatter identically given the same taps.
func _verify_the_same_seed_reproduces_the_same_scatter() -> void:
	var first := await _make_level(_runtime_config())
	await _throw(first, _level_rack(first).get_dispensers()[0])
	var first_board := _board_signature(first)
	await _dispose(first)

	var second := await _make_level(_runtime_config())
	await _throw(second, _level_rack(second).get_dispensers()[0])
	_check(_board_signature(second) == first_board, "The same seed scatters to the same slots.")
	await _dispose(second)

	var different := _runtime_config()
	different["throw_seed"] = "0000000000001234"
	var third := await _make_level(different)
	await _throw(third, _level_rack(third).get_dispensers()[0])
	_check(_board_signature(third) != first_board, "A different seed scatters differently.")
	await _dispose(third)


## The rule the whole mode rests on. A move needs a free slot to land in, so a board with none has no
## legal move and, with every item already thrown, no way to ever regain one.
func _verify_a_throw_never_takes_the_last_free_slot() -> void:
	# Two shelves (6 slots) and a dispenser holding 9, thrown 9 at a time.
	var config := _runtime_config()
	config["shelves"] = [{"layers": [[null, null, null]]}, {"layers": [[null, null, null]]}]
	config["dispensers"] = [{"throw_count": 9, "contents": [
		"milk_carton", "soda_bottle", "juice_box_apple", "milk_carton", "soda_bottle", "juice_box_apple", "milk_carton", "soda_bottle", "juice_box_apple",
	]}]
	var level := await _make_level(config)
	var dispenser: ThrowingDispenser = _level_rack(level).get_dispensers()[0]

	await _throw(level, dispenser)
	_check(_board_item_count(level) == 5, "A throw stops one slot short of filling the board.")
	_check(dispenser.get_remaining_count() == 4, "The items that did not fit stay in the dispenser.")

	# With one slot left and nothing matched, a further tap can throw nothing at all.
	await _throw(level, dispenser)
	_check(_board_item_count(level) == 5, "A refused throw lands nothing.")
	_check(dispenser.get_remaining_count() == 4, "A refused throw consumes no stock.")
	await _dispose(level)


## Asserted by counting rather than by slot, because where an item lands is the one thing this mode
## does not fix. Nine copies of one type thrown at a nine-slot board is clamped to eight by the
## reserved slot, and eight items across nine slots must fill exactly two of the three shelves
## whatever order they land in, so the triples are forced even though the placement is not.
func _verify_a_throw_that_completes_a_triple_clears_it() -> void:
	var level := await _make_level(_single_type_config())
	var dispenser: ThrowingDispenser = _level_rack(level).get_dispensers()[0]

	await _throw(level, dispenser)
	_check(int(level.get("_triples_cleared")) == 2, "Both triples the throw completed are cleared.")
	_check(_board_item_count(level) == 2, "The two items that formed no triple stay on the board.")
	_check(dispenser.get_remaining_count() == 1, "The item the reserved slot held back stays in stock.")
	await _dispose(level)


## Undispensed stock is data, not `ShelfItem` nodes, so `_get_all_items()` cannot see it. Without the
## stock gate this level would complete on its very first frame, because it opens on an empty board.
func _verify_completion_waits_for_dispenser_stock() -> void:
	var level := await _make_level(_single_type_config())
	var dispenser: ThrowingDispenser = _level_rack(level).get_dispensers()[0]
	_check(_board_item_count(level) == 0, "The board opens with no items on it.")
	_check(
		not bool(level.get("_level_completed")),
		"An empty board with full dispensers is not a completed level."
	)

	await _throw(level, dispenser)
	_check(
		not bool(level.get("_level_completed")),
		"One item still in stock keeps the level running."
	)

	# Emptied by hand: reaching an empty board *and* empty stock through play needs a scatter this
	# fixture cannot force, and what is under test here is the completion rule, not the scatter.
	dispenser.take(dispenser.get_remaining_count())
	for item in level.call("_get_all_items") as Array:
		item.queue_free()
	await process_frame
	level.call("_check_level_completed")
	_check(bool(level.get("_level_completed")), "The level completes once nothing is left anywhere.")
	await _dispose(level)


## Three shelves and nine copies of one item: see `_verify_a_throw_that_completes_a_triple_clears_it`
## for why that shape makes a random scatter's outcome deterministic.
func _single_type_config() -> Dictionary:
	var contents: Array = []
	for copy_index in range(9):
		contents.append("milk_carton")

	var config := _runtime_config()
	config["shelves"] = [
		{"layers": [[null, null, null]]},
		{"layers": [[null, null, null]]},
		{"layers": [[null, null, null]]},
	]
	config["dispensers"] = [{"throw_count": 9, "contents": contents}]
	return config


## Without the rack's bounds the responsive fit sizes the level to the shelves alone and pushes the
## dispensers off the top of a short viewport.
func _verify_the_rack_is_inside_the_fitted_board() -> void:
	var level := await _make_level(_runtime_config())
	var rack := _level_rack(level)
	var board_bounds: Rect2 = level.call("_get_shelf_cells_bounds")
	var rack_bounds := rack.get_layout_bounds()
	_check(rack_bounds.size.x > 0.0 and rack_bounds.size.y > 0.0, "The rack reports layout bounds.")
	_check(rack_bounds.end.y <= board_bounds.position.y, "The rack sits entirely above the shelves.")

	var level_bounds: Rect2 = level.call("_get_shelves_local_bounds")
	_check(level_bounds.encloses(rack_bounds), "The level's fitted bounds contain the rack.")
	await _dispose(level)


func _verify_the_preview_fixture_builds() -> void:
	var fixture := FileAccess.get_file_as_string("res://configs/test_levels/throwing_dispensers_preview.json")
	var config = JSON.parse_string(fixture)
	_check(config is Dictionary, "The preview fixture parses.")
	if not config is Dictionary:
		return

	var level := await _make_level(config)
	var rack := _level_rack(level)
	_check(String(level.get("_level_config_error")).is_empty(), "The preview fixture passes runtime validation.")
	_check(rack != null and rack.get_remaining_count() == 30, "The preview opens with all 30 items in stock.")
	_check(_board_item_count(level) == 0, "The preview opens on an empty board.")
	await _dispose(level)


## The mode is additive: a level that does not declare it must build exactly as before.
func _verify_a_classic_level_is_unaffected() -> void:
	var config := {
		"level": 1,
		"time_seconds": 300,
		"layout_preset": "grid_3x3",
		"shelves": [],
	}
	var shelves: Array = []
	for shelf_index in range(9):
		shelves.append({"layers": [[null, null, null]]})
	shelves[0] = {"layers": [["milk_carton", "milk_carton", "milk_carton"]]}
	config["shelves"] = shelves

	var level := await _make_level(config)
	_check(String(level.get("_level_config_error")).is_empty(), "A classic level still passes both guards.")
	_check(_level_rack(level) == null, "A classic level builds no dispenser rack.")
	await _dispose(level)


## The preview scene is how this mode is played by hand, so it is worth proving it still loads its
## fixture through the ordinary runtime rather than only in theory.
func _verify_the_preview_scene_builds_the_fixture() -> void:
	var preview := (load("res://scenes/testing/throwing_dispensers_preview.tscn") as PackedScene).instantiate()
	preview.set("_sound_effects_enabled", false)
	root.add_child(preview)
	await process_frame
	await process_frame
	var rack := _level_rack(preview)
	_check(
		String(preview.get("_level_config_error")).is_empty(),
		"The preview scene passes runtime validation."
	)
	_check(rack != null and rack.get_remaining_count() == 30, "The preview opens with all 30 items in stock.")
	_check(_board_item_count(preview) == 0, "The preview opens on an empty board.")
	await _dispose(preview)


func _runtime_config() -> Dictionary:
	var shelves: Array = []
	for shelf_index in range(6):
		shelves.append({"layers": [[null, null, null]]})

	return {
		"level": 21,
		"time_seconds": 300,
		"gameplay_mode": "throwing_dispensers",
		"layout_preset": "grid_3x2",
		"throw_seed": "00000000000052ad",
		"dispensers": [
			{"throw_count": 3, "contents": ["milk_carton", "soda_bottle", "milk_carton", "soda_bottle", "milk_carton", "soda_bottle"]},
			{"throw_count": 3, "contents": ["juice_box_apple", "juice_box_apple", "juice_box_apple", "water_bottle", "water_bottle", "water_bottle"]},
		],
		"shelves": shelves,
	}


func _make_level(config: Dictionary) -> Node:
	var level := (load("res://level.tscn") as PackedScene).instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 1)
	level.set("_sound_effects_enabled", false)
	level.set("hammer_haptics_enabled", false)
	level.set("item_move_duration_seconds", 0.0)
	level.set("match_gather_duration_seconds", 0.0)
	level.set("match_shrink_duration_seconds", 0.0)
	# A headless frame is far shorter than a real one, so a real flight duration would
	# never finish inside a frame-counted settle.
	level.set("thrown_item_flight_seconds", 0.0)
	level.set("thrown_item_stagger_seconds", 0.0)
	root.add_child(level)
	await process_frame
	level.call("_apply_level_config", config)
	level.call("_collect_slots")
	await _settle(level)
	return level


## Taps the dispenser the way the player does, through the signal the scene emits, so the test
## exercises the level's own eligibility rules rather than reaching past them.
func _throw(level: Node, dispenser: ThrowingDispenser) -> void:
	# `_process` is what re-enables input after a state change, and the level only runs it once a
	# frame has passed.
	await process_frame
	dispenser.throw_requested.emit()
	await _settle(level)


func _settle(level: Node) -> void:
	for _frame in range(12):
		await process_frame


func _level_rack(level: Node) -> ThrowingDispenserRack:
	return level.get_node_or_null("Shelves/ThrowingDispenserRack") as ThrowingDispenserRack


func _board_item_count(level: Node) -> int:
	return (level.call("_get_all_items") as Array).size()


## Which item sits in which slot, in the level's own stable slot order. Two runs of the same seed
## must produce the same string.
func _board_signature(level: Node) -> String:
	var parts := PackedStringArray()
	for shelf in level.call("_get_all_shelves") as Array:
		for slot in level.call("_get_front_slots", shelf) as Array:
			var item := level.call("_get_slot_item", slot) as ShelfItem
			parts.append("-" if item == null else String(item.item_id))

	return ",".join(parts)


func _dispose(level: Node) -> void:
	level.queue_free()
	await process_frame
	await process_frame


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
	null_content["dispensers"] = [{"throw_count": 3, "contents": ["milk_carton", null, "milk_carton"]}]
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
	config["dispensers"] = [{"throw_count": 3, "contents": ["milk_carton", "milk_carton"]}]
	_check(
		not ThrowingDispenserRules.validate_config(config).is_empty(),
		"An item with a non-multiple-of-three count is rejected."
	)

	# The count is a whole-level total, so copies may be spread across dispensers.
	var split := _valid_config()
	split["dispensers"] = [
		{"throw_count": 3, "contents": ["milk_carton", "milk_carton"]},
		{"throw_count": 3, "contents": ["milk_carton"]},
	]
	_check(
		ThrowingDispenserRules.validate_config(split).is_empty(),
		"A triple split across two dispensers is accepted."
	)


func _verify_shelves_must_start_empty() -> void:
	var config := _valid_config()
	config["shelves"] = [{"layers": [["milk_carton", null, null]]}]
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
		"shelves": [{"layers": [["milk_carton", "milk_carton", "milk_carton"]]}],
		"dispensers": [{"throw_count": 3, "contents": ["milk_carton", "milk_carton", "milk_carton"]}],
	}
	_check(
		not ThrowingDispenserRules.validate_config(classic).is_empty(),
		"dispensers on a classic level is rejected."
	)

	var seeded := {"shelves": [{"layers": [["milk_carton", "milk_carton", "milk_carton"]]}], "throw_seed": "00000000000052ad"}
	_check(
		not ThrowingDispenserRules.validate_config(seeded).is_empty(),
		"throw_seed on a classic level is rejected."
	)

	var plain_classic := {"shelves": [{"layers": [["milk_carton", "milk_carton", "milk_carton"]]}]}
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
			{"throw_count": 3, "contents": ["milk_carton", "soda_bottle", "milk_carton", "milk_carton", "soda_bottle", "soda_bottle"]},
			{"throw_count": 2, "contents": ["juice_box_apple", "juice_box_apple", "juice_box_apple"]},
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
