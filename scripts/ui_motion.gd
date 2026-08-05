class_name UIMotion
extends RefCounted

## Shared motion tokens and small tween helpers for the Main Menu / Shop / Leaderboard / Chapter
## Selection interaction system (UI-002, see docs/UI_002_INTERACTION_MOTION_TICKET.md's "Establish
## Motion Tokens" section and docs/SCENES.md's "Shared Interaction Roles"). Consumers preload this
## script (matching the project convention used by scripts/destination_screen_layout.gd and
## scripts/chapters/menu_background_resolver.gd) and call its static consts/funcs directly -- no
## instance needed.
##
## The chapter pager's ~320ms quadratic-ease-out snap (scripts/horizontal_pager.gd) is an existing,
## already-compliant value kept local to that script rather than duplicated here.

const PRESS_IN_DURATION := 0.09
const RELEASE_DURATION := 0.12
const NAV_ACTIVE_CHANGE_DURATION := 0.165
const OVERLAY_DURATION := 0.2


## Fades `node` in from fully transparent to `target_alpha` (default opaque) over OVERLAY_DURATION,
## showing it first if it was hidden. Kills any tween already animating `node`'s modulate so rapid
## open/close never accumulates competing tweens. Returns the tween so callers can
## `await tween.finished` to sequence work after the fade, or ignore it.
static func fade_in(node: CanvasItem, duration: float = OVERLAY_DURATION, target_alpha: float = 1.0) -> Tween:
	_kill_modulate_tween(node)
	node.modulate.a = 0.0
	node.show()
	var tween := node.create_tween()
	node.set_meta(&"_ui_motion_tween", tween)
	tween.tween_property(node, "modulate:a", target_alpha, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## Fades `node` out to fully transparent over OVERLAY_DURATION. Does not hide/free `node` --
## callers should `await tween.finished` and then hide()/queue_free() it themselves.
static func fade_out(node: CanvasItem, duration: float = OVERLAY_DURATION) -> Tween:
	_kill_modulate_tween(node)
	var tween := node.create_tween()
	node.set_meta(&"_ui_motion_tween", tween)
	tween.tween_property(node, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tween


static func _kill_modulate_tween(node: CanvasItem) -> void:
	if not node.has_meta(&"_ui_motion_tween"):
		return
	var previous_tween: Tween = node.get_meta(&"_ui_motion_tween")
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	node.remove_meta(&"_ui_motion_tween")
