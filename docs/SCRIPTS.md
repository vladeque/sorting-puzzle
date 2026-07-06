# Scripts

This file documents what each script owns. Keep script docs focused on responsibilities, exports, dependencies, and boundaries.

## `scripts/production_main_menu.gd`

Attached to:
- `scenes/main_menu.tscn` root `ProductionMainMenu`.

Purpose:
- Shows the production campaign entry point over the production menu background.
- Labels the bottom button with the saved current level.
- Displays saved campaign lives in the top status bar and disables campaign play at zero lives.
- Displays saved gold coins in the top status bar.
- Displays the saved profile avatar and opens the profile editor from the top status bar.
- Displays the saved reward chest star progress in a separate left-side widget under the profile icon.
- Opens the main-menu settings popup from the top status bar.
- Launches the saved campaign level.

Key constants:
- `LEVEL_SCENE`: preloads `res://level.tscn`.
- `PROFILE_MENU_SCENE`: preloads `res://scenes/ui/profile_menu.tscn`.
- `SETTINGS_MENU_SCENE`: preloads `res://scenes/ui/settings_menu.tscn`.
- `MIN_LEVEL`: first campaign level number.
- `MAX_LEVEL`: last campaign level number.
- `PRODUCTION_MENU_SCENE`: return path assigned to campaign level instances.
- `LIFE_STATUS_REFRESH_SECONDS`: cadence for refreshing the lives countdown while the menu is visible.
- `BOTTOM_BAR_*`, `SIDE_MARGIN`, and `LEVEL_BUTTON_MAX_WIDTH`: responsive bottom-button layout values.

Important nodes:
- `%TopStatusBar`: top-anchored container positioned at runtime with safe-area padding; owns the status icon layout through `scenes/ui/main_menu_top_status.tscn`.
- `%RewardChest`: side-screen `scenes/ui/main_menu_reward_chest.tscn` instance positioned under the profile icon.
- `MainMenuTopStatus/ProfileWidget`: opens the profile menu.
- `MainMenuTopStatus/ProfileWidget/AvatarTexture`: displays the saved avatar texture.
- `MainMenuTopStatus/CoinsWidget/CoinAmount`: shows the saved gold coin balance.
- `MainMenuTopStatus/SettingsWidget/SettingsButton`: opens the main-menu settings popup.
- `MainMenuTopStatus/LivesWidget/LifeCount`: shows current campaign lives.
- `MainMenuTopStatus/LivesWidget/LifeStatus`: shows `Full` or the `MM:SS` countdown until the next restored life.
- `%BottomBar`: bottom-anchored container positioned at runtime with safe-area padding.
- `%LevelButton`: `scenes/ui/level_button.tscn` instance that starts the saved campaign level.

Key methods:
- `_ready()`: loads progress, wires the level button, and applies responsive layout.
- `_process(delta)`: refreshes the lives display and play button state once per elapsed real-time second while the menu is open.
- `_apply_responsive_layout()`: keeps the top status row and bottom button inside the viewport and safe area.
- `_layout_top_status_bar()`: positions the static top status row.
- `_layout_reward_chest()`: positions the side reward chest under the profile icon without putting it in the top status scene.
- `_update_level_button()`: displays the saved current level, no-lives state, or complete state.
- `_update_coin_status()`: writes the saved gold coin balance into the top status label.
- `_update_lives_status()`: writes current lives and the next-life `MM:SS` countdown into the top status labels.
- `_update_reward_chest_status()`: writes `PlayerProgress` reward chest progress into the side widget.
- `_format_life_restore_time(seconds_remaining)`: formats the next-life restore timer as zero-padded minutes and seconds.
- `_update_profile_avatar()`: loads the saved avatar texture into the top status profile widget.
- `_open_profile_menu()`: creates the centered profile menu window and listens for saved avatar changes.
- `_open_settings_menu()`: creates the centered settings popup and wires its close button.
- `_close_settings_menu()`: dismisses the settings popup.
- `_on_profile_avatar_saved(avatar_id)`: refreshes the top status avatar after the profile menu saves.
- `_launch_campaign_level()`: instantiates the level, sets campaign launch metadata, swaps current scene, and queues the menu for deletion.

Depends on:
- `level.tscn`
- `scenes/ui/settings_menu.tscn`
- `scripts/level.gd` export `selected_level`
- `scripts/level.gd` export `launched_from_dev_mode`
- `scripts/level.gd` export `return_menu_scene_path`
- `PlayerProgress` autoload

