extends RefCounted

## Capture setup for `level.tscn`: renders one `layout_preset` on a real board so a shelf placement
## template can be reviewed as pixels before any level is authored against it.
##
## The preset name comes from the `SORTING_PUZZLE_CAPTURE_LAYOUT_PRESET` environment variable, so one
## script covers every preset:
##
## ```powershell
## $env:SORTING_PUZZLE_CAPTURE_LAYOUT_PRESET = 'staggered_rows_2_3_2'
## & .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name layout_staggered_rows_2_3_2 `
##     -Setup scripts/tools/captures/layout_preset_setup.gd
## ```
##
## Shelf contents come from `BOARD_SOURCE_LEVEL`, trimmed to exactly as many shelves as the preset
## authored. Counting the preset's own markers is what keeps the capture honest: a shelf count that
## disagrees with the template makes `scripts/level.gd` fall back to `grid_3x3`, which would quietly
## photograph the wrong layout.
##
## Moving rows are paused after the board is built so every resolution captures the same authored
## belt offset instead of wherever the belt happened to have travelled.

const BOARD_SOURCE_LEVEL := 4
const LAYOUT_PRESET_ENVIRONMENT_VARIABLE := "SORTING_PUZZLE_CAPTURE_LAYOUT_PRESET"
const LAYOUT_SCENE_TEMPLATE := "res://scenes/layouts/layout_%s.tscn"


func setup(scene_root: Node, tree: SceneTree) -> void:
	var layout_preset := OS.get_environment(LAYOUT_PRESET_ENVIRONMENT_VARIABLE).strip_edges()
	if layout_preset.is_empty():
		push_error(
			"Set %s to the layout preset to capture." % LAYOUT_PRESET_ENVIRONMENT_VARIABLE
		)
		return

	var shelf_count := _get_layout_preset_shelf_count(layout_preset)
	if shelf_count <= 0:
		push_error("Layout preset '%s' has no shelf markers to capture." % layout_preset)
		return

	var config := scene_root.call("_load_level_config", BOARD_SOURCE_LEVEL) as Dictionary
	var source_shelves := config.get("shelves", []) as Array
	if source_shelves.is_empty():
		push_error("Level %d has no shelves to capture with." % BOARD_SOURCE_LEVEL)
		return

	# A preset with more shelves than the source level reuses its shelves from the start. Repeating a
	# shelf cannot create a match, because a triple has to sit inside one shelf's own visible layer.
	var board_shelves := []
	for shelf_index in range(shelf_count):
		board_shelves.append(source_shelves[shelf_index % source_shelves.size()])

	config["layout_preset"] = layout_preset
	config["shelves"] = board_shelves

	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_apply_level_config", config)
	scene_root.call("_collect_slots")
	scene_root.call("_set_moving_shelf_rows_paused", true)

	for _frame in range(4):
		await tree.process_frame


## Mirrors `scripts/level.gd`'s own template accounting: `ShelfXX` markers contribute one shelf each
## and a `ShelfLayoutRow` contributes its whole `shelf_count`, whether or not the row is on screen.
func _get_layout_preset_shelf_count(layout_preset: String) -> int:
	var layout_scene_path := LAYOUT_SCENE_TEMPLATE % layout_preset
	if not ResourceLoader.exists(layout_scene_path):
		push_error("Layout preset '%s' has no template at %s." % [layout_preset, layout_scene_path])
		return 0

	var layout_scene := load(layout_scene_path) as PackedScene
	if layout_scene == null:
		push_error("Layout preset '%s' could not load from %s." % [layout_preset, layout_scene_path])
		return 0

	var layout_template := layout_scene.instantiate() as Node2D
	if layout_template == null:
		push_error("Layout preset '%s' is not a Node2D scene." % layout_preset)
		return 0

	var shelf_count := 0
	for layout_node in layout_template.get_children():
		if layout_node is ShelfLayoutRow:
			shelf_count += (layout_node as ShelfLayoutRow).shelf_count
		elif layout_node is Marker2D and str(layout_node.name).begins_with("Shelf"):
			shelf_count += 1

	layout_template.queue_free()
	return shelf_count
