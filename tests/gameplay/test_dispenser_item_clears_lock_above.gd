extends SceneTree

## Verification that an item standing in a dispenser is never covered by the padlock of a locked shelf
## in the row above it.
##
## A dispenser is packed directly under the row above and lifted to clear the row below, so a
## standard-size item's tip -- a pump nozzle, a unicorn horn -- reached up under the padlock that
## hangs to the bottom of a locked shelf there. The dispenser seats its items smaller to stay clear,
## and this checks that against every item texture rather than one tall example. Run through:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/gameplay/test_dispenser_item_clears_lock_above.gd
##
## The board is supplied inline so verification does not depend on mutable campaign content.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"
const ITEM_SPRITES_PATH := "res://configs/item_sprites.json"
const LOCK_TEXTURE_PATH := "res://assets/ui/lock_shelf_cutout.png"
const ALIGNMENT_TOLERANCE := 0.001
## Visible pixels of the padlock and the item may not touch. The rendered gap for the tallest item is
## a few pixels, and antialiased edge pixels are already counted as visible by `get_used_rect()`.
const MINIMUM_CLEARANCE_PIXELS := 1.0

## A locked standard shelf, a dispenser under it, and a standard shelf under that. The row below is
## what makes the runtime lift the dispenser, so the fixture has to have one to place it as a
## mid-column dispenser is placed in a campaign level.
const LOCK_ABOVE_DISPENSER_CONFIG := {
	"level": 1,
	"time_seconds": 300,
	"row_layouts": [
		{"shelf_count": 1},
		{"shelf_count": 1},
		{"shelf_count": 1},
	],
	"shelves": [
		{"layers": [["candy_bag", "milk_carton", null]], "unlock_after_triples": 5},
		{
			"type": "dispenser",
			"layers": [["soap_pump"], ["candy_bag"], ["milk_carton"]],
		},
		{"layers": [[null, null, null]]},
	],
}

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Dispenser item clearance verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return

	call_deferred("_run")


func _run() -> void:
	await process_frame

	await _test_every_item_clears_the_lock_above()
	await _test_item_takes_the_size_of_the_shelf_it_rests_on()

	await _wait_frames(30)

	if _failures.is_empty():
		print("Dispenser item clearance verification passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_every_item_clears_the_lock_above() -> void:
	var level := await _make_level()
	var dispenser := _find_dispenser(level)
	var locked_shelf := _find_locked_shelf(level)
	if dispenser == null or locked_shelf == null:
		_check(false, "The fixture needs a dispenser and a locked shelf.")
		await _teardown(level)
		return

	var overlay := locked_shelf.get_node_or_null("LockedOverlay") as ShelfLockOverlay
	var lock_sprite := (
		locked_shelf.get_node_or_null("LockedOverlay/VisualRig/LockRig/LockSprite") as Sprite2D
	)
	var slot := (level.call("_get_front_slots", dispenser) as Array)[0] as Node2D
	var item := level.call("_get_slot_item", slot) as ShelfItem
	if overlay == null or not overlay.visible or lock_sprite == null or item == null:
		_check(false, "The locked shelf shows its overlay and the dispenser holds an item.")
		await _teardown(level)
		return

	var lock_bottom := _get_opaque_bottom(lock_sprite, LOCK_TEXTURE_PATH)
	var item_sprite := item.get_node("Sprite2D") as Sprite2D
	var item_textures := level.get("_item_textures") as Dictionary
	var checked := 0
	for entry in _load_item_sprite_entries():
		var item_id := str(entry.get("id", ""))
		var texture := item_textures.get(item_id) as Texture2D
		if texture == null:
			continue

		item.texture = texture
		var item_top := _get_opaque_top(item_sprite, str(entry.get("texture", "")))
		checked += 1
		_check(
			item_top - lock_bottom >= MINIMUM_CLEARANCE_PIXELS,
			"A %s in a dispenser reaches %.1fpx into the padlock above it." % [
				item_id,
				lock_bottom - item_top,
			]
		)

	_check(checked > 0, "The item catalog should provide textures to measure.")
	await _teardown(level)


func _test_item_takes_the_size_of_the_shelf_it_rests_on() -> void:
	var level := await _make_level()
	var dispenser := _find_dispenser(level)
	var target_slot := _find_empty_standard_slot(level)
	if dispenser == null or target_slot == null:
		_check(false, "The fixture needs a dispenser and an empty standard slot.")
		await _teardown(level)
		return

	var dispenser_slot := (level.call("_get_front_slots", dispenser) as Array)[0] as Node2D
	var item := level.call("_get_slot_item", dispenser_slot) as ShelfItem
	var marker := level.call("_get_slot_marker", dispenser_slot) as Marker2D
	var target_marker := level.call("_get_slot_marker", target_slot) as Marker2D
	var seated_scale := DispenserShelf.ITEM_VISUAL_SCALE
	_check(
		seated_scale < ShelfItem.DEFAULT_VISUAL_SCALE,
		"A dispenser seats its items smaller than a standard shelf does."
	)
	_check(
		absf(item.visual_scale - seated_scale) < ALIGNMENT_TOLERANCE,
		"An item built into a dispenser starts at the dispenser's size."
	)

	level.call("_begin_drag", item, marker.global_position)
	await _wait_seconds(ShelfItem.VISUAL_SCALE_SECONDS + 0.1)
	_check(
		absf(item.visual_scale - ShelfItem.DEFAULT_VISUAL_SCALE) < ALIGNMENT_TOLERANCE,
		"An item the player is carrying is the standard size."
	)

	# Released far from every shelf, the carried item goes home and is seated small again.
	level.call("_finish_active_drag", marker.global_position + Vector2(0.0, -4000.0))
	await _wait_seconds(0.6)
	_check(
		level.call("_get_slot_item", dispenser_slot) == item
		and absf(item.visual_scale - seated_scale) < ALIGNMENT_TOLERANCE,
		"An item put back in its dispenser returns to the dispenser's size."
	)

	# Dropped on a standard shelf it stays the standard size.
	level.call("_begin_drag", item, marker.global_position)
	level.call("_move_active_drag", target_marker.global_position)
	level.call("_finish_active_drag", target_marker.global_position)
	await _wait_seconds(0.6)
	_check(
		level.call("_get_slot_item", target_slot) == item
		and absf(item.visual_scale - ShelfItem.DEFAULT_VISUAL_SCALE) < ALIGNMENT_TOLERANCE,
		"An item moved onto a standard shelf is the standard size."
	)

	await _teardown(level)


func _load_item_sprite_entries() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ITEM_SPRITES_PATH))
	if not parsed is Dictionary:
		return []

	return (parsed as Dictionary).get("items", []) as Array


