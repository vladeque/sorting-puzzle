extends RefCounted

## Expose back-layer artwork in empty front slots, then promote the moving-row anchor. One capture
## shows a pink front marker, unmarked back previews, and an amber marker revealed after promotion.
func setup(scene_root: Node, tree: SceneTree) -> void:
	var config: Dictionary = scene_root._load_level_config(1)
	for shelf_index in [0, 3, 6]:
		var shelf: Dictionary = config.shelves[shelf_index]
		shelf.layers[1][2] = shelf.layers[1][0]
		shelf.layers[1][0] = null
		shelf.sticky_items[1].slot = 2
	scene_root.item_move_duration_seconds = 0.0
	scene_root.layer_promotion_duration_seconds = 0.0
	scene_root.match_gather_duration_seconds = 0.0
	scene_root.match_shrink_duration_seconds = 0.0
	scene_root._apply_level_config(config)
	scene_root._collect_slots()
	scene_root._set_preview_variant("both")
	scene_root._set_moving_shelf_rows_paused(true)
	for frame in range(12):
		await tree.process_frame
	var shelves: Array = scene_root._get_all_shelves()
	for slot_index in [0, 1]:
		var source: Node2D = scene_root._get_front_slots(shelves[7])[slot_index]
		var target: Node2D = scene_root._get_front_slots(shelves[6])[slot_index + 1]
		scene_root._move_item_to_slot(scene_root._get_slot_item(source), source, target)
		for frame in range(12):
			await tree.process_frame
	# Keep the comparison board still while capture_ui cycles resolutions.
	scene_root._set_moving_shelf_rows_paused(true)
	scene_root._has_player_started_timer = false
	await tree.create_timer(1.0).timeout