Do not use for:
- Developer/test level selection. Put that in `scripts/main_menu.gd`.
- Persistent save data ownership. Put that in `scripts/player_progress.gd`.
- Puzzle runtime logic.

## `scripts/main_menu_reward_chest.gd`

Attached to:
- `scenes/ui/main_menu_reward_chest.tscn` root `MainMenuRewardChest`.

Purpose:
- Owns the visual state of the main-menu reward chest progress widget.
- Updates the progress bar value and centered `current/goal` label.
- Shrinks the label font for longer progress text so it stays inside the bar.

Key methods:
- `set_reward_progress(current_stars, goal_stars)`: clamps the displayed value to the active goal and updates the bar and label.

Depends on:
- `scenes/ui/main_menu_reward_chest.tscn` node names `%ProgressBar` and `%AmountLabel`.

Do not use for:
- Saving stars, loading goal config, or awarding completion stars. Those stay in `PlayerProgress`.

## `scripts/profile_menu.gd`

Attached to:
- `scenes/ui/profile_menu.tscn` root `ProfileMenu`.

Purpose:
- Builds the player profile name editor and avatar picker.
- Loads the current player name into an editable field above the avatar section.
- Creates one avatar button for each id exposed by `PlayerProgress.get_available_avatar_ids()`.
- Keeps the pause-style menu panel responsive, with the avatar grid at three columns.
- Clips opaque square avatar PNGs to circular display in the top profile widget and picker.
- Emits `avatar_saved(avatar_id)` after the profile save succeeds so the main menu can refresh the avatar.

Key constants:
- `AVATAR_CLIP_SHADER`: shader used to hide square avatar texture corners.
- `GRID_COLUMNS`: fixed to `3`.
- `PANEL_MAX_WIDTH`, `PANEL_MAX_HEIGHT`, and `PANEL_MIN_MARGIN`: centered popup panel bounds.
- `AVATAR_BUTTON_MIN_SIZE` and `AVATAR_BUTTON_MAX_SIZE`: responsive avatar button bounds.
- `SAVE_BUTTON_MAX_WIDTH`: width cap for the bottom `Save` button.

Important nodes:
- `%ProfileMenuPanel`: centered pause-style popup panel resized by the script.
- `%NameLineEdit`: editable player-name field populated from `PlayerProgress.get_player_name()`.
- `%AvatarGrid`: `GridContainer` populated with generated avatar buttons.
- `%SaveButton`: `scenes/ui/level_button.tscn` instance labeled `Save`.
- `%CloseButton`: dismisses the picker without saving.

Key methods:
- `_build_avatar_buttons()`: creates the 18 avatar buttons and loads their textures.
- `_select_avatar(avatar_id)`: updates the pending avatar selection.
- `_save_selection()`: writes the entered player name and selected avatar through `PlayerProgress.set_profile()` and closes the menu.
- `_save_from_name_submit(new_text)`: saves the full profile when the name field is submitted.
- `_apply_responsive_layout()`: updates panel bounds, avatar button sizes, and save button width.
- `_apply_avatar_clip_material(avatar_texture)`: applies circular clipping to an avatar `TextureRect`.

Depends on:
- `PlayerProgress`
- `assets/ui/avatars/*.png`
- `assets/ui/avatar_circle_clip.gdshader`
- `scenes/ui/level_button.tscn`

Do not use for:
- Owning saved profile data, campaign progress, lives state, or main menu navigation.

## `scripts/main_menu.gd`

Attached to:
- `scenes/main_menu_testing.tscn` root `MainMenu`.

Purpose:
- Shows the testing-menu campaign play entry point for the saved current level.
- Builds the developer/test level selection grid when dev level select is enabled.
- Launches campaign or isolated dev/test levels.

Key constants:
- `LEVEL_SCENE`: preloads `res://level.tscn`.
- `MIN_LEVEL`: first selectable level number.
- `MAX_LEVEL`: last selectable level number.
- `DEV_LEVEL_SELECT_SETTING`: optional project setting that overrides debug-build dev level selection.
- `TESTING_MENU_SCENE`: return path assigned to levels launched from the testing menu.

Important nodes:
- `%PlayButton`: starts the saved campaign level.
- `%LevelGrid`: `GridContainer` filled with generated `Button` nodes.

