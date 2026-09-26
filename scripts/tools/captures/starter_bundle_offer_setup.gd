extends RefCounted

## Opens the catalog-backed Main Menu offer for responsive screenshot review.
func setup(scene_root: Node, tree: SceneTree) -> void:
	await scene_root.call("_refresh_starter_bundle_offer")
	await scene_root.call("_open_starter_bundle_offer")
	for _index in range(25):
		await tree.process_frame
