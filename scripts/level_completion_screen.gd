extends Control
class_name LevelCompletionScreen

## Reusable completed-level reward overlay instanced by level.tscn. Composes
## scenes/ui/gameplay_result_shell.tscn for the shared terminal shade, hero title, action
## placement, safe-area layout, and open/close motion (UI-003; see docs/SCENES.md "Shared Gameplay
## UI Roles"). Keeps its own star/earned-count positioning, which is state-specific and not shared
## with scripts/level_failure_screen.gd.

signal next_pressed

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")

const STAR_SIZE := Vector2(340, 340)
const STAR_CENTER_Y := 466.0
const STARS_LABEL_SIZE := Vector2(320, 84)
const STARS_LABEL_OFFSET_Y := 150.0

@onready var _shell := %Shell as GameplayResultShell
@onready var _star_image := %StarImage as TextureRect
@onready var _earned_stars_label := %EarnedStarsLabel as Label
@onready var _next_button := %NextButton as Button


func _ready() -> void:
	_shell.configure("GREAT JOB!")
	var content := _shell.get_content_region()
	_star_image.reparent(content, false)
	_earned_stars_label.reparent(content, false)

	var action := _shell.get_action_region()
	_next_button.reparent(action, false)
	_next_button.anchor_left = 0.0
	_next_button.anchor_top = 0.0
	_next_button.anchor_right = 1.0
	_next_button.anchor_bottom = 1.0
	_next_button.offset_left = 0.0
	_next_button.offset_top = 0.0
	_next_button.offset_right = 0.0
	_next_button.offset_bottom = 0.0
	_next_button.pressed.connect(_on_next_button_pressed)


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_shell.apply_safe_layout(safe_margins, viewport_size)

	# Star image/earned-count placement is Completion-specific and stays local rather than moving
	# into the shared shell (see docs/SCENES.md "Shared Gameplay UI Roles" -- shade/title/action/
	# safe-area/motion are shared; state-specific content is not).
	var scale := GameplayUIThemeScript.get_result_title_scale(viewport_size)
	var center_x := viewport_size.x * 0.5
	var star_center_y := safe_margins.y + STAR_CENTER_Y * scale
	_layout_centered_control(_star_image, Vector2(center_x, star_center_y), STAR_SIZE * scale)
	_layout_centered_control(
		_earned_stars_label,
		Vector2(center_x, star_center_y + STARS_LABEL_OFFSET_Y * scale),
		STARS_LABEL_SIZE * scale
	)


func set_earned_stars(stars: int) -> void:
	var earned_text := "×%d" % stars
	var font_size := 58
	if earned_text.length() >= 8:
		font_size = 42
	elif earned_text.length() >= 7:
		font_size = 48
	elif earned_text.length() >= 6:
		font_size = 52

	_earned_stars_label.add_theme_font_size_override("font_size", font_size)
	_earned_stars_label.text = earned_text


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
	if control == null:
		return

	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = center.x - size.x * 0.5
	control.offset_top = center.y - size.y * 0.5
	control.offset_right = center.x + size.x * 0.5
	control.offset_bottom = center.y + size.y * 0.5


func _on_next_button_pressed() -> void:
	next_pressed.emit()
