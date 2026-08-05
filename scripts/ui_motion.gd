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
## Presence of this key means "a close_with_fade() is in flight"; its value is a generation token
## that lets a stale, superseded close notice it was superseded (see close_with_fade()).
const _CLOSE_GENERATION_META := &"_ui_motion_close_generation"


## Fades `node` in from fully transparent to `target_alpha` (default opaque) over OVERLAY_DURATION,
## showing it first if it was hidden. Cancels any close_with_fade() still in flight for `node` (a
## reusable dialog can legitimately be re-shown before its previous close finished fading out), so
## that stale close never fires its finish callback against the freshly-reopened node. Returns the
## tween so callers can `await tween.finished` to sequence work after the fade, or ignore it.
static func fade_in(node: CanvasItem, duration: float = OVERLAY_DURATION, target_alpha: float = 1.0) -> Tween:
	if node.has_meta(_CLOSE_GENERATION_META):
		node.remove_meta(_CLOSE_GENERATION_META)
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
## restarting the fade or running `on_finished` twice.
##
## Waits out the fade on a plain timer rather than the fade tween's own `finished` signal, because
## fade_in() is allowed to kill that tween mid-flight (see above) -- a killed tween never emits
## `finished`, which would otherwise strand this coroutine (and its "closing" guard) forever. A
## generation token detects that supersession on the way out: if `node` was re-shown (or asked to
## close again) while this call was waiting, its token no longer matches and this stale call quietly
## does nothing instead of hiding/freeing a node someone else already reopened.
static func close_with_fade(node: CanvasItem, on_finished: Callable, duration: float = OVERLAY_DURATION) -> void:
	if node.has_meta(_CLOSE_GENERATION_META):
		return

	var my_generation := int(node.get_meta(_CLOSE_GENERATION_META, 0)) + 1
	node.set_meta(_CLOSE_GENERATION_META, my_generation)
	fade_out(node, duration)
	await node.get_tree().create_timer(duration).timeout
	if int(node.get_meta(_CLOSE_GENERATION_META, -1)) != my_generation:
		return

	node.remove_meta(_CLOSE_GENERATION_META)
	on_finished.call()


## Kills whichever tween this exact (node, meta_key) pair last started, if it is still running, and
## returns a freshly created tween tagged the same way -- so callers never accumulate competing
## tweens on the same property across rapid repeated triggers (nav icon moves, status pulses, fades,
## ...). Use a distinct `meta_key` per independent concern when a single node needs more than one
## concurrently-running animation (for example a fade and a move).
static func retween(node: Node, meta_key: StringName) -> Tween:
	stop_tween(node, meta_key)
	var tween := node.create_tween()
	node.set_meta(meta_key, tween)
	return tween


## Kills whichever tween this exact (node, meta_key) pair last started, if it is still running, and
## clears the tracking meta, without starting a replacement. Use to explicitly stop a looping or
## in-flight animation created via retween() -- for example the shared status panel's loading pulse
## when the status becomes hidden or leaves the tree.
static func stop_tween(node: Node, meta_key: StringName) -> void:
	if not node.has_meta(meta_key):
		return

	var tracked_tween: Tween = node.get_meta(meta_key)
	if tracked_tween != null and tracked_tween.is_valid():
		tracked_tween.kill()
	node.remove_meta(meta_key)
