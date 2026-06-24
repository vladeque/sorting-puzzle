# Project Map

Use this file as the first stop when you need to identify where a feature lives. Keep entries short and update this map in the same commit as meaningful scene, script, or config changes.

## Entry Points

Main scene:
- `scenes/main_menu.tscn`
- Configured in `project.godot` as `run/main_scene`.
- Owns the level selection screen and launches playable levels.

Playable level scene:
- `level.tscn`
- Instantiated by `scripts/main_menu.gd`.
- Owns shelf layout, timer, drag and tap movement, triple matching, abilities, failure, and completion flow.

Reusable item scene:
- `scenes/item.tscn`
- Instantiated by `scripts/level.gd` for every shelf item.
- Displays the item sprite and exposes item identity through `ShelfItem`.

## Core Systems

### Level Selection

Files:
- `scenes/main_menu.tscn`
- `scripts/main_menu.gd`

Responsibility:
- Builds level buttons for levels 1 through 10.
- Instantiates `level.tscn`, assigns `selected_level`, swaps it into `SceneTree.current_scene`, and removes the menu.

Change here when:
- Adding level selection UI, lock states, stars, level paging, or menu-to-game navigation behavior.

### Level Runtime

Files:
- `level.tscn`
- `scripts/level.gd`
- `configs/levels/level_*.json`
- `configs/item_sprites.json`

Responsibility:
- Loads level JSON and item sprite config.
- Generates shelf nodes and slot nodes at runtime.
- Renders generated shelves as packed cells whose wall, floor, and ceiling bounds define tight shared borders in grid layouts.
- Spawns `ShelfItem` instances from config layers.
- Handles mouse and touch interaction.
- Resolves matches of three identical visible items on the same shelf, including the gather-and-shrink clear animation.
- Keeps non-clearing items interactive while match animations run, with pending shelf resolves queued behind the active animation.
- Promotes back layers when the visible layer clears.
- Tracks the countdown timer and win/loss overlays.

Change here when:
- Editing puzzle rules, input behavior, runtime shelf construction, level timing, completion conditions, or ability behavior.

### Item Runtime

Files:
- `scenes/item.tscn`
- `scripts/item.gd`
- `assets/items/*.png`

Responsibility:
- Represents one sortable item as an `Area2D`.
- Stores `item_id`.
- Applies texture and visual scale to its `Sprite2D`.

Change here when:
- Adjusting item hitboxes, sprite scale behavior, item identity storage, or common item visuals.

### Ability Bar

Files:
- `level.tscn`
- `scripts/level.gd`
- `assets/abilities/*.png`

Responsibility:
- Provides hammer, shuffle, and highlight buttons.
- Tracks three uses per ability per level.
- Disables abilities after failure, completion, or when uses run out.

Change here when:
- Adding, removing, rebalancing, or restyling player abilities.

### Level Data And Tooling

Files:
- `configs/levels/level_*.json`
- `scripts/tools/generate_level_shelves.py`
- `scripts/tools/validate_level_solvable.py`

Responsibility:
- Stores level number, time limit, layout preset, and shelf layers.
- Generates shelf configs from difficulty, item, shelf, and layer settings.
- Validates shelf shape, known item IDs, item counts, and bounded solvability.

Change here when:
- Creating levels, adjusting level schema, adding layout presets, or improving validation/generation rules.

## Common Change Guide

Add a new item type:
- Add the item image under `assets/items/`.
- Add an entry to `configs/item_sprites.json`.
- Use the item ID in `configs/levels/level_*.json` or pass it to the generator.

Add a new level:
- Create `configs/levels/level_011.json` or the next numbered file.
- Update `MAX_LEVEL` in `scripts/main_menu.gd`.
- Validate the level with `scripts/tools/validate_level_solvable.py`.

Change shelf layout spacing:
- Update `SHELF_CELL_*` and `_get_layout_positions()` in `scripts/level.gd`.
- Keep `scripts/tools/generate_level_shelves.py` layout presets in sync if preset names or supported shapes change.

Change matching rules:
- Update `_clear_matching_shelves()`, `_resolve_shelves()`, and related validation logic if the data rules also change.
- Update `scripts/tools/validate_level_solvable.py` so generated or validated levels match runtime behavior.

Change drag or tap movement:
- Update `_input()`, `_handle_press_at()`, `_handle_motion_at()`, `_handle_release_at()`, `_move_item_to_slot()`, and slot lookup helpers in `scripts/level.gd`.

Change level win or loss flow:
- Update `_process()`, `_fail_level()`, `_complete_level()`, `_check_level_completed()`, and the panels in `level.tscn`.

## Related Docs

- `docs/SCENES.md`: scene and node ownership inventory.
- `docs/SCRIPTS.md`: script responsibilities, exports, and dependencies.
- `docs/CONFIGS.md`: config file schema and data contracts.
