# Project Map

Use this file as the first stop when you need to identify where a feature lives. Keep entries short and update this map in the same commit as meaningful scene, script, or config changes.

## Entry Points

Main scene:
- `scenes/main_menu.tscn`
- Configured in `project.godot` as `run/main_scene`.
- `project.godot` keeps the 720x1280 design viewport and uses `canvas_items` stretch with `keep_width` so portrait devices share a stable logical width while gaining or losing vertical play space.
- Owns the campaign play entry point, shows developer level selection in dev/test mode, and launches playable levels.

Playable level scene:
- `level.tscn`
- Instantiated by `scripts/main_menu.gd` and by `scripts/level.gd` when normal campaign play auto-advances to the next level.
- Owns shelf layout, timer, drag and tap movement, triple matching, abilities, pause-menu wiring, failure, and completion flow.

Player progression:
- `scripts/player_progress.gd`
- `scripts/save_providers/*.gd`
- Registered in `project.godot` as the `PlayerProgress` autoload.
- Saves campaign level progress and campaign ability inventory through the configured save provider.

Reusable item scene:
- `scenes/item.tscn`
- Instantiated by `scripts/level.gd` for every shelf item.
- Displays the item sprite and exposes item identity through `ShelfItem`.

## Core Systems

### Level Selection

Files:
- `scenes/main_menu.tscn`
- `scripts/main_menu.gd`
- `scripts/player_progress.gd`

Responsibility:
- Shows a normal campaign `Play` button for `PlayerProgress.current_level`.
- Hides free level selection from normal campaign play.
- Builds level buttons for levels 1 through 10 only when dev/test level selection is enabled.
- Instantiates `level.tscn`, assigns `selected_level` and `launched_from_dev_mode`, swaps it into `SceneTree.current_scene`, and removes the menu.

Change here when:
- Adding campaign entry UI, dev/test level selection UI, lock states, stars, level paging, or menu-to-game navigation behavior.

### Player Progression

Files:
- `scripts/player_progress.gd`
- `scripts/save_providers/save_provider.gd`
- `scripts/save_providers/local_save_provider.gd`
- `scripts/save_providers/cloud_save_provider.gd`
- `project.godot`
- `docs/CLOUD_SAVE.md`

Responsibility:
- Loads and saves campaign progress through the configured provider.
- Uses `LocalSaveProvider` for editor/development saves under `user://player_progress.json`.
- Uses `CloudSaveProvider` for release cloud saves through native Google Play Games or Apple Game Center bridge singletons.
- Tracks the current campaign level, highest completed level, and campaign ability uses.
- Spends ability uses immediately so failure or leaving a level does not refund them.
- Advances `current_level` only when the active campaign level is completed.

Change here when:
- Adding ability refills, rewards, purchases, reset flows, save migrations, native cloud save hooks, or new persisted player state.

### Level Runtime

Files:
- `level.tscn`
- `scenes/shelf.tscn`
- `scenes/moving_shelf_row.tscn`
- `scenes/layouts/layout_*.tscn`
- `scenes/pause_menu.tscn`
- `assets/ui/*.png`
- `scripts/level.gd`
- `scripts/moving_shelf_row.gd`
- `scripts/shelf_layout_row.gd`
- `assets/audio/*.wav`
- `configs/levels/level_*.json`
- `configs/item_sprites.json`

Responsibility:
- Loads level JSON and item sprite config.
- Applies responsive layout for the top HUD, ability bar over the floor/baseboard transition strip, overlays, pause menu panel, and scaled shelf root when the viewport size changes.
- Instantiates `scenes/shelf.tscn` for each configured shelf and places shelf cells from `scenes/layouts/layout_*.tscn` preset templates.
- Builds optional `row_layouts` or template-authored moving rows, including moving rows that clip and horizontally wrap more shelves than are visible at once.
- Spawns `ShelfItem` instances from config layers.
- Handles mouse and touch interaction.
- Resolves matches of three identical visible items on the same shelf, including the gather-and-shrink clear animation.
- Shows and expires the active combo count and shrinking green time strip in `Background/HudCenterSlot` when triple clears happen within the configured combo window.
- Shows the current run's star total in `UI/StarCounterLabel`; triple clears add stars equal to the 10-based combo value reached by each clear.
- Tracks cleared triples and unlocks shelves whose configs require progress before becoming accessible.
- Plays item placement and triple-clear sound effects.
- Keeps non-clearing items interactive while match animations run, with pending shelf resolves queued behind the active animation.
- Promotes back layers when the visible layer clears.
- Tracks the countdown timer, starting it only after the first meaningful player action, and win/loss overlays.
- Wires the in-level pause menu, including the top-right circular menu button, modal overlay, Leave action, and Continue action.
- Displays a responsive Godot-authored level backdrop with a top HUD strip, monotone shop wall, baseboard, and bottom floor band behind generated shelves.

