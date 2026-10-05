extends RefCounted

## Renders reviewed starter-offer copy, prices, all booster names and the busy-status clearance.
func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("set_offer", {
		"rewards": {"coins": 1000, "abilities": {"hammer": 3, "shuffle": 3, "highlight": 3, "freezer": 3}},
		"store": {"formatted_price": "$4.99", "compare_at_formatted_price": "$14.99"},
		"discount_percent": 67,
	})
	var layout := func() -> void:
		scene_root.call("apply_safe_layout", Vector4.ZERO, scene_root.get_viewport_rect().size)
	tree.root.size_changed.connect(layout)
	layout.call()
	scene_root.call("open")
	await tree.create_timer(0.4).timeout
	match OS.get_environment("SORTING_PUZZLE_CAPTURE_STARTER_STATE"):
		"busy":
			scene_root.call("set_busy", "Purchasing…")
		"error":
			scene_root.call("show_error", TranslationServer.translate("shop.error.purchase_failed"), true)
		"claimed":
			for name in ["HammerReward", "ShuffleReward", "LanternReward", "FreezerReward"]:
				scene_root.get_node("%" + name).call("set_claimed", true)
	for frame in range(4):
		await tree.process_frame
