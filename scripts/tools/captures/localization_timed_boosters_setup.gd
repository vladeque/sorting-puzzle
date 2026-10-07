extends "res://scripts/tools/captures/localization_gameplay_setup.gd"

## Hold localized countdown badges while the capture tool resizes the playable board.
func setup(scene_root: Node, tree: SceneTree) -> void:
	await super.setup(scene_root, tree)
	var ability_bar := scene_root.get("_ability_bar") as AbilityBar
	ability_bar.set_active_seconds(&"highlight", 15.0)
	ability_bar.set_active_seconds(&"freezer", 30.0)
