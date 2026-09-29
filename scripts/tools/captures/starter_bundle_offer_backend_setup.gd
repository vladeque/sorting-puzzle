extends RefCounted

## Opens the Main Menu offer, then binds a backend-shaped Starter Bundle (three boosters, no Freezer)
## with a long regional price so the centered booster row and Buy label fit can be reviewed.
func setup(scene_root: Node, tree: SceneTree) -> void:
	await scene_root.call("_refresh_starter_bundle_offer")
	await scene_root.call("_open_starter_bundle_offer")
	scene_root.get_node("%StarterBundleOfferModal").call("set_offer", {
		"id": "starter_bundle",
		"type": "bundle",
		"rewards": {"coins": 1000, "abilities": {"hammer": 3, "shuffle": 3, "highlight": 3}},
		"discount_percent": 67,
		"store": {"formatted_price": "₴199.99", "compare_at_formatted_price": "₴599.99"},
	})
	# Let the shell's 0.34 s pop-in finish so the capture shows the settled, fully opaque modal.
	await tree.create_timer(0.6).timeout
	for _index in range(5):
		await tree.process_frame
