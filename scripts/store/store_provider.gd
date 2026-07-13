extends RefCounted
class_name StoreProvider


func load_products(_catalog_offers: Array) -> Dictionary:
	return {
		"ok": false,
		"error": "Store provider does not implement product loading.",
	}


func purchase(_product_id: String) -> Dictionary:
	return {
		"ok": false,
		"error": "Store provider does not implement purchases.",
	}
