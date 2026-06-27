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
- `shelves`: ordered shelf list.

Supported layout presets:
- `grid_2x3`
- `grid_3x3`
- `grid_3x4`
- `grid_3x5`
- `grid_4x3`
- `staggered_5_4_5`: 14 shelves arranged as five left, four centered, five right.
- `staggered_4_5_4`: 13 shelves arranged as four left, five centered, four right.

Shelf shape:

```json
{
  "layers": [
    ["milk_carton", "chips_can", null],
    ["milk_carton", "chips_can", "toy_robot"]
  ]
}
```

Layer rules:
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
- `scripts/level.gd` uses `time_seconds` as the active timer.

Validation:

```powershell
py scripts\tools\validate_level_solvable.py configs\levels\level_001.json --max-states 20000 --max-depth 200
```

Generation:

```powershell
py scripts\tools\generate_level_shelves.py --shelf-count 9 --layer-count 2 --difficulty medium --seed 123 --require-solvable --stats
```

## Documentation Update Checklist

When changing scene, script, or config ownership:
- Update `docs/PROJECT_MAP.md` if navigation or system ownership changes.
- Update `docs/SCENES.md` if scene nodes, attachments, or scene responsibilities change.
- Update `docs/SCRIPTS.md` if script exports, dependencies, or boundaries change.
- Update this file if config shape, supported values, or validation rules change.
