# Configs

This file describes data files that drive gameplay and tooling.

## Support contact project setting

- `application/config/support_email` supplies the address shown by the native support FAQ and used
  for its prefilled general-support and inappropriate-ad-report `mailto:` actions.
- The committed `support@sortingpuzzle.example` value is intentionally a development placeholder.
  ADS-008 release readiness rejects reserved placeholder domains, so a deliverable owner-approved
  address must be injected before an ads-enabled release can pass.

## Chapter-selection project setting

- `application/config/chapter_selection_enabled` controls whether Main Menu exposes the chapter
  picker. It defaults to `false` for the Chapter 1-only release.
- The chapter catalog remains active while selection is hidden because campaign numbering, item
  progression, backgrounds, and saved progress still depend on the selected Chapter 1 identity.

## `configs/ads.json`

Purpose:
- Defines the bounded client ad switches and automatic-interstitial pacing limits.
- Contains no authoritative reward amounts, production ad-unit IDs, or secrets.

Contract:
- `provider_enabled` and the global/per-placement rewarded switches must all allow a voluntary
  placement before the provider is used.
- The initial release keeps `interstitial.enabled` false and `rollout_percent` zero. ADS-007 still
  ships its pacing implementation so a later approved policy can activate from current progress
  without backfilling historical completions.
- Missing, malformed, or out-of-range policy fails closed in `scripts/ads/ad_policy.gd`.

## `configs/ad_release_evidence.json`

Purpose:
- Records ADS-008 owner evidence for legal/privacy, store disclosure, dependency, and native-device
  release gates without pretending repository automation can approve those external decisions.

Contract:
- The initial policy is general-audience 3+, non-personalized ads, and no ATT prompt solely for ads.
- Every approval requires both `complete = true` and a durable non-empty evidence reference.
- The committed file remains incomplete until the named owner reviews are actually performed.
- `scripts/tools/check_ad_release_readiness.gd` combines this evidence with `configs/ads.json` and
  environment-specific project settings; any missing requirement exits non-zero.

## `configs/profile_frames.json`

Purpose:
- Defines the ordered cosmetic avatar-frame catalog used by the profile editor and reusable profile
  avatar view.
- Maps stable frame IDs to transparent frame textures and keeps the legacy-compatible default
  outside UI scripts.

Contract:
- `default_frame_id` references one entry in `frames` and is currently `frame_classic`.
- Frame IDs are unique, stable opaque identifiers saved as `avatar_frame_id`.
- Each frame references one transparent PNG under `assets/ui/avatar_frames/`. Every variant is
  normalized to the same 256x256 canvas and has a transparent circular opening of at least 190 px
  diameter, so the avatar layer beneath has the same guaranteed visible area under every frame.
- `frame_classic` keeps the original muted ring art. The eight color variants use the supplied
  glossy ring art, whose band is a few pixels thicker and reaches slightly closer to the canvas
  edge than `frame_classic`.
- `weekly_rank_required` gates the three weekly metal frames. `combo_required` gates the ×20
  fire-ring and ×50 phoenix frames. `completed_level_required` gates five level milestone frames
  at 20, 50, 100, 200, and 500. All remain visible while locked. Level milestones check the
  corresponding key in the saved completion map, so future levels need no frame-specific code.
- Selections are saved locally and sent through a signed `profile_edit` operation. The backend
  validates premium frame awards before accepting the selection.
- Opaque premium-frame review art lives in `assets/ui/avatar_frames/candidates/`; see
  `docs/AVATAR_FRAME_CONCEPTS.md`. These concepts are not catalog entries.

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
- `gameplay_background_mode` is `legacy` for Chapter 1's scene-authored wall/baseboard and generated floor-texture presentation or
  `artwork` for the chapter's full-screen gameplay texture. Chapter 1 uses `legacy`.
- `background_texture` and `selection_preview` must reference existing Godot textures.
  `background_texture` owns gameplay presentation, while `selection_preview` supplies both the
  chapter-selection cover and the production main-menu background for the selected chapter.

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
- Variant families use family-first IDs followed by a distinguishing suffix, such as
  `soda_can_lime`, `soda_can_strawberry`, and `juice_box_grape_tall`.
- Texture paths should point to imported Godot image assets.

## `configs/item_progression.json`

