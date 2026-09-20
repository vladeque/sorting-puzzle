extends RefCounted

## Capture setup for ADS-006's ready rewarded shelf-unlock confirmation.
##
## Level 3 authors one locked shelf, so this rebuilds the board from that config (the same way
## `level_board_setup.gd` does, because `_ready()` has already built the default level), opens that
## shelf's confirmation modal, and forces the ready CTA. The level owner normally supplies that
## state from authoritative readiness, which a capture run has no backend for.

const LEVEL_NUMBER := 3
## Any rewarded CTA state can be reviewed without a second setup script:
## `$env:SORTING_PUZZLE_CAPTURE_SHELF_UNLOCK_STATE = 'error'` before the capture.
const STATE_ENVIRONMENT_VARIABLE := "SORTING_PUZZLE_CAPTURE_SHELF_UNLOCK_STATE"
const ENABLED_STATES := [&"ready", &"pending"]


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.set("_loading_transition_pending", false)
	scene_root.call("_apply_chapter_background")
	scene_root.call("_apply_level_config", scene_root.call("_load_level_config", LEVEL_NUMBER))
	scene_root.call("_collect_slots")
	for _frame in range(4):
		await tree.process_frame

	var locked_shelf: Node = null
	for shelf in scene_root.call("_get_all_shelves"):
		if bool(scene_root.call("_is_shelf_locked", shelf)):
			locked_shelf = shelf
			break
	if locked_shelf == null:
		push_error("rewarded_shelf_unlock_setup expects the captured level to author a locked shelf.")
		return

	var requested := OS.get_environment(STATE_ENVIRONMENT_VARIABLE).strip_edges()
	var state := StringName(requested) if not requested.is_empty() else &"ready"

	scene_root.call("_open_shelf_unlock_menu", locked_shelf)
	await tree.create_timer(0.25).timeout
	var overlay = scene_root.get("_shelf_unlock_overlay")
	overlay.call("set_rewarded_action_state", state, state in ENABLED_STATES)
	for _frame in range(2):
		await tree.process_frame
