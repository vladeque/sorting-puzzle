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
- `layout_preset`: shelf placement preset used by `scripts/level.gd`.
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
- `motion.type` currently supports `horizontal_wrap`.
- `motion.speed` is pixels per second. Use `0` for a row that is structured as a moving row but currently stopped.
- `motion.direction` supports `right` and `left`.
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
- `scripts/level.gd` uses `layout_preset` to choose the grid columns or fixed staggered shelf pattern, then packs generated shelf cells with overlapping shared boundaries.
- If `row_layouts` is present, `scripts/level.gd` creates shelves row by row instead. Moving rows are clipped to their visible window and wrap shelves horizontally from right to left or left to right.
- `scripts/level.gd` uses `time_seconds` as the active timer.
- Locked shelves show a runtime lock overlay with the remaining triple count on the lock and cannot be used as move sources, move targets, match clears, promotions, or ability targets until unlocked.
- Off-window moving shelves cannot be selected or targeted by drag/drop, but abilities can still target their front-layer items.
- Hammer clears count as cleared triples for shelf unlocking. If no unlocked visible/front item type has three available copies, hammer can combine visible/front items with first-back-layer copies of the same type to reach a triple.

Validation:

```powershell
py scripts\tools\validate_level_solvable.py configs\levels\level_001.json --max-states 20000 --max-depth 200
```

The validator checks `row_layouts` totals, moving-row motion fields, supported visual variants, and rejects locked shelves inside moving rows.
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

## Documentation Update Checklist

When changing scene, script, or config ownership:
- Update `docs/PROJECT_MAP.md` if navigation or system ownership changes.
- Update `docs/SCENES.md` if scene nodes, attachments, or scene responsibilities change.
- Update `docs/SCRIPTS.md` if script exports, dependencies, or boundaries change.
- Update this file if config shape, supported values, or validation rules change.
