extends SceneTree

## First-time gameplay tips (docs/GAMEPLAY_TIPS.md): the catalog contract, the device-local seen
## set, and both shipped tips driven through the real launch path (`prepare_for_loading_transition()`
## then `activate_after_loading_transition()`), with the tip delays zeroed so a headless frame can
## reach them.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const GameplayTipCatalogScript := preload("res://scripts/gameplay_tip_catalog.gd")
const LEVEL_1_TIP_ID := "level_1_move_to_triple"
const LEVEL_10_TIP_ID := "level_10_tap_dispenser"
const SLOT_ITEM_POSITION := Vector2(0, -32)
const ANCHOR_TOLERANCE := 1.0

var _failures: Array[String] = []
## The PlayerProgress autoload, looked up at run time: this script compiles before autoloads exist.
## Left untyped so its script methods are called dynamically.
var _progress


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Gameplay tip verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_progress = root.get_node_or_null("PlayerProgress")
	if _progress == null:
		push_error("The PlayerProgress autoload is not available.")
		quit(1)
		return

	_verify_the_shipped_catalog()
	_verify_the_catalog_rejects_bad_tips()
	_verify_the_seen_set_is_device_local_and_persistent()

	await _verify_only_a_real_launch_arms_a_tip()
	await _verify_the_level_1_tip_follows_the_board()
	await _verify_input_passes_through_the_hand()
	await _verify_the_tip_steps_aside_while_the_screen_is_busy()
	await _verify_a_board_rebuild_drops_the_tip()
	await _verify_the_hammer_does_not_finish_the_move_tip()
	await _verify_the_level_10_tip_waits_for_a_real_throw()
	await _verify_a_seen_tip_stays_hidden_unless_forced()
	await _verify_a_completed_level_suppresses_its_tip()
	_finish()


func _verify_the_shipped_catalog() -> void:
	var catalog := GameplayTipCatalogScript.new()
	_check(catalog.load_catalog(), "The shipped gameplay tips config loads: %s" % "; ".join(catalog.get_errors()))
	var level_1 := catalog.get_tip_for_level(1)
	var level_10 := catalog.get_tip_for_level(10)
	_check(level_1.get("id") == LEVEL_1_TIP_ID, "Level 1 has the move tip.")
	_check(level_1.get("type") == GameplayTipCatalogScript.TYPE_MOVE_TO_TRIPLE, "Level 1's tip is a move tip.")
	_check(str(level_1.get("message")).is_empty(), "Level 1's tip is the hand alone, without text.")
	_check(level_10.get("id") == LEVEL_10_TIP_ID, "Level 10 has the dispenser tip.")
	_check(level_10.get("type") == GameplayTipCatalogScript.TYPE_TAP_DISPENSER, "Level 10's tip is a tap tip.")
	_check(not str(level_10.get("message")).is_empty(), "Level 10's tip carries its explanation.")
	_check(catalog.get_tip_for_level(2).is_empty(), "Levels without a tip get none.")

	# The tip is keyed by level number, so the level it names must still teach what the tip shows.
	var level_10_config = JSON.parse_string(FileAccess.get_file_as_string("res://configs/levels/level_010.json"))
	_check(
		level_10_config is Dictionary and level_10_config.get("gameplay_mode") == "throwing_dispensers",
		"Level 10 is still the throwing-dispensers level its tip explains."
	)


