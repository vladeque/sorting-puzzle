extends "res://scripts/store/store_provider.gd"
class_name MockStoreProvider

const DEFAULT_COUNTRY_CODE := "US"
const PURCHASE_DELAY_SECONDS := 0.18

var _country_code := DEFAULT_COUNTRY_CODE
var _purchase_serial := 0


func _init(country_code: String = DEFAULT_COUNTRY_CODE) -> void:
	_country_code = country_code.strip_edges().to_upper()
	if _country_code.is_empty():
		_country_code = DEFAULT_COUNTRY_CODE


func load_products(catalog_offers: Array) -> Dictionary:
	await Engine.get_main_loop().process_frame
	var products := []
	for raw_offer in catalog_offers:
		if not (raw_offer is Dictionary):
			continue

		var offer := raw_offer as Dictionary
		var product_id := str(offer.get("product_id", ""))
		var mock_prices = offer.get("mock_prices", {})
		if product_id.is_empty() or not (mock_prices is Dictionary):
			continue

		var price_map := mock_prices as Dictionary
		var raw_price = price_map.get(_country_code, price_map.get(DEFAULT_COUNTRY_CODE, {}))
		if not (raw_price is Dictionary):
			continue

		var price := raw_price as Dictionary
		var formatted_price := str(price.get("formatted_price", ""))
		if formatted_price.is_empty():
			continue

		products.append({
			"product_id": product_id,
			"formatted_price": formatted_price,
			"currency_code": str(price.get("currency_code", "")),
			"country_code": _country_code,
		})

	return {
		"ok": true,
		"products": products,
		"country_code": _country_code,
	}


func purchase(product_id: String) -> Dictionary:
	if product_id.is_empty():
		return {"ok": false, "error": "The mock product id is empty."}

	await Engine.get_main_loop().create_timer(PURCHASE_DELAY_SECONDS).timeout
	_purchase_serial += 1
	return {
		"ok": true,
		"product_id": product_id,
		"transaction_id": "mock_%s_%d_%d" % [
			product_id.replace(".", "_"),
			Time.get_ticks_msec(),
			_purchase_serial,
		],
	}
