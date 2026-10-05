extends RefCounted

## Diagnostic claimed-chip preview for localized count/name fitting. Prepares the existing offer
## without making a purchase or granting rewards, then switches its chips to their claimed state.
const OfferSetup := preload("res://scripts/tools/captures/starter_bundle_offer_setup.gd")


func setup(scene_root: Node, tree: SceneTree) -> void:
	await OfferSetup.new().setup(scene_root, tree)
	var modal := scene_root.get_node_or_null("%StarterBundleOfferModal") as Control
	if modal == null:
		push_error("starter_bundle_claimed_boosters_setup could not open the offer.")
		return
	for chip_name in ["HammerReward", "ShuffleReward", "LanternReward", "FreezerReward"]:
		var chip := modal.find_child(chip_name, true, false)
		chip.call("set_claimed", true)
	for _frame in range(3):
		await tree.process_frame
