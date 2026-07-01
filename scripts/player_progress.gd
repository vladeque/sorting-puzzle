extends Node

const SAVE_PATH := "user://player_progress.json"
const SAVE_VERSION := 1
const MIN_LEVEL := 1
const ABILITY_HAMMER := "hammer"
const ABILITY_SHUFFLE := "shuffle"
const ABILITY_HIGHLIGHT := "highlight"
const DEFAULT_ABILITY_USES := {
	ABILITY_HAMMER: 3,
	ABILITY_SHUFFLE: 3,
	ABILITY_HIGHLIGHT: 3,
}

var _data := {}


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	var loaded_data := {}
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				loaded_data = parsed
			else:
				push_warning("Ignoring invalid player progress save.")
		else:
			push_warning("Could not open player progress save for reading.")

	_data = _sanitize_data(loaded_data)


func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open player progress save for writing.")
		return

	file.store_string(JSON.stringify(_data, "\t"))


func get_current_level() -> int:
	return int(_data.get("current_level", MIN_LEVEL))


func get_highest_completed_level() -> int:
	return int(_data.get("highest_completed_level", 0))


func get_ability_uses() -> Dictionary:
	var ability_uses := _data.get("ability_uses", {}) as Dictionary
	if ability_uses == null:
		return DEFAULT_ABILITY_USES.duplicate()

	return ability_uses.duplicate()


func spend_ability(ability_id: StringName) -> bool:
	var ability_key := String(ability_id)
	var ability_uses := _data.get("ability_uses", {}) as Dictionary
	if ability_uses == null:
		ability_uses = DEFAULT_ABILITY_USES.duplicate()
		_data["ability_uses"] = ability_uses

	var uses_left := int(ability_uses.get(ability_key, 0))
	if uses_left <= 0:
		return false

	ability_uses[ability_key] = uses_left - 1
	save_progress()
	return true


func complete_level(level_number: int) -> void:
	if level_number < MIN_LEVEL:
		return

	_data["highest_completed_level"] = maxi(get_highest_completed_level(), level_number)
	if level_number == get_current_level():
		_data["current_level"] = level_number + 1

	save_progress()


func reset_progress() -> void:
	_data = _default_data()
	save_progress()


func _sanitize_data(raw_data: Dictionary) -> Dictionary:
	var sanitized := _default_data()
	sanitized["version"] = int(raw_data.get("version", SAVE_VERSION))
	sanitized["current_level"] = maxi(int(raw_data.get("current_level", MIN_LEVEL)), MIN_LEVEL)
	sanitized["highest_completed_level"] = maxi(int(raw_data.get("highest_completed_level", 0)), 0)

	var raw_ability_uses := raw_data.get("ability_uses", {}) as Dictionary
	if raw_ability_uses != null:
		var ability_uses := sanitized["ability_uses"] as Dictionary
		for ability_key in DEFAULT_ABILITY_USES.keys():
			ability_uses[ability_key] = maxi(int(raw_ability_uses.get(ability_key, ability_uses[ability_key])), 0)

	return sanitized


func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"current_level": MIN_LEVEL,
		"highest_completed_level": 0,
		"ability_uses": DEFAULT_ABILITY_USES.duplicate(),
	}
