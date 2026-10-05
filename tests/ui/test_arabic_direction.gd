extends SceneTree

const Layout := preload("res://scripts/destination_screen_layout.gd")
var _failures: Array[String] = []
var _manager: Node


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with("SortingPuzzleTest_"):
		push_error("Arabic direction tests require the isolated runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_manager = root.get_node("LocaleManager")
	var pager := _scene("res://scenes/ui/horizontal_pager.tscn") as HorizontalPager
	for index in range(3):
		pager.add_page(Control.new())
	var support := _scene("res://scenes/ui/support_screen.tscn") as Control
	var faq := support.get_node("%ReportAdItem") as Control
	faq.call("set_expanded", true)
	var content := MarginContainer.new()
	root.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var modal := _scene("res://scenes/ui/gameplay_modal_shell.tscn") as GameplayModalShell
	var chapter := _scene("res://scenes/ui/chapter_cover_card.tscn") as Control
	var hud := _scene("res://scenes/ui/level_top_hud.tscn") as Control
	var time_up := _scene("res://scenes/ui/time_up_extension_modal.tscn") as Control
	var reward_row := _scene("res://scenes/ui/reward_reveal_row.tscn") as Control
	var profile := _scene("res://scenes/ui/profile_menu.tscn") as Control
	var name_edit := profile.get_node("%NameLineEdit") as LineEdit
	profile.call("_begin_name_edit")
	name_edit.text = "مريم Play 123"
	name_edit.caret_column = 4
	name_edit.select(0, 4)
	var original_name := name_edit.text
	var text_server := TextServerManager.get_primary_interface()
	_check(text_server.has_feature(TextServer.FEATURE_BIDI_LAYOUT), "BiDi text server is available.")
	_check(text_server.has_feature(TextServer.FEATURE_SHAPING), "Complex shaping is available.")

	for locale: String in ["en", "ar", "en", "ru", "ar", "uk", "ar", "it", "ar", "en"]:
		_manager.call("set_locale", locale)
		for frame in range(4):
			await process_frame
		var rtl := locale == "ar"
		_check(pager.is_layout_rtl() == rtl, "%s applies the expected direction." % locale)
		_check(faq.get_node("%AnswerLabel").get("horizontal_alignment") ==
			(HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT), "%s FAQ reading alignment." % locale)
		_check(bool(faq.call("is_expanded")), "Live switching preserves FAQ expansion.")
		_check(name_edit.text == original_name and name_edit.get_selected_text() == "مريم",
			"Switching preserves mixed name text and selection.")
		_check(name_edit.text_direction == Control.TEXT_DIRECTION_AUTO, "Names follow their content direction.")
		_check(chapter.get_node("%ProgressValueLabel").get("text_direction") == Control.TEXT_DIRECTION_LTR,
			"Chapter fractions retain current/total order.")
		_check(hud.get_node("%TimerLabel").get("text_direction") == Control.TEXT_DIRECTION_LTR,
			"Timer punctuation retains LTR order.")
		_check(reward_row.get_node("%CoinAmountLabel").get("text_direction") == Control.TEXT_DIRECTION_LTR,
			"Reward coin amounts retain +count order.")
		for viewport_size: Vector2 in [Vector2(540, 960), Vector2(720, 1280), Vector2(1080, 1920), Vector2(1080, 2400), Vector2(1200, 1600)]:
			time_up.call("apply_safe_layout", Vector4.ZERO, viewport_size)
			for frame in range(3):
				await process_frame
			var cream: Rect2 = time_up.get_node("%Shell").get_node("%ContentRegion").get_global_rect()
			var message: Rect2 = time_up.get_node("%MessageLabel").get_global_rect()
			_check(message.end.y <= cream.end.y and message.position.y >= cream.position.y,
				"%s timeout explanation fits its panel at %s." % [locale, viewport_size])
		pager.go_to_page(0, false)
		var first_page := pager.get_node("%Track").get_child(0) as Control
		_check(is_equal_approx(first_page.global_position.x - pager.global_position.x, pager.peek_width),
			"The first page has the same physical peek in %s." % locale)
		var swipe := 400.0 if rtl else -400.0
		pager.call("_begin_press", Vector2(360, 300))
		pager.call("_update_pointer_motion", Vector2(360 + swipe, 300))
		pager.call("_end_press", Vector2(360 + swipe, 300))
		_check(pager.get_current_page() == 1, "The conventional next swipe advances in %s." % locale)
		await create_timer(0.4).timeout
		var second_page := pager.get_node("%Track").get_child(1) as Control
		_check(is_equal_approx(second_page.global_position.x - pager.global_position.x, pager.peek_width),
			"The selected page snaps into the viewport in %s." % locale)
		pager.call("_go_next")
		_check(pager.get_current_page() == 2, "Next arrow advances the logical index.")
		pager.call("_begin_press", Vector2(360, 300))
		pager.call("_update_pointer_motion", Vector2(360 + swipe, 300))
		pager.call("_end_press", Vector2(360 + swipe, 300))
		_check(pager.get_current_page() == 2, "Swiping beyond the last page stays bounded.")
		pager.go_to_page(1, false)
		pager.call("_begin_press", Vector2(360, 300))
		pager.call("_update_pointer_motion", Vector2(390, 300))
		# A live switch during a drag must cancel the gesture without changing chapter identity.
		_manager.call("set_locale", "en" if rtl else "ar")
		for frame in range(4):
			await process_frame
		_check(pager.get_current_page() == 1 and not bool(pager.get("_pressed")),
			"Direction changes cancel dragging and preserve the current page.")
		_manager.call("set_locale", locale)
		for frame in range(4):
			await process_frame
		for insets: Vector4 in [Vector4(48, 24, 0, 32), Vector4(0, 24, 64, 32)]:
			var viewport := root.get_visible_rect().size
			Layout.apply_content_rect(content, viewport, insets, 100)
			modal.apply_safe_layout(insets, viewport)
			pager.set_safe_margins(insets)
			await process_frame
			var rect := content.get_global_rect()
			_check(rect.position.x >= insets.x + 15.0 and rect.end.x <= viewport.x - insets.z - 15.0,
				"%s content respects both physical cutout sides." % locale)
			var panel := modal.get_node("%OuterPanel") as Control
			var expected_center := (viewport.x + insets.x - insets.z) * 0.5
			_check(absf(panel.get_global_rect().get_center().x - expected_center) < 1.0,
				"%s modal centers in the physical safe area." % locale)
			var prev := pager.get_node("%PrevArrow") as Control
			var next := pager.get_node("%NextArrow") as Control
			var left_arrow := next if rtl else prev
			var right_arrow := prev if rtl else next
			_check(left_arrow.global_position.x >= insets.x and right_arrow.get_global_rect().end.x <= viewport.x - insets.z,
				"%s pager arrows respect asymmetric physical insets." % locale)

	_manager.call("set_locale", "ar")
	_check(GameText.isolate_ltr("2/11/2026") == "\u20662/11/2026\u2069", "Dates isolate only their display run.")
	_check(GameText.combo_caption(3).contains("\u2066×3\u2069"), "The combo multiplier retains ×count order.")
	for price: String in ["$4.99", "€4,99", "4.99 ر.س", "\u200f4.99 ر.س\u200f"]:
		_check(GameText.isolate_price(price) == "\u2068" + price + "\u2069", "Price isolation preserves supplied content and direction marks.")
	var raw_body := tr("support.ad_email.body")
	_check(not raw_body.contains("\u2066") and not raw_body.contains("\u2069"), "Raw email templates contain no presentation direction marks.")
	_manager.call("set_locale", "en")
	_check(GameText.isolate_ltr("id-123") == "id-123", "Existing LTR presentation stays literal.")
	for scene in [pager, support, content, modal, chapter, hud, profile, time_up, reward_row]:
		scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Arabic direction tests passed (gestures, physical safe areas, names, reading alignment and live switches).")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _scene(path: String) -> Node:
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	return scene


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
