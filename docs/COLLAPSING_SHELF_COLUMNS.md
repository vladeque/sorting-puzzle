# Collapsing shelf columns

Implemented in the game client and level tools on 2026-09-19. Existing levels are unchanged: a
level without `gameplay_mode` still loads as `classic`. The original task, including the product
decision gate and its confirmed answers, is kept in
[COLLAPSING_SHELF_COLUMNS_IMPLEMENTATION_TASK.md](COLLAPSING_SHELF_COLUMNS_IMPLEMENTATION_TASK.md).

## Play it

In a debug build, open `scenes/main_menu_testing.tscn` and press **Collapsing columns preview**, or
run `scenes/testing/collapsing_columns_preview.tscn` directly with **Run Current Scene (F6)**. The
production menu is unchanged.

The preview plays `configs/test_levels/collapsing_columns_preview.json`: three columns of ten
one-layer shelves, an authored window of four shelves, and 72 items across 18 item types. The
solver proves it in 50 moves. The preview uses the ordinary level runtime, so its window resolves
from the device exactly as a campaign level would, which also makes it the touch-device check for
this mode.

## The campaign level

Level 9 is the first campaign level in this mode, replacing a hand-authored classic board that had
no template. It is three columns of nine one-layer shelves (27 in total), an authored window of
four, 69 items across 14 types, medium difficulty, seed 9009, and a 300-second timer. The solver
proves it in 45 moves, and five item types can already be collected from the opening window.

Columns of nine are deliberate: the window never exceeds eight, so shelves still wait above it even
on the tallest supported screen. The window resolves to 6 rows at 540x960, 720x1280, 1080x1920, and
900x1600, and to 8 rows at 1080x2400.

Authored as `configs/level_templates/level_009.json` and materialized to
`configs/levels/level_009.json`:

```powershell
py scripts\tools\generate_level_shelves.py --gameplay-mode collapsing_columns --column-heights 9,9,9 `
    --visible-shelves-per-column 4 --item-type-count 14 --difficulty medium --seed 9009 --full-level `
    --level-number 9 --time-seconds 300 --output configs\level_templates\level_009.json --require-solvable --stats
py scripts\tools\level_item_progression.py configs\level_templates\level_009.json --output configs\levels\level_009.json
```

The replaced board was a nine-shelf, two-layer `grid_3x3` level with a 35-second timer; that short
timer is gone, because a 27-shelf collapsing board cannot be finished in 35 seconds.

## Rules

- Every shelf has exactly one layer of three standard slots, and shelves are stacked in tall
  columns. The first version always builds three columns.
- Every visible shelf is playable. Shelves above the window are hidden and cannot be a move source,
  a drop target, an automatic-match candidate, or a Hammer, Shuffle, or Highlight target.
- A shelf is destroyed once a committed move, a triple clear, or Hammer leaves it with no items.
  Lifting an item into a drag never counts as emptying its shelf.
- The shelves above a destroyed shelf drop one row; shelves below it never move. A shelf entering
  the window becomes playable after the drop settles, and an authored triple on it clears
  automatically, which can collapse the column again.
- The level completes after the last shelf is destroyed and its collapse has settled.
- All four abilities stay available. No remaining-shelf count is shown.
- Dispensers, locks, sticky items, moving rows, and multiple layers are rejected in this mode.

## How many shelves are visible

`column_layout.visible_shelves_per_column` is the **authored guaranteed minimum**: every viewport
reveals at least that many shelves per column, and it is the window the solver and generator prove
the level against. When the fitted board has spare height, the runtime reveals more, up to
`MAX_VISIBLE_SHELVES_PER_COLUMN` (8) and the tallest column. Extra rows only use spare height
at the scale the authored minimum already needs, so they never shrink the board or its touch
targets. The count is resolved once, when the level is built, and never changes during play.

This is safe for solvability because a larger window only adds legal moves. The only extra forced
event it can trigger is an automatic triple clear, which destroys a shelf and so only advances the
objective. Proving the minimum therefore proves every larger window.

With the preview fixture and with campaign level 9, the window resolves to 6 rows at 540x960,
720x1280, 1080x1920, and 900x1600, and to 8 rows at 1080x2400.

## Ownership

| Concern | Owner |
| --- | --- |
| Level contract, validation, solvability | `scripts/tools/validate_level_solvable.py` (`CollapsingColumnsRules`) |
| Generation | `scripts/tools/generate_level_shelves.py` (`--gameplay-mode collapsing_columns`) |
| Materialization contract check | `scripts/tools/level_item_progression.py` (`validate_board_contract()`) |
| Runtime contract check | `scripts/collapsing_column_rules.gd` |
| Columns, clip window, visible count, batched collapse | `scenes/collapsing_shelf_board.tscn`, `scripts/collapsing_shelf_board.gd` |
| One column's order and movement | `scenes/collapsing_shelf_column.tscn`, `scripts/collapsing_shelf_column.gd` |
| Empty-shelf break visuals | `scenes/effects/shelf_destruction_effect.tscn`, `scripts/shelf_destruction_effect.gd` |
| Construction, availability, resolution, abilities, completion | `scripts/level.gd` |
| Debug preview | `scenes/testing/collapsing_columns_preview.tscn`, `scripts/collapsing_columns_preview.gd` |

