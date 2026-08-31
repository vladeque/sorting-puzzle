extends SceneTree

const LEVEL := "res://level.tscn"
const RULES := preload("res://scripts/sticky_item_rules.gd")
const FIXTURE := "res://tests/fixtures/sticky_items_conformance.json"
var failures: Array[String] = []
var completed_stages := 0


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with("SortingPuzzleTest_"):
		push_error("Use run_isolated_godot_test.ps1 for sticky verification")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_contract()
	await _test_input_and_promotion()
	await _test_abilities()
	await _test_unusable_abilities()
	await _test_python_conformance()
	await _test_preview_and_locks()
	_check(completed_stages == 6, "Every test stage must finish without script errors")
	if failures.is_empty():
		print("STICKY ITEMS VERIFICATION PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) as Dictionary


func _new_level(config: Dictionary):
	var level = (load(LEVEL) as PackedScene).instantiate()
	level.launched_from_dev_mode = true
	level._sound_effects_enabled = false
	level.item_move_duration_seconds = 0.0
	level.layer_promotion_duration_seconds = 0.0
	level.match_gather_duration_seconds = 0.0
	level.match_shrink_duration_seconds = 0.0
	root.add_child(level)
	level._apply_level_config(config)
	level._collect_slots()
	await _settle(level)
	return level


func _settle(level) -> void:
	for frame in range(90):
		await process_frame
		if frame >= 6 and not level._is_resolving_shelves and level._transitioning_item_ids.is_empty():
			return
	_check(false, "Board did not settle")


func _test_contract() -> void:
	var config: Dictionary = _fixture().config
	_check(RULES.validate_config(config).is_empty(), "Different sticky layers should be valid")
	var bad := config.duplicate(true)
	bad.shelves[0].sticky_items.append({"layer": 0, "slot": 1})
	_check(not RULES.validate_config(bad).is_empty(), "Two sticky entries in one layer must fail")
	for coordinate in [true, -1, 0.5, 50, "0"]:
		bad = config.duplicate(true)
		bad.shelves[0].sticky_items[0].layer = coordinate
		_check(not RULES.validate_config(bad).is_empty(), "Invalid sticky coordinate must fail: %s" % coordinate)
	bad = config.duplicate(true)
	bad.shelves[0].type = "dispenser"
	_check(not RULES.validate_config(bad).is_empty(), "Dispenser cannot be sticky")
	bad = config.duplicate(true)
	bad.shelves[0].sticky_items[0].slot = 2
	_check(not RULES.validate_config(bad).is_empty(), "Empty slot cannot be sticky")
	completed_stages += 1


func _test_input_and_promotion() -> void:
	var level = await _new_level(_fixture().config)
	var shelves: Array = level._get_all_shelves()
	var slots: Array = level._get_front_slots(shelves[0])
	var anchor: ShelfItem = level._get_slot_item(slots[0])
	var original_position := anchor.global_position
	level._handle_press_at(anchor.global_position)
	level._handle_release_at(anchor.global_position)
	_check(level._selected_item == null and level._pressed_item == null, "Sticky tap must not select")
	_check(not level._has_player_started_timer, "Blocked tap must not start timer")
	level._begin_drag(anchor, anchor.global_position)
	_check(level._dragged_item == null, "Sticky drag must not start")
	_check(not level._move_item_to_slot(anchor, slots[0], level._get_front_slots(shelves[1])[2]), "Direct sticky move must fail")
	_check(level._is_slot_drop_target_eligible(slots[1]), "Sticky shelf still accepts drops")
	var source: Node2D = level._get_front_slots(shelves[1])[0]
	var donor: ShelfItem = level._get_slot_item(source)
	level._handle_press_at(donor.global_position)
	level._handle_release_at(donor.global_position)
	_check(level._selected_item == donor, "Ordinary tap must select")
	level._handle_press_at(anchor.global_position)
	await _settle(level)
	_check(donor.get_parent() == slots[1], "Tap onto sticky item must route donor to free slot")
	_check(anchor.global_position.is_equal_approx(original_position), "Sticky anchor must stay put")
	level.set_sticky_marker_variant("amber")
	_check(anchor.sticky_variant == "amber", "Live marker change must update anchor")
	source = level._get_front_slots(shelves[2])[0]
	donor = level._get_slot_item(source)
	level._begin_drag(donor, donor.global_position)
	_check(level._dragged_item == donor, "Ordinary item remains draggable")
	level._finish_active_drag(slots[2].global_position)
	await _settle(level)
	var promoted: ShelfItem = level._get_slot_item(slots[0])
	_check(level._triples_cleared == 1, "Sticky triple must clear normally")
	_check(promoted != null and promoted.is_sticky and promoted.item_id == &"milk_carton", "Next sticky layer must promote")
	_check(promoted.sticky_variant == "amber", "Hidden marker variant must survive promotion")
	_check(not level._is_slot_move_source_eligible(slots[0]), "Promotion must not enable sticky movement")
	completed_stages += 1
	level.queue_free()
	await process_frame


func _test_abilities() -> void:
	var level = await _new_level(_fixture().config)
	var all_items: Array[ShelfItem] = level._get_all_items()
	var anchors := all_items.filter(func(item: ShelfItem) -> bool: return item.is_sticky)
	var before: Dictionary = level._ability_uses.duplicate()
	_check(not level._can_apply_ability(&"hammer"), "Hammer must reserve the only two partners of each anchor")
	_check(not level._apply_ability_from_button(&"hammer"), "Unusable Hammer must fail")
	_check(before == level._ability_uses, "Rejected Hammer must not consume inventory")
	_check(level._find_hammer_targets(all_items).is_empty(), "Direct Hammer targeting must exclude reserved types")
	_check(level._find_hammer_supplemented_targets(level._get_visible_items(), level._get_first_back_layer_items()).is_empty(), "Back-layer Hammer must respect anchors")
	var hint: Array = level._find_immediate_triple_items()
	_check(hint.size() == 3 and hint.has(anchors[0]), "Highlight must include a sticky destination and its two donors")
	level._shuffle_item_id_assignments(all_items)
	for anchor: ShelfItem in anchors:
		_check(anchor.is_sticky, "Shuffle must preserve flag")
	_check(anchors[0].item_id == &"soda_bottle" and anchors[1].item_id == &"milk_carton", "Shuffle must preserve hidden and front sticky identities")
	_check(not level._get_shuffle_eligible_items().any(func(item: ShelfItem) -> bool: return item.is_sticky), "Shuffle animation must exclude sticky items")
	completed_stages += 1
	level.queue_free()
	await process_frame


func _test_python_conformance() -> void:
	var fixture := _fixture()
	var level = await _new_level(fixture.config)
	var shelves: Array = level._get_all_shelves()
	for move in fixture.solution:
		var source: Node2D = level._get_front_slots(shelves[int(move.from_shelf)])[int(move.from_slot)]
		var target: Node2D = level._get_front_slots(shelves[int(move.to_shelf)])[int(move.to_slot)]
		var item: ShelfItem = level._get_slot_item(source)
		_check(item != null and item.item_id == StringName(move.item), "Python solution must use authored coordinates")
		if item == null:
			break
		_check(level._move_item_to_slot(item, source, target), "Python solution must be legal in Godot")
		await _settle(level)
	_check(level._get_all_items().is_empty() and level._level_completed, "Python solution must clear the Godot board")
	await create_timer(1.5).timeout
	completed_stages += 1
	level.queue_free()
	await process_frame


func _test_unusable_abilities() -> void:
	var config: Dictionary = _fixture().config.duplicate(true)
	config.shelves[0].layers = [["soda_bottle", null, null]]
	config.shelves[0].sticky_items = [{"layer": 0, "slot": 0}]
	for shelf_index in [1, 2]:
		config.shelves[shelf_index].layers = [["soda_bottle", null, null]]
	var level = await _new_level(config)
	var before: Dictionary = level._ability_uses.duplicate()
	_check(not level._apply_ability_from_button(&"shuffle"), "Identical ordinary partners cannot be shuffled meaningfully")
	_check(level._find_immediate_triple_items().size() == 3, "One anchor with two ordinary partners is highlightable")
	# Deliberately deadlocked content: two immovable copies must never be suggested as donors.
	var shelves: Array = level._get_all_shelves()
	level._get_slot_item(level._get_front_slots(shelves[1])[0]).is_sticky = true
	_check(level._find_immediate_triple_items().is_empty(), "Highlight must not group two anchors")
	_check(not level._apply_ability_from_button(&"highlight"), "Unusable highlight must fail")
	_check(before == level._ability_uses, "Unusable Shuffle and Highlight must not consume inventory")
	completed_stages += 1
	level.queue_free()
	await process_frame


func _test_preview_and_locks() -> void:
	var level = (load("res://scenes/testing/sticky_items_preview.tscn") as PackedScene).instantiate()
	level._sound_effects_enabled = false
	root.add_child(level)
	await _settle(level)
	_check(level.launched_from_dev_mode, "Preview must not spend campaign resources")
	level._set_preview_variant("both")
	var shelves: Array = level._get_all_shelves()
	var locked_slot: Node2D = level._get_front_slots(shelves[3])[0]
	_check(level._is_slot_locked(locked_slot), "Preview contains locked sticky shelf")
	level._record_triples_cleared(1)
	_check(not level._is_slot_locked(locked_slot) and not level._is_slot_move_source_eligible(locked_slot), "Shelf unlock must not unstick its item")
	var moving_slot: Node2D = level._get_front_slots(shelves[6])[0]
	var moving_anchor: ShelfItem = level._get_slot_item(moving_slot)
	_check(level._get_moving_shelf_row(moving_slot) != null and not level._is_slot_move_source_eligible(moving_slot), "Moving shelf anchor stays immovable")
	_check(moving_anchor.sticky_variant == "amber", "Both preview must show amber on moving row")
	_check(level._can_apply_ability(&"hammer"), "Ordinary unrelated triples remain Hammer eligible")
	level._set_preview_variant("pink")
	_check(level._get_all_items().all(func(item: ShelfItem) -> bool: return item.sticky_variant == "pink"), "Pink toggle must update every layer")
	level._set_preview_variant("amber")
	_check(level._get_all_items().all(func(item: ShelfItem) -> bool: return item.sticky_variant == "amber"), "Amber toggle must update every layer")
	var anchors: Array = level._get_all_items().filter(func(item: ShelfItem) -> bool: return item.is_sticky)
	_check(level._apply_ability_from_button(&"hammer"), "Hammer must still remove an unrelated ordinary triple")
	await create_timer(4.0).timeout
	await _settle(level)
	_check(not level._hammer_effect_active, "Hammer must finish")
	for anchor: ShelfItem in anchors:
		_check(is_instance_valid(anchor) and not anchor.is_queued_for_deletion(), "Actual Hammer animation must preserve all sticky instances")
	completed_stages += 1
	level.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
