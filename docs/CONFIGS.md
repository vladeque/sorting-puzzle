# Configs

This file describes data files that drive gameplay and tooling.

## `configs/chapters.json`

Purpose:
- Defines ordered chapters, chapter-local level lists, presentation art, and unlock rules.
- Keeps global campaign level IDs stable for save/protocol compatibility while allowing each
  chapter to contain hundreds of levels with chapter-local numbering in the UI.

Contract:
- Chapter IDs and orders are unique; order starts at `1` without gaps.
- Chapter 1 is unlocked by default. Every later chapter names the immediately previous chapter and
  uses `default_unlock_required_levels` (`25`) when its own positive requirement is omitted.
- `level_ids` contains global campaign IDs. Every referenced runtime level must exist and declare
  the same ID in its `level` field.
- A future locked chapter may have an empty `level_ids` list so it can be previewed before content
  ships.
- `gameplay_background_mode` is `legacy` for the original procedural wall/floor presentation or
  `artwork` for the chapter's full-screen gameplay texture. Chapter 1 uses `legacy`.
- `background_texture` and `selection_preview` must reference existing Godot textures; the preview
  remains available in chapter-selection UI even for a legacy gameplay background.

## `configs/item_sprites.json`

Purpose:
- Registers item IDs and texture paths used by runtime level loading and level tooling.

Top-level fields:
- `sheet`: source sprite sheet path for reference.
- `columns`: number of columns in the source sheet.
- `rows`: number of rows in the source sheet.
- `cell_size`: source cell dimensions.
- `items`: list of item definitions.

Item fields:
- `id`: stable item ID used in level JSON.
- `category`: grouping label for organization and tooling.
- `texture`: `res://` path to the individual item texture loaded by `scripts/level.gd`.

Contract:
- Every non-null item ID in `configs/levels/level_*.json` should exist here.
- IDs should remain stable once used by levels.
- Texture paths should point to imported Godot image assets.

## `configs/item_progression.json`

Purpose:
- Defines the exclusive item-art pool available to each chapter during level materialization.
- Keeps progression tuning separate from abstract shelf generation and the texture catalog.

Top-level fields:
- `schema_version`: currently `2`.
- `mapping_salt`: stable non-empty string used for deterministic level-specific item selection.
- `chapters`: one entry per chapter in `configs/chapters.json`.

Milestone fields:
- `from_chapter_level`: first chapter-local level that can use the milestone's items.
- `unlock`: non-empty list of item IDs from `configs/item_sprites.json`.

Contract:
- Every configured chapter has a progression entry whose first milestone starts at local level `1`.
- Every catalog item is scheduled exactly once across all chapters, so chapter pools never overlap.
- A level's available pool is the cumulative union of its chapter milestones whose
  `from_chapter_level` is not greater than that level's chapter-local number.
- Chapter 1 owns the 20 item types used by levels 1-10; Chapter 2 owns the remaining 19 catalog
  types.
- Materialization selects a deterministic subset and maps logical item tokens one-to-one. Different
  logical identities never collapse into the same concrete item.
- The mapping follows the global level's catalog location and chapter-local number, not the
  player's current or highest progress.

## `configs/level_templates/level_*.json`

Purpose:
- Stores abstract authored/generated campaign levels.
- Uses canonical `item_NN` logical identities so shelf generation does not choose item art.

Contract:
- Templates otherwise use the same level, shelf, layer, lock, and layout shape as runtime levels.
- Every non-null slot is a logical token such as `item_01`; concrete catalog IDs are rejected.
- Logical identities are local to one level and must have a one-to-one mapping into that level's
  progression pool.
- Run `py scripts\tools\materialize_level_templates.py` after changing templates, chapters, or
  item progression.
- Run `py scripts\tools\materialize_level_templates.py --check` to detect missing or stale runtime
  outputs.

## `configs/levels/level_*.json`

Purpose:
- Contains materialized runtime levels loaded by Godot and published to the backend.
- These files are generated from `configs/level_templates/level_*.json` and
  `configs/item_progression.json`; do not independently choose or edit their item identities.

File naming:
- Runtime loader expects `configs/levels/level_%03d.json`.
- Example: selected level `1` loads `configs/levels/level_001.json`.
- Missing selected levels fall back to `configs/levels/level_001.json`.