Purpose:
- Defines the independently configured item-art pool available to each chapter during level
  materialization.
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
- Every catalog item is scheduled in at least one chapter.
- An item may be unlocked only once within a chapter, but different chapter pools may reuse it.
- A level's available pool is the cumulative union of its chapter milestones whose
  `from_chapter_level` is not greater than that level's chapter-local number.
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
- `gameplay_mode`: optional board behavior. Omit it or use `classic` for every existing level; see
  [Collapsing shelf columns](#collapsing-shelf-columns) for `collapsing_columns`.
- `column_layout`: required by `collapsing_columns` and rejected by `classic`.
- `layout_preset`: shelf placement preset used by `scripts/level.gd`; preset positions are authored in matching `scenes/layouts/layout_*.tscn` template scenes.
- `difficulty`: generation metadata recording the difficulty preset used to create the shelf layout.
- `row_layouts`: optional row-by-row shelf placement and motion config. When present, its `shelf_count` total must equal the `shelves` length and it replaces `layout_preset` placement at runtime.
- `shelves`: ordered shelf list.

Preset naming:
- `grid_<columns>x<rows>` is a full rectangle; a suffix such as `_hollow` names the cells it omits.
- `staggered_rows_<a>_<b>_...` counts shelves per row, top to bottom.
- `staggered_columns_<a>_<b>_<c>` counts shelves per column, left to right.
- `shape_<silhouette>_<columns>x<rows>` is a static cutout silhouette inside the named bounding grid.
- `_moving_<count>_<placement>` marks moving rows.
- A level must declare exactly as many shelves as its preset has markers; a mismatch warns and falls
  back to `grid_3x3`.

Supported static layout presets:
- `grid_2x3`: 6 shelves arranged as two columns across three rows.
- `grid_3x2`: 6 shelves arranged as three columns across two rows.
- `grid_3x3`: 9 shelves.
- `grid_3x4`: 12 shelves.
- `grid_3x5`: 15 shelves.
- `grid_3x6`: 18 shelves arranged as three columns across six rows.
- `grid_4x3`: 12 shelves arranged as four columns across three rows.
- `grid_4x4_hollow`: 12 shelves arranged as a 4x4 field without its four inner cells.
- `shape_arch_3x5`: 11 shelves with occupancy `111/101/101/101/101` from top to bottom.
- `shape_cup_3x5`: 11 shelves with occupancy `101/101/101/101/111`.
- `shape_hourglass_3x5`: 9 shelves with occupancy `111/010/010/010/111`.
- `shape_keyhole_3x5`: 10 shelves with occupancy `111/101/111/010/010`.
- `shape_t_3x5`: 7 shelves with occupancy `111/010/010/010/010`.
- `shape_zigzag_3x5`: 10 shelves with occupancy `110/011/110/011/110`.
- `staggered_rows_2_3_2`: 7 shelves arranged as centered rows of two, three, and two shelves.
- `staggered_rows_3_2_3`: 8 shelves arranged as centered rows of three, two, and three shelves.
- `staggered_rows_2_3_3_2`: 10 shelves arranged as centered rows of two, three, three, and two shelves.
- `staggered_rows_3_4_4_3`: 14 shelves arranged as rows of three, four, four, and three shelves in a
  brick bond.
- `staggered_columns_4_3_4`: 11 shelves arranged as four left, three centered, four right.
- `staggered_columns_4_5_4`: 13 shelves arranged as four left, five centered, four right.
- `staggered_columns_5_4_5`: 14 shelves arranged as five left, four centered, five right.

Campaign Level 5 uses `grid_3x4` for its 12 shelves. Its two top-row dispensers therefore pass
through the preset-marker placement path and receive the dispenser-only lower-row clearance instead
of falling back to an unadjusted generic grid.

Supported layout presets with moving rows:

The visible counts below describe authored board footprints. Runtime travel expands to the full
playable background along the motion axis, so additional configured shelves can be visible.

- `grid_3x2_moving_5_bottom`: 11 shelves arranged as two static rows of three plus a bottom row of
  five moving shelves, three visible at 60 px/s to the right.
- `grid_3x3_moving_5_middle`: 14 shelves arranged as a static row of three, a row of five moving
  shelves, and two more static rows of three. Three moving shelves are visible at 60 px/s to the right.
- `grid_3x2_moving_5_5_center`: 16 shelves arranged as a static row of three, two counter-running
  rows of five moving shelves, and a static row of three. Three moving shelves per row are visible at
  60 px/s, the upper row to the right and the lower row to the left.
- `grid_3x2_moving_5_5_top_bottom`: 16 shelves arranged as a static 3x2 grid between two
  counter-running rows of five moving shelves. Three moving shelves per row are visible at 60 px/s,
  the upper row to the right and the lower row to the left. Level 12 uses it.
- `grid_3x3_moving_5_bottom`: 14 shelves arranged as a 3x3 static grid plus a bottom row of five
  moving shelves, three visible at 70 px/s to the right.
- `staggered_columns_4_moving_8_4`: 16 shelves arranged as a static column of four, a vertical belt
  of eight moving shelves, and a static column of four. Three moving shelves are visible at 55 px/s
  downward.
- `staggered_columns_5_moving_8_5`: 18 shelves arranged as a static column of five, a vertical belt
  of eight moving shelves, and a static column of five. Four moving shelves are visible at 55 px/s
  downward. This is the tallest board that fits the play area.
- `grid_2x4_moving_8_left`: 16 shelves arranged as a vertical belt of eight moving shelves down the
  left edge and a static 2x4 block beside it. Four moving shelves are visible at 60 px/s downward.
- `grid_1x4_moving_8_8_sides`: 20 shelves arranged as two vertical belts of eight moving shelves around
  a static column of four. Four moving shelves per belt are visible at 55 px/s, the left belt
  downward and the right belt upward.
- `shape_arch_3x5_moving_5_bottom`: 14 shelves arranged as a nine-shelf static Arch over a
  five-shelf horizontal belt. Three belt shelves are visible at 60 px/s to the left.
- `shape_hourglass_3x5_moving_5_waist`: 13 shelves arranged as the two static halves of an
  Hourglass around a five-shelf horizontal belt. Three belt shelves are visible at 60 px/s to the
  right.
- `shape_alternating_alcoves_3x5_moving_8_center`: 13 shelves arranged as a central eight-shelf
  vertical belt with five static shelves alternating left and right. Four belt shelves are visible
  at 60 px/s downward.
- `shape_side_elevator_steps_3x5_moving_8_left`: 15 shelves arranged as an eight-shelf vertical
  belt beside seven static staircase shelves. Four belt shelves are visible at 60 px/s downward.

Every built-in horizontal belt carries five shelves and every built-in vertical belt carries eight;
`tests/tools/test_generate_level_shelves.py` checks this against every layout scene.

The `vertical_wrap` presets above cannot be combined with horizontal moving rows in the same
level.

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
        "speed": 60,
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
- `visible_count` is optional. Moving rows default to a `3`-shelf authored footprint, clamped to
  `shelf_count`; static rows default to their full `shelf_count`. The moving-row footprint controls
  board fitting, while its travel window expands to the playable background at runtime.
- `motion.type` supports `horizontal_wrap` and `vertical_wrap`.
- `motion.speed` is pixels per second. Built-in campaign presets use `60` for an even cadence on
  common 60 Hz displays. Use `0` for a row that is structured as a moving row but currently stopped.
- `motion.direction` supports `right` and `left` for `horizontal_wrap`, and `down` and `up` for `vertical_wrap`. Vertical rows default to `down`, moving shelves from top to bottom.
- A level may use horizontal moving shelves or vertical moving shelves, but not both at the same time.
- The built-in `vertical_wrap` presets carry eight shelves per belt. Runtime wrapping also handles
  shorter belts or taller windows by extending the empty portion of the loop until a shelf can fully
  exit before re-entering on the other side.
- `visual_variant` supports `full` and `floor_only`. Moving rows default to `floor_only`; static rows default to `full`.
- Locked shelves are not allowed inside moving rows.
- `grid_3x3_moving_5_bottom` is a shorthand preset for three static rows of three shelves plus the bottom moving row from the example above.

Shelf shape:

```json
{
  "unlock_after_triples": 3,
  "layers": [
    ["milk_carton", "chips_can_classic", null],
    ["milk_carton", "chips_can_classic", "toy_robot"]
  ]
}
```

Layer rules:
- `type` is optional and defaults to `standard`. The only other value is `dispenser`.
- `unlock_after_triples` is optional. Omit it or set `0` for shelves that are accessible at level start.
- A positive `unlock_after_triples` keeps the shelf inaccessible until the player has cleared that many triples.
- The value counts cleared triples rather than pointer moves. Hammer-destroyed triples use the same
  runtime counter and continue to advance locked-shelf progress.
- Each shelf must contain a non-empty `layers` array.
- Each layer must contain exactly as many slots as the shelf type has: three for `standard`, one for `dispenser`.
- Slot values must be item ID strings or `null`.
- Layer `0` is the visible front layer.
- Later layers are hidden or previewed back layers that promote when the front layer clears.

Dispenser shelf shape:

```json
{
  "type": "dispenser",
  "layers": [["milk_carton"], ["chips_can_classic"], ["toy_robot"]]
}
```

Dispenser rules:
- A dispenser is a narrow, source-only shelf: the player can take the item on display but can never
  place onto it, so its authored queue is the only route its items take to the board.
- Between `2` and `4` layers, each exactly one slot wide.
- No `null` slots. A hole in a queue has nothing to hand out and nothing can move into it.
- A compact circular badge reuses the ability count-badge style and shows the exact remaining count.
  The attached stock rail contains one cell per authored layer (2-4), drawn as one continuous strip
  with a minimal outer outline and thin seams; taking an item pops and extinguishes the rightmost lit
  cell, while promoting the next item changes nothing because that item is still on the shelf.
- `unlock_after_triples` works the same as on a standard shelf.
- Not supported inside moving rows, which step and wrap on a single uniform cell width. The runtime
  warns and falls back to a standard shelf, the same way it handles locked shelves in moving rows.
- Hammer and shuffle skip dispensers so the authored queue survives; highlight still outlines the
  item on display.
- Static rows pack by each cell's own width so the narrow shelf sits flush against its neighbours. A
  dispenser with another row below moves upward by `DISPENSER_LOWER_CLEARANCE` so the overlapping
  badge/stock rail clears that row; standard neighbours keep their authored interlocked positions.
  `layout_preset` markers use the same per-dispenser adjustment.

Item count rules:
- Each item ID should appear in a multiple of three across the level, dispenser items included.
- The runtime clears three identical visible items on one standard shelf; dispensers never match.

Runtime behavior:
- `scripts/level.gd` instantiates standard static cells from `scenes/shelf.tscn` and cells belonging
  to a moving row from `scenes/moving_shelf.tscn`. Moving shelf art can be edited independently;
  shelf counts, item layers, and the existing `full`/`floor_only` config values do not change.
- `scripts/level.gd` uses `layout_preset` to load `scenes/layouts/layout_%s.tscn`, then places generated shelf cells at the template's `ShelfXX` markers.
- Layout template `MovingRowXX` nodes with `scripts/shelf_layout_row.gd` create moving rows from authored row positions and metadata.
- Moving-row `visible_count` defines the authored footprint used to fit and center the board, not a
  cap on shelves visible at runtime. After fitting, horizontal belts span the full safe background
  width and vertical belts span the playable wall from below the HUD to the back-wall bottom
  boundary. Taller screens can show more of the same configured shelves; none are duplicated.
- Static shelf left/middle/right visuals are derived from authored shelf positions or `row_layouts`
  order at runtime; there is no per-shelf config field for row placement. Dispensers carry their own
  complete frame and are excluded from that ordering, so a lone standard shelf among dispensers uses
  the `single` presentation with both exposed backboard ends tapered.
- If `row_layouts` is present, `scripts/level.gd` creates shelves row by row instead. Moving rows are clipped to their visible window and wrap shelves horizontally or vertically according to their motion type.
- `scripts/level.gd` uses `time_seconds` as the active timer.
- Locked shelves show a runtime lock overlay with the remaining triple count on the lock and cannot be used as move sources, move targets, match clears, promotions, or ability targets until unlocked.
- Partially clipped moving shelves keep their visible items pickable even after the shelf center
  leaves the window. Pickup is limited to the visible part of each item's hit area; drops and
  occupied-slot fallback require visible slot markers. Fully off-window shelves remain unavailable
  to drag/drop, but abilities can still target their front-layer items.
- Hammer clears count as cleared triples for shelf unlocking. If no unlocked visible/front item type has three available copies, hammer can combine visible/front items with first-back-layer copies of the same type to reach a triple.

Validation:

```powershell
py scripts\tools\validate_level_solvable.py configs\levels\level_001.json --max-states 20000 --max-depth 200
```

The validator checks `row_layouts` totals, moving-row motion fields, supported visual variants, rejects locked shelves inside moving rows, and rejects levels that mix horizontal and vertical moving shelves. For preset-defined moving rows, the validator mirrors the moving-row metadata from the matching layout template.

Shelf kind is part of the search state: layer width comes from the kind, dispensers are validated as
2-4 single-item layers with no holes, and the search treats them as move sources but never as move
targets. Matching is gated on the kind for a reason worth keeping -- a dispenser layer is one slot
wide, so "every slot holds the same item" is trivially true for it, and an ungated settle step would
clear every dispenser on sight, hand out free triples, and report unsolvable boards as solvable.
Solvability search treats moving rows as eventually accessible and does not model shelf positions over time.

Generation:

```powershell
py scripts\tools\generate_level_shelves.py --shelf-count 9 --layer-count 2 --item-type-count 7 --difficulty medium --seed 123 --full-level --level-number 2 --output configs\level_templates\level_002.json --require-solvable --stats
py scripts\tools\materialize_level_templates.py
```

`scripts\tools\regenerate_level.py` runs both steps for a single level. It takes every
`generate_level_shelves.py` argument, derives the template path from `--level-number`, and writes
`configs\level_templates\level_NNN.json` plus `configs\levels\level_NNN.json` only when generation
and materialization both succeed:

```powershell
py scripts\tools\regenerate_level.py --level-number 2 --shelf-count 9 --layer-count 2 --item-type-count 7 --difficulty medium --seed 123 --stats
```

Differences from calling the two tools by hand:

- `--level-number` is required and `--output` is rejected, because the level number selects which
  shipped template is replaced.
- `--require-solvable` is on unless `--allow-unsolvable` is passed.
- Only the regenerated level is materialized, so other stale runtime levels are left alone; run
  `materialize_level_templates.py` for a full sweep.
- Top-level template differences, such as a hand-edited `layout_preset` or `time_seconds`, are
  printed before the file is replaced. Generation does not preserve post-generation hand edits.
- `--dry-run` reports those differences without writing.
- Both written files are hashed in `configs/backend/content_provenance.json`, so regeneration makes
  the published content digest stale.
- Every file is written with LF line endings, matching `.gitattributes`, so working-tree bytes
  equal the committed bytes on Windows too.

### Adding a new campaign level

A level must belong to a chapter before it can be materialized, because its item art comes from
that chapter's pool. It cannot be added to `configs/chapters.json` by hand first either: the runtime
chapter catalog rejects a chapter that lists a level whose `configs/levels/` file does not exist.
Pass `--chapter` for a level that no chapter lists yet:

```powershell
py scripts\tools\regenerate_level.py --level-number 11 --chapter chapter_01 --shelf-count 9 --layer-count 2 --item-type-count 7 --difficulty medium --seed 11011 --stats
```

- The level ID is appended to that chapter's `level_ids`, and the chapters config is written in the
  same step as the template and runtime level, only after materialization succeeds. The change is
  one line, because `level_ids` arrays keep their inline formatting.
- Without `--chapter`, an unassigned level fails with the list of chapters and their levels.
- A level a chapter already lists needs no `--chapter`. Naming a different chapter is rejected:
  moving a level changes its item pool and campaign position, so that is a hand edit.
- A level ID that skips unassigned campaign IDs, such as `14` after `10`, is reported as a warning.
- `--chapter` is not recorded in the generation manifest. Chapter membership is catalog state owned
  by `configs/chapters.json`, and replaying an existing level does not need it.
- A new level is also absent from `supported_campaign_levels` in
  `configs/backend/content_provenance.json`, which the run reports.

### Generation manifest

Every successful run records itself in `configs/level_templates/generation_manifest.json`, so a
level can be rebuilt later without recovering its arguments from git history. Pass `--no-record` to
skip the update. The file is ignored by `materialize_level_templates.py`, whose glob only matches
`level_*.json`.

```json
{
  "schema_version": 1,
  "entries": {
    "level_002.json": {
      "command": "py scripts/tools/regenerate_level.py --difficulty medium ... --seed 2034 ...",
      "generated_at": "2026-09-25T01:11:51Z",
      "resolved_seed": 2034,
      "template_sha256": "e1c9fd0419c57c4d...",
      "arguments": { "--shelf-count": 9, "--difficulty": "medium", "...": "..." }
    }
  }
}
```

- `arguments` is the replay contract and holds every generator argument, defaults included, so a
  later change to a generator default cannot silently change what a replay produces. `command` is
  derived from it for reading and pasting; the structured values are what a future batch
  regeneration should consume.
- Values are recorded as the generator resolved them, not as they were requested. `--seed` is the
  seed the board actually came from, which matters when none was given or a `--require-solvable`
  retry advanced it, and `--layout-preset` is the preset the template was wrapped with. Collapsing
  levels record no preset, because replaying one with a preset is rejected.
- `template_sha256` is the template as generated. A later mismatch against the file on disk means
  the template was hand-edited after generation, and regenerating it will revert that edit. The hash
  covers whitespace, so a tool that only re-indents the file trips it too: levels 2-8 were rewritten
  in a mixed tab and two-space style minutes after they were generated, with identical parsed JSON.
  Compare parsed JSON to tell a re-indent from a real edit, and replaying the entry's `command`
  with `--no-record` restores the exact bytes.
- Entries stay sorted by file name, and an unreadable or unsupported manifest stops the run before
  any level file is replaced.

`--item-type-count` creates `item_01` through the requested count. When it is omitted, the generator
uses `ceil(target_filled_slots / preferred_copies_per_type)` to infer the logical type count.
`--preferred-copies-per-type` accepts integers or fractions of at least `3` and defaults to `3`.
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

Read those readiness ratios for what they are: a per-layer-depth count of copies, not a count of
matches the player can make. A triple clears only when all three copies sit on **one shelf's** front
layer, and placement spreads a layer's copies across every shelf in it, so a layer reported as
triple-ready routinely offers no match anyone can act on. Judge a board by `collectible_front_types`
and the `flow` block instead, both of which count only what can actually be gathered.

Generated levels default to `--min-front-visible-triples 1`: at least one item type must be one the
player can genuinely complete a triple with on the opening board, counting only types whose copies
can be brought onto a single shelf. Use `0` for layouts that should not force a starter match.
Raising it well above what a board reaches naturally is counterproductive — copies pulled forward to
satisfy it occupy the free slots a gather needs, so the count rises while the board gets less
playable.

### Board flow

`--pair-ratio` (default `0.5`) seeds that share of each layer's pair-capable shelves with two copies
of one item beside a free slot, which is a one-move match. Placement alone lands very few of these.
Swaps stay inside one layer depth, so the per-depth composition the distribution engine solved for is
untouched and only the shelf a copy sits on changes; item counts, layer readiness, the per-layer
repetition cap and each item's layer range all come out unchanged. `0` disables the pass.

Measured on 18x3 medium boards, comparing `0.5` against `0.0` on the same seed, 20 seeds each:

| item types | scarce-ratio change | average-options change | seeds better / tied / worse |
| --- | --- | --- | --- |
| 30 | -4.9pp (median -4.5) | +0.07 | 10 / 4 / 6 |
| 22 | -2.4pp (median -2.7) | +0.09 | 10 / 4 / 6 |

So it is a mild but consistent gain on the metric worth caring about, not a fix on its own; its
practical value is that fewer attempts get rejected by the flow gate. The best ratio varies by board
— on some shapes `1.0` measured better and on others worse — so treat `0.5` as a starting point and
read `--stats` rather than assuming it is optimal for a given level.

`--min-average-options` and `--max-scarce-option-ratio` reject a generated board that does not give
the player enough to do:

```powershell
py scripts\tools\regenerate_level.py --level-number 12 --shelf-count 18 --layer-count 3 `
    --item-type-count 44 --difficulty medium --seed 1035551170 `
    --min-average-options 2.0 --max-scarce-option-ratio 0.35 --stats
```

- `scripts/tools/level_flow.py` walks every attempt before the solvability search, so a board that
  would play badly is thrown back before anything expensive is spent proving it can be finished.
- `--max-scarce-option-ratio` caps the share of moves offering at most one completable type. That is
  the metric to gate on: a level can average four options and still spend its last quarter at one,
  which an average hides and this does not.
- Retries only happen under `--require-solvable`, which `regenerate_level.py` turns on by default.
  With a bare `generate_level_shelves.py` run a board below the bar fails the run instead.
- Boards with fewer than four triples are never judged; a tutorial has one option because one triple
  is the whole level.
- Inspect any level, shipped or generated, with `py scripts\tools\level_flow.py <level.json>`.

The walk's option counts are a heuristic, not a proof. They rank boards against each other reliably,
but its greedy player is more consistent than a person: a board it handles well can still feel worse
in a playtest, while a board it does badly on is the reliable signal. Whether the walk *finished* is
different: it plays legal moves through the solver's own rules, so a walk that clears the board is a
solvability proof, and the generator accepts it as one without running the search
(`validation.reason: "flow_walk"`).

Current authored generation parameters:

Levels 2-8 have manifest entries as of 2026-09-25 and were regenerated together against the flow
gate. `generation_manifest.json` is the source of truth for their exact arguments; this list is the
readable summary. Every level below also records `--pair-ratio 0.5`, `--max-generation-attempts 100`
and `--validator-max-states 400`. Each keeps the shelf count, layer count, layout, timer, locks and
dispensers the level shipped with, and none carries fewer items than the board it replaced, so the
regeneration did not thin out item variety.

- Level 2: 9 shelves, 2 layers, `grid_3x3`, medium, 300 s, 16 item types of three copies, seed 2034.
- Level 3: 12 shelves, 2 layers, `grid_3x4`, medium, 180 s, shelf 3 locked behind 5 triples, 21 item
  types of three copies, seed 3014.
- Level 4: 13 shelves, 2 layers, `staggered_columns_4_5_4`, medium, 360 s, shelves 5 and 9 locked
  behind 5 and 10 triples, 22 item types of three copies, seed 4025.
- Level 5: 12 shelves, 3 layers, `grid_3x4`, hard, 420 s, dispenser shelves at positions 1 and 3
  holding three items each, `--item-type-count 17` (nine types of three copies, eight of six),
  seed 5036.
- Level 6: 11 shelves, 3 layers, `grid_3x2_moving_5_bottom`, medium, 420 s, 28 item types of three
  copies, seed 6007.
- Level 7: 16 shelves, 2 layers, `grid_2x4_moving_8_left`, hard, 300 s, 27 item types of three
  copies, seed 7035.
- Level 8: 14 shelves, 3 layers, `grid_3x3_moving_5_bottom`, hard, 300 s, `--item-type-count 15`
  (nine types of six copies, six of nine), seed 8012.

The flow bar (`--min-average-options` / `--max-scarce-option-ratio`) is 2.5 / 0.30 for levels 2, 3,
4, 6 and 8, whose previous boards all failed it. Levels 5 and 7 already played well (2.72 average
options with 5.3% scarce moves, and 3.51 with 9.9%), so their bars, 2.7 / 0.08 and 3.0 / 0.15, sit
at what the old boards measured instead of at the looser floor. Before this pass a plain greedy
player stalled partway through levels 4, 6 and 8; all seven now finish.

Item counts are not a generator input: unless `--item-type-count` is passed they follow from the
filled-slot count, which is drawn from the difficulty's empty-ratio range per seed. Levels 2, 3, 4
and 8 shipped at the densest end of that range, so a random seed usually returns fewer items. The
seeds above were chosen by scanning for a board that keeps the shipped count, passes the flow bar
and solves, so a plain `--seed` replay reproduces each one.

How these were recovered: before the manifest, a level's arguments survived only in its template's
`seed` and `difficulty` fields, and those went stale. Level 6 changed from 13 shelves and 15 types
to 11 shelves and 27 types while its `seed` stayed 6007, and level 5's 5005 predates the dispenser
board beside it. Levels 2 and 3 never recorded a seed. Structure was read back from the shipped
templates, and replaying the recorded seeds against 15 historical generator versions reproduced only
level 8, exactly, under the generator at commit `82b198a` with `--shelf-count 14 --layer-count 3
--difficulty hard --seed 8008 --item-type-count 15`. The previous boards for levels 2-7 cannot be
regenerated, so these are new boards with the same shape.

- Level 9 is the campaign's first `collapsing_columns` board: three columns of nine one-layer
  shelves, an authored window of four, 14 logical item types, medium difficulty, and seed 9009.
  Columns are deliberately taller than `MAX_VISIBLE_SHELVES_PER_COLUMN`, so shelves still wait
  above the window on the tallest supported screen.

Use `--locked-shelves` to add unlock requirements to generated shelves. Entries are 1-based shelf numbers and required cleared triples:

```powershell
py scripts\tools\generate_level_shelves.py --shelf-count 9 --layer-count 2 --difficulty medium --locked-shelves 7:3,8:5 --validate
```

By default the lock goes on whatever the generator put at that position, and the generator never
considered the locks. That works for one or two low locks, but not for several or high ones. With
three copies per type, one locked copy freezes its whole type, so the open shelves start with pairs
whose third copy is locked and too few free slots to dig for anything else. Add
`--lock-placement playable` to choose which generated shelves go behind the locks instead:

```powershell
py scripts\tools\regenerate_level.py --chapter chapter_01 --level-number 18 `
    --layout-preset staggered_columns_5_6_5 --shelf-count 16 --layer-count 3 --difficulty hard `
    --max-items-per-type 3 --validator-max-states 400 --dispenser-shelves 6:3,11:3 `
    --locked-shelves 1:4,5:8,12:12,16:16 --lock-placement playable --stats
```

- Whole shelves are permuted, never items, so every shelf's contents, pairs and layer readiness stay
  exactly as generated. The requested positions stay locked and dispensers never move.
- Measured on that command over seeds 18000-18019: `as-generated` accepted 0 of 20 attempts, where
  a plain greedy player cleared at most 9 of 35 triples, often only 1-2 before the first lock at 4.
  With `playable`, 5 of the first 10 attempts were accepted, each proven by the flow walk, averaging
  1.7-2.7 options per move. An attempt costs about 5 s when accepted and 12-15 s when rejected.
- Raising `--validator-max-states` does not rescue these boards (400, 5,000 and 30,000 all fail),
  and neither does an easier `--difficulty`.
- The flag is opt-in so manifest entries recorded before it existed still replay to the same board.

Use `--dispenser-shelves` to add source-only dispenser shelves. Entries are 1-based positions and
layer counts (`2` to `4`), and they count against `--shelf-count`:

```powershell
py scripts\tools\generate_level_shelves.py --shelf-count 11 --layer-count 2 --item-type-count 7 --difficulty medium --dispenser-shelves 10:3,11:2 --require-solvable
```

The distribution engine is untouched: it lays out only the standard shelves, and the queues are then
stocked by relocating items out of the deepest layers, so every item ID keeps the multiple-of-three
count it was given. Because relocation can change whether a board is winnable, pair the flag with
`--require-solvable` so the search re-runs afterwards instead of assuming a solution survived.

### Collapsing shelf columns

`gameplay_mode: "collapsing_columns"` replaces the classic board with tall vertical columns of
one-layer shelves. When a shelf becomes empty it is destroyed permanently and every shelf above it
in the same column falls one position, so the level is finished when no shelf is left rather than
when no item is left. `gameplay_mode` is optional and defaults to `classic`; every existing level
loads unchanged.

```json
{
  "level": 11,
  "time_seconds": 300,
  "gameplay_mode": "collapsing_columns",
  "column_layout": {
    "shelf_counts": [8, 8, 8],
    "visible_shelves_per_column": 4
  },
  "shelves": [
    { "layers": [["item_01", "item_02", null]] },
    { "layers": [["item_03", "item_01", "item_02"]] }
  ]
}
```

Contract rules:
- `column_layout.shelf_counts` is a non-empty array of positive integers, one per column, ordered
  left to right. Its total must equal the `shelves` length.
- The flat `shelves` array is consumed column by column, left to right, and bottom to top within each
  column. This ordering is the contract; it is never inferred from node names or coordinates.
- `column_layout.visible_shelves_per_column` is a positive integer no greater than
  `MAX_VISIBLE_SHELVES_PER_COLUMN` (`8`). It may exceed a shorter column's height.
- Every shelf must be `standard`, must have exactly one layer, and that layer must hold exactly three
  item ID or `null` slots.
- Every authored shelf must contain at least one item. A fully empty authored shelf would be
  destroyed before the player could touch it and is rejected as a content error.
- Each item ID must still appear a multiple of three times across the level.
- `layout_preset`, `row_layouts`, `type: dispenser`, a positive `unlock_after_triples`, and non-empty
  `sticky_items` are all rejected in this mode. Each needs its own compatibility task with solver
  fixtures before content may use it.
- Animation durations, easing, spacing, and presentation offsets are scene and script properties, not
  level-content fields, and never affect solvability.
- The runtime fails closed on an invalid collapsing level. It never falls back to `grid_3x3`, because
  the same shelves array means something different under each mode.

What `visible_shelves_per_column` means:
- It is the **guaranteed minimum** window. Every supported viewport reveals at least this many
  shelves per column, and it is the count the solver and generator prove the level against.
- The runtime may reveal **more** shelves per column when the fitted board has room, up to
  `MAX_VISIBLE_SHELVES_PER_COLUMN` and the column's own height. The resolved count is decided once
  when the level is built and never changes during play.
- Proving the minimum proves every larger window: a larger window only ever adds legal moves, and the
  only extra forced event it can trigger is an automatic triple clear, which destroys a shelf and so
  only advances the objective.

Validation and solvability:

```powershell
py scripts\tools\validate_level_solvable.py configs\levels\level_011.json --show-solution
```

The validator selects a mode-specific rules object rather than branching through every helper.
`CollapsingColumnsRules` restricts sources, targets, and matching to the shelves inside each column's
visible window, destroys every active shelf whose only layer is empty, compacts the column while
preserving survivor order, reveals the next shelves, and repeats until the board is stable. Its
canonical state keeps column membership and bottom-to-top order, normalizing only slot order inside
one shelf, so two boards that differ in pile topology are never treated as the same position. Moves
address shelves by **stable authored shelf ID**, so a reported solution stays replayable after
earlier shelves have disappeared, and `solution_indexing` stays `authored_1_based`.

Item-count checks alone are not sufficient in this mode: a board can hold three copies of every item
and still deadlock because the workspace needed to finish a triple is hidden behind a shelf that can
never be emptied first.

Runtime behavior:
- `scripts/level.gd` builds `scenes/collapsing_shelf_board.tscn` with one
  `scenes/collapsing_shelf_column.tscn` per column and standard `scenes/shelf.tscn` shelves; see
  `docs/SCENES.md` and `docs/SCRIPTS.md` for ownership.
- Every visible shelf is playable. Shelves above the window are hidden and are never move sources,
  drop targets, automatic-match candidates, or Hammer, Shuffle, or Highlight targets.
- A shelf is destroyed once a committed move, a triple clear, or Hammer leaves it with no items.
  Lifting an item into a drag never empties its shelf.
- Every column keeps its last three shelves (capped at `visible_shelves_per_column`): once a column
  is down to them, an emptied shelf stays as an ordinary empty shelf, so the board ends as a full
  grid with room to sort. It is a fixed rule, not a config field.
- All shelves emptied in one resolution pass collapse together, and columns animate in parallel.
  Play continues on every surviving shelf while they fall; abilities wait until every column
  settles. The countdown keeps running, as it does through match-clear animations, and Freezer does
  not stop the movement.
- The level completes once no item is left and nothing is resolving or collapsing.
- No remaining-shelf count is shown.

Development fixture: `configs/test_levels/collapsing_columns_preview.json` is three columns of ten
shelves with an authored window of four, proven solvable in 50 moves, and is played by
`scenes/testing/collapsing_columns_preview.tscn`. See [COLLAPSING_SHELF_COLUMNS.md](COLLAPSING_SHELF_COLUMNS.md).

Generation:

```powershell
py scripts\tools\generate_level_shelves.py --gameplay-mode collapsing_columns --column-heights 6,6,6 --visible-shelves-per-column 4 --item-type-count 12 --difficulty medium --seed 11011 --full-level --level-number 11 --output configs\level_templates\level_011.json --require-solvable --stats
py scripts\tools\materialize_level_templates.py
```

- `--column-heights` determines the shelf count; passing `--shelf-count` as well is rejected.
- `--visible-shelves-per-column` is required and becomes the authored minimum window.
- `--layer-count` and `--filled-layer-count` default to `1` and may not be anything else.
- `--dispenser-shelves`, `--locked-shelves`, `--sticky-items-percent`, and `--layout-preset` are
  rejected with an argparse error rather than being silently ignored.
- Items are distributed across the whole authored stack, hidden shelves included. A shelf the
  distribution left empty receives one item moved from the fullest other shelf, so every item keeps
  its multiple-of-three copy count; the move count is reported as `rescued_empty_shelves`.
- `--min-front-visible-triples` is judged on the shelves the level opens with, not the whole stack;
  an attempt that fails it is retried under `--require-solvable`.
- Every candidate is validated with `CollapsingColumnsRules`, and under `--require-solvable` no file
  is written unless the search proves the board solvable.
- `--stats` adds `gameplay_mode`, `column_heights`, `visible_shelves_per_column`,
  `total_shelf_count`, `active_shelf_count`, `hidden_shelf_count`, `active_occupied_slots`,
  `active_collectible_front_types`, and `rescued_empty_shelves` alongside the existing attempt and
  validation fields.

Materialization keeps `gameplay_mode` and `column_layout` unchanged, maps items on hidden and
active shelves alike from the flat `shelves` array, and never infers item identity from column
position. `materialize_level()` validates the board contract first, so a malformed column layout
fails before a stale runtime level can be written.

### Throwing dispensers

`gameplay_mode: "throwing_dispensers"` opens an **empty** shelf layout with one or more dispensers
mounted above it. Every item in the level starts inside a dispenser; tapping one throws the next
`throw_count` items into random free slots. The level is finished when no item is left on the board
and every dispenser is empty. `gameplay_mode` is optional and defaults to `classic`; every existing
level loads unchanged.

The **dispensers** here are a different object from the `"type": "dispenser"` **dispenser shelf**
above, which is a narrow source-only shelf the player drags items off. The two never appear in the
same level.

```json
{
  "level": 21,
  "time_seconds": 300,
  "gameplay_mode": "throwing_dispensers",
  "layout_preset": "grid_3x4",
  "throw_seed": "00000000000052ad",
  "dispensers": [
    { "throw_count": 3, "contents": ["item_01", "item_02", "item_01"] },
    { "throw_count": 3, "contents": ["item_02", "item_01", "item_02"] }
  ],
  "shelves": [
    { "layers": [[null, null, null]] }
  ]
}
```

Contract rules:
- `dispensers` is a non-empty array, ordered left to right. That order is the contract, and it is
  the order they are placed above the board in.
- `contents` is a non-empty array of item ID strings in the order they are handed out. `null` is
  rejected: a hole has nothing to throw and, unlike a shelf slot, nothing can ever move into it.
- `throw_count` is a positive integer. A value larger than the board could ever hold is reported,
  because a throw clamped to the board is not the throw its author described.
- `throw_seed` is a 16-digit lowercase hex string. The shape is checked rather than coerced: a wrong
  length, uppercase, or an `0x` prefix all silently change the scatter the level was tuned against.
- Every shelf must be `standard`, must have exactly one layer, and that layer must hold exactly three
  `null` slots. An item authored onto the board is an item the playability estimate never accounted
  for.
- Each item ID must appear a multiple of three times **across dispensers**, which is where a level's
  items now live.
- `row_layouts`, `column_layout`, `type: dispenser`, a positive `unlock_after_triples`, and non-empty
  `sticky_items` are all rejected. `layout_preset` is expected, not exclusive: it is how this mode
  places its empty board.
- The runtime fails closed on an invalid level. It never falls back to `grid_3x3`, because a level in
  this mode authors an empty board and a fallback would open a board that cannot be filled.

The reserved free slot:
- A throw lands `min(throw_count, remaining stock, free slots - 1)` items and keeps the rest. The
  `- 1` is a fixed rule, not a config field.
- Without it a board can reach zero free slots. A move needs a free slot to land in, so such a board
  has no legal move and, with every item already thrown, no way to regain one.
- A consequence worth knowing when authoring: a throw can never fill the board's *last* slot, so a
  board too small to hold a spare slot beside a triple can never be completed. A one-shelf level is
  the degenerate case and the playability estimate reports it as unplayable.

Validation and playability:

```powershell
py scripts\tools\validate_level_solvable.py configs\test_levels\throwing_dispensers_preview.json
```

This mode is **sampled, not proven**, and the report says `playability` rather than `solvable`. The
contents arrive over time and land in random slots, and which slots are free depends on the player's
move order, so there is no single line of play to prove. `ThrowingDispensersRules` plays the level
`--playability-trials` times (default 200) with a greedy player and requires a
`--playability-threshold` completion rate (default 0.95). See
[THROWING_DISPENSERS.md](THROWING_DISPENSERS.md#solvability-sampled-not-proven).

Development fixture: `configs/test_levels/throwing_dispensers_preview.json` is a `grid_3x4` board of
twelve empty shelves and two dispensers holding fifteen items each, played by
`scenes/testing/throwing_dispensers_preview.tscn`.

Generation:

```powershell
py scripts\tools\generate_level_shelves.py --gameplay-mode throwing_dispensers --shelf-count 12 `
    --layout-preset grid_3x4 --dispenser-count 2 --throw-count 3 --item-type-count 10 `
    --difficulty medium --seed 4242 --full-level --level-number 21 --time-seconds 300 `
    --require-solvable --stats
py scripts\tools\materialize_level_templates.py
```

- `--dispenser-count`, `--throw-count`, and `--item-type-count` are required; `--throw-seed` is
  derived from `--seed` when omitted, so regenerating a level reproduces its scatter as well as its
  contents.
- `--layer-count` and `--filled-layer-count` default to `1` and may not be anything else.
- `--dispenser-shelves`, `--locked-shelves`, and `--sticky-items-percent` are rejected with an
  argparse error: the board is authored empty, so a flag that shapes a shelf's contents has nothing
  to act on.
- The three throwing flags are likewise rejected outside this mode.
- Under `--require-solvable` the generator reshuffles up to `--max-generation-attempts` times and
  writes nothing unless a candidate reaches the playability threshold.
- `--stats` reports `gameplay_mode`, `dispenser_count`, `throw_count`, `board_slots`, `total_items`,
  `throw_seed`, and the full `playability` block.

Materialization keeps `gameplay_mode`, `throw_seed`, and every `throw_count` unchanged, and maps the
logical `item_NN` tokens inside each dispenser's `contents` in place, so the authored hand-out order
survives. Logical identities are collected from dispensers as well as shelves; reading only the
shelves would report a level in this mode as having no items at all.

### Sticky items

Each standard shelf may include `sticky_items: [{"layer": 0, "slot": 1}]`, using zero-based
coordinates and at most one occupied sticky slot per individual layer. Multiple layers may each
have one. The metadata survives abstract-to-runtime materialization; dispensers cannot use it.
`--sticky-items-percent 10` adds deterministic placement, counting all items and capping at occupied
standard layers. Use `--require-solvable` to validate the final sticky board; failed proof never
overwrites output. See [STICKY_ITEMS.md](STICKY_ITEMS.md) for schema, rounding, statistics, and
publication constraints. The isolated comparison board is `configs/test_levels/sticky_items_preview.json`.

## `configs/gameplay_tips.json`

Purpose:
- Chooses which campaign level shows which first-time gameplay tip. See
  [GAMEPLAY_TIPS.md](GAMEPLAY_TIPS.md).
- Loaded by `scripts/gameplay_tip_catalog.gd` when `scripts/level.gd` arms a tip after the loading
  reveal.
- Presentation only. It is deliberately separate from `configs/levels/level_*.json`, whose bytes are
  hashed into `configs/backend/content_provenance.json`, and it is not in that manifest's file list.

Shape:

```json
{
  "tips": [
    {
      "id": "level_10_tap_dispenser",
      "level": 10,
      "type": "tap_dispenser",
      "message": "Tap a dispenser to throw items onto the shelves!",
      "start_delay_seconds": 0.6,
      "reshow_delay_seconds": 1.5
    }
  ]
}
```

Rules:
- `id`: non-empty string of at most 64 characters, unique. It is the key saved in
  `PlayerProgress`'s `seen_gameplay_tips` preference, so renaming an id shows that tip again to
  players who already saw it.
- `level`: positive whole-number campaign level. At most one tip per level.
- `type`: `move_to_triple` (a hand drags an item onto the shelf holding most of its type) or
  `tap_dispenser` (a hand taps the first stocked throwing dispenser). A `tap_dispenser` tip on a level
  without dispensers is skipped with a warning.
- `message`: optional English source text for a bubble under the hand, shown through `tr()`.
- `start_delay_seconds` / `reshow_delay_seconds`: optional, 0-10, default 0.6 and 1.5. The first is
  the wait after the loading reveal; the second is the wait after the tip was suspended.
- Any error fails closed: every error is reported and no tip is served at all.

## `configs/combo_scoring.json`

Purpose:
- Defines the combo tiers: how long the player has to land the next triple and how many stars each
  triple earns, by combo value.
- Owned by `scripts/combo_scoring_rules.gd` and used by `scripts/level.gd`. A missing or invalid file
  logs an error and falls back to the built-in `DEFAULT_TIERS`, which mirrors this file.

Shape:

```json
{
  "tiers": [
    { "min_combo": 1, "window_seconds": 15.0, "stars_per_triple": 1 },
    { "min_combo": 4, "window_seconds": 10.0, "stars_per_triple": 2 },
    { "min_combo": 7, "window_seconds": 7.0, "stars_per_triple": 3 },
    { "min_combo": 10, "window_seconds": 5.0, "stars_per_triple": 4 },
    { "min_combo": 15, "window_seconds": 4.0, "stars_per_triple": 5 },
    { "min_combo": 20, "window_seconds": 3.0, "stars_per_triple": 7 }
  ]
}
```

Rules:
- A tier runs from its `min_combo` to the next tier's `min_combo` minus one; the last is open-ended.
  The first tier must start at `1` and `min_combo` must strictly increase.
- The triple that brings the combo to ×N earns ×N's `stars_per_triple`. ×N's `window_seconds` is
  then the time allowed to land ×(N+1) before the combo resets, so the HUD fill refills to the new
  tier's window on every triple.
- Several triples cleared by one move each advance the combo by one and are scored by their own
  tier. A 5-triple chain earns 1 + 1 + 1 + 2 + 2 = 7 stars.
- Stars only count once the player has started the timer, and not after the level is failed or
  completed.
- `window_seconds` must be positive and `stars_per_triple` non-negative.
- Backend: production settlement accepts the client's star claim (backend ADR 0019, capped at
  10,000), so changing this file needs no backend release. The dormant replay validator in
  `../sorting-puzzle-backend` still describes the old rules: one flat 8-second window, with stars
  equal to the combo count (`createLaunchPuzzleRules` scoring and "Combo and stars" in
  `docs/GAMEPLAY_VALIDATOR_BOUNDARY.md`). Reactivating it requires a new rules version that
  implements these tiers.

