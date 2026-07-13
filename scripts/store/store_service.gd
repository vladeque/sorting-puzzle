extends RefCounted
class_name StoreService

const MockStoreProviderScript := preload("res://scripts/store/mock_store_provider.gd")
const CATALOG_PATH := "res://configs/shop_catalog.json"
const STORE_PROVIDER_SETTING := "application/config/store_provider"
const MOCK_COUNTRY_SETTING := "application/config/mock_store_country"
const PROVIDER_MOCK := "mock"

var _provider: RefCounted
var _offers_by_id := {}


func _init() -> void:
	_provider = _create_provider()


func load_catalog() -> Dictionary:
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

	_offers_by_id.clear()
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
		_offers_by_id[str(offer.get("id", ""))] = offer

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
	return sanitized


func _create_provider() -> RefCounted:
	var provider_id := str(ProjectSettings.get_setting(STORE_PROVIDER_SETTING, PROVIDER_MOCK)).to_lower()
	if provider_id != PROVIDER_MOCK:
		push_warning("Unknown store provider '%s'; using mock store." % provider_id)

	var country_code := str(ProjectSettings.get_setting(MOCK_COUNTRY_SETTING, "US"))
	return MockStoreProviderScript.new(country_code)
