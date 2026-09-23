extends RefCounted

## Capture setup for `level.tscn`: a throwing-dispensers board, with the rack above it.
##
## Two views, chosen by `SORTING_PUZZLE_CAPTURE_THROW_TAPS`: `0` (the default) is the level as the
## player first sees it -- an empty board and full dispensers -- and a higher number taps each
## dispenser that many times so the shot shows thrown items sitting on the shelves.
##
## The board is rebuilt on every resize because `capture_ui.ps1` runs a setup once and then resizes
## the window for each resolution. The rack is placed against the shelves' bounds when the level is
## built, so a capture taken without rebuilding would show the previous resolution's placement.
##
## ```powershell
## & .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name throwing_dispensers -Position '0,0' `
##     -Settle 30 -Setup scripts/tools/captures/throwing_dispensers_setup.gd
## ```

const FIXTURE_PATH := "res://configs/test_levels/throwing_dispensers_preview.json"
const TAP_COUNT_ENVIRONMENT_VARIABLE := "SORTING_PUZZLE_CAPTURE_THROW_TAPS"

var _level: Node
var _tree: SceneTree
## Each resize starts a fresh rebuild. Without this counter the previous rebuild's coroutine carried
## on throwing into the board the new one had just reset, and the captured board showed whichever
## partial sequence happened to finish last.
var _generation := 0


func setup(scene_root: Node, tree: SceneTree) -> void:
	_level = scene_root
	_tree = tree
	# `capture_scene.gd` drops its reference to a setup once `setup()` returns, which would free this
	# object and silently disconnect the resize handler below.
	scene_root.set_meta(&"throwing_dispensers_capture_setup", self)
	scene_root.set("_sound_effects_enabled", false)
	# Land every thrown item instantly. A capture that raced the flight showed items still drawn at
	# the dispenser mouth and one dispenser's badge not yet decremented, which reads as a layout bug
	# rather than as the half-finished animation it was.
	scene_root.set("thrown_item_flight_seconds", 0.0)
	scene_root.set("thrown_item_stagger_seconds", 0.0)
	tree.root.size_changed.connect(_rebuild)
	await _rebuild()


func _rebuild() -> void:
	_generation += 1
	var generation := _generation
	var fixture := FileAccess.get_file_as_string(FIXTURE_PATH)
	var config = JSON.parse_string(fixture)
	if not config is Dictionary:
		push_error("Could not read the throwing dispensers fixture at %s." % FIXTURE_PATH)
		return

	_level.call("_apply_level_config", config)
	_level.call("_collect_slots")
	if not await _settle(generation):
		return

	var taps := int(OS.get_environment(TAP_COUNT_ENVIRONMENT_VARIABLE))
	if taps <= 0:
		return

	var rack := _level.get_node_or_null("Shelves/ThrowingDispenserRack") as ThrowingDispenserRack
	if rack == null:
		return

	# Through the scene's own signal, so the capture shows what a tap actually produces rather than a
	# board arranged by the setup.
	for _tap_index in range(taps):
		for dispenser in rack.get_dispensers():
			dispenser.throw_requested.emit()
			if not await _settle(generation):
				return


## False once a newer rebuild has started, which is this coroutine's cue to stop touching the board.
func _settle(generation: int) -> bool:
	for _frame in range(8):
		await _tree.process_frame
		if generation != _generation:
			return false

	return true
