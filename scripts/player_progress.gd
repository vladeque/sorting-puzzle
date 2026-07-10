extends Node

const LocalSaveProviderScript := preload("res://scripts/save_providers/local_save_provider.gd")
const CloudSaveProviderScript := preload("res://scripts/save_providers/cloud_save_provider.gd")
const SAVE_PATH := "user://player_progress.json"
const SAVE_NAME := "player_progress"
const SAVE_VERSION := 2
const MIN_LEVEL := 1
const SAVE_PROVIDER_SETTING := "application/config/save_provider"
const CLOUD_SAVE_NAME_SETTING := "application/config/cloud_save_name"
const CLOUD_SAVE_BRIDGE_SETTING := "application/config/cloud_save_bridge_singleton"
const SAVE_PROVIDER_LOCAL := "local"
const SAVE_PROVIDER_CLOUD := "cloud"
const ABILITY_HAMMER := "hammer"
const ABILITY_SHUFFLE := "shuffle"
const ABILITY_HIGHLIGHT := "highlight"
const DEFAULT_AVATAR_ID := "avatar_cat"
const PLAYER_NAME_PREFIX := "player_"
const PLAYER_NAME_RANDOM_ALPHABET := "abcdefghijklmnopqrstuvwxyz0123456789"
const PLAYER_NAME_RANDOM_LENGTH := 5
const REWARD_CHEST_GOALS_CONFIG := "res://configs/reward_chest_goals.json"
const DEFAULT_COINS := 300
const DEFAULT_REWARD_CHEST_GOALS := [
	{"stars": 500, "coin_reward": 100},
	{"stars": 1000, "coin_reward": 225},
	{"stars": 1500, "coin_reward": 375},
	{"stars": 2000, "coin_reward": 550},
	{"stars": 3000, "coin_reward": 900},
]
const AVAILABLE_AVATAR_IDS := [
	"avatar_bear",
	"avatar_cat",
	"avatar_cow",
	"avatar_deer",
	"avatar_dog",
	"avatar_dolphin",
	"avatar_elephant",
	"avatar_frog",
	"avatar_hamster",
	"avatar_koala",
	"avatar_lion",
	"avatar_monkey",
	"avatar_owl",
	"avatar_penguin",
	"avatar_sheep",
	"avatar_sloth",
	"avatar_tiger",
	"avatar_turtle",
]
const AVATAR_TEXTURE_PATH_FORMAT := "res://assets/ui/avatars/%s.png"
const MAX_LIVES := 5
const LIFE_RESTORE_SECONDS := 3600
const DEFAULT_ABILITY_USES := {
	ABILITY_HAMMER: 3,
	ABILITY_SHUFFLE: 3,
	ABILITY_HIGHLIGHT: 3,
}
const DEFAULT_DISABLED_SETTINGS := {
	"music": false,
	"sound_effects": false,
	"vibration": false,
}

var _data := {}
var _save_provider: SaveProvider
var _reward_chest_goals := []


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

		var sanitized_data := _sanitize_data(loaded_data)
		var should_save_sanitized_data := loaded_data != sanitized_data
		_data = sanitized_data
		if _refresh_lives_state() or should_save_sanitized_data:
			save_progress()
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


func get_coins() -> int:
	return maxi(int(_data.get("coins", DEFAULT_COINS)), 0)


func spend_coins(amount: int) -> bool:
	var normalized_amount := maxi(amount, 0)
	if normalized_amount <= 0:
		return true

	var coins := get_coins()
	if coins < normalized_amount:
		return false

	_data["coins"] = coins - normalized_amount
	save_progress()
	return true


func get_reward_chest_progress() -> Dictionary:
	var goals := _get_reward_chest_goals()
	var goal_index := _get_reward_chest_goal_index(goals)
	var active_goal := goals[goal_index] as Dictionary
	return {
		"stars": maxi(int(_data.get("reward_chest_stars", 0)), 0),
		"goal": int(active_goal.get("stars", 1)),
		"goal_index": goal_index,
		"coin_reward": int(active_goal.get("coin_reward", 0)),
	}


func add_reward_chest_stars(star_count: int) -> void:
	if _apply_reward_chest_stars(star_count):
		save_progress()


func get_available_avatar_ids() -> Array:
	return AVAILABLE_AVATAR_IDS.duplicate()


