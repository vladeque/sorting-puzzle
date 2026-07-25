extends SceneTree

## GAME-009 coverage for the backend leaderboard integration
## (scripts/leaderboards/backend_leaderboard_provider.gd, scripts/leaderboards/backend_leaderboard_cache.gd,
## and scripts/leaderboards/leaderboard_service.gd's `leaderboard_provider` selection).
##
## Feeds BackendLeaderboardProvider synthetic transport outcomes through the same test-double
## pattern tests/backend/test_game_007.gd and tests/backend/test_game_008.gd already established for
## BackendTransport (a subclass overriding only the _send_get/_send_post/_wait_before_retry network
## seams), so these checks never open a real socket. Every check exercises the real
## BackendReadOperations.parse_leaderboard() adapter -- nothing about response parsing is faked.

const BackendTransportScript := preload("res://scripts/backend/backend_transport.gd")
const BackendLeaderboardProviderScript := preload("res://scripts/leaderboards/backend_leaderboard_provider.gd")
const BackendLeaderboardCacheScript := preload("res://scripts/leaderboards/backend_leaderboard_cache.gd")
const LeaderboardServiceScript := preload("res://scripts/leaderboards/leaderboard_service.gd")
const LeaderboardProviderScript := preload("res://scripts/leaderboards/leaderboard_provider.gd")

const TEST_PLAYER_ID := "00000000-0000-4000-8000-000000000001"
const TEST_DEVICE_ID := "00000000-0000-4000-8000-000000000002"

var _failures := PackedStringArray()
var _created_transports := []
var _cache_paths := []


class FakeSessionStore:
	extends RefCounted
	var session := {
		"session_id": "00000000-0000-4000-8000-0000000000a1",
		"access_token": "initial-access-token",
		"access_token_expires_at": "2026-07-14T09:05:00.000Z",
		"refresh_token": "initial-refresh-token",
		"refresh_token_expires_at": "2026-08-14T09:00:00.000Z",
	}
	var store_calls := []

	func load_session(_player_id: String) -> Dictionary:
		return {"ok": true, "session": session.duplicate(true)}

	func get_device_id() -> String:
		return TEST_DEVICE_ID

	func store_session(player_id: String, new_session: Dictionary) -> Dictionary:
		store_calls.append({"player_id": player_id, "session": new_session.duplicate(true)})
		session = new_session.duplicate(true)
		return {"ok": true}


class FakeTransport:
	extends BackendTransportScript
	var get_queue := []
	var post_queue := []
	var get_calls := []

	func _send_get(url: String, headers: PackedStringArray) -> Array:
		get_calls.append({"url": url, "headers": headers})
		if get_queue.is_empty():
			return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
		return get_queue.pop_front()

	func _send_post(url: String, headers: PackedStringArray, body: String) -> Array:
		if post_queue.is_empty():
			return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
		return post_queue.pop_front()

	func _wait_before_retry(_attempt: int, _retry_after_seconds: int) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Deferred + one process_frame, matching tests/backend/test_game_008.gd's convention: the
	# PlayerProgress autoload (touched indirectly through LeaderboardService._create_provider() in
	# the selection checks below) is not guaranteed to be ready during this script's own _init().
	await process_frame
	await _run_provider_tests()
	_run_leaderboard_service_selection_tests()
	_finish()


