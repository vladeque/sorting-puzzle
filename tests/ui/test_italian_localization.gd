extends SceneTree

const FIXTURE := "res://tests/localization/italian_inventory.json"
const COUNTS := [0, 1, 2, 3, 10, 11, 21, 101, 1000, 1000000]
var _failures: Array[String] = []
var _reviewed: Dictionary
var _locale_manager: Node


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with("SortingPuzzleTest_"):
		push_error("Italian localization tests require the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_locale_manager = root.get_node("LocaleManager")
	_reviewed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) as Dictionary
	var entries: Array = _reviewed["entries"]
	_check(entries.size() == 251, "The fixture includes every reviewed Italian entry.")
	for locale in ["it", "en", "id"]:
		_check(bool(_locale_manager.call("set_locale", locale)), "%s can be selected." % locale)
		for entry: Dictionary in entries:
			var key := str(entry["key"])
			var expected := str(entry["it" if locale == "it" else "en"])
			if locale == "it" and _reviewed["plurals"].has(key):
				expected = _form(key, 1)
			_check(TranslationServer.translate(key) == expected,
				"%s resolves reviewed key %s." % [locale, key])
			if locale == "it" and key not in ["common.resume", "common.retry_load"]:
				_check(TranslationServer.translate(str(entry["en"])) == str(entry["it"]),
					"English scene alias resolves reviewed key %s." % key)

	_locale_manager.call("set_locale", "it")
	for entry: Dictionary in _reviewed["additional"]:
		_check(TranslationServer.translate(str(entry["key"])) == str(entry["it"]),
			"Supplementary copy resolves %s." % entry["key"])
	_check(GameText.format_number(1234567) == "1.234.567", "Italian counts use period grouping.")
	_check(GameText.format_number(1) == "1", "Single-digit amounts have no separator.")
	for month in range(1, 13):
		_check(GameText.format_date({"day": 2, "month": month, "year": 2026}) ==
			"2 %s 2026" % _reviewed["months"][month - 1], "Month %d uses the Italian date form." % month)
	var theme := load("res://assets/themes/game_typography.tres") as Theme
	var title_font := theme.get_font("font", "GameTitleLabel")
	for letter in "àèéìòùÀÈÉÌÒÙ«»°×":
		_check(title_font.has_char(letter.unicode_at(0)), "The bundled title font covers %s." % letter)

	var shelf := _scene("res://scenes/ui/shelf_unlock_menu.tscn")
	var starter := _scene("res://scenes/ui/starter_bundle_offer_modal.tscn")
	var row := _scene("res://scenes/ui/leaderboard_row.tscn")
	var weekly := _scene("res://scenes/ui/leaderboard_reward_dialog.tscn")
	var rank_reward := _scene("res://scenes/ui/leaderboard_rank_reward.tscn")
	var chip := _scene("res://scenes/ui/offer_booster_chip.tscn")
	var chapter := _scene("res://scenes/ui/chapter_cover_card.tscn")
	chip.call("set_claimed", true)
	var shop_price := "€4,99"
	var reward_texture := GradientTexture2D.new()
	for count: int in COUNTS:
		for key: String in _reviewed["plurals"]:
			_check(TranslationServer.translate_plural(key, key + ".plural", count) == _form(key, count),
				"%s selects the reviewed form for %d." % [key, count])
		for booster: String in _reviewed["counted_boosters"]:
			var names: Array = _reviewed["counted_boosters"][booster]
			var name := str(names[0 if count == 1 else 1])
			_check(GameText.counted_booster(booster, count) == name,
				"%s inflects correctly for %d." % [booster, count])
			chip.set("title", booster)
			chip.call("set_count", count)
			_check(chip.get_node("%NameLabel").get("text") == "+%d %s" % [count, name],
				"The claimed chip displays %d %s." % [count, booster])
		shelf.call("set_offer", count)
		if count > 0:
			_check(shelf.get_node("%OfferLabel").get("text") ==
				_form("shelf_unlock.offer_or_clear", count) % str(count), "Shelf text agrees with %d triples." % count)
		starter.call("set_offer", {"rewards": {"coins": count}, "store": {"formatted_price": shop_price}})
		_check(starter.get_node("%CoinRibbon").call("get_text") ==
			_form("starter.coins", count) % GameText.format_number(count), "The coin ribbon agrees with %d coins." % count)
		row.call("set_entry", {"rank": 2, "score": count, "display_name": "Play"})
		_check(row.get("tooltip_text") == _form("leaderboard.row_tooltip", count) % [2, "Play", count],
			"Row text chooses the star count rather than rank for %d." % count)
		weekly.call("show_reward", 3, count)
		_check(weekly.get_node("%MessageLabel").get("text") ==
			_form("leaderboard.reward.body", count) % [3, count], "Weekly copy chooses coins rather than rank for %d." % count)
		rank_reward.call("set_reward", reward_texture, count)
		if count > 0:
			_check(rank_reward.get("tooltip_text") ==
				_form("leaderboard.reward_tooltip", count) % GameText.format_number(count),
				"The weekly coin tooltip agrees with %d coins." % count)
		chapter.call("configure", root.get_node("ChapterCatalog").call("get_chapter", "chapter_02"),
			{"unlocked": false, "previous_completed_levels": 0, "required_completed_levels": count}, false)
		if count > 0:
			_check(chapter.get_node("%StatusLabel").get("text") ==
				_form("chapter.locked_status", count) % [count, tr("chapter.title.chapter_01")],
				"Chapter copy agrees with %d remaining levels." % count)

	_check(starter.get_node("%BuyPriceLabel").get("text") == "Acquista per %s" % shop_price,
		"The reviewed price caption keeps the store-formatted price unchanged.")
	var name_label := row.get_node("%NameLabel") as Label
	_check(name_label.atr(name_label.text) == "Play", "A player name matching an English key stays unchanged.")
	var badge := _scene("res://scenes/ui/main_menu_starter_bundle_badge.tscn")
	var badge_label := badge.find_child("BadgeLabel", true, false) as Label
	_check(badge_label.atr(badge_label.text) == "PACCHETTO", "The BUNDLE scene alias uses the reviewed badge.")
	_check(tr("AD") == "AD" and tr("OFF") == "OFF", "Compact English markers stay unchanged.")
	var pause := _scene("res://scenes/pause_menu.tscn")
	var leave := _scene("res://scenes/leave_confirmation_menu.tscn")
	for overlay in [pause, leave]:
		_check(overlay.find_child("ContinueButton", true, false).get("text") == "Riprendi",
			"Resume gameplay uses Riprendi rather than the move-on action Continua.")
	shelf.call("set_rewarded_action_state", &"pending", false)
	var main_menu := _scene("res://scenes/main_menu.tscn")
	await process_frame
	_locale_manager.call("set_locale", "en")
	await process_frame
	_check(main_menu.get_node("%LevelButton").get("text") == "LEVEL 1", "An existing Main Menu switches to English.")
	_check(starter.get_node("%BuyPriceLabel").get("text") == "Buy for %s" % shop_price, "Existing offer text refreshes.")
	_check(bool(shelf.get_node("%RewardedAdButton").get("disabled")), "Language switching preserves pending ad state.")
	for overlay in [pause, leave]:
		_check(overlay.find_child("ContinueButton", true, false).get("text") == "Continue",
			"An existing resume action switches to English.")
	_locale_manager.call("set_locale", "it")
	await process_frame
	_check(main_menu.get_node("%LevelButton").get("text") == "LIVELLO 1", "The Main Menu refreshes to Italian.")
	_check(starter.get_node("%BuyPriceLabel").get("text") == "Acquista per %s" % shop_price,
		"The corrected Italian purchase caption returns on a live switch.")
	for overlay in [pause, leave]:
		_check(overlay.find_child("ContinueButton", true, false).get("text") == "Riprendi",
			"An existing resume action switches back to Italian.")
	_check(root.get_node("PlayerProgress").call("_preferences_for_storage").get("locale") == "it",
		"Italian persists in local preferences.")
	_check(not root.get_node("PlayerProgress").call("_snapshot_for_storage").has("locale"),
		"Selecting Italian does not alter synchronized gameplay state.")
	_locale_manager.call("set_locale", "en")
	for scene in [shelf, starter, row, weekly, rank_reward, chip, chapter, badge, pause, leave, main_menu]:
		scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Italian localization tests passed (251 reviewed strings, aliases, plurals, fonts, dates, live switches and unchanged data).")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _form(key: String, count: int) -> String:
	return str(_reviewed["plurals"][key]["one" if count == 1 else "other"])


func _scene(scene_path: String) -> Node:
	var instance := (load(scene_path) as PackedScene).instantiate()
	root.add_child(instance)
	return instance


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
