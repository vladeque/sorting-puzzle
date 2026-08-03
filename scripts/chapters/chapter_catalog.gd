extends Node

const CONFIG_PATH := "res://configs/chapters.json"
const LEVEL_PATH_TEMPLATE := "res://configs/levels/level_%03d.json"

var _chapters: Array[Dictionary] = []
var _chapters_by_id: Dictionary = {}
var _level_locations: Dictionary = {}
var _default_unlock_required_levels := 25
var _valid := false
var _diagnostic := ""


func _ready() -> void:
	load_catalog()


func load_catalog(path: String = CONFIG_PATH) -> bool:
	_reset()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Could not open chapter catalog: %s" % path)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _fail("Chapter catalog must contain a JSON object.")
	var document := parsed as Dictionary
	if int(document.get("schema_version", 0)) != 1:
		return _fail("Chapter catalog schema_version must be 1.")
	_default_unlock_required_levels = int(document.get("default_unlock_required_levels", 0))
	if _default_unlock_required_levels < 1:
		return _fail("Default chapter unlock requirement must be positive.")

	var raw_chapters := document.get("chapters", []) as Array
	if raw_chapters == null or raw_chapters.is_empty():
		return _fail("Chapter catalog must contain at least one chapter.")
	for chapter_index in range(raw_chapters.size()):
		var raw_chapter := raw_chapters[chapter_index] as Dictionary
		if raw_chapter == null:
			return _fail("Chapter %d must be an object." % (chapter_index + 1))
		var normalized := _normalize_chapter(raw_chapter, chapter_index)
		if normalized.is_empty():
			return false
		_chapters.append(normalized)
		_chapters_by_id[normalized["id"]] = normalized

	_valid = true
	return true


func is_valid() -> bool:
	return _valid


func get_diagnostic() -> String:
	return _diagnostic


func get_default_unlock_required_levels() -> int:
	return _default_unlock_required_levels


func get_chapters() -> Array[Dictionary]:
	return _chapters.duplicate(true)


func get_chapter(chapter_id: String) -> Dictionary:
	if not _chapters_by_id.has(chapter_id):
		return {}
	return (_chapters_by_id.get(chapter_id, {}) as Dictionary).duplicate(true)


func get_first_chapter_id() -> String:
	return str(_chapters[0].get("id", "")) if not _chapters.is_empty() else ""


func get_previous_chapter_id(chapter_id: String) -> String:
	return str((_chapters_by_id.get(chapter_id, {}) as Dictionary).get("previous_chapter_id", ""))


func get_unlock_requirement(chapter_id: String) -> int:
	return maxi(int((_chapters_by_id.get(chapter_id, {}) as Dictionary).get("required_completed_levels", 0)), 0)


func get_level_ids(chapter_id: String) -> Array[int]:
	var result: Array[int] = []
	var chapter := _chapters_by_id.get(chapter_id, {}) as Dictionary
	for level_id in chapter.get("level_ids", []) as Array:
		result.append(int(level_id))
	return result


func get_chapter_for_level(level_id: int) -> Dictionary:
	var location := _level_locations.get(level_id, {}) as Dictionary
	return get_chapter(str(location.get("chapter_id", "")))


func get_chapter_id_for_level(level_id: int) -> String:
	return str((_level_locations.get(level_id, {}) as Dictionary).get("chapter_id", ""))


func get_local_level_number(level_id: int) -> int:
	return int((_level_locations.get(level_id, {}) as Dictionary).get("chapter_level", 0))


func get_background_texture_path(chapter_id: String) -> String:
	return str((_chapters_by_id.get(chapter_id, {}) as Dictionary).get("background_texture", ""))


func get_gameplay_background_mode(chapter_id: String) -> String:
	return str(
		(_chapters_by_id.get(chapter_id, {}) as Dictionary).get(
			"gameplay_background_mode", "artwork"
		)
	)


func get_selection_preview_path(chapter_id: String) -> String:
	return str((_chapters_by_id.get(chapter_id, {}) as Dictionary).get("selection_preview", ""))


func _normalize_chapter(raw: Dictionary, chapter_index: int) -> Dictionary:
	var chapter_id := str(raw.get("id", "")).strip_edges()
	var title := str(raw.get("title", "")).strip_edges()
	var order := int(raw.get("order", 0))
	if chapter_id.is_empty() or _chapters_by_id.has(chapter_id):
		_fail("Chapter IDs must be unique and non-empty.")
		return {}
	if title.is_empty() or order != chapter_index + 1:
		_fail("Chapter titles must be non-empty and order must start at 1 without gaps.")
		return {}

	var background_texture := str(raw.get("background_texture", ""))
	var selection_preview := str(raw.get("selection_preview", ""))
	var gameplay_background_mode := str(raw.get("gameplay_background_mode", ""))
	if gameplay_background_mode not in ["legacy", "artwork"]:
		_fail("Chapter '%s' has an invalid gameplay background mode." % chapter_id)
		return {}
	if not ResourceLoader.exists(background_texture) or not ResourceLoader.exists(selection_preview):
		_fail("Chapter '%s' references a missing presentation texture." % chapter_id)
		return {}

	var unlock := raw.get("unlock", {}) as Dictionary
	var previous_chapter_id = unlock.get("previous_chapter_id")
	var default_requirement := 0 if chapter_index == 0 else _default_unlock_required_levels
	var required_completed_levels := int(unlock.get("required_completed_levels", default_requirement))
	if chapter_index == 0:
		if previous_chapter_id != null or required_completed_levels != 0:
			_fail("The first chapter must be unlocked by default.")
			return {}
		previous_chapter_id = ""
	else:
		var expected_previous_id := str(_chapters[chapter_index - 1].get("id", ""))
		if str(previous_chapter_id) != expected_previous_id or required_completed_levels < 1:
			_fail("Every later chapter must reference the immediately previous chapter.")
			return {}

	var level_ids: Array[int] = []
	for raw_level_id in raw.get("level_ids", []) as Array:
		var level_id := int(raw_level_id)
		if level_id < 1 or _level_locations.has(level_id):
			_fail("Chapter level IDs must be unique positive integers.")
			return {}
		var level_path := LEVEL_PATH_TEMPLATE % level_id
		if not FileAccess.file_exists(level_path):
			_fail("Chapter '%s' references missing level %d." % [chapter_id, level_id])
			return {}
		var level_document := _load_json(level_path)
		if int(level_document.get("level", 0)) != level_id:
			_fail("Level %d does not declare its own campaign ID." % level_id)
			return {}
		level_ids.append(level_id)
		_level_locations[level_id] = {
			"chapter_id": chapter_id,
			"chapter_level": level_ids.size(),
		}
	if chapter_index == 0 and level_ids.is_empty():
		_fail("The first chapter must contain at least one level.")
		return {}

	return {
		"id": chapter_id,
		"order": order,
		"title": title,
		"level_ids": level_ids,
		"previous_chapter_id": str(previous_chapter_id),
		"required_completed_levels": required_completed_levels,
		"gameplay_background_mode": gameplay_background_mode,
		"background_texture": background_texture,
		"selection_preview": selection_preview,
	}


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _fail(message: String) -> bool:
	_valid = false
	_diagnostic = message
	push_error(message)
	return false


func _reset() -> void:
	_chapters.clear()
	_chapters_by_id.clear()
	_level_locations.clear()
	_valid = false
	_diagnostic = ""
