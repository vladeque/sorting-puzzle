extends SceneTree

## UI-003 level UI consistency verification: shared gameplay resource identity, explicit disabled
## styles (no engine-default fallback), the star pill's receive pulse leaving its chrome alone, the
## Completion/Failure signal routing and copy, the
## ui_cancel back-stack precedence, safe-area layout at fabricated insets, responsive ability-bar
## icon/badge bounds, long-value formatting, the hidden rewarded-ad placeholder, and locked-shelf
## chain/count/unlock feedback. See docs/UI_003_LEVEL_UI_CONSISTENCY_TICKET.md and docs/SCENES.md's
## "Shared Gameplay UI Roles" section.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

var _failures: Array[String] = []

## Loaded at runtime inside _run() rather than preloaded at the class level (matching
## tests/ui/test_interaction_motion.gd): level.tscn and its sub-scenes transitively compile scripts
## that reference the PlayerProgress/ChapterCatalog autoload globals, which do not exist yet while
## this main-loop script itself is still being compiled.
var _level_scene: PackedScene
var _pause_menu_scene: PackedScene
var _leave_confirmation_scene: PackedScene
var _ability_purchase_scene: PackedScene
var _main_menu_top_status_scene: PackedScene


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Level UI consistency verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_level_scene = load("res://level.tscn") as PackedScene
	_pause_menu_scene = load("res://scenes/pause_menu.tscn") as PackedScene
	_leave_confirmation_scene = load("res://scenes/leave_confirmation_menu.tscn") as PackedScene
	_ability_purchase_scene = load("res://scenes/ability_purchase_menu.tscn") as PackedScene
	_main_menu_top_status_scene = load("res://scenes/ui/main_menu_top_status.tscn") as PackedScene

	await _test_shared_resource_identity()
	await _test_explicit_disabled_styles()
	await _test_star_receive_pulse_keeps_pill_chrome()
	await _test_focus_and_cursor_policy()
	await _test_rewarded_ad_placeholder()
	await _test_completion_and_failure_routing()
	await _test_ui_cancel_chain()
	await _test_modal_transition_interruption()
	await _test_safe_area_layout()
	await _test_ability_bar_responsive_bounds()
	await _test_long_value_formatting()
	await _test_locked_shelf_feedback()

	# Let any still-in-flight tween/timer from the phases above drain naturally before quitting.
	await _wait_frames(60)

	if _failures.is_empty():
		print("Level UI consistency verification passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


## Pause, Leave Confirmation, and Ability Purchase must consume the same modal shell/resources
## rather than local copies -- checked as literal Resource identity (===), the same pattern
## scripts/tools/verify_shop.gd already uses for the Shop/Leaderboard Retry style.
func _test_shared_resource_identity() -> void:
	var pause := _pause_menu_scene.instantiate()
	var leave := _leave_confirmation_scene.instantiate()
	var purchase := _ability_purchase_scene.instantiate()
	root.add_child(pause)
	root.add_child(leave)
	root.add_child(purchase)
	await process_frame

	var pause_outer := pause.find_child("OuterPanel", true, false) as Panel
	var leave_outer := leave.find_child("OuterPanel", true, false) as Panel
	var purchase_outer := purchase.find_child("OuterPanel", true, false) as Panel
	_check(
		pause_outer.get_theme_stylebox("panel") == leave_outer.get_theme_stylebox("panel")
			and leave_outer.get_theme_stylebox("panel") == purchase_outer.get_theme_stylebox("panel"),
		"Pause/Leave Confirmation/Ability Purchase should share one modal outer-panel StyleBox instance."
	)

	var pause_close := pause.find_child("CloseButton", true, false) as Button
	var leave_close := leave.find_child("CloseButton", true, false) as Button
	var purchase_close := purchase.find_child("CloseButton", true, false) as Button
	_check(
		pause_close.get_theme_stylebox("normal") == leave_close.get_theme_stylebox("normal")
			and leave_close.get_theme_stylebox("normal") == purchase_close.get_theme_stylebox("normal"),
		"Pause/Leave Confirmation/Ability Purchase should share one close-button StyleBox instance."
	)

	var pause_shade := pause.find_child("Shade", true, false) as Panel
	var leave_shade := leave.find_child("Shade", true, false) as Panel
	_check(
		pause_shade.get_theme_stylebox("panel") == leave_shade.get_theme_stylebox("panel"),
		"Pause/Leave Confirmation should share one modal-shade StyleBox instance."
	)
	var pause_content := pause.find_child("ContentRegion", true, false) as Control
	var leave_content := leave.find_child("ContentRegion", true, false) as Control
	var purchase_content := purchase.find_child("ContentRegion", true, false) as Control
	_check(
		pause_outer.size.is_equal_approx(Vector2(520.0, 500.0))
			and leave_outer.size.is_equal_approx(pause_outer.size)
			and purchase_outer.size.is_equal_approx(pause_outer.size),
		"All gameplay modals should use the same compact 520x500 outer-panel size."
	)
	_check(
		is_equal_approx(pause_content.size.y, 224.0)
			and is_equal_approx(leave_content.size.y, 240.0)
			and is_equal_approx(purchase_content.size.y, 224.0),
		"Gameplay modal cream panels should use compact content-specific heights, not stretch with the shell."
	)
	_check(
		purchase.find_child("UseNowLabel", true, false) == null,
		"Ability Purchase should not show the redundant USE NOW badge."
	)

	pause.queue_free()
	leave.queue_free()
	purchase.queue_free()
	await process_frame

	var main_menu_top_status := _main_menu_top_status_scene.instantiate()
	root.add_child(main_menu_top_status)
	await process_frame
	var settings_button := main_menu_top_status.find_child("SettingsButton", true, false) as Button

	var level := await _make_level()
	var top_hud = level.get("_top_hud")
	var pause_button := top_hud.find_child("PauseButton", true, false) as Button
	_check(
		pause_button.get_theme_stylebox("normal") == settings_button.get_theme_stylebox("normal")
			and pause_button.get_theme_stylebox("pressed") == settings_button.get_theme_stylebox("pressed")
			and pause_button.get_theme_stylebox("hover") == settings_button.get_theme_stylebox("hover"),
		"The Pause button should consume the Main Menu settings button's warm style resources."
	)
	_check(
		pause_button.get_theme_stylebox("disabled") == settings_button.get_theme_stylebox("normal"),
		"Disabled Pause should retain the warm settings-button shape instead of falling back to a default."
	)
	_check(
		pause_button.size.is_equal_approx(Vector2(72.0, 64.0)),
		"The Pause button should match the Main Menu settings button's 72x64 size."
	)
	_check(
		is_equal_approx(float(pause_button.get("held_scale")), float(settings_button.get("held_scale")))
			and pause_button.get_theme_color("font_color") == settings_button.get_theme_color("font_color"),
		"Pause should match the Main Menu settings button's held behavior and dark glyph color."
	)
	main_menu_top_status.queue_free()

	var completion_screen = level.get("_completion_screen")
	var completion_shade_panel := completion_screen.find_child("ResultShade", true, false) as Panel
	var completion_button := completion_screen.find_child("NextButton", true, false) as Button
	# Read the shared StyleBox resource itself (not the node) before freeing -- the resource is an
	# independent external object and stays valid after its consuming node is gone, but the node
	# reference itself would dangle.
	var completion_shade_style := completion_shade_panel.get_theme_stylebox("panel")
	var completion_action_style := completion_button.get_theme_stylebox("normal")
	level.free()

	var failure_level := await _make_level()
	var failure_shade_panel := failure_level.get("_failure_screen").find_child("ResultShade", true, false) as Panel
	_check(
		completion_shade_style == failure_shade_panel.get_theme_stylebox("panel"),
		"Completion and Failure should share one terminal-result shade StyleBox instance."
	)
	var failure_button := failure_level.get("_failure_screen").find_child("MainMenuButton", true, false) as Button
	_check(
		completion_action_style == failure_button.get_theme_stylebox("normal"),
		"Completion and Failure should consume the same positive-action StyleBox instance."
	)
	failure_level.free()


## No level-owned button may fall back to a Godot engine-default when disabled -- opening any overlay
## used to visibly turn the circular Pause button into a square because it had no disabled StyleBox
## at all, and Pause's "II" glyph later washed out to the engine's pale default because only the
## normal/pressed/hover font colors were authored.
func _test_explicit_disabled_styles() -> void:
	var level := await _make_level()
	var top_hud = level.get("_top_hud")
	var ability_bar = level.get("_ability_bar")

	var pause_button := top_hud.find_child("PauseButton", true, false) as Button
	_check(pause_button.get_theme_stylebox("disabled") != null, "Pause button must have an explicit disabled style.")
	# Pause is disabled for the whole completion celebration, where the frozen board leaves it in
	# plain sight rather than behind an overlay.
	_check(
		pause_button.get_theme_color("font_disabled_color")
			== pause_button.get_theme_color("font_color"),
		"A disabled Pause button must keep its dark glyph instead of the engine's pale default."
	)

	for button_name in ["HammerButton", "ShuffleButton", "HighlightButton", "FreezerButton"]:
		var button := ability_bar.find_child(button_name, true, false) as Button
		_check(button.get_theme_stylebox("disabled") != null, "%s must have an explicit disabled style." % button_name)

	level.free()


## The star pill's receive pulse must never scale the pill itself. Its StyleBoxFlat carries a 2px
## gold border and a 6px drop shadow, and the count is rasterized text, so a scaled pill visibly
## thickens its own chrome and blurs its number -- most obviously during the completion celebration,
## when the level-clearing combo's stars land over the frozen board. Only the star icon, which is
## drawn straight from its texture, may scale.
func _test_star_receive_pulse_keeps_pill_chrome() -> void:
	var level := await _make_level()
	var top_hud = level.get("_top_hud")
	var star_counter := top_hud.find_child("StarCounter", true, false) as Control
	var star_icon := star_counter.get_node("Icon") as Control

	# Stepped by hand rather than sampled against the clock: a single slow frame in a headless run
	# can swallow the whole 0.2s pulse, which would make a timed sample flaky.
	top_hud.call("play_star_receive_pulse")
	var pulse_tween: Tween = top_hud.get("_star_pulse_tween")
	pulse_tween.pause()
	pulse_tween.custom_step(0.05)
	_check(
		star_counter.scale.is_equal_approx(Vector2.ONE),
		"The star pill must not scale during its receive pulse."
	)
	_check(
		star_icon.scale.x > 1.0 and star_icon.scale.y > 1.0,
		"The star icon should carry the receive pulse instead."
	)

	pulse_tween.custom_step(1.0)
	_check(
		star_icon.scale.is_equal_approx(Vector2.ONE),
		"The receive pulse should settle the star icon back to its authored scale."
	)

	top_hud.call("play_star_receive_pulse")
	var interrupted_tween: Tween = top_hud.get("_star_pulse_tween")
	interrupted_tween.pause()
	interrupted_tween.custom_step(0.05)
	top_hud.call("reset_star_pulse")
	_check(
		star_icon.scale.is_equal_approx(Vector2.ONE)
			and star_counter.scale.is_equal_approx(Vector2.ONE),
		"Resetting the pulse on level restart should clear a mid-flight icon scale."
	)

	level.free()


## Every level-owned button stays FOCUS_NONE (documented touch-only policy, matching the rest of the
## project) with the pointing-hand cursor while enabled.
func _test_focus_and_cursor_policy() -> void:
	var level := await _make_level()
	var top_hud = level.get("_top_hud")
	var ability_bar = level.get("_ability_bar")
	var pause_overlay = level.get("_pause_menu_overlay")

	var pause_button := top_hud.find_child("PauseButton", true, false) as Button
	_check(pause_button.focus_mode == Control.FOCUS_NONE, "Pause button should be FOCUS_NONE.")
	_check(
		pause_button.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
		"Pause button should use the pointing-hand cursor."
	)
	top_hud.call("set_pause_enabled", false)
	_check(
		pause_button.mouse_default_cursor_shape == Control.CURSOR_ARROW,
		"A disabled Pause button should restore the arrow cursor."
	)
	top_hud.call("set_pause_enabled", true)

	for button_name in ["HammerButton", "ShuffleButton", "HighlightButton", "FreezerButton"]:
		var button := ability_bar.find_child(button_name, true, false) as Button
		_check(button.focus_mode == Control.FOCUS_NONE, "%s should be FOCUS_NONE." % button_name)
		_check(
			button.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"%s should use the pointing-hand cursor." % button_name
		)

	ability_bar.call("set_interaction_blocked", true, false)
	for button_name in ["HammerButton", "ShuffleButton", "HighlightButton", "FreezerButton"]:
		var disabled_button := ability_bar.find_child(button_name, true, false) as Button
		_check(
			disabled_button.mouse_default_cursor_shape == Control.CURSOR_ARROW,
			"A disabled %s should restore the arrow cursor." % button_name
		)
	ability_bar.call("set_interaction_blocked", false, false)

	var close_button := pause_overlay.find_child("CloseButton", true, false) as Button
	_check(close_button.focus_mode == Control.FOCUS_NONE, "Modal close button should be FOCUS_NONE.")
	_check(
		close_button.get_script() != null,
		"Modal close button should use PressScaleButton for held feedback."
	)

	level.free()


## The rewarded-ad placeholder must never be an enabled no-op, in any build. It hides entirely
## outside a debug build and stays disabled with "Coming Soon" copy inside one.
func _test_rewarded_ad_placeholder() -> void:
	var purchase := _ability_purchase_scene.instantiate()
	root.add_child(purchase)
	await process_frame

	var watch_ad_button := purchase.find_child("WatchAdButton", true, false) as Button
	_check(watch_ad_button.disabled, "WatchAdButton must never be enabled -- no enabled no-op in any build.")
	_check(
		watch_ad_button.visible == OS.is_debug_build(),
		"WatchAdButton visibility should exactly follow OS.is_debug_build() (hidden in production)."
	)
	if watch_ad_button.visible:
		_check(watch_ad_button.text == "Coming Soon", "A visible dev-preview WatchAdButton should read Coming Soon.")

	purchase.queue_free()
	await process_frame


## Completion's action reads "Continue" (same return-to-menu behavior); Failure has a working exit
## instead of being a terminal dead end. Both route through their documented signal.
func _test_completion_and_failure_routing() -> void:
	var level := await _make_level()
	var completion = level.get("_completion_screen")
	var next_button := completion.find_child("NextButton", true, false) as Button
	_check(next_button.text == "Continue", "Completion's action should read Continue, not Next.")

	# A single-element Array, not a raw bool, because GDScript lambda captures snapshot primitive
	# locals by value -- mutating a captured bool inside the lambda would not be observable here.
	var completion_signal_fired := [false]
	completion.next_pressed.connect(func() -> void: completion_signal_fired[0] = true)
	next_button.pressed.emit()
	_check(completion_signal_fired[0], "Pressing Completion's action should emit next_pressed.")
	level.free()

	var failure_level := await _make_level()
	var failure = failure_level.get("_failure_screen")
	var main_menu_button := failure.find_child("MainMenuButton", true, false) as Button
	_check(main_menu_button.text == "Main Menu", "Failure should expose a working Main Menu action.")

	var failure_signal_fired := [false]
	failure.main_menu_pressed.connect(func() -> void: failure_signal_fired[0] = true)
	main_menu_button.pressed.emit()
	_check(failure_signal_fired[0], "Pressing Failure's action should emit main_menu_pressed.")
	failure_level.free()


## The full ui_cancel precedence chain: in-level Shop -> Ability Purchase, Leave Confirmation ->
## Pause -> resume; Ability Purchase restores its prior state; Completion/Failure invoke their
## routes; an in-flight transition drops the press instead of double-navigating.
func _test_ui_cancel_chain() -> void:
	var gameplay_level := await _make_level()
	gameplay_level.call("_unhandled_input", _make_ui_cancel_event())
	await _wait_seconds(0.35)
	_check(
		bool(gameplay_level.get("_pause_menu_overlay").visible),
		"ui_cancel during active gameplay should open Pause."
	)

	gameplay_level.call("_unhandled_input", _make_ui_cancel_event())
	await _wait_seconds(0.35)
	_check(
		not bool(gameplay_level.get("_pause_menu_overlay").visible)
			and not bool(gameplay_level.get("_level_paused")),
		"ui_cancel on Pause should resume gameplay."
	)
	gameplay_level.free()

	var stack_level := await _make_level()
	stack_level.call("_open_pause_menu")
	await _wait_seconds(0.35)
	stack_level.call("_on_pause_menu_leave_pressed")
	await _wait_seconds(0.35)
	stack_level.call("_unhandled_input", _make_ui_cancel_event())
	await _wait_seconds(0.35)
	_check(
		not bool(stack_level.get("_leave_confirmation_overlay").visible)
			and bool(stack_level.get("_pause_menu_overlay").visible),
		"ui_cancel on Leave Confirmation should return to Pause, not resume gameplay directly."
	)

	stack_level.call("_open_ability_purchase_menu", &"hammer")
	await _wait_seconds(0.35)
	stack_level.call("_open_in_level_shop")
	await _wait_seconds(0.35)
	stack_level.call("_unhandled_input", _make_ui_cancel_event())
	await _wait_seconds(0.35)
	_check(
		not bool(stack_level.get("_in_level_shop_overlay").visible)
			and bool(stack_level.get("_ability_purchase_overlay").visible)
			and not bool(stack_level.get("_pause_menu_overlay").visible),
		"ui_cancel on the in-level Shop should return to Ability Purchase first."
	)

	stack_level.call("_unhandled_input", _make_ui_cancel_event())
	await _wait_seconds(0.35)
	_check(
		not bool(stack_level.get("_ability_purchase_overlay").visible)
			and bool(stack_level.get("_pause_menu_overlay").visible),
		"ui_cancel on Ability Purchase opened from Pause should restore Pause, not resume gameplay."
	)

	# In-flight transition: a second ui_cancel arriving before open() finishes must be dropped.
	stack_level.call("_close_pause_menu")
	await _wait_seconds(0.35)
	stack_level.call("_open_pause_menu")
	stack_level.call("_unhandled_input", _make_ui_cancel_event())
	await _wait_seconds(0.35)
	_check(
		bool(stack_level.get("_pause_menu_overlay").visible),
		"ui_cancel during an in-flight open() transition must be dropped, not double-toggle."
	)
	stack_level.free()

	var completion_level := await _make_level()
	completion_level.call("_complete_level")
	await _wait_seconds(0.35)
	var completion_tree := completion_level.get_tree()
	completion_level.call("_unhandled_input", _make_ui_cancel_event())
	await _wait_seconds(0.2)
	_check(
		completion_tree.current_scene != completion_level,
		"ui_cancel on Completion should invoke its Continue route."
	)

	var failure_level := await _make_level()
	failure_level.call("_fail_level")
	await _wait_seconds(0.35)
	var failure_tree := failure_level.get_tree()
	failure_level.call("_unhandled_input", _make_ui_cancel_event())
	await _wait_seconds(0.2)
	_check(
		failure_tree.current_scene != failure_level,
		"ui_cancel on Failure should invoke its Main Menu route."
	)


## Visible modal controls must be inert during an open/close fade, and a stale owner close must not
## hide a root that has been reopened before that close's timer finishes.
func _test_modal_transition_interruption() -> void:
	var level := await _make_level()
	var pause_overlay = level.get("_pause_menu_overlay")
	var leave_overlay = level.get("_leave_confirmation_overlay")

	level.call("_open_pause_menu")
	await _wait_seconds(0.3)
	level.call("_on_pause_menu_leave_pressed")
	await _wait_seconds(0.05)
	level.call("_on_leave_confirmation_close_pressed")
	await _wait_seconds(0.3)
	_check(
		leave_overlay.visible and not pause_overlay.visible and bool(level.get("_level_paused")),
		"A close tap during Leave Confirmation's opening fade should be dropped without losing the modal."
	)

	level.call("_on_leave_confirmation_close_pressed")
	await _wait_seconds(0.3)
	_check(
		pause_overlay.visible and not leave_overlay.visible and bool(level.get("_level_paused")),
		"Closing a stable Leave Confirmation should return to a visible Pause overlay."
	)

	pause_overlay.close()
	await _wait_seconds(0.05)
	pause_overlay.open()
	await _wait_seconds(0.3)
	_check(
		pause_overlay.visible and pause_overlay.find_child("Shell", true, false).visible,
		"A superseded Pause close coroutine must not hide the freshly reopened owner root."
	)
	level.free()


## Safe-area insets (top/side/bottom) must keep the HUD strip, timer/level/star/pause cluster, and
## modal outer panel within bounds instead of sliding under a notch or overflowing a tight viewport.
func _test_safe_area_layout() -> void:
	var level := await _make_level()
	var top_hud = level.get("_top_hud")
	var pause_overlay = level.get("_pause_menu_overlay")
	var pause_button := top_hud.find_child("PauseButton", true, false) as Control
	var timer_label := top_hud.find_child("TimerLabel", true, false) as Control
	var level_label := top_hud.find_child("LevelLabel", true, false) as Control
	var star_counter := top_hud.find_child("StarCounter", true, false) as Control

	var safe_margins := Vector4(60.0, 90.0, 60.0, 70.0)
	var viewport_size := Vector2(720.0, 1280.0)
	top_hud.call("apply_safe_layout", Vector4.ZERO, viewport_size)
	await process_frame
	_check(
		is_equal_approx(pause_button.get_rect().get_center().y, timer_label.get_rect().get_center().y),
		"Pause button and timer should share the same top-HUD row center."
	)
	_check(
		is_equal_approx(star_counter.get_rect().get_center().y, timer_label.get_rect().get_center().y),
		"Star counter and timer should share the same top-HUD row center."
	)
	_check(
		is_equal_approx(pause_button.get_rect().position.x - star_counter.get_rect().end.x, 36.0),
		"Regular star and Pause controls should keep their authored 36px gap."
	)

	top_hud.call("apply_safe_layout", safe_margins, viewport_size)
	await process_frame

	_check(
		top_hud.offset_bottom >= safe_margins.y,
		"The HUD strip background should grow with the safe-top inset instead of staying a fixed height."
	)

	_check(pause_button.offset_top >= safe_margins.y, "Pause button should sit clear of the safe-top inset.")
	_check(
		pause_button.offset_right <= viewport_size.x - safe_margins.z + 0.5,
		"Pause button should stay clear of the safe-right inset."
	)

	_check(
		is_equal_approx(pause_button.get_rect().position.x - star_counter.get_rect().end.x, 30.0),
		"Compact star and Pause controls should keep their authored 30px gap."
	)
	_check(
		timer_label.get_rect().position.x + 0.5 >= level_label.get_rect().end.x,
		"Timer should stay clear of the level label (left exclusion zone)."
	)
	_check(
		timer_label.get_rect().end.x <= star_counter.get_rect().position.x + 0.5,
		"Timer should stay clear of the star/pause cluster (right exclusion zone)."
	)

	# A viewport far too narrow for the modal's preferred 520px width must clamp, not overflow.
	var tight_margins := Vector4(200.0, 100.0, 200.0, 100.0)
	var tight_viewport := Vector2(540.0, 960.0)
	pause_overlay.call("apply_safe_layout", tight_margins, tight_viewport)
	await process_frame
	var outer_panel := pause_overlay.find_child("OuterPanel", true, false) as Control
	var fitted_width := outer_panel.size.x * outer_panel.scale.x
	var fitted_height := outer_panel.size.y * outer_panel.scale.y
	_check(
		fitted_width <= tight_viewport.x - tight_margins.x - tight_margins.z - 39.0,
		"Modal outer panel width must fit within the safe content rect at a tight viewport."
	)
	_check(
		fitted_height <= tight_viewport.y - tight_margins.y - tight_margins.w - 39.0,
		"Modal outer panel height must fit within the safe content rect at a tight viewport."
	)
	var safe_rect := Rect2(
		Vector2(tight_margins.x, tight_margins.y),
		Vector2(
			tight_viewport.x - tight_margins.x - tight_margins.z,
			tight_viewport.y - tight_margins.y - tight_margins.w
		)
	)
	for button_name in ["LeaveButton", "ContinueButton", "CloseButton"]:
		var modal_button := pause_overlay.find_child(button_name, true, false) as Control
		var button_rect := modal_button.get_global_rect()
		_check(
			safe_rect.encloses(button_rect),
			"%s must stay inside the modal's safe rect after fitting." % button_name
		)

	level.free()


## Compact ability layout must resize/reposition the icon and both badge types, not only the parent
## button -- previously the icon and badges stayed at their 96px-authored offsets and overflowed an
## 82px compact button.
func _test_ability_bar_responsive_bounds() -> void:
	var level := await _make_level()
	var top_hud = level.get("_top_hud")
	var ability_bar = level.get("_ability_bar")
	var hammer_button := ability_bar.find_child("HammerButton", true, false) as Control
	var hammer_icon := hammer_button.find_child("Icon", true, false) as Control
	var hammer_badge := hammer_button.find_child("UsesLabel", true, false) as Control

	ability_bar.call("apply_responsive_layout", 900.0)
	await process_frame
	var regular_size: Vector2 = hammer_button.custom_minimum_size
	var regular_badge_right: float = hammer_badge.offset_right

	ability_bar.call("apply_responsive_layout", 400.0)
	top_hud.call(
		"apply_safe_layout",
		Vector4(70.0, 0.0, 70.0, 0.0),
		Vector2(540.0, 960.0)
	)
	await process_frame
	var compact_size: Vector2 = hammer_button.custom_minimum_size
	var compact_icon_right: float = hammer_icon.offset_right
	var compact_badge_right: float = hammer_badge.offset_right

	_check(compact_size.x < regular_size.x, "Compact ability button should be smaller than regular.")
	var pause_button := top_hud.find_child("PauseButton", true, false) as Control
	var expected_pause_size := Vector2(72.0, 64.0) * (400.0 / 540.0)
	_check(
		pause_button.size.is_equal_approx(expected_pause_size),
		"Pause should preserve its smaller settings-button proportions when safe-inset scaled."
	)
	_check(
		compact_icon_right <= compact_size.x + 0.5,
		"Compact icon must stay within the compact button bounds, not overflow it."
	)
	_check(
		compact_badge_right < regular_badge_right,
		"Compact badge offset should shrink relative to the regular one, not stay at the 96px value."
	)

	level.free()


## LEVEL 99, 59:59, a large star total, a large ability-use count, and an active ability timer must
## all remain legible rather than truncated or silently unhandled.
func _test_long_value_formatting() -> void:
	var level := await _make_level()
	var top_hud = level.get("_top_hud")
	var ability_bar = level.get("_ability_bar")

	level.set("selected_level", 99)
	level.call("_update_level_label")
	var level_label := top_hud.find_child("LevelLabel", true, false) as Label
	_check(level_label.text == "LEVEL 99", "Level label should handle a two-digit level number.")

	level.set("_time_remaining", 3599.0)
	level.call("_update_timer_label")
	var timer_label := top_hud.find_child("TimerLabel", true, false) as Label
	_check(timer_label.text == "59:59", "Timer label should format the maximum MM:SS value correctly.")

	level.set("_stars", 123456)
	level.call("_update_star_counter_label")
	var star_label := top_hud.find_child("StarCountLabel", true, false) as Label
	_check(star_label.text == "123456", "Star count label should display a large total in full.")
	_check(
		int(star_label.get_theme_font_size("font_size")) < 26,
		"Star count label should shrink its font for a large total instead of overflowing the pill."
	)

	ability_bar.call("apply_responsive_layout", 400.0)
	ability_bar.call("set_uses", {"hammer": 123456, "shuffle": 3, "highlight": 3, "freezer": 3})
	var hammer_uses := ability_bar.find_child("HammerButton", true, false).find_child("UsesLabel", true, false) as Label
	_check(hammer_uses.text == "123456", "A long ability-use count should display in full.")
	_check(
		_get_rendered_text_width(hammer_uses) <= hammer_uses.size.x - 3.5,
		"A long ability-use count should shrink to fit the compact badge's rendered bounds."
	)
	_check(
		_get_rendered_text_width(star_label) <= star_label.size.x - 3.5,
		"A large star total should fit the rendered star-pill label bounds."
	)

	ability_bar.call("set_active_seconds", &"highlight", 15.0)
	var highlight_timer := ability_bar.find_child("HighlightButton", true, false).find_child("TimerLabel", true, false) as Label
	_check(
		highlight_timer.visible and highlight_timer.text == "15s",
		"An active ability timer should show its remaining seconds."
	)

	level.free()


## The extracted overlay keeps its decorative AD label and countdown readable, tensions its chains,
## swings the hanging lock on a decrease, and releases cleanly without delaying unlock availability.
func _test_locked_shelf_feedback() -> void:
	var level := _level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 7)
	root.add_child(level)
	await process_frame

	var shelf: Node2D = null
	for candidate in level.call("_get_all_shelves"):
		if int(level.call("_get_shelf_unlock_requirement", candidate)) > 0:
			shelf = candidate
			break

	if shelf == null:
		_failures.append("Level 7 should have at least one locked shelf to exercise this test.")
		level.free()
		return

	var overlay := shelf.get_node_or_null("LockedOverlay") as ShelfLockOverlay
	var chain_rig := overlay.get_node("VisualRig/ChainRig") as Node2D
	var chain_top_left := overlay.get_node("VisualRig/ChainRig/TopLeftArm") as Sprite2D
	var chain_top_right := overlay.get_node("VisualRig/ChainRig/TopRightArm") as Sprite2D
	var chain_bottom_left := overlay.get_node("VisualRig/ChainRig/BottomLeftArm") as Sprite2D
	var chain_bottom_right := overlay.get_node("VisualRig/ChainRig/BottomRightArm") as Sprite2D
	var chain_arms: Array[Sprite2D] = [
		chain_top_left,
		chain_top_right,
		chain_bottom_left,
		chain_bottom_right,
	]
	var wall_covers := overlay.get_node("VisualRig/WallAttachmentCovers") as Node2D
	var lock_rig := overlay.get_node("VisualRig/LockRig") as Node2D
	var ad_label := overlay.get_node("VisualRig/LockRig/AdLabel") as Label
	var countdown_badge := overlay.get_node("VisualRig/CountdownBadge") as Node2D
	var count_label := overlay.get_node("VisualRig/CountdownBadge/RemainingLabel") as Label
	var requirement := int(level.call("_get_shelf_unlock_requirement", shelf))
	var chain_rest_positions: Array[Vector2] = []
	var chain_rest_scales: Array[Vector2] = []
	for chain_arm in chain_arms:
		chain_rest_positions.append(chain_arm.position)
		chain_rest_scales.append(chain_arm.scale)
	var wall_endpoint_at_rest := _get_chain_wall_endpoint(chain_top_left, true)
	var lock_endpoint_at_rest := _get_chain_lock_endpoint(chain_top_left, true)
	var lock_rest_position := lock_rig.position
	var badge_rest_position := countdown_badge.position
	var badge_rest_scale := countdown_badge.scale
	var standard_chain_scale := chain_top_left.scale

	_check(ad_label.text == "AD", "Locked shelf should show the decorative AD label on its lock.")
	_check(
		chain_rig.z_index > lock_rig.z_index,
		"Locked-shelf chains should render in front of the lock."
	)
	_check(
		wall_covers.z_index > chain_rig.z_index
		and countdown_badge.z_index > wall_covers.z_index,
		"Wall covers should mask chain ends while the count remains topmost."
	)
	_check(
		wall_endpoint_at_rest.x <= -overlay.overlay_half_width
		and absf(lock_endpoint_at_rest.x) <= 6.0,
		"A chain arm should span from beneath the shelf wall to the lock shackle."
	)
	var hammer_button := level.get_node("UI/AbilityBar").find_child(
		"HammerButton",
		true,
		false
	) as Control
	var ability_uses_label := hammer_button.find_child("UsesLabel", true, false) as Label
	_check(
		is_same(
			count_label.get_theme_stylebox("normal"),
			ability_uses_label.get_theme_stylebox("normal")
		),
		"Locked-shelf and ability-use counters should share the exact badge style resource."
	)
	var shared_chain_texture := chain_top_left.texture
	var all_arms_share_texture := shared_chain_texture != null
	for chain_arm in chain_arms:
		all_arms_share_texture = all_arms_share_texture and is_same(
			chain_arm.texture,
			shared_chain_texture
		)
	_check(all_arms_share_texture, "All four arms should reuse selected chain candidate A.")

	level.set("_triples_cleared", requirement - 1)
	level.call("_update_locked_shelves")
	await process_frame
	_check(overlay.visible, "Shelf should stay locked before the requirement is met.")
	_check(count_label.text == "1", "Countdown badge should show one remaining clear.")
	_check(
		not countdown_badge.scale.is_equal_approx(badge_rest_scale),
		"Countdown badge should be mid-pop right after a count decrease."
	)
	_check(
		not chain_top_left.position.is_equal_approx(chain_rest_positions[0]),
		"Chain arms should be pulling toward the lock right after a count decrease."
	)
	_check(
		_get_chain_wall_endpoint(chain_top_left, true).is_equal_approx(wall_endpoint_at_rest)
		and not _get_chain_lock_endpoint(chain_top_left, true).is_equal_approx(
			lock_endpoint_at_rest
		),
		"Tension feedback should preserve the wall anchor and move the shackle endpoint."
	)
	_check(
		not is_zero_approx(lock_rig.rotation),
		"Hanging lock should be mid-swing right after a count decrease."
	)
	await _wait_seconds(0.35)
	_check(
		countdown_badge.scale.is_equal_approx(badge_rest_scale)
		and chain_top_left.position.is_equal_approx(chain_rest_positions[0])
		and chain_top_left.scale.is_equal_approx(chain_rest_scales[0])
		and is_zero_approx(lock_rig.rotation),
		"Badge, chains, and hanging lock should settle back to their authored transforms."
	)

	level.set("_triples_cleared", requirement)
	level.call("_update_locked_shelves")
	await process_frame
	_check(
		overlay.visible,
		"Overlay should still be visible/fading right after unlocking, not disappear on the same frame."
	)
	_check(count_label.text == "0", "Final clear should visibly decrement the badge to zero.")
	_check(
		bool(level.call("_is_shelf_move_source_eligible", shelf)),
		"Shelf should become gameplay-eligible immediately while its chains are still releasing."
	)
	await _wait_seconds(0.5)
	_check(not overlay.visible, "Overlay should be fully hidden once the unlock animation finishes.")
	var all_arms_reset := true
	for index in range(chain_arms.size()):
		all_arms_reset = all_arms_reset and chain_arms[index].position.is_equal_approx(
			chain_rest_positions[index]
		) and chain_arms[index].scale.is_equal_approx(chain_rest_scales[index])
	_check(
		overlay.modulate.a == 1.0
		and overlay.scale.is_equal_approx(Vector2.ONE)
		and all_arms_reset
		and lock_rig.position.is_equal_approx(lock_rest_position)
		and is_zero_approx(lock_rig.rotation)
		and countdown_badge.position.is_equal_approx(badge_rest_position)
		and countdown_badge.scale.is_equal_approx(badge_rest_scale),
		"Unlock should hide and fully reset every animated overlay transform."
	)

	level.free()

	var dispenser := (load("res://scenes/dispenser_shelf.tscn") as PackedScene).instantiate()
	root.add_child(dispenser)
	await process_frame
	var compact_overlay := dispenser.get_node("LockedOverlay") as ShelfLockOverlay
	var compact_shade := compact_overlay.get_node("Shade") as Polygon2D
	var compact_chain := compact_overlay.get_node("VisualRig/ChainRig/TopLeftArm") as Sprite2D
	var compact_left_wall_cover := compact_overlay.get_node(
		"VisualRig/WallAttachmentCovers/Left"
	) as Polygon2D
	var compact_label := compact_overlay.get_node(
		"VisualRig/CountdownBadge/RemainingLabel"
	) as Label
	compact_overlay.show_locked(123)
	_check(compact_overlay.compact_layout, "Dispenser should use the compact locked-shelf layout.")
	_check(
		is_equal_approx(compact_shade.polygon[0].x, -40.0)
		and is_equal_approx(compact_shade.polygon[1].x, 40.0),
		"Compact shade should fit the dispenser's narrow shelf bounds."
	)
	_check(
		compact_chain.scale.x < standard_chain_scale.x,
		"Compact chain treatment should be narrower than the standard shelf treatment."
	)
	_check(
		_get_chain_wall_endpoint(compact_chain, true).x <= -40.0
		and is_equal_approx(compact_left_wall_cover.polygon[1].x, -40.0),
		"Compact chain should disappear beneath the dispenser wall cover."
	)
	_check(compact_label.text == "123", "Compact countdown should retain a three-digit value.")
	dispenser.free()


func _get_chain_wall_endpoint(chain_arm: Sprite2D, is_left_arm: bool) -> Vector2:
	var endpoints := _get_chain_endpoints(chain_arm)
	return endpoints[0] if is_left_arm else endpoints[1]


func _get_chain_lock_endpoint(chain_arm: Sprite2D, is_left_arm: bool) -> Vector2:
	var endpoints := _get_chain_endpoints(chain_arm)
	return endpoints[1] if is_left_arm else endpoints[0]


func _get_chain_endpoints(chain_arm: Sprite2D) -> Array[Vector2]:
	var half_span := Vector2(
		ShelfLockOverlay.CHAIN_ARM_VISIBLE_WIDTH * chain_arm.scale.x * 0.5,
		0.0
	).rotated(chain_arm.rotation)
	return [chain_arm.position - half_span, chain_arm.position + half_span]


func _make_level() -> Node:
	var level := _level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 1)
	root.add_child(level)
	await process_frame
	return level


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout


func _make_ui_cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


func _get_rendered_text_width(label: Label) -> float:
	return label.get_theme_font("font").get_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		label.get_theme_font_size("font_size")
	).x


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
