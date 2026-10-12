extends SceneTree

## Release-safety guards (Google Play testing plan step 2.4a and 2.4b): a release build never sells
## through the mock store and never shows the mock leaderboard's invented rivals, while debug builds
## keep both. Release mode is simulated by switching each service's guard field after construction.

const StoreServiceScript := preload("res://scripts/store/store_service.gd")
const LeaderboardServiceScript := preload("res://scripts/leaderboards/leaderboard_service.gd")
const MockLeaderboardProviderScript := preload("res://scripts/leaderboards/mock_leaderboard_provider.gd")

class FakeBackendProvider:
	extends RefCounted

	func get_provider_name() -> String:
		return "backend"

	func fetch_leaderboard(_scope: StringName, _current_player: Dictionary, _limit: int = 50) -> Dictionary:
		return {
			"ok": true,
			"entries": [{"player_id": "real-player", "rank": 1, "score": 40, "is_current_player": false}],
			"player_entry": {},
			"period_end_unix": 0,
			"has_more": false,
			"error": "",
		}

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _check_debug_builds_keep_the_mock_shop_and_rows()
	await _check_release_store_sells_nothing_through_the_mock()
	await _check_release_leaderboard_hides_only_mock_rows()
	if _failures.is_empty():
		print("Release safety guard tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_debug_builds_keep_the_mock_shop_and_rows() -> void:
	_check(OS.is_debug_build(), "these tests run in a debug build")
	var store = StoreServiceScript.new()
	var catalog: Dictionary = await store.load_catalog()
	_check(
		bool(catalog.get("ok", false)) and not (catalog.get("offers", []) as Array).is_empty(),
		"a debug build still lists the mock Shop offers"
	)
	var leaderboard = LeaderboardServiceScript.new(MockLeaderboardProviderScript.new())
	var page: Dictionary = await leaderboard.fetch_leaderboard(&"weekly", _current_player())
	_check(
		(page.get("entries", []) as Array).size() > 1,
		"a debug build still shows the mock leaderboard rows"
	)


func _check_release_store_sells_nothing_through_the_mock() -> void:
	var store = StoreServiceScript.new()
	var debug_catalog: Dictionary = await store.load_catalog()
	var any_offer_id := ""
	for offer in debug_catalog.get("offers", []) as Array:
		any_offer_id = str((offer as Dictionary).get("id", ""))
		break
	_check(not any_offer_id.is_empty(), "the debug catalog loaded an offer to try buying")

	store.set("_real_money_enabled", false)
	var purchase: Dictionary = await store.purchase_offer(StringName(any_offer_id))
	_check(
		not bool(purchase.get("ok", true)) and str(purchase.get("error", "")) == "This shop offer is unavailable.",
		"an offer loaded earlier can no longer be bought once the release guard is on"
	)
	var catalog: Dictionary = await store.load_catalog()
	_check(
		bool(catalog.get("ok", false)) and (catalog.get("offers", []) as Array).is_empty(),
		"a release build lists no real-money offers while only the mock store exists"
	)
	_check(
		str(catalog.get("source", "")) == "release_guard",
		"the empty release catalog says why, so the main menu hides the starter badge"
	)


func _check_release_leaderboard_hides_only_mock_rows() -> void:
	var mock_service = LeaderboardServiceScript.new(MockLeaderboardProviderScript.new())
	mock_service.set("_hide_mock_rows", true)
	var hidden: Dictionary = await mock_service.fetch_leaderboard(&"weekly", _current_player())
	_check(bool(hidden.get("ok", false)), "the hidden mock leaderboard is not an error")
	_check((hidden.get("entries", []) as Array).is_empty(), "a release build shows no mock rows")
	_check(
		(hidden.get("player_entry", {}) as Dictionary).is_empty(),
		"a release build ranks the player against no one, so no weekly rank is recorded"
	)

	var backend_service = LeaderboardServiceScript.new(FakeBackendProvider.new())
	backend_service.set("_hide_mock_rows", true)
	var real: Dictionary = await backend_service.fetch_leaderboard(&"weekly", _current_player())
	_check(
		(real.get("entries", []) as Array).size() == 1,
		"a release build still shows real backend leaderboard rows"
	)


func _current_player() -> Dictionary:
	return {
		"player_id": "local_player",
		"display_name": "Tester",
		"avatar_id": "avatar_cat",
		"avatar_frame_id": "frame_classic",
		"country_code": "",
		"total_score": 120,
		"weekly_score": 40,
		"week_end_unix": 0,
	}


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
