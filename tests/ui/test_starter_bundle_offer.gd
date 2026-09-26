extends SceneTree

const MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const STORE_SERVICE_SCRIPT := preload("res://scripts/store/store_service.gd")
const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

var _failures: Array[String] = []


class FakeCatalogService extends RefCounted:
	var response := {}

	func load_catalog() -> Dictionary:
		await Engine.get_main_loop().process_frame
		return response.duplicate(true)


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Starter Bundle test must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var progress := root.get_node_or_null("PlayerProgress")
	_check(progress != null, "PlayerProgress is available.")
	if progress == null:
		quit(1)
		return
	progress.reset_progress()
	await _test_availability_states()
	progress.reset_progress()
	await _test_one_time_purchase(progress)

	if _failures.is_empty():
		print("Starter Bundle offer verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_availability_states() -> void:
	var menu := (load(MENU_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for _frame in range(4):
		await process_frame
	if not _check_menu_loaded(menu):
		current_scene = null
		menu.queue_free()
		return
	var fake := FakeCatalogService.new()
	menu.set("_starter_store_service", fake)
	var badge := menu.get_node("%StarterBundleBadge") as Control
	var priced_offer := _example_offer()

	fake.response = {"ok": true, "source": "live", "offers": [priced_offer]}
	await menu.call("_refresh_starter_bundle_offer")
	_check(badge.visible, "Live eligible priced starter appears.")

	fake.response = {"ok": true, "source": "cached", "offers": [priced_offer]}
	await menu.call("_refresh_starter_bundle_offer")
	_check(not badge.visible, "Cached backend eligibility does not advertise a purchase.")

	fake.response = {"ok": true, "source": "live", "offers": []}
	await menu.call("_refresh_starter_bundle_offer")
	_check(not badge.visible, "Missing or ineligible starter is hidden.")

	var unpriced_offer := priced_offer.duplicate(true)
	unpriced_offer["store"] = {}
	fake.response = {"ok": true, "source": "live", "offers": [unpriced_offer]}
	await menu.call("_refresh_starter_bundle_offer")
	_check(not badge.visible, "Unpriced starter is hidden.")

	var wrong_type := priced_offer.duplicate(true)
	wrong_type["type"] = "coins"
	fake.response = {"ok": true, "source": "live", "offers": [wrong_type]}
	await menu.call("_refresh_starter_bundle_offer")
	_check(not badge.visible, "An offer with the starter id but wrong type is hidden.")

	fake.response = {"ok": false, "source": "unavailable", "offers": []}
	await menu.call("_refresh_starter_bundle_offer")
	_check(not badge.visible, "Failed catalog load is hidden.")

	var modal := menu.get_node("%StarterBundleOfferModal") as Control
	modal.call("set_offer", priced_offer)
	_check(not (modal.get_node("%FreezerReward") as Control).visible, "Zero-count ability is omitted.")
	_check(not (modal.get_node("%DiscountLabel") as Control).visible, "Absent discount is omitted.")
	_check(
		(modal.get_node("%BuyButton") as Button).text == "Buy for $4.99",
		"Modal binds the formatted catalog price."
	)
	current_scene = null
	menu.queue_free()
	await process_frame


func _test_one_time_purchase(progress: Node) -> void:
	var menu := (load(MENU_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for _frame in range(4):
		await process_frame
	if not _check_menu_loaded(menu):
		current_scene = null
		menu.queue_free()
		return
	var local_catalog: Dictionary = await menu.call("_refresh_starter_bundle_offer")
	_check(not local_catalog.is_empty(), "Local Starter Bundle loads before purchase.")
	var badge := menu.get_node("%StarterBundleBadge") as Control
	_check(badge.visible, "Local Starter Bundle badge is visible before purchase.")
	for resolution in [Vector2i(540, 960), Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(1200, 1600)]:
		root.size = resolution
		for _frame in range(4):
			await process_frame
		var logical_size := menu.get_viewport_rect().size
		var badge_rect := badge.get_global_rect()
		_check(
			badge_rect.position.x >= 0.0 and badge_rect.end.x <= logical_size.x + 1.0,
			"Badge stays horizontally inside %s." % resolution
		)
	root.size = Vector2i(720, 1280)
	await process_frame
	var starting_coins: int = progress.get_coins()
	(badge.get_node("BadgeButton") as Button).pressed.emit()
	await create_timer(0.45).timeout
	var modal := menu.get_node("%StarterBundleOfferModal") as Control
	_check(modal.visible, "Badge action opens the dedicated offer modal.")
	_check((modal.get_node("%FreezerReward") as Control).visible, "Local freezer reward is shown.")
	await create_timer(0.4).timeout
	var outer := modal.get_node("%Shell").get_node("%OuterPanel") as Control
	for resolution in [Vector2i(540, 960), Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(1200, 1600)]:
		root.size = resolution
		for _frame in range(4):
			await process_frame
		var logical_size := modal.get_viewport_rect().size
		var panel_center := outer.get_global_rect().get_center()
		_check(
			absf(panel_center.y - logical_size.y * 0.5) < 4.0,
			"Offer modal is vertically centered at %s." % resolution
		)
		var panel_rect := outer.get_global_rect()
		_check(
			panel_rect.position.x >= 0.0 and panel_rect.end.x <= logical_size.x + 1.0,
			"Offer modal stays horizontally inside %s." % resolution
		)
	root.size = Vector2i(720, 1280)
	await process_frame
	var buy_button := modal.get_node("%BuyButton") as Button
	buy_button.pressed.emit()
	buy_button.pressed.emit()
	await create_timer(0.5).timeout
	_check(progress.has_purchased_shop_offer(&"starter_bundle"), "Purchase records the lifetime claim.")
	_check(progress.get_coins() == starting_coins + 1000, "Duplicate Buy taps grant shown coins once.")
	_check(not badge.visible, "Badge disappears immediately after purchase.")
	_check((modal.get_node("%ContinueButton") as Button).visible, "Modal shows purchase success.")

	var store := STORE_SERVICE_SCRIPT.new()
	_check(
		not bool(store.call("_is_offer_available", _example_offer())),
		"Saved mock claim narrows a backend-sourced starter without local limit fields."
	)
	var catalog_result: Dictionary = await store.load_catalog()
	var starter_still_available := false
	for raw_offer in catalog_result.get("offers", []) as Array:
		if raw_offer is Dictionary and str((raw_offer as Dictionary).get("id", "")) == "starter_bundle":
			starter_still_available = true
	_check(not starter_still_available, "Catalog omits claimed Starter Bundle on later loads.")
	var second_result: Dictionary = await store.purchase_offer(&"starter_bundle")
	_check(not bool(second_result.get("ok", false)), "A second purchase is refused.")
	_check(progress.get_coins() == starting_coins + 1000, "Refused repeat adds no coins.")
	current_scene = null
	menu.queue_free()
	await process_frame


func _example_offer() -> Dictionary:
	return {
		"id": "starter_bundle",
		"type": "bundle",
		"title": "Starter Bundle",
		"rewards": {"coins": 1000, "abilities": {"hammer": 3, "shuffle": 3, "highlight": 3}},
		"store": {"formatted_price": "$4.99"},
	}


func _check_menu_loaded(menu: Control) -> bool:
	var loaded := menu.has_method("_refresh_starter_bundle_offer")
	_check(loaded, "Production Main Menu script loaded.")
	return loaded


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
