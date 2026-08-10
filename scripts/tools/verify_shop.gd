extends Node

const StoreServiceScript := preload("res://scripts/store/store_service.gd")
const SHOP_SCENE := preload("res://scenes/ui/shop_screen.tscn")
const IN_LEVEL_SHOP_SCENE := preload("res://scenes/ui/in_level_shop_screen.tscn")
const COIN_OFFER_ROW_SCENE := preload("res://scenes/ui/shop_coin_offer_row.tscn")
const GREEN_PRIMARY_STYLE := preload("res://assets/themes/style_box_green_primary_button.tres")
const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const TEST_REGIONS := {
	"US": "$0.99",
	"UA": "₴39.99",
	"DE": "0,99 €",
	"JP": "¥160",
}
const TEST_RESOLUTIONS := [
	Vector2i(540, 960),
	Vector2i(720, 1280),
	Vector2i(1080, 1920),
	Vector2i(1080, 2400),
	Vector2i(1200, 1600),
]
const EXPECTED_COIN_OFFER_ICONS := {
	&"coins_100": "res://assets/ui/shop_coin_offers/shop_coin_offer_tier_01.png",
	&"coins_300": "res://assets/ui/shop_coin_offers/shop_coin_offer_tier_02.png",
	&"coins_750": "res://assets/ui/shop_coin_offers/shop_coin_offer_tier_03.png",
	&"coins_1600": "res://assets/ui/shop_coin_offers/shop_coin_offer_tier_04.png",
	&"coins_3500": "res://assets/ui/shop_coin_offers/shop_coin_offer_tier_05.png",
}
const HIGH_TIER_COIN_OFFER_ICONS := [
	{
		"amount": 13000,
		"path": "res://assets/ui/shop_coin_offers/shop_coin_offer_tier_06.png",
	},
	{
		"amount": 13001,
		"path": "res://assets/ui/shop_coin_offers/shop_coin_offer_tier_07.png",
	},
]

var _failures := []


