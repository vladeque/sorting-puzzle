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
- `slot_snap_distance`: maximum snap distance for drag or tap placement, sized for the wider shelf spacing.
- `item_pick_size`: rectangle used to detect clicked or touched visible items at the default item scale.
- `drag_start_distance`: pointer movement required to convert a press into a drag.
- `back_layer_offset`: visual offset for hidden/upcoming shelf layers.
- `back_layer_item_scale`: scale multiplier for back-layer item previews.
- `back_layer_item_modulate`: color used for visible back-layer previews.
- `layer_promotion_duration_seconds`: duration for back-layer items to slide forward into active front slots.
- `item_move_duration_seconds`: duration for moved items to slide into destination slots after tap or drag placement, including invalid drag returns.
- `highlight_outline_color`: border color used by the highlight ability.
- `selected_highlight_outline_color`: border color used when a highlighted item is also selected.
- `highlight_outline_width`: screen-pixel expansion used by the item outline sprite.
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
- `SHELF_CELL_SIZE`: reusable shelf scene bounds; three cells in a row are packed to fill most of the 720 px gameplay viewport, with compact vertical row spacing.
- `SHELF_SHARED_EDGE_THICKNESS`: shelf boundary thickness that neighboring cells overlap.
- `SHELF_GRID_STEP`: packed layout spacing after overlapping shared shelf edges.
- `SHELF_SCENE`: `res://scenes/shelf.tscn`.
- `MOVING_SHELF_ROW_SCENE`: `res://scenes/moving_shelf_row.tscn`.
- `ITEM_SCENE`: `res://scenes/item.tscn`.
- `ITEM_SPRITES_CONFIG`: `res://configs/item_sprites.json`.
- `LEVEL_CONFIG_TEMPLATE`: `res://configs/levels/level_%03d.json`.
- `DEFAULT_LEVEL_CONFIG`: fallback level config.
- `LAYOUT_SCENE_TEMPLATE`: `res://scenes/layouts/layout_%s.tscn` path pattern used by `layout_preset`.
- `DEFAULT_LAYOUT_PRESET`: fallback layout preset.
- `MAIN_MENU_SCENE`: scene returned to after completion.
- `ITEM_PLACE_SOUND`: short sound played when the player drops or moves an item into a shelf slot.
- `TRIPLE_CLEAR_SOUND`: sound played when a matched triple gathers and disappears.

Key responsibilities:
- Load JSON configs with `_load_json_file()`.
- Instantiate reusable shelf cells with `_add_shelf()` and add generated back layers with `_add_back_layer()`.
- Load `layout_preset` scene templates from `scenes/layouts/` and place runtime shelves at their authored `ShelfXX` markers.
- Build optional `row_layouts` rows with `_add_row_layout_shelves()`, including horizontally wrapping moving rows and static rows mixed in one level.
- Build moving rows declared by layout template `MovingRowXX` nodes with `scripts/shelf_layout_row.gd`.
- Keep moving-row shelves out of drag/drop targeting while they are outside the row's visible window, while abilities still use unlocked shelf items.
- Spawn configured items with `_add_configured_item()`.
- Handle mouse and touch input through `_input()` and the press/motion/release helpers.
- Move items with `_move_item_to_slot()`, `_resolve_move_target_slot()`, `_play_item_move_animation()`, and `_place_item_in_slot()`.
- Redirect moves aimed at an occupied destination slot on another shelf to the nearest free front slot on that destination shelf; same-shelf occupied targets leave the item in its original slot.
- Clear triples with `_clear_matching_shelves()` and `_play_match_clear_animation()`.
- Track cleared triples and locked shelf accessibility with `_record_triples_cleared()`, `_update_locked_shelves()`, and shelf metadata from `unlock_after_triples`.
- Toggle each shelf scene's lock overlay with the remaining triple count, fit that count to the lock art's center panel, and keep locked shelves out of move, match, promotion, and ability targeting.
- Play placement and triple-clear sound effects with runtime `AudioStreamPlayer` nodes.
- Track clearing items so only disappearing items ignore input and abilities during the animation.
- Track transitioning items so newly promoted back-layer items ignore input and abilities until their forward slide finishes.
- Queue shelf resolution requests made while another match animation is still finishing.
- Promote back layers with `_promote_back_layer()`, `_play_layer_promotion_animation()`, and `_advance_back_layers()`.
- Check win/loss state with `_check_level_completed()`, `_fail_level()`, and `_complete_level()`.
- Format the active timer as zero-padded `MM:SS` text with `_update_timer_label()`.
- Pause and resume active gameplay through the top-right menu button, the instanced `UI/PauseMenuOverlay`, `Leave`, and `Continue`.
- Disable item placement and triple-clear sound effects while the pause menu sound-effects toggle is crossed out.
- Manage hammer, shuffle, and highlight abilities. Hammer targets visible/front triples first, then can supplement visible/front matches with first-back-layer copies of the same item type when no visible item type has three available copies.
- Count hammer destroys as cleared triples for shelf unlocking.
- Let highlight uses start their timed window even when no immediate triple can currently be highlighted.
- Apply highlight ability visuals through `ShelfItem.set_outline()` so only item silhouettes receive a border, and update the highlight button countdown label while that window is active.

