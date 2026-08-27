extends RefCounted

## Capture setup for the ordinary tap-selection treatment on a representative real level board.

const LEVEL_NUMBER := 5


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("selected_level", LEVEL_NUMBER)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_apply_level_config", scene_root.call("_load_level_config", LEVEL_NUMBER))
	scene_root.call("_collect_slots")

	for _frame in range(4):
		await tree.process_frame

	var visible_items := scene_root.call("_get_visible_items") as Array
	var shelf_items: Array[ShelfItem] = []
	for candidate_variant in visible_items:
		var candidate := candidate_variant as ShelfItem
		var shelf := candidate.get_parent().get_parent()
		if shelf != null and shelf.has_method("accepts_dropped_items") and shelf.call("accepts_dropped_items"):
			shelf_items.append(candidate)

	if shelf_items.is_empty():
		return

	var viewport_center: Vector2 = scene_root.get_viewport_rect().size * 0.5
	var selected_item := shelf_items[0]
	var best_distance: float = selected_item.global_position.distance_squared_to(viewport_center)
	for candidate in shelf_items:
		var distance := candidate.global_position.distance_squared_to(viewport_center)
		if distance < best_distance:
			selected_item = candidate
			best_distance = distance

	scene_root.call("_set_selected_item", selected_item, selected_item.get_parent() as Node2D)
	await tree.process_frame