Key methods:
- `_ready()`: loads progress, wires the play button, updates campaign progress text, and populates the dev selector when enabled.
- `_update_campaign_progress()`: displays the saved current level, no-lives state, or all-complete state.
- `_populate_level_selector()`: clears old buttons and creates one isolated dev/test button per level when dev selection is enabled.
- `_launch_campaign_level()`: launches `PlayerProgress.current_level`.
- `_launch_level(level_number, launched_from_dev_mode)`: instantiates the level, sets launch metadata, swaps current scene, and queues the menu for deletion.

Depends on:
- `level.tscn`
- `scripts/level.gd` export `selected_level`
- `scripts/level.gd` export `launched_from_dev_mode`
- `scripts/level.gd` export `return_menu_scene_path`
- `PlayerProgress` autoload

Do not use for:
- Persistent save data ownership. Put that in `scripts/player_progress.gd`.
- Puzzle runtime logic.

## `scripts/press_scale_button.gd`

Class:
- `PressScaleButton`

Attached to:
- `scenes/ui/level_button.tscn` root `LevelButton`.
- `level.tscn` `UI/CompletionPanel/NextButton`.
- `scenes/pause_menu.tscn` `PauseMenuPanel/ButtonRow/LeaveButton` and `ContinueButton`.
- `scenes/leave_confirmation_menu.tscn` `ConfirmationPanel/ButtonRow/ConfirmLeaveButton` and `ContinueButton`.

Purpose:
- Provides the default held-press visual behavior for buttons using `assets/ui/level_button_blank.png` and `assets/ui/level_button_blank_red.png`.
- Scales the button slightly smaller from its center on `button_down`, then restores its original scale on `button_up`, visibility changes, or exit from the scene tree.

Exports:
- `held_scale`: visual scale multiplier while the pointer or touch is held down, defaulting to `0.94`.

Use when:
- Adding future green or red blank-image level/action buttons that should visually press inward while held.

Do not use for:
- Plain text buttons, icon-slot settings buttons, or puzzle item input.

## `scripts/player_progress.gd`

Autoload:
- Registered as `PlayerProgress` in `project.godot`.

Purpose:
- Owns saved campaign progression, campaign lives, gold coins, campaign ability inventory, selected profile avatar, and player name.
- Owns saved reward chest star progress and active reward chest goal index.
- Persists state through the configured save provider.

Saved fields:
- `version`: save schema version.
- `current_level`: next campaign level to play.
- `highest_completed_level`: highest campaign level completed.
- `lives`: current campaign lives, clamped from `0` to `5`.
- `next_life_restore_unix`: Unix timestamp for the next hourly life restore, or `0` when lives are full.
- `coins`: current gold coin balance. Fresh saves start at `300`.
- `ability_uses`: remaining campaign uses for hammer, shuffle, and highlight.
- `avatar_id`: selected profile avatar id. Fresh and legacy saves default to `avatar_cat`.
- `player_name`: saved profile display name. Fresh and legacy saves without a valid value receive a generated `player_` name with a five-character random suffix, such as `player_g26f3`.
- `reward_chest_stars`: stars accumulated toward the active reward chest goal.
- `reward_chest_goal_index`: index into `configs/reward_chest_goals.json` for the active goal; the final configured goal repeats after it is reached.

Key methods:
- `load_progress()`: reads and sanitizes provider data or creates default in-memory progress.
- `save_progress()`: writes the current progress data through the active provider.
- `get_current_level()`: returns the next campaign level.
- `get_ability_uses()`: returns remaining campaign ability uses.
- `get_coins()`: returns the saved gold coin balance.
- `get_reward_chest_progress()`: returns the saved reward chest stars, active goal, and goal index.
- `add_reward_chest_stars(star_count)`: adds stars to the reward chest and rolls over reached goals.
- `get_available_avatar_ids()`: returns the 18 valid profile avatar ids.
- `get_avatar_id()`: returns the selected avatar id, sanitized to `avatar_cat` when needed.
- `get_avatar_texture_path(avatar_id)`: returns the resource path for a valid or sanitized avatar id.
- `get_player_name()`: returns a non-empty saved or generated player name.
- `set_avatar_id(avatar_id)`: validates, stores, and saves the selected profile avatar.
- `set_player_name(player_name)`: trims, stores, and saves a non-empty player name.
- `set_profile(avatar_id, player_name)`: validates and saves the avatar and player name together.
- `get_lives()`: refreshes and returns current campaign lives.
- `get_max_lives()`: returns the lives cap.
- `get_next_life_restore_seconds_remaining()`: returns seconds until the next life restore, or `0` when full.
- `refresh_lives()`: restores one life per elapsed real-time hour while lives are not full.
- `spend_life()`: immediately spends and saves one campaign life when available.
- `spend_ability(ability_id)`: immediately spends and saves one campaign ability use.
- `complete_level(level_number, earned_stars)`: records completion, advances `current_level` when the completed level is the active campaign level, adds earned campaign stars to the reward chest, and grants configured chest coin rewards when goals are reached.
- `reset_progress()`: restores default progress and writes it to disk for testing.
- `get_save_provider_name()`: reports the active provider for diagnostics.

