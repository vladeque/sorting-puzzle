extends SceneTree

const LEVEL_SCENE_PATH := "res://level.tscn"
const FIRST_MATERIALIZED_LEVEL := 1
const LAST_MATERIALIZED_LEVEL := 8

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	for level_number in range(FIRST_MATERIALIZED_LEVEL, LAST_MATERIALIZED_LEVEL + 1):
		await _check_level_items(level_number)

	if _failures.is_empty():
		print("Item progression runtime tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_level_items(level_number: int) -> void:
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	_check(level_scene != null, "level scene loads for level %d" % level_number)
	if level_scene == null:
		return
	var level = level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", level_number)
	get_root().add_child(level)
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED

	var items := level.find_children("*", "ShelfItem", true, false)
	_check(not items.is_empty(), "level %d instantiates items" % level_number)
	for raw_item in items:
		var item := raw_item as ShelfItem
		_check(item != null, "level %d item has ShelfItem type" % level_number)
		if item == null:
			continue
		_check(not item.item_id.is_empty(), "level %d item has a concrete ID" % level_number)
		_check(item.texture != null, "level %d item '%s' has a loaded texture" % [level_number, item.item_id])

	level.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
