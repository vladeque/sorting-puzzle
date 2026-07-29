extends SceneTree

const ITEM_CONFIG_PATH := "res://configs/item_sprites.json"
const LEVEL_CONFIG_TEMPLATE := "res://configs/levels/level_%03d.json"
const FIRST_MATERIALIZED_LEVEL := 1
const LAST_MATERIALIZED_LEVEL := 8

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var item_textures := _load_item_textures()
	for level_number in range(FIRST_MATERIALIZED_LEVEL, LAST_MATERIALIZED_LEVEL + 1):
		_check_level_items(level_number, item_textures)
	item_textures.clear()

	if _failures.is_empty():
		print("Item progression runtime tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _load_item_textures() -> Dictionary:
	var textures := {}
	var item_config := _load_json_object(ITEM_CONFIG_PATH)
	for raw_item in item_config.get("items", []) as Array:
		var item := raw_item as Dictionary
		if item == null:
			continue
		var item_id := str(item.get("id", ""))
		var texture_path := str(item.get("texture", ""))
		var texture := load(texture_path) as Texture2D
		_check(not item_id.is_empty(), "item catalog entry has an ID")
		_check(texture != null, "item '%s' has a loaded texture" % item_id)
		if not item_id.is_empty() and texture != null:
			textures[item_id] = texture
	return textures


func _check_level_items(level_number: int, item_textures: Dictionary) -> void:
	var path := LEVEL_CONFIG_TEMPLATE % level_number
	var level := _load_json_object(path)
	var item_count := 0
	for raw_shelf in level.get("shelves", []) as Array:
		var shelf := raw_shelf as Dictionary
		if shelf == null:
			continue
		for raw_layer in shelf.get("layers", []) as Array:
			var layer := raw_layer as Array
			if layer == null:
				continue
			for item_value in layer:
				if item_value == null:
					continue
				item_count += 1
				var item_id := str(item_value)
				_check(
					not item_id.begins_with("item_"),
					"level %d contains only concrete item IDs" % level_number
				)
				_check(
					item_textures.has(item_id),
					"level %d item '%s' has a loaded catalog texture" % [level_number, item_id]
				)
	_check(item_count > 0, "level %d contains materialized items" % level_number)


func _load_json_object(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "%s can be opened" % path)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary, "%s contains a JSON object" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
