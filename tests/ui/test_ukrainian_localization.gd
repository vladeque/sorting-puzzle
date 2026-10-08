extends SceneTree

const FIXTURE := "res://tests/localization/ukrainian_inventory.json"
const COUNTS := [0, 1, 2, 3, 4, 5, 11, 12, 14, 21, 22, 25, 101, 111, 112, 114]
const WEIGHT_AXIS := 2003265652 # OpenType "wght".
var _failures: Array[String] = []
var _reviewed: Dictionary
var _locale_manager: Node


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with("SortingPuzzleTest_"):
		push_error("Ukrainian localization tests require the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_locale_manager = root.get_node("LocaleManager")
	_reviewed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) as Dictionary
	var entries: Array = _reviewed["entries"]
	_check(entries.size() == 251, "The fixture includes every reviewed Ukrainian entry.")
	for locale in ["uk", "en", "hi"]:
		if locale == "hi":
			TranslationServer.set_locale(locale) # Test-only catalog-free fallback.
		else:
			_check(bool(_locale_manager.call("set_locale", locale)), "%s can be selected." % locale)
		for entry: Dictionary in entries:
			var expected := str(entry["uk" if locale == "uk" else "en"])
			_check(TranslationServer.translate(str(entry["key"])) == expected,
				"%s resolves reviewed key %s." % [locale, entry["key"]])

	_locale_manager.call("set_locale", "uk")
	for entry: Dictionary in _reviewed["additional"]:
		_check(TranslationServer.translate(str(entry["key"])) == str(entry["uk"]),
			"Supplementary copy resolves %s." % entry["key"])
	_check(GameText.format_number(1234567) == "1 234 567", "Ukrainian counts use spaces.")
	for month in range(1, 13):
		_check(GameText.format_date({"day": 2, "month": month, "year": 2026}) ==
			"2 %s 2026 р." % _reviewed["months"][month - 1], "Month %d uses its reviewed date form." % month)
	var theme := load("res://assets/themes/game_typography.tres") as Theme
	var title_font := theme.get_font("font", "GameTitleLabel")
	for letter in "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯабвгґдеєжзиіїйклмнопрстуфхцчшщьюя’№":
		_check(title_font.has_char(letter.unicode_at(0)), "The bundled title font covers %s." % letter)
	_check_cyrillic_display(theme, true)
	for letter in "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯабвгґдеєжзиіїйклмнопрстуфхцчшщьюя’№0123456789×":
		_check((title_font as FontVariation).base_font.has_char(letter.unicode_at(0)),
			"The Ukrainian display face draws %s itself." % letter)

	var shelf := _scene("res://scenes/ui/shelf_unlock_menu.tscn")
	var starter := _scene("res://scenes/ui/starter_bundle_offer_modal.tscn")
	var row := _scene("res://scenes/ui/leaderboard_row.tscn")
	var weekly := _scene("res://scenes/ui/leaderboard_reward_dialog.tscn")
	var chip := _scene("res://scenes/ui/offer_booster_chip.tscn")
	var chapter := _scene("res://scenes/ui/chapter_cover_card.tscn")
	chip.call("set_claimed", true)
	var shop_price := "€4,99"
	for count: int in COUNTS:
		for key: String in _reviewed["plurals"]:
			_check(TranslationServer.translate_plural(key, key + ".plural", count) == _form(key, count),
				"%s selects the reviewed form for %d." % [key, count])
		for booster: String in _reviewed["counted_boosters"]:
			var names: Array = _reviewed["counted_boosters"][booster]
			var name := str(names[_form_index(count)])
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
		_check(starter.get_node("%CoinRibbon").call("get_text") == _form("starter.coins", count) % str(count),
			"The coin ribbon agrees with %d coins." % count)
		row.call("set_entry", {"rank": 2, "score": count, "display_name": "Play"})
		_check(row.get("tooltip_text") == _form("leaderboard.row_tooltip", count) % [2, "Play", count],
			"Row text chooses the star count rather than rank for %d." % count)
		weekly.call("show_reward", 3, count)
		_check(weekly.get_node("%MessageLabel").get("text") ==
			_form("leaderboard.reward.body", count) % [3, count], "Weekly copy chooses coins rather than rank for %d." % count)
		chapter.call("configure", root.get_node("ChapterCatalog").call("get_chapter", "chapter_02"),
			{"unlocked": false, "previous_completed_levels": 0, "required_completed_levels": count}, false)
		if count > 0:
			_check(chapter.get_node("%StatusLabel").get("text") ==
				_form("chapter.locked_status", count) % [count, tr("chapter.title.chapter_01")],
				"Chapter copy agrees with %d remaining levels." % count)

	_check(starter.get_node("%BuyPriceLabel").get("text") == "Купити за %s" % shop_price,
		"The platform-formatted price passes through unchanged.")
	var name_label := row.get_node("%NameLabel") as Label
	_check(name_label.atr(name_label.text) == "Play", "A real player name matching an English key stays unchanged.")
	var badge := _scene("res://scenes/ui/main_menu_starter_bundle_badge.tscn")
	var badge_label := badge.find_child("BadgeLabel", true, false) as Label
	_check(badge_label.atr(badge_label.text) == "НАБІР", "The BUNDLE scene alias resolves to НАБІР.")
	_check(tr("AD") == "AD" and tr("OFF") == "OFF", "Compact English markers stay unchanged.")
	shelf.call("set_rewarded_action_state", &"pending", false)
	var main_menu := _scene("res://scenes/main_menu.tscn")
	await process_frame
	_locale_manager.call("set_locale", "en")
	await process_frame
	_check_cyrillic_display(theme, false)
	_check(main_menu.get_node("%LevelButton").get("text") == "LEVEL 1", "An existing Main Menu switches to English.")
	_check(starter.get_node("%BuyPriceLabel").get("text") == "Buy for %s" % shop_price, "Existing offer text refreshes.")
	_check(bool(shelf.get_node("%RewardedAdButton").get("disabled")), "Language switching preserves pending ad state.")
	_locale_manager.call("set_locale", "uk")
	await process_frame
	_check(main_menu.get_node("%LevelButton").get("text") == "РІВЕНЬ 1", "The Main Menu refreshes to Ukrainian.")
	_check(root.get_node("PlayerProgress").call("_preferences_for_storage").get("locale") == "uk",
		"Ukrainian persists in local preferences.")
	_check(not root.get_node("PlayerProgress").call("_snapshot_for_storage").has("locale"),
		"Selecting Ukrainian does not alter synchronized gameplay state.")
	_locale_manager.call("set_locale", "en")
	for scene in [shelf, starter, row, weekly, chip, chapter, badge, main_menu]:
		scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Ukrainian localization tests passed (251 reviewed strings, plurals, fonts, dates, live switches and unchanged data).")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _form(key: String, count: int) -> String:
	return str(_reviewed["plurals"][key][["one", "few", "many"][_form_index(count)]])