func get_avatar_id() -> String:
	return _sanitize_avatar_id(str(_data.get("avatar_id", DEFAULT_AVATAR_ID)))


func get_avatar_texture_path(avatar_id: String) -> String:
	return AVATAR_TEXTURE_PATH_FORMAT % _sanitize_avatar_id(avatar_id)


func get_player_name() -> String:
	return _sanitize_player_name(str(_data.get("player_name", "")))


func get_disabled_settings() -> Dictionary:
	var disabled_settings := _data.get("settings_disabled", {}) as Dictionary
	if disabled_settings == null:
		return DEFAULT_DISABLED_SETTINGS.duplicate()

	return disabled_settings.duplicate()


func is_setting_disabled(setting_id: StringName) -> bool:
	var disabled_settings := get_disabled_settings()
	return bool(disabled_settings.get(String(setting_id), false))


func set_setting_disabled(setting_id: StringName, is_disabled: bool) -> bool:
	var setting_key := String(setting_id)
	if not DEFAULT_DISABLED_SETTINGS.has(setting_key):
		return false

	var disabled_settings := get_disabled_settings()
	if bool(disabled_settings.get(setting_key, false)) == is_disabled:
		return true

	disabled_settings[setting_key] = is_disabled
	_data["settings_disabled"] = disabled_settings
	save_progress()
	return true


func set_avatar_id(avatar_id: String) -> bool:
	if not AVAILABLE_AVATAR_IDS.has(avatar_id):
		return false

	if get_avatar_id() == avatar_id:
		return true

	_data["avatar_id"] = avatar_id
	save_progress()
	return true


func set_player_name(player_name: String) -> bool:
	var sanitized_player_name := _sanitize_player_name(player_name, get_player_name())
	if get_player_name() == sanitized_player_name:
		return true

	_data["player_name"] = sanitized_player_name
	save_progress()
	return true


func set_profile(avatar_id: String, player_name: String) -> bool:
	if not AVAILABLE_AVATAR_IDS.has(avatar_id):
		return false

	var sanitized_player_name := _sanitize_player_name(player_name, get_player_name())
	var did_change := false
	if get_avatar_id() != avatar_id:
		_data["avatar_id"] = avatar_id
		did_change = true
	if get_player_name() != sanitized_player_name:
		_data["player_name"] = sanitized_player_name
		did_change = true

	if did_change:
		save_progress()

	return true


func get_lives() -> int:
	refresh_lives()
	return int(_data.get("lives", MAX_LIVES))


func get_max_lives() -> int:
	return MAX_LIVES


func get_next_life_restore_seconds_remaining() -> int:
	refresh_lives()
	if get_lives() >= MAX_LIVES:
		return 0

	var next_restore_unix := int(_data.get("next_life_restore_unix", 0))
	if next_restore_unix <= 0:
		return LIFE_RESTORE_SECONDS

	var now_unix := int(Time.get_unix_time_from_system())
	return maxi(next_restore_unix - now_unix, 0)


func refresh_lives() -> void:
	if _refresh_lives_state():
		save_progress()


func spend_life() -> bool:
	refresh_lives()
	var lives := int(_data.get("lives", MAX_LIVES))
	if lives <= 0:
		return false

	_data["lives"] = lives - 1
	if int(_data.get("lives", 0)) < MAX_LIVES and int(_data.get("next_life_restore_unix", 0)) <= 0:
		_data["next_life_restore_unix"] = int(Time.get_unix_time_from_system()) + LIFE_RESTORE_SECONDS

	save_progress()
	return true


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


