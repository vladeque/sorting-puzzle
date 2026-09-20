extends RefCounted

## Shared steps for the `collapsing_columns_*_setup.gd` capture setups.
##
## The level resolves its visible window once, when a board is built, from the screen it is built
## on. `capture_ui.ps1` runs a setup once and then resizes the window for each resolution, so the
## setups rebuild the board on every resize: each capture then shows exactly the window a fresh level
## load on that device would reveal.

const FIXTURE_PATH := "res://configs/test_levels/collapsing_columns_preview.json"
## Set to a campaign level number to review that level instead of the development fixture, for
## example `$env:SORTING_PUZZLE_CAPTURE_COLLAPSE_LEVEL = '9'`. Only the initial setup honours it;
## the progress and motion setups replay the fixture's own recorded solution.
const LEVEL_NUMBER_ENVIRONMENT_VARIABLE := "SORTING_PUZZLE_CAPTURE_COLLAPSE_LEVEL"
const AUTHORED_WINDOW := 4
const SETTLE_TIMEOUT_MSEC := 6000
## Opening steps of the solver's solution for FIXTURE_PATH at its authored window of four shelves,
## as authored 1-based [from_shelf, from_slot, to_shelf, to_slot] from
## `py scripts\tools\validate_level_solvable.py configs\test_levels\collapsing_columns_preview.json --show-solution`.
## They are only valid for that fixture; regenerate them whenever it changes.
const SOLUTION_PREFIX := [
	[11, 1, 4, 1], [12, 3, 2, 1], [13, 2, 12, 3], [13, 3, 24, 3], [1, 1, 3, 2],
	[5, 3, 11, 1], [2, 2, 3, 1], [21, 1, 2, 2], [6, 3, 21, 1], [3, 1, 6, 3],
	[3, 2, 25, 1], [7, 3, 13, 3], [25, 2, 13, 2], [22, 1, 15, 1],
]


## `capture_scene.gd` drops its reference to a setup once `setup()` returns, which would free the
## setup and silently disconnect its resize handler. Parking it on the scene keeps it alive for as
## long as the scene being captured.
static func keep_alive(scene_root: Node, setup_instance: RefCounted) -> void:
	scene_root.set_meta(&"collapsing_capture_setup", setup_instance)


## `pinned_window` 0 lets the screen decide, exactly as in play. Replayed solutions pin the authored
## window because they were proven against it. `use_requested_level` allows the campaign level named
## by the environment variable to stand in for the fixture.
static func build(
	level: Node, pinned_window: int, animated: bool, use_requested_level := false
) -> CollapsingShelfBoard:
	level.set("launched_from_dev_mode", true)
	level.set("_sound_effects_enabled", false)
	level.set("item_move_duration_seconds", 0.0)
	level.set("match_gather_duration_seconds", 0.0)
	level.set("match_shrink_duration_seconds", 0.0)
	level.set("max_collapsing_visible_shelves", pinned_window)

	var requested_level := requested_level_number() if use_requested_level else 0
	if requested_level > 0:
		level.set("selected_level", requested_level)
		level.call("_apply_chapter_background")
		level.call("_apply_level_config", level.call("_load_level_config", requested_level))
		level.call("_update_level_label")
	else:
		level.call("_apply_level_config", level.call("_load_json_file", FIXTURE_PATH))
	level.call("_collect_slots")
	var board := level.get_node_or_null("Shelves/CollapsingShelfBoard") as CollapsingShelfBoard
	if board == null:
		push_error("The collapsing fixture did not build a board: %s" % level.get("_level_config_error"))
		return null

	if not animated:
		board.destroy_duration_seconds = 0.0
		board.shift_duration_seconds = 0.0
	return board


static func settle(level: Node, tree: SceneTree) -> void:
	var deadline := Time.get_ticks_msec() + SETTLE_TIMEOUT_MSEC
	var calm_frames := 0
	while Time.get_ticks_msec() < deadline:
		var busy := (
			bool(level.get("_is_resolving_shelves"))
			or bool(level.call("_is_collapse_in_progress"))
			or not (level.get("_clearing_item_ids") as Array).is_empty()
		)
		calm_frames = 0 if busy else calm_frames + 1
		if calm_frames >= 2:
			return
		await tree.process_frame


## Plays one authored move; false when the fixture and its recorded solution disagree.
static func play_move(level: Node, board: CollapsingShelfBoard, move: Array) -> bool:
	var source := find_shelf(board, int(move[0]))
	var target := find_shelf(board, int(move[2]))
	if source == null or target == null or not board.is_shelf_active(source) or not board.is_shelf_active(target):
		push_error("Recorded move %s addresses an unavailable shelf." % [move])
		return false

	var from_slot := source.get_node("Slot%02d" % int(move[1])) as Node2D
	var to_slot := target.get_node("Slot%02d" % int(move[3])) as Node2D
	var item := level.call("_get_slot_item", from_slot) as ShelfItem
	if item == null or not bool(level.call("_move_item_to_slot", item, from_slot, to_slot)):
		push_error("Recorded move %s could not be played." % [move])
		return false

	return true


static func replay(level: Node, tree: SceneTree, board: CollapsingShelfBoard, move_count: int) -> void:
	for move_index in range(mini(move_count, SOLUTION_PREFIX.size())):
		if not play_move(level, board, SOLUTION_PREFIX[move_index]):
			return
		await settle(level, tree)


static func requested_level_number() -> int:
	var requested := OS.get_environment(LEVEL_NUMBER_ENVIRONMENT_VARIABLE).strip_edges()
	return requested.to_int() if requested.is_valid_int() and requested.to_int() > 0 else 0


static func find_shelf(board: CollapsingShelfBoard, authored_number: int) -> Shelf:
	for shelf in board.get_all_shelves():
		if board.get_authored_shelf_id(shelf) == authored_number - 1:
			return shelf as Shelf
	return null