Depends on:
- `scripts/save_providers/local_save_provider.gd`
- `scripts/save_providers/cloud_save_provider.gd`
- `application/config/save_provider`
- `application/config/cloud_save_name`
- `application/config/cloud_save_bridge_singleton`
- `configs/reward_chest_goals.json`

Do not use for:
- Per-level shelf state, timer state, or dev/test level runtime state.

## `scripts/save_providers/save_provider.gd`

Class:
- `SaveProvider`

Purpose:
- Base interface for progress persistence providers.

Key methods:
- `get_provider_name()`: returns a diagnostic provider name.
- `is_available()`: reports whether the provider can be used.
- `load_data()`: returns `{ "ok": bool, "data": Dictionary, "error": String }`.
- `save_data(data)`: writes a progress dictionary using the same result shape.

## `scripts/save_providers/local_save_provider.gd`

Class:
- `LocalSaveProvider`

Purpose:
- Reads and writes local development progress at `user://player_progress.json`.

Do not use for:
- Release cloud persistence that must survive uninstall/reinstall.

## `scripts/save_providers/cloud_save_provider.gd`

Class:
- `CloudSaveProvider`

Purpose:
- Routes progress JSON to a platform-native cloud save bridge.
- Uses Google Play Games on Android and Apple Game Center on iOS when the matching Godot native singleton exists.

Bridge singleton names:
- `GooglePlayGamesSaveBridge` on Android.
- `GameCenterSaveBridge` on iOS.
- `CloudSaveBridge` fallback for tests or custom plugins.

Bridge method contract:
- Optional sign-in method: `is_signed_in()` or `is_authenticated()`.
- Load method: `load_save(save_name)`, `load_game(save_name)`, `load_progress(save_name)`, or `load_data(save_name)`.
- Save method: `save_save(save_name, json_payload)`, `save_game(save_name, json_payload)`, `save_progress(save_name, json_payload)`, or `save_data(save_name, json_payload)`.

Depends on:
- A native Godot Android/iOS plugin for real platform API calls.
- `docs/CLOUD_SAVE.md` for release setup details.

## `scripts/level.gd`

Attached to:
- `level.tscn` root `Level`.

Purpose:
- Owns active level state, runtime shelf creation, item spawning, input handling, matching, abilities, timer, failure, and completion.

Important exports:
- `slot_snap_distance`: maximum snap distance for drag or tap placement, sized for the wider shelf spacing.
- `item_pick_size`: rectangle used to detect clicked or touched visible items at the default item scale.
- `drag_start_distance`: pointer movement required to convert a press into a drag.
- `layer_promotion_duration_seconds`: duration for back-layer items to slide forward into active front slots.
- `item_move_duration_seconds`: duration for moved items to slide into destination slots after tap or drag placement, including invalid drag returns.
- `highlight_outline_color`: border color used by the highlight ability.
- `selected_highlight_outline_color`: border color used when a highlighted item is also selected.
- `highlight_outline_width`: screen-pixel expansion used by the item outline sprite.
- `match_gather_duration_seconds`: duration for side items to pull into the center item when a triple clears.
- `match_shrink_duration_seconds`: duration for the center item shrink-out after a triple gathers.
- `combo_window_seconds`: time allowed after a triple clear to extend the active combo before the center HUD combo label and fill disappear.
- `level_duration_seconds`: fallback duration if config does not define `time_seconds`.
- `item_place_volume_db`: volume for the item placement sound effect.
- `triple_clear_volume_db`: volume for the matched triple clear sound effect.
- `selected_level`: level number loaded from `configs/levels/level_%03d.json`.
- `launched_from_dev_mode`: makes a level use isolated temporary ability counts and return to the menu instead of saving campaign progress.
- `return_menu_scene_path`: menu scene path used by Leave and dev/test completion returns.

