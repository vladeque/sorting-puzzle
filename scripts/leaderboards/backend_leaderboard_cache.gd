extends RefCounted
class_name BackendLeaderboardCache

## GAME-009: persists the last successfully fetched backend leaderboard page per scope so the
## leaderboard screen can render an offline "cached" view when `GET /v1/leaderboards/{scope}` is
## unavailable, unauthorized, or malformed. Mirrors `scripts/store/backend_catalog_cache.gd`'s
## GAME-008 shape/behavior. Only already-public entries/rank/score/period data is written here --
## never a token, signature, or pagination cursor.

const DEFAULT_CACHE_PATH := "user://leaderboard_backend_cache.json"

var _cache_path: String


func _init(cache_path: String = DEFAULT_CACHE_PATH) -> void:
	_cache_path = cache_path


func save(scope: String, entries: Array, player_entry: Dictionary, period_end_unix: int) -> void:
	var document := _load_document()
	document[scope] = {
		"entries": entries,
		"player_entry": player_entry,
		"period_end_unix": period_end_unix,
		"cached_at": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(_cache_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(document))


func load_cached(scope: String) -> Dictionary:
	var entry = _load_document().get(scope)
	if not (entry is Dictionary):
		return {"ok": false}
	var cached := entry as Dictionary
	var entries = cached.get("entries")
	if not (entries is Array) or (entries as Array).is_empty():
		return {"ok": false}
	var player_entry = cached.get("player_entry")
	return {
		"ok": true,
		"entries": entries,
		"player_entry": (player_entry as Dictionary).duplicate(true) if player_entry is Dictionary else {},
		"period_end_unix": int(cached.get("period_end_unix", 0)),
	}


func _load_document() -> Dictionary:
	if not FileAccess.file_exists(_cache_path):
		return {}
	var file := FileAccess.open(_cache_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