## `configs/reward_chest_goals.json`

Purpose:
- Defines the reward chest star goals shown by `scenes/ui/main_menu_reward_chest.tscn`.
- Owned by `scripts/player_progress.gd`, which loads the configured goal ladder and falls back to built-in defaults if the file is missing or invalid.

Shape:

```json
{
  "goals": [
    { "stars": 500, "coin_reward": 100, "ability_rewards": { "hammer": 1, "shuffle": 1, "highlight": 1, "freezer": 1 } },
    { "stars": 1000, "coin_reward": 225, "ability_rewards": { "hammer": 1, "shuffle": 1, "highlight": 1, "freezer": 1 } }
  ]
}
```

Rules:
- `goals` must be an ordered list of objects with a positive `stars` target.
- `coin_reward` is the number of gold coins granted when that goal is reached.
- `ability_rewards` grants the configured number of Hammer, Shuffle, Highlight, and Freezer uses on each crossing. Omitted values default to zero for older configurations.
- Legacy numeric entries such as `500` are still accepted as star goals with `0` coin reward.
- The saved `reward_chest_goal_index` selects the active goal.
- When saved chest stars reach the active goal, the configured coins and ability uses are added to the player's saved inventory, the goal starts over with remaining stars carried forward, and the next configured goal becomes active. Each crossed goal grants its rewards once, including multiple crossings in one completion.
- After the final configured goal is reached, the final goal value repeats.
- Publishing this change requires a new immutable backend chest configuration. Existing players keep their chest stars and goal; ability rewards start with crossings under the new version, without retroactive grants.

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

