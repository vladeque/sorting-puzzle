extends SceneTree

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LANGUAGE_MODAL_SCENE_PATH := "res://scenes/ui/language_selection_modal.tscn"
const LocaleCatalogScript := preload("res://scripts/localization/locale_catalog.gd")

var _failures: Array[String] = []
var _progress: Node
var _locale_manager: Node


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Language selection tests must use the isolated test runner.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_progress = root.get_node_or_null("PlayerProgress")
	_locale_manager = root.get_node_or_null("LocaleManager")
	_check(_progress != null, "PlayerProgress autoload is available.")
	_check(_locale_manager != null, "LocaleManager autoload is available.")
	if _progress == null or _locale_manager == null:
		quit(1)
		return

	_progress.call("reset_progress")
	_check(bool(_locale_manager.call("set_locale", "en")), "English can be selected for test setup.")
	_check(
		LocaleCatalogScript.get_entries().size() == 11,
		"The release catalog exposes exactly eleven approved locales."
	)
	_check(LocaleCatalogScript.resolve_device_locale("pt-PT") == "pt_BR", "Portuguese maps to pt_BR.")
	_check(LocaleCatalogScript.resolve_device_locale("zh-TW") == "zh_Hant", "Taiwan maps to zh_Hant.")
	_check(LocaleCatalogScript.resolve_device_locale("zh-CN") == "en", "Simplified Chinese falls back to English.")
	_check(
		not bool(_locale_manager.call("set_locale", "unsupported")),
		"Unsupported locale codes are rejected."
	)

	var modal_scene := load(LANGUAGE_MODAL_SCENE_PATH) as PackedScene
	var modal := modal_scene.instantiate() as Control
	root.add_child(modal)
	await create_timer(0.35).timeout
	var list := modal.get_node("%LanguageList") as VBoxContainer
	var scroll := modal.get_node("%LanguageScroll") as ScrollContainer
	_check(list.get_child_count() == 11, "The language modal renders all eleven release locales.")
	_check(modal.call("get_pending_locale") == "en", "The active locale is selected on open.")
	_check(
		scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
		"The language list remains scrollable without showing a mobile scrollbar."
	)
	_check(modal.get_node("%SaveButton").text == "SAVE", "The modal uses the Profile-style Save action.")

	modal.call("_select_locale", "ru")
	_check(modal.call("get_pending_locale") == "ru", "Tapping a row changes the pending locale.")
	_check(_progress.call("get_locale") == "en", "Pending selection does not change saved locale.")
	_check(TranslationServer.get_locale() == "en", "Pending selection does not change runtime locale.")
	modal.call("_save_selection")
	_check(_progress.call("get_locale") == "ru", "Save persists the selected locale.")
	_check(TranslationServer.get_locale() == "ru", "Save updates TranslationServer immediately.")
	var snapshot := _progress.call("_snapshot_for_storage") as Dictionary
	var preferences := _progress.call("_preferences_for_storage") as Dictionary
	_check(not snapshot.has("locale"), "Locale is excluded from the synchronized gameplay snapshot.")
	_check(preferences.get("locale", "") == "ru", "Locale is stored in local preferences.")
	await create_timer(0.5).timeout
	_progress.call("load_progress")
	_check(_progress.call("get_locale") == "ru", "Reloading progress restores the saved locale.")

	var discard_modal := modal_scene.instantiate() as Control
	root.add_child(discard_modal)
	await create_timer(0.35).timeout
	_check(discard_modal.call("get_pending_locale") == "ru", "A reopened modal restores saved locale.")
	discard_modal.call("_select_locale", "ja")
	discard_modal.call("close")
	await create_timer(0.5).timeout
	_check(_progress.call("get_locale") == "ru", "Closing the modal discards a pending selection.")
	_check(TranslationServer.get_locale() == "ru", "Closing does not change runtime locale.")

	var main_scene := load("res://scenes/main_menu.tscn") as PackedScene
	var main_menu := main_scene.instantiate() as Control
	root.add_child(main_menu)
	await create_timer(0.35).timeout
	main_menu.call("_open_settings_menu")
	await create_timer(0.35).timeout
	var settings := main_menu.get_node_or_null("MainMenuSettingsOverlay") as Control
	_check(settings != null, "Main Menu opens Settings before language selection.")
	if settings != null:
		var language_button := settings.find_child("LanguageButton", true, false) as Button
		_check(language_button != null, "Settings exposes its Language button.")
		if language_button != null:
			language_button.pressed.emit()
			await create_timer(0.35).timeout
			var stacked_modal := main_menu.get_node_or_null("LanguageSelectionModal") as Control
			_check(stacked_modal != null, "Language opens as a modal above Settings.")
			if stacked_modal != null:
				stacked_modal.call("close")
				await create_timer(0.5).timeout
				_check(
					is_instance_valid(settings),
					"Closing Language leaves the underlying Settings modal open."
				)
	main_menu.queue_free()
	await create_timer(0.5).timeout

	if _failures.is_empty():
		print("Language selection tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
