extends RefCounted

## Capture setup for ADS-005's ready rewarded ability offer.


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.set("launched_from_dev_mode", true)
	scene_root.set("_sound_effects_enabled", false)
	scene_root.set("_loading_transition_pending", false)
	scene_root.call("_open_ability_purchase_menu", &"hammer")
	await tree.create_timer(0.25).timeout
	var purchase = scene_root.get("_ability_purchase_overlay")
	purchase.call("set_ad_action_state", &"ready", true, true)
	for _frame in range(2):
		await tree.process_frame
