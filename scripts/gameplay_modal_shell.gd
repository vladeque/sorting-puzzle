extends Control
class_name GameplayModalShell

## Shared gameplay modal shell (UI-003): fullscreen shade + input blocker, safe-area-fitted
## centered outer panel, title region (regular/long variant), true-circular close action, cream
## content region, and a bottom action row. Pause, Leave Confirmation, and Ability Purchase each
## instance this as their first child and compose their own content/actions into the slots below
## instead of repeating shade/panel/close-button styling locally. See docs/SCENES.md's "Shared
## Gameplay UI Roles" section.
##
## Ownership split (matches the project's destination_screen_shell.tscn precedent): this shell owns
## presentation, safe-area fitting, and open/close motion. The owning scene's own script owns its
## content, signals, and gameplay data -- `scripts/level.gd` only sets data, shows/hides through
## open()/close(), and listens for signals.

signal close_requested
signal opened
signal closed

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const CONTENT_REGION_TOP := 116.0
const POP_START_SCALE := 0.90
const POP_OVERSHOOT_SCALE := 1.02
const POP_RISE_SECONDS := 0.22
const POP_SETTLE_SECONDS := 0.12

@onready var _outer_panel := %OuterPanel as Control
@onready var _title_label := %TitleLabel as Label
@onready var _close_button := %CloseButton as Button
@onready var _content_region := %ContentRegion as Control
@onready var _action_row := %ActionRow as Control

var _preferred_size := Vector2(
	GameplayUIThemeScript.MODAL_MAX_WIDTH,
	GameplayUIThemeScript.MODAL_COMPACT_HEIGHT
)
var _is_transitioning := false


func _ready() -> void:
	_close_button.pressed.connect(func() -> void: close_requested.emit())


## Sets the title text and selects the regular/long modal-title typography role.
func configure(title: String, is_long_title: bool = false) -> void:
	_title_label.text = title
	_title_label.add_theme_font_size_override(
		"font_size",
		GameplayUIThemeScript.MODAL_TITLE_LONG_SIZE if is_long_title else GameplayUIThemeScript.MODAL_TITLE_REGULAR_SIZE
	)


## Sets the panel's preferred (unclamped) size; apply_safe_layout() fits it within safe bounds.
func set_preferred_size(size: Vector2) -> void:
	_preferred_size = size


## Gives each modal a compact authored content height without stretching the cream panel when an
## owner needs a different outer-panel height. The whole shell is still uniformly safe-area scaled.
func set_content_region_height(height: float) -> void:
	_content_region.anchor_top = 0.0
	_content_region.anchor_bottom = 0.0
	_content_region.offset_top = CONTENT_REGION_TOP
	_content_region.offset_bottom = CONTENT_REGION_TOP + maxf(height, 1.0)
	_content_region.grow_vertical = Control.GROW_DIRECTION_END


func get_content_region() -> Control:
	return _content_region


func get_action_row() -> Control:
	return _action_row


## Hides the cream content region for modals that only need a title and action row.
func hide_content_region() -> void:
	_content_region.visible = false


## True while an open()/close() fade is in flight. Callers (scripts/level.gd's button handlers and
## its ui_cancel chain) should ignore duplicate navigation input until this clears.
func is_transitioning() -> bool:
	return _is_transitioning


## Fits and centers the outer panel within the safe content rect. Safe to call every time the
## viewport changes size, matching every other responsive-layout owner in this project.
func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var fitted_size := GameplayUIThemeScript.fit_outer_panel_size(
		_preferred_size,
		safe_margins,
		viewport_size
	)
	# Keep the authored panel/content/action geometry intact and uniformly scale the whole subtree.
	# Resizing only OuterPanel lets Container minimum sizes spill fixed children back outside the safe
	# rect. Scaling the composed panel makes the shell, title, close cutout, content, and actions obey
	# the same fit while preserving their relative shapes.
	var fit_scale := minf(
		fitted_size.x / maxf(_preferred_size.x, 1.0),
		fitted_size.y / maxf(_preferred_size.y, 1.0)
	)
	fit_scale = minf(fit_scale, 1.0)
	var safe_size := Vector2(
		maxf(viewport_size.x - safe_margins.x - safe_margins.z, 1.0),
		maxf(viewport_size.y - safe_margins.y - safe_margins.w, 1.0)
	)
	var safe_center := Vector2(
		safe_margins.x + safe_size.x * 0.5,
		safe_margins.y + safe_size.y * 0.5
	)
	_outer_panel.anchor_left = 0.0
	_outer_panel.anchor_top = 0.0
	_outer_panel.anchor_right = 0.0
	_outer_panel.anchor_bottom = 0.0
	_outer_panel.offset_left = safe_center.x - _preferred_size.x * 0.5
	_outer_panel.offset_top = safe_center.y - _preferred_size.y * 0.5
	_outer_panel.offset_right = safe_center.x + _preferred_size.x * 0.5
	_outer_panel.offset_bottom = safe_center.y + _preferred_size.y * 0.5
	_outer_panel.pivot_offset = _preferred_size * 0.5
	_outer_panel.scale = Vector2.ONE * fit_scale


## Fades the shell in. `with_pop` adds a 90% -> 102% -> 100% panel settle for result-like reveals
## while preserving the fitted responsive scale calculated by apply_safe_layout(). Cancels an
## in-flight close() first (UIMotion.fade_in() cancels it), so re-opening mid-close never strands
## the old close coroutine.
func open(with_pop := false) -> void:
	_is_transitioning = true
	if with_pop:
		var fitted_scale := _outer_panel.scale
		_outer_panel.scale = fitted_scale * POP_START_SCALE
		UIMotionScript.fade_in(
			self,
			POP_RISE_SECONDS + POP_SETTLE_SECONDS
		)
		var pop_tween := create_tween()
		pop_tween.tween_property(
			_outer_panel,
			"scale",
			fitted_scale * POP_OVERSHOOT_SCALE,
			POP_RISE_SECONDS
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(
			_outer_panel,
			"scale",
			fitted_scale,
			POP_SETTLE_SECONDS
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await pop_tween.finished
	else:
		var tween := UIMotionScript.fade_in(self)
		await tween.finished
	_is_transitioning = false
	opened.emit()


## Fades the shell out, then hides it. A no-op if already hidden. A repeat call while already
## closing is ignored by UIMotion.close_with_fade()'s own generation-token guard.
func close() -> void:
	if not visible:
		return

	_is_transitioning = true
	await UIMotionScript.close_with_fade(self, _finish_close)


func _finish_close() -> void:
	hide()
	_is_transitioning = false
	closed.emit()
