extends RefCounted

## Capture setup for `level.tscn`: a campaign level with its first-time tip showing
## (docs/GAMEPLAY_TIPS.md).
##
## `SORTING_PUZZLE_CAPTURE_TIP_LEVEL` picks the level (default 1). `SORTING_PUZZLE_CAPTURE_TIP_HOLD`
## is how far into the gesture loop to freeze, in seconds; the defaults show the level-1 hand halfway
## through its drag and the level-10 hand just after its press, with the ripple spreading.
##
## The board is rebuilt on every resize, because `capture_ui.ps1` runs a setup once and then resizes
## the window for each resolution, and the dispenser rack is placed against the board when it is built.
##
## ```powershell
## $env:SORTING_PUZZLE_CAPTURE_TIP_LEVEL = '10'
## & .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name gameplay_tip_level_010 -Position '0,0' `
##     -Settle 40 -Setup scripts/tools/captures/gameplay_tips_setup.gd
## ```

const LEVEL_ENVIRONMENT_VARIABLE := "SORTING_PUZZLE_CAPTURE_TIP_LEVEL"
const HOLD_ENVIRONMENT_VARIABLE := "SORTING_PUZZLE_CAPTURE_TIP_HOLD"
const DEFAULT_HOLD_SECONDS := {1: 0.73, 10: 0.3}

var _level: Node
var _tree: SceneTree
var _level_number := 1
var _hold_seconds := 0.0
## Each resize starts a fresh rebuild; an older rebuild still waiting on frames notices and stops.
var _generation := 0


func setup(scene_root: Node, tree: SceneTree) -> void:
	_level = scene_root
	_tree = tree
	_level_number = maxi(int(OS.get_environment(LEVEL_ENVIRONMENT_VARIABLE)), 1)
	var hold_text := OS.get_environment(HOLD_ENVIRONMENT_VARIABLE)
	_hold_seconds = float(hold_text) if not hold_text.is_empty() else float(DEFAULT_HOLD_SECONDS.get(_level_number, 0.5))
	# `capture_scene.gd` drops its reference to a setup once `setup()` returns, which would free this
	# object and silently disconnect the resize handler below.
	scene_root.set_meta(&"gameplay_tips_capture_setup", self)
	scene_root.set("selected_level", _level_number)
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("force_gameplay_tips", true)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_apply_chapter_background")
	tree.root.size_changed.connect(_rebuild)
	await _rebuild()


func _rebuild() -> void:
	_generation += 1
	var generation := _generation
	_level.call("_apply_level_config", _level.call("_load_level_config", _level_number))
	_level.call("_collect_slots")
	_level.call("_update_level_label")
	_level.call("_arm_gameplay_tip")
	var overlay := _level.get_node("UI/GameplayTipOverlay") as GameplayTipOverlay
	for property in ["_start_delay", "_reshow_delay", "_delay_remaining"]:
		overlay.set(property, 0.0)

	for _frame in range(6):
		await _tree.process_frame
		if generation != _generation:
			return

	if not overlay.is_showing():
		push_error("The level %d tip did not show for the capture." % _level_number)
		return

	# Restart the loop and freeze it in the same frame, so every resolution shows the same moment.
	overlay.call("_start_animation")
	overlay.hold_at(_hold_seconds)