## Bottom edge of the sprite's visible pixels in canvas coordinates. The source PNG is read directly
## because a headless run does not keep imported texture pixels.
func _get_opaque_bottom(sprite: Sprite2D, texture_path: String) -> float:
	var used := _get_used_rect(texture_path)
	var local_bottom := Vector2(0.0, float(used.end.y)) - _get_texture_center(sprite)
	return (sprite.get_global_transform() * (local_bottom + sprite.offset)).y


func _get_opaque_top(sprite: Sprite2D, texture_path: String) -> float:
	var used := _get_used_rect(texture_path)
	var local_top := Vector2(0.0, float(used.position.y)) - _get_texture_center(sprite)
	return (sprite.get_global_transform() * (local_top + sprite.offset)).y


func _get_used_rect(texture_path: String) -> Rect2i:
	var image := Image.load_from_file(ProjectSettings.globalize_path(texture_path))
	if image == null:
		_check(false, "Could not read %s." % texture_path)
		return Rect2i()

	return image.get_used_rect()


## Sprite2D draws a centered texture around its origin. The imported texture and the source PNG share
## dimensions, so the imported size locates the source's rows.
func _get_texture_center(sprite: Sprite2D) -> Vector2:
	if sprite.texture == null:
		return Vector2.ZERO

	return sprite.texture.get_size() * 0.5 if sprite.centered else Vector2.ZERO


func _make_level() -> Node:
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level := level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 1)
	root.add_child(level)
	await process_frame

	level.set("_sound_effects_enabled", false)
	level.call("_apply_level_config", LOCK_ABOVE_DISPENSER_CONFIG)
	# _ready() collects slots after applying its own config; rebuilding the board here has to refresh
	# the same cache or drop targeting would still be pointing at the freed shelves.
	level.call("_collect_slots")
	await process_frame
	return level


func _find_dispenser(level: Node) -> Node2D:
	for shelf in level.call("_get_all_shelves") as Array:
		if shelf is DispenserShelf:
			return shelf as Node2D

	return null


func _find_locked_shelf(level: Node) -> Node2D:
	for shelf in level.call("_get_all_shelves") as Array:
		if bool(level.call("_is_shelf_locked", shelf)):
			return shelf as Node2D

	return null


func _find_empty_standard_slot(level: Node) -> Node2D:
	for shelf in level.call("_get_all_shelves") as Array:
		if shelf is DispenserShelf or bool(level.call("_is_shelf_locked", shelf)):
			continue

		for slot in level.call("_get_front_slots", shelf) as Array:
			if level.call("_get_slot_item", slot) == null:
				return slot as Node2D

	return null


## Lets in-flight move tweens finish before the board goes away, so teardown does not strand
## references to freed nodes.
func _teardown(level: Node) -> void:
	await _wait_seconds(0.5)
	level.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout
