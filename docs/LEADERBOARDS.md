# Leaderboards

## Current implementation

The production menu trophy tab opens `scenes/ui/leaderboard_screen.tscn`. The screen fetches entries through `LeaderboardService`, which selects a provider from `application/config/leaderboard_provider` (`mock`, the default, or `backend` since GAME-009).

Scopes with the default `mock` provider:
- `weekly`: global mock ranking using stars earned since Monday 00:00 UTC.
- `country`: mock country ranking using lifetime earned stars.
- `world`: mock worldwide ranking using lifetime earned stars.

Scopes with `backend`: all three scopes read `GET /v1/leaderboards/{scope}` from the authenticated backend; see "Backend provider (GAME-009)" below.

The provider returns up to 50 entries plus the current player's entry. If the player is not in the returned range, the screen pins the highlighted player row above the bottom navigation.

## Score ownership

`PlayerProgress` owns three different star values:
- `reward_chest_stars` is spend-like progress that rolls over at configured chest goals.
- `total_earned_stars` is the non-spending lifetime leaderboard score.
- `weekly_earned_stars` is the current Monday-UTC leaderboard score.

Only normal campaign completion updates leaderboard totals. Developer/test launches do not call `PlayerProgress.complete_level()` and therefore do not submit score.

Save schema 3 migrates an older development save by using its retained `reward_chest_stars` as the initial lifetime total and starting its weekly total at zero. This is an approximate development migration because completed chest cycles are not recoverable from the previous schema.

## Provider contract

`LeaderboardProvider.fetch_leaderboard(scope, current_player, limit)` is asynchronous and returns:

```text
ok: bool
entries: Array[Dictionary]
player_entry: Dictionary
period_end_unix: int
has_more: bool
error: String
```

Entry dictionaries contain:

```text
player_id
display_name
avatar_id
country_code
score
rank
is_current_player
```

## Backend provider (GAME-009)

`application/config/leaderboard_provider="backend"` selects `scripts/leaderboards/backend_leaderboard_provider.gd` (`BackendLeaderboardProvider`) from `LeaderboardService._create_provider()`, resolved through the same `PlayerProgress.get_backend_transport()` lookup `StoreService` uses for the Shop (GAME-008). It implements the provider contract above unchanged, so the screen needed no changes.

Behavior:
- Reads `GET /v1/leaderboards/{scope}` through the shared GAME-007 `BackendTransport`/`BackendReadOperations.parse_leaderboard()`. Entries, rank, score, and tie ordering are authoritative from the backend and are never re-derived or re-sorted locally.
- `player_entry` comes from the response's `current_player` field when the backend places the authenticated player outside the returned page, or from the matching `is_current_player` row inside `entries` otherwise -- matching the backend's `playerIsInPage` behavior.
- `period_end_unix` is converted from the response's `period_end` ISO timestamp; `has_more` reflects whether the response carries a non-empty `next_cursor`.
- Country scope's no-country response (`entries: []`, no `period_id`/`period_end`/`current_player`) renders as an ordinary empty board. The client never infers or defaults a country locally.
- `scripts/leaderboards/backend_leaderboard_cache.gd` (`BackendLeaderboardCache`) persists the last successful page per scope to `user://leaderboard_backend_cache.json` (entries/current-player/period end only, never a token, signature, or cursor). An unavailable, unauthorized, expired-cursor, or malformed later read falls back to that cache; an error only reaches the screen when no cache exists either.
- `fetch_page(scope, limit, cursor)` exposes cursor forwarding for a later "load more" page; the screen currently requests only the backend's single 50-row max page, matching the existing mock behavior.

Known gap: the backend's leaderboard score model must be populated from protocol-v2 selected-completion checkpoints (`save.checkpoint_merged.v1`) for two local players' distinct v2 completions to appear in deterministic order against a real backend. That materialization is backend-owned and not yet implemented (`docs/LOCAL_BACKEND_INTEGRATION.md` Phase L3, gap 7); this client-side provider, its cache, and its provider selection are fully covered by `tests/backend/test_game_009.gd` independent of that gap.
