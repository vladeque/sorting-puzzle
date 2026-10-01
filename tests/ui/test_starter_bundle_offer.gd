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
	_check(
		not (badge.get_node("%DiscountTag") as Control).visible,
		"The sign omits its discount tag when the offer has no discount."
	)

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
	_check((modal.get_node("%LanternReward") as Control).visible, "Positive-count ability is shown.")
	_check(not (modal.get_node("%DiscountBadge") as Control).visible, "Absent discount is omitted.")
	_check(
		not (modal.get_node("%CompareAtPriceLabel") as Control).visible,
		"Absent compare price is omitted from the Buy button."
	)
	_check(
		(modal.get_node("%BuyPriceLabel") as Label).text == "Buy for $4.99",
		"Modal binds the formatted catalog price."
	)
	_check(
		str(modal.get_node("%CoinRibbon").call("get_text")) == "1,000 COINS",
		"The hero ribbon carries the offer's coin amount."
	)
	_check((modal.get_node("%OneTimeBadge") as Control).visible, "The one-time offer badge is shown.")
	await _test_modal_states(modal, priced_offer)
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
	_check(
		(badge.get_node("%DiscountTag") as Control).visible
		and (badge.get_node("%DiscountLabel") as Label).text == "-67%",
		"The sign pins the local offer's discount tag."
	)
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
	for _frame in range(2):
		await process_frame
	var discount_badge := modal.get_node("%DiscountBadge") as Control
	_check(discount_badge.visible, "The local discounted offer pins its discount tag.")
	_check(
		discount_badge.get_global_rect().end.x <= outer.get_global_rect().end.x,
		"The discount tag stays inside the panel's right edge."
	)
	_check(
		(modal.get_node("%CompareAtPriceLabel") as Control).visible,
		"The local offer's compare price is shown on the Buy button."
	)
	var ability_row := modal.get_node("%AbilityRow") as Control
	_check(
		absf(ability_row.get_global_rect().get_center().x - outer.get_global_rect().get_center().x) < 2.0,
		"Booster chips are centered in the panel."
	)
	var buy_button := modal.get_node("%BuyButton") as Button
	var sequence := menu.get_node("%PurchaseRewardSequence") as Control
	var coin_widget := menu.get_node("%TopStatusBar").get_node(
		"MainMenuTopStatus/CoinsWidget"
	).get_node("%CoinBalanceWidget")
	var sequence_finished := [false]
	sequence.connect("finished", func() -> void: sequence_finished[0] = true)
	buy_button.pressed.emit()
	buy_button.pressed.emit()
	await process_frame
	var status_pill := modal.get_node("%StatusPill") as Control
	_check(status_pill.visible, "Purchasing shows the status pill.")
	_check(
		status_pill.get_global_rect().end.y <= buy_button.get_global_rect().position.y + 1.0,
		"The status pill sits above the Buy button."
	)
	var chip_row_bottom := (modal.get_node("%AbilityRow") as Control).get_global_rect().end.y
	_check(
		chip_row_bottom <= status_pill.get_global_rect().position.y + 1.0,
		"The status pill does not cover the booster names."
	)
	await create_timer(0.5).timeout
	_check(progress.has_purchased_shop_offer(&"starter_bundle"), "Purchase records the lifetime claim.")
	_check(progress.get_coins() == starting_coins + 1000, "Duplicate Buy taps grant shown coins once.")
	_check(not badge.visible, "Badge disappears immediately after purchase.")
	_check(not modal.visible, "The modal closes once the purchase completes.")
	_check(
		sequence.visible,
		"The purchase reward sequence confirms the purchase in place of a success screen."
	)
	_check(
		int(coin_widget.get("_amount")) == starting_coins,
		"The counter holds back the purchased coins until they fly in."
	)
	var deadline := Time.get_ticks_msec() + 8000
	while not sequence_finished[0] and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(sequence_finished[0], "The purchase reward sequence plays through.")
	_check(
		int(coin_widget.get("_amount")) == starting_coins + 1000,
		"The counter reaches the saved balance once every purchased coin lands."
	)

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


func _test_modal_states(modal: Control, offer: Dictionary) -> void:
	var buy_button := modal.get_node("%BuyButton") as Button
	var buy_label := modal.get_node("%BuyPriceLabel") as Label
	var compare_label := modal.get_node("%CompareAtPriceLabel") as Label
	var status_pill := modal.get_node("%StatusPill") as Control
	var status_label := modal.get_node("%StatusLabel") as Label
	var close_button := modal.get_node("%Shell").get_node("%CloseButton") as Button
	var ribbon := modal.get_node("%CoinRibbon")
	var hammer := modal.get_node("%HammerReward")
	var freezer := modal.get_node("%FreezerReward")

	var discounted := offer.duplicate(true)
	discounted["discount_percent"] = 67
	(discounted["store"] as Dictionary)["compare_at_formatted_price"] = "$14.99"
	modal.call("set_offer", discounted)
	_check((modal.get_node("%DiscountBadge") as Control).visible, "A loaded discount pins the tag.")
	_check((modal.get_node("%PercentLabel") as Label).text == "67%", "The tag shows the loaded percent.")
	_check(
		compare_label.visible and compare_label.text == "$14.99",
		"The Buy button shows the loaded compare price."
	)
	_check(not status_pill.visible, "A fresh offer shows no status.")

	modal.call("set_busy", "Purchasing…")
	_check(buy_button.disabled and buy_label.text == "Purchasing…", "Purchasing disables Buy.")
	_check(not compare_label.visible, "The compare price steps aside while purchasing.")
	_check(close_button.disabled, "Close is disabled while purchasing.")
	_check(status_pill.visible and status_label.text == "Purchasing…", "Purchasing shows its status.")

	modal.call("show_error", "The purchase could not be completed.", true)
	_check(not buy_button.disabled and buy_label.text == "Try Again", "A retryable failure offers retry.")
	_check(not close_button.disabled, "Close is available again after a failure.")
	_check(
		status_pill.visible and status_label.text == "The purchase could not be completed.",
		"The failure message is shown in the status pill."
	)

	modal.call("open")
	await process_frame
	var reward_rects: Dictionary = modal.call("get_reward_icon_global_rects")
	_check(
		reward_rects.has("coins") and reward_rects.has("hammer") and not reward_rects.has("freezer"),
		"The reward sequence lifts only the offer's shown rewards off the modal (got %s)."
			% [reward_rects.keys()]
	)
	_check(
		(reward_rects.get("hammer", Rect2()) as Rect2).get_center().distance_to(
			(hammer.call("get_icon_global_rect") as Rect2).get_center()
		) < 1.0,
		"A booster lifts off from its own chip icon."
	)
	_check(not freezer.visible, "Absent boosters stay hidden.")
	modal.call("set_busy", "Purchasing…")
	modal.call("close_after_purchase")
	_check(not bool(modal.call("is_busy")), "A completed purchase releases the busy lock.")
	_check(not close_button.disabled, "A completed purchase re-enables Close.")
	await create_timer(0.4).timeout
	_check(not modal.visible, "A completed purchase closes the modal.")

	modal.call("set_offer", offer)
	_check(str(ribbon.call("get_text")) == "1,000 COINS", "Reloading the offer restores the ribbon.")
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
