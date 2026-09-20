extends RefCounted

## Reveals the optional cabinet body on a moving shelf so shared shelf-art changes can be captured.


func setup(scene_root: Node, _tree: SceneTree) -> void:
	var shelf := scene_root as Shelf
	if shelf == null:
		push_error("moving_shelf_full_setup expects a Shelf scene root.")
		return

	shelf.set_visual_variant(Shelf.VISUAL_VARIANT_FULL)
	shelf.set_row_placement(Shelf.ROW_PLACEMENT_MIDDLE)
