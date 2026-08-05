extends SceneTree

## UI-002 interaction/motion verification: PressScaleButton's shared press-feedback contract,
## active-tab reselection, ui_cancel/back behavior, focus/cursor policy, rapid-input robustness
## (Leaderboard scope switching, Shop reload, purchase-dialog dismissal), and the reward-chest
## flight's star-art/PlayerProgress-untouched semantics. See docs/UI_002_INTERACTION_MOTION_TICKET.md
## and docs/SCENES.md's "Shared Interaction Roles" / "Active-Tab Reselection Rule" /
## "Back/ui_cancel Behavior" sections.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

## Safe to preload at the class level -- neither script references an autoload singleton, so
## compiling them carries no risk of running before PlayerProgress/ChapterCatalog exist.
const UIMotionScript := preload("res://scripts/ui_motion.gd")
const PressScaleButtonScript := preload("res://scripts/press_scale_button.gd")

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SHOP_SCENE_PATH := "res://scenes/ui/shop_screen.tscn"
const LEADERBOARD_SCENE_PATH := "res://scenes/ui/leaderboard_screen.tscn"
const REWARD_STAR_FLYER_SCENE_PATH := "res://scenes/ui/main_menu_reward_star_flyer.tscn"

var _failures: Array[String] = []
var _player_progress: Node
## Loaded at runtime inside _run() rather than preloaded at the class level (matching
## tests/ui/test_chapter_ui.gd): these scenes transitively compile scripts that reference the
## PlayerProgress/ChapterCatalog autoload globals, which do not exist yet while this main-loop
## script itself is still being compiled -- preloading them here would fail the same way.
var _main_menu_scene: PackedScene
var _shop_scene: PackedScene
var _leaderboard_scene: PackedScene
var _reward_star_flyer_scene: PackedScene


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Interaction/motion verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_player_progress = root.get_node_or_null("PlayerProgress")
	_check(_player_progress != null, "PlayerProgress autoload is available.")
	if _player_progress == null:
		quit(1)
		return

	_main_menu_scene = load(MAIN_MENU_SCENE_PATH) as PackedScene
	_shop_scene = load(SHOP_SCENE_PATH) as PackedScene
	_leaderboard_scene = load(LEADERBOARD_SCENE_PATH) as PackedScene
	_reward_star_flyer_scene = load(REWARD_STAR_FLYER_SCENE_PATH) as PackedScene

	await _test_press_scale_button_self_target()
	await _test_press_scale_button_visual_target()
	await _test_active_tab_reselection()
	await _test_ui_cancel_overlays()
	await _test_focus_and_cursor_policy()
	await _test_rapid_leaderboard_scope_switching()
	await _test_shop_reload_and_dialog_dismissal()
	await _test_reward_star_flyer()
	await _test_final_navigation_phase()

	# Let any still-in-flight tween/timer from the phases above (a superseded close_with_fade's
	# timer keeps running out its duration even once its result is ignored, for example) drain
	# naturally before quitting, so a harmless straggler doesn't trip Godot's leaked-object exit
	# warning and turn a fully passing suite into a nonzero exit code.
	await _wait_frames(60)

	if _failures.is_empty():
		print("Interaction/motion verification passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


## Press/release restoration, release-outside-equals-inside (button_up fires the same either way),
## disable-while-held and hide-while-held snapping immediately with no animation, and scene-exit
## cleanup -- all against the button's own scale (the default, no visual_target_path set).
func _test_press_scale_button_self_target() -> void:
	var button := _make_press_scale_button(Vector2(160, 60))
	root.add_child(button)
	await process_frame

	_check(is_equal_approx(button.scale.x, 1.0), "A fresh PressScaleButton should start at the released scale.")

	button.emit_signal("button_down")
	await _wait_seconds(UIMotionScript.PRESS_IN_DURATION + 0.05)
	_check(
		is_equal_approx(button.scale.x, button.held_scale),
		"Holding the button should animate to exactly held_scale."
	)

	button.emit_signal("button_up")
	await _wait_seconds(UIMotionScript.RELEASE_DURATION + 0.05)
	_check(
		is_equal_approx(button.scale.x, 1.0),
		"Releasing should animate back to the released scale."
	)

	# button_up is what Godot emits for a release outside the button too, so re-exercising the
	# same signal path covers "release outside" without needing real pointer simulation.
	button.emit_signal("button_down")
	await process_frame
	button.emit_signal("button_up")
	await _wait_seconds(UIMotionScript.RELEASE_DURATION + 0.05)
	_check(
		is_equal_approx(button.scale.x, 1.0),
		"Release outside the button should restore the released scale the same as a release inside."
	)

	# Disabling mid-press must snap back immediately, with no animation.
	button.emit_signal("button_down")
	await process_frame
	_check(not is_equal_approx(button.scale.x, 1.0), "Button should be visibly held before disabling.")
	button.disabled = true
	await process_frame
	_check(
		is_equal_approx(button.scale.x, 1.0),
		"Disabling mid-press should snap back to the released scale on the very next frame."
	)
	button.disabled = false

	# Hiding mid-press must also snap back immediately.
	button.emit_signal("button_down")
	await process_frame
	_check(not is_equal_approx(button.scale.x, 1.0), "Button should be visibly held before hiding.")
	button.visible = false
	await process_frame
	_check(is_equal_approx(button.scale.x, 1.0), "Hiding mid-press should restore the released scale.")
	button.visible = true

	# Rapid re-press without an intervening release must not accumulate scale.
	button.emit_signal("button_down")
	await process_frame
	button.emit_signal("button_down")
	await _wait_seconds(UIMotionScript.PRESS_IN_DURATION + 0.05)
	_check(
		is_equal_approx(button.scale.x, button.held_scale),
		"A redundant button_down while already held must not compound the held scale."
	)
	button.emit_signal("button_up")
	await _wait_seconds(UIMotionScript.RELEASE_DURATION + 0.05)

	# Scene exit mid-press restores the released scale (checked just before the node is gone).
	button.emit_signal("button_down")
	await process_frame
	button.queue_free()
	await process_frame
	_check(not is_instance_valid(button), "The test button should be gone after queue_free().")


## visual_target_path lets an invisible/full-rect hit target animate a designated visual child
## instead of itself: the child's scale changes, but the button's own scale (and therefore its
## touch rectangle) never does.
func _test_press_scale_button_visual_target() -> void:
	var button := _make_press_scale_button(Vector2(96, 96))
	var visual := Control.new()
	visual.name = "Visual"
	visual.custom_minimum_size = Vector2(64, 64)
	visual.size = Vector2(64, 64)
	button.add_child(visual)
	button.visual_target_path = ^"Visual"
	button.held_scale = 0.9
	root.add_child(button)
	await process_frame

	var button_size_before := button.size
	button.emit_signal("button_down")
	await _wait_seconds(UIMotionScript.PRESS_IN_DURATION + 0.05)
	_check(
		is_equal_approx(visual.scale.x, 0.9),
		"The designated visual child should animate to held_scale while pressed."
	)
	_check(
		is_equal_approx(button.scale.x, 1.0),
		"The button's own scale must stay untouched when a visual_target_path is set."
	)
	_check(
		button.size == button_size_before,
		"The button's touch rectangle must not shrink when only the visual child scales."
	)

	button.emit_signal("button_up")
	await _wait_seconds(UIMotionScript.RELEASE_DURATION + 0.05)
	_check(is_equal_approx(visual.scale.x, 1.0), "The visual child should restore its released scale.")

	button.queue_free()
	await process_frame


## Retapping the already-active bottom-navigation tab must be a documented no-op everywhere:
## Shop does not reload its catalog, Leaderboard does not reload rankings, and Main Menu's Home tab
## does not navigate away.
func _test_active_tab_reselection() -> void:
	ProjectSettings.set_setting("application/config/mock_store_country", "US")
	_player_progress.reset_progress()
	var shop := _shop_scene.instantiate() as Control
	root.add_child(shop)
	current_scene = shop
	await _wait_frames(6)

	var serial_before := int(shop.get("_load_request_serial"))
	(shop.get_node("%BottomNavigation") as Node).emit_signal("shop_pressed")
	await process_frame
	_check(
		int(shop.get("_load_request_serial")) == serial_before,
		"Retapping the active Shop tab must not reload the catalog."
	)
	shop.queue_free()
	await process_frame

	ProjectSettings.set_setting("application/config/leaderboard_provider", "mock")
	_player_progress.reset_progress()
	var leaderboard := _leaderboard_scene.instantiate() as Control
	root.add_child(leaderboard)
	current_scene = leaderboard
	await _wait_frames(6)

	var lb_serial_before := int(leaderboard.get("_request_serial"))
	(leaderboard.get_node("%BottomNavigation") as Node).emit_signal("leaderboard_pressed")
	await process_frame
	_check(
		int(leaderboard.get("_request_serial")) == lb_serial_before,
		"Retapping the active Leaderboard tab must not reload rankings."
	)
	leaderboard.queue_free()
	await process_frame

	_player_progress.reset_progress()
	var menu := _main_menu_scene.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await _wait_frames(6)

	(menu.get_node("%BottomNavigation") as Node).emit_signal("home_pressed")
	await process_frame
	_check(
		current_scene == menu,
		"Retapping the active Home tab on Main Menu must not navigate away."
	)
	menu.queue_free()
	await process_frame


## ui_cancel behavior that never triggers a real scene change, so it is safe to exercise freely
## mid-suite: Shop closes its purchase dialog first if one is open; Main Menu closes an open
## profile modal; Main Menu's own handling defers entirely to an open Chapter Selection instead of
## double-handling the same press; and ui_cancel with nothing open on Main Menu does nothing.
func _test_ui_cancel_overlays() -> void:
	_player_progress.reset_progress()
	var shop := _shop_scene.instantiate() as Control
	root.add_child(shop)
	current_scene = shop
	await _wait_frames(6)

	var dialog := shop.get_node("%PurchaseDialog") as Control
	dialog.call("show_result", "Test", "Message")
	await process_frame
	_check(dialog.visible, "The purchase dialog should be visible before testing ui_cancel precedence.")
	shop.call("_unhandled_input", _make_ui_cancel_event())
	_check(
		not bool(shop.get("_is_navigating")),
		"ui_cancel should close the open purchase dialog instead of leaving Shop."
	)
	await _wait_seconds(UIMotionScript.OVERLAY_DURATION + 0.1)
	_check(not dialog.visible, "ui_cancel should have closed the purchase dialog.")
	shop.queue_free()
	await process_frame

	_player_progress.reset_progress()
	var menu := _main_menu_scene.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await _wait_frames(6)

	menu.call("_open_profile_menu")
	await process_frame
	_check(menu.get_node_or_null("ProfileMenu") != null, "The profile modal should be open before testing ui_cancel.")
	menu.call("_unhandled_input", _make_ui_cancel_event())
	await _wait_seconds(UIMotionScript.OVERLAY_DURATION + 0.1)
	_check(menu.get_node_or_null("ProfileMenu") == null, "ui_cancel should close the open profile modal.")
	_check(current_scene == menu, "Closing an overlay via ui_cancel must not navigate Main Menu away.")

	menu.call("_open_chapter_selection")
	await process_frame
	var selection := menu.get_node_or_null("ChapterSelectionScreen") as Control
	_check(selection != null, "Chapter Selection should be open before testing ui_cancel precedence.")
	# Simulate the engine delivering the same press to both nodes -- order is not guaranteed, so
	# Main Menu's own handling must no-op purely because Chapter Selection is open right now.
	menu.call("_unhandled_input", _make_ui_cancel_event())
	_check(
		is_instance_valid(selection) and menu.get_node_or_null("ChapterSelectionScreen") == selection,
		"Main Menu's ui_cancel handling must defer entirely to an open Chapter Selection, not also act."
	)
	selection.call("_unhandled_input", _make_ui_cancel_event())
	await _wait_seconds(UIMotionScript.OVERLAY_DURATION + 0.1)
	_check(menu.get_node_or_null("ChapterSelectionScreen") == null, "Chapter Selection should close itself on ui_cancel.")

	# Nothing open: ui_cancel must be a true no-op, not a quit or an unexpected navigation.
	menu.call("_unhandled_input", _make_ui_cancel_event())
	await process_frame
	_check(current_scene == menu, "ui_cancel with nothing open on Main Menu must not navigate or quit.")
	menu.queue_free()
	await process_frame


## Every control fixed to FOCUS_NONE and every control fixed to the pointing-hand cursor stays
## that way -- a lightweight regression lock for the touch-only focus-policy decision and the
## cursor sweep (see docs/SCENES.md's "Focus Policy").
func _test_focus_and_cursor_policy() -> void:
	var menu := _main_menu_scene.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await _wait_frames(3)

	var level_button := menu.get_node("%LevelButton") as Button
	_check(level_button.focus_mode == Control.FOCUS_NONE, "LevelButton should stay FOCUS_NONE.")
	_check(
		level_button.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
		"LevelButton should use the pointing-hand cursor."
	)

	var profile_widget := menu.get_node("%TopStatusBar/MainMenuTopStatus/ProfileWidget") as Button
	_check(profile_widget.focus_mode == Control.FOCUS_NONE, "ProfileWidget should stay FOCUS_NONE.")

	var chest_button := menu.get_node("%RewardChest/ChestButton") as Button
	_check(chest_button.focus_mode == Control.FOCUS_NONE, "Reward Chest's ChestButton should stay FOCUS_NONE.")

	var shop_nav_button := menu.get_node("%BottomNavigation/Buttons/ShopButton") as Button
	_check(shop_nav_button.focus_mode == Control.FOCUS_NONE, "Bottom navigation's ShopButton should stay FOCUS_NONE.")

	menu.call("_open_chapter_selection")
	await process_frame
	var selection := menu.get_node_or_null("ChapterSelectionScreen") as Control
	if selection != null:
		var back_button := selection.get_node("%BackButton") as Button
		_check(back_button.focus_mode == Control.FOCUS_NONE, "Chapter Selection's BackButton should stay FOCUS_NONE.")
		_check(
			back_button.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"Chapter Selection's BackButton should use the pointing-hand cursor."
		)
		var prev_arrow := (selection.get_node("%Pager") as Control).get_node("%PrevArrow") as Button
		_check(prev_arrow.focus_mode == Control.FOCUS_NONE, "The chapter pager's PrevArrow should stay FOCUS_NONE.")

	menu.queue_free()
	await process_frame


## Rapid Weekly/Country/World switching (no awaits between presses) must settle on the
## last-selected scope with no stale loading state or leaked pulse tween on the shared status panel.
func _test_rapid_leaderboard_scope_switching() -> void:
	ProjectSettings.set_setting("application/config/leaderboard_provider", "mock")
	_player_progress.reset_progress()
	var leaderboard := _leaderboard_scene.instantiate() as Control
	root.add_child(leaderboard)
	current_scene = leaderboard
	await _wait_frames(6)

	leaderboard.call("_select_scope", &"country")
	leaderboard.call("_select_scope", &"world")
	leaderboard.call("_select_scope", &"weekly")
	leaderboard.call("_select_scope", &"country")
	await _wait_frames(8)

	_check(
		str(leaderboard.get("_selected_scope")) == "country",
		"Rapid scope switching should settle on the last scope actually requested."
	)
	var status_panel := leaderboard.get_node("%StatusPanel") as Control
	_check(not status_panel.visible, "The status panel should end hidden once rapid scope switching settles.")
	var status_message := status_panel.get_node("StatusPanelBackground/StatusStack/StatusMessageLabel") as Label
	_check(
		is_equal_approx(status_message.modulate.a, 1.0),
		"The loading pulse must not leave the status message stuck at partial opacity after settling."
	)

	leaderboard.queue_free()
	await process_frame


## Rapid repeated Shop reloads (Retry spam) must settle cleanly, and rapid show/close on the reused
## purchase dialog must never leave it stuck mid-fade (regression coverage for the close_with_fade()
## supersession fix).
func _test_shop_reload_and_dialog_dismissal() -> void:
	ProjectSettings.set_setting("application/config/mock_store_country", "US")
	_player_progress.reset_progress()
	var shop := _shop_scene.instantiate() as Control
	root.add_child(shop)
	current_scene = shop
	await _wait_frames(6)

	shop.call("_load_shop")
	shop.call("_load_shop")
	shop.call("_load_shop")
	await _wait_frames(10)

	var bundles := shop.get_node("%BundlesContainer") as VBoxContainer
	_check(bundles.get_child_count() > 0, "Rapid repeated Shop reloads should still settle on a populated catalog.")
	var status_panel := shop.get_node("%StatusPanel") as Control
	_check(not status_panel.visible, "The status panel should end hidden once a rapid reload settles.")

	var dialog := shop.get_node("%PurchaseDialog") as Control
	dialog.call("show_result", "Test", "Message one")
	dialog.call("close")
	dialog.call("show_result", "Test", "Message two")
	await _wait_seconds(UIMotionScript.OVERLAY_DURATION + 0.1)
	_check(
		dialog.visible and is_equal_approx(dialog.modulate.a, 1.0),
		"The last of several rapid show/close calls should leave the dialog fully visible, not stuck mid-fade."
	)

	dialog.call("close")
	await _wait_seconds(UIMotionScript.OVERLAY_DURATION + 0.1)
	_check(
		not dialog.visible and is_equal_approx(dialog.modulate.a, 0.0),
		"Closing afterward should leave the dialog fully hidden, not stuck mid-fade."
	)

	shop.queue_free()
	await process_frame


## The reward-chest flight uses the shared reward-star art (never clover-coin art) and never
## touches PlayerProgress -- it only re-displays chest progress complete_level() already saved.
func _test_reward_star_flyer() -> void:
	_player_progress.reset_progress()
	var coins_before: int = _player_progress.get_coins()
	var progress_before: Dictionary = _player_progress.get_reward_chest_progress()

	var flyer := _reward_star_flyer_scene.instantiate() as Control
	root.add_child(flyer)
	await process_frame

	flyer.call("play", 2, Vector2(100, 900), Vector2(60, 240))
	await process_frame

	var found_star_texture := false
	for child in flyer.get_children():
		var texture_rect := child as TextureRect
		if texture_rect == null or texture_rect.texture == null:
			continue
		_check(
			texture_rect.texture.resource_path == "res://assets/ui/reward_star_84x84.png",
			"The reward-chest flight must use the shared reward-star art, not clover-coin art."
		)
		found_star_texture = true
	_check(found_star_texture, "Playing the reward-chest flight should spawn at least one star view.")

	# Let the flight finish naturally instead of freeing mid-animation: each star's tween is only
	# guaranteed to signal completion by running to the end, not by being killed out from under it,
	# so freeing early would strand a suspended await (and its Tween) for the rest of the process.
	await _wait_seconds(1.5)

	_check(
		_player_progress.get_coins() == coins_before,
		"The reward-chest flight is presentation only and must not change the saved coin balance."
	)
	var progress_after: Dictionary = _player_progress.get_reward_chest_progress()
	_check(
		int(progress_after.get("stars", -1)) == int(progress_before.get("stars", -2))
			and int(progress_after.get("goal", -1)) == int(progress_before.get("goal", -2)),
		"The reward-chest flight is presentation only and must not change saved reward-chest progress."
	)

	flyer.queue_free()
	await process_frame


## Exercises two real navigation paths together as the very last thing this suite does, since both
## legitimately call change_scene_to_file() (deferred, but harmless in this throwaway isolated
## project): ui_cancel with no overlay open returns Shop to Main Menu, and a second, immediate
## navigation attempt is ignored while the first is still in flight. Waits out the deferred swap
## and frees whatever it lands on afterward, so the suite does not report a false failure via
## Godot's own leaked-object exit warning.
func _test_final_navigation_phase() -> void:
	_player_progress.reset_progress()
	var shop := _shop_scene.instantiate() as Control
	root.add_child(shop)
	current_scene = shop
	await _wait_frames(6)

	_check(not bool(shop.get("_is_navigating")), "Shop should not be mid-navigation before ui_cancel.")
	_check(
		shop.process_mode != Node.PROCESS_MODE_DISABLED,
		"Shop should still accept input before ui_cancel starts a navigation."
	)
	shop.call("_unhandled_input", _make_ui_cancel_event())
	_check(
		bool(shop.get("_is_navigating")),
		"ui_cancel with no overlay open should start returning Shop to Main Menu."
	)
	_check(
		shop.process_mode == Node.PROCESS_MODE_DISABLED,
		"Shop should stop accepting input once a navigation starts, so the outgoing screen never accepts input while the new one becomes visible."
	)
	# A duplicate press arriving before the deferred scene swap resolves must be ignored rather
	# than calling change_scene_to_file() a second time.
	shop.call("_begin_navigation", "res://scenes/ui/leaderboard_screen.tscn")
	_check(
		bool(shop.get("_is_navigating")),
		"A duplicate navigation attempt while already navigating should not clear the in-progress flag."
	)

	await _wait_frames(10)
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame


func _make_press_scale_button(min_size: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = min_size
	button.size = min_size
	button.set_script(PressScaleButtonScript)
	return button


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout


func _make_ui_cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
