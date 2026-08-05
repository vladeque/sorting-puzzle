extends Button
class_name PressScaleButton

## Shared press-feedback owner for every interactive role in the UI-002 interaction system (see
## docs/UI_002_INTERACTION_MOTION_TICKET.md and the "Shared Interaction Roles" section of
## docs/SCENES.md).
##
## By default this animates the button's own scale, matching every pre-UI-002 consumer where the
## whole button IS the visual (Main Menu Play, Chapter CTA, Settings, Shop purchase buttons, ...).
## Set `visual_target_path` to a sibling/child Control instead so an invisible or full-rect hit
## target (Profile, Reward Chest, bottom-navigation icons, Shop ability info cells, ...) can shrink
## a designated visual child on press without shrinking or moving its own clickable rect -- the
## Button's own size and touch rectangle never change in that case.
##
## Always restores the released scale -- with no animation, since nothing should look "successful"
## -- when disabled while held, hidden, exiting the tree, or when the application loses focus
## (backgrounded mid-press). A normal release, including release outside the button (Godot's
## `button_up` fires the same whether the pointer let go inside or outside), animates back over
## UIMotion.RELEASE_DURATION. Any in-flight scale tween is always killed before starting another,
## so rapid repeated presses never accumulate scale.

const UIMotionScript := preload("res://scripts/ui_motion.gd")

@export var visual_target_path: NodePath = ^""
@export_range(0.85, 1.0, 0.01) var held_scale := 0.94

var _visual: Control
var _released_scale := Vector2.ONE
var _is_held := false
var _scale_tween: Tween


func _ready() -> void:
	_visual = self
	if not visual_target_path.is_empty():
		var resolved := get_node_or_null(visual_target_path)
		if resolved is Control:
			_visual = resolved as Control

	_released_scale = _visual.scale
	_update_pivot_offset()
	set_process(false)
	button_down.connect(_apply_held_scale)
	button_up.connect(_restore_released_scale)
	visibility_changed.connect(_on_visibility_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_snap_released_scale()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# The app was backgrounded mid-press (or lost window focus during desktop testing); there
		# is no pointer left to release the button, so drop the held state immediately.
		_snap_released_scale()


## Catches disabling this button while a press is already in progress -- Button.set_disabled()
## silently clears the engine's own internal press state without emitting `button_up`, so nothing
## else observes that transition. Only runs while actually held (see _apply_held_scale()/
## _restore_released_scale()), so the cost is a few frames per press, never while idle.
func _process(_delta: float) -> void:
	if disabled:
		_snap_released_scale()


func _apply_held_scale() -> void:
	if disabled:
		return

	_is_held = true
	set_process(true)
	_animate_to(_released_scale * held_scale, UIMotionScript.PRESS_IN_DURATION)


func _restore_released_scale() -> void:
	if not _is_held:
		return

	_is_held = false
	set_process(false)
	_animate_to(_released_scale, UIMotionScript.RELEASE_DURATION)


func _on_visibility_changed() -> void:
	if not visible:
		_snap_released_scale()


## Immediately cancels any held state with no animation -- used whenever the button stops being a
## legitimate ongoing press (disabled, hidden, exiting the tree, app backgrounded) rather than a
## normal release, matching "disabled controls must not ... animate".
func _snap_released_scale() -> void:
	_is_held = false
	set_process(false)
	_kill_scale_tween()
	if is_instance_valid(_visual):
		_visual.scale = _released_scale


func _animate_to(target_scale: Vector2, duration: float) -> void:
	_kill_scale_tween()
	if not is_instance_valid(_visual):
		return

	_update_pivot_offset()
	if not is_inside_tree():
		_visual.scale = target_scale
		return

	_scale_tween = create_tween()
	_scale_tween.tween_property(_visual, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _kill_scale_tween() -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = null


func _update_pivot_offset() -> void:
	if is_instance_valid(_visual):
		_visual.pivot_offset = _visual.size * 0.5
