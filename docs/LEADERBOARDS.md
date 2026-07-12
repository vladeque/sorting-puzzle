# Leaderboards

## Current implementation

The production menu trophy tab opens `scenes/ui/leaderboard_screen.tscn`. The screen fetches entries through `LeaderboardService`, which currently selects `MockLeaderboardProvider` from `application/config/leaderboard_provider="mock"`.

Scopes:
- `weekly`: global mock ranking using stars earned since Monday 00:00 UTC.
- `country`: mock country ranking using lifetime earned stars.
- `world`: mock worldwide ranking using lifetime earned stars.

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

## Backend integration later

Add a provider under `scripts/leaderboards/`, select it from `LeaderboardService._create_provider()`, and extend `application/config/leaderboard_provider` documentation. Keep HTTP/authentication, country resolution, pagination cursors, cached responses, and idempotent score submission inside the service/provider layer; the screen should continue consuming normalized result dictionaries.

The backend must treat score submission as an earned-star event rather than trusting reward chest balance. It should assign the weekly period server-side, deduplicate completion event ids, and return ranks for the authenticated player. The current mock `has_more` field reserves pagination behavior, but the screen intentionally loads a single 50-entry page until the backend API exists.