Top-level fields:
- `level`: numeric level identifier.
- `time_seconds`: countdown duration for the level.
- `layout_preset`: shelf placement preset used by `scripts/level.gd`; preset positions are authored in matching `scenes/layouts/layout_*.tscn` template scenes.
- `difficulty`: generation metadata recording the difficulty preset used to create the shelf layout.
- `row_layouts`: optional row-by-row shelf placement and motion config. When present, its `shelf_count` total must equal the `shelves` length and it replaces `layout_preset` placement at runtime.
- `shelves`: ordered shelf list.

Supported layout presets:
- `grid_2x3`
- `grid_3x3`
- `grid_3x4`
- `grid_3x5`
- `grid_4x3`
- `grid_3x3_moving_5_bottom`: 14 shelves arranged as a 3x3 static grid plus a bottom row of five moving shelves, with three moving shelves visible at once.
- `staggered_5_4_5`: 14 shelves arranged as five left, four centered, five right.
- `staggered_4_5_4`: 13 shelves arranged as four left, five centered, four right.

Row layout shape:

```json
{
  "row_layouts": [
    { "shelf_count": 3 },
    {
      "shelf_count": 5,
      "visible_count": 3,
      "motion": {
        "type": "horizontal_wrap",
        "speed": 70,
        "direction": "right"
      },
      "visual_variant": "floor_only"
    },
    { "shelf_count": 3 }
  ]
}
```

Row layout rules:
- `shelf_count` is required for each row and consumes shelves in order from the `shelves` array.
- `visible_count` is optional. Moving rows default to `3` visible shelves, clamped to `shelf_count`; static rows default to their full `shelf_count`.
- `motion.type` supports `horizontal_wrap` and `vertical_wrap`.
- `motion.speed` is pixels per second. Use `0` for a row that is structured as a moving row but currently stopped.
- `motion.direction` supports `right` and `left` for `horizontal_wrap`, and `down` and `up` for `vertical_wrap`. Vertical rows default to `down`, moving shelves from top to bottom.
- A level may use horizontal moving shelves or vertical moving shelves, but not both at the same time.
- `visual_variant` supports `full` and `floor_only`. Moving rows default to `floor_only`; static rows default to `full`.
- Locked shelves are not allowed inside moving rows.
- `grid_3x3_moving_5_bottom` is a shorthand preset for three static rows of three shelves plus the bottom moving row from the example above.

Shelf shape:

```json
{
  "unlock_after_triples": 3,
  "layers": [
    ["milk_carton", "chips_can", null],
    ["milk_carton", "chips_can", "toy_robot"]
  ]
}
```

Layer rules:
- `unlock_after_triples` is optional. Omit it or set `0` for shelves that are accessible at level start.
- A positive `unlock_after_triples` keeps the shelf inaccessible until the player has cleared that many triples.
- Each shelf must contain a non-empty `layers` array.
- Each layer must contain exactly three slots.
- Slot values must be item ID strings or `null`.
- Layer `0` is the visible front layer.
- Later layers are hidden or previewed back layers that promote when the front layer clears.

Item count rules:
- Each item ID should appear in a multiple of three across the level.
- The runtime clears three identical visible items on one shelf.

Runtime behavior:
- `scripts/level.gd` instantiates one `scenes/shelf.tscn` cell for each configured shelf.
- `scripts/level.gd` uses `layout_preset` to load `scenes/layouts/layout_%s.tscn`, then places generated shelf cells at the template's `ShelfXX` markers.
- Layout template `MovingRowXX` nodes with `scripts/shelf_layout_row.gd` create moving rows from authored row positions and metadata.
- Static shelf left/middle/right visuals are derived from authored shelf positions or `row_layouts` order at runtime; there is no per-shelf config field for row placement.
- If `row_layouts` is present, `scripts/level.gd` creates shelves row by row instead. Moving rows are clipped to their visible window and wrap shelves horizontally or vertically according to their motion type.
- `scripts/level.gd` uses `time_seconds` as the active timer.
- Locked shelves show a runtime lock overlay with the remaining triple count on the lock and cannot be used as move sources, move targets, match clears, promotions, or ability targets until unlocked.
- Off-window moving shelves cannot be selected or targeted by drag/drop, but abilities can still target their front-layer items.
- Hammer clears count as cleared triples for shelf unlocking. If no unlocked visible/front item type has three available copies, hammer can combine visible/front items with first-back-layer copies of the same type to reach a triple.