func complete_level(level_number: int, earned_stars: int = 0) -> void:
	if level_number < MIN_LEVEL:
		return

	var completes_current_level := level_number == get_current_level()
	_data["highest_completed_level"] = maxi(get_highest_completed_level(), level_number)
	if completes_current_level:
		_data["current_level"] = level_number + 1
		_apply_reward_chest_stars(earned_stars)
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
	sanitized["lives"] = clampi(int(raw_data.get("lives", MAX_LIVES)), 0, MAX_LIVES)
	sanitized["next_life_restore_unix"] = maxi(int(raw_data.get("next_life_restore_unix", 0)), 0)
	sanitized["coins"] = maxi(int(raw_data.get("coins", DEFAULT_COINS)), 0)
	sanitized["avatar_id"] = _sanitize_avatar_id(str(raw_data.get("avatar_id", DEFAULT_AVATAR_ID)))
	sanitized["player_name"] = _sanitize_player_name(str(raw_data.get("player_name", sanitized["player_name"])), sanitized["player_name"])
	sanitized["settings_disabled"] = _sanitize_disabled_settings(raw_data.get("settings_disabled", {}))
	var reward_chest_state := _normalize_reward_chest_progress(
		maxi(int(raw_data.get("reward_chest_stars", 0)), 0),
		maxi(int(raw_data.get("reward_chest_goal_index", 0)), 0)
	)
	sanitized["reward_chest_stars"] = reward_chest_state["stars"]
	sanitized["reward_chest_goal_index"] = reward_chest_state["goal_index"]
	if int(sanitized["lives"]) >= MAX_LIVES:
		sanitized["next_life_restore_unix"] = 0
	elif int(sanitized["next_life_restore_unix"]) <= 0:
		sanitized["next_life_restore_unix"] = int(Time.get_unix_time_from_system()) + LIFE_RESTORE_SECONDS

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
		"lives": MAX_LIVES,
		"next_life_restore_unix": 0,
		"coins": DEFAULT_COINS,
		"ability_uses": DEFAULT_ABILITY_USES.duplicate(),
		"avatar_id": DEFAULT_AVATAR_ID,
		"player_name": _generate_player_name(),
		"settings_disabled": DEFAULT_DISABLED_SETTINGS.duplicate(),
		"reward_chest_stars": 0,
		"reward_chest_goal_index": 0,
	}


func _sanitize_avatar_id(avatar_id: String) -> String:
	if AVAILABLE_AVATAR_IDS.has(avatar_id):
		return avatar_id

	return DEFAULT_AVATAR_ID


func _sanitize_player_name(player_name: String, fallback_name: String = "") -> String:
	var sanitized_name := player_name.strip_edges()
	if sanitized_name.is_empty():
		return fallback_name if not fallback_name.is_empty() else _generate_player_name()

	return sanitized_name


func _sanitize_disabled_settings(raw_settings) -> Dictionary:
	var sanitized := DEFAULT_DISABLED_SETTINGS.duplicate()
	if not (raw_settings is Dictionary):
		return sanitized

	var raw_dictionary := raw_settings as Dictionary
	for setting_key in DEFAULT_DISABLED_SETTINGS.keys():
		sanitized[setting_key] = bool(raw_dictionary.get(setting_key, sanitized[setting_key]))

	return sanitized


func _apply_reward_chest_stars(star_count: int) -> bool:
	if star_count <= 0:
		return false

	var normalized := _normalize_reward_chest_progress(
		maxi(int(_data.get("reward_chest_stars", 0)), 0) + star_count,
		_get_reward_chest_goal_index(_get_reward_chest_goals())
	)
	_data["reward_chest_stars"] = normalized["stars"]
	_data["reward_chest_goal_index"] = normalized["goal_index"]
	_data["coins"] = get_coins() + int(normalized.get("coin_reward", 0))
	return true


func _normalize_reward_chest_progress(stars: int, goal_index: int) -> Dictionary:
	var goals := _get_reward_chest_goals()
	var safe_goal_index := clampi(goal_index, 0, goals.size() - 1)
	var safe_stars := maxi(stars, 0)
	var coin_reward := 0

	while safe_stars >= _get_reward_chest_goal_stars(goals, safe_goal_index):
		safe_stars -= _get_reward_chest_goal_stars(goals, safe_goal_index)
		coin_reward += _get_reward_chest_goal_coin_reward(goals, safe_goal_index)
		if safe_goal_index < goals.size() - 1:
			safe_goal_index += 1

	return {
		"stars": safe_stars,
		"goal_index": safe_goal_index,
		"coin_reward": coin_reward,
	}


func _get_reward_chest_goal_index(goals: Array) -> int:
	return clampi(int(_data.get("reward_chest_goal_index", 0)), 0, goals.size() - 1)


func _get_reward_chest_goal_stars(goals: Array, goal_index: int) -> int:
	var goal := goals[clampi(goal_index, 0, goals.size() - 1)] as Dictionary
	return maxi(int(goal.get("stars", 1)), 1)


