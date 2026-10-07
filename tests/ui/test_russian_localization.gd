extends SceneTree

const EXPECTED_STRINGS := "res://tests/localization/russian_inventory.json"
const COIN_TEXTURE := preload("res://assets/ui/clover_coin_transparent_96x96.png")
var _failures: Array[String] = []
var _locale_manager: Node


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with("SortingPuzzleTest_"):
		push_error("Russian localization tests require the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_locale_manager = root.get_node("LocaleManager")
	for script_path in [
		"res://scripts/reward_reveal_row.gd",
		"res://scripts/purchase_reward_sequence.gd",
		"res://scripts/reward_chest_open_ceremony.gd",
	]:
		var owner_script := load(script_path) as Script
		_check(owner_script != null and owner_script.can_instantiate(),
			"Reward owners compile before scene checks: %s" % script_path)
	var expected := JSON.parse_string(FileAccess.get_file_as_string(EXPECTED_STRINGS)) as Array
	_check(expected.size() == 251, "The fixture contains all reviewed strings.")
	for locale in ["ru", "en", "hi"]:
		if locale == "hi":
			TranslationServer.set_locale(locale) # Test-only catalog-free fallback.
		else:
			_locale_manager.call("set_locale", locale)
		for raw_entry in expected:
			var entry := raw_entry as Dictionary
			var value := str(entry["ru" if locale == "ru" else "en"])
			_check(TranslationServer.translate(str(entry["key"])) == value,
				"%s resolves %s, including English fallback." % [locale, entry["key"]])

	_locale_manager.call("set_locale", "ru")
	_check(GameText.format_number(1234567) == "1 234 567", "Russian counts use spaces.")
	_check(GameText.format_date({"day": 2, "month": 11, "year": 2026}) == "2 ноября 2026 г.",
		"Russian deadlines use the genitive month.")
	_check(GameText.purchase_error("Catalog response has a malformed offer entry.") ==
		"The purchase could not be completed.", "Technical purchase errors use reviewed UI copy.")
	var theme := load("res://assets/themes/game_typography.tres") as Theme
	var font := theme.get_font("font", "GameTitleLabel")
	for letter in "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя":
		_check(font.has_char(letter.unicode_at(0)), "The display font covers %s." % letter)

	var shelf := _scene("res://scenes/ui/shelf_unlock_menu.tscn")
	var starter := _scene("res://scenes/ui/starter_bundle_offer_modal.tscn")
	var row := _scene("res://scenes/ui/leaderboard_row.tscn")
	var weekly := _scene("res://scenes/ui/leaderboard_reward_dialog.tscn")
	var chip := _scene("res://scenes/ui/offer_booster_chip.tscn")
	var chapter := _scene("res://scenes/ui/chapter_cover_card.tscn")
	chip.set("title", "Hammer")
	chip.call("set_claimed", true)
	var shop_price := "€4,99"
	for count in [0, 1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 101, 111, 112, 114]:
		var form := 0 if count % 10 == 1 and count % 100 != 11 else (
			1 if count % 10 in [2, 3, 4] and count % 100 not in [12, 13, 14] else 2)
		var coin_endings := ["МОНЕТА", "МОНЕТЫ", "МОНЕТ"]
		var star_endings := ["звезда", "звезды", "звёзд"]
		var triple_endings := ["тройку.", "тройки.", "троек."]
		var hammer_endings := ["молоток", "молотка", "молотков"]
		shelf.call("set_offer", count)
		if count > 0:
			_check(str(shelf.get_node("%OfferLabel").get("text")).ends_with(triple_endings[form]),
				"Shelf copy agrees with %d remaining triples." % count)
		starter.call("set_offer", {"rewards": {"coins": count}, "store": {"formatted_price": shop_price}})
		_check(str(starter.get_node("%CoinRibbon").call("get_text")).ends_with(coin_endings[form]),
			"Starter coins use the correct form for %d." % count)
		row.call("set_entry", {"rank": 1, "score": count, "display_name": "Play"})
		_check(str(row.get("tooltip_text")).ends_with(star_endings[form]),
			"Row plurals use stars rather than the rank for %d." % count)
		weekly.call("show_reward", 1, count)
		_check(str(weekly.get_node("%MessageLabel").get("text")).ends_with(
			["монету!", "монеты!", "монет!"][form]), "Weekly payout agrees with %d coins." % count)
		chip.call("set_count", count)
		_check(chip.get_node("%NameLabel").get("text") == "+%d %s" % [count, hammer_endings[form]],
			"Claimed booster names agree with %d." % count)
		chapter.call("configure", root.get_node("ChapterCatalog").call("get_chapter", "chapter_02"),
			{"unlocked": false, "previous_completed_levels": 0, "required_completed_levels": count}, false)
		_check(str(chapter.get_node("%StatusLabel").get("text")).ends_with("чтобы открыть эту главу"),
			"The corrected chapter wording is retained.")

	_check(starter.get_node("%BuyPriceLabel").get("text") == "Купить за %s" % shop_price,
		"The platform price is passed through unchanged.")
	var name_label := row.get_node("%NameLabel") as Label
	_check(name_label.atr(name_label.text) == "Play", "An actual player name matching a key is unchanged.")
	row.call("set_rank_reward", COIN_TEXTURE, 1000)
	shelf.call("set_rewarded_action_state", &"pending", false)
	var main_menu := _scene("res://scenes/main_menu.tscn")
	await process_frame
	_locale_manager.call("set_locale", "en")
	await process_frame
	_check(starter.get_node("%BuyPriceLabel").get("text") == "Buy for %s" % shop_price,
		"An existing offer refreshes its formatted price label in English.")
	_check(str(row.get("tooltip_text")).ends_with("stars"), "An existing row refreshes to English.")
	_check(bool(shelf.get_node("%RewardedAdButton").get("disabled")),
		"Changing language preserves disabled reward actions.")
	_check(bool(row.get_node("%RankReward").get("visible")), "Changing language preserves rank prizes.")
	_check(main_menu.get_node("%LevelButton").get("text") == "LEVEL 1",
		"The existing Main Menu formats English level text.")
	_locale_manager.call("set_locale", "ru")
	await process_frame
	_check(main_menu.get_node("%LevelButton").get("text") == "УРОВЕНЬ 1",
		"The existing Main Menu refreshes immediately in Russian.")
	_check(root.get_node("PlayerProgress").call("_preferences_for_storage").get("locale") == "ru",
		"Russian is persisted in local preferences.")
	_check(not root.get_node("PlayerProgress").call("_snapshot_for_storage").has("locale"),
		"Localization does not alter synchronized gameplay state.")
	_locale_manager.call("set_locale", "en")
	for scene in [shelf, starter, row, weekly, chip, chapter, main_menu]:
		scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Russian localization tests passed (251 strings, plurals, live switches, names and prices).")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _scene(scene_path: String) -> Node:
	var instance := (load(scene_path) as PackedScene).instantiate()
	root.add_child(instance)
	return instance


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