Change here when:
- Editing puzzle rules, input behavior, runtime shelf construction, procedural level background styling, level timing, completion conditions, or ability behavior.

### Moving Shelf Rows

Files:
- `scenes/moving_shelf_row.tscn`
- `scenes/layouts/layout_*.tscn`
- `scripts/moving_shelf_row.gd`
- `scripts/shelf_layout_row.gd`
- `scripts/level.gd`
- `configs/levels/level_*.json`

Responsibility:
- Clips a shelf row to a configured visible window.
- Moves shelves horizontally at runtime and wraps them back through the opposite side.
- Lets layout templates author moving-row center positions and metadata.
- Lets `scripts/level.gd` decide drag/drop eligibility based on whether a moving shelf is currently inside the row window.
- Supports the floor-only shelf visual variant by runtime node hiding in `scripts/level.gd`.

Change here when:
- Adding row motion types, changing wrap timing, changing moving-row drag/drop targeting, or changing moving-row visual variants.

### Shelf Cell

Files:
- `scenes/shelf.tscn`
- `scripts/shelf.gd`

Responsibility:
- Defines the reusable shelf cell visuals, front slots, and item snap markers.
- Owns generated back-layer slot layout and preview styling defaults.
- Contains the visible back wall, opaque non-compounding interior/cast shadows, wood floor, frame, floor lip, floor grain nodes, and hidden edge details shown by `scripts/level.gd` for shelves with no stacked neighbor above, below, or to the right. Shelf cast shadows draw below generated back-layer item previews.
- Contains the hidden lock overlay used by triple-gated shelves; `scripts/level.gd` toggles it and fits the remaining count onto the lock center panel.
- Keeps the shelf width, height, and slot positions aligned with the level grid constants so a three-shelf row fills most of the gameplay viewport.

Change here when:
- Editing shelf visual details, back-layer preview presentation, locked shelf overlay visuals, front slot positions, item snap marker positions, or cell art node names.

### Item Runtime

Files:
- `scenes/item.tscn`
- `scripts/item.gd`
- `assets/items/*.png`

Responsibility:
- Represents one sortable item as an `Area2D`.
- Stores `item_id`.
- Applies texture and visual scale to its `Sprite2D` and shared opaque up-right cast shadow, which is disabled for generated back-layer item previews.
- Draws reusable alpha-based sprite outlines for item highlight states.

Change here when:
- Adjusting item hitboxes, sprite scale behavior, item identity storage, outline rendering, or common item visuals.

### Ability Bar

Files:
- `level.tscn`
- `scripts/level.gd`
- `scripts/player_progress.gd`
- `assets/abilities/*.png`

Responsibility:
- Provides hammer, shuffle, and highlight buttons.
- Reads campaign ability uses from `PlayerProgress`, spends campaign uses immediately, and uses temporary three-use counts for isolated dev/test levels.
- Lets hammer clear matching visible/front items first, or supplement visible/front items with first-back-layer copies of the same type if no visible item type can make a triple.
- Disables abilities after failure, completion, or when uses run out.
- Starts the highlight timer even when no current shelf state can be highlighted.
- Uses `ShelfItem` outline state for border-only highlight ability visuals.
- Shows the active highlight countdown in a bottom-right badge on the highlight button.

Change here when:
- Adding, removing, rebalancing, or restyling player abilities.

### Pause Menu

Files:
- `level.tscn`
- `scenes/pause_menu.tscn`
- `assets/ui/*.png`
- `scripts/pause_menu.gd`
- `scripts/level.gd`

Responsibility:
- `level.tscn` provides the top-right circular pause button and instances the pause menu scene.
- `scenes/pause_menu.tscn` owns the popup layout, `Pause` title, music / sound-effects / vibration icon buttons, and Leave/Continue buttons.
- `scripts/pause_menu.gd` toggles crossed-out visuals on the three settings icon buttons and emits setting state changes.
- `scripts/level.gd` opens and closes the menu, pauses the timer and gameplay input, routes Leave back to the main menu, and mutes gameplay sound effects when the sound-effects button is crossed out.

Change here when:
- Restyling the in-level pause popup, adding pause menu actions, or changing pause/resume behavior.

### Level Data And Tooling

