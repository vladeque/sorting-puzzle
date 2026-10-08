extends SceneTree

const FIXTURE := "res://tests/localization/korean_inventory.json"
const COUNTS := [0, 1, 2, 3, 10, 11, 21, 101, 1000, 1000000]
var _failures: Array[String] = []
var _reviewed: Dictionary
var _locale_manager: Node
const DISPLAY_ROLES: Array[String] = ["GameTitleLabel", "GameSectionLabel", "GameHudLabel", "GameNumberLabel", "Button"]
var _font_characters: Dictionary = {}


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with("SortingPuzzleTest_"):
		push_error("Korean localization tests require the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_locale_manager = root.get_node("LocaleManager")
	_reviewed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) as Dictionary
	for device_locale in ["ko", "ko_KR", "ko-KR", "ko_KP"]:
		_check(LocaleCatalog.resolve_device_locale(device_locale) == "ko",
			"Korean regional device locale %s selects 한국어." % device_locale)
	var entries: Array = _reviewed["entries"]
	_check(entries.size() == 251, "The fixture includes every reviewed Korean entry.")
	for locale in ["ko", "en", "hi"]:
		if locale == "hi":
			TranslationServer.set_locale(locale) # Test-only catalog-free fallback.
		else:
			_check(bool(_locale_manager.call("set_locale", locale)), "%s can be selected." % locale)
		for entry: Dictionary in entries:
			var key := str(entry["key"])
			var expected := str(entry["ko" if locale == "ko" else "en"])
			if locale == "ko" and _reviewed["plurals"].has(key):
				expected = _form(key, 1)
			_check(TranslationServer.translate(key) == expected,
				"%s resolves reviewed key %s." % [locale, key])
			if locale == "ko" and key not in ["common.resume", "common.retry_load"]:
				_check(TranslationServer.translate(str(entry["en"])) == str(entry["ko"]),
					"English scene alias resolves reviewed key %s." % key)

	_locale_manager.call("set_locale", "ko")
	for entry: Dictionary in _reviewed["additional"]:
		_check(TranslationServer.translate(str(entry["key"])) == str(entry["ko"]),
			"Supplementary copy resolves %s." % entry["key"])
	_check(GameText.format_number(1234567) == "1,234,567", "Korean counts use comma grouping.")
	_check(GameText.format_number(1) == "1", "Single-digit amounts have no separator.")
	_check(GameText.format_number(-1) == "0", "The formatter retains its existing nonnegative boundary.")
	_check("%s: %s" % [tr("support.email.deletion_reference"), "op_sample"] ==
		"삭제 참조 번호: op_sample", "Email fragments retain Korean labels and raw references.")
	for month in range(1, 13):
		_check(GameText.format_date({"day": 2, "month": month, "year": 2026}) ==
			"2026년 %d월 2일" % month, "Month %d uses the Korean year/month/day date form." % month)
	var theme := load("res://assets/themes/game_typography.tres") as Theme
	var characters := "한국어년월일₩한국어×·•"
	for entry: Dictionary in entries:
		characters += str(entry["ko"])
	for entry: Dictionary in _reviewed["additional"]:
		characters += str(entry["ko"])
	var checked := {}
	for letter in characters:
		checked[letter] = true
	for role in ["GameTitleLabel", "GameSectionLabel", "GameHudLabel", "GameNumberLabel", "GameBodyLabel", "GameSmallLabel", "Button", "GameBodyButton", "LineEdit", "TextEdit"]:
		var font := theme.get_font("font", role)
		for letter: String in checked:
			if letter.unicode_at(0) > 127:
				_check(_bundled_has_char(font, letter), "Bundled %s covers %s without system fallback." % [role, letter])
	for role in ["normal_font", "bold_font"]:
		for letter: String in checked:
			if letter.unicode_at(0) > 127:
				_check(_bundled_has_char(theme.get_font(role, "GameBodyRichText"), letter), "RichText %s covers %s." % [role, letter])
	var display_face := load("res://assets/fonts/Jua-Regular.ttf") as FontFile
	for role in ["GameTitleLabel", "GameSectionLabel", "GameHudLabel", "GameNumberLabel", "GameBodyLabel", "GameSmallLabel", "Button", "GameBodyButton", "LineEdit", "TextEdit"]:
		var expected := "Jua-Regular.ttf" if DISPLAY_ROLES.has(role) else "NotoSansKR-Variable.ttf"
		_check(_first_face_for(theme.get_font("font", role), "레") == expected, "%s draws Korean with %s." % [role, expected])
	for letter: String in checked:
		if letter.unicode_at(0) >= 0xAC00 and letter.unicode_at(0) <= 0xD7A3:
			_check(display_face.has_char(letter.unicode_at(0)), "Jua draws %s in display roles." % letter)
	_check(tr("failed.headline") == "레벨 실패", "The reviewed failure headline is preserved.")
	_check(tr("starter.one_time") == "한 번만 구매 가능", "The reviewed one-time offer is preserved.")
	_check(tr("Retry") == "다시 도전", "The failure-screen scene alias uses the reviewed replay action.")
	_check(tr("common.retry_load") == "다시 불러오기", "The reload action keeps its distinct reviewed translation.")

	var shelf := _scene("res://scenes/ui/shelf_unlock_menu.tscn")
	var starter := _scene("res://scenes/ui/starter_bundle_offer_modal.tscn")
	var row := _scene("res://scenes/ui/leaderboard_row.tscn")
	var weekly := _scene("res://scenes/ui/leaderboard_reward_dialog.tscn")
	var rank_reward := _scene("res://scenes/ui/leaderboard_rank_reward.tscn")
	var chip := _scene("res://scenes/ui/offer_booster_chip.tscn")
	var chapter := _scene("res://scenes/ui/chapter_cover_card.tscn")
	var failure_screen := _scene("res://scenes/ui/level_failure_screen.tscn")
	var support := _scene("res://scenes/ui/support_screen.tscn") as Control
	var deletion := _scene("res://scenes/ui/account_deletion_modal.tscn") as Control
	deletion.set("_attempted", true)
	deletion.call("present", {"phase": "idle", "failure": {"reason": "offline"}}, {"kind": "account"})
	chip.call("set_claimed", true)
	var shop_price := "₩6,600"
	var reward_texture := GradientTexture2D.new()
	for count: int in COUNTS:
		for key: String in _reviewed["plurals"]:
			_check(TranslationServer.translate_plural(key, key + ".plural", count) == _form(key, count),
				"%s selects the reviewed form for %d." % [key, count])
		for booster: String in _reviewed["counted_boosters"]:
			var names: Array = _reviewed["counted_boosters"][booster]
			var name := str(names[0])
			_check(GameText.counted_booster(booster, count) == name,
				"%s preserves the reviewed fixed product label for %d." % [booster, count])
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

	_check(starter.get_node("%BuyPriceLabel").get("text") == "%s에 구매하기" % shop_price,
		"The reviewed price caption keeps the store-formatted price unchanged.")
	shelf.call("set_rewarded_action_state", &"ready", true)
	var shelf_button := shelf.get_node("%RewardedAdButton") as Button
	for viewport_size in [Vector2(540, 960), Vector2(720, 1280), Vector2(1080, 1920),
		Vector2(1080, 2400), Vector2(1200, 1600)]:
		shelf.call("set_rewarded_action_state", &"ready", true)
		shelf.call("apply_safe_layout", Vector4.ZERO, viewport_size)
		failure_screen.call("apply_safe_layout", Vector4.ZERO, viewport_size)
		root.size = Vector2i(viewport_size)
		await process_frame
		await process_frame
		for action in ["PrimaryButton", "SecondaryButton"]:
			var deletion_button := deletion.get_node("%" + action) as Button
			var deletion_width := deletion_button.get_theme_font("font").get_string_size(
				deletion_button.atr(deletion_button.text), HORIZONTAL_ALIGNMENT_LEFT, -1,
				deletion_button.get_theme_font_size("font_size")).x
			_check(deletion_width <= minf(deletion_button.size.x, deletion_button.custom_minimum_size.x)
				- float(deletion.get("action_text_padding")), "The complete deletion action fits with padding at %s." % viewport_size)
		for item in support.get_node("%FaqList").get_children():
			if not item is SupportFaqItem:
				continue
			var question_button := item.get_node("%QuestionButton") as Button
			var question_style := question_button.get_theme_stylebox("normal")
			var question_width := question_button.get_theme_font("font").get_string_size(
				question_button.atr(question_button.text), HORIZONTAL_ALIGNMENT_LEFT, -1,
				question_button.get_theme_font_size("font_size")).x
			_check(question_width <= question_button.size.x - question_style.get_content_margin(SIDE_LEFT)
				- question_style.get_content_margin(SIDE_RIGHT),
				"The complete FAQ question leaves room for its expand icon: %s, width %s, font %d." % [
					question_button.atr(question_button.text), question_button.size,
					question_button.get_theme_font_size("font_size")])
		var font_size := shelf_button.get_theme_font_size("font_size")
		var caption_width := shelf_button.get_theme_font("font").get_string_size(
			shelf_button.atr(shelf_button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var available_width := minf(shelf_button.size.x, shelf_button.custom_minimum_size.x) \
			- float(shelf.get("rewarded_action_text_padding"))
		_check(caption_width <= available_width, "The complete shelf action fits with padding at %s." % viewport_size)
		_check(shelf_button.atr(shelf_button.text) == "광고 보기 · 선반 잠금 해제",
			"Font fitting preserves the reviewed shelf action.")
		var retry_button := failure_screen.get_node("%RetryButton") as Button
		var retry_width := retry_button.get_theme_font("font").get_string_size(
			retry_button.atr(retry_button.text), HORIZONTAL_ALIGNMENT_LEFT, -1,
			retry_button.get_theme_font_size("font_size")).x
		_check(retry_width <= minf(retry_button.size.x, retry_button.custom_minimum_size.x)
			- float(failure_screen.get("retry_text_padding")), "The replay caption fits with padding at %s." % viewport_size)
		_check(retry_button.atr(retry_button.text) == "다시 도전", "Failure preserves the reviewed replay wording.")
		for state in [&"ready", &"pending", &"error"]:
			shelf.call("set_rewarded_action_state", state, false)
			for frame in range(4):
				await process_frame
			var offer_row := shelf.get_node("%UnlockContent").get_node("OfferRow") as HBoxContainer
			var cream_panel := (shelf.get("_shell") as GameplayModalShell).get_content_region()
			var padded_height := offer_row.get_combined_minimum_size().y + offer_row.offset_top - offer_row.offset_bottom
			_check(padded_height <= cream_panel.size.y + 0.5,
				"The complete shelf description and %s status stay inside the cream panel at %s." % [state, viewport_size])
	var name_label := row.get_node("%NameLabel") as Label
	_check(name_label.atr(name_label.text) == "Play", "A player name matching an English key stays unchanged.")
	var badge := _scene("res://scenes/ui/main_menu_starter_bundle_badge.tscn")
	var badge_label := badge.find_child("BadgeLabel", true, false) as Label
	_check(badge_label.atr(badge_label.text) == "패키지", "The BUNDLE scene alias uses the reviewed badge.")
	_check(tr("AD") == "AD" and tr("OFF") == "OFF", "Compact English markers stay unchanged.")
	var pause := _scene("res://scenes/pause_menu.tscn")
	var leave := _scene("res://scenes/leave_confirmation_menu.tscn")
	for overlay in [pause, leave]:
		_check(overlay.find_child("ContinueButton", true, false).get("text") == "계속하기",
			"Gameplay resume preserves the reviewed 계속하기 action.")
	shelf.call("set_rewarded_action_state", &"pending", false)
	var main_menu := _scene("res://scenes/main_menu.tscn")
	await process_frame
	_locale_manager.call("set_locale", "en")
	await process_frame
	await process_frame
	_check(main_menu.get_node("%LevelButton").get("text") == "LEVEL 1", "An existing Main Menu switches to English.")
	_check(starter.get_node("%BuyPriceLabel").get("text") == "Buy for %s" % shop_price, "Existing offer text refreshes.")
	_check(bool(shelf.get_node("%RewardedAdButton").get("disabled")), "Language switching preserves pending ad state.")
	_check(shelf_button.get_theme_font_size("font_size") == 24,
		"A shorter English pending action restores the maximum font size after a live switch.")
	_check((failure_screen.get_node("%RetryButton") as Button).get_theme_font_size("font_size") == 32,
		"The shorter English replay action restores the original maximum font size.")
	_check((deletion.get_node("%PrimaryButton") as Button).get_theme_font_size("font_size") == 22,
		"The shorter English deletion retry restores the original font size.")
	for overlay in [pause, leave]:
		_check(overlay.find_child("ContinueButton", true, false).get("text") == "Continue",
			"An existing resume action switches to English.")
	_locale_manager.call("set_locale", "ko")
	await process_frame
	_check(main_menu.get_node("%LevelButton").get("text") == "레벨 1", "The Main Menu retains its level number and translates on a live Korean switch.")
	var chapter_button := main_menu.get_node("%ChapterButton") as Button
	_check(chapter_button.text == "챕터 1", "The existing chapter button refreshes to Korean.")
	_check(starter.get_node("%BuyPriceLabel").get("text") == "%s에 구매하기" % shop_price,
		"The corrected Korean purchase caption returns on a live switch.")
	for overlay in [pause, leave]:
		_check(overlay.find_child("ContinueButton", true, false).get("text") == "계속하기",
			"An existing resume action switches back to Korean.")
	_check(root.get_node("PlayerProgress").call("_preferences_for_storage").get("locale") == "ko",
		"Korean persists in local preferences.")
	_check(not root.get_node("PlayerProgress").call("_snapshot_for_storage").has("locale"),
		"Selecting Korean does not alter synchronized gameplay state.")
	_locale_manager.call("set_locale", "en")
	for scene in [shelf, starter, row, weekly, rank_reward, chip, chapter, failure_screen, support, deletion, badge, pause, leave, main_menu]:
		scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Korean localization tests passed (251 reviewed strings, aliases, plurals, fonts, dates, live switches and unchanged data).")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _form(key: String, _count: int) -> String:
	if _reviewed["plurals"].has(key):
		return str(_reviewed["plurals"][key]["other"])
	for entry: Dictionary in _reviewed["entries"]:
		if entry["key"] == key:
			return str(entry["ko"])
	return ""


func _scene(scene_path: String) -> Node:
	var instance := (load(scene_path) as PackedScene).instantiate()
	root.add_child(instance)
	return instance


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


## Returns the file of the first bundled face, in the order Godot searches a fallback chain, that
## draws the character.
func _first_face_for(font: Font, character: String) -> String:
	var own: Font = (font as FontVariation).base_font if font is FontVariation else font
	if own is FontFile and own.has_char(character.unicode_at(0)):
		return own.resource_path.get_file()
	for fallback in font.fallbacks:
		var found := _first_face_for(fallback, character)
		if not found.is_empty():
			return found
	return ""


func _bundled_has_char(font: Font, character: String) -> bool:
	if font is FontVariation and _bundled_has_char((font as FontVariation).base_font, character):
		return true
	if font is FontFile:
		var font_id := font.get_instance_id()
		if not _font_characters.has(font_id):
			_font_characters[font_id] = font.get_supported_chars()
		if str(_font_characters[font_id]).contains(character):
			return true
	for fallback in font.fallbacks:
		if _bundled_has_char(fallback, character):
			return true
	return false
