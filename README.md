# sorting-puzzle

## Level shelf generation

Use `scripts/tools/generate_level_shelves.py` with Python 3.10+ to generate the `shelves` array for a level config.

```powershell
py scripts\tools\generate_level_shelves.py --shelf-count 9 --layer-count 2 --difficulty medium --seed 123 --stats
```

By default the tool prints only the JSON array that belongs in a level file's `shelves` field. Add `--full-level --output configs\levels\level_002.json` to write a complete level config.
