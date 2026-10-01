extends RefCounted
class_name ShopPurchaseFlow

const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")
const HapticsCatalogScript := preload("res://scripts/haptics/haptics_catalog.gd")

var _store_service: RefCounted
var _player_progress: Node


func _init(store_service: RefCounted, player_progress: Node) -> void:
	_store_service = store_service
	_player_progress = player_progress


## One purchase/grant boundary for the Shop and the Main Menu offer modal. The provider result
## supplies the transaction and reward payload; the save keeps transaction application idempotent.
func execute(offer_id: StringName) -> Dictionary:
	var purchase_result: Dictionary = await _store_service.purchase_offer(offer_id)
	if not bool(purchase_result.get("ok", false)):
		return {
			"ok": false,
			"stage": "purchase",
			"error": str(purchase_result.get("error", "The mock purchase could not be completed.")),
		}

	var rewards := purchase_result.get("rewards", {}) as Dictionary
	var grant_result: Dictionary = _player_progress.apply_shop_purchase(
		str(purchase_result.get("transaction_id", "")),
		rewards,
		str(purchase_result.get("offer_id", ""))
	)
	if not bool(grant_result.get("ok", false)):
		return {
			"ok": false,
			"stage": "grant",
			"error": str(grant_result.get("error", "The purchased rewards could not be granted.")),
		}

	return {"ok": true, "grant": grant_result, "rewards": rewards}


## The purchase confirmation cue and haptic, played as the purchase reward sequence bursts open. Its
## coin flights play coin_gain as each coin lands, so no coin cue is layered here.
static func play_success_feedback(grant_result: Dictionary) -> void:
	if not bool(grant_result.get("applied", false)):
		return
	SfxManager.play(SfxCatalogScript.EVENT_SHOP_PURCHASE_SUCCESS)
	HapticsManager.play(HapticsCatalogScript.EVENT_SHOP_PURCHASE_SUCCESS)
