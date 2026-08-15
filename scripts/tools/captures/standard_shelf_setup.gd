extends RefCounted

## Capture setup for `scenes/shelf.tscn`: exposes the middle-placement top cap so the complete
## standard light-oak frame can be reviewed without constructing a whole level.


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("set_row_placement", Shelf.ROW_PLACEMENT_MIDDLE)
	scene_root.call("set_top_ceiling_cap_visible", true)

	for _frame in range(2):
		await tree.process_frame
