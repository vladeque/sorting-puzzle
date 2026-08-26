extends "res://scripts/leaderboards/leaderboard_provider.gd"
class_name MockLeaderboardProvider

const MOCK_NAMES := [
	"ShelfStar", "MochiMatch", "LunaSorts", "TripleFox", "SunnySnacks",
	"NovaNinja", "CozyKoala", "PuzzlePanda", "BerryBee", "TidyTiger",
	"MatchMallow", "CleverCat", "HappyHippo", "SwiftSloth", "SortSprout",
	"NeonNarwhal", "CandyCrow", "JollyJaguar", "PixelPenguin", "CocoaCow",
	"CometCub", "BouncyBear", "DaringDeer", "FizzyFrog", "GoldenGoat",
	"LuckyLion", "MintyMonkey", "NimbleOwl", "PeppyPig", "QuickQuokka",
	"RubyRabbit", "SillySheep", "TurboTurtle", "VelvetVixen", "WittyWhale",
	"ZestyZebra", "AmberAnt", "BubbleBat", "CoralCrab", "DreamyDog",
	"EchoEagle", "FluffyFinch", "GingerGecko", "HoneyHare", "IcyIbis",
	"JadeJay", "KiwiKitten", "LemonLynx", "MapleMouse", "PeachPup",
]
const MOCK_AVATAR_IDS := [
	"avatar_cat", "avatar_dog", "avatar_koala", "avatar_tiger", "avatar_penguin",
	"avatar_bear", "avatar_owl", "avatar_frog", "avatar_lion", "avatar_turtle",
]
const MOCK_AVATAR_FRAME_IDS := [
	"frame_classic", "frame_gold", "frame_leaf", "frame_rose", "frame_coral",
	"frame_sky", "frame_plum", "frame_ruby", "frame_aqua",
]


func get_provider_name() -> String:
	return "mock"


func fetch_leaderboard(
	scope: StringName,
	current_player: Dictionary,
	limit: int = 50
) -> Dictionary:
	await Engine.get_main_loop().process_frame
	if scope not in VALID_SCOPES:
		return _error("Unknown leaderboard scope: %s" % scope)

	var entries := _build_mock_entries(scope)
	entries.append(_build_current_player_entry(scope, current_player))
	entries.sort_custom(_sort_by_score)
	_assign_ranks(entries)

	var player_entry := {}
	for entry in entries:
		if bool((entry as Dictionary).get("is_current_player", false)):
			player_entry = (entry as Dictionary).duplicate()
			break

	var safe_limit := clampi(limit, 1, entries.size())
	var visible_entries := entries.slice(0, safe_limit)
	var period_end_unix := int(current_player.get("week_end_unix", 0)) if scope == SCOPE_WEEKLY else 0
	return _success(visible_entries, player_entry, period_end_unix, entries.size() > safe_limit)


func _build_mock_entries(scope: StringName) -> Array:
	var entries := []
	for index in range(MOCK_NAMES.size()):
		entries.append({
			"player_id": "mock_%02d" % index,
			"display_name": MOCK_NAMES[index],
			"avatar_id": MOCK_AVATAR_IDS[index % MOCK_AVATAR_IDS.size()],
			"avatar_frame_id": MOCK_AVATAR_FRAME_IDS[index % MOCK_AVATAR_FRAME_IDS.size()],
			"country_code": "UA" if scope == SCOPE_COUNTRY else "",
			"score": _get_mock_score(scope, index),
			"rank": 0,
			"is_current_player": false,
		})

	return entries


func _get_mock_score(scope: StringName, index: int) -> int:
	match scope:
		SCOPE_WEEKLY:
			return maxi(920 - index * 17, 12)
		SCOPE_COUNTRY:
			return maxi(7820 - index * 93, 140)
		_:
			return maxi(15880 - index * 176, 250)


func _build_current_player_entry(scope: StringName, current_player: Dictionary) -> Dictionary:
	var score_key := "weekly_score" if scope == SCOPE_WEEKLY else "total_score"
	return {
		"player_id": str(current_player.get("player_id", "local_player")),
		"display_name": str(current_player.get("display_name", "You")),
		"avatar_id": str(current_player.get("avatar_id", "avatar_cat")),
		"avatar_frame_id": str(current_player.get("avatar_frame_id", "frame_classic")),
		"country_code": str(current_player.get("country_code", "")),
		"score": maxi(int(current_player.get(score_key, 0)), 0),
		"rank": 0,
		"is_current_player": true,
	}


func _sort_by_score(left: Dictionary, right: Dictionary) -> bool:
	var left_score := int(left.get("score", 0))
	var right_score := int(right.get("score", 0))
	if left_score == right_score:
		return str(left.get("player_id", "")) < str(right.get("player_id", ""))

	return left_score > right_score


func _assign_ranks(entries: Array) -> void:
	var previous_score := -1
	var current_rank := 0
	for index in range(entries.size()):
		var entry := entries[index] as Dictionary
		var score := int(entry.get("score", 0))
		if index == 0 or score != previous_score:
			current_rank = index + 1
		entry["rank"] = current_rank
		previous_score = score
