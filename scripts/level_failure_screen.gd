extends Control
class_name LevelFailureScreen

## Reusable level-failure modal instanced by level.tscn. The shared gameplay modal shell owns the
## dimmed backdrop, safe-area-fitted panel, title, close button, action row, and transition motion;
## this scene owns the broken-heart result content and Retry intent.

signal retry_pressed
signal main_menu_pressed

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const FAILURE_MODAL_HEIGHT := 620.0
const CONTENT_REGION_HEIGHT := 336.0

@onready var _shell := %Shell as GameplayModalShell
@onready var _failure_content := %FailureContent as Control
@onready var _message_label := %MessageLabel as Label
@onready var _retry_button := %RetryButton as Button

var _level_number := 1


func _ready() -> void:
	_shell.set_preferred_size(Vector2(
		GameplayUIThemeScript.MODAL_MAX_WIDTH,
		FAILURE_MODAL_HEIGHT
	))
	_shell.set_content_region_height(CONTENT_REGION_HEIGHT)
	_shell.close_requested.connect(func() -> void: main_menu_pressed.emit())
	_failure_content.reparent(_shell.get_content_region(), false)
	_retry_button.reparent(_shell.get_action_row(), false)
	_retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	_update_title()
	_message_label.resized.connect(_fit_message)
	_fit_message.call_deferred()


func set_level_number(level_number: int) -> void:
	_level_number = maxi(level_number, 1)
	if is_node_ready():
		_update_title()


func is_transitioning() -> bool:
	return _shell.is_transitioning()


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_shell.apply_safe_layout(safe_margins, viewport_size)


func open() -> void:
	show()
	_shell.open()


func close() -> void:
	await _shell.close()
	if _shell.visible:
		return
	hide()


func _update_title() -> void:
	_shell.configure(tr("failed.title") % _level_number)


func _fit_message() -> void:
	_message_label.add_theme_font_size_override("font_size", GameplayUIThemeScript.fit_label_font_size(
		_message_label, _message_label.size.x, 36, 24
	))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_title()
		_fit_message.call_deferred()