Important constants:
- `SLOT_COUNT`: currently three items per shelf front layer.
- `SLOT_ITEM_POSITION`: item local position that matches `scenes/shelf.tscn` item snap markers.
- `SHELF_CELL_VISUAL_SCALE`: slight runtime scale applied to generated shelf instances so shelf art and item children enlarge together.
- `SHELF_BASE_CELL_SIZE`: unscaled reusable shelf scene bounds from `scenes/shelf.tscn`.
- `SHELF_CELL_SIZE`: scaled reusable shelf scene bounds; three cells in a row are packed to fill most of the 720 px gameplay viewport, with compact vertical row spacing.
- `SHELF_SHARED_EDGE_THICKNESS`: shelf boundary thickness that neighboring cells overlap.
- `SHELF_GRID_STEP`: packed layout spacing after overlapping shared shelf edges.
- `LAYOUT_ROW_VERTICAL_EPSILON`: tolerance used to group authored layout-template shelf markers into horizontal rows before assigning left/middle/right shelf visuals.
- `HUD_*`, `ABILITY_BAR_*`, `SHELVES_*`, `RESULT_LABEL_HEIGHT`, `PAUSE_MENU_PANEL_SIZE`, and `LEAVE_CONFIRM_PANEL_SIZE`: responsive layout constants for positioning the HUD, ability bar, result overlays, pause panel, leave confirmation panel, and generated shelf root across portrait viewport sizes, including minimum and maximum shelf layout scale.
- `SHELF_SCENE`: `res://scenes/shelf.tscn`.
- `MOVING_SHELF_ROW_SCENE`: `res://scenes/moving_shelf_row.tscn`.
- `ITEM_SCENE`: `res://scenes/item.tscn`.
- `ITEM_SPRITES_CONFIG`: `res://configs/item_sprites.json`.
- `LEVEL_CONFIG_TEMPLATE`: `res://configs/levels/level_%03d.json`.
- `DEFAULT_LEVEL_CONFIG`: fallback level config.
- `LAYOUT_SCENE_TEMPLATE`: `res://scenes/layouts/layout_%s.tscn` path pattern used by `layout_preset`.
- `DEFAULT_LAYOUT_PRESET`: fallback layout preset.
- `MAIN_MENU_SCENE`: default scene returned to after completion.
- `LEVEL_SCENE_PATH`: scene loaded when the completion `Next` button advances normal campaign play to the next level.
- `ITEM_PLACE_SOUND`: short sound played when the player drops or moves an item into a shelf slot.
- `TRIPLE_CLEAR_SOUND`: sound played when a matched triple gathers and disappears.

