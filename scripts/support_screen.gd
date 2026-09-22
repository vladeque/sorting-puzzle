extends Control
class_name SupportScreen

signal closed

const DestinationScreenLayoutScript := preload("res://scripts/destination_screen_layout.gd")
const UIMotionScript := preload("res://scripts/ui_motion.gd")
const SUPPORT_EMAIL_SETTING := "application/config/support_email"
const DEFAULT_SUPPORT_EMAIL := "support@sortingpuzzle.example"

@onready var _destination_shell := %DestinationShell as Control
@onready var _content_margin := %ContentMargin as MarginContainer
@onready var _title_label := %TitleLabel as Label
@onready var _back_button := %BackButton as Button
@onready var _faq_list := %FaqList as VBoxContainer
@onready var _contact_item := %ContactSupportItem as Control
@onready var _report_ad_item := %ReportAdItem as Control

var _support_email := DEFAULT_SUPPORT_EMAIL


func _ready() -> void:
	_support_email = str(
		ProjectSettings.get_setting(SUPPORT_EMAIL_SETTING, DEFAULT_SUPPORT_EMAIL)
	).strip_edges()
	_back_button.pressed.connect(_close)
	for child in _faq_list.get_children():
		var item := child as Control
		if item == null or not item.has_signal("expansion_changed"):
			continue
		item.connect("expansion_changed", Callable(self, "_on_faq_expansion_changed"))
		item.connect("action_requested", Callable(self, "_on_faq_action_requested"))
	_contact_item.call("set_answer",
		"Email us at %s. Include a short description, your device platform, and when the problem happened."
		% _support_email
	)
	_report_ad_item.call("set_answer",
		"1. Close the ad if you can do so safely.\n"
		+ "2. Take a screenshot of the ad and any advertiser or app name shown.\n"
		+ "3. Note the approximate time and where the ad appeared in the game.\n"
		+ "4. Describe why the ad seemed offensive, misleading, or fraudulent.\n"
		+ "5. Email these details to %s. Do not include passwords or payment information."
		% _support_email
	)
	_destination_shell.call("set_background_for_chapter", PlayerProgress.get_selected_chapter_id())
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var safe_margins := DestinationScreenLayoutScript.get_safe_area_margins(viewport_size)
	DestinationScreenLayoutScript.apply_content_rect(
		_content_margin,
		viewport_size,
		safe_margins,
		DestinationScreenLayoutScript.get_overlay_bottom_reserved(safe_margins)
	)
	_title_label.add_theme_font_size_override(
		"font_size", DestinationScreenLayoutScript.get_title_font_size(viewport_size)
	)
	var compact := DestinationScreenLayoutScript.is_compact_viewport(viewport_size)
	_back_button.custom_minimum_size = Vector2(64.0, 58.0) if compact else Vector2(72.0, 64.0)


func _on_faq_expansion_changed(expanded_item: Control, expanded: bool) -> void:
	if not expanded:
		return
	for child in _faq_list.get_children():
		var item := child as Control
		if (
			item != null
			and item != expanded_item
			and item.has_method("is_expanded")
			and bool(item.call("is_expanded"))
		):
			item.call("set_expanded", false, false)


func _on_faq_action_requested(action_id: StringName) -> void:
	match action_id:
		&"contact_support":
			_open_support_email(
				"Sorting Puzzle support request",
				"Please describe the issue here.\n\nDevice/platform:\nApproximate time:\n"
			)
		&"report_ad":
			_open_support_email(
				"Sorting Puzzle ad report",
				"Please attach a screenshot and complete the details below.\n\n"
				+ "Approximate time:\nAd placement in the game:\nAdvertiser or app name:\n"
				+ "Why the ad should be reviewed:\n"
			)


func _open_support_email(subject: String, body: String) -> void:
	var mailto_url := build_mailto_url(_support_email, subject, body)
	if mailto_url.is_empty():
		push_warning("Support email is not configured.")
		return
	var error := OS.shell_open(mailto_url)
	if error != OK:
		push_warning("Could not open the device email app.")


func build_mailto_url(email: String, subject: String, body: String) -> String:
	var address := email.strip_edges()
	if not is_safe_email(address):
		return ""
	return "mailto:%s?subject=%s&body=%s" % [
		address,
		subject.uri_encode(),
		body.uri_encode(),
	]


func is_safe_email(email: String) -> bool:
	if email.is_empty() or email.length() > 254 or email.contains("\r") or email.contains("\n"):
		return false
	if email.contains(" ") or email.count("@") != 1:
		return false
	var parts := email.split("@", false, 1)
	return (
		parts.size() == 2
		and not parts[0].is_empty()
		and parts[1].contains(".")
		and not parts[1].begins_with(".")
		and not parts[1].ends_with(".")
	)


func _close() -> void:
	UIMotionScript.close_with_fade(self, _finish_close)


func _finish_close() -> void:
	closed.emit()
	queue_free()