Depends on:
- `level.tscn` node names and paths.
- `scenes/shelf.tscn` slot names and item snap marker names.
- `scenes/shelf.tscn` `LockedOverlay/RemainingLabel` for locked shelf progress display on the lock image.
- `scenes/moving_shelf_row.tscn` for optional row-layout movement and clipping.
- `scenes/layouts/layout_*.tscn` for named layout preset placement.
- `scenes/pause_menu.tscn` button node names used under `UI/PauseMenuOverlay`.
- `scenes/item.tscn` and `ShelfItem`.
- `assets/audio/item_place.wav` and `assets/audio/triple_clear.wav`.
- `configs/item_sprites.json` item IDs and texture paths.
- `configs/levels/level_*.json` shelf schema.

Do not use for:
- Offline level generation or solvability search. Keep that in `scripts/tools/`.
- Persistent progression or save data once that system exists.

## `scripts/shelf_layout_row.gd`

Class:
- `ShelfLayoutRow`

Attached to:
- Moving-row marker nodes in `scenes/layouts/layout_*.tscn`.

Purpose:
- Stores editor-authored moving-row metadata for layout templates.
- Converts row properties into the same row config shape used by runtime `row_layouts`.

Exports:
- `shelf_count`: number of level shelves consumed by this row.
- `visible_count`: number of shelf positions visible inside the clipped row window.
- `motion_type`: currently `horizontal_wrap`.
- `speed_pixels_per_second`: row motion speed.
- `direction`: `right` or `left`.
- `visual_variant`: `full` or `floor_only`.

Key methods:
- `to_row_config()`: returns a runtime row dictionary consumed by `scripts/level.gd`.

Do not use for:
- Moving the shelves at runtime. That stays in `scripts/moving_shelf_row.gd`.
- Shelf contents, locking, matching, or item spawning.

## `scripts/moving_shelf_row.gd`

Class:
- `MovingShelfRow`

Attached to:
- `scenes/moving_shelf_row.tscn` root `MovingShelfRow`.

Purpose:
- Clips a horizontal shelf row to a visible window.
- Moves child shelves horizontally and wraps them when they pass the row bounds.
- Reports whether a shelf center is inside the visible window for drag/drop targeting.

Exports:
- `visible_shelf_count`: number of shelf positions in the clipped row window.
- `shelf_cell_size`: shelf cell bounds supplied by `scripts/level.gd`.
- `shelf_step_x`: packed horizontal shelf spacing supplied by `scripts/level.gd`.
- `speed_pixels_per_second`: row motion speed.
- `direction`: `1` for rightward motion, `-1` for leftward motion.

Key methods:
- `configure()`: applies runtime row settings from a level config.
- `add_shelf()`: registers a child shelf for wrapping layout.
- `set_movement_paused()`: pauses row motion during pause, failure, or completion states.
- `is_shelf_inside_visible_window()`: used by `scripts/level.gd` drag/drop targeting.

Do not use for:
- Shelf item rules, matching, ability behavior, locking, or level completion. Those stay in `scripts/level.gd`.