func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error(
			"Shop verification must run through scripts/tools/run_isolated_godot_test.ps1."
		)
		get_tree().quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await _verify_regional_prices()
	ProjectSettings.set_setting("application/config/mock_store_country", "US")
	PlayerProgress.reset_progress()

	var shop := SHOP_SCENE.instantiate() as Control
	get_tree().root.add_child(shop)
	get_tree().current_scene = shop
	for _frame in range(5):
		await get_tree().process_frame

	var destination_shell := shop.get_node("%DestinationShell") as Control
	_check(
		_get_shell_background_path(destination_shell) == "res://assets/backgrounds/main_menu.jpeg",
		"Shop should start on the selected Chapter 1 background."
	)
	destination_shell.call("set_background_for_chapter", "chapter_02")
	_check(
		_get_shell_background_path(destination_shell)
			== ChapterCatalog.get_selection_preview_path("chapter_02"),
		"Shop's shared background shell did not follow the selected chapter."
	)
	destination_shell.call("set_background_for_chapter", "chapter_01")

	var status_panel := shop.get_node("%StatusPanel") as Control
	var status_retry_button := status_panel.get_node(
		"StatusPanelBackground/StatusStack/StatusRetryButton"
	) as Button
	_check(
		status_retry_button.get_theme_stylebox("normal")
			== load("res://assets/themes/style_box_orange_utility_normal.tres"),
		"Shop's status Retry button is not using the shared orange utility style resource."
	)

	await _verify_in_level_shop_variant()

	var bundles := shop.get_node("%BundlesContainer") as VBoxContainer
	var coin_offers := shop.get_node("%CoinOffersContainer") as VBoxContainer
	_check(bundles.get_child_count() == 2, "Expected two configured bundle cards.")
	_check(coin_offers.get_child_count() == 5, "Expected five configured coin offers.")
	_check((shop.get_node("%TitleLabel") as Label).text == "SHOP", "Shop title is missing.")
	for offer_id in EXPECTED_COIN_OFFER_ICONS:
		var icon_row := _find_coin_offer_row(coin_offers, offer_id)
		_check(icon_row != null, "Could not find %s to verify its amount-based icon." % offer_id)
		if icon_row != null:
			var icon_texture := (icon_row.get_node("%CoinIcon") as TextureRect).texture
			_check(icon_texture != null, "%s has no coin-offer icon." % offer_id)
			if icon_texture != null:
				_check(
					icon_texture.resource_path == EXPECTED_COIN_OFFER_ICONS[offer_id],
					"%s selected the wrong amount-based coin-offer icon." % offer_id
				)
	_verify_high_tier_coin_offer_icons()
	var bundle_card := _find_bundle_card(bundles, &"starter_bundle")
	var new_player_bundle_card := _find_bundle_card(bundles, &"new_player_bundle")
	_check(bundle_card != null, "Could not find the starter bundle card.")
	_check(new_player_bundle_card != null, "Could not find the new-player bundle card.")
	if bundle_card != null:
		var bundle_purchase := bundle_card.get_node("%PurchaseButton") as Button
		_check(
			bundle_purchase.get_theme_stylebox("normal") == GREEN_PRIMARY_STYLE,
			"Bundle purchases should use the shared green primary-button resource."
		)
		var reward_cell := bundle_card.get_node(
			"CardBody/CardStack/Rewards/CoinReward"
		) as PanelContainer
		var reward_style := reward_cell.get_theme_stylebox("panel") as StyleBoxFlat
		_check(
			reward_style.corner_radius_top_left == 20
				and reward_style.corner_radius_top_right == 20
				and reward_style.corner_radius_bottom_right == 20
				and reward_style.corner_radius_bottom_left == 20,
			"Shop reward cells should use the shared 20 px cell-radius role."
		)
	if new_player_bundle_card != null:
		_check(
			(new_player_bundle_card.get_node("%CoinCount") as Label).text == "2,500",
			"New-player bundle card does not show 2,500 coins."
		)
		_check(
			(new_player_bundle_card.get_node("%PurchaseButton") as Button).text == "$7.99",
			"New-player bundle card does not show the requested US price."
		)
		for ability_count_name in ["HammerCount", "ShuffleCount", "LanternCount", "FreezerCount"]:
			_check(
				(new_player_bundle_card.get_node("%%%s" % ability_count_name) as Label).text.ends_with("3"),
				"New-player bundle card does not show three uses in %s." % ability_count_name
			)
	_check(
		(bundle_card.get_node("%FreezerCount") as Label).text == "×3",
		"Starter bundle card does not show three Freezers."
	)
	_check(
		(bundle_card.get_node("%DiscountBadge") as Control).visible,
		"Starter bundle discount badge did not show for a discounted offer."
	)
	_check(
		(bundle_card.get_node("CardBody/DiscountBadge/BadgeTexture") as TextureRect).texture != null,
		"Starter bundle discount badge texture did not load."
	)
	_check(
		(bundle_card.get_node("%PercentLabel") as Label).text == "67%",
		"Starter bundle discount badge percent text is wrong."
	)
	_check(
		(bundle_card.get_node("CardBody/CardStack/Rewards") as HBoxContainer).get_child(0).name == "CoinReward",
		"Coins should be the first reward shown in the bundle card."
	)
	_check(
		(bundle_card.get_node("%CompareAtPriceLabel") as Control).visible,
		"Starter bundle compare-at price did not show for a discounted offer."
	)

	var best_value_row := _find_coin_offer_row(coin_offers, &"coins_3500")
	_check(best_value_row != null, "Could not find the coins_3500 row to check its tag.")
	if best_value_row != null:
		_check(
			(best_value_row.get_node("%TagBanner") as Control).visible,
			"coins_3500 should show a BEST VALUE tag."
		)
		_check(
			(best_value_row.get_node("%TagLabel") as Label).text == "BEST VALUE",
			"coins_3500 tag text is wrong."
		)
	var other_row := _find_coin_offer_row(coin_offers, &"coins_100")
	_check(other_row != null, "Could not find the coins_100 row to check its tag.")
	if other_row != null:
		_check(
			(other_row.get_node("%PurchaseButton") as Button).get_theme_stylebox("normal")
				== GREEN_PRIMARY_STYLE,
			"Coin-offer purchases should use the shared green primary-button resource."
		)
		_check(
			not (other_row.get_node("%TagBanner") as Control).visible,
			"coins_100 should not show a value tag."
		)

	var dialog := shop.get_node("%PurchaseDialog") as Control
	(bundle_card.get_node("%HammerInfoButton") as Button).emit_signal("pressed")
	_check(dialog.visible, "Tapping the Hammer icon did not open the info dialog.")
	_check(
		(dialog.get_node("%TitleLabel") as Label).text == "HAMMER",
		"Hammer info dialog title is wrong."
	)
	dialog.hide()

	for resolution in TEST_RESOLUTIONS:
		get_tree().root.size = resolution
		for _frame in range(3):
			await get_tree().process_frame
		var logical_size := shop.get_viewport_rect().size
		var navigation := shop.get_node("%BottomNavigation") as Control
		var content := shop.get_node("%ContentMargin") as Control
		var reward_row := bundle_card.get_node("CardBody/CardStack/Rewards") as HBoxContainer
		_check(content.position.x >= 0.0, "Content escaped the left edge at %s." % resolution)
		_check(content.position.x + content.size.x <= logical_size.x + 1.0, "Content escaped the right edge at %s." % resolution)
		_check(navigation.position.y + navigation.size.y <= logical_size.y + 1.0, "Navigation escaped the bottom edge at %s." % resolution)
		_check(
			reward_row.size.x <= bundle_card.size.x + 1.0,
			"Five starter rewards overflowed the bundle card at %s." % resolution
		)
		print("Shop layout %s -> logical %s" % [resolution, logical_size])

	get_tree().root.size = Vector2i(720, 1280)
	for _frame in range(3):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		var screenshot_error := image.save_png("res://tmp/shop_720x1280.png")
		_check(screenshot_error == OK, "Could not save the shop verification screenshot.")

	var starting_coins := PlayerProgress.get_coins()
	shop.call("_purchase_offer", &"coins_100")
	await get_tree().create_timer(0.35).timeout
	_check(PlayerProgress.get_coins() == starting_coins + 100, "Mock coin purchase did not grant 100 coins.")
	_check((shop.get_node("%PurchaseDialog") as Control).visible, "Purchase result dialog did not open.")
	if DisplayServer.get_name() != "headless":
		var dialog_image := get_viewport().get_texture().get_image()
		var dialog_screenshot_error := dialog_image.save_png("res://tmp/shop_purchase_dialog_720x1280.png")
		_check(dialog_screenshot_error == OK, "Could not save the purchase dialog verification screenshot.")

	var bundle_starting_coins := PlayerProgress.get_coins()
	var bundle_starting_abilities := PlayerProgress.get_ability_uses()
	shop.call("_purchase_offer", &"starter_bundle")
	await get_tree().create_timer(0.35).timeout
	_check(PlayerProgress.get_coins() == bundle_starting_coins + 1000, "Mock bundle did not grant 1,000 coins.")
	var bundle_abilities := PlayerProgress.get_ability_uses()
	for ability_id in ["hammer", "shuffle", "highlight", "freezer"]:
		_check(
			int(bundle_abilities.get(ability_id, 0)) == int(bundle_starting_abilities.get(ability_id, 0)) + 3,
			"Mock bundle did not grant three %s uses." % ability_id
		)

	var new_player_starting_coins := PlayerProgress.get_coins()
	var new_player_starting_abilities := PlayerProgress.get_ability_uses()
	shop.call("_purchase_offer", &"new_player_bundle")
	await get_tree().create_timer(0.4).timeout
	_check(
		PlayerProgress.get_coins() == new_player_starting_coins + 2500,
		"Mock new-player bundle did not grant 2,500 coins."
	)
	var new_player_abilities := PlayerProgress.get_ability_uses()
	for ability_id in ["hammer", "shuffle", "highlight", "freezer"]:
		_check(
			int(new_player_abilities.get(ability_id, 0))
			== int(new_player_starting_abilities.get(ability_id, 0)) + 3,
			"Mock new-player bundle did not grant three %s uses." % ability_id
		)
	_check(
		_find_bundle_card(bundles, &"new_player_bundle") == null,
		"Purchased new-player bundle remained visible after its lifetime claim."
	)
	var repeat_purchase_coins := PlayerProgress.get_coins()
	shop.call("_purchase_offer", &"new_player_bundle")
	await get_tree().create_timer(0.05).timeout
	_check(
		PlayerProgress.get_coins() == repeat_purchase_coins,
		"Purchased new-player bundle granted rewards a second time."
	)
	PlayerProgress.load_progress()
	var reloaded_service = StoreServiceScript.new()
	var reloaded_catalog: Dictionary = await reloaded_service.load_catalog()
	_check(
		_find_offer(reloaded_catalog.get("offers", []) as Array, "new_player_bundle").is_empty(),
		"Purchased new-player bundle returned after progress reload."
	)

	var duplicate_start := PlayerProgress.get_coins()
	var first_grant := PlayerProgress.apply_shop_purchase("verify_duplicate_transaction", {"coins": 7})
	var duplicate_grant := PlayerProgress.apply_shop_purchase("verify_duplicate_transaction", {"coins": 7})
	_check(bool(first_grant.get("applied", false)), "First transaction grant was not applied.")
	_check(not bool(duplicate_grant.get("applied", true)), "Duplicate transaction was applied twice.")
	_check(PlayerProgress.get_coins() == duplicate_start + 7, "Duplicate transaction changed the balance twice.")

	if _failures.is_empty():
		print("SHOP VERIFICATION PASSED")
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)