Validation:

```powershell
py scripts\tools\validate_level_solvable.py configs\levels\level_001.json --max-states 20000 --max-depth 200
```

The validator checks `row_layouts` totals, moving-row motion fields, supported visual variants, rejects locked shelves inside moving rows, and rejects levels that mix horizontal and vertical moving shelves. For preset-defined moving rows, the validator mirrors the moving-row metadata from the matching layout template.
Solvability search treats moving rows as eventually accessible and does not model shelf positions over time.

Generation:

```powershell
py scripts\tools\generate_level_shelves.py --shelf-count 9 --layer-count 2 --item-type-count 7 --difficulty medium --seed 123 --full-level --level-number 2 --output configs\level_templates\level_002.json --require-solvable --stats
py scripts\tools\materialize_level_templates.py
```

`--item-type-count` creates `item_01` through the requested count. When it is omitted, the generator
uses `ceil(target_filled_slots / preferred_copies_per_type)` to infer the logical type count.
`--preferred-copies-per-type` accepts integers or fractions of at least `3` and defaults to `6`.
It is a target average because each logical type's actual copy count must remain a multiple of three.
An explicit `--item-type-count` overrides this inference.

The generator distributes triples across all logical types and fills the difficulty preset's target
slot count. Use `--max-items-per-type` to impose a lower global repetition cap; the generator applies
that cap after type-count inference and adds empty slots rather than exceeding it.

Item placement uses soft per-layer triple-readiness targets of approximately 65% for easy, 50% for
medium, 40% for hard, and 30% for expert. The generator balances toward those ratios without rejecting
otherwise valid constrained boards. Copies that are not part of a preferred local triple expand into
adjacent layers before more distant layers, so each item normally occupies one compact layer range.
`--stats` reports the target, actual readiness for every layer, and any non-adjacent item spreads.

Generated levels default to `--min-front-visible-triples 1`, so at least one item type starts with three visible front-layer copies across shelves. Use `--min-front-visible-triples 0` for layouts that should not force a starter visible triple candidate.

Current authored generation parameters:

- Level 2 uses 9 shelves, 2 filled layers, 7 logical item types, easy difficulty, and a maximum of 6 copies per logical item type.
- Level 3 uses 12 shelves, 2 filled layers, 7 logical item types, medium difficulty, and a maximum of 6 copies per logical item type.
- Level 4 uses 15 shelves, 3 filled layers, 19 logical item types, medium difficulty, and seed 4004.

Use `--locked-shelves` to add unlock requirements to generated shelves. Entries are 1-based shelf numbers and required cleared triples:

```powershell
py scripts\tools\generate_level_shelves.py --shelf-count 9 --layer-count 2 --difficulty medium --locked-shelves 7:3,8:5 --validate
```

## `configs/reward_chest_goals.json`

Purpose:
- Defines the reward chest star goals shown by `scenes/ui/main_menu_reward_chest.tscn`.
- Owned by `scripts/player_progress.gd`, which loads the configured goal ladder and falls back to built-in defaults if the file is missing or invalid.

Shape:

```json
{
  "goals": [
    { "stars": 500, "coin_reward": 100 },
    { "stars": 1000, "coin_reward": 225 }
  ]
}
```

Rules:
- `goals` must be an ordered list of objects with a positive `stars` target.
- `coin_reward` is the number of gold coins granted when that goal is reached.
- Legacy numeric entries such as `500` are still accepted as star goals with `0` coin reward.
- The saved `reward_chest_goal_index` selects the active goal.
- When saved chest stars reach the active goal, the configured coin reward is added to the player's saved coins, the goal starts over with remaining stars carried forward, and the next configured goal becomes active.
- After the final configured goal is reached, the final goal value repeats.

## `configs/leaderboard_reward_tiers.json`

Purpose:
- Defines the coin reward paid out for a Weekly leaderboard rank range when the leaderboard week
  rolls over.
