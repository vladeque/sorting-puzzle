extends "res://scripts/level.gd"

## Debug-build preview of the `collapsing_columns` mode on the development fixture, reached from
## `scenes/main_menu_testing.tscn`. It plays the ordinary level runtime; only the config source, the
## HUD title, and retry/return routing differ. The window resolves from the device exactly as it
## would for a campaign level, so the preview is also the touch-device check for this mode.

const PREVIEW_CONFIG := "res://configs/test_levels/collapsing_columns_preview.json"
const PREVIEW_SCENE := "res://scenes/testing/collapsing_columns_preview.tscn"


func _ready() -> void:
	launched_from_dev_mode = true
	return_menu_scene_path = "res://scenes/main_menu_testing.tscn"
	super._ready()
	_top_hud.set_level_text("COLUMNS PREVIEW")


func _load_level_config(_level_number: int) -> Dictionary:
	return _load_json_file(PREVIEW_CONFIG)


func _restart_level() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	var next := (load(PREVIEW_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(next)
	get_tree().current_scene = next
	queue_free()
