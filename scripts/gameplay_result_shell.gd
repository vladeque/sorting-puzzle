extends Control
class_name GameplayResultShell

## Shared terminal-result shell (UI-003) for a level's two end states, Completion and Failure. Owns
## the shared result shade, hero title role, action-button placement, safe-area layout, and
## open/close motion. Each owning scene keeps and positions its own state-specific content
## (Completion's star/earned-count, Failure's body copy) inside the content region this shell
## exposes -- shade/title/action/safe-area/motion are shared without merging that content. See
## docs/SCENES.md "Shared Gameplay UI Roles".

signal opened
signal closed

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")

const TITLE_SIZE := Vector2(720.0, 96.0)
const TITLE_TOP := 108.0
const ACTION_SIZE := Vector2(340.0, 124.0)
const ACTION_CENTER_Y := 850.0
const MIN_ACTION_BOTTOM_MARGIN := 118.0

@onready var _title_label := %TitleLabel as Label
@onready var _content_region := %ContentRegion as Control
@onready var _action_region := %ActionRegion as Control

var _is_transitioning := false


func _ready() -> void:
	_title_label.add_theme_font_size_override("font_size", GameplayUIThemeScript.RESULT_HERO_TITLE_SIZE)


func configure(title: String) -> void:
	_title_label.text = title


func get_content_region() -> Control:
	return _content_region


## The single CTA slot (Completion's Continue, Failure's Main Menu). The owning scene reparents its
## own button here and anchors it full-rect so it fills whatever size apply_safe_layout() computes.
func get_action_region() -> Control:
	return _action_region


## True while an open()/close() fade is in flight -- scripts/level.gd's ui_cancel chain and button
## handlers should ignore duplicate navigation input until this clears.
func is_transitioning() -> bool:
	return _is_transitioning


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var scale := GameplayUIThemeScript.get_result_title_scale(viewport_size)
	var center_x := viewport_size.x * 0.5
	var title_top := safe_margins.y + TITLE_TOP * scale
	_layout_centered(
		_title_label,
		Vector2(center_x, title_top + TITLE_SIZE.y * scale * 0.5),
		Vector2(maxf(viewport_size.x - safe_margins.x - safe_margins.z, 1.0), TITLE_SIZE.y * scale)
	)

	var action_center_y := minf(
		safe_margins.y + ACTION_CENTER_Y * scale,
		viewport_size.y - safe_margins.w - MIN_ACTION_BOTTOM_MARGIN * scale - ACTION_SIZE.y * scale * 0.5
	)
	_layout_centered(_action_region, Vector2(center_x, action_center_y), ACTION_SIZE * scale)


func _layout_centered(control: Control, center: Vector2, size: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = center.x - size.x * 0.5
	control.offset_top = center.y - size.y * 0.5
	control.offset_right = center.x + size.x * 0.5
	control.offset_bottom = center.y + size.y * 0.5


## Shows this shell immediately (so its own fade-in is actually visible), then fades in.
func open() -> void:
	show()
	_is_transitioning = true
	var tween := UIMotionScript.fade_in(self)
	await tween.finished
	_is_transitioning = false
	opened.emit()


## Fades out, then hides. A no-op if already hidden.
func close() -> void:
	if not visible:
		return

	_is_transitioning = true
	await UIMotionScript.close_with_fade(self, _finish_close)


func _finish_close() -> void:
	hide()
	_is_transitioning = false
	closed.emit()