- Owned by `scripts/player_progress.gd`, which loads the tier ladder and falls back to built-in
  defaults if the file is missing or invalid. Also drives the amount shown by
  `leaderboard_screen.gd` in the Weekly top-three row reward sections, so the displayed promise and
  the actual payout always read from the same source.

Shape:

```json
{
  "tiers": [
    { "min_rank": 1, "max_rank": 1, "coin_reward": 500 },
    { "min_rank": 2, "max_rank": 3, "coin_reward": 300 }
  ]
}
```

Rules:
- `tiers` must be an ordered list of objects with `min_rank <= max_rank` and a positive `coin_reward`;
  invalid entries are dropped.
- A rank is paid the `coin_reward` of the first tier whose `[min_rank, max_rank]` range contains it;
  a rank matching no tier gets nothing.
- Ranks are **locally observed, not backend-verified**: `record_weekly_leaderboard_rank()` tracks the
  best Weekly rank `leaderboard_screen.gd` has seen since the current week started, and that
  observation (if any) is what gets paid when the week rolls over -- see "Weekly rewards" in
  `docs/LEADERBOARDS.md` for the gap this approximates and why a player who never opens the
  leaderboard in a given week is paid nothing for it.

## `configs/ability_purchase_prices.json`

Purpose:
- Defines the coin price for buying one immediate paid use of an ability from `scenes/ability_purchase_menu.tscn` when the player has no saved uses remaining.
- Owned by `scripts/level.gd`, which falls back to built-in defaults if the file is missing or invalid.

Shape:

```json
{
  "prices": {
    "hammer": 100,
    "shuffle": 100,
    "highlight": 100,
    "freezer": 100
  }
}
```

Rules:
- `prices` is a map from ability id to non-negative coin price.
- Missing entries use the built-in default price for that ability.
- Buying from the modal spends coins only when the selected ability can actually start, then uses that one paid ability immediately without adding saved inventory.

## `configs/shop_catalog.json`

Purpose:
- Defines ordered Shop offers, product ids, display titles, reward contents, and development-only regional mock prices.
- Does not make the UI authoritative for a purchase; `StoreService` attaches provider product details and `PlayerProgress` applies the returned reward payload.

Rules:
- `type` is `bundle` or `coins`.
- `rewards.coins` is a non-negative coin grant.
- `rewards.abilities` may grant `hammer`, `shuffle`, `highlight`, and `freezer`; the UI labels
  `highlight` as Lantern.
- `purchase_limit: 1` together with `limit_period: "lifetime"` marks a local/mock offer as a
  once-per-account purchase. Its offer id is saved with the purchase grant, the offer is removed
  from later catalog loads, and purchase execution rechecks the claim before contacting the mock
  provider. Backend-sourced eligibility remains server-authoritative.
- `mock_prices` is keyed by mock country code and contains the complete `formatted_price` plus ISO currency code. Missing regions fall back to `US` in the development provider.
- Real providers must ignore `mock_prices` and display the formatted string returned by Google Play or the App Store.
- `discount_percent` (optional, integer) and `compare_at_prices` (optional, same per-region
  `formatted_price` shape as `mock_prices`) drive the Shop's rotated "X% OFF" starburst badge and
  struck-through "was" price on `shop_bundle_card.tscn`. Both are presentation-only promotional
  copy, authored by the game team; they are never store-authoritative and an offer without them
  simply shows no badge/compare price. `MockStoreProvider` resolves `compare_at_prices` into
  `store.compare_at_formatted_price` the same way it resolves `mock_prices`.
- `tag` (optional, string, e.g. `"BEST VALUE"`) shows a small banner on `shop_coin_offer_row.tscn`.
  Also presentation-only; omit it for offers that shouldn't call out a tag.
- Current mock catalog: the existing 3-hammer, 3-shuffle, 3-lantern, 3-freezer, 1,000-coin starter
  bundle (67% off its authored `compare_at_prices`); a once-per-account New Player Bundle with
  2,500 coins and three of every ability for US `$7.99`; and five coin-only offers, with
  `coins_3500` tagged `BEST VALUE` as the best coins-per-dollar pack. Historic backend catalog
  versions without `freezer`, `discount_percent`, `compare_at_prices`, or `tag` remain valid; the
  first parses as a zero-Freezer reward and the rest simply show no promotional decoration.