func _verify_regional_prices() -> void:
	for country_code in TEST_REGIONS:
		ProjectSettings.set_setting("application/config/mock_store_country", country_code)
		var service = StoreServiceScript.new()
		var result: Dictionary = await service.load_catalog()
		_check(bool(result.get("ok", false)), "Catalog failed to load for %s." % country_code)
		var offers := result.get("offers", []) as Array
		var coin_offer := _find_offer(offers, "coins_100")
		var store := coin_offer.get("store", {}) as Dictionary
		_check(
			str(store.get("formatted_price", "")) == TEST_REGIONS[country_code],
			"Unexpected mock price for %s." % country_code
		)


func _verify_in_level_shop_variant() -> void:
	var overlay := IN_LEVEL_SHOP_SCENE.instantiate() as ShopScreen
	get_tree().root.add_child(overlay)
	await get_tree().process_frame
	var navigation := overlay.get_node("%BottomNavigation") as Control
	var close_button := overlay.get_node("%OverlayCloseButton") as Button
	_check(not navigation.visible, "In-level Shop should hide BottomNavigation.")
	_check(close_button.visible, "In-level Shop should show its X close button.")

	var close_requested := [false]
	overlay.close_requested.connect(func() -> void:
		close_requested[0] = true
		overlay.close()
	)
	overlay.open()
	await get_tree().create_timer(0.35).timeout
	_check(overlay.visible, "In-level Shop did not open.")
	_check(
		(overlay.get_node("%BundlesContainer") as VBoxContainer).get_child_count() == 2,
		"In-level Shop should reuse the destination Shop bundle catalog."
	)
	_check(
		(overlay.get_node("%CoinOffersContainer") as VBoxContainer).get_child_count() == 5,
		"In-level Shop should reuse the destination Shop coin catalog."
	)
	for resolution in TEST_RESOLUTIONS:
		get_tree().root.size = resolution
		for _frame in range(3):
			await get_tree().process_frame
		var logical_size := overlay.get_viewport_rect().size
		var content := overlay.get_node("%ContentMargin") as Control
		_check(content.position.x >= 0.0, "In-level Shop content escaped left at %s." % resolution)
		_check(
			content.position.x + content.size.x <= logical_size.x + 1.0,
			"In-level Shop content escaped right at %s." % resolution
		)
		_check(
			content.position.y + content.size.y <= logical_size.y + 1.0,
			"In-level Shop content escaped bottom at %s." % resolution
		)
	get_tree().root.size = Vector2i(720, 1280)
	await get_tree().process_frame

	close_button.pressed.emit()
	await get_tree().create_timer(0.35).timeout
	_check(bool(close_requested[0]), "In-level Shop X should request close.")
	_check(not overlay.visible, "In-level Shop X should close the overlay through its owner.")
	overlay.queue_free()
	await get_tree().process_frame


