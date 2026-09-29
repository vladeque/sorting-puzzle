extends SceneTree

const BackendReadOperationsScript := preload("res://scripts/backend/backend_read_operations.gd")


func _init() -> void:
	var summary := BackendReadOperationsScript._parse_leaderboard_summary({
		"lifetime_stars": 100,
		"weekly_stars": 30,
		"weekly_period_id": "weekly-2026-09-21",
		"weekly_period_start": "2026-09-21T00:00:00.000Z",
		"weekly_period_end": "2026-09-28T00:00:00.000Z",
		"weekly_frame_best_rank": 2,
	})
	var entry := BackendReadOperationsScript._parse_leaderboard_entry({
		"player_id": "00000000-0000-4000-8000-000000000001",
		"rank": 2,
		"score": 30,
		"display_name": "Weekly Winner",
		"avatar_id": "avatar_cat",
		"avatar_frame_id": "frame_weekly_silver",
		"is_current_player": true,
	})
	if (
		bool(summary.get("ok", false))
		and int((summary.get("leaderboards", {}) as Dictionary).get("weekly_frame_best_rank", -1)) == 2
		and bool(entry.get("ok", false))
		and str((entry.get("entry", {}) as Dictionary).get("avatar_frame_id", "")) == "frame_weekly_silver"
	):
		print("Weekly frame contract tests passed.")
		quit(0)
		return
	push_error("Weekly frame rank or public frame ID was not preserved by the read adapter.")
	quit(1)
