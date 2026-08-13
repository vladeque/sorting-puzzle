extends RefCounted

## Capture setup for `level.tscn`: rebuilds the board from a chosen level config so a real playable
## layout can be reviewed as pixels.
##
## `_ready()` has already built whatever `selected_level` defaulted to by the time a setup script
## runs, so this re-applies the wanted config and refreshes the slot cache the same way
## `tests/gameplay/test_dispenser_shelf.gd` does after rebuilding a board.

const LEVEL_NUMBER := 5


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_apply_level_config", scene_root.call("_load_level_config", LEVEL_NUMBER))
	scene_root.call("_collect_slots")

	for _frame in range(4):
		await tree.process_frame