func _verify_the_catalog_rejects_bad_tips() -> void:
	var valid := {"id": "a", "level": 3, "type": "move_to_triple"}
	var cases := {
		"a non-object document": [],
		"a missing tips array": {"tip": []},
		"a duplicate id": {"tips": [valid, {"id": "a", "level": 4, "type": "move_to_triple"}]},
		"a second tip on one level": {"tips": [valid, {"id": "b", "level": 3, "type": "tap_dispenser"}]},
		"an unknown type": {"tips": [{"id": "a", "level": 3, "type": "wave"}]},
		"a zero level": {"tips": [{"id": "a", "level": 0, "type": "move_to_triple"}]},
		"a fractional level": {"tips": [{"id": "a", "level": 3.5, "type": "move_to_triple"}]},
		"an empty id": {"tips": [{"id": "", "level": 3, "type": "move_to_triple"}]},
		"an id too long to save": {"tips": [{"id": "x".repeat(65), "level": 3, "type": "move_to_triple"}]},
		"a non-string message": {"tips": [{"id": "a", "level": 3, "type": "move_to_triple", "message": 4}]},
		"a negative delay": {"tips": [{"id": "a", "level": 3, "type": "move_to_triple", "start_delay_seconds": -1}]},
	}
	for label in cases:
		var catalog := GameplayTipCatalogScript.new()
		_check(not catalog.load_document(cases[label]), "The catalog rejects %s." % label)
		_check(catalog.get_tips().is_empty(), "A rejected catalog (%s) serves no tip at all." % label)

	var catalog := GameplayTipCatalogScript.new()
	_check(catalog.load_document({"tips": [valid]}), "A minimal tip loads.")
	var tip := catalog.get_tip_for_level(3)
	_check(
		is_equal_approx(float(tip.get("start_delay_seconds")), GameplayTipCatalogScript.DEFAULT_START_DELAY_SECONDS),
		"An omitted start delay takes the default."
	)


func _verify_the_seen_set_is_device_local_and_persistent() -> void:
	_progress.reset_seen_gameplay_tips()
	var journal_before := (_progress.get("_local_store").get_journal() as Array).size()
	_check(not _progress.has_seen_gameplay_tip("probe_tip"), "A fresh seen set is empty.")
	_check(_progress.mark_gameplay_tip_seen("probe_tip"), "A tip can be marked seen.")
	_check(_progress.mark_gameplay_tip_seen("probe_tip"), "Marking a seen tip again is harmless.")
	_check(_progress.has_seen_gameplay_tip("probe_tip"), "A marked tip reads as seen.")
	_check(
		not _progress.mark_gameplay_tip_seen("x".repeat(65)),
		"An id longer than the save allows is refused rather than stored truncated."
	)
	_check(
		not (_progress.call("_snapshot_for_storage") as Dictionary).has("seen_gameplay_tips"),
		"The seen set never enters the authoritative snapshot."
	)
	_check(
		((_progress.call("_preferences_for_storage") as Dictionary).get("seen_gameplay_tips", []) as Array).has("probe_tip"),
		"The seen set is stored in the local preferences partition."
	)
	_check(
		(_progress.get("_local_store").get_journal() as Array).size() == journal_before,
		"Marking a tip seen creates no backend journal operation."
	)

	_progress.load_progress()
	_check(_progress.has_seen_gameplay_tip("probe_tip"), "The seen set survives a save reload.")
	_check(
		_progress.call("_sanitize_seen_gameplay_tips", ["a", "a", "", 5, "b"]) == ["a", "b"],
		"Sanitizing keeps unique, non-empty string ids in order."
	)
	_check(_progress.reset_seen_gameplay_tips(), "The debug reset succeeds.")
	_check(not _progress.has_seen_gameplay_tip("probe_tip"), "The debug reset forgets every tip.")


func _verify_only_a_real_launch_arms_a_tip() -> void:
	_progress.reset_seen_gameplay_tips()
	var direct := (load("res://level.tscn") as PackedScene).instantiate()
	direct.set("selected_level", 1)
	direct.set("launched_from_dev_mode", true)
	direct.set("_sound_effects_enabled", false)
	root.add_child(direct)
	await _settle()
	_check(
		(direct.get("_gameplay_tip") as Dictionary).is_empty(),
		"A level opened without LevelTransition (a test, a capture, F6) arms no tip."
	)
	await _dispose(direct)

	var launched := await _make_level(1)
	_check(
		(launched.get("_gameplay_tip") as Dictionary).get("id") == LEVEL_1_TIP_ID,
		"Activating after the loading reveal arms the level's tip."
	)
	await _dispose(launched)


