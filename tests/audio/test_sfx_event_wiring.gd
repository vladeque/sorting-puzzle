extends SceneTree

## AUDIO-001 event-wiring verification: the eleven approved events fire from the semantic moments
## the ticket names, and stay silent everywhere it says they must.
##
## Run through scripts/tools/run_isolated_godot_test.ps1:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/audio/test_sfx_event_wiring.gd
##
## Playback itself is covered by tests/audio/test_sfx_manager.gd. This file only cares about which
## owner asks for which event, observed through SfxManager's `event_played` signal.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")

const LEVEL_SCENE_PATH := "res://level.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SHOP_SCREEN_SCRIPT_PATH := "res://scripts/shop_screen.gd"
const TEST_LEVEL := 2
const SOUND_EFFECTS_SETTING := &"sound_effects"

var _failures: Array[String] = []
var _manager: Node
var _progress: Node
var _recorded: Array[Dictionary] = []
var _level_scene: PackedScene
var _main_menu_scene: PackedScene
var _shop_screen_script: GDScript


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("SFX event-wiring verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_manager = root.get_node_or_null(^"SfxManager")
	_progress = root.get_node_or_null(^"PlayerProgress")
	if _manager == null or _progress == null:
		push_error("SfxManager and PlayerProgress autoloads are required.")
		quit(1)
		return

	_manager.connect("event_played", _on_event_played)
	_manager.call("set_muted", false)
	_progress.call("set_setting_disabled", SOUND_EFFECTS_SETTING, false)
	# Scenes loaded here compile scripts that reference the autoload globals, so they cannot be
	# preloaded at class level (matching tests/ui/test_interaction_motion.gd).
	_level_scene = load(LEVEL_SCENE_PATH) as PackedScene
	_main_menu_scene = load(MAIN_MENU_SCENE_PATH) as PackedScene
	_shop_screen_script = load(SHOP_SCREEN_SCRIPT_PATH) as GDScript

	await _test_placement_routing()
	await _test_item_selection()
	await _test_critical_timer_and_time_up()
	await _test_level_coin_spending()
	_test_shop_purchase_routing()
	await _test_reward_chest_arrivals()

	_progress.call("set_setting_disabled", SOUND_EFFECTS_SETTING, false)
	if _failures.is_empty():
		print("SFX event-wiring verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


## An accepted landing sounds; a rejected drop rewinding to its origin must not, even though both
## run the same visible landing impact.
func _test_placement_routing() -> void:
	var level := await _open_level()
	var items := level.call("_get_visible_items") as Array
	if items.is_empty():
		_failures.append("Level %d exposes no visible item to place." % TEST_LEVEL)
		await _free_current_scene()
		return

	var item = items[0]
	var slot: Node = item.get_parent()

	_begin_recording()
	level.call("_place_item_in_slot", item, slot, true)
	_check(
		_played(SfxCatalogScript.EVENT_ITEM_PLACE_VALID) == 1,
		"A deliberate same-slot landing that runs the landing impact plays item_place_valid."
	)

	_begin_recording()
	level.call("_place_item_in_slot", item, slot, false)
	_check(
		_played(SfxCatalogScript.EVENT_ITEM_PLACE_VALID) == 0,
		"A silent forced restore does not play item_place_valid."
	)

	_begin_recording()
	await level.call("_return_item_to_origin_after_animation", item, slot)
	_check(
		_played(SfxCatalogScript.EVENT_ITEM_PLACE_VALID) == 0,
		"An invalid/no-target return to the origin stays silent."
	)

	_begin_recording()
	await level.call("_play_item_move_animation", item, slot, true)
	_check(
		_played(SfxCatalogScript.EVENT_ITEM_PLACE_VALID) == 1,
		"An accepted move landing plays item_place_valid."
	)

	await _free_current_scene()


func _test_item_selection() -> void:
	var level := await _open_level()
	var items := level.call("_get_visible_items") as Array
	if items.is_empty():
		await _free_current_scene()
		return

	var item = items[0]
	var slot: Node = item.get_parent()

	_begin_recording()
	level.set("_pressed_item", item)
	level.set("_pressed_origin_slot", slot)
	level.call("_handle_release_at", item.global_position)
	_check(
		_played(SfxCatalogScript.EVENT_ITEM_SELECT) == 1,
		"A finished tap that selects an eligible item plays item_select."
	)
	_check(level.get("_selected_item") == item, "The tap actually selected the item.")

	# A press that became a drag clears the pressed item on the way, so the release selects nothing.
	level.call("_clear_selected_item")
	_begin_recording()
	level.set("_pressed_item", null)
	level.set("_pressed_origin_slot", null)
	level.call("_handle_release_at", item.global_position)
	_check(
		_played(SfxCatalogScript.EVENT_ITEM_SELECT) == 0,
		"A release with no pending press (drag or cancel) plays nothing."
	)

	await _free_current_scene()


func _test_critical_timer_and_time_up() -> void:
	var level := await _open_level()
	var hud = level.get("_top_hud")
	if hud == null:
		_failures.append("The level exposes no top HUD to drive the critical countdown.")
		await _free_current_scene()
		return

	hud.call("reset_timer_attention")
	_begin_recording()
	hud.call("set_timer_state", "00:20", 20, true)
	_check(
		_played(SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK) == 1,
		"Entering the HUD's critical range ticks once."
	)

	_begin_recording()
	hud.call("set_timer_state", "00:20", 20, true)
	_check(
		_played(SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK) == 0,
		"Repeated updates inside the same displayed second do not tick again."
	)

	_begin_recording()
	hud.call("set_timer_state", "00:19", 19, true)
	_check(
		_played(SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK) == 1,
		"Each new critical displayed second ticks once."
	)

	# Above the threshold there is no alarm state at all.
	_begin_recording()
	hud.call("set_timer_state", "01:00", 60, true)
	_check(
		_played(SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK) == 0,
		"A second above the critical threshold does not tick."
	)

	# Before the player's first action the countdown is not running.
	hud.call("reset_timer_attention")
	_begin_recording()
	hud.call("set_timer_state", "00:18", 18, false)
	_check(
		_played(SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK) == 0,
		"A countdown that is not running does not tick."
	)

	# Freezer holds the countdown, so the HUD suppresses its own pulse and the audio with it.
	hud.call("reset_timer_attention")
	hud.call("set_timer_frozen_visual", true)
	_begin_recording()
	hud.call("set_timer_state", "00:17", 17, true)
	_check(
		_played(SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK) == 0,
		"No tick while Freezer holds the countdown."
	)
	hud.call("set_timer_frozen_visual", false)

	# The final five seconds change character without becoming the loudest thing in the mix.
	hud.call("reset_timer_attention")
	_begin_recording()
	hud.call("set_timer_state", "00:04", 4, true)
	var accent := _last_context(SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK)
	_check(
		_played(SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK) == 1
			and float(accent.get("pitch_scale", 0.0)) > 1.0,
		"The final five seconds use a restrained pitch accent."
	)

	hud.call("reset_timer_attention")
	_begin_recording()
	hud.call("set_timer_state", "00:12", 12, true)
	var normal := _last_context(SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK)
	_check(
		not normal.has("pitch_scale"),
		"Ordinary critical seconds keep the catalog's own subtle variation."
	)

	# One time_up per accepted expiry, and nothing when the expiry is re-entered.
	level.set("_time_remaining", 0.0)
	_begin_recording()
	level.call("_handle_level_time_expired")
	_check(
		_played(SfxCatalogScript.EVENT_TIME_UP) == 1,
		"An accepted time expiry plays time_up exactly once."
	)

	_begin_recording()
	level.call("_handle_level_time_expired")
	level.call("_refresh_time_extension_offer")
	_check(
		_played(SfxCatalogScript.EVENT_TIME_UP) == 0,
		"Re-entering the expiry or refreshing the modal does not replay time_up."
	)

	# A terminal level keeps ticking silent even if the HUD is driven again.
	level.set("_level_completed", true)
	hud.call("reset_timer_attention")
	_begin_recording()
	hud.call("set_timer_state", "00:10", 10, true)
	_check(
		_played(SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK) == 0,
		"A terminal level does not keep ticking."
	)

	await _free_current_scene()


func _test_level_coin_spending() -> void:
	_progress.call("reset_progress")
	var grant: Dictionary = _progress.call(
		"apply_shop_purchase", "audio-001-extension-coins", {"coins": 900}
	)
	_check(bool(grant.get("ok", false)), "Test setup grants coins for the extension purchase.")

	var level := await _open_level()
	level.set("_time_remaining", 0.0)
	level.call("_handle_level_time_expired")
	await _wait_seconds(0.3)

	_begin_recording()
	level.call("_on_time_extension_coin_requested")
	await _wait_seconds(0.45)
	_check(
		_played(SfxCatalogScript.EVENT_COIN_SPEND) == 1,
		"A successful time-extension purchase plays coin_spend once."
	)

	# A rejected spend (no coins left) must stay silent.
	_progress.call("spend_coins", _progress.call("get_coins"), "gameplay")
	level.set("_time_remaining", 0.0)
	level.call("_handle_level_time_expired")
	await _wait_seconds(0.3)
	_begin_recording()
	level.call("_on_time_extension_coin_requested")
	await _wait_seconds(0.3)
	_check(
		_played(SfxCatalogScript.EVENT_COIN_SPEND) == 0,
		"An extension the player cannot afford does not play coin_spend."
	)

	await _free_current_scene()
	_progress.call("reset_progress")


## The Shop's decision point, isolated from the store provider: the confirmation and the layered
## coin cue follow what was actually granted, not what was pressed.
func _test_shop_purchase_routing() -> void:
	var shop = _shop_screen_script.new()

	_begin_recording()
	shop.call("_play_purchase_success_audio", {"ok": true, "applied": true, "coins": 500})
	_check(
		_played(SfxCatalogScript.EVENT_SHOP_PURCHASE_SUCCESS) == 1
			and _played(SfxCatalogScript.EVENT_COIN_GAIN) == 1,
		"A granted coin pack plays the confirmation with one layered coin_gain."
	)

	_begin_recording()
	shop.call("_play_purchase_success_audio", {"ok": true, "applied": true, "coins": 0})
	_check(
		_played(SfxCatalogScript.EVENT_SHOP_PURCHASE_SUCCESS) == 1
			and _played(SfxCatalogScript.EVENT_COIN_GAIN) == 0,
		"An ability-only bundle plays the confirmation alone."
	)

	_begin_recording()
	shop.call("_play_purchase_success_audio", {"ok": true, "applied": false})
	_check(
		_played(SfxCatalogScript.EVENT_SHOP_PURCHASE_SUCCESS) == 0
			and _played(SfxCatalogScript.EVENT_COIN_GAIN) == 0,
		"A duplicate transaction that grants nothing stays silent."
	)

	shop.free()


func _test_reward_chest_arrivals() -> void:
	_progress.call("reset_progress")
	var menu := _main_menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame

	# Reconciling the displayed count to saved progress is not an arrival.
	_begin_recording()
	menu.call("_update_reward_chest_status")
	menu.call("_prepare_pending_reward_animation", {"start_stars": 3, "start_goal_index": 0})
	_check(
		_played(SfxCatalogScript.EVENT_REWARD_CHEST_STAR_ARRIVAL) == 0
			and _played(SfxCatalogScript.EVENT_COIN_GAIN) == 0,
		"Silent state reconciliation plays no reward audio."
	)

	_begin_recording()
	menu.call("_on_reward_star_arrived")
	_check(
		_played(SfxCatalogScript.EVENT_REWARD_CHEST_STAR_ARRIVAL) == 1,
		"An accepted star arrival plays the chest arrival cue."
	)
	_check(
		_played(SfxCatalogScript.EVENT_COIN_GAIN) == 0,
		"An arrival short of the goal does not pay out coins."
	)

	# The arrival that crosses the goal layers exactly one coin_gain for the completed goal.
	var goal: int = _progress.call("get_reward_chest_goal_at_index", 0)
	menu.set("_animated_reward_goal_index", 0)
	menu.set("_animated_reward_stars", goal - 1)
	_begin_recording()
	menu.call("_on_reward_star_arrived")
	_check(
		_played(SfxCatalogScript.EVENT_REWARD_CHEST_STAR_ARRIVAL) == 1
			and _played(SfxCatalogScript.EVENT_COIN_GAIN) == 1,
		"A goal-crossing arrival layers one coin_gain for the completed goal."
	)
	_check(
		int(menu.get("_animated_reward_goal_index")) == 1,
		"The goal-crossing arrival advanced the animated goal."
	)

	await _free_current_scene()
	_progress.call("reset_progress")


func _open_level() -> Node:
	var level := _level_scene.instantiate()
	level.set("selected_level", TEST_LEVEL)
	level.set("launched_from_dev_mode", true)
	root.add_child(level)
	current_scene = level
	await process_frame
	await process_frame
	return level


func _free_current_scene() -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


## Clears the recorded events and the owner's cooldown/variant history, so one subtest's spacing
## never suppresses the next subtest's first cue.
func _begin_recording() -> void:
	_manager.call("reset_playback_state")
	_recorded.clear()


func _played(event_id: StringName) -> int:
	var count := 0
	for entry in _recorded:
		if entry["event_id"] == event_id:
			count += 1

	return count


func _last_context(event_id: StringName) -> Dictionary:
	for index in range(_recorded.size() - 1, -1, -1):
		if _recorded[index]["event_id"] == event_id:
			return _recorded[index]["context"] as Dictionary

	return {}


func _on_event_played(event_id: StringName, context: Dictionary) -> void:
	_recorded.append({"event_id": event_id, "context": context})


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
