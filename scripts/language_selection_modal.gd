extends Control
class_name LanguageSelectionModal

signal locale_confirmed(locale: String)

const LANGUAGE_OPTION_ROW_SCENE := preload("res://scenes/ui/language_option_row.tscn")
const DestinationScreenLayoutScript := preload("res://scripts/destination_screen_layout.gd")
const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const PREFERRED_SIZE := Vector2(520.0, 760.0)
const CONTENT_HEIGHT := 510.0

@onready var _shell := %Shell as GameplayModalShell
@onready var _language_content := %LanguageContent as Control
@onready var _language_scroll := %LanguageScroll as ScrollContainer
@onready var _language_list := %LanguageList as VBoxContainer
@onready var _save_button := %SaveButton as Button

var _pending_locale := ""
var _rows: Dictionary = {}
var _is_closing := false


func _ready() -> void:
	_shell.configure("LANGUAGE")
	_shell.set_preferred_size(PREFERRED_SIZE)
	_shell.set_content_region_height(CONTENT_HEIGHT)
	_language_content.reparent(_shell.get_content_region(), false)
	_save_button.reparent(_shell.get_action_row(), false)
	_shell.close_requested.connect(close)
	_save_button.pressed.connect(_save_selection)
	_pending_locale = LocaleManager.get_current_locale()
	_build_language_rows()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_shell.hide()
	open.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _is_closing:
		return
	get_viewport().set_input_as_handled()
	close()


func open() -> void:
	show()
	_apply_responsive_layout()
	_shell.show()
	_shell.open()
	_scroll_to_pending.call_deferred()


func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	await _shell.close()
	queue_free()


func get_pending_locale() -> String:
	return _pending_locale


func _build_language_rows() -> void:
	for child in _language_list.get_children():
		child.queue_free()
	_rows.clear()
	for entry in LocaleManager.get_supported_locales():
		var locale := str(entry.get("locale", ""))
		var row := LANGUAGE_OPTION_ROW_SCENE.instantiate() as Button
		_language_list.add_child(row)
		row.call("setup", locale, str(entry.get("label", locale)), locale == _pending_locale)
		row.connect("locale_selected", Callable(self, "_select_locale"))
		_rows[locale] = row


func _select_locale(locale: String) -> void:
	if not _rows.has(locale):
		return
	_pending_locale = locale
	for row_locale in _rows:
		(_rows[row_locale] as Button).call("set_locale_selected", row_locale == locale)


func _save_selection() -> void:
	if _is_closing:
		return
	if not LocaleManager.set_locale(_pending_locale):
		push_error("Could not apply supported locale: %s" % _pending_locale)
		return
	locale_confirmed.emit(_pending_locale)
	close()


func _scroll_to_pending() -> void:
	var selected_row := _rows.get(_pending_locale) as Control
	if selected_row != null and is_instance_valid(selected_row):
		_language_scroll.ensure_control_visible(selected_row)


func _apply_responsive_layout() -> void:
	if _shell == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var safe_margins := DestinationScreenLayoutScript.get_safe_area_margins(viewport_size)
	_shell.apply_safe_layout(safe_margins, viewport_size)
	var available_width := maxf(
		viewport_size.x - safe_margins.x - safe_margins.z
		- GameplayUIThemeScript.MODAL_MIN_EDGE_GAP * 2.0,
		1.0
	)
	var save_minimum := _save_button.custom_minimum_size
	save_minimum.x = minf(300.0, available_width)
	_save_button.custom_minimum_size = save_minimum
