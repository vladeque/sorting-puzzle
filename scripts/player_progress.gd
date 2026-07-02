extends Node

const LocalSaveProviderScript := preload("res://scripts/save_providers/local_save_provider.gd")
const CloudSaveProviderScript := preload("res://scripts/save_providers/cloud_save_provider.gd")
const SAVE_PATH := "user://player_progress.json"
const SAVE_NAME := "player_progress"
const SAVE_VERSION := 1
const MIN_LEVEL := 1
const SAVE_PROVIDER_SETTING := "application/config/save_provider"
const CLOUD_SAVE_NAME_SETTING := "application/config/cloud_save_name"
const CLOUD_SAVE_BRIDGE_SETTING := "application/config/cloud_save_bridge_singleton"
const SAVE_PROVIDER_LOCAL := "local"
const SAVE_PROVIDER_CLOUD := "cloud"
const ABILITY_HAMMER := "hammer"
const ABILITY_SHUFFLE := "shuffle"
const ABILITY_HIGHLIGHT := "highlight"
const DEFAULT_ABILITY_USES := {
	ABILITY_HAMMER: 3,
	ABILITY_SHUFFLE: 3,
	ABILITY_HIGHLIGHT: 3,
}

var _data := {}
var _save_provider: SaveProvider


func _ready() -> void:
	_save_provider = _create_save_provider()
	load_progress()


func load_progress() -> void:
	_ensure_save_provider()
	var result := _save_provider.load_data()
	if bool(result.get("ok", false)):
		var loaded_data := result.get("data", {}) as Dictionary
		if loaded_data == null:
			loaded_data = {}

		_data = _sanitize_data(loaded_data)
		return

	push_warning("Could not load %s save: %s" % [_save_provider.get_provider_name(), result.get("error", "")])
	_data = _default_data()


func save_progress() -> void:
	_ensure_save_provider()
	var result := _save_provider.save_data(_data)
	if not bool(result.get("ok", false)):
		push_error("Could not save %s progress: %s" % [_save_provider.get_provider_name(), result.get("error", "")])


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


func get_save_provider_name() -> String:
	_ensure_save_provider()
	return _save_provider.get_provider_name()


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


func _ensure_save_provider() -> void:
	if _save_provider == null:
		_save_provider = _create_save_provider()


func _create_save_provider() -> SaveProvider:
	var provider_id := str(_get_project_setting(SAVE_PROVIDER_SETTING, SAVE_PROVIDER_LOCAL)).to_lower()
	if provider_id == SAVE_PROVIDER_CLOUD:
		return CloudSaveProviderScript.new(
			str(_get_project_setting(CLOUD_SAVE_NAME_SETTING, SAVE_NAME)),
			str(_get_project_setting(CLOUD_SAVE_BRIDGE_SETTING, ""))
		)

	return LocalSaveProviderScript.new(SAVE_PATH)


func _get_project_setting(setting_name: String, default_value):
	if ProjectSettings.has_setting(setting_name):
		return ProjectSettings.get_setting(setting_name)

	return default_value
