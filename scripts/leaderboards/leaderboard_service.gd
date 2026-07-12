extends RefCounted
class_name LeaderboardService

const MockLeaderboardProviderScript := preload("res://scripts/leaderboards/mock_leaderboard_provider.gd")
const PROVIDER_SETTING := "application/config/leaderboard_provider"
const PROVIDER_MOCK := "mock"

var _provider: RefCounted


func _init(provider: RefCounted = null) -> void:
	_provider = provider if provider != null else _create_provider()


func get_provider_name() -> String:
	return _provider.get_provider_name()


func fetch_leaderboard(
	scope: StringName,
	current_player: Dictionary,
	limit: int = 50
) -> Dictionary:
	return await _provider.fetch_leaderboard(scope, current_player, limit)


func _create_provider() -> RefCounted:
	var provider_id := PROVIDER_MOCK
	if ProjectSettings.has_setting(PROVIDER_SETTING):
		provider_id = str(ProjectSettings.get_setting(PROVIDER_SETTING)).to_lower()

	if provider_id != PROVIDER_MOCK:
		push_warning("Unsupported leaderboard provider '%s'; using mock data." % provider_id)

	return MockLeaderboardProviderScript.new()
