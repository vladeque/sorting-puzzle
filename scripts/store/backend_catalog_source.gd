extends RefCounted
class_name BackendCatalogSource

## GAME-008: sources Shop offers from the authenticated backend development catalog
## (`GET /v1/catalog`, read through the shared GAME-007 `BackendTransport`). Eligibility, rewards,
## and platform product IDs are authoritative from the backend response -- this class never widens
## eligibility, invents a reward, or trusts any local file for whether an offer may be shown.
##
## Regional price formatting and purchase execution remain entirely local/mock: every eligible
## offer is joined against `configs/backend/shop_catalog_prices.json` by `platform_product_id` and
## priced through the same `price_provider` (`MockStoreProvider`) the local catalog uses. This
## class never calls a purchase-intent or verification endpoint.
##
## Loading, empty, unavailable, unauthorized, and malformed responses all resolve through
## `_fall_back_to_cache()`: a successful read refreshes `BackendCatalogCache`; any failure serves
## the last cached catalog when one exists, and only surfaces an error when no cache is available
## either, matching the "offline cached display" requirement.

const BackendReadOperationsScript := preload("res://scripts/backend/backend_read_operations.gd")
const BackendCatalogCacheScript := preload("res://scripts/store/backend_catalog_cache.gd")
const PRESENTATION_PATH := "res://configs/backend/shop_catalog_prices.json"

const BUNDLE_TYPES := ["starter", "timed_bundle", "evergreen_bundle"]
const COIN_TYPES := ["coin_pack"]

var _transport
var _cache: RefCounted


func _init(transport, cache_path: String = "") -> void:
	_transport = transport
	_cache = BackendCatalogCacheScript.new(cache_path) if not cache_path.is_empty() else BackendCatalogCacheScript.new()


func load_catalog(price_provider) -> Dictionary:
	if _transport == null or not _transport.can_use_backend():
		return _fall_back_to_cache("The development backend is not available.")

	var read_result: Dictionary = await _transport.get_json(BackendReadOperationsScript.catalog_path())
	if not bool(read_result.get("ok", false)):
		var error := read_result.get("error", {}) as Dictionary
		var message := str(error.get("message", ""))
		return _fall_back_to_cache(message if not message.is_empty() else "The shop catalog is temporarily unavailable.")

	var parsed := BackendReadOperationsScript.parse_catalog(read_result.get("data"))
	if not bool(parsed.get("ok", false)):
		return _fall_back_to_cache("The shop catalog response was malformed.")

	var offers := parsed.get("offers", []) as Array
	if offers.is_empty():
		_cache.save(str(parsed.get("catalog_version", "")), [], "")
		return {
			"ok": true,
			"offers": [],
			"country_code": "",
			"catalog_version": str(parsed.get("catalog_version", "")),
			"source": "live",
		}

	var join_result: Dictionary = await _join_offers(offers, price_provider)
	if not bool(join_result.get("ok", false)):
		return _fall_back_to_cache(str(join_result.get("error", "Could not price the shop catalog.")))

	var joined_offers := join_result.get("offers", []) as Array
	var country_code := str(join_result.get("country_code", ""))
	var catalog_version := str(parsed.get("catalog_version", ""))
	_cache.save(catalog_version, joined_offers, country_code)
	return {
		"ok": true,
		"offers": joined_offers,
		"country_code": country_code,
		"catalog_version": catalog_version,
		"source": "live",
	}


func _join_offers(offers: Array, price_provider) -> Dictionary:
	var presentation := _load_presentation()
	var eligible_offers := []
	var priceable := []
	for raw_offer in offers:
		if not (raw_offer is Dictionary):
			continue
		var offer := raw_offer as Dictionary
		if not bool(offer.get("eligible", false)):
			continue
		var ui_type := _map_offer_type(str(offer.get("type", "")))
		if ui_type.is_empty():
			continue
		var product_id := str(offer.get("platform_product_id", ""))
		var presentation_entry = presentation.get(product_id)
		if not (presentation_entry is Dictionary):
			continue

		eligible_offers.append({"offer": offer, "ui_type": ui_type, "presentation": presentation_entry})
		priceable.append({
			"product_id": product_id,
			"mock_prices": (presentation_entry as Dictionary).get("mock_prices", {}),
		})

	var product_result: Dictionary = await price_provider.load_products(priceable)
	if not bool(product_result.get("ok", false)):
		return {"ok": false, "error": str(product_result.get("error", ""))}

	var products_by_id := {}
	for raw_product in product_result.get("products", []) as Array:
		if raw_product is Dictionary:
			var product := raw_product as Dictionary
			products_by_id[str(product.get("product_id", ""))] = product

	var joined := []
	for entry in eligible_offers:
		var offer := entry.get("offer") as Dictionary
		var product_id := str(offer.get("platform_product_id", ""))
		var product = products_by_id.get(product_id)
		if not (product is Dictionary):
			continue

		var presentation_entry := entry.get("presentation") as Dictionary
		joined.append({
			"id": str(offer.get("offer_id", "")),
			"product_id": product_id,
			"type": str(entry.get("ui_type", "")),
			"title": str(presentation_entry.get("title", "")),
			"rewards": (offer.get("rewards", {}) as Dictionary).duplicate(true),
			"store": (product as Dictionary).duplicate(true),
		})

	return {
		"ok": true,
		"offers": joined,
		"country_code": str(product_result.get("country_code", "")),
	}


func _map_offer_type(backend_type: String) -> String:
	if BUNDLE_TYPES.has(backend_type):
		return "bundle"
	if COIN_TYPES.has(backend_type):
		return "coins"
	return ""


func _load_presentation() -> Dictionary:
	if not FileAccess.file_exists(PRESENTATION_PATH):
		return {}
	var file := FileAccess.open(PRESENTATION_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	var raw_entries = (parsed as Dictionary).get("prices", [])
	if not (raw_entries is Array):
		return {}

	var by_product_id := {}
	for raw_entry in raw_entries as Array:
		if not (raw_entry is Dictionary):
			continue
		var entry := raw_entry as Dictionary
		var product_id := str(entry.get("platform_product_id", "")).strip_edges()
		var title := str(entry.get("title", "")).strip_edges()
		var mock_prices = entry.get("mock_prices", {})
		if product_id.is_empty() or title.is_empty() or not (mock_prices is Dictionary):
			continue
		by_product_id[product_id] = {"title": title, "mock_prices": mock_prices}
	return by_product_id


func _fall_back_to_cache(error_message: String) -> Dictionary:
	var cached: Dictionary = _cache.load_cached()
	if bool(cached.get("ok", false)):
		return {
			"ok": true,
			"offers": cached.get("offers", []),
			"country_code": cached.get("country_code", ""),
			"catalog_version": cached.get("catalog_version", ""),
			"source": "cached",
		}
	return {
		"ok": false,
		"error": error_message,
		"offers": [],
		"country_code": "",
		"catalog_version": "",
		"source": "unavailable",
	}
