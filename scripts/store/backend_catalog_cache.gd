extends RefCounted
class_name BackendCatalogCache

## GAME-008: persists the last successfully joined/priced backend Shop catalog so the Shop can
## render an offline "cached" view when `GET /v1/catalog` is unavailable, unauthorized, or
## malformed. Only already-public catalog/offer/mock-price data is written here -- never a token,
## signature, or other secret.

const DEFAULT_CACHE_PATH := "user://shop_catalog_backend_cache.json"

var _cache_path: String


func _init(cache_path: String = DEFAULT_CACHE_PATH) -> void:
	_cache_path = cache_path


func save(catalog_version: String, offers: Array, country_code: String) -> void:
	var document := {
		"catalog_version": catalog_version,
		"country_code": country_code,
		"offers": offers,
		"cached_at": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(_cache_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(document))


func load_cached() -> Dictionary:
	if not FileAccess.file_exists(_cache_path):
		return {"ok": false}
	var file := FileAccess.open(_cache_path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"ok": false}
	var document := parsed as Dictionary
	var offers = document.get("offers")
	if not (offers is Array) or (offers as Array).is_empty():
		return {"ok": false}
	return {
		"ok": true,
		"offers": offers,
		"country_code": str(document.get("country_code", "")),
		"catalog_version": str(document.get("catalog_version", "")),
	}
