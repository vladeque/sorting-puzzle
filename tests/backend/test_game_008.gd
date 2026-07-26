extends SceneTree

## GAME-008 coverage for the backend Shop catalog integration
## (scripts/store/backend_catalog_source.gd, scripts/store/backend_catalog_cache.gd, and
## scripts/store/store_service.gd's `shop_catalog_source` selection).
##
## Feeds BackendCatalogSource synthetic transport outcomes through the same test-double pattern
## tests/backend/test_game_007.gd already established for BackendTransport (a subclass overriding
## only the _send_get/_send_post/_wait_before_retry network seams), so these checks never open a
## real socket. Every check exercises the real BackendReadOperations.parse_catalog() adapter and
## the real MockStoreProvider price join -- nothing about response parsing or pricing is faked.

const BackendTransportScript := preload("res://scripts/backend/backend_transport.gd")
const BackendCatalogSourceScript := preload("res://scripts/store/backend_catalog_source.gd")
const BackendCatalogCacheScript := preload("res://scripts/store/backend_catalog_cache.gd")
const MockStoreProviderScript := preload("res://scripts/store/mock_store_provider.gd")
const StoreServiceScript := preload("res://scripts/store/store_service.gd")

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
	# Deferred + one process_frame, matching tests/save/test_player_progress_facade.gd's
	# convention: the PlayerProgress autoload (touched indirectly through
	# StoreService._create_catalog_source() in the selection checks below) is not guaranteed to be
	# ready during this script's own _init().
	await process_frame
	await _run_source_tests()
	_run_store_service_selection_tests()
	_finish()