[CONFIGS.md](CONFIGS.md#collapsing-shelf-columns) documents the schema,
[SCENES.md](SCENES.md) the scene hierarchy, and [SCRIPTS.md](SCRIPTS.md) the script APIs.

## Timer, pause, and retry

- A collapse is gameplay resolution, not a pause: the countdown keeps running exactly as it does
  through match-clear animations, and Freezer holds the countdown without stopping the movement.
- The new column order is committed before any animation starts. A collapse keeps running under the
  pause menu, like every other gameplay animation, so pausing, backgrounding, failing, or tearing
  the scene down mid-collapse always leaves a consistent board and never a stuck input lock.
- Empty-shelf destruction recoils and separates the wooden frame into a short oak-chip/dust burst,
  overlapping the opening of the accelerated column fall. Survivors pass their destination by a
  few pixels and settle with a restrained rebound. Newly revealed shelves remain opaque and enter
  physically through the board's clip edge instead of fading in as ghosted content.
- Retry rebuilds the board from config. No live column state is saved.

## Verification

```powershell
py -m unittest discover -s tests/tools -p "test_*.py" -t tests/tools
& .\scripts\tools\run_isolated_godot_test.ps1 -Script res://tests/gameplay/test_collapsing_shelf_columns.gd
py scripts\tools\validate_level_solvable.py configs\test_levels\collapsing_columns_preview.json --show-solution
py scripts\tools\validate_level_solvable.py configs\levels\level_009.json
py scripts\tools\materialize_level_templates.py --check
```

`tests/tools/test_validate_level_solvable.py` also proves every committed campaign level in this
mode is valid and solvable, so level 9 cannot drift into an unfinishable state unnoticed.

`tests/gameplay/test_collapsing_shelf_columns.gd` covers the components in isolation and the full
level: build order, hidden-shelf reachability, move/triple/Hammer destruction and reveal chains,
drags, Shuffle, Highlight, Freezer, input and ability blocking, completion timing, retry, pause,
backgrounding, failure and teardown mid-collapse, invalid configs, responsive windows, the preview
scene, and a classic-level regression.

Rendered captures:

```powershell
& .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name collapsing_columns_initial -Position '0,0' -Settle 30 `
    -Setup scripts/tools/captures/collapsing_columns_initial_setup.gd
# A campaign level instead of the fixture:
$env:SORTING_PUZZLE_CAPTURE_COLLAPSE_LEVEL = '9'
& .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name collapsing_columns_progress -Position '0,0' -Settle 90 `
    -Setup scripts/tools/captures/collapsing_columns_progress_setup.gd
& .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name collapsing_columns_motion -Position '0,0' -Settle 120 `
    -Setup scripts/tools/captures/collapsing_columns_motion_setup.gd
& .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name collapsing_columns_destruction -Position '0,0' -Settle 120 `
    -Setup scripts/tools/captures/collapsing_columns_destruction_setup.gd
```

The capture setups rebuild the board on every resize, because the level resolves its window only
when a board is built. The progress and motion setups replay the fixture's recorded solution
(`SOLUTION_PREFIX` in `scripts/tools/captures/collapsing_columns_capture_support.gd`) with the
window pinned to the authored four shelves; regenerate those moves if the fixture changes. The
motion setup freezes a collapse part-way through its drop with `Tween.custom_step()`
(`SORTING_PUZZLE_CAPTURE_COLLAPSE_PROGRESS`, default `0.5`).
The destruction setup freezes the preceding wood-snap beat the same way
(`SORTING_PUZZLE_CAPTURE_DESTRUCTION_PROGRESS`, default `0.58`).

## Not yet done

- Play-balancing level 9 against the rest of chapter 1: its 300-second timer and 45-move solution
  are a first estimate, not a tuned difficulty curve.
- Hands-on touch-device testing: drag accuracy on the scaled board, rapid input just before a
  collapse, and pause/background restoration. The preview scene is set up for this.
- Publishing and activating campaign content. Backend publication compatibility is implemented in
  sibling commit `9b8921d`: normalization preserves `gameplay_mode` and `column_layout`, emits a
  mode-aware immutable rules identity, and rejects client ranges not registered for the mode. The
  production candidate/provenance manifest cannot be regenerated until a campaign slot and the
  first supporting Android/iOS build numbers are chosen; activation remains an approved operational
  action. See section 14 of the task document.