func _form_index(count: int) -> int:
	if count % 10 == 1 and count % 100 != 11:
		return 0
	return 1 if count % 10 in [2, 3, 4] and count % 100 not in [12, 13, 14] else 2


## Russian and Ukrainian draw every DynaPuff display role, digits included, in heavier bundled
## Nunito so mixed strings such as "РІВЕНЬ 12" use one face; other locales restore DynaPuff.
func _check_cyrillic_display(theme: Theme, active: bool) -> void:
	var weights := {
		"GameTitleLabel": 700.0,
		"GameSectionLabel": 700.0,
		"GameNumberLabel": 700.0,
		"Button": 700.0,
		"GameHudLabel": 600.0,
	}
	var fonts := {"default": theme.default_font}
	for role: String in weights:
		fonts[role] = theme.get_font("font", role)
	weights["default"] = 500.0
	for role: String in fonts:
		var font := fonts[role] as FontVariation
		var path := "res://assets/fonts/Nunito-Variable.ttf" if active else "res://assets/fonts/DynaPuff-Variable.ttf"
		var weight := float(weights[role]) + (200.0 if active else 0.0)
		_check(font.base_font.resource_path == path, "The %s display face is %s." % [role, path.get_file()])
		_check(is_equal_approx(float(font.variation_opentype.get(WEIGHT_AXIS, 0.0)), weight),
			"The %s display weight is %d." % [role, weight])
	for role in ["GameGlyphButton", "GameGlyphLabel", "GameGlyphBoldLabel"]:
		var glyph_font := theme.get_font("font", role) as FontVariation
		_check(glyph_font.base_font.resource_path == "res://assets/fonts/DynaPuff-Variable.ttf",
			"%s icon characters keep DynaPuff in every locale." % role)


func _scene(scene_path: String) -> Node:
	var instance := (load(scene_path) as PackedScene).instantiate()
	root.add_child(instance)
	return instance


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
