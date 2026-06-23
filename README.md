# sorting-puzzle

## Level shelf generation

Use `scripts/tools/generate_level_shelves.py` with Python 3.10+ to generate the `shelves` array for a level config.

```powershell
py scripts\tools\generate_level_shelves.py --shelf-count 9 --layer-count 2 --difficulty medium --seed 123 --stats
```

By default the tool prints only the JSON array that belongs in a level file's `shelves` field. Add `--full-level --output configs\levels\level_002.json` to write a complete level config.

Add `--validate` to run the solvability validator once after generation. Add `--require-solvable --max-generation-attempts 25` to retry generation until a solvable layout is found.

Available layout presets are `grid_2x3`, `grid_3x3`, `grid_3x4`, `grid_3x5`, and `grid_4x3`.

```powershell
py scripts\tools\generate_level_shelves.py --shelf-count 9 --layer-count 2 --difficulty medium --seed 123 --require-solvable --stats
```

## Level solvability validation

Use `scripts/tools/validate_level_solvable.py` to validate level JSON and run a bounded solvability search.

```powershell
py scripts\tools\validate_level_solvable.py configs\levels\level_001.json --max-states 20000 --max-depth 200
```

The validator returns JSON with shape errors, item counts, solvability, searched state count, and the result reason. Add `--show-solution` to include a canonicalized move path for debugging.