## `configs/life_purchase.json`

Purpose:
- Defines the offline-capable coin price for buying exactly one life from the Main Menu's Out of
  Lives modal.
- Owned by `scripts/player_progress.gd`, which uses a built-in 500-coin fallback if the file is
  missing or invalid.

Shape:

```json
{
  "coin_price": 500
}
```

Rules:
- `coin_price` must be a positive integer.
- The grant is always exactly one life and never exceeds the five-life cap.
- A purchase keeps the existing next-restore deadline while lives remain below the cap; reaching
  the cap clears the deadline.
- The coin spend and resulting life state are persisted together as one signed `life_purchase`
  operation so the feature works offline and reconciles later.

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
- `starter_bundle` now uses that lifetime limit in the local catalog. The backend development
  catalog already defines the Starter Bundle with the same limit. Since backend-sourced purchases
  still use the mock provider, `StoreService` also hides a locally claimed Starter Bundle returned
  by the backend until real verified billing and backend claims replace the mock path.
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
  bundle (67% off its authored `compare_at_prices`); an always-available Basic Bundle with
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

The gameplay snapshot schema is version 9. It retains campaign completion maps, account-scoped
offer claims, reward-chest cycles, moderation state, the four-ability inventory, and the
authoritative public `avatar_frame_id`; it intentionally excludes `settings_disabled`,
`locale`, and `seen_gameplay_tips`, which belong to local `preferences`.

