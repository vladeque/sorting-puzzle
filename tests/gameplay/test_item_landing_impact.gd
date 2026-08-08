extends SceneTree

## Focused verification for the ShelfItem landing squash-and-stretch (scripts/item.gd's
## play_land_impact). Covers the impact shape, the planted contact pivot, and the regression that
## motivated the separate land_squash channel: highlight/outline updates arriving mid-bounce used to
## overwrite the sprite scale with a uniform value and flatten the animation.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"

## Sampled inside each phase rather than at its boundary, so the assertions do not depend on landing
## exactly on a frame edge. The impact runs squash 0-70ms, stretch 70-140ms, settle 140-230ms.
const SQUASH_SAMPLE_SECONDS := 0.045
const STRETCH_SAMPLE_SECONDS := 0.075
const SETTLE_SAMPLE_SECONDS := 0.2

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Item landing impact verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level = level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 2)
	root.add_child(level)
	await process_frame
	await process_frame

	var visible_items := level.call("_get_visible_items") as Array
	_check(not visible_items.is_empty(), "Level 2 exposes at least one visible item to land.")
	if visible_items.is_empty():
		_finish(level)
		return

	var item := visible_items[0] as ShelfItem
	var sprite := item.get_node("Sprite2D") as Sprite2D
	var outline_sprite := item.get_node("OutlineSprite") as Sprite2D
	var resting_scale := sprite.scale

	_check(
		is_equal_approx(resting_scale.x, resting_scale.y),
		"Item rests at a uniform sprite scale."
	)
	_check(
		is_zero_approx(sprite.position.y),
		"Item rests with no contact pivot offset."
	)

	await _verify_squash_phase(item, sprite, resting_scale)
	await _verify_highlight_does_not_flatten_impact(item, sprite, outline_sprite)
	await _verify_stretch_phase(item, sprite, resting_scale)
	await _verify_settle(item, sprite, resting_scale)
	await _verify_reset_cancels_impact(item, sprite, resting_scale)
	await _verify_placement_paths(level, item, sprite)

	_finish(level)


func _verify_squash_phase(item: ShelfItem, sprite: Sprite2D, resting_scale: Vector2) -> void:
	item.play_land_impact()
	await create_timer(SQUASH_SAMPLE_SECONDS).timeout

	_check(
		sprite.scale.x > resting_scale.x and sprite.scale.y < resting_scale.y,
		"Landing compresses the item wider and shorter than its resting shape."
	)
	_check(
		sprite.position.y > 0.0,
		"Squash pivots on the item's contact point by pushing the sprite down, not lifting it."
	)


func _verify_highlight_does_not_flatten_impact(
	item: ShelfItem,
	sprite: Sprite2D,
	outline_sprite: Sprite2D
) -> void:
	# Regression guard: these writers own the uniform highlight scale and used to stomp the bounce.
	item.set_highlight_scale(1.234)
	item.set_outline(true, Color(1.0, 0.86, 0.18, 1.0), 4.0)

	_check(
		not is_equal_approx(sprite.scale.x, sprite.scale.y),
		"Highlight and outline updates mid-bounce keep the squash instead of flattening it."
	)
	_check(
		outline_sprite.scale.is_equal_approx(sprite.scale)
		and is_equal_approx(outline_sprite.position.y, sprite.position.y),
		"Outline sprite tracks the squashed sprite exactly."
	)

	item.set_outline(false, Color(1.0, 0.86, 0.18, 1.0), 0.0)
	item.set_highlight_scale(1.0)


func _verify_stretch_phase(item: ShelfItem, sprite: Sprite2D, resting_scale: Vector2) -> void:
	await create_timer(STRETCH_SAMPLE_SECONDS).timeout

	_check(
		sprite.scale.y > resting_scale.y,
		"Landing rebounds past the resting height instead of easing straight back to it."
	)
	_check(
		sprite.position.y < 0.0,
		"Stretch lifts the sprite while keeping the same contact pivot."
	)


func _verify_settle(item: ShelfItem, sprite: Sprite2D, resting_scale: Vector2) -> void:
	await create_timer(SETTLE_SAMPLE_SECONDS).timeout

	_check(
		sprite.scale.is_equal_approx(resting_scale),
		"Landing settles back to the exact resting scale."
	)
	_check(
		is_zero_approx(sprite.position.y),
		"Landing settles back to the exact resting position."
	)
	_check(
		item.land_squash.is_equal_approx(Vector2.ONE),
		"Landing leaves no residual squash state."
	)


func _verify_reset_cancels_impact(
	item: ShelfItem,
	sprite: Sprite2D,
	resting_scale: Vector2
) -> void:
	item.play_land_impact()
	await create_timer(SQUASH_SAMPLE_SECONDS).timeout
	item.reset_land_impact()

	_check(
		sprite.scale.is_equal_approx(resting_scale) and is_zero_approx(sprite.position.y),
		"reset_land_impact restores the resting shape immediately."
	)

	# The killed tween must not resume and re-deform the item on later frames.
	await create_timer(SQUASH_SAMPLE_SECONDS).timeout
	_check(
		sprite.scale.is_equal_approx(resting_scale),
		"A reset landing stays reset instead of resuming its remaining phases."
	)


func _verify_placement_paths(level: Node, item: ShelfItem, sprite: Sprite2D) -> void:
	var slot := item.get_parent() as Node2D

	level.call("_place_item_in_slot", item, slot, false)
	await create_timer(SQUASH_SAMPLE_SECONDS).timeout
	_check(
		item.land_squash.is_equal_approx(Vector2.ONE),
		"A silent forced restore does not play the landing impact."
	)

	level.call("_place_item_in_slot", item, slot, true)
	await create_timer(SQUASH_SAMPLE_SECONDS).timeout
	_check(
		not is_equal_approx(sprite.scale.x, sprite.scale.y),
		"A player-visible drop into a slot plays the landing impact."
	)


func _finish(level: Node) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Item landing impact verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
