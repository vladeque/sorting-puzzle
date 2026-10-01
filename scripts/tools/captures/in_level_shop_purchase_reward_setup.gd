extends RefCounted

## Opens the in-level Shop from Ability Purchase, buys the Basic Bundle through the mock store, and
## freezes its purchase reward sequence mid-flight: coins rise to the overlay's counter and, with no
## Home tab in the overlay, boosters drop toward the level's ability bar underneath it.
## Time-sensitive, so capture one resolution with a short settle:
##
##     & .\scripts\tools\capture_ui.ps1 -Scene scenes/level.tscn -Name in_level_purchase_flight `
##         -Setup scripts/tools/captures/in_level_shop_purchase_reward_setup.gd `
##         -Resolutions '720x1280' -Settle 1

const SupportScript := preload("res://scripts/tools/captures/purchase_reward_capture_support.gd")
const FLIGHT_SECONDS := 4.0


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.call("_open_ability_purchase_menu", &"hammer")
	await tree.create_timer(0.35).timeout
	scene_root.call("_open_in_level_shop")
	await tree.create_timer(0.8).timeout
	var shop := scene_root.get_node("UI/InLevelShopOverlay")
	SupportScript.prepare(shop.get_node("%PurchaseRewardSequence"), FLIGHT_SECONDS)
	shop.call("_purchase_offer", &"new_player_bundle")
	await tree.create_timer(3.6).timeout
