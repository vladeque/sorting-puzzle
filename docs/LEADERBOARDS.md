# Leaderboards

## Current implementation

The production menu trophy tab opens `scenes/ui/leaderboard_screen.tscn`. The screen fetches entries through `LeaderboardService`, which selects a provider from `application/config/leaderboard_provider` (`mock`, the default, or `backend` since GAME-009).

Scopes with the default `mock` provider:
- `weekly`: global mock ranking using stars earned since Monday 00:00 UTC.
- `country`: mock country ranking using lifetime earned stars.
- `world`: mock worldwide ranking using lifetime earned stars.

Scopes with `backend`: all three scopes read `GET /v1/leaderboards/{scope}` from the authenticated backend; see "Backend provider (GAME-009)" below.

The provider returns up to 50 entries plus the current player's entry. `leaderboard_screen.gd` pins the highlighted player row above the bottom navigation whenever the player is absent from the returned entries *or* their rank is beyond `PINNED_ROW_RANK_THRESHOLD` (10, approximating how many rows are visible without scrolling on the reference viewport) -- being technically present on a 50-row page is not the same as being visible without scrolling, so rank alone decides pin visibility for anyone buried past the fold.

Ranks 1-3 additionally get a gold/silver/bronze medal circle behind the rank number
(`scenes/ui/leaderboard_row.tscn`'s `RankSlot`, toggled by `scripts/leaderboard_row.gd`), independent
of the current-player highlight so a top-3 row that's also the local player shows both cues at once.
On the Weekly scope, those same three rows also instance `leaderboard_rank_reward.tscn`: first place
uses `shop_coin_offer_tier_04.png`, second uses tier 03, and third uses tier 02. Country and World do
not show the reward section because they have no reset payout.

## Score ownership

`PlayerProgress` owns three different star values:
- `reward_chest_stars` is spend-like progress that rolls over at configured chest goals.
- `total_earned_stars` is the non-spending lifetime leaderboard score.
- `weekly_earned_stars` is the current Monday-UTC leaderboard score.

Only normal campaign completion updates leaderboard totals. Developer/test launches do not call `PlayerProgress.complete_level()` and therefore do not submit score.

Save schema 3 migrates an older development save by using its retained `reward_chest_stars` as the initial lifetime total and starting its weekly total at zero. This is an approximate development migration because completed chest cycles are not recoverable from the previous schema.

## Weekly rewards

`configs/leaderboard_reward_tiers.json` maps Weekly rank ranges to a coin reward (defaults: #1 500,
#2-3 300, #4-10 150, #11-50 50). `leaderboard_screen.gd` reads that same config when it binds the
amount displayed inside each Weekly top-three row's reward section, so the on-screen promise cannot
drift from what actually gets paid. The former full-width `%RewardTiersLabel` summary is intentionally
gone; ranks below third still receive their configured payout even though they do not get a row
reward preview. Country/World show no reward preview since they're all-time boards with no
reset/payout moment.

**This is a local approximation, not a backend-verified final standing.** There is currently no
backend job (and, per the Known Gap below, not yet even a fully populated backend leaderboard
score model) that computes an authoritative rank at the exact moment a Weekly period ends. Instead:

- Every successful Weekly fetch calls `PlayerProgress.record_weekly_leaderboard_rank(rank)`, which
  keeps the *best* (lowest-numbered) rank observed so far this week in the saved
  `last_weekly_rank_observation`. Because the mock roster's scores never change on their own, a
  player's true rank can only improve or hold steady as the week progresses, so "best observed" can
  under-pay (if they improve further after their last check) but never over-pays.
- The reward is granted when the week rolls over -- detected either at load time
  (`_sanitize_data()`, the common case: the app was closed across the boundary) or at runtime
  (`_refresh_leaderboard_week_state()`, if the app happens to stay open across it). Both paths share
  `_apply_leaderboard_week_rollover()` so the grant can't be skipped depending on which one notices
  first.
- A player who never opens the leaderboard during a given week has no observation and is paid
  nothing for it, even if their `weekly_earned_stars` would have ranked well. The reward is
  therefore best understood as "what you were seen to have earned," not "what you actually finished
  with."
- The granted `{rank, coin_reward, week_start_unix}` is queued as `_pending_leaderboard_reward` and
  shown once via `%LeaderboardRewardDialog` on `scenes/main_menu.tscn`'s next `_ready()`
  (`consume_pending_leaderboard_reward()` drains it so it can't repeat).

Revisit this once the backend leaderboard score model (see the Known Gap below) is real: an
authoritative server-computed final rank, delivered through a real payout endpoint, should replace
this client-side observation-based approximation.

### Weekly avatar frames

The gold, silver, and bronze avatar frames use a separate backend-owned award. On a completed
Weekly world period, competition rank 1 unlocks all three, rank 2 unlocks silver and bronze, and
rank 3 unlocks bronze. The best award is permanent and crosses account merges. The optional
`leaderboards.weekly_frame_best_rank` field in an authoritative v2 checkpoint is cached in
`PlayerProgress`; a missing field means no new award. The profile frame picker and local save guard
use this rank. All weekly frames remain visible in the picker; unearned ones are gray and tapping
them shows the finish required after the week closes. The backend checks the rank again on both v1
profile updates and v2 profile edits. The
local observed-rank coin reward above does not unlock premium frames.
`BackendReadOperations` recognizes the three premium frame IDs on public leaderboard rows and
preserves the optional award rank in player-state reads.

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