func _finish() -> void:
	for transport in _created_transports:
		(transport as Node).free()
	for path in _cache_paths:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	if _failures.is_empty():
		print("GAME-009 backend leaderboard tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# ---------------------------------------------------------------------------
# BackendLeaderboardProvider checks
# ---------------------------------------------------------------------------

func _run_provider_tests() -> void:
	await _check_current_player_outside_page_is_pinned_from_current_player_field()
	await _check_current_player_inside_page_is_found_in_entries()
	await _check_ties_preserve_backend_rank_and_order()
	await _check_empty_rankings_is_ok_with_no_entries()
	await _check_country_no_country_response_never_infers_country_locally()
	await _check_next_cursor_reports_has_more()
	await _check_unavailable_without_cache_is_an_error()
	await _check_unavailable_falls_back_to_cache()
	await _check_unauthorized_without_cache_is_an_error()
	await _check_malformed_response_falls_back_to_cache()
	await _check_cursor_expiry_is_a_terminal_error()
	await _check_backend_disabled_short_circuits()
	await _check_unknown_scope_is_rejected_locally()


func _check_current_player_outside_page_is_pinned_from_current_player_field() -> void:
	var provider := _make_provider(_next_cache_path())
	var transport = provider.get("transport")
	(transport as FakeTransport).get_queue = [
		_leaderboard_success(
			"weekly",
			[
				_entry("00000000-0000-4000-8000-000000000071", 1, 120, "player_top01", false),
				_entry("00000000-0000-4000-8000-000000000072", 2, 100, "player_top02", false),
			],
			"weekly-2026-07-13",
			"2026-07-20T00:00:00.000Z",
			"",
			_entry(TEST_PLAYER_ID, 51, 65, "player_demo1", true),
		),
	]
	var result: Dictionary = await provider.get("provider").fetch_leaderboard(&"weekly", {}, 50)
	_check(bool(result.get("ok", false)), "weekly fetch with an outside-page player succeeds")
	var entries := result.get("entries", []) as Array
	_check(entries.size() == 2, "weekly page returns the two top entries")
	var player_entry := result.get("player_entry", {}) as Dictionary
	_check(str(player_entry.get("player_id", "")) == TEST_PLAYER_ID, "player_entry comes from the current_player field")
	_check(int(player_entry.get("rank", 0)) == 51, "player_entry keeps the backend-reported rank")
	_check(result.get("period_end_unix", 0) is int and int(result.get("period_end_unix", 0)) > 0, "period_end is converted to a unix timestamp")


func _check_current_player_inside_page_is_found_in_entries() -> void:
	var provider := _make_provider(_next_cache_path())
	var transport = provider.get("transport")
	(transport as FakeTransport).get_queue = [
		_leaderboard_success(
			"world",
			[
				_entry("00000000-0000-4000-8000-000000000071", 1, 500, "player_top01", false),
				_entry(TEST_PLAYER_ID, 2, 400, "player_demo1", true),
			],
			"",
			"",
			"",
			{},
		),
	]
	var result: Dictionary = await provider.get("provider").fetch_leaderboard(&"world", {}, 50)
	_check(bool(result.get("ok", false)), "world fetch with an inside-page player succeeds")
	var player_entry := result.get("player_entry", {}) as Dictionary
	_check(str(player_entry.get("player_id", "")) == TEST_PLAYER_ID, "player_entry is recovered from entries when current_player is absent")
	_check(int(result.get("period_end_unix", 0)) == 0, "world scope has no period end")


func _check_ties_preserve_backend_rank_and_order() -> void:
	var provider := _make_provider(_next_cache_path())
	var transport = provider.get("transport")
	(transport as FakeTransport).get_queue = [
		_leaderboard_success(
			"world",
			[
				_entry("00000000-0000-4000-8000-000000000071", 1, 300, "player_a", false),
				_entry("00000000-0000-4000-8000-000000000072", 1, 300, "player_b", false),
				_entry("00000000-0000-4000-8000-000000000073", 3, 250, "player_c", false),
			],
			"",
			"",
			"",
			{},
		),
	]
	var result: Dictionary = await provider.get("provider").fetch_leaderboard(&"world", {}, 50)
	var entries := result.get("entries", []) as Array
	_check(int((entries[0] as Dictionary).get("rank", 0)) == 1, "the first tied entry keeps competition rank 1")
	_check(int((entries[1] as Dictionary).get("rank", 0)) == 1, "the second tied entry keeps competition rank 1")
	_check(int((entries[2] as Dictionary).get("rank", 0)) == 3, "the entry after a tie skips to competition rank 3")


func _check_empty_rankings_is_ok_with_no_entries() -> void:
	var provider := _make_provider(_next_cache_path())
	var transport = provider.get("transport")
	(transport as FakeTransport).get_queue = [_leaderboard_success("world", [], "", "", "", {})]
	var result: Dictionary = await provider.get("provider").fetch_leaderboard(&"world", {}, 50)
	_check(bool(result.get("ok", false)), "an empty leaderboard is not an error")
	_check((result.get("entries", []) as Array).is_empty(), "an empty leaderboard returns no entries")
	_check((result.get("player_entry", {}) as Dictionary).is_empty(), "an empty leaderboard has no player entry")


func _check_country_no_country_response_never_infers_country_locally() -> void:
	# Matches the backend's documented no-country response for scope=country: entries: [], no
	# period_id/period_end/current_player/next_cursor (leaderboard-query-store.ts's
	# `if (period === undefined) return { scope, entries: [], limit }`). This provider must render
	# that exactly as an empty board, never guessing or defaulting a country locally.
	var provider := _make_provider(_next_cache_path())
	var transport = provider.get("transport")
	(transport as FakeTransport).get_queue = [_leaderboard_success("country", [], "", "", "", {})]
	var result: Dictionary = await provider.get("provider").fetch_leaderboard(&"country", {}, 50)
	_check(bool(result.get("ok", false)), "the no-country response is not an error")
	_check((result.get("entries", []) as Array).is_empty(), "the no-country response has no entries")
	_check(int(result.get("period_end_unix", 0)) == 0, "the no-country response has no period end")


func _check_next_cursor_reports_has_more() -> void:
	var provider := _make_provider(_next_cache_path())
	var transport = provider.get("transport")
	(transport as FakeTransport).get_queue = [
		_leaderboard_success(
			"world",
			[_entry("00000000-0000-4000-8000-000000000071", 1, 900, "player_a", false)],
			"",
			"",
			"Zml4dHVyZS1wYWdlLTI",
			{},
		),
	]
	var result: Dictionary = await provider.get("provider").fetch_leaderboard(&"world", {}, 1)
	_check(bool(result.get("ok", false)), "a page with a next cursor still succeeds")
	_check(bool(result.get("has_more", false)), "a non-empty next_cursor reports has_more true")


func _check_unavailable_without_cache_is_an_error() -> void:
	var provider := _make_provider(_next_cache_path())
	var transport = provider.get("transport")
	(transport as FakeTransport).get_queue = [
		_error_response(503, "dependency.leaderboard_unavailable", true),
		_error_response(503, "dependency.leaderboard_unavailable", true),
		_error_response(503, "dependency.leaderboard_unavailable", true),
		_error_response(503, "dependency.leaderboard_unavailable", true),
		_error_response(503, "dependency.leaderboard_unavailable", true),
	]
	var result: Dictionary = await provider.get("provider").fetch_leaderboard(&"weekly", {}, 50)
	_check(not bool(result.get("ok", true)), "an unavailable leaderboard with no cache is a terminal error")
	_check(not str(result.get("error", "")).is_empty(), "the unavailable error carries a message")


func _check_unavailable_falls_back_to_cache() -> void:
	var cache_path := _next_cache_path()
	var live_provider := _make_provider(cache_path)
	(live_provider.get("transport") as FakeTransport).get_queue = [
		_leaderboard_success(
			"weekly",
			[_entry("00000000-0000-4000-8000-000000000071", 1, 900, "player_a", false)],
			"weekly-2026-07-13",
			"2026-07-20T00:00:00.000Z",
			"",
			{},
		),
	]
	var live_result: Dictionary = await live_provider.get("provider").fetch_leaderboard(&"weekly", {}, 50)
	_check(bool(live_result.get("ok", false)), "priming fetch for the cache test succeeds")

	var offline_provider := _make_provider(cache_path)
	(offline_provider.get("transport") as FakeTransport).get_queue = [
		_error_response(503, "dependency.leaderboard_unavailable", true),
		_error_response(503, "dependency.leaderboard_unavailable", true),
		_error_response(503, "dependency.leaderboard_unavailable", true),
		_error_response(503, "dependency.leaderboard_unavailable", true),
		_error_response(503, "dependency.leaderboard_unavailable", true),
	]
	var offline_result: Dictionary = await offline_provider.get("provider").fetch_leaderboard(&"weekly", {}, 50)
	_check(bool(offline_result.get("ok", false)), "a later unavailable fetch serves the cached page")
	_check(
		not (offline_result.get("entries", []) as Array).is_empty(),
		"the cached fallback still has the previously fetched entries"
	)
	_check(not bool(offline_result.get("has_more", true)), "a cached fallback page never claims more pages")


func _check_unauthorized_without_cache_is_an_error() -> void:
	# A 401 makes BackendTransport attempt exactly one refresh-and-replay (proven by
	# tests/backend/test_game_007.gd). No refresh response is queued here, so the refresh's own
	# transport call fails and the read is terminal without ever consuming a second GET -- this
	# check only needs to confirm that outcome surfaces as a leaderboard error with no cache to fall
	# back on.
	var provider := _make_provider(_next_cache_path())
	var transport = provider.get("transport")
	(transport as FakeTransport).get_queue = [_error_response(401, "auth.token_expired", false)]
	var result: Dictionary = await provider.get("provider").fetch_leaderboard(&"weekly", {}, 50)
	_check(not bool(result.get("ok", true)), "an unauthorized read with no cache is a terminal error")
	_check((transport as FakeTransport).get_calls.size() == 1, "the failed refresh never replays the read")


func _check_malformed_response_falls_back_to_cache() -> void:
	var cache_path := _next_cache_path()
	var live_provider := _make_provider(cache_path)
	(live_provider.get("transport") as FakeTransport).get_queue = [
		_leaderboard_success(
			"weekly",
			[_entry("00000000-0000-4000-8000-000000000071", 1, 900, "player_a", false)],
			"weekly-2026-07-13",
			"2026-07-20T00:00:00.000Z",
			"",
			{},
		),
	]
	await live_provider.get("provider").fetch_leaderboard(&"weekly", {}, 50)

	var malformed_provider := _make_provider(cache_path)
	var malformed_entry := _entry("00000000-0000-4000-8000-000000000071", 1, 900, "player_a", false)
	malformed_entry.erase("rank")
	(malformed_provider.get("transport") as FakeTransport).get_queue = [
		_leaderboard_success("weekly", [malformed_entry], "weekly-2026-07-13", "2026-07-20T00:00:00.000Z", "", {}),
	]
	var result: Dictionary = await malformed_provider.get("provider").fetch_leaderboard(&"weekly", {}, 50)
	_check(bool(result.get("ok", false)), "a malformed response falls back to the cached page")
	_check(not (result.get("entries", []) as Array).is_empty(), "the malformed-response fallback still has cached entries")


func _check_cursor_expiry_is_a_terminal_error() -> void:
	var provider := _make_provider(_next_cache_path())
	var transport = provider.get("transport")
	(transport as FakeTransport).get_queue = [_error_response(400, "request.invalid_cursor", false)]
	var result: Dictionary = await provider.get("provider").fetch_page(&"weekly", 50, "expired-cursor")
	_check(not bool(result.get("ok", true)), "an expired/invalid cursor with no cache is a terminal error")
	_check((transport as FakeTransport).get_calls.size() == 1, "an invalid cursor is not retried")


func _check_backend_disabled_short_circuits() -> void:
	var original_url: String = ProjectSettings.get_setting("application/config/backend_base_url", "")
	ProjectSettings.set_setting("application/config/backend_base_url", "")
	var transport := FakeTransport.new()
	_created_transports.append(transport)
	transport.configure(FakeSessionStore.new(), func(): return TEST_PLAYER_ID)
	var cache_path := _next_cache_path()
	var provider := BackendLeaderboardProviderScript.new(transport, cache_path)
	var result: Dictionary = await provider.fetch_leaderboard(&"weekly", {}, 50)
	ProjectSettings.set_setting("application/config/backend_base_url", original_url)
	_check(not bool(result.get("ok", true)), "a disabled backend with no cache is an error")
	_check((transport as FakeTransport).get_calls.is_empty(), "a disabled backend never issues a GET")


func _check_unknown_scope_is_rejected_locally() -> void:
	var provider := _make_provider(_next_cache_path())
	var result: Dictionary = await provider.get("provider").fetch_leaderboard(&"galaxy", {}, 50)
	_check(not bool(result.get("ok", true)), "an unrecognized scope is rejected before any request is sent")
	_check(
		(provider.get("transport") as FakeTransport).get_calls.is_empty(),
		"an unrecognized scope never issues a GET"
	)


# ---------------------------------------------------------------------------
# LeaderboardService selection checks
# ---------------------------------------------------------------------------

func _run_leaderboard_service_selection_tests() -> void:
	var original_provider: String = ProjectSettings.get_setting("application/config/leaderboard_provider", "mock")

	ProjectSettings.set_setting("application/config/leaderboard_provider", "mock")
	var mock_service := LeaderboardServiceScript.new()
	_check(mock_service.get_provider_name() == "mock", "the default mock provider is selected")

	ProjectSettings.set_setting("application/config/leaderboard_provider", "backend")
	var backend_service := LeaderboardServiceScript.new()
	_check(backend_service.get_provider_name() == "backend", "selecting 'backend' constructs the backend provider")

	ProjectSettings.set_setting("application/config/leaderboard_provider", "nonsense")
	var fallback_service := LeaderboardServiceScript.new()
	_check(
		fallback_service.get_provider_name() == "mock",
		"an unknown leaderboard_provider value falls back to the mock provider"
	)

	ProjectSettings.set_setting("application/config/leaderboard_provider", original_provider)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_provider(cache_path: String) -> Dictionary:
	var original_url: String = ProjectSettings.get_setting("application/config/backend_base_url", "")
	if original_url.strip_edges().is_empty():
		ProjectSettings.set_setting("application/config/backend_base_url", "http://127.0.0.1:8080")
	var transport := FakeTransport.new()
	transport.configure(FakeSessionStore.new(), func(): return TEST_PLAYER_ID)
	_created_transports.append(transport)
	return {
		"transport": transport,
		"provider": BackendLeaderboardProviderScript.new(transport, cache_path),
	}


func _next_cache_path() -> String:
	var path := "user://test_game_009_cache_%d_%d.json" % [Time.get_ticks_usec(), _cache_paths.size()]
	_cache_paths.append(path)
	return path


func _entry(
	player_id: String,
	rank: int,
	score: int,
	display_name: String,
	is_current_player: bool,
	country_code: String = ""
) -> Dictionary:
	var entry := {
		"player_id": player_id,
		"rank": rank,
		"score": score,
		"display_name": display_name,
		"avatar_id": "avatar_cat",
		"is_current_player": is_current_player,
	}
	if not country_code.is_empty():
		entry["country_code"] = country_code
	return entry


func _leaderboard_success(
	scope: String,
	entries: Array,
	period_id: String,
	period_end: String,
	next_cursor: String,
	current_player: Dictionary
) -> Array:
	var data := {
		"scope": scope,
		"entries": entries,
		"limit": 50,
	}
	if not period_id.is_empty():
		data["period_id"] = period_id
	if not period_end.is_empty():
		data["period_end"] = period_end
	if not next_cursor.is_empty():
		data["next_cursor"] = next_cursor
	if not current_player.is_empty():
		data["current_player"] = current_player
	var envelope := {
		"meta": {
			"protocol_version": "1.0",
			"request_id": "00000000-0000-4000-8000-0000000000c1",
			"correlation_id": "00000000-0000-4000-8000-0000000000c1",
			"server_time": "2026-07-14T09:00:00.000Z",
		},
		"data": data,
	}
	return [HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer()]


func _error_response(code: int, error_code: String, retryable: bool) -> Array:
	var envelope := {
		"meta": {
			"protocol_version": "1.0",
			"request_id": "00000000-0000-4000-8000-0000000000c2",
			"correlation_id": "00000000-0000-4000-8000-0000000000c2",
			"server_time": "2026-07-14T09:00:00.000Z",
		},
		"error": {
			"code": error_code,
			"category": (
				"rate_limit" if code == 429
				else ("authentication" if code == 401 else ("validation" if code == 400 else "dependency"))
			),
			"message": "synthetic test error",
			"retryable": retryable,
		},
	}
	return [HTTPRequest.RESULT_SUCCESS, code, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer()]


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
