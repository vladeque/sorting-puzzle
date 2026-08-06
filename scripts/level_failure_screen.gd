extends Control
class_name LevelFailureScreen

## Reusable level-failure overlay instanced by level.tscn (UI-003 P0). Previously the level embedded
## a bare shade + "LEVEL FAILED" label directly in level.tscn with no action at all, trapping the
## player in a terminal screen with no route forward. This scene gives Failure the same working
## exit Completion already has, sharing terminal shade, hero title, action placement, safe-area
## layout, and open/close motion with Completion through scenes/ui/gameplay_result_shell.tscn (see
## docs/SCENES.md "Shared Gameplay UI Roles") without merging their state-specific content.

signal main_menu_pressed

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")

const MESSAGE_SIZE := Vector2(560.0, 140.0)
const MESSAGE_CENTER_Y := 460.0

@onready var _shell := %Shell as GameplayResultShell
@onready var _message_label := %MessageLabel as Label
@onready var _main_menu_button := %MainMenuButton as Button


func _ready() -> void:
	_shell.configure("LEVEL FAILED")
	_message_label.reparent(_shell.get_content_region(), false)

	var action := _shell.get_action_region()
	_main_menu_button.reparent(action, false)
	_main_menu_button.anchor_left = 0.0
	_main_menu_button.anchor_top = 0.0
	_main_menu_button.anchor_right = 1.0
	_main_menu_button.anchor_bottom = 1.0
	_main_menu_button.offset_left = 0.0
	_main_menu_button.offset_top = 0.0
	_main_menu_button.offset_right = 0.0
	_main_menu_button.offset_bottom = 0.0
	_main_menu_button.pressed.connect(_on_main_menu_button_pressed)


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_shell.apply_safe_layout(safe_margins, viewport_size)

	# Body-message placement is Failure-specific and stays local rather than moving into the shared
	# shell, matching how Completion keeps its own star/earned-count placement local.
	var scale := GameplayUIThemeScript.get_result_title_scale(viewport_size)
	var center_x := viewport_size.x * 0.5
	var message_center_y := safe_margins.y + MESSAGE_CENTER_Y * scale
	_layout_centered_control(_message_label, Vector2(center_x, message_center_y), MESSAGE_SIZE * scale)


func is_transitioning() -> bool:
	return _shell.is_transitioning()


## Shows this overlay's root immediately (so the shell's own fade-in is actually visible), then
## starts the shell's animated fade.
func open() -> void:
	show()
	_shell.open()


## Waits for the shell's fade-out before hiding the root.
func close() -> void:
	await _shell.close()
	hide()


func _layout_centered_control(control: Control, center: Vector2, size: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = center.x - size.x * 0.5
	control.offset_top = center.y - size.y * 0.5
	control.offset_right = center.x + size.x * 0.5
	control.offset_bottom = center.y + size.y * 0.5


func _on_main_menu_button_pressed() -> void:
	main_menu_pressed.emit()
