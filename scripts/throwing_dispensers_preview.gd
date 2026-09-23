extends "res://scripts/level.gd"

## Debug-build preview of the `throwing_dispensers` mode on the development fixture, reached from
## `scenes/main_menu_testing.tscn`. It plays the ordinary level runtime; only the config source, the
## HUD title, and retry/return routing differ.
##
## This is also the touch-device check for the mode: tapping a dispenser is a new kind of target on
## the board, and how it feels under a thumb -- and whether taps near the top of a tall screen are
## comfortable at all -- is not something a capture can answer.

const PREVIEW_CONFIG := "res://configs/test_levels/throwing_dispensers_preview.json"
const PREVIEW_SCENE := "res://scenes/testing/throwing_dispensers_preview.tscn"


func _ready() -> void:
	launched_from_dev_mode = true
	return_menu_scene_path = "res://scenes/main_menu_testing.tscn"
	super._ready()
	# Short on purpose: the HUD's level slot runs into the timer at "DISPENSERS PREVIEW" on a 720px
	# wide screen, where the collapsing preview's shorter "COLUMNS PREVIEW" still fits.
	_top_hud.set_level_text("THROW PREVIEW")


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
