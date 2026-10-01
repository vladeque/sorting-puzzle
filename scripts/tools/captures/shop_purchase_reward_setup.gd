extends RefCounted

## Buys an offer in the destination Shop through the mock store and captures its purchase reward
## sequence. By default it holds the reveal: the "PURCHASE COMPLETE" ribbon over the Basic Bundle's
## coins and boosters. Environment overrides:
##
## - `SORTING_PUZZLE_CAPTURE_OFFER`: another offer id, e.g. `coins_750` for a coins-only reveal.
## - `SORTING_PUZZLE_CAPTURE_FLIGHT=1`: freeze the coins and boosters mid-flight to the header
##   counter and the Home tab instead. Time-sensitive, so capture one resolution with a short settle:
##
##     & .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/shop_screen.tscn -Name shop_purchase_flight `
##         -Setup scripts/tools/captures/shop_purchase_reward_setup.gd -Resolutions '720x1280' -Settle 1

const SupportScript := preload("res://scripts/tools/captures/purchase_reward_capture_support.gd")
const DEFAULT_OFFER := &"new_player_bundle"
const FLIGHT_SECONDS := 4.0


func setup(scene_root: Node, tree: SceneTree) -> void:
	var offer_id := StringName(OS.get_environment("SORTING_PUZZLE_CAPTURE_OFFER"))
	if offer_id.is_empty():
		offer_id = DEFAULT_OFFER
	var capture_flight := OS.get_environment("SORTING_PUZZLE_CAPTURE_FLIGHT") == "1"
	var sequence := scene_root.get_node("%PurchaseRewardSequence")
	SupportScript.prepare(sequence, FLIGHT_SECONDS if capture_flight else 0.0)
	# Let the catalog load before buying.
	await tree.create_timer(0.5).timeout
	scene_root.call("_purchase_offer", offer_id)
	if capture_flight:
		await tree.create_timer(3.4).timeout
		return
	await tree.create_timer(1.6).timeout
	SupportScript.pin_tap_hint(sequence)
