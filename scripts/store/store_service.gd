extends RefCounted
class_name StoreService

const MockStoreProviderScript := preload("res://scripts/store/mock_store_provider.gd")
const BackendCatalogSourceScript := preload("res://scripts/store/backend_catalog_source.gd")
const CATALOG_PATH := "res://configs/shop_catalog.json"
const STORE_PROVIDER_SETTING := "application/config/store_provider"
const MOCK_COUNTRY_SETTING := "application/config/mock_store_country"
const CATALOG_SOURCE_SETTING := "application/config/shop_catalog_source"
const PROVIDER_MOCK := "mock"
const CATALOG_SOURCE_LOCAL := "local"
const CATALOG_SOURCE_BACKEND := "backend"

var _provider: RefCounted
var _catalog_source: RefCounted
var _offers_by_id := {}


func _init() -> void:
	_provider = _create_provider()
	_catalog_source = _create_catalog_source()


## GAME-008: when `shop_catalog_source` selects `backend`, offers come from the authenticated
## backend development catalog (eligibility, rewards, and product IDs are authoritative there);
## price formatting and purchase execution still go through `_provider` (mock), unchanged. The
## default `local` source keeps reading the bundled `configs/shop_catalog.json` exactly as before.
func load_catalog() -> Dictionary:
	var result: Dictionary = (
		await _catalog_source.load_catalog(_provider)
		if _catalog_source != null
		else await _load_local_catalog()
	)
	if not bool(result.get("ok", false)):
		return result

	_offers_by_id.clear()
	var available_offers := []
	for raw_offer in result.get("offers", []) as Array:
		if not (raw_offer is Dictionary):
			continue
		var offer := raw_offer as Dictionary
		if _catalog_source == null and not _is_local_offer_available(offer):
			continue
		_offers_by_id[str(offer.get("id", ""))] = offer
		available_offers.append(offer)
	result["offers"] = available_offers

	return result


func _load_local_catalog() -> Dictionary:
	var catalog_result := _load_catalog_file()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result

	var offers := catalog_result.get("offers", []) as Array
	var product_result: Dictionary = await _provider.load_products(offers)
	if not bool(product_result.get("ok", false)):
		return product_result

	var products_by_id := {}
	for raw_product in product_result.get("products", []) as Array:
		if raw_product is Dictionary:
			var product := raw_product as Dictionary
			products_by_id[str(product.get("product_id", ""))] = product

	var available_offers := []
	for raw_offer in offers:
		if not (raw_offer is Dictionary):
			continue

		var offer := (raw_offer as Dictionary).duplicate(true)
		var product_id := str(offer.get("product_id", ""))
		var product = products_by_id.get(product_id)
		if not (product is Dictionary):
			continue

		offer.erase("mock_prices")
		offer["store"] = (product as Dictionary).duplicate(true)
		available_offers.append(offer)

	return {
		"ok": true,
		"offers": available_offers,
		"country_code": str(product_result.get("country_code", "")),
	}


func purchase_offer(offer_id: StringName) -> Dictionary:
	var offer = _offers_by_id.get(String(offer_id))
	if not (offer is Dictionary):
		return {"ok": false, "error": "This shop offer is unavailable."}

	var offer_dictionary := offer as Dictionary
	if _catalog_source == null and not _is_local_offer_available(offer_dictionary):
		_offers_by_id.erase(String(offer_id))
		return {"ok": false, "error": "This one-time shop offer has already been purchased."}
	var purchase_result: Dictionary = await _provider.purchase(str(offer_dictionary.get("product_id", "")))
	if not bool(purchase_result.get("ok", false)):
		return purchase_result

	return {
		"ok": true,
		"offer_id": String(offer_id),
		"product_id": str(offer_dictionary.get("product_id", "")),
		"transaction_id": str(purchase_result.get("transaction_id", "")),
		"rewards": (offer_dictionary.get("rewards", {}) as Dictionary).duplicate(true),
	}