Key responsibilities:
- Apply responsive layout with `_apply_responsive_layout()`, including safe-area-aware top HUD placement, ability bar placement over the floor/baseboard transition strip, full-screen overlays, centered pause and leave-confirmation popups, shelf-root scaling, and shelf-root centering between HUD and ability controls.
- Resize the scene-owned `Background` control so its procedural top strip, shop wall, baseboard, and floor bands fill the active viewport.
- Load JSON configs with `_load_json_file()`.
- Instantiate reusable shelf cells with `_add_shelf()`, apply the shared shelf visual scale, assign left/middle/right row placement visuals for static shelves, and ask `Shelf` to add generated back layers.
- Ask each shelf scene to show or hide its placement-specific `TopCeilingCap` when it has no stacked neighbor above. Show each shelf scene's bottom `Shadow` and `RightColumnShadow` whenever the shelf uses full visuals so neighboring shelf bodies and items cover those low-layer cast shadows while exposed wall/background areas still receive them.
- Load `layout_preset` scene templates from `scenes/layouts/`, group authored `ShelfXX` markers into rows by position, and place runtime shelves with derived row-placement visuals.
- Build optional `row_layouts` rows with `_add_row_layout_shelves()`, including horizontally wrapping moving rows and static rows mixed in one level. Moving-row shelves currently use the neutral middle row-placement visual.
- Build moving rows declared by layout template `MovingRowXX` nodes with `scripts/shelf_layout_row.gd`; their shelves also use the neutral middle row-placement visual.
- Keep moving-row shelves out of drag/drop targeting while they are outside the row's visible window, while abilities still use unlocked shelf items.
- Spawn configured items with `_add_configured_item()`.
- Handle mouse and touch input through `_input()` and the press/motion/release helpers.
- Move items with `_move_item_to_slot()`, `_resolve_move_target_slot()`, `_play_item_move_animation()`, and `_place_item_in_slot()`.
- Hide the active item's contact shadow while the player is dragging it, then restore the shadow when the drag releases, cancels, fails, or completes.
- Redirect moves aimed at an occupied destination slot on another shelf to the nearest free front slot on that destination shelf; same-shelf occupied targets leave the item in its original slot.
- Clear triples with `_clear_matching_shelves()` and `_play_match_clear_animation()`.
- Track the active triple-clear combo with `_extend_combo()`, `_update_combo_timer()`, `_reset_combo()`, and `_update_combo_hud()`, including the shrinking center-slot fill. Combo value increases by 1 per cleared triple, and each cleared triple adds stars equal to the combo value reached by that triple; `_update_star_counter_label()` writes that number into `UI/StarCounterLabel/CountLabel` beside the shared reward star icon.
- Track cleared triples and locked shelf accessibility with `_record_triples_cleared()`, `_update_locked_shelves()`, and shelf metadata from `unlock_after_triples`.
- Toggle each shelf scene's lock overlay with the remaining triple count, fit that count to the lock art's center panel, and keep locked shelves out of move, match, promotion, and ability targeting.
- Play placement and triple-clear sound effects with runtime `AudioStreamPlayer` nodes.
- Track clearing items so only disappearing items ignore input and abilities during the animation.
- Track transitioning items so newly promoted back-layer items ignore input and abilities until their forward slide finishes.
- Queue shelf resolution requests made while another match animation is still finishing.
- Promote back layers with `_promote_back_layer()`, `_play_layer_promotion_animation()`, and `_advance_back_layers()`.
- Check win/loss state with `_check_level_completed()`, `_fail_level()`, and `_complete_level()`.
- Spend one campaign life on campaign failure and on confirmed pause-menu Leave through `_spend_campaign_life_for_run()`, guarded so one level run cannot spend twice.
- Save campaign completion through `PlayerProgress`, show `UI/CompletionPanel` with the run's earned star count, and load the next campaign level when the completion `Next` button is pressed.
- Return to the configured menu scene when leaving a level or when the dev/test completion `Next` button is pressed.
- Keep the level countdown idle until the first meaningful player action, then format the active timer as zero-padded `MM:SS` text with `_update_timer_label()`.
- Pause and resume active gameplay through the top-right menu button, the instanced `UI/PauseMenuOverlay`, `UI/LeaveConfirmationOverlay`, `Leave`, `Continue`, and red close buttons.
- Initialize item placement and triple-clear sound effects from the shared sound-effects setting and keep them disabled while that toggle is crossed out.
- Manage hammer, shuffle, and highlight abilities. Campaign levels read and spend saved ability counts through `PlayerProgress`; dev/test levels use isolated temporary counts.
- Hammer targets visible/front triples first, then can supplement visible/front matches with first-back-layer copies of the same item type when no visible item type has three available copies.
- Count hammer destroys as cleared triples for shelf unlocking.
- Let highlight uses start their timed window even when no immediate triple can currently be highlighted.
- Apply highlight ability visuals through `ShelfItem.set_outline()` so only item silhouettes receive a border, and update the highlight button countdown label while that window is active.

Depends on:
- `level.tscn` node names and paths.
- `scenes/shelf.tscn` slot names and item snap marker names.
- `scripts/shelf.gd` for generated back-layer preview setup.
- `scenes/shelf.tscn` `LockedOverlay/RemainingLabel` for locked shelf progress display on the lock image.
- `scenes/moving_shelf_row.tscn` for optional row-layout movement and clipping.
- `scenes/layouts/layout_*.tscn` for named layout preset placement.
- `scenes/pause_menu.tscn` button node names used under `UI/PauseMenuOverlay`.
- `scenes/item.tscn` and `ShelfItem`.
- `assets/audio/item_place.wav` and `assets/audio/triple_clear.wav`.
- `configs/item_sprites.json` item IDs and texture paths.
- `configs/levels/level_*.json` shelf schema.
- `PlayerProgress` autoload for campaign progress, lives, and ability inventory.
- `scenes/leave_confirmation_menu.tscn` button and star-count node names used under `UI/LeaveConfirmationOverlay`.