func _get_reward_chest_goal_coin_reward(goals: Array, goal_index: int) -> int:
	var goal := goals[clampi(goal_index, 0, goals.size() - 1)] as Dictionary
	return maxi(int(goal.get("coin_reward", 0)), 0)


func _get_reward_chest_goals() -> Array:
	if _reward_chest_goals.is_empty():
		_reward_chest_goals = _load_reward_chest_goals()

	return _reward_chest_goals.duplicate()


func _load_reward_chest_goals() -> Array:
	if not FileAccess.file_exists(REWARD_CHEST_GOALS_CONFIG):
		return DEFAULT_REWARD_CHEST_GOALS.duplicate()

	var config_file := FileAccess.open(REWARD_CHEST_GOALS_CONFIG, FileAccess.READ)
	if config_file == null:
		push_warning("Could not open reward chest goals config: %s" % REWARD_CHEST_GOALS_CONFIG)
		return DEFAULT_REWARD_CHEST_GOALS.duplicate()

	var parsed_config = JSON.parse_string(config_file.get_as_text())
	if not (parsed_config is Dictionary):
		push_warning("Reward chest goals config must contain a JSON object.")
		return DEFAULT_REWARD_CHEST_GOALS.duplicate()

	var parsed_goals := []
	var parsed_dictionary := parsed_config as Dictionary
	var raw_goals = parsed_dictionary.get("goals", [])
	if not (raw_goals is Array):
		push_warning("Reward chest goals config must define goals as an array.")
		return DEFAULT_REWARD_CHEST_GOALS.duplicate()

	for raw_goal in raw_goals:
		var parsed_goal := _parse_reward_chest_goal(raw_goal)
		if not parsed_goal.is_empty():
			parsed_goals.append(parsed_goal)

	if parsed_goals.is_empty():
		push_warning("Reward chest goals config does not define positive goals.")
		return DEFAULT_REWARD_CHEST_GOALS.duplicate()

	return parsed_goals


func _parse_reward_chest_goal(raw_goal) -> Dictionary:
	if raw_goal is Dictionary:
		var goal_dictionary := raw_goal as Dictionary
		var stars := maxi(int(goal_dictionary.get("stars", 0)), 0)
		var coin_reward := maxi(int(goal_dictionary.get("coin_reward", 0)), 0)
		if stars <= 0:
			return {}

		return {
			"stars": stars,
			"coin_reward": coin_reward,
		}

	var legacy_stars := maxi(int(raw_goal), 0)
	if legacy_stars <= 0:
		return {}

	return {
		"stars": legacy_stars,
		"coin_reward": 0,
	}


func _generate_player_name() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var suffix := ""
	for index in range(PLAYER_NAME_RANDOM_LENGTH):
		var suffix_index := rng.randi_range(0, PLAYER_NAME_RANDOM_ALPHABET.length() - 1)
		suffix += PLAYER_NAME_RANDOM_ALPHABET.substr(suffix_index, 1)

	return "%s%s" % [PLAYER_NAME_PREFIX, suffix]


func _refresh_lives_state() -> bool:
	var current_lives := clampi(int(_data.get("lives", MAX_LIVES)), 0, MAX_LIVES)
	var next_restore_unix := maxi(int(_data.get("next_life_restore_unix", 0)), 0)
	var original_lives := current_lives
	var original_next_restore_unix := next_restore_unix

	if current_lives >= MAX_LIVES:
		next_restore_unix = 0
	else:
		var now_unix := int(Time.get_unix_time_from_system())
		if next_restore_unix <= 0:
			next_restore_unix = now_unix + LIFE_RESTORE_SECONDS
		elif next_restore_unix <= now_unix:
			var elapsed_after_next_restore := now_unix - next_restore_unix
			var restored_lives := 1 + floori(float(elapsed_after_next_restore) / float(LIFE_RESTORE_SECONDS))
			current_lives = mini(current_lives + restored_lives, MAX_LIVES)
			if current_lives >= MAX_LIVES:
				next_restore_unix = 0
			else:
				next_restore_unix += restored_lives * LIFE_RESTORE_SECONDS

	_data["lives"] = current_lives
	_data["next_life_restore_unix"] = next_restore_unix
	return current_lives != original_lives or next_restore_unix != original_next_restore_unix


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
