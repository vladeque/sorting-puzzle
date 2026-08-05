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

const _FADE_TWEEN_META := &"_ui_motion_fade_tween"
const _CLOSING_META := &"_ui_motion_closing"


## Fades `node` in from fully transparent to `target_alpha` (default opaque) over OVERLAY_DURATION,
## showing it first if it was hidden. Returns the tween so callers can `await tween.finished` to
## sequence work after the fade, or ignore it.
static func fade_in(node: CanvasItem, duration: float = OVERLAY_DURATION, target_alpha: float = 1.0) -> Tween:
	node.modulate.a = 0.0
	node.show()
	var tween := retween(node, _FADE_TWEEN_META)
	tween.tween_property(node, "modulate:a", target_alpha, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## Fades `node` out to fully transparent over OVERLAY_DURATION. Does not hide/free `node` --
## callers should `await tween.finished` and then hide()/queue_free() it themselves.
static func fade_out(node: CanvasItem, duration: float = OVERLAY_DURATION) -> Tween:
	var tween := retween(node, _FADE_TWEEN_META)
	tween.tween_property(node, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tween


## Fades `node` out and then calls `on_finished` (typically `node.queue_free` or `node.hide`) once.
## Safe to call more than once while already closing -- a repeat call (the Close button pressed
## twice, or `ui_cancel` arriving while a press already started closing it) is ignored rather than
## restarting the fade or running `on_finished` twice. The guard clears once the fade completes, so
## a reusable node (a dialog shown/hidden repeatedly rather than freed) closes normally next time.
static func close_with_fade(node: CanvasItem, on_finished: Callable, duration: float = OVERLAY_DURATION) -> void:
	if node.has_meta(_CLOSING_META) and bool(node.get_meta(_CLOSING_META)):
		return

	node.set_meta(_CLOSING_META, true)
	await fade_out(node, duration).finished
	node.remove_meta(_CLOSING_META)
	on_finished.call()


## Kills whichever tween this exact (node, meta_key) pair last started, if it is still running, and
## returns a freshly created tween tagged the same way -- so callers never accumulate competing
## tweens on the same property across rapid repeated triggers (nav icon moves, status pulses, fades,
## ...). Use a distinct `meta_key` per independent concern when a single node needs more than one
## concurrently-running animation (for example a fade and a move).
static func retween(node: Node, meta_key: StringName) -> Tween:
	if node.has_meta(meta_key):
		var previous_tween: Tween = node.get_meta(meta_key)
		if previous_tween != null and previous_tween.is_valid():
			previous_tween.kill()

	var tween := node.create_tween()
	node.set_meta(meta_key, tween)
	return tween
