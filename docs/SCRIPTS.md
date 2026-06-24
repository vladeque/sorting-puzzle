# Scripts

This file documents what each script owns. Keep script docs focused on responsibilities, exports, dependencies, and boundaries.

## `scripts/main_menu.gd`

Attached to:
- `scenes/main_menu.tscn` root `MainMenu`.

Purpose:
- Builds the level selection grid.
- Launches the selected level.

Key constants:
- `LEVEL_SCENE`: preloads `res://level.tscn`.
- `MIN_LEVEL`: first selectable level number.
- `MAX_LEVEL`: last selectable level number.

Important nodes:
- `%LevelGrid`: `GridContainer` filled with generated `Button` nodes.

Key methods:
- `_ready()`: populates the selector.
- `_populate_level_selector()`: clears old buttons and creates one button per level.
- `_launch_level(level_number)`: instantiates the level, sets `selected_level`, swaps current scene, and queues the menu for deletion.

Depends on:
- `level.tscn`
- `scripts/level.gd` export `selected_level`

Do not use for:
- Level availability rules that need persisted player progress until save data exists.
- Puzzle runtime logic.

## `scripts/level.gd`

Attached to:
- `level.tscn` root `Level`.

Purpose:
- Owns active level state, runtime shelf creation, item spawning, input handling, matching, abilities, timer, failure, and completion.

Important exports:
- `slot_snap_distance`: maximum snap distance for drag or tap placement.
- `item_pick_size`: rectangle used to detect clicked or touched visible items.
- `drag_start_distance`: pointer movement required to convert a press into a drag.
- `back_layer_offset`: visual offset for hidden/upcoming shelf layers.
- `back_layer_item_scale`: scale multiplier for back-layer item previews.
- `back_layer_item_modulate`: color used for visible back-layer previews.
- `match_gather_duration_seconds`: duration for side items to pull into the center item when a triple clears.
- `match_shrink_duration_seconds`: duration for the center item shrink-out after a triple gathers.
- `level_duration_seconds`: fallback duration if config does not define `time_seconds`.
- `completion_return_delay_seconds`: delay before returning to the main menu after completion.
- `item_place_volume_db`: volume for the item placement sound effect.
- `triple_clear_volume_db`: volume for the matched triple clear sound effect.
- `selected_level`: level number loaded from `configs/levels/level_%03d.json`.

Important constants:
- `SLOT_COUNT`: currently three items per shelf front layer.
- `SLOT_ITEM_POSITION`: item local position that matches `scenes/shelf.tscn` item snap markers.
- `SHELF_CELL_SIZE`: reusable shelf scene bounds.
- `SHELF_SHARED_EDGE_THICKNESS`: shelf boundary thickness that neighboring cells overlap.
- `SHELF_GRID_STEP`: packed layout spacing after overlapping shared shelf edges.
- `SHELF_SCENE`: `res://scenes/shelf.tscn`.
- `ITEM_SCENE`: `res://scenes/item.tscn`.
- `ITEM_SPRITES_CONFIG`: `res://configs/item_sprites.json`.
- `LEVEL_CONFIG_TEMPLATE`: `res://configs/levels/level_%03d.json`.
- `DEFAULT_LEVEL_CONFIG`: fallback level config.
- `DEFAULT_LAYOUT_PRESET`: fallback layout preset.
- `MAIN_MENU_SCENE`: scene returned to after completion.
- `ITEM_PLACE_SOUND`: short sound played when the player drops or moves an item into a shelf slot.
- `TRIPLE_CLEAR_SOUND`: sound played when a matched triple gathers and disappears.

Key responsibilities:
- Load JSON configs with `_load_json_file()`.
- Instantiate reusable shelf cells with `_add_shelf()` and add generated back layers with `_add_back_layer()`.
- Pack shelf cells with shared boundaries based on `SHELF_GRID_STEP`.
- Spawn configured items with `_add_configured_item()`.
- Handle mouse and touch input through `_input()` and the press/motion/release helpers.
- Move items with `_move_item_to_slot()` and `_place_item_in_slot()`.
- Clear triples with `_clear_matching_shelves()` and `_play_match_clear_animation()`.
- Play placement and triple-clear sound effects with runtime `AudioStreamPlayer` nodes.
- Track clearing items so only disappearing items ignore input and abilities during the animation.
- Queue shelf resolution requests made while another match animation is still finishing.
- Promote back layers with `_promote_back_layer()` and `_advance_back_layers()`.
- Check win/loss state with `_check_level_completed()`, `_fail_level()`, and `_complete_level()`.
- Manage hammer, shuffle, and highlight abilities.

Depends on:
- `level.tscn` node names and paths.
- `scenes/shelf.tscn` slot names and item snap marker names.
- `scenes/item.tscn` and `ShelfItem`.
- `assets/audio/item_place.wav` and `assets/audio/triple_clear.wav`.
- `configs/item_sprites.json` item IDs and texture paths.
- `configs/levels/level_*.json` shelf schema.

Do not use for:
- Offline level generation or solvability search. Keep that in `scripts/tools/`.
- Persistent progression or save data once that system exists.

## `scripts/item.gd`

Class:
- `ShelfItem`

Attached to:
- `scenes/item.tscn` root `Item`.

Purpose:
- Stores the item ID and applies sprite visuals for one sortable item.

Exports:
- `item_id`: item identity used by matching and config loading.
- `texture`: assigned by `scripts/level.gd`; setter updates `Sprite2D.texture`.
- `visual_scale`: scalar applied to `Sprite2D.scale`.

Key methods:
- `_ready()`: applies current texture and scale.
- `_apply_texture()`: updates `Sprite2D.texture`.
- `_apply_visual_scale()`: updates `Sprite2D.scale`.

Depends on:
- Child node `Sprite2D`.

Do not use for:
- Input ownership, matching rules, abilities, or shelf promotion.

## `scripts/tools/generate_level_shelves.py`

Purpose:
- Generates level `shelves` arrays or complete level JSON from CLI arguments.

Key inputs:
- Shelf count, layer count, filled layer count, difficulty, seed, layout preset, item type filters, and optional solvability requirements.

Depends on:
- `configs/item_sprites.json` for known item IDs by default.
- `scripts/tools/validate_level_solvable.py` for validation and optional solvability checks.

Use when:
- Creating or regenerating level shelf layouts.

Do not use for:
- Runtime game logic.

## `scripts/tools/validate_level_solvable.py`

Purpose:
- Validates level JSON shape and runs a bounded search to determine whether a level can be completed.

Checks:
- Level has shelves.
- Shelves have non-empty `layers` arrays.
- Each layer has exactly three slots.
- Slot values are item ID strings or `null`.
- Item IDs exist in `configs/item_sprites.json` unless skipped.
- Item counts are multiples of three.

Use when:
- Reviewing generated levels or hand-authored level JSON.

Do not use for:
- Runtime state transitions unless the runtime rules are intentionally mirrored and kept in sync.