## `user://save_v2/<namespace>/current.json`

Purpose:
- Always-active, account-scoped local-first save owned by `scripts/save/local_save_store.gd`.
- Replaces `user://player_progress.json`; the old schema-4 file is a one-time migration input.

Top-level contract:
- `format`: `sorting-puzzle-local-save/1`.
- `schema_version`: local container schema version.
- `namespace`: either immutable backend `player_id` or stable installation guest id.
- `generation`: strictly increasing atomic local generation.
- `snapshot`: player-facing campaign, economy, lives, chest, leaderboard, purchase provenance, and profile.
- `journal`: append-ordered BE-307 `save-operation/2` entries.
- `sync`: device chain/cursor, exact pending retry, checkpoint, adjustment, and migration metadata.
- `preferences`: device-only settings-button disabled states.
- `integrity.sha256`: canonical SHA-256 of every other top-level field.

Runtime files:
- `current.json`: active fully validated generation.
- `previous.json`: previous-good generation.
- `pending.tmp`: flushed and validated candidate awaiting promotion.
- `legacy_v4.previous.json`: retained read-only copy of the migrated schema-4 file.

The gameplay snapshot schema is version 6. It retains the former schema-5 fields, adds
`purchased_shop_offer_ids` for account-scoped local/mock lifetime-offer claims, retains
`reward_chest_completed_cycles` and `moderation_state`, and intentionally excludes
`settings_disabled`, which now belongs to `preferences`.

Runtime behavior:
- Fresh saves start at level 1 with five lives, 300 gold coins, three uses for each ability, `avatar_cat` selected as the profile avatar, a generated `player_` name with a five-character random suffix, and all settings buttons enabled.
- The main menu blocks campaign level launch at zero lives.
- The production profile menu can save the player name and any avatar id from `assets/ui/avatars/*.png`; invalid avatar ids are sanitized back to `avatar_cat`.
- Campaign level failure and pause-menu Leave spend one life. Completed levels do not spend lives.
- Missing lives restore at one life per real-time hour until the five-life cap is reached.
- Ability uses are spent and saved immediately when an ability successfully applies.
- Paid zero-use ability purchases spend configured coins immediately when the selected ability can start, without adding saved ability inventory.
- Settings button disabled states are saved immediately when toggled and restored by the main-menu settings popup and in-level pause menu on later game starts.
- Failed or abandoned levels do not refund ability uses.
- Completing the current campaign level advances `current_level` by one and adds the run's earned stars to the reward chest.
- The same completion adds stars to `total_earned_stars` and `weekly_earned_stars`; neither is reduced by reward chest rollover.
- Schema-4 migration retains campaign, coins, lives/timer, existing ability inventory, processed
  mock transaction ids, profile, settings, chest progress, and lifetime/weekly stars, advances the
  snapshot to schema 6, and grants exactly three Freezer uses once. Schema-5 migration advances to
  schema 6 with an empty purchased-offer claim list and never repeats the Freezer grant.
- Weekly stars reset when the saved Monday-UTC boundary no longer matches the current week.
- Reward chest stars roll over when a configured goal is reached, grant that goal's `coin_reward`, then the next configured goal starts.
- Developer/test level selection is isolated from this save data.
- Local persistence remains active in all builds; there is no cloud-only mode.

## Local-first sync settings

Purpose:
- Gates asynchronous BE-307 recovery without changing offline gameplay behavior.

Fields:
- `application/config/backend_base_url`: backend origin; empty disables transport.
- `application/config/save_sync_v2_enabled`: protocol-1.1 guest registration plus BE-307
  synchronization rollout gate. Defaults to `false`.
- `application/config/secure_storage_bridge_singleton`: native secure bridge override; empty uses
  `SortingPuzzleSecureStoreBridge`.
- `application/config/build_number`: positive mobile build number sent in request metadata.

Content provenance is not a project setting and has no synthetic fallback. Campaign journal
operations load their exact configuration/level/rules identities from
`configs/backend/content_provenance.json`.

See:
- `docs/CLOUD_SAVE.md`

