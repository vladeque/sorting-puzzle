extends Control
class_name LeaveConfirmationMenu

## Reusable in-level leave-confirmation overlay shown from Pause's Leave action. Composes
## scenes/ui/gameplay_modal_shell.tscn for shade, outer panel, title, close button, content region,
## and action row (UI-003; see docs/SCENES.md "Shared Gameplay UI Roles"). Previously this scene had
## no script of its own and scripts/level.gd reached its Leave/Continue buttons and star-count label
## directly by child path -- this script now owns that data and those signals instead.
##
## close_requested (the shared X button / system back) and continue_pressed (the explicit green
## Continue action) are deliberately distinct signals: per UI-003, close/system-back on this screen
## returns to Pause, while the explicit Continue action resumes gameplay directly. Both used to
## collapse into the same "resume gameplay" behavior; scripts/level.gd now tells them apart.

signal close_requested
signal leave_pressed
signal continue_pressed

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")

@onready var _shell := %Shell as GameplayModalShell
@onready var _loss_content := %LossContent as Control
@onready var _confirm_leave_button := %ConfirmLeaveButton as Button
@onready var _continue_button := %ContinueButton as Button
@onready var _star_count_label := %CountLabel as Label


func _ready() -> void:
	_shell.configure("LEAVING THE LEVEL", true)
	_shell.set_preferred_size(Vector2(GameplayUIThemeScript.MODAL_MAX_WIDTH, 560.0))
	_shell.close_requested.connect(func() -> void: close_requested.emit())
	_loss_content.reparent(_shell.get_content_region(), false)
	_confirm_leave_button.reparent(_shell.get_action_row(), false)
	_continue_button.reparent(_shell.get_action_row(), false)
	_confirm_leave_button.pressed.connect(func() -> void: leave_pressed.emit())
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())


## Writes the current run's star total into the lost-reward badge, shrinking the font for longer
## values so it stays inside the badge (matches the star HUD counter's own overflow handling).
func set_star_count(stars: int) -> void:
	var stars_text := "%d" % stars
	var font_size := 30
	if stars_text.length() >= 6:
		font_size = 22
	elif stars_text.length() >= 5:
		font_size = 24
	elif stars_text.length() >= 4:
		font_size = 26

	_star_count_label.add_theme_font_size_override("font_size", font_size)
	_star_count_label.text = stars_text


func is_transitioning() -> bool:
	return _shell.is_transitioning()


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_shell.apply_safe_layout(safe_margins, viewport_size)


## Shows this overlay's root immediately (so the shell's own fade-in is actually visible), then
## starts the shell's animated fade. The root's own visible flag is what scripts/level.gd's
## `_leave_confirmation_overlay.visible` checks observe.
func open() -> void:
	show()
	_shell.open()


## Waits for the shell's fade-out before hiding the root -- hiding the root immediately would skip
## the fade entirely, since an invisible ancestor stops all descendant rendering regardless of the
## shell's own modulate/visible state.
func close() -> void:
	await _shell.close()
	hide()