func _finish() -> void:
	for transport in _created_transports:
		(transport as Node).free()
	for path in _cache_paths:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	if _failures.is_empty():
		print("GAME-008 backend Shop catalog tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# ---------------------------------------------------------------------------
# BackendCatalogSource checks
# ---------------------------------------------------------------------------

func _run_source_tests() -> void:
	await _check_eligible_offers_are_joined_and_priced()
	await _check_historic_bundle_without_freezer_remains_compatible()
	await _check_ineligible_offers_are_excluded()
	await _check_unknown_offer_type_is_excluded()
	await _check_offer_without_local_price_entry_is_excluded()
	await _check_empty_catalog_is_ok_with_no_offers()
	await _check_unavailable_without_cache_is_an_error()
	await _check_unavailable_falls_back_to_cache()
	await _check_unauthorized_without_cache_is_an_error()
	await _check_malformed_response_falls_back_to_cache()
	await _check_backend_disabled_short_circuits()


func _check_eligible_offers_are_joined_and_priced() -> void:
	var source := _make_source(_next_cache_path())
	var transport = source.get("transport")
	(transport as FakeTransport).get_queue = [
		_catalog_success([
			_backend_offer("starter_bundle", "starter", "sorting_puzzle.local.starter_bundle", true),
			_backend_offer("coin_pack_small", "coin_pack", "sorting_puzzle.local.coin_pack_small", true),
		]),
	]
	var result: Dictionary = await source.get("source").load_catalog(_price_provider())
	_check(bool(result.get("ok", false)), "eligible catalog fetch succeeds")
	_check(str(result.get("source", "")) == "live", "eligible catalog fetch reports a live source")
	var offers := result.get("offers", []) as Array
	_check(offers.size() == 2, "both eligible offers are returned")
	var starter := _find_offer(offers, "starter_bundle")
	_check(str(starter.get("type", "")) == "bundle", "starter offer type maps to bundle")
	_check(str(starter.get("title", "")) == "Starter Bundle", "starter offer title comes from the local presentation table")
	_check(int((starter.get("rewards", {}) as Dictionary).get("coins", -1)) == 1000, "starter offer rewards come from the backend")
	_check(
		int(
			((starter.get("rewards", {}) as Dictionary).get("abilities", {}) as Dictionary).get(
				"freezer",
				-1
			)
		) == 3,
		"new starter catalog versions retain three Freezer rewards"
	)
	var starter_store := starter.get("store", {}) as Dictionary
	_check(str(starter_store.get("formatted_price", "")) == "$4.99", "starter offer price is joined from the mock price table")
	var coins := _find_offer(offers, "coin_pack_small")
	_check(str(coins.get("type", "")) == "coins", "coin pack offer type maps to coins")


func _check_historic_bundle_without_freezer_remains_compatible() -> void:
	var source := _make_source(_next_cache_path())
	var historic_offer := _backend_offer(
		"starter_bundle",
		"starter",
		"sorting_puzzle.local.starter_bundle",
		true
	)
	((historic_offer.get("rewards", {}) as Dictionary).get("abilities", {}) as Dictionary).erase(
		"freezer"
	)
	(source.get("transport") as FakeTransport).get_queue = [_catalog_success([historic_offer])]
	var result: Dictionary = await source.get("source").load_catalog(_price_provider())
	_check(bool(result.get("ok", false)), "historic starter catalog without Freezer remains valid")
	var starter := _find_offer(result.get("offers", []) as Array, "starter_bundle")
	var abilities := (starter.get("rewards", {}) as Dictionary).get("abilities", {}) as Dictionary
	_check(int(abilities.get("freezer", -1)) == 0, "historic starter catalog grants no Freezer")


func _check_ineligible_offers_are_excluded() -> void:
	var source := _make_source(_next_cache_path())
	var transport = source.get("transport")
	(transport as FakeTransport).get_queue = [
		_catalog_success([
			_backend_offer("starter_bundle", "starter", "sorting_puzzle.local.starter_bundle", true),
			_backend_offer("coin_pack_small", "coin_pack", "sorting_puzzle.local.coin_pack_small", false),
		]),
	]
	var result: Dictionary = await source.get("source").load_catalog(_price_provider())
	_check(bool(result.get("ok", false)), "ineligible-mixed catalog fetch succeeds")
	var offers := result.get("offers", []) as Array
	_check(offers.size() == 1, "only the eligible offer is returned")
	_check(_find_offer(offers, "coin_pack_small").is_empty(), "the ineligible offer never crosses the join")


func _check_unknown_offer_type_is_excluded() -> void:
	var source := _make_source(_next_cache_path())
	var transport = source.get("transport")
	(transport as FakeTransport).get_queue = [
		_catalog_success([
			_backend_offer("mystery_offer", "future_offer_type", "sorting_puzzle.local.starter_bundle", true),
		]),
	]
	var result: Dictionary = await source.get("source").load_catalog(_price_provider())
	_check(bool(result.get("ok", false)), "unknown-type catalog fetch still succeeds")
	_check((result.get("offers", []) as Array).is_empty(), "an offer with an unrecognized type is excluded, not rendered blindly")


func _check_offer_without_local_price_entry_is_excluded() -> void:
	var source := _make_source(_next_cache_path())
	var transport = source.get("transport")
	(transport as FakeTransport).get_queue = [
		_catalog_success([
			_backend_offer("unpriced_offer", "coin_pack", "sorting_puzzle.local.unpriced_product", true),
		]),
	]
	var result: Dictionary = await source.get("source").load_catalog(_price_provider())
	_check(bool(result.get("ok", false)), "unpriced-offer catalog fetch still succeeds")
	_check((result.get("offers", []) as Array).is_empty(), "an offer with no local price table entry is excluded")


func _check_empty_catalog_is_ok_with_no_offers() -> void:
	var source := _make_source(_next_cache_path())
	var transport = source.get("transport")
	(transport as FakeTransport).get_queue = [_catalog_success([])]
	var result: Dictionary = await source.get("source").load_catalog(_price_provider())
	_check(bool(result.get("ok", false)), "an empty catalog is not an error")
	_check((result.get("offers", []) as Array).is_empty(), "an empty catalog returns no offers")


func _check_unavailable_without_cache_is_an_error() -> void:
	var source := _make_source(_next_cache_path())
	var transport = source.get("transport")
	(transport as FakeTransport).get_queue = [
		_error_response(503, "dependency.catalog_unavailable", true),
		_error_response(503, "dependency.catalog_unavailable", true),
		_error_response(503, "dependency.catalog_unavailable", true),
		_error_response(503, "dependency.catalog_unavailable", true),
		_error_response(503, "dependency.catalog_unavailable", true),
	]
	var result: Dictionary = await source.get("source").load_catalog(_price_provider())
	_check(not bool(result.get("ok", true)), "an unavailable catalog with no cache is a terminal error")
	_check(not str(result.get("error", "")).is_empty(), "the unavailable error carries a message")
	_check(str(result.get("source", "")) == "unavailable", "the unavailable result reports an unavailable source")


func _check_unavailable_falls_back_to_cache() -> void:
	var cache_path := _next_cache_path()
	var live_source := _make_source(cache_path)
	(live_source.get("transport") as FakeTransport).get_queue = [
		_catalog_success([_backend_offer("starter_bundle", "starter", "sorting_puzzle.local.starter_bundle", true)]),
	]
	var live_result: Dictionary = await live_source.get("source").load_catalog(_price_provider())
	_check(bool(live_result.get("ok", false)), "priming fetch for the cache test succeeds")

	var offline_source := _make_source(cache_path)
	(offline_source.get("transport") as FakeTransport).get_queue = [
		_error_response(503, "dependency.catalog_unavailable", true),
		_error_response(503, "dependency.catalog_unavailable", true),
		_error_response(503, "dependency.catalog_unavailable", true),
		_error_response(503, "dependency.catalog_unavailable", true),
		_error_response(503, "dependency.catalog_unavailable", true),
	]
	var offline_result: Dictionary = await offline_source.get("source").load_catalog(_price_provider())
	_check(bool(offline_result.get("ok", false)), "a later unavailable fetch serves the cached catalog")
	_check(str(offline_result.get("source", "")) == "cached", "the fallback result reports a cached source")
	_check(
		not (offline_result.get("offers", []) as Array).is_empty(),
		"the cached fallback still has the previously joined/priced offers"
	)


func _check_unauthorized_without_cache_is_an_error() -> void:
	# A 401 makes BackendTransport attempt exactly one refresh-and-replay (proven by
	# tests/backend/test_game_007.gd). No refresh response is queued here, so the refresh's own
	# transport call fails and the read is terminal without ever consuming a second GET -- this
	# check only needs to confirm that outcome surfaces as a catalog error with no cache to fall
	# back on.
	var source := _make_source(_next_cache_path())
	var transport = source.get("transport")
	(transport as FakeTransport).get_queue = [_error_response(401, "auth.token_expired", false)]
	var result: Dictionary = await source.get("source").load_catalog(_price_provider())
	_check(not bool(result.get("ok", true)), "an unauthorized read with no cache is a terminal error")
	_check((transport as FakeTransport).get_calls.size() == 1, "the failed refresh never replays the read")


func _check_malformed_response_falls_back_to_cache() -> void:
	var cache_path := _next_cache_path()
	var live_source := _make_source(cache_path)
	(live_source.get("transport") as FakeTransport).get_queue = [
		_catalog_success([_backend_offer("starter_bundle", "starter", "sorting_puzzle.local.starter_bundle", true)]),
	]
	await live_source.get("source").load_catalog(_price_provider())

	var malformed_source := _make_source(cache_path)
	var malformed_offer := _backend_offer("starter_bundle", "starter", "sorting_puzzle.local.starter_bundle", true)
	malformed_offer.erase("rewards")
	(malformed_source.get("transport") as FakeTransport).get_queue = [_catalog_success([malformed_offer])]
	var result: Dictionary = await malformed_source.get("source").load_catalog(_price_provider())
	_check(bool(result.get("ok", false)), "a malformed response falls back to the cached catalog")
	_check(str(result.get("source", "")) == "cached", "the malformed-response fallback reports a cached source")


func _check_backend_disabled_short_circuits() -> void:
	var original_url: String = ProjectSettings.get_setting("application/config/backend_base_url", "")
	ProjectSettings.set_setting("application/config/backend_base_url", "")
	var transport := FakeTransport.new()
	_created_transports.append(transport)
	transport.configure(FakeSessionStore.new(), func(): return TEST_PLAYER_ID)
	var cache_path := _next_cache_path()
	var source := BackendCatalogSourceScript.new(transport, cache_path)
	var result: Dictionary = await source.load_catalog(_price_provider())
	ProjectSettings.set_setting("application/config/backend_base_url", original_url)
	_check(not bool(result.get("ok", true)), "a disabled backend with no cache is an error")
	_check((transport as FakeTransport).get_calls.is_empty(), "a disabled backend never issues a GET")


# ---------------------------------------------------------------------------
# StoreService selection checks
# ---------------------------------------------------------------------------

func _run_store_service_selection_tests() -> void:
	var original_source: String = ProjectSettings.get_setting("application/config/shop_catalog_source", "local")
	ProjectSettings.set_setting("application/config/shop_catalog_source", "local")
	var local_service := StoreServiceScript.new()
	_check(local_service.call("_create_catalog_source") == null, "the default local source leaves _catalog_source null")

	ProjectSettings.set_setting("application/config/shop_catalog_source", "backend")
	var backend_service := StoreServiceScript.new()
	var backend_catalog_source = backend_service.call("_create_catalog_source")
	_check(backend_catalog_source != null, "selecting 'backend' constructs a non-null catalog source")
	_check(
		backend_catalog_source != null and backend_catalog_source.has_method("load_catalog"),
		"selecting 'backend' constructs an object that implements load_catalog()"
	)

	ProjectSettings.set_setting("application/config/shop_catalog_source", "nonsense")
	var fallback_service := StoreServiceScript.new()
	_check(
		fallback_service.call("_create_catalog_source") == null,
		"an unknown shop_catalog_source value falls back to the local catalog"
	)

	ProjectSettings.set_setting("application/config/shop_catalog_source", original_source)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_source(cache_path: String) -> Dictionary:
	var original_url: String = ProjectSettings.get_setting("application/config/backend_base_url", "")
	if original_url.strip_edges().is_empty():
		ProjectSettings.set_setting("application/config/backend_base_url", "http://127.0.0.1:8080")
	var transport := FakeTransport.new()
	transport.configure(FakeSessionStore.new(), func(): return TEST_PLAYER_ID)
	_created_transports.append(transport)
	return {
		"transport": transport,
		"source": BackendCatalogSourceScript.new(transport, cache_path),
	}


func _price_provider() -> RefCounted:
	return MockStoreProviderScript.new("US")


func _next_cache_path() -> String:
	var path := "user://test_game_008_cache_%d_%d.json" % [Time.get_ticks_usec(), _cache_paths.size()]
	_cache_paths.append(path)
	return path


func _backend_offer(offer_id: String, offer_type: String, platform_product_id: String, eligible: bool) -> Dictionary:
	return {
		"offer_id": offer_id,
		"type": offer_type,
		"title_key": "shop.offer.%s.title" % offer_id,
		"rewards": {
			"coins": 1000,
			"abilities": {"hammer": 3, "shuffle": 3, "highlight": 3, "freezer": 3},
		},
		"platform_product_id": platform_product_id,
		"limit_period": "lifetime",
		"display_priority": 100,
		"eligible": eligible,
	}


func _catalog_success(offers: Array) -> Array:
	var envelope := {
		"meta": {
			"protocol_version": "1.0",
			"request_id": "00000000-0000-4000-8000-0000000000c1",
			"correlation_id": "00000000-0000-4000-8000-0000000000c1",
			"server_time": "2026-07-14T09:00:00.000Z",
		},
		"data": {
			"catalog_version": "catalog-2026-07-14",
			"offers": offers,
		},
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
			"category": "rate_limit" if code == 429 else ("authentication" if code == 401 else "dependency"),
			"message": "synthetic test error",
			"retryable": retryable,
		},
	}
	return [HTTPRequest.RESULT_SUCCESS, code, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer()]


func _find_offer(offers: Array, offer_id: String) -> Dictionary:
	for raw_offer in offers:
		if raw_offer is Dictionary and str((raw_offer as Dictionary).get("id", "")) == offer_id:
			return raw_offer as Dictionary
	return {}


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