## `local/backend_debug.cfg` (GAME-003, gitignored)

Purpose:
- Local-only override for `application/config/backend_base_url` and
  `application/config/save_sync_v2_enabled`, applied only in debug builds, so the committed
  `project.godot` defaults (empty URL, sync disabled) never need to change for local Android
  local-backend testing.
- Owned by `scripts/save/local_backend_debug_bootstrap.gd`, registered as the first autoload so the
  override lands before `SaveSyncService` reads either setting.

Shape (template at `local/backend_debug.example.cfg`; copy it to `local/backend_debug.cfg` and
edit the copy):

```ini
[backend]

base_url="http://127.0.0.1:8080"
sync_enabled=true
```

Rules:
- `local/backend_debug.cfg` itself is gitignored and must never be committed with a real value.
- The Android export plugin injects it only into debug exports. A release export does not package
  the file even when the local copy exists.
- `base_url` must start with `http://` or `https://`; anything else is rejected and the committed
  defaults stay active.
- `sync_enabled` must be a literal `true`/`false`; a non-boolean value is rejected.
- The file is only read when `OS.is_debug_build()` is true and only if it exists; a missing file or
  a release export both leave `project.godot`'s committed defaults untouched.
- With `adb reverse tcp:8080 tcp:8080` running, `http://127.0.0.1:8080` reaches the developer
  machine's backend from the Android emulator; `http://10.0.2.2:8080` is the documented fallback.
- `scripts/tools/run_android_local_development.ps1` regenerates this ignored file for the selected
  host port workflow before every daily-development debug export; release exports still exclude it.

See:
- `platform/android/secure-store-plugin/README.md`
- `docs/LOCAL_BACKEND_INTEGRATION.md`

## `configs/backend/content_provenance.json`

Purpose:
- Bundles the exact GAME-002 client view of the immutable development publication generated by the
  sibling backend.

Owner:
- Canonical generation: `../sorting-puzzle-backend/scripts/local-development-content.mjs`.
- Canonical backend copy:
  `../sorting-puzzle-backend/contracts/configuration/v1/development-client-provenance.json`.
- Runtime validation: `scripts/save/content_provenance_manifest.gd`.

Contract:
- `digest_sha256` covers every other manifest field as canonical JSON.
- `publication` binds one content-addressed `configuration_version` to its publication digest and
  source-candidate digest.
- `levels` maps all current Chapter 1 campaign levels 1-10 to exact opaque configuration, level,
  and rules versions.
- `source.files` pins the authored Godot files used by that publication.
- `configs/chapters.json` is included in the pinned source-file set so chapter membership changes
  invalidate stale provenance before export.
- Runtime validates the packaged manifest's closed schema, self-digest, publication identity, and
  level mappings. It deliberately does not hash raw authored `.gd`/`.tscn` files because Godot
  export templates compile/remap them.
- The pre-export check runs with raw-source verification enabled and remains responsible for
  rejecting stale source hashes before an APK is produced.

Verification:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script scripts/tools/check_content_provenance.gd
pnpm --dir ..\sorting-puzzle-backend check:development-client-manifest
```

Both commands must pass before export. At runtime, missing, incomplete, digest-mismatched, or
provenance-invalid packaged content disables guest registration and synchronization while local
campaign state remains writable. Source staleness is rejected before export while the authored
source tree is available.

## Leaderboard Provider Setting

Purpose:
- Selects the data source used by `LeaderboardService` without coupling the UI to backend details.

Field:
- `application/config/leaderboard_provider`: `mock` (default) or `backend` (GAME-009). Unsupported values warn and fall back to mock data. `backend` sources Weekly/Country/World pages from the authenticated backend development leaderboard through `scripts/leaderboards/backend_leaderboard_provider.gd`; entries, rank, and current-player placement are authoritative from the response and are never re-derived locally.

See:
- `docs/LEADERBOARDS.md`

## `user://leaderboard_backend_cache.json`

Purpose:
- Offline cache of the last successfully fetched backend leaderboard page per scope, owned by `scripts/leaderboards/backend_leaderboard_cache.gd`. Only used when `leaderboard_provider` is `backend`.

