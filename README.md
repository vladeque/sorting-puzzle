# sorting-puzzle

## Project documentation

Start with `docs/PROJECT_MAP.md` to identify which scene, script, config, or tool owns a feature. Supporting inventories live in `docs/SCENES.md`, `docs/SCRIPTS.md`, and `docs/CONFIGS.md`. Production server planning and implementation requirements live in `docs/BACKEND_REQUIREMENTS.md`.

## One-click Android local development

Double-click `run_android_local_development.cmd`, or run:

```powershell
.\scripts\tools\run_android_local_development.ps1
```

The launcher starts or reuses the `sorting-puzzle-api36` emulator, persistent local PostgreSQL
database and backend API, exports the debug APK, installs it, and launches the game. The emulator,
database container, and API remain running after the launcher exits. See
`docs/LOCAL_BACKEND_INTEGRATION.md` for prerequisites and troubleshooting.

After changing only the game, double-click `redeploy_android_game.cmd`, or run:

```powershell
.\scripts\tools\redeploy_android_game.ps1
```

This faster path requires the emulator and backend to already be running. It exports and installs
the updated APK, preserves app data, and restarts the game without repeating backend setup.

## Level shelf generation

Use `scripts/tools/generate_level_shelves.py` with Python 3.10+ to generate an abstract
level template. The generator works only with logical `item_NN` identities and does not choose
item art.

```powershell
py scripts\tools\generate_level_shelves.py --shelf-count 9 --layer-count 2 --item-type-count 7 --difficulty medium --seed 123 --full-level --level-number 2 --output configs\level_templates\level_002.json --require-solvable --stats
```

By default the tool prints only the abstract JSON array that belongs in a template's `shelves`
field. `--item-type-count` controls how many distinct logical types the board uses.

Add `--validate` to run the solvability validator once after generation. Add `--require-solvable --max-generation-attempts 25` to retry generation until a solvable layout is found.

Available layout presets are `grid_2x3`, `grid_3x3`, `grid_3x4`, `grid_3x5`, and `grid_4x3`.

Materialize every template through the campaign item progression after generation:

```powershell
py scripts\tools\materialize_level_templates.py
py scripts\tools\materialize_level_templates.py --check
```

The materializer writes concrete runtime files under `configs/levels/`. Commit templates and their
materialized runtime files together.

## Level solvability validation

Use `scripts/tools/validate_level_solvable.py` to validate level JSON and run a bounded solvability search.

```powershell
py scripts\tools\validate_level_solvable.py configs\levels\level_001.json --max-states 20000 --max-depth 200
```

The validator returns JSON with shape errors, item counts, solvability, searched state count, and the result reason. Add `--show-solution` to include a canonicalized move path for debugging.
