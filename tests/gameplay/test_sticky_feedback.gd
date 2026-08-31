extends SceneTree

var failures: Array[String] = []
var stages := 0
var level
var anchor: ShelfItem
var sprite: Sprite2D
var feedback


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with("SortingPuzzleTest_"):
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	level = load("res://scenes/testing/sticky_items_preview.tscn").instantiate()
	level._sound_effects_enabled = false
	root.add_child(level)
	level._set_moving_shelf_rows_paused(true)
	for frame in range(12):
		await process_frame
	anchor = level._get_slot_item(level._get_front_slots(level._get_all_shelves()[0])[0])
	sprite = anchor.get_node("Sprite2D")
	feedback = anchor.get_node("StickyBlockedFeedback")
	await _test_tap_and_hold()
	await _test_pointer_ownership()
	await _test_cancellation()
	await _test_moving_and_scaling()
	await _test_destination_and_free()
	_check(stages == 5, "Every feedback stage completed")
	level.queue_free()
	await process_frame
	if failures.is_empty():
		print("STICKY FEEDBACK VERIFICATION PASSED (5 stages)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_tap_and_hold() -> void:
	var parent := anchor.get_parent()
	var transform := anchor.transform
	var collision: Transform2D = anchor.get_node("CollisionShape2D").transform
	var shadow: Transform2D = anchor.get_node("Shadow").transform
	var gum_offset: Vector2 = anchor.get_node("StickyItemIndicator/Sprite2D").position
	level._handle_press_at(anchor.global_position)
	level._handle_release_at(anchor.global_position)
	await create_timer(0.06).timeout
	_check(sprite.rotation > 0.01, "Tap visibly rocks the body")
	await create_timer(0.46).timeout
	_check(feedback.pose == Vector3.ZERO and sprite.position == Vector2.ZERO and sprite.rotation == 0.0, "Tap restores the exact resting pose")
	for tap in range(8):
		level._handle_press_at(anchor.global_position)
		level._handle_release_at(anchor.global_position)
		await process_frame
	await create_timer(0.5).timeout
	_check(feedback.pose == Vector3.ZERO, "Rapid taps do not accumulate pose/tweens")
	level._handle_press_at(anchor.global_position)
	level._handle_motion_at(anchor.global_position + Vector2(10000, -10000))
	await create_timer(0.25).timeout
	_check(sprite.rotation > deg_to_rad(4.0) and sprite.rotation <= deg_to_rad(5.0), "Extreme pull leans toward finger but stops at five degrees")
	var foot := sprite.transform * Vector2(0, ShelfItem.SHADOW_GROUND_TEXELS)
	_check(foot.is_equal_approx(Vector2(0, ShelfItem.SHADOW_GROUND_TEXELS * anchor.visual_scale)), "Body ground contact stays anchored under rotation and vertical stretch")
	anchor.set_outline(true, Color.YELLOW, 3.0)
	_check(anchor.get_node("OutlineSprite").transform.is_equal_approx(sprite.transform), "Hint outline composes with resistance")
	anchor.set_highlight_scale(1.05)
	_check(sprite.rotation > 0.01, "Highlight refresh does not erase resistance")
	anchor.set_highlight_scale(1.0)
	anchor.set_outline(false, Color.YELLOW, 0.0)
	_check(anchor.get_parent() == parent and anchor.transform == transform and anchor.is_sticky and anchor.item_id == &"soda_bottle", "Blocked gesture preserves logical item identity and slot")
	_check(anchor.get_node("CollisionShape2D").transform == collision and anchor.get_node("Shadow").transform == shadow and anchor.shadow_lift == 0.0, "Hitbox and grounded shadow never lift or move")
	_check(anchor.get_node("StickyItemIndicator/Sprite2D").position == gum_offset, "Gum retains authored offset")
	_check(level._pressed_item == null and level._selected_item == null and level._dragged_item == null and not level._has_player_started_timer, "Blocked input never selects/drags/starts timer")
	level._handle_release_at(anchor.global_position + Vector2(10000, -10000))
	await create_timer(0.35).timeout
	_check(feedback.pose == Vector3.ZERO, "Held release springs exactly home")
	stages += 1


func _touch(pressed: bool, index: int, at: Vector2, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.index = index
	event.position = level.get_canvas_transform() * at
	event.canceled = canceled
	level._input(event)


func _test_pointer_ownership() -> void:
	_touch(true, 3, anchor.global_position)
	_check(level._blocked_pointer_id == 3, "Native touch owns the blocked gesture")
	_touch(true, 8, anchor.global_position)
	var drag := InputEventScreenDrag.new()
	drag.index = 8
	drag.position = level.get_canvas_transform() * (anchor.global_position + Vector2(160, 0))
	level._input(drag)
	_touch(false, 8, anchor.global_position)
	level._handle_release_at(anchor.global_position)
	_check(level._blocked_pointer_id == 3 and feedback._target.x == 0.0, "Second finger and mouse cannot pull or release the owned touch")
	drag.index = 3
	level._input(drag)
	await create_timer(0.1).timeout
	_check(sprite.rotation > 0.01, "Owning native screen drag drives resistance")
	_touch(false, 3, anchor.global_position, true)
	_check(level._blocked_item == null and feedback.pose == Vector3.ZERO, "Canceled touch resets immediately")
	var duplicate := InputEventMouseButton.new()
	duplicate.device = InputEvent.DEVICE_ID_EMULATION
	duplicate.button_index = MOUSE_BUTTON_LEFT
	duplicate.pressed = true
	level._input(duplicate)
	_check(level._blocked_item == null and level._pressed_item == null, "Emulated mouse cannot duplicate touch input")
	stages += 1


func _test_cancellation() -> void:
	for reason in ["pause", "interrupt", "focus", "back", "busy", "hidden", "unstick"]:
		level._handle_press_at(anchor.global_position)
		level._handle_motion_at(anchor.global_position + Vector2(90, -50))
		await create_timer(0.07).timeout
		match reason:
			"pause":
				level._level_paused = true
				level._refresh_sticky_feedback_availability()
				level._level_paused = false
			"interrupt":
				level._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
				level._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
			"focus": level._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
			"back": anchor.is_in_back_layer = true
			"busy": level._mark_item_clearing_by_id(anchor.get_instance_id())
			"hidden": anchor.hide()
			"unstick": anchor.is_sticky = false
		level._refresh_sticky_feedback_availability()
		_check(level._blocked_item == null and feedback.pose == Vector3.ZERO, "Cancellation restores pose and gesture: " + reason)
		anchor.play_sticky_blocked_feedback()
		if reason in ["back", "busy", "hidden", "unstick"]:
			_check(not feedback.is_active(), "Unavailable item refuses animation: " + reason)
		anchor.reset_sticky_blocked_feedback()
		anchor.is_in_back_layer = false
		anchor.is_sticky = true
		anchor.show()
		level._unmark_item_clearing_by_id(anchor.get_instance_id())
	# Also cancel a one-shot after the pointer is already gone.
	anchor.play_sticky_blocked_feedback()
	level._cancel_active_interaction()
	_check(feedback.pose == Vector3.ZERO and not feedback.is_active(), "Global cancellation resets released wobble")
	stages += 1


func _test_moving_and_scaling() -> void:
	var moving: ShelfItem = level._get_slot_item(level._get_front_slots(level._get_all_shelves()[6])[0])
	var shelf: Node2D = level._get_owning_shelf(moving)
	var original := shelf.position
	var pointer := moving.global_position
	level._handle_press_at(pointer)
	shelf.position.x += 8.0
	level._handle_motion_at(pointer)
	await create_timer(0.12).timeout
	_check(moving.get_node("Sprite2D").rotation == 0.0, "Moving shelf beneath stationary finger creates no pull")
	shelf.position.x += 10000.0
	level._refresh_sticky_feedback_availability()
	_check(level._blocked_item == null and not moving.is_sticky_feedback_active(), "Off-window moving item cancels")
	shelf.position = original
	var original_scale := anchor.scale
	var target_x := 0.0
	for factor in [0.75, 1.0, 1.5]:
		anchor.scale = Vector2.ONE * factor
		level._handle_press_at(anchor.global_position)
		var delta := anchor.global_transform.basis_xform(Vector2(80.0, 0.0))
		level._handle_motion_at(anchor.global_position + delta)
		if target_x == 0.0:
			target_x = feedback._target.x
		_check(is_equal_approx(feedback._target.x, target_x), "Responsive scaling preserves local resistance")
		level._cancel_active_interaction()
	anchor.scale = original_scale
	stages += 1


func _test_destination_and_free() -> void:
	var shelves: Array = level._get_all_shelves()
	var source: Node2D = level._get_front_slots(shelves[1])[0]
	var donor: ShelfItem = level._get_slot_item(source)
	level.item_move_duration_seconds = 0.0
	level._handle_press_at(donor.global_position)
	level._handle_release_at(donor.global_position)
	level._handle_press_at(anchor.global_position)
	_check(level._blocked_item == null and not feedback.is_active(), "Ordinary destination routing never plays refusal")
	for frame in range(12):
		await process_frame
	_check(donor.get_parent() == level._get_front_slots(shelves[0])[2], "Selected donor reaches the sticky shelf's free slot")
	# Its shelf is now full; another selected donor still must not trigger a sticky pickup.
	donor = level._get_slot_item(level._get_front_slots(shelves[1])[1])
	level._handle_press_at(donor.global_position)
	level._handle_release_at(donor.global_position)
	level._handle_press_at(anchor.global_position)
	_check(level._blocked_item == null and not feedback.is_active(), "Full destination does not misreport an ordinary drop as a blocked pickup")
	level._handle_press_at(anchor.global_position)
	anchor.queue_free()
	await process_frame
	await process_frame
	level._refresh_sticky_feedback_availability()
	_check(level._blocked_item == null, "Freed item leaves no dangling pointer gesture")
	stages += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