Rules:
- Written after every successful `GET /v1/leaderboards/{scope}` read that returns at least one entry.
- Read only when a later fetch for that scope fails (unavailable, unauthorized, expired/invalid cursor, or malformed); a failure with no prior cache surfaces as a leaderboard load error instead.
- Contains only already-public entries, current-player row, and period-end data; never a token, signature, or pagination cursor.

## Store Provider Settings

Fields:
- `application/config/store_provider`: currently supports `mock` and defaults to it. Unsupported values warn and fall back to the mock provider. Always used for regional price formatting and purchase execution, regardless of `shop_catalog_source`.
- `application/config/mock_store_country`: mock storefront country used to select development price strings. Defaults to `US`; the catalog also defines `UA`, `DE`, and `JP` examples.
- `application/config/shop_catalog_source` (GAME-008): selects where the Shop's *offer list* comes from, independently of `store_provider`. `local` (default) reads `configs/shop_catalog.json` exactly as before. `backend` sources eligibility, rewards, and product IDs from the authenticated backend development catalog through `scripts/store/backend_catalog_source.gd`; unsupported values warn and fall back to `local`.

Production integration must replace the mock provider with platform product queries and verified, server-idempotent purchase grants rather than trusting these development settings.

## `configs/backend/shop_catalog_prices.json`

Purpose:
- Local-only presentation join table used when `application/config/shop_catalog_source` is `backend`. The backend catalog (`GET /v1/catalog`) is authoritative for offer eligibility, rewards, and product IDs but never returns a display title or a price (see `../sorting-puzzle-backend/docs/SHOP_CATALOGS.md`); this file supplies both for local development.
- Owned by `scripts/store/backend_catalog_source.gd`, which joins each eligible backend offer to one entry here by `platform_product_id`.

Shape:

```json
{
  "prices": [
    {
      "platform_product_id": "sorting_puzzle.local.starter_bundle",
      "title": "Starter Bundle",
      "mock_prices": {
        "US": {"formatted_price": "$4.99", "currency_code": "USD"}
      },
      "discount_percent": 67,
      "compare_at_prices": {
        "US": {"formatted_price": "$14.99"}
      }
    }
  ]
}
```

Rules:
- `platform_product_id` must match a `platform_product_id` value the backend's active development catalog actually returns (see `../sorting-puzzle-backend/contracts/configuration/v1/local-development-shop-catalog.json`, the seed `pnpm bootstrap:local` publishes).
- `mock_prices` follows the exact same shape as `configs/shop_catalog.json`'s `mock_prices` and is formatted by the same `MockStoreProvider`.
- `discount_percent`, `compare_at_prices`, and `tag` are optional and follow the same shape and
  presentation-only semantics as their `configs/shop_catalog.json` counterparts.
  `scripts/store/backend_catalog_source.gd` copies them onto the joined offer (`compare_at_prices`
  through the same `MockStoreProvider` price resolution as `mock_prices`; `discount_percent`/`tag`
  directly) so the Shop's discount badge and tag banner behave the same regardless of
  `shop_catalog_source`. An entry that omits them simply shows no badge/tag.
- A backend offer whose `platform_product_id` has no matching entry here is silently excluded from the Shop rather than shown without a price.
- This file is never treated as an eligibility source; only the backend's `eligible: true` field decides whether an offer is shown.

## `user://shop_catalog_backend_cache.json`

Purpose:
- Offline cache of the last successfully joined/priced backend Shop catalog, owned by `scripts/store/backend_catalog_cache.gd`. Only used when `shop_catalog_source` is `backend`.

Rules:
- Written after every successful `GET /v1/catalog` join (including an empty-catalog result).
- Read only when a later fetch fails (unavailable, unauthorized, or malformed); a failure with no prior cache surfaces as a Shop load error instead.
- Contains only already-public catalog/offer/mock-price data; never a token, signature, or other secret.

## Documentation Update Checklist

When changing scene, script, or config ownership:
- Update `docs/PROJECT_MAP.md` if navigation or system ownership changes.
- Update `docs/SCENES.md` if scene nodes, attachments, or scene responsibilities change.
- Update `docs/SCRIPTS.md` if script exports, dependencies, or boundaries change.
- Update this file if config shape, supported values, or validation rules change.
