extends RefCounted

## Opens the catalog-backed Main Menu offer and shows its purchase-complete state for review.
func setup(scene_root: Node, tree: SceneTree) -> void:
	await scene_root.call("_refresh_starter_bundle_offer")
	await scene_root.call("_open_starter_bundle_offer")
	scene_root.get_node("%StarterBundleOfferModal").call("show_success")
	# Let the shell's 0.34 s pop-in finish so the capture shows the settled, fully opaque modal.
	await tree.create_timer(0.6).timeout
	for _index in range(5):
		await tree.process_frame
