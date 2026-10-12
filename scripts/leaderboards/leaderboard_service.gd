extends RefCounted
class_name LeaderboardService

const MockLeaderboardProviderScript := preload("res://scripts/leaderboards/mock_leaderboard_provider.gd")
const BackendLeaderboardProviderScript := preload("res://scripts/leaderboards/backend_leaderboard_provider.gd")
const PROVIDER_SETTING := "application/config/leaderboard_provider"
const PROVIDER_MOCK := "mock"
const PROVIDER_BACKEND := "backend"

var _provider: RefCounted
## Release-safety guard (Google Play testing plan step 2.4b): a release build never shows the
## mock provider's invented rivals, so it never records a weekly rank or reward against them.
## The screen then shows its normal empty state. Debug builds keep the mock rows.
var _hide_mock_rows := not OS.is_debug_build()


func _init(provider: RefCounted = null) -> void:
	_provider = provider if provider != null else _create_provider()


func get_provider_name() -> String:
	return _provider.get_provider_name()


func fetch_leaderboard(
	scope: StringName,
	current_player: Dictionary,
	limit: int = 50
) -> Dictionary:
	if _hide_mock_rows and _provider.get_provider_name() == PROVIDER_MOCK:
		return {
			"ok": true,
			"entries": [],
			"player_entry": {},
			"period_end_unix": 0,
			"has_more": false,
			"error": "",
		}
	return await _provider.fetch_leaderboard(scope, current_player, limit)


## GAME-009: `backend` sources Weekly/Country/World pages from the authenticated backend
## (`scripts/leaderboards/backend_leaderboard_provider.gd`); any other configured value keeps the
## existing mock provider unchanged.
func _create_provider() -> RefCounted:
	var provider_id := PROVIDER_MOCK
	if ProjectSettings.has_setting(PROVIDER_SETTING):
		provider_id = str(ProjectSettings.get_setting(PROVIDER_SETTING)).to_lower()

	if provider_id == PROVIDER_BACKEND:
		return BackendLeaderboardProviderScript.new(_find_backend_transport())
	if provider_id != PROVIDER_MOCK:
		push_warning("Unsupported leaderboard provider '%s'; using mock data." % provider_id)

	return MockLeaderboardProviderScript.new()


## Looks up the `PlayerProgress` autoload by name instead of the bare global identifier, so this
## script (which headless tooling/tests may `preload()` before autoloads are registered) never
## takes a hard compile-time dependency on singleton resolution order. Mirrors
## `scripts/store/store_service.gd`'s `_find_backend_transport()` from GAME-008.
func _find_backend_transport():
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var player_progress = (main_loop as SceneTree).root.get_node_or_null("PlayerProgress")
	return player_progress.get_backend_transport() if player_progress != null else null