Runtime behavior:
- Fresh saves start at level 1 with five lives, 300 gold coins, three uses for each ability, `avatar_cat` selected as the profile avatar, a generated `player_` name with a five-character random suffix, and all settings buttons enabled.
- The main menu keeps campaign launch pressable at zero lives and opens the Out of Lives modal.
- Buying one life costs the configured `configs/life_purchase.json` price (500 by default), works
  offline, and resumes the level launch that opened the modal.
- The production profile menu can save the player name and any avatar id from `assets/ui/avatars/*.png`; invalid avatar ids are sanitized back to `avatar_cat`.
- Campaign level failure and pause-menu Leave spend one life. Completed levels do not spend lives.
- Missing lives restore at one life per real-time hour until the five-life cap is reached.
- Ability uses are spent and saved immediately when an ability successfully applies.
- Paid zero-use ability purchases spend configured coins immediately when the selected ability can start, without adding saved ability inventory.
- A settled rewarded Hammer, Shuffle, or Lantern authorization applies one immediate use without
  adding saved inventory or spending coins. Freezer is not in the backend rewarded enum and keeps
  only the configured coin route.
- A settled rewarded shelf-unlock authorization releases only the configured shelf it names, for the
  current attempt only. It adds no cleared triples, stars, or combo, and leaves every other shelf's
  `unlock_after_triples` countdown unchanged.