## `scripts/pause_menu.gd`

Attached to:
- `scenes/pause_menu.tscn` root `PauseMenuOverlay`.

Purpose:
- Owns local pause menu settings-button visual state.
- Toggles a crossed-out overlay on the music, sound effects, and vibration buttons when clicked.
- Emits `setting_toggled(setting_id, is_disabled)` so owning runtime scripts can apply supported settings.

Important nodes:
- `PauseMenuPanel/MarginContainer/VBoxContainer/IconRow/MusicButton`
- `PauseMenuPanel/MarginContainer/VBoxContainer/IconRow/SoundEffectsButton`
- `PauseMenuPanel/MarginContainer/VBoxContainer/IconRow/VibrationButton`

Do not use for:
- Applying actual music or vibration settings until those runtime systems exist.
- Level pause, continue, or leave flow. Those stay in `scripts/level.gd`.

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
- `outline_color`: color passed to the item outline shader.
- `outline_width`: screen-pixel expansion used when the outline sprite is enabled.
- `outline_alpha_threshold`: alpha cutoff used to detect the item silhouette.

Key methods:
- `_ready()`: applies current texture and scale.
- `_apply_texture()`: updates `Sprite2D.texture`.
- `_apply_visual_scale()`: updates `Sprite2D.scale`.
- `set_outline(enabled, color, width)`: enables or disables the sprite border highlight.
- `_apply_outline()`: sends outline properties to the `OutlineSprite` shader material and keeps the outline node visible only while enabled.

Depends on:
- Child node `Sprite2D`.
- Child node `OutlineSprite`.
- `scenes/item.tscn` outline `ShaderMaterial`.

Do not use for:
- Input ownership, matching rules, abilities, or shelf promotion.

## `scripts/tools/generate_level_shelves.py`

Purpose:
- Generates level `shelves` arrays or complete level JSON from CLI arguments.

Key inputs:
- Shelf count, layer count, filled layer count, difficulty, seed, layout preset, item type filters, and optional solvability requirements.
- Layout preset values mirror the runtime layout template names in `scenes/layouts/`, including fixed-count staggered presets for 14-shelf `staggered_5_4_5`, 13-shelf `staggered_4_5_4`, and 14-shelf `grid_3x3_moving_5_bottom` layouts.

Generation constraints:
- Difficulty presets cap how many copies of the same item can appear on one filled layer.
- The generator derives the default total item cap per type from the per-layer cap and the filled layer count, then rounds that cap down to a valid multiple of three.
- `--max-items-per-type` can lower the derived total cap for special levels that need less overall repetition, such as limiting a four-layer level to six copies of each item type.
- `--min-front-visible-triples` defaults to `1` and guarantees at least that many item types have three visible front-layer copies somewhere across shelves, which gives generated levels an intuitive starting move without requiring a completed shelf match. Use `0` to disable the guarantee.
- `--locked-shelves` can add per-shelf `unlock_after_triples` requirements using 1-based shelf numbers such as `7:3,8:5`.
- When the item catalog cannot satisfy the target filled-slot count within the effective per-type cap, the generator adds extra empty slots instead of exceeding the cap.
- Generated layouts reshuffle shelf slots to reduce same-item concentration on a single filled layer, using an adaptive per-layer limit so constrained levels remain possible.
- Hard and expert difficulties still avoid shelves that start with a complete front-layer match.

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
- Optional `unlock_after_triples` values are non-negative integers.
- Each layer has exactly three slots.
- Slot values are item ID strings or `null`.
- Item IDs exist in `configs/item_sprites.json` unless skipped.
- Item counts are multiples of three.
- Optional `row_layouts` totals match the number of shelves.
- Moving row fields use supported motion, direction, and visual variant values.
- Locked shelves are not placed inside moving rows.
- Solvability search mirrors locked shelf timing by counting auto-cleared triples and only allowing moves on unlocked shelves.
- Moving row timing is treated as eventually accessible; the search does not model shelf positions over time.

Use when:
- Reviewing generated levels or hand-authored level JSON.

Do not use for:
- Runtime state transitions unless the runtime rules are intentionally mirrored and kept in sync.