func _verify_the_level_1_tip_follows_the_board() -> void:
	_progress.reset_seen_gameplay_tips()
	var level := await _make_level(1)
	var overlay := _overlay(level)
	var shelves := _shelves_by_config_order(level)
	_check(shelves.size() == 3, "Level 1 builds three shelves.")
	if shelves.size() != 3:
		await _dispose(level)
		return

	var left_slots := level.call("_get_front_slots", shelves[0]) as Array
	var middle_jar := (level.call("_get_shelf_items", shelves[1]) as Array)[0] as ShelfItem
	var right_jar := (level.call("_get_shelf_items", shelves[2]) as Array)[0] as ShelfItem

	_check(overlay.is_showing(), "The level 1 hand is showing.")
	_check(overlay.get_hand().visible, "The hand node is visible.")
	_check(not overlay.get_bubble().visible, "The level 1 tip has no message bubble.")
	_check_anchor(overlay, "_playing_from", _canvas_point(middle_jar), "The first demonstration starts on the middle jar.")
	_check_anchor(overlay, "_playing_to", _slot_point(left_slots[1]), "It ends on the left shelf's first free slot.")
	_check(not bool(level.get("_has_player_started_timer")), "The tip never starts the level timer.")

	level.call("_move_item_to_slot", middle_jar, middle_jar.get_parent(), left_slots[1])
	await _settle()
	_check(overlay.is_showing(), "The tip comes back after the player's move.")
	_check_anchor(overlay, "_playing_from", _canvas_point(right_jar), "It now demonstrates the right jar.")
	_check_anchor(overlay, "_playing_to", _slot_point(left_slots[2]), "It aims at the left shelf's last free slot.")
	_check(not _progress.has_seen_gameplay_tip(LEVEL_1_TIP_ID), "A move without a triple does not finish the tip.")

	level.call("_move_item_to_slot", right_jar, right_jar.get_parent(), left_slots[2])
	await _settle()
	_check(_progress.has_seen_gameplay_tip(LEVEL_1_TIP_ID), "The first matched triple marks the tip seen.")
	_check(not overlay.is_active(), "The finished tip is no longer active.")
	await _dispose(level)


func _verify_input_passes_through_the_hand() -> void:
	_progress.reset_seen_gameplay_tips()
	var level := await _make_level(1)
	var overlay := _overlay(level)
	_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The overlay ignores the pointer.")
	var bubble := overlay.get_bubble()
	for control: Control in [bubble, bubble.get_node("Panel"), bubble.get_node("Label")]:
		_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s ignores the pointer." % control.name)

	var middle_jar := (level.call("_get_shelf_items", _shelves_by_config_order(level)[1]) as Array)[0] as ShelfItem
	var hand_rect := overlay.get_hand().get_artwork_rect()
	var press_point := _canvas_point(middle_jar) + Vector2(4, 8)
	_check(hand_rect.has_point(press_point), "The press lands on the hand's artwork.")
	_push_touch(press_point, true)
	await process_frame
	_push_touch(press_point, false)
	await process_frame
	_check(level.get("_selected_item") == middle_jar, "A tap through the hand still selects the jar under it.")
	await process_frame
	_check(not overlay.is_showing(), "The tip steps aside while an item is selected.")

	level.call("_clear_selected_item")
	await _settle()
	_check(overlay.is_showing(), "The tip returns once the selection is cleared.")
	await _dispose(level)


func _verify_the_tip_steps_aside_while_the_screen_is_busy() -> void:
	_progress.reset_seen_gameplay_tips()
	var level := await _make_level(1)
	var overlay := _overlay(level)
	_check(overlay.is_showing(), "The tip is showing before the pause.")

	level.set("_level_paused", true)
	await _settle()
	_check(not overlay.is_showing() and not overlay.get_hand().visible, "Pausing hides the tip.")
	_check(overlay.is_active(), "A suspended tip is not finished.")

	level.set("_level_paused", false)
	await _settle()
	_check(overlay.is_showing(), "Resuming brings the tip back.")

	level.get_node("UI/PauseMenuOverlay").visible = true
	await _settle()
	_check(not overlay.is_showing(), "A visible modal hides the tip.")
	level.get_node("UI/PauseMenuOverlay").visible = false
	await _settle()
	_check(overlay.is_showing(), "Closing the modal brings the tip back.")
	await _dispose(level)