- Settings button disabled states are saved immediately when toggled and restored by the main-menu settings popup and in-level pause menu on later game starts.
- The approved locale is stored beside those local preferences, applied through `LocaleManager` on
  startup, and excluded from backend snapshots and journal operations.
- Failed or abandoned levels do not refund ability uses.
- Completing the current campaign level advances `current_level` by one and adds the run's earned stars to the reward chest.
- The same completion adds stars to `total_earned_stars` and `weekly_earned_stars`; neither is reduced by reward chest rollover.
- Schema-4 migration retains campaign, coins, lives/timer, existing ability inventory, processed
  mock transaction ids, profile, settings, chest progress, and lifetime/weekly stars, advances the
  snapshot to schema 9, and grants exactly three Freezer uses once. Later migrations never repeat
  the Freezer grant; schema 7 defaults the new frame to `frame_classic`, and schema 8 preserves a
  non-default local frame by appending one signed `profile_edit` during the schema-9 migration.
- Weekly stars reset when the saved Monday-UTC boundary no longer matches the current week.
- Reward chest stars roll over when a configured goal is reached, grant that goal's `coin_reward` and `ability_rewards`, then the next configured goal starts.
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
- `levels` maps all current Chapter 1 campaign levels 1-20 to exact opaque configuration, level,
  and rules versions.
- `source.files` pins the authored Godot files used by that publication.
- The generated development publication now includes the one-of-each chest ability rewards and
  level 10's `throwing_dispensers` definition. Regenerate the candidate and this manifest together
  after changing either source.
- `configs/chapters.json` is included in the pinned source-file set so chapter membership changes
  invalidate stale provenance before export.
- `configs/combo_scoring.json` and `scripts/combo_scoring_rules.gd` are pinned too, so a combo
  window or stars-per-triple change also invalidates stale provenance until the backend candidate
  is regenerated.
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
