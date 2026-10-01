extends RefCounted

## Buys the catalog-backed Main Menu Starter Bundle through the mock store and holds the purchase
## reward sequence on its reveal: the "PURCHASE COMPLETE" ribbon over the granted coins and
## boosters, with the Main Menu dimmed behind it.
##
##     & .\scripts\tools\capture_ui.ps1 -Scene scenes/main_menu.tscn -Name starter_purchase_reward `
##         -Setup scripts/tools/captures/starter_bundle_purchase_reward_setup.gd

const SupportScript := preload("res://scripts/tools/captures/purchase_reward_capture_support.gd")


func setup(scene_root: Node, tree: SceneTree) -> void:
	var sequence := scene_root.get_node("%PurchaseRewardSequence")
	SupportScript.prepare(sequence)
	await scene_root.call("_refresh_starter_bundle_offer")
	await scene_root.call("_open_starter_bundle_offer")
	await tree.create_timer(0.5).timeout
	await scene_root.call("_buy_starter_bundle")
	# The burst, the ribbon pop, and every reward settling into the row.
	await tree.create_timer(1.4).timeout
	SupportScript.pin_tap_hint(sequence)