func _verify_a_board_rebuild_drops_the_tip() -> void:
	_progress.reset_seen_gameplay_tips()
	var level := await _make_level(1)
	var overlay := _overlay(level)
	level.call("_apply_level_config", level.call("_load_level_config", 2))
	level.call("_collect_slots")
	await _settle()
	_check((level.get("_gameplay_tip") as Dictionary).is_empty(), "Rebuilding the board drops the tip.")
	_check(not overlay.is_active() and not overlay.get_hand().visible, "The dropped tip is hidden at once.")
	await _dispose(level)


func _verify_the_hammer_does_not_finish_the_move_tip() -> void:
	_progress.reset_seen_gameplay_tips()
	var level := await _make_level(1)
	_check(bool(level.call("_use_hammer")), "The Hammer can clear level 1's jars.")
	await create_timer(2.5).timeout
	_check(
		not _progress.has_seen_gameplay_tip(LEVEL_1_TIP_ID),
		"A triple destroyed by the Hammer does not mark the move tip seen."
	)
	await _dispose(level)


func _verify_the_level_10_tip_waits_for_a_real_throw() -> void:
	_progress.reset_seen_gameplay_tips()
	var level := await _make_level(10)
	var overlay := _overlay(level)
	var rack := level.get("_dispenser_rack") as ThrowingDispenserRack
	_check(rack != null and rack.get_dispensers().size() == 2, "Level 10 builds its two dispensers.")
	if rack == null or rack.get_dispensers().size() != 2:
		await _dispose(level)
		return

	var dispensers := rack.get_dispensers()
	_check(overlay.is_showing(), "The level 10 hand is showing.")
	_check_anchor(overlay, "_playing_from", _tap_point(level, dispensers[0]), "The hand taps the first dispenser.")

	var bubble := overlay.get_bubble()
	var viewport_size := (level as Node2D).get_viewport_rect().size
	var panel := bubble.get_panel_rect()
	_check(bubble.visible, "The explanation bubble is showing.")
	_check(bubble.get_message() == "Tap a dispenser to throw items onto the shelves!", "The bubble shows the configured text.")
	_check(
		panel.position.x >= 16.0 - 0.5 and panel.end.x <= viewport_size.x - 16.0 + 0.5,
		"The bubble stays inside the 16 px side gutters (%s in %s)." % [panel, viewport_size]
	)
	_check(
		panel.position.y >= overlay.get_hand().get_artwork_rect().end.y,
		"The bubble sits below the hand instead of under it."
	)

	# A tap that cannot throw (here, an emptied dispenser) is refused and teaches nothing.
	dispensers[0].take(dispensers[0].get_remaining_count())
	level.call("_on_dispenser_throw_requested", dispensers[0])
	await _settle()
	_check(overlay.is_active(), "A refused tap leaves the tip active.")
	_check(not _progress.has_seen_gameplay_tip(LEVEL_10_TIP_ID), "A refused tap does not mark the tip seen.")
	_check_anchor(overlay, "_playing_from", _tap_point(level, dispensers[1]), "The hand moves to the dispenser that still has stock.")

	dispensers[1].throw_requested.emit()
	await _settle()
	_check(_progress.has_seen_gameplay_tip(LEVEL_10_TIP_ID), "The first real throw marks the tip seen.")
	_check(not overlay.is_active(), "The finished dispenser tip is no longer active.")
	await create_timer(0.4).timeout
	_check(not bubble.visible and not overlay.get_hand().visible, "Hand and bubble fade away after the throw.")
	await _dispose(level)


