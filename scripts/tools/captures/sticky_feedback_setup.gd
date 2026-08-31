extends RefCounted

## Three exposed shapes under held tension; production input is tested separately.
func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root._set_moving_shelf_rows_paused(true)
	scene_root._record_triples_cleared(1)
	await tree.create_timer(0.8).timeout
	var shelves: Array = scene_root._get_all_shelves()
	var pulls := [Vector2(180, -80), Vector2(-180, 0), Vector2(0, -180)]
	for index in range(3):
		var slot: Node2D = scene_root._get_front_slots(shelves[[0, 3, 6][index]])[0]
		var item: ShelfItem = scene_root._get_slot_item(slot)
		item.begin_sticky_hold()
		item.update_sticky_pull(pulls[index])
	await tree.create_timer(0.3).timeout