Files:
- `configs/levels/level_*.json`
- `scenes/layouts/layout_*.tscn`
- `scripts/tools/generate_level_shelves.py`
- `scripts/tools/validate_level_solvable.py`

Responsibility:
- Stores level number, time limit, layout preset, and shelf layers.
- Stores named layout preset positions in Godot scene templates.
- Supports optional row layout configs for static and moving shelf rows.
- Supports the `grid_3x3_moving_5_bottom` preset for a 3x3 static grid plus a five-shelf moving bottom row.
- Supports optional per-shelf triple-clear unlock requirements.
- Generates shelf configs from difficulty, item, shelf, and layer settings.
- Validates shelf shape, known item IDs, row layout shape, item counts, and bounded solvability.

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
- Update `SHELF_CELL_VISUAL_SCALE`, `SHELF_BASE_CELL_SIZE`, `SHELF_SHARED_EDGE_THICKNESS`, and `SHELF_GRID_STEP` in `scripts/level.gd`.
- Reposition shelf markers in the relevant `scenes/layouts/layout_*.tscn` templates.
- Keep `scenes/shelf.tscn` cell bounds and boundary thickness aligned with those layout constants.
- Keep `scripts/moving_shelf_row.gd` row sizing and runtime configuration aligned with `SHELF_CELL_SIZE` and `SHELF_GRID_STEP`.
- Keep `SLOT_ITEM_POSITION`, shelf slot markers, `scenes/item.tscn` default scale, shelf instance scaling, and `item_pick_size` aligned when shelf width changes affect item spacing.
- Keep `scripts/tools/generate_level_shelves.py` layout presets in sync if preset names or supported shapes change.
- Fixed staggered preset positions live in `scenes/layouts/`; keep their required shelf counts documented in `docs/CONFIGS.md`.

Change matching rules:
- Update `_clear_matching_shelves()`, `_resolve_shelves()`, and related validation logic if the data rules also change.
- Update `scripts/tools/validate_level_solvable.py` so generated or validated levels match runtime behavior.

Change shelf unlock rules:
- Update `scripts/level.gd` shelf lock helpers, ability item collection, and match/promotion filters.
- Update `scenes/shelf.tscn` when changing the locked shelf overlay art, placement, or count label.
- Update `scripts/tools/validate_level_solvable.py` when unlock timing or counting semantics change.
- Keep `docs/CONFIGS.md` and generator `--locked-shelves` behavior aligned with the level JSON field.

Change drag or tap movement:
- Update `_input()`, `_handle_press_at()`, `_handle_motion_at()`, `_handle_release_at()`, `_move_item_to_slot()`, `_resolve_move_target_slot()`, and slot lookup helpers in `scripts/level.gd`.
- Keep occupied-slot fallback behavior in sync with `_resolve_move_target_slot()` and `_find_free_slot_on_target_shelf()`, including the same-shelf return-to-origin rule.
- Keep `_is_slot_drag_drop_targetable()` aligned with moving-row visibility rules if moving rows change.

Change moving shelf rows:
- Update `scripts/moving_shelf_row.gd` for row wrapping, clipping, speed, or visible-window behavior.
- Update `scripts/level.gd` row layout helpers and floor-only visual variant node list when config semantics or shelf visuals change.
- Update `scripts/tools/validate_level_solvable.py` when row layout config validation changes.
- Keep `docs/CONFIGS.md` row-layout schema and moving-row lock restrictions aligned.

Change gameplay sound effects:
- Update `assets/audio/item_place.wav`, `assets/audio/triple_clear.wav`, and the audio player helpers in `scripts/level.gd`.
- Keep the `SoundEffectsButton` setting path in `scripts/pause_menu.gd` and `scripts/level.gd` aligned when changing pause menu sound-effect controls.

Change level win or loss flow:
- Update `_process()`, `_fail_level()`, `_complete_level()`, `_check_level_completed()`, pause-menu helpers, and the panels in `level.tscn`.

Change pause menu layout:
- Update `scenes/pause_menu.tscn`.
- Update `assets/ui/*.png` when changing pause menu icon art.
- `assets/ui/pause_menu_option_a_sheet.png` and `assets/ui/pause_menu_option_b_sheet.png` are kept as alternate generated style sheets.
- Keep node paths used by `scripts/level.gd` stable unless the script is updated in the same change.

## Related Docs

- `docs/SCENES.md`: scene and node ownership inventory.
- `docs/SCRIPTS.md`: script responsibilities, exports, and dependencies.
- `docs/CONFIGS.md`: config file schema and data contracts.
- `docs/CLOUD_SAVE.md`: platform cloud-save setup and bridge contract.
