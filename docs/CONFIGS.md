# Configs

This file describes data files that drive gameplay and tooling.

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

## `configs/levels/level_*.json`

Purpose:
- Defines one playable level.

File naming:
- Runtime loader expects `configs/levels/level_%03d.json`.
- Example: selected level `1` loads `configs/levels/level_001.json`.
- Missing selected levels fall back to `configs/levels/level_001.json`.

Top-level fields:
- `level`: numeric level identifier.
- `time_seconds`: countdown duration for the level.
- `layout_preset`: shelf placement preset used by `scripts/level.gd`; preset positions are authored in matching `scenes/layouts/layout_*.tscn` template scenes.
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
py scripts\tools\generate_level_shelves.py --shelf-count 9 --layer-count 2 --difficulty medium --seed 123 --require-solvable --stats
```

Use `--max-items-per-type` when a generated level should have a lower global item repetition cap than the layer-based default. If the item catalog cannot fill the board within that cap, the generator leaves additional slots empty rather than exceeding the requested cap.

Generated levels default to `--min-front-visible-triples 1`, so at least one item type starts with three visible front-layer copies across shelves. Use `--min-front-visible-triples 0` for layouts that should not force a starter visible triple candidate.

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
    "highlight": 100
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
- `rewards.abilities` may grant `hammer`, `shuffle`, and `highlight`; the UI labels `highlight` as Lantern.
- `mock_prices` is keyed by mock country code and contains the complete `formatted_price` plus ISO currency code. Missing regions fall back to `US` in the development provider.
- Real providers must ignore `mock_prices` and display the formatted string returned by Google Play or the App Store.
- Current mock catalog: one 3-hammer, 3-shuffle, 3-lantern, 1,000-coin starter bundle and five coin-only offers.

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

The gameplay snapshot retains the former schema-4 fields, adds
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
- Schema-4 migration retains campaign, coins, lives/timer, ability inventory, processed mock
  transaction ids, profile, settings, chest progress, and lifetime/weekly stars.
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
- `levels` maps campaign levels 1-8 to exact opaque configuration, level, and rules versions.
- `source.files` pins the authored Godot files used by that publication.
- Levels 9-10 remain explicitly excluded and produce no uploadable campaign operation.

Verification:

```powershell
& 'D:\Godot\godot.exe' --headless --path . --script scripts/tools/check_content_provenance.gd
pnpm --dir ..\sorting-puzzle-backend check:development-client-manifest
```

Both commands must pass before export. Missing, incomplete, stale, or digest-mismatched content
disables guest registration and synchronization while local campaign state remains writable.

## Leaderboard Provider Setting

Purpose:
- Selects the data source used by `LeaderboardService` without coupling the UI to backend details.

Field:
- `application/config/leaderboard_provider`: currently supports `mock` and defaults to it. Unsupported values warn and fall back to mock data until another provider is implemented.

See:
- `docs/LEADERBOARDS.md`

## Store Provider Settings

Fields:
- `application/config/store_provider`: currently supports `mock` and defaults to it. Unsupported values warn and fall back to the mock provider.
- `application/config/mock_store_country`: mock storefront country used to select development price strings. Defaults to `US`; the catalog also defines `UA`, `DE`, and `JP` examples.

Production integration must replace the mock provider with platform product queries and verified, server-idempotent purchase grants rather than trusting these development settings.

## Documentation Update Checklist

When changing scene, script, or config ownership:
- Update `docs/PROJECT_MAP.md` if navigation or system ownership changes.
- Update `docs/SCENES.md` if scene nodes, attachments, or scene responsibilities change.
- Update `docs/SCRIPTS.md` if script exports, dependencies, or boundaries change.
- Update this file if config shape, supported values, or validation rules change.
