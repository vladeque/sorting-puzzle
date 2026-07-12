extends RefCounted
class_name LeaderboardProvider

const SCOPE_WEEKLY := &"weekly"
const SCOPE_COUNTRY := &"country"
const SCOPE_WORLD := &"world"
const VALID_SCOPES := [SCOPE_WEEKLY, SCOPE_COUNTRY, SCOPE_WORLD]


func get_provider_name() -> String:
	return "leaderboard_provider"


func fetch_leaderboard(
	_scope: StringName,
	_current_player: Dictionary,
	_limit: int = 50
) -> Dictionary:
	await Engine.get_main_loop().process_frame
	return _error("Leaderboard provider does not implement fetch_leaderboard().")


func _success(
	entries: Array,
	player_entry: Dictionary,
	period_end_unix: int = 0,
	has_more: bool = false
) -> Dictionary:
	return {
		"ok": true,
		"entries": entries,
		"player_entry": player_entry,
		"period_end_unix": period_end_unix,
		"has_more": has_more,
		"error": "",
	}


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"entries": [],
		"player_entry": {},
		"period_end_unix": 0,
		"has_more": false,
		"error": message,
	}