func _verify_high_tier_coin_offer_icons() -> void:
	var row := COIN_OFFER_ROW_SCENE.instantiate() as Control
	get_tree().root.add_child(row)
	for test_case in HIGH_TIER_COIN_OFFER_ICONS:
		var amount := int(test_case.get("amount", 0))
		row.call(
			"set_offer",
			{
				"id": "verify_coins_%d" % amount,
				"rewards": {"coins": amount},
				"store": {"formatted_price": "$0.00"},
			}
		)
		var icon_texture := (row.get_node("%CoinIcon") as TextureRect).texture
		_check(icon_texture != null, "%d-coin test offer has no icon." % amount)
		if icon_texture != null:
			_check(
				icon_texture.resource_path == str(test_case.get("path", "")),
				"%d-coin test offer selected the wrong high-tier icon." % amount
			)
	row.queue_free()


func _find_coin_offer_row(coin_offers: VBoxContainer, offer_id: StringName) -> Control:
	for child in coin_offers.get_children():
		if child is Control and (child as Control).call("get_offer_id") == offer_id:
			return child as Control
	return null


func _find_bundle_card(bundles: VBoxContainer, offer_id: StringName) -> Control:
	for child in bundles.get_children():
		if child is Control and (child as Control).call("get_offer_id") == offer_id:
			return child as Control
	return null


func _find_offer(offers: Array, offer_id: String) -> Dictionary:
	for raw_offer in offers:
		if raw_offer is Dictionary and str((raw_offer as Dictionary).get("id", "")) == offer_id:
			return raw_offer as Dictionary
	return {}


func _get_shell_background_path(shell: Control) -> String:
	var background := shell.get_node("Background") as TextureRect
	if background == null or background.texture == null:
		return ""
	return background.texture.resource_path


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
