extends SceneTree

## Focused regression for the reusable locked-shelf overlay. The broader UI-003 suite also covers
## this behavior, but this test stays independent from unrelated gameplay modal assertions.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Shelf lock overlay verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_level_progression_feedback()
	await _test_compact_layout_and_restart_safe_motion()
	await _wait_frames(10)

	if _failures.is_empty():
		print("Shelf lock overlay verification passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_level_progression_feedback() -> void:
	var level_scene := load("res://level.tscn") as PackedScene
	var level := level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 7)
	root.add_child(level)
	await process_frame

	var shelf: Node2D = null
	for candidate in level.call("_get_all_shelves"):
		if int(level.call("_get_shelf_unlock_requirement", candidate)) > 1:
			shelf = candidate
			break

	if shelf == null:
		_failures.append("Level 7 should provide a locked shelf with at least two remaining clears.")
		level.free()
		return

	var requirement := int(level.call("_get_shelf_unlock_requirement", shelf))
	var overlay := shelf.get_node("LockedOverlay") as ShelfLockOverlay
	var chain_rig := overlay.get_node("VisualRig/ChainRig") as Node2D
	var lock_rig := overlay.get_node("VisualRig/LockRig") as Node2D
	var badge := overlay.get_node("VisualRig/CountdownBadge") as Node2D
	var label := overlay.get_node("VisualRig/CountdownBadge/RemainingLabel") as Label
	var ad_label := overlay.get_node("VisualRig/LockRig/AdLabel") as Label
	var chain_rest_position := chain_rig.position
	var badge_rest_scale := badge.scale

	_check(ad_label.text == "AD", "Lock should retain the selected decorative AD copy.")
	level.set("_triples_cleared", requirement - 2)
	level.call("_update_locked_shelves")
	_check(label.text == "2", "Setup should show two clears remaining.")

	# Every clearing source, including Hammer, funnels through this same method. Exercising it here
	# protects Hammer's existing contribution without coupling the visual test to Hammer VFX timing.
	level.call("_record_triples_cleared", 1)
	await process_frame
	_check(label.text == "1", "A recorded triple should decrement the visible countdown.")
	_check(
		not chain_rig.position.is_equal_approx(chain_rest_position),
		"A countdown decrement should shake the crossed chains."
	)
	_check(not is_zero_approx(lock_rig.rotation), "A countdown decrement should swing the lock.")
	_check(
		not badge.scale.is_equal_approx(badge_rest_scale),
		"A countdown decrement should pop the circular badge."
	)
	await _wait_seconds(0.35)
	_check(
		chain_rig.position.is_equal_approx(chain_rest_position)
		and is_zero_approx(lock_rig.rotation)
		and badge.scale.is_equal_approx(badge_rest_scale),
		"Decrement feedback should settle completely."
	)

	level.call("_record_triples_cleared", 1)
	await process_frame
	_check(label.text == "0", "The opening clear should visibly reach zero.")
	_check(overlay.visible, "Chains should remain visible while their release animation begins.")
	_check(
		bool(level.call("_is_shelf_move_source_eligible", shelf)),
		"Unlock animation must not delay shelf eligibility."
	)
	await _wait_seconds(0.5)
	_check(not overlay.visible, "Released chain overlay should hide after its animation.")

	level.free()
	await process_frame


func _test_compact_layout_and_restart_safe_motion() -> void:
	var dispenser_scene := load("res://scenes/dispenser_shelf.tscn") as PackedScene
	var dispenser := dispenser_scene.instantiate()
	root.add_child(dispenser)
	await process_frame

	var overlay := dispenser.get_node("LockedOverlay") as ShelfLockOverlay
	var shade := overlay.get_node("Shade") as Polygon2D
	var chain := overlay.get_node("VisualRig/ChainRig/ChainBack") as Sprite2D
	var chain_rig := overlay.get_node("VisualRig/ChainRig") as Node2D
	var lock_rig := overlay.get_node("VisualRig/LockRig") as Node2D
	var badge := overlay.get_node("VisualRig/CountdownBadge") as Node2D
	var label := overlay.get_node("VisualRig/CountdownBadge/RemainingLabel") as Label
	var chain_rest_position := chain_rig.position
	var lock_rest_position := lock_rig.position
	var badge_rest_scale := badge.scale

	overlay.show_locked(123)
	_check(overlay.compact_layout, "Dispenser should opt into the compact layout.")
	_check(label.text == "123", "Compact badge should retain a three-digit count.")
	_check(
		is_equal_approx(shade.polygon[0].x, -40.0)
		and is_equal_approx(shade.polygon[1].x, 40.0),
		"Compact shade should fit the dispenser aperture."
	)
	_check(chain.scale.x <= 0.201, "Compact crossed chains should fit the narrow shelf.")

	# A second update before the first feedback settles must replace its tweens rather than stack
	# conflicting transforms.
	overlay.show_locked(122)
	await process_frame
	overlay.show_locked(121)
	await _wait_seconds(0.4)
	_check(label.text == "121", "Rapid updates should keep the newest countdown value.")
	_check(
		chain_rig.position.is_equal_approx(chain_rest_position)
		and lock_rig.position.is_equal_approx(lock_rest_position)
		and is_zero_approx(lock_rig.rotation)
		and badge.scale.is_equal_approx(badge_rest_scale),
		"Rapid updates should still settle to authored compact transforms."
	)

	dispenser.free()
	await process_frame


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