func _load_catalog_file() -> Dictionary:
	if not FileAccess.file_exists(CATALOG_PATH):
		return {"ok": false, "error": "Shop catalog is missing."}

	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Shop catalog could not be opened."}

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"ok": false, "error": "Shop catalog is not valid JSON."}

	var raw_offers = (parsed as Dictionary).get("offers", [])
	if not (raw_offers is Array):
		return {"ok": false, "error": "Shop catalog offers must be an array."}

	var offers := []
	for raw_offer in raw_offers as Array:
		var offer := _sanitize_offer(raw_offer)
		if not offer.is_empty():
			offers.append(offer)

	if offers.is_empty():
		return {"ok": false, "error": "Shop catalog has no valid offers."}

	return {"ok": true, "offers": offers}


func _sanitize_offer(raw_offer) -> Dictionary:
	if not (raw_offer is Dictionary):
		return {}

	var offer := raw_offer as Dictionary
	var offer_id := str(offer.get("id", "")).strip_edges()
	var product_id := str(offer.get("product_id", "")).strip_edges()
	var offer_type := str(offer.get("type", "")).to_lower()
	var rewards = offer.get("rewards", {})
	if offer_id.is_empty() or product_id.is_empty() or offer_type not in ["bundle", "coins"]:
		return {}
	if not (rewards is Dictionary):
		return {}

	var sanitized := offer.duplicate(true)
	sanitized["id"] = offer_id
	sanitized["product_id"] = product_id
	sanitized["type"] = offer_type
	sanitized["title"] = str(offer.get("title", offer_id))
	if offer.has("purchase_limit"):
		var purchase_limit := int(offer.get("purchase_limit", 0))
		if purchase_limit <= 0:
			return {}
		sanitized["purchase_limit"] = purchase_limit
		var limit_period := str(offer.get("limit_period", "")).to_lower()
		if limit_period not in ["lifetime", "campaign", "day", "week", "offer_window"]:
			return {}
		sanitized["limit_period"] = limit_period
	return sanitized


func _is_local_offer_available(offer: Dictionary) -> bool:
	if not _is_lifetime_single_purchase_offer(offer):
		return true
	var player_progress = _find_player_progress()
	return (
		player_progress == null
		or not player_progress.has_method("has_purchased_shop_offer")
		or not bool(
			player_progress.call(
				"has_purchased_shop_offer",
				StringName(str(offer.get("id", "")))
			)
		)
	)


func _is_lifetime_single_purchase_offer(offer: Dictionary) -> bool:
	return (
		int(offer.get("purchase_limit", 0)) == 1
		and str(offer.get("limit_period", "")).to_lower() == "lifetime"
	)


func _create_provider() -> RefCounted:
	var provider_id := str(ProjectSettings.get_setting(STORE_PROVIDER_SETTING, PROVIDER_MOCK)).to_lower()
	if provider_id != PROVIDER_MOCK:
		push_warning("Unknown store provider '%s'; using mock store." % provider_id)

	var country_code := str(ProjectSettings.get_setting(MOCK_COUNTRY_SETTING, "US"))
	return MockStoreProviderScript.new(country_code)


## GAME-008: `shop_catalog_source` is independent of `store_provider` -- it only selects where the
## offer list/eligibility/rewards come from. Price formatting and purchase execution always go
## through `_provider` (mock), even when offers come from the backend, per this ticket's
## requirement to keep price lookup and purchasing explicitly local/mock.
func _create_catalog_source() -> RefCounted:
	var source_id := str(ProjectSettings.get_setting(CATALOG_SOURCE_SETTING, CATALOG_SOURCE_LOCAL)).to_lower()
	if source_id == CATALOG_SOURCE_BACKEND:
		return BackendCatalogSourceScript.new(_find_backend_transport())
	if source_id != CATALOG_SOURCE_LOCAL:
		push_warning("Unknown shop catalog source '%s'; using the local catalog." % source_id)
	return null


## Looks up the `PlayerProgress` autoload by name instead of the bare global identifier, so this
## script (which headless tooling/tests may `preload()` before autoloads are registered) never
## takes a hard compile-time dependency on singleton resolution order.
func _find_backend_transport():
	var player_progress = _find_player_progress()
	return player_progress.get_backend_transport() if player_progress != null else null


func _find_player_progress():
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	return (main_loop as SceneTree).root.get_node_or_null("PlayerProgress")