Do not use for:
- Offline level generation or solvability search. Keep that in `scripts/tools/`.
- Save data ownership. Keep that in `scripts/player_progress.gd`.

## `scripts/shelf.gd`

Class:
- `Shelf`

Attached to:
- `scenes/shelf.tscn` root `Shelf`.

Purpose:
- Owns reusable shelf-cell runtime helpers and back-layer preview presentation.
- Owns shelf visual switching for `full` versus `floor_only` variants.
- Owns row-placement visual switching for `left`, `middle`, and `right` shelf cells by toggling scene-authored `PlacementVisuals` containers.
- Creates generated back-layer slot nodes for one shelf.
- Applies back-layer preview item scale, tint, visibility, z-index, and disabled collision state.

Important exports:
- `back_layer_offset`: visual offset for generated hidden/upcoming shelf layers.
- `back_layer_z_index`: z-index used by generated back-layer container nodes, above shelf floor details and below active front items.
- `back_layer_item_z_index`: z-index used by generated back-layer preview items.
- `back_layer_item_scale`: scale multiplier for back-layer item previews.
- `back_layer_item_modulate`: color used for visible back-layer previews.

Key methods:
- `set_visual_variant(visual_variant)`: applies `full` or `floor_only` shelf presentation and records the active variant as metadata for `scripts/level.gd` shelf edge and cast-shadow visibility checks.
- `get_visual_variant()`: returns the active shelf visual variant.
- `set_row_placement(row_placement)`: toggles the matching `PlacementVisuals/Left`, `PlacementVisuals/Middle`, or `PlacementVisuals/Right` container and records the active placement as metadata.
- `get_row_placement()`: returns the active shelf row placement.
- `set_top_ceiling_cap_visible(should_show)`: applies layout-derived visibility to every placement-specific `TopCeilingCap`, gated by the active shelf visual variant.
- `add_back_layer(layer_index, front_slots)`: creates a generated back-layer container and slot nodes aligned to the shelf front slots.
- `get_back_layer(layer_index)`: returns a generated back-layer container by index.
- `get_back_layer_name(layer_index)`: centralizes generated back-layer node names.
- `configure_back_layer(layer, layer_index)`: shows only the first back layer and hides deeper previews.
- `configure_back_layer_item(item, should_show)`: applies preview styling and disables input, collision, and contact shadow rendering for one back-layer item.

Depends on:
- `ShelfItem` from `scripts/item.gd`.
- Front slot node names from `scenes/shelf.tscn`.

Do not use for:
- Level JSON parsing, item identity assignment, matching, abilities, lock progression, or promotion timing. Those stay in `scripts/level.gd`.

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
- `scenes/ui/settings_menu.tscn` root `MainMenuSettingsOverlay`.

Purpose:
- Owns shared in-memory settings-button visual state for the current app session.
- Toggles a crossed-out overlay on the music, sound effects, and vibration rectangular slot buttons when clicked.
- Emits `setting_toggled(setting_id, is_disabled)` so owning runtime scripts can apply supported settings.
- Also powers the matching visual toggles in the main-menu settings popup, which intentionally keeps the same `PauseMenuPanel/InnerPanel/IconRow` button paths.
- Initializes every pause-menu and main-menu settings instance from the same disabled-state dictionary so matching buttons stay visually synchronized.

Important nodes:
- `PauseMenuPanel/InnerPanel/IconRow/MusicOption/MusicButton`
- `PauseMenuPanel/InnerPanel/IconRow/SoundEffectsOption/SoundEffectsButton`
- `PauseMenuPanel/InnerPanel/IconRow/VibrationOption/VibrationButton`

Key methods:
- `is_setting_disabled(setting_id)`: returns the shared disabled state for owning scripts such as `scripts/level.gd`.

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
- `_apply_texture()`: updates `Sprite2D.texture` and hides the soft contact shadow when the item has no texture.
- `_apply_visual_scale()`: updates `Sprite2D`, `OutlineSprite`, and contact-shadow scale.
- `set_outline(enabled, color, width)`: enables or disables the sprite border highlight.
- `set_contact_shadow_enabled(enabled)`: toggles the item contact shadow while still respecting texture availability; used by back-layer previews and active player dragging.
- `_apply_outline()`: sends outline properties to the `OutlineSprite` shader material and keeps the outline node visible only while enabled.

Depends on:
- Child node `Sprite2D`.
- Child node `OutlineSprite`.
- Child node `Shadow`.
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