func _verify_a_seen_tip_stays_hidden_unless_forced() -> void:
	_progress.reset_seen_gameplay_tips()
	_progress.mark_gameplay_tip_seen(LEVEL_10_TIP_ID)
	var level := await _make_level(10)
	_check((level.get("_gameplay_tip") as Dictionary).is_empty(), "A seen tip is not armed again.")
	_check(not _overlay(level).is_showing(), "A seen tip does not show.")
	await _dispose(level)

	var forced := await _make_level(10, true, true)
	_check(_overlay(forced).is_showing(), "force_gameplay_tips shows a seen tip for tests and captures.")
	await _dispose(forced)


func _verify_a_completed_level_suppresses_its_tip() -> void:
	_progress.reset_seen_gameplay_tips()
	_check(_progress.complete_level(1, 3), "Level 1 can be recorded as completed.")
	var campaign := await _make_level(1, false)
	_check(
		(campaign.get("_gameplay_tip") as Dictionary).is_empty(),
		"A campaign launch of a completed level shows no tip, even with an empty seen set."
	)
	await _dispose(campaign)

	var picker := await _make_level(1, true)
	_check(
		(picker.get("_gameplay_tip") as Dictionary).get("id") == LEVEL_1_TIP_ID,
		"A developer-picker launch replays an unseen tip on a completed level."
	)
	await _dispose(picker)


## Builds `level_number` the way `LevelTransition` does and zeroes the tip delays.
func _make_level(level_number: int, dev_mode := true, force_tips := false) -> Node:
	var level := (load("res://level.tscn") as PackedScene).instantiate()
	level.set("selected_level", level_number)
	level.set("launched_from_dev_mode", dev_mode)
	level.set("force_gameplay_tips", force_tips)
	level.set("_sound_effects_enabled", false)
	level.set("hammer_haptics_enabled", false)
	level.set("item_move_duration_seconds", 0.0)
	level.set("match_gather_duration_seconds", 0.0)
	level.set("match_shrink_duration_seconds", 0.0)
	level.set("thrown_item_flight_seconds", 0.0)
	level.set("thrown_item_stagger_seconds", 0.0)
	level.call("prepare_for_loading_transition")
	root.add_child(level)
	await _settle()
	level.call("activate_after_loading_transition")
	var overlay := _overlay(level)
	for property in ["_start_delay", "_reshow_delay", "_delay_remaining"]:
		overlay.set(property, 0.0)
	await _settle()
	return level


func _overlay(level: Node) -> GameplayTipOverlay:
	return level.get_node("UI/GameplayTipOverlay") as GameplayTipOverlay


func _shelves_by_config_order(level: Node) -> Array:
	var shelves := (level.call("_get_all_shelves") as Array).duplicate()
	shelves.sort_custom(func(left: Node, right: Node) -> bool:
		return int(left.get_meta(&"config_shelf_id", 0)) < int(right.get_meta(&"config_shelf_id", 0))
	)
	return shelves


func _canvas_point(node: Node2D) -> Vector2:
	return node.get_global_transform_with_canvas().origin


func _slot_point(slot: Node2D) -> Vector2:
	return slot.get_global_transform_with_canvas() * SLOT_ITEM_POSITION


func _tap_point(level: Node2D, dispenser: ThrowingDispenser) -> Vector2:
	return level.get_canvas_transform() * dispenser.get_tap_global_rect().get_center()


func _check_anchor(overlay: GameplayTipOverlay, property: String, expected: Vector2, message: String) -> void:
	var actual := overlay.get(property) as Vector2
	_check(actual.distance_to(expected) <= ANCHOR_TOLERANCE, "%s (expected %s, got %s)" % [message, expected, actual])


func _push_touch(position: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = position
	touch.pressed = pressed
	# `position` is already in viewport coordinates; without this the headless window's stretch
	# transform would be applied on top.
	root.push_input(touch, true)


func _settle() -> void:
	for _frame in range(12):
		await process_frame


func _dispose(level: Node) -> void:
	level.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Gameplay tip verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
