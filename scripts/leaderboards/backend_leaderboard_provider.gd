extends "res://scripts/leaderboards/leaderboard_provider.gd"
class_name BackendLeaderboardProvider

## GAME-009: sources Weekly, Country, and World leaderboard pages from the authenticated backend
## (`GET /v1/leaderboards/{scope}`, read through the shared GAME-007 `BackendTransport`). Entries,
## current-player placement, period end, and the pagination cursor are all authoritative from the
## already-contract-tested `BackendReadOperations.parse_leaderboard()` -- this class never re-derives
## rank/score locally and never infers a country when the backend's no-country response omits one.
##
## Loading, empty, unavailable, unauthorized, and malformed responses all resolve through
## `_fall_back_to_cache()`, mirroring `scripts/store/backend_catalog_source.gd`'s GAME-008 pattern:
## a successful read refreshes `BackendLeaderboardCache` for that scope; any failure serves the last
## cached page for that scope when one exists, and only surfaces an error when no cache is available
## either.

const BackendReadOperationsScript := preload("res://scripts/backend/backend_read_operations.gd")
const BackendLeaderboardCacheScript := preload("res://scripts/leaderboards/backend_leaderboard_cache.gd")
const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")

var _transport
var _cache: RefCounted


func _init(transport, cache_path: String = "") -> void:
	_transport = transport
	_cache = (
		BackendLeaderboardCacheScript.new(cache_path)
		if not cache_path.is_empty()
		else BackendLeaderboardCacheScript.new()
	)


func get_provider_name() -> String:
	return "backend"


func fetch_leaderboard(
	scope: StringName,
	_current_player: Dictionary,
	limit: int = 50
) -> Dictionary:
	return await fetch_page(scope, limit, "")


## `cursor` requests a later page. The screen only ever requests the backend's full 50-row max page
## in one call today, so `fetch_leaderboard()` above never passes one; this is exposed as its own
## method so callers/tests can exercise cursor forwarding and cursor-expiry error handling
## independently of the screen's current single-page use.
func fetch_page(scope: StringName, limit: int, cursor: String = "") -> Dictionary:
	if scope not in VALID_SCOPES:
		return _error("Unknown leaderboard scope: %s" % scope)

	var scope_name := String(scope)
	if _transport == null or not _transport.can_use_backend():
		return _fall_back_to_cache(scope_name, "The development backend is not available.")

	var path := BackendReadOperationsScript.leaderboard_path(scope_name, limit, cursor)
	var read_result: Dictionary = await _transport.get_json(path)
	if not bool(read_result.get("ok", false)):
		var error := read_result.get("error", {}) as Dictionary
		var message := str(error.get("message", ""))
		return _fall_back_to_cache(
			scope_name,
			message if not message.is_empty() else "The leaderboard is temporarily unavailable."
		)

	var parsed := BackendReadOperationsScript.parse_leaderboard(read_result.get("data"))
	if not bool(parsed.get("ok", false)):
		return _fall_back_to_cache(scope_name, "The leaderboard response was malformed.")

	var entries := parsed.get("entries", []) as Array
	var player_entry := _resolve_player_entry(parsed, entries)
	var period_end_unix := _resolve_period_end_unix(parsed)
	var has_more := not str(parsed.get("next_cursor", "")).is_empty()

	_cache.save(scope_name, entries, player_entry, period_end_unix)
	return _success(entries, player_entry, period_end_unix, has_more)


## The backend only includes `current_player` when the authenticated player is outside the
## returned page (see backend `leaderboard-query-store.ts`'s `playerIsInPage` check); when the
## player is within the page, their row is only present inside `entries`.
func _resolve_player_entry(parsed: Dictionary, entries: Array) -> Dictionary:
	if parsed.get("current_player") is Dictionary:
		return (parsed.get("current_player") as Dictionary).duplicate(true)
	for raw_entry in entries:
		if raw_entry is Dictionary and bool((raw_entry as Dictionary).get("is_current_player", false)):
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _resolve_period_end_unix(parsed: Dictionary) -> int:
	var period_end := str(parsed.get("period_end", ""))
	return LocalSaveCodecScript.unix_from_timestamp(period_end) if not period_end.is_empty() else 0


func _fall_back_to_cache(scope: String, error_message: String) -> Dictionary:
	var cached: Dictionary = _cache.load_cached(scope)
	if bool(cached.get("ok", false)):
		return _success(
			cached.get("entries", []) as Array,
			cached.get("player_entry", {}) as Dictionary,
			int(cached.get("period_end_unix", 0)),
			false
		)
	return _error(error_message)
