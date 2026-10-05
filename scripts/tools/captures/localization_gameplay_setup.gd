extends "res://scripts/tools/captures/level_board_setup.gd"

## Locale review of the playable board, HUD, numeric combo and ability counters.
## Capture the full level at -Position '0,0'; the generic tool otherwise centers Node2D components.
func setup(scene_root: Node, tree: SceneTree) -> void:
	await super.setup(scene_root, tree)
	scene_root.get("_top_hud").call("set_combo", true, 3, 0.65)
	scene_root.set("_app_interrupted", true)
