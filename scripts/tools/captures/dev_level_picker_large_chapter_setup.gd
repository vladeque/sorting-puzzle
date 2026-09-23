extends RefCounted

## Fills the testing menu's level picker with a chapter the size Chapter 1 is planned to reach, so
## the scrolling grid can be reviewed at its intended scale instead of at today's twenty levels.

const LEVEL_COUNT := 500
## Reviewed level. It sits deep in the list so the capture also shows the picker scrolling a late
## level into view rather than resting on the first row.
const FOCUS_LEVEL := 473


func setup(scene_root: Node, tree: SceneTree) -> void:
	var picker := scene_root.get_node_or_null("%LevelPicker")
	if picker == null:
		push_error("dev_level_picker_large_chapter_setup could not find %LevelPicker.")
		return

	var levels := PackedInt32Array()
	for level_number in range(1, LEVEL_COUNT + 1):
		levels.append(level_number)
	picker.call("set_levels", levels, FOCUS_LEVEL)
	for _frame in range(3):
		await tree.process_frame
