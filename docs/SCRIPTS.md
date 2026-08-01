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
- Consumes completed-level reward payloads, displays the pre-reward chest value, and advances it once for each clover coin that reaches the chest.
- Opens the reward chest detail modal when the reward chest widget emits `chest_pressed`.
- Opens the main-menu settings popup from the top status bar.
- Launches the saved campaign level.
- Opens the dedicated leaderboard scene from the bottom navigation trophy signal.
- Consumes `PlayerProgress.consume_pending_leaderboard_reward()` and shows `%LeaderboardRewardDialog` when a weekly leaderboard rollover granted a coin reward since the last launch.

Key constants:
- `LEVEL_SCENE`: preloads `res://level.tscn`.
- `PROFILE_MENU_SCENE`: preloads `res://scenes/ui/profile_menu.tscn`.
- `SETTINGS_MENU_SCENE`: preloads `res://scenes/ui/settings_menu.tscn`.
- `REWARD_CHEST_MENU_SCENE`: preloads `res://scenes/ui/reward_chest_menu.tscn`.
- `MIN_LEVEL`: first campaign level number.
- `MAX_LEVEL`: last campaign level number.
- `PRODUCTION_MENU_SCENE`: return path assigned to campaign level instances.
- `LEADERBOARD_SCENE`: destination path for the trophy tab.
- `LIFE_STATUS_REFRESH_SECONDS`: cadence for refreshing the lives countdown while the menu is visible.
- `TOP_MARGIN`: preferred distance from the physical top edge for the status row.
- `CAMERA_CUTOUT_PADDING`: empty space reserved around each reported display cutout.
- `BOTTOM_BAR_*`, `SIDE_MARGIN`, and `LEVEL_BUTTON_MAX_WIDTH`: responsive bottom-button layout values.

Important nodes:
- `%TopStatusBar`: top-anchored container positioned inside the display's top inset region while avoiding exact camera cutout rectangles.
- `%RewardChest`: side-screen `scenes/ui/main_menu_reward_chest.tscn` instance positioned under the profile icon.
- `%HouseRewardOrigin`: normalized marker over the background house.
- `%RewardCoinFlyer`: dedicated fullscreen completed-level coin effect.
- `MainMenuTopStatus/ProfileWidget`: opens the profile menu.
- `MainMenuTopStatus/ProfileWidget/AvatarTexture`: displays the saved avatar texture.
- `MainMenuTopStatus/CoinsWidget/CoinAmount`: shows the saved gold coin balance.
- `MainMenuTopStatus/SettingsWidget/SettingsButton`: opens the main-menu settings popup.
- `MainMenuTopStatus/LivesWidget/LifeCount`: shows current campaign lives.
- `MainMenuTopStatus/LivesWidget/LifeStatus`: shows `Full` or the `MM:SS` countdown until the next restored life.
- `%BottomBar`: bottom-anchored container positioned at runtime with safe-area padding.
- `%LevelButton`: `scenes/ui/level_button.tscn` instance that starts the saved campaign level.
- `%BottomNavigation`: full-width `scenes/ui/main_menu_bottom_navigation.tscn` instance aligned to the viewport bottom and extended through the device safe area.

Key methods:
- `_ready()`: loads progress, wires level and bottom-navigation buttons, refreshes the saved coin label, selects Home, and applies responsive layout.
- `_process(delta)`: refreshes the lives display and play button state once per elapsed real-time second while the menu is open.
- `_apply_responsive_layout()`: keeps the top status row cutout-aware and the bottom button inside the viewport safe area.
- `_layout_top_status_bar()`: places the status row at `TOP_MARGIN`, expands its center exclusion gap around camera cutouts, and falls below a cutout only when the row cannot fit around it.
- `_layout_reward_chest()`: positions the side reward chest under the profile icon without putting it in the top status scene.
- `_layout_bottom_navigation()`: sizes the full-width navigation bar and passes its safe-bottom inset to the scene-owned layout.
- `_update_level_button()`: displays the saved current level, no-lives state, or complete state.
- `_update_coin_status()`: writes the saved gold coin balance into the top status label.
- `_update_lives_status()`: writes current lives and the next-life `MM:SS` countdown into the top status labels.
- `_update_reward_chest_status()`: writes `PlayerProgress` reward chest progress into the side widget.
- `_play_pending_reward_animation()`: flies earned clover coins from the house to the chest after scene entry.
- `_on_reward_coin_arrived()`: advances the displayed chest count and handles configured goal rollover on impact.
- `_format_life_restore_time(seconds_remaining)`: formats the next-life restore timer as zero-padded minutes and seconds.
- `_update_profile_avatar()`: loads the saved avatar texture into the top status profile widget.
- `_open_profile_menu()`: creates the centered profile menu window and listens for saved avatar changes.
- `_open_settings_menu()`: creates the centered settings popup and wires its close button.
- `_close_settings_menu()`: dismisses the settings popup.
- `_open_reward_chest_menu()`: creates the centered reward chest detail modal; the modal reads its own progress and wires its own close button.
- `_open_leaderboard()`: replaces the production menu with the dedicated leaderboard scene.
- `_open_shop()`: replaces the production menu with the dedicated Shop scene.
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
- Persistent save data ownership. Put that in `scripts/save/local_save_store.gd`; use
  `PlayerProgress` only as the gameplay facade.
- Puzzle runtime logic.

## `scripts/main_menu_top_status.gd`

Attached to:
- `scenes/ui/main_menu_top_status.tscn` root `MainMenuTopStatus`.

Purpose:
- Owns the status row's center exclusion spacer.
- Applies the requested camera corridor while preserving the minimum visual gap between the coin and lives widgets.
- Reports the exclusion width that fits after accounting for the four fixed-width status widgets.

Do not use for:
- Querying display cutouts or positioning the row vertically. The owning menu performs those screen-level layout decisions.

## `scripts/main_menu_bottom_navigation.gd`

Attached to:
- `scenes/ui/main_menu_bottom_navigation.tscn` root `MainMenuBottomNavigation`.

Purpose:
- Wires the three scene-owned icon buttons to `shop_pressed`, `home_pressed`, and `leaderboard_pressed` signals.
- Applies runtime bottom safe-area padding while preserving three equal-width button segments.
- Owns the reusable active-tab presentation: `set_active_tab(tab_name)` raises the selected icon beyond the bar height, shows its label, and restores the other icons to centered unlabeled states.

Do not use for:
- Loading destination scenes or owning menu progression.

## `scripts/leaderboard_screen.gd`

Attached to:
- `scenes/ui/leaderboard_screen.tscn` root `LeaderboardScreen`.

Purpose:
- Owns Weekly, Country, and World selection and asynchronous provider requests.
- Builds ranking rows from provider dictionaries and pins the local player via `%PinnedPlayerRow`
  when absent from the returned entries or ranked beyond `PINNED_ROW_RANK_THRESHOLD` (10) -- being
  technically present on a 50-row page doesn't mean the player is visible without scrolling.
- Updates the weekly reset countdown and loading, empty, and retry states.
- Reports the player's Weekly rank to `PlayerProgress.record_weekly_leaderboard_rank()` after every
  successful Weekly fetch, and populates `%RewardTiersLabel` from
  `PlayerProgress.get_leaderboard_reward_tiers()` (Weekly scope only -- Country/World are all-time
  boards with no reset/payout moment).
- Applies responsive content width, compact row sizing, bottom-navigation placement, and mobile safe-area margins.
- Routes the shared Home tab back to `scenes/main_menu.tscn`.
- Routes the shared Shop tab to `scenes/ui/shop_screen.tscn`.

Depends on:
- `scripts/leaderboards/leaderboard_service.gd`.
- `scenes/ui/leaderboard_row.tscn`.
- `PlayerProgress` leaderboard and profile getters.

## `scripts/shop_screen.gd`

- Owns Shop loading/error states, creates reusable offer scenes, coordinates one purchase at a time, and routes the shared navigation.
- Passes purchase results to `PlayerProgress.apply_shop_purchase()` and refreshes the visible balance after a grant.
- Applies maximum content width, compact offer sizing, fixed bottom navigation, and mobile safe-area margins.
- Owns the `ABILITY_INFO` display copy (name + one-line description) for Hammer/Shuffle/Lantern/
  Freezer and shows it through `%PurchaseDialog` when a bundle card's `info_requested` signal fires.

## Shop component scripts

- `scripts/shop_bundle_card.gd`: binds one bundle's title, coin/Hammer/Shuffle/Lantern/Freezer
  rewards (coins shown first), formatted price, and purchase signal. Also binds the optional
  discount starburst badge/compare-at price from
  `offer.discount_percent`/`offer.store.compare_at_formatted_price` and widens `%TitleSpacer` while
  the badge is visible so it never overlaps the title, and emits `info_requested(ability_id)` when a
  reward cell's transparent info button is tapped.
- `scripts/shop_coin_offer_row.gd`: binds a coin quantity, formatted price, and purchase signal.
  Also binds an optional `tag` banner (for example "BEST VALUE").
- `scripts/coin_balance_widget.gd`: formats and displays a non-negative coin balance.
- `scripts/shop_purchase_dialog.gd`: shows and dismisses a focused result modal; `show_result()`
  takes an optional `button_text` (defaults to "Continue") so the same dialog reads correctly for
  both purchase results and ability info lookups ("Got it").

## Store scripts

- `scripts/store/store_provider.gd`: provider contract for product loading and purchase requests.
- `scripts/store/mock_store_provider.gd`: resolves config prices for `application/config/mock_store_country` and returns unique mock transaction ids after a short asynchronous delay. Also resolves an offer's optional `compare_at_prices` into `compare_at_formatted_price` the same way it resolves `mock_prices` into `formatted_price`; omitted when the offer has no compare-at price.
- `scripts/store/store_service.gd`: selects a catalog source via `application/config/shop_catalog_source` (`local` default or `backend`), joins its offers with `_provider` (always the mock provider), and returns normalized purchase results. `purchase_offer()`/pricing behavior is unchanged by the catalog source. This is the client replacement point for later platform integrations.
- `scripts/store/backend_catalog_source.gd` (GAME-008): `shop_catalog_source=backend`'s offer source. Reads the authenticated backend development catalog (`GET /v1/catalog`) through the shared `BackendTransport`/`BackendReadOperations` (GAME-007), keeps only offers with `eligible: true`, maps the backend `type` enum to the UI's `bundle`/`coins` grouping, and joins each offer to `configs/backend/shop_catalog_prices.json` by `platform_product_id` for its display title and mock regional price via the same `MockStoreProvider.load_products()` the local catalog uses. Also carries that presentation entry's optional `compare_at_prices` (through the same price-provider resolution), `discount_percent`, and `tag` onto the joined offer, so the Shop's discount badge and value tag work the same regardless of `shop_catalog_source`. Offers with an unrecognized type or no local price-table entry are silently excluded rather than rendered without a price. Any failed read (unavailable, unauthorized, malformed, or an empty local `backend_base_url`) falls back to `BackendCatalogCache`; only surfaces an error when no cache exists either.
- `scripts/store/backend_catalog_cache.gd` (GAME-008): persists the last successfully joined/priced backend catalog to `user://shop_catalog_backend_cache.json` (offers/prices only, never a token or signature) for the offline-cache fallback above.

## `scripts/tools/verify_shop.gd`

- Runs through `scenes/shop_verification.tscn` with an isolated test user-data directory.
- Verifies US, Ukrainian, German, and Japanese mock price strings; five representative portrait
  viewports; the five-reward starter layout (coins first), its loaded discount badge texture, and
  compare-at price; offer population; the `coins_3500` best-value tag (and that untagged offers
  stay untagged); the ability info dialog opening with the right title when a reward icon is
  tapped; coin and bundle purchases including three Freezers; and duplicate transaction
  protection.

Run:

```powershell
& 'D:\Godot\godot.exe' --headless --path . scenes/shop_verification.tscn --user-data-dir <scratch-dir>
```

Prints `SHOP VERIFICATION PASSED` and exits `0` on success; otherwise prints each failed check and exits `1`.

## `scripts/leaderboard_row.gd`

Class:
- `LeaderboardRow`

Attached to:
- `scenes/ui/leaderboard_row.tscn` root `LeaderboardRow`.

Purpose:
- Binds one provider entry to rank, avatar, display name, and comma-formatted star score controls.
- Toggles the scene-authored current-player highlight.
- Toggles the scene-authored gold/silver/bronze `RankSlot` medal circle for rank 1/2/3 and switches
  `RankLabel` between a bare number (top 3) and "#N" (rank 4+).
- Applies compact or regular row and font sizing, including `RankSlot`'s size to match the avatar.

## `scripts/leaderboard_reward_dialog.gd`

Class:
- `LeaderboardRewardDialog`

Attached to:
- `scenes/ui/leaderboard_reward_dialog.tscn` root `LeaderboardRewardDialog`.

Purpose:
- Generic titled-message modal shown once per granted weekly reward, mirroring
  `shop_purchase_dialog.gd`'s structure. `show_reward(rank, coin_reward)` builds the message from
  the actual granted values; `scripts/production_main_menu.gd` is the only caller.

## `scripts/leaderboards/leaderboard_provider.gd`

Class:
- `LeaderboardProvider`

Purpose:
- Defines the provider contract and shared Weekly, Country, and World scope identifiers.
- Normalizes provider results as `ok`, `entries`, `player_entry`, `period_end_unix`, `has_more`, and `error` fields.

## `scripts/leaderboards/mock_leaderboard_provider.gd`

Class:
- `MockLeaderboardProvider`

Purpose:
- Produces 50 deterministic mock competitors plus the current player for all three scopes.
- Sorts scores descending, assigns competition ranks, and returns the current player separately for pinned presentation.
- Uses weekly stars for Weekly and lifetime stars for Country and World.

## `scripts/leaderboards/backend_leaderboard_provider.gd`

Class:
- `BackendLeaderboardProvider`

Purpose:
- GAME-009 `leaderboard_provider=backend` provider. Reads `GET /v1/leaderboards/{scope}` through the shared `BackendTransport`/`BackendReadOperations.parse_leaderboard()` (GAME-007) and implements the same `fetch_leaderboard(scope, current_player, limit)` contract as `MockLeaderboardProvider`, so `leaderboard_screen.gd` is unchanged.
- Passes entries, rank, score, and tie order through unchanged; resolves `player_entry` from the response's `current_player` field (outside-page placement) or from the matching `is_current_player` row in `entries` (inside-page placement); converts `period_end` to `period_end_unix`; and sets `has_more` from a non-empty `next_cursor`.
- Exposes `fetch_page(scope, limit, cursor)` for cursor-forwarded pagination, not yet used by the screen.
- Falls back to `BackendLeaderboardCache` on any unavailable, unauthorized, expired-cursor, or malformed read; only surfaces an error when no cache exists either.

## `scripts/leaderboards/backend_leaderboard_cache.gd`

Class:
- `BackendLeaderboardCache`

Purpose:
- Persists the last successfully fetched backend leaderboard page per scope to `user://leaderboard_backend_cache.json` (entries/current-player/period end only, never a token, signature, or cursor) for the offline-cache fallback above.

## `scripts/leaderboards/leaderboard_service.gd`

Class:
- `LeaderboardService`

Purpose:
- Selects the configured provider and exposes the asynchronous fetch method used by the screen.
- Falls back to the mock provider when an unsupported provider id is configured.
- GAME-009: `application/config/leaderboard_provider=backend` selects `BackendLeaderboardProvider`, looking up the shared `BackendTransport` through the `PlayerProgress` autoload by name (mirrors `scripts/store/store_service.gd`'s `_find_backend_transport()`).
- Is the replacement point for a later HTTP or platform-backed provider.

## `scripts/main_menu_reward_coin_flyer.gd`

Attached to:
- `scenes/ui/main_menu_reward_coin_flyer.tscn` root `MainMenuRewardCoinFlyer`.

Purpose:
- Creates and animates one clover coin for every star earned in the just-completed level.
- Staggers arcing coin tweens between menu-provided global positions.
- Emits `coin_arrived` for count updates and `animation_finished` for final saved-state reconciliation.

Depends on:
- `assets/ui/clover_coin_transparent_96x96.png`.
- The production menu for start and target positions.

## `scripts/main_menu_reward_chest.gd`

Attached to:
- `scenes/ui/main_menu_reward_chest.tscn` root `MainMenuRewardChest`.

Purpose:
- Owns the visual state of the main-menu reward chest progress widget.
- Updates the progress bar value and centered `current/goal` label.
- Shrinks the label font for longer progress text so it stays inside the bar.
- Emits `chest_pressed` when the widget's full-rect `%ChestButton` overlay is tapped; the icon and
  progress bar underneath stay `mouse_filter = Ignore` and never receive input directly.

Key methods:
- `set_reward_progress(current_stars, goal_stars)`: clamps the displayed value to the active goal and updates the bar and label.
- `get_coin_target_global_position()`: returns the center of the chest art for reward flights.
- `play_receive_pulse()`: briefly pulses the chest when a reward coin arrives.

Depends on:
- `scenes/ui/main_menu_reward_chest.tscn` node names `%ProgressBar`, `%AmountLabel`, and `%ChestButton`.

Do not use for:
- Saving stars, loading goal config, or awarding completion stars. Those stay in `PlayerProgress`.
- Owning the detail modal. `scripts/reward_chest_menu.gd` reads `PlayerProgress` itself once opened.

## `scripts/reward_chest_menu.gd`

Attached to:
- `scenes/ui/reward_chest_menu.tscn` root `RewardChestMenu`.

Purpose:
- Self-contained reward chest detail modal, opened from the main menu's reward chest widget.
- Reads `PlayerProgress.get_reward_chest_progress()` directly in `_ready()`, the same self-contained
  pattern as `scripts/profile_menu.gd`, rather than having the opening menu push data in.
- Read-only: there is no claim/collect action, since `scripts/player_progress.gd` already grants the
  configured coin reward automatically when a goal is reached. Both the close and `Continue`
  buttons only dismiss the modal.

Key methods:
- `_apply_reward_progress(progress)`: writes the clamped `current/goal` values into the progress bar
  and label, the remaining-stars caption, and the hero image's reward badge.
- `_sync_illustration_corner_mask()`: updates the image shader with the illustration's actual
  runtime size and 16-pixel corner radius whenever container layout resizes it.

Depends on:
- `scenes/ui/reward_chest_menu.tscn` node names `%CloseButton`, `%ContinueButton`, `%ProgressBar`,
  `%Illustration`, `%AmountLabel`, `%GoalCaptionLabel`, and `%NextRewardLabel`.
- `PlayerProgress.get_reward_chest_progress()`.

Do not use for:
- Persisting reward stars, loading goal config, or awarding completion stars. Those stay in
  `scripts/player_progress.gd` and `configs/reward_chest_goals.json`.

## `scripts/profile_menu.gd`

Attached to:
- `scenes/ui/profile_menu.tscn` root `ProfileMenu`.

Purpose:
- Builds the player profile name editor and avatar picker.
- Loads the current player name into an editable field above the avatar section.
- Creates one avatar button for each id exposed by `PlayerProgress.get_available_avatar_ids()`.
- Keeps the pause-style menu panel responsive, with the avatar grid at three columns.
- Displays alpha-cleaned circular avatar PNGs in the top profile widget and picker.
- Emits `avatar_saved(avatar_id)` after the profile save succeeds so the main menu can refresh the avatar.

Key constants:
- `AVATAR_CLIP_SHADER`: defensive circular clip that keeps avatar edges consistent at runtime.
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
- Persistent save data ownership. Put that in `scripts/save/local_save_store.gd`; use
  `PlayerProgress` only as the gameplay facade.
- Puzzle runtime logic.

## `scripts/press_scale_button.gd`

Class:
- `PressScaleButton`

Attached to:
- `scenes/ui/level_button.tscn` root `LevelButton`.
- `scenes/ui/level_completion_screen.tscn` `NextButton`.
- `scenes/pause_menu.tscn` `PauseMenuPanel/InnerPanel/IconRow/*/*Button` settings icon buttons.
- `scenes/ui/settings_menu.tscn` `PauseMenuPanel/InnerPanel/IconRow/*/*Button` settings icon buttons.
- `scenes/pause_menu.tscn` `PauseMenuPanel/ButtonRow/LeaveButton` and `ContinueButton`.
- `scenes/leave_confirmation_menu.tscn` `ConfirmationPanel/ButtonRow/ConfirmLeaveButton` and `ContinueButton`.

Purpose:
- Provides the default held-press visual behavior for game UI buttons.
- Scales the button slightly smaller from its center on `button_down`, then restores its original scale on `button_up`, visibility changes, or exit from the scene tree.

Exports:
- `held_scale`: visual scale multiplier while the pointer or touch is held down, defaulting to `0.94`.

Use when:
- Adding future visible game UI buttons, including image buttons, icon toggles, and generated scene buttons that should visually press inward while held.

Do not use for:
- Text input controls, non-button puzzle item input, or invisible hit areas where scaling would move the perceived target without a visible button.

## `scripts/level_completion_screen.gd`

Class:
- `LevelCompletionScreen`

Attached to:
- `scenes/ui/level_completion_screen.tscn` root `LevelCompletionScreen`.

Purpose:
- Owns the completed-level reward overlay UI shown by `level.tscn` after all items clear.
- Applies responsive placement for the title, reward star, earned-star label, and `Next` button.
- Sizes the earned-star label for longer totals and emits `next_pressed` when the player taps `Next`.

Key methods:
- `apply_responsive_layout(safe_margins)`: fills the viewport and positions the screen contents with the same safe-area margins used by `scripts/level.gd`.
- `set_earned_stars(stars)`: updates the `xN` reward label and reduces font size when the value is long.

Depends on:
- `scenes/ui/level_completion_screen.tscn` child node names.
- `scripts/press_scale_button.gd` on `NextButton`.
- `assets/ui/reward_star.png` and `assets/ui/level_button_blank_new.png`.

Do not use for:
- Level progression or save data. Keep that in `scripts/level.gd` and `scripts/player_progress.gd`.

## `scripts/player_progress.gd`

Autoload:
- Registered as `PlayerProgress` in `project.godot`.

Purpose:
- Gameplay-facing facade over the active account-scoped local snapshot.
- Keeps scene APIs stable while delegating generations/journal, secure identity, account selection,
  and backend transport to focused owners under `scripts/save/`.
- Maps a BE-307 checkpoint into gameplay state and reapplies only local operations beyond its
  acknowledged device cursor.

Saved fields:
- `version`: gameplay snapshot schema version retained through legacy migration.
- `current_level`: next campaign level to play.
- `highest_completed_level`: highest campaign level completed.
- `lives`: current campaign lives, clamped from `0` to `5`.
- `next_life_restore_unix`: Unix timestamp for the next hourly life restore, or `0` when lives are full.
- `coins`: current gold coin balance. Fresh saves start at `300`.
- `ability_uses`: remaining campaign uses for hammer, shuffle, highlight/Lantern, and Freezer.
- `processed_shop_purchase_ids`: transaction ids whose Shop rewards were already applied locally.
- `avatar_id`: selected profile avatar id. Fresh and legacy saves default to `avatar_cat`.
- `player_name`: saved profile display name. Fresh and legacy saves without a valid value receive a generated `player_` name with a five-character random suffix, such as `player_g26f3`.
- `settings_disabled`: disabled-state map for `music`, `sound_effects`, and `vibration` settings buttons.
- `reward_chest_stars`: stars accumulated toward the active reward chest goal.
- `reward_chest_goal_index`: index into `configs/reward_chest_goals.json` for the active goal; the final configured goal repeats after it is reached.
- `reward_chest_completed_cycles`: completed goal count represented in recovery checkpoints.
- `total_earned_stars`: lifetime campaign stars; unlike chest stars, this value never rolls over or spends.
- `leaderboard_week_start_unix`: Monday 00:00 UTC boundary for the saved weekly counter.
- `weekly_earned_stars`: campaign stars earned since the saved weekly boundary.
- `last_weekly_rank_observation`: `{week_start_unix, rank}` for the best (lowest-numbered) Weekly
  rank `leaderboard_screen.gd` has reported this week via `record_weekly_leaderboard_rank()`. Cleared
  every rollover; see "Weekly rewards" in `docs/LEADERBOARDS.md` for why this is a local
  approximation rather than a backend-verified final standing.
- `moderation_state`: last server checkpoint's profile moderation state.

Key methods:
- `load_progress()`: opens/recover/migrates the active namespace and starts silent background sync.
- `save_progress()`: writes an atomic local generation without creating an operation.
- `get_current_level()`: returns the next campaign level.
- `get_ability_uses()`: returns remaining campaign ability uses.
- `get_coins()`: returns the saved gold coin balance.
- `get_total_earned_stars()`: returns the lifetime leaderboard score.
- `get_weekly_earned_stars()`: resets an expired weekly period when needed and returns the current weekly score.
- `get_current_leaderboard_week_start_unix()`: returns the current Monday 00:00 UTC boundary.
- `get_current_leaderboard_week_end_unix()`: returns the next Monday boundary used by the UI countdown.
- `spend_coins(amount, reason)`: atomically subtracts coins and appends a resource-spend operation.
- `apply_shop_purchase(transaction_id, rewards)`: development-mock/server-fact compatibility path;
  production grants must originate from a verified checkpoint.
- `record_weekly_leaderboard_rank(rank)`: records `rank` as this week's best-known standing if it
  improves on (or starts) the current week's observation. Called by `leaderboard_screen.gd` after
  every successful Weekly fetch.
- `consume_pending_leaderboard_reward()`: drains and returns the `{rank, coin_reward, week_start_unix}`
  granted by the most recent weekly rollover, or `{}` if none is pending. Consuming clears it.
- `get_leaderboard_reward_tiers()`: returns the configured `{min_rank, max_rank, coin_reward}` tiers
  from `configs/leaderboard_reward_tiers.json`, used both to grant rewards and to render the Shop-style
  "Weekly rewards" summary so the displayed promise can't drift from the payout.
- `get_reward_chest_progress()`: returns the saved reward chest stars, active goal, and goal index.
- `get_reward_chest_goal_at_index(goal_index)`: exposes a configured goal threshold for menu animation rollover.
- `consume_pending_reward_chest_animation()`: returns and clears the in-memory completed-level animation payload.
- `add_reward_chest_stars(star_count)`: adds stars to the reward chest and rolls over reached goals.
- `get_available_avatar_ids()`: returns the 18 valid profile avatar ids.
- `get_avatar_id()`: returns the selected avatar id, sanitized to `avatar_cat` when needed.
- `get_avatar_texture_path(avatar_id)`: returns the resource path for a valid or sanitized avatar id.
- `get_player_name()`: returns a non-empty saved or generated player name.
- `get_disabled_settings()`: returns saved disabled states for the settings buttons.
- `is_setting_disabled(setting_id)`: returns one saved settings-button disabled state.
- `set_setting_disabled(setting_id, is_disabled)`: validates, stores, and saves one settings-button disabled state.
- `set_avatar_id(avatar_id)`: validates, stores, and saves the selected profile avatar.
- `set_player_name(player_name)`: trims, stores, and saves a non-empty player name.
- `set_profile(avatar_id, player_name)`: validates and saves the avatar and player name together.
- `get_lives()`: refreshes and returns current campaign lives.
- `get_max_lives()`: returns the lives cap.
- `get_next_life_restore_seconds_remaining()`: returns seconds until the next life restore, or `0` when full.
- `refresh_lives()`: restores one life per elapsed real-time hour while lives are not full.
- `spend_life(level_number, outcome)`: atomically appends the attempt and resulting life state.
- `spend_ability(ability_id)`: validates one of the four canonical ability ids, then immediately
  spends, journals, and saves one campaign ability use.
- `complete_level(level_number, earned_stars)`: atomically records completion, advancement,
  lifetime/weekly/chest totals, immediate chest coins, and reward-animation metadata; returns false
  before result UI if persistence fails.
- `bind_registered_guest()`, `switch_to_player()`, and `sign_out()`: activate account-scoped
  namespaces without deleting inactive journals.
- `get_local_save_diagnostics()`: returns non-secret namespace/recovery/support state.
- `reset_progress()`: restores default progress and writes it to disk for testing.
- `get_save_provider_name()`: returns `local_first_v2`.
- `get_backend_transport()`: GAME-007, returns the configured `BackendTransport` shared by backend
  read features outside the focused save services (catalog, leaderboards, purchase status, device
  list); wired once here to the existing `SecureSessionStore` and active player id.

Depends on:
- `scripts/save/*.gd`
- `scripts/backend/backend_transport.gd`
- `configs/reward_chest_goals.json`

Do not use for:
- Per-level shelf state, timer state, or dev/test level runtime state.

## `scripts/save/local_save_codec.gd`

Class:
- `LocalSaveCodec`

Purpose:
- Canonical protocol JSON with recursively sorted object keys.
- SHA-256, UUID, timestamp, opaque-id, and namespace helpers shared by persistence and sync.

## `scripts/save/local_save_store.gd`

Class:
- `LocalSaveStore`

Purpose:
- Validates the four-part `sorting-puzzle-local-save/1` container.
- Appends signed, hash-chained operations in the same generation as snapshot changes.
- Flushes/validates/promotes `pending.tmp`, retains `previous.json`, and recovers the newest valid
  generation.
- Applies checkpoint/cursor transactions, compacts acknowledged history, and migrates schema 4.

## `scripts/save/secure_session_store.gd`

Class:
- `SecureSessionStore`

Purpose:
- Persists public installation/device UUIDs outside account saves.
- Delegates P-256 signing and player sessions to `SortingPuzzleSecureStoreBridge`.
- Refuses mobile synchronization without secure native storage; desktop signatures are
  development-only crash-test markers.
- Calls bridge methods directly rather than gating on `Object.has_method()`: GAME-004 found that
  `has_method()` returns `false` on a real Android device for this native plugin singleton even
  though the methods work correctly, which was silently disabling `can_synchronize()` and every
  installation-key/session call. A `null`/failed bridge result is now treated as an error instead.

## `scripts/save/local_backend_debug_bootstrap.gd`

Autoload:
- Registered as `LocalBackendDebugBootstrap` in `project.godot`, first in the autoload list so it
  runs before `PlayerProgress`/`SaveSyncService` read backend settings.

Purpose:
- GAME-003 local-only configuration path: in debug builds only, reads the gitignored
  `res://local/backend_debug.cfg` and overrides `application/config/backend_base_url` and
  `application/config/save_sync_v2_enabled` for that run without touching the committed
  `project.godot` defaults.
- `parse_override(config)` is a pure static validator (base_url must be `http://`/`https://`,
  `sync_enabled` must be boolean) covered by
  `tests/save/test_local_backend_debug_bootstrap.gd`.
- On a valid override, logs one non-secret `[LocalBackendDebug]` diagnostic line and fires a
  best-effort `/health/live` HTTPRequest, then logs the result plus whether
  `SortingPuzzleSecureStoreBridge` is available -- never tokens, signatures, or key material.
- GAME-004: also starts a 3-second periodic timer that logs `PlayerProgress
  .get_local_save_diagnostics()` as one `identity diagnostics:` line (namespace kind, opaque
  player/device ids, generation, guest-registration phase/retry/terminal-error, save-sync
  retry/terminal-error, server `correlation_id`, and the `sync_gate` precondition booleans) so an
  emulator smoke check can prove real guest bootstrap and restart resumption via `adb logcat`
  alone, again without ever exposing tokens, signatures, or key material.

Do not use for:
- Anything that should affect a release export; a missing file or a non-debug build is always a
  no-op.

## `scripts/save/account_save_coordinator.gd`

Class:
- `AccountSaveCoordinator`

Purpose:
- Bootstraps installation guest progress and rebinds it exactly once after registration.
- Switches player A/B and signed-out guest namespaces without leaking or deleting snapshots,
  profiles, balances, sessions, or unsynchronized journals.

## `scripts/save/guest_session_bootstrap_service.gd`

Class:
- `GuestSessionBootstrapService`

Purpose:
- Owns the feature-gated protocol-1.1 guest challenge and bootstrap HTTP flow.
- Requires valid bundled content provenance before issuing network requests.
- Persists exact challenge/bootstrap retry payloads, signs the ordered
  `guest-registration-proof/1` payload through the native bridge, validates the returned
  player/device/session binding, and hands the transition to `AccountSaveCoordinator`.
- GAME-004: records the server's `meta.correlation_id` and stable error code from every parsed
  response (`sync.guest_registration.terminal_error.correlation_id`,
  `sync.identity_diagnostics`), and rejects device-binding-mismatched or expired-challenge
  responses without ever binding a foreign device/player. Covered end to end (not just via private
  helpers) by `tests/save/test_game_004.gd`.

## `scripts/save/save_sync_service.gd`

Class:
- `SaveSyncService`

Purpose:
- Owns feature-gated `POST /v2/saves/sync` and recovery `GET /v2/saves/state`.
- Emits additive protocol v2.1 save envelopes so `resource_spend.asset = freezer` and the fourth
  checkpoint ability are preserved. It accepts supported v2.0 responses during rollout; a v2.0
  checkpoint with no Freezer field preserves the local schema-5 Freezer balance before replaying
  unacknowledged operations.
- Requires valid bundled content provenance before issuing network requests.
- Caps batches at 500 operations/1 MiB and persists exact payload/idempotency values before send.
- Owns timeout, full-jitter/`Retry-After`, session-refresh hooks, cursor conflict recovery, response
  validation, checkpoint reconciliation, continuation, and silent batching.
- GAME-004: records the server's `meta.correlation_id` (`sync.last_correlation_id`) from every
  parsed response, and the single-refresh-attempt guard, malformed/replayed
  (`auth.refresh_reuse_detected`)/binding-mismatched refresh-response handling are covered end to
  end by `tests/save/test_game_004.gd`.
- GAME-005: `_apply_response()`/`_apply_state_response()` were verified against a real
  protocol-v2 API and PostgreSQL instance (empty sync, all five signed operation types, atomic
  checkpoint/cursor application, two-request multi-batch continuation, idempotent replay, and a
  stale-cursor conflict) by
  `scripts/tools/local_backend_save_sync_integration_check.mjs`, and against the exact response
  bodies it captured by `tests/save/test_game_005.gd`
  (`tests/fixtures/save_sync_v2/*.json`). That gap-testing found and fixed two real defects in
  `scripts/save/local_save_codec.gd`: `iso_timestamp()` used `Time.get_datetime_string_from_unix_time`'s
  `use_space` argument backwards, emitting a space instead of the required ISO-8601 `T` separator
  in every `meta.client_time`/`occurred_at`/`observed_at` value this client has ever sent (the live
  backend confirmed this is rejected outright: `400 request.invalid` /
  `request.schema.pattern`), and `is_timestamp()` only checked string length and a literal
  `.000Z` suffix, so it never caught the malformed format and additionally rejected any
  genuine non-`.000` millisecond value a real backend or another platform's clock could produce.

## `scripts/save/content_provenance_manifest.gd`

Class:
- `ContentProvenanceManifest`

Purpose:
- Loads the generated GAME-002 manifest from `configs/backend/content_provenance.json`.
- Validates its closed schema, canonical digest, content-addressed configuration identity,
  complete levels 1-8 mapping, and explicit levels 9-10 exclusion at runtime.
- Does not require raw authored `.gd`/`.tscn` files at runtime because Godot export templates
  compile/remap them. `load_manifest_with_source_verification()` is reserved for pre-export
  tooling and tests, where it validates every pinned source-file hash.
- Returns exact immutable campaign provenance to `PlayerProgress` without constructing fallback
  protocol identifiers.
- Exposes only bounded non-secret diagnostics when invalid; the caller keeps local play available
  and disables network synchronization.

## `scripts/tools/check_content_provenance.gd`

Purpose:
- Headless pre-export check for missing, stale, incomplete, or digest-mismatched provenance.
- Explicitly enables raw-source verification while the authored project tree is available.
- Exits unsuccessfully before export when the packaged campaign sources differ from the backend
  publication.

## `scripts/tools/android_local_backend_smoke_check.ps1`

Purpose:
- GAME-003 emulator smoke check: waits for an adb device, sets up `adb reverse tcp:8080 tcp:8080`,
  installs/launches the debug APK, and tails `adb logcat` for the `[LocalBackendDebug]` lines from
  `scripts/save/local_backend_debug_bootstrap.gd`.
- Resolves adb from `-AdbPath`, PATH, `ANDROID_SDK_ROOT`, `ANDROID_HOME`, or the standard Windows
  user SDK location.
- Accepts `-DeviceSerial` when multiple devices are connected and `-HostPort` when emulator
  tcp:8080 should reverse to a different host API port.

## `scripts/tools/run_android_local_development.ps1`

Purpose:
- Daily one-command Windows launcher used by `run_android_local_development.cmd`.
- Starts or reuses the `sorting-puzzle-api36` AVD, starts the persistent PostgreSQL Compose
  service, validates or creates the complete persistent ignored secret set, runs the idempotent
  backend development bootstrap, and reuses a healthy Sorting Puzzle API or starts one.
- Rebuilds the Android secure-store debug AAR, writes the ignored debug-only backend override,
  exports the configured Android debug APK, and delegates targeted install/launch verification to
  `android_local_backend_smoke_check.ps1`.
- Preserves emulator app data, the `sorting_puzzle` database, and local secrets across launches.
  It leaves the emulator, database container, and API running after completion.
- Fails instead of overwriting partial secrets, using a mismatched secret/database pair, reusing an
  unrelated listener, selecting the wrong AVD, or exporting with an incompatible Godot/Node
  version.

Parameters:
- `-AvdName`, `-GodotPath`, `-BackendPath`, and `-ApiPort` override workstation paths/routing.
- `-SkipInstall` and `-SkipPluginBuild` shorten repeat runs only when those outputs are current.
- `-EmulatorTimeoutSeconds` and `-BackendTimeoutSeconds` control readiness waits.

## `run_android_local_development.cmd`

Purpose:
- Double-click entry point for the PowerShell daily-development launcher.
- Keeps the console open on failure so the actionable phase error remains visible; closes after a
  successful launch while the emulator/backend continue running.

## `scripts/tools/redeploy_android_game.ps1`

Purpose:
- Fast game-only Android iteration path used after the full local-development workflow is already
  running.
- Requires the named AVD, persistent backend API, ignored debug config, Android build template, and
  secure-store debug AAR to exist and be ready; it does not start or rebuild any of them.
- Runs the authored-source content-provenance gate before exporting so level/config changes that
  require a backend republication fail instead of producing a stale network-enabled APK.
- Exports the Android debug preset, refreshes `adb reverse` with bounded retries for transient ADB
  transport/rebind failures, force-stops the installed game, installs the APK with
  `adb install -r`, relaunches it, and waits for the Android process. A terminal reverse failure
  reports the selected serial, exit code, and ADB diagnostic text.
- Preserves Android app data and therefore the existing installation identity, secure session, and
  local save.

Parameters:
- `-AvdName`, `-GodotPath`, `-ApiPort`, and `-PackageName` override workstation/target defaults.
- `-LaunchTimeoutSeconds` controls the final process-start wait.

## `redeploy_android_game.cmd`

Purpose:
- Double-click entry point for the fast game-only redeploy script.
- Keeps the console open on failure and closes after the updated game is running.

## `scripts/tools/android_local_backend_identity_smoke_check.ps1`

Purpose:
- GAME-004 emulator smoke check: builds on the GAME-003 connectivity/bridge check and additionally
  waits for the `identity diagnostics:` logcat line to show `namespace_kind=player` with a real
  `player_id` (proving guest bootstrap), then force-stops and relaunches the app and confirms the
  same `player_id`/`device_id` are observed again (proving restart resumption without a second
  guest).
- As of 2026-07-24 this could not be driven to a passing end because of an emulator/`HTTPRequest`
  POST reliability issue documented in the GAME-004 ticket entry; it remains the intended
  automation once that is resolved.
- Exits `0` only once a local override, `/health/live` HTTP 200, and
  `secure_bridge_available=true` are all observed in logcat, or `1` after a timeout.
- Fails immediately if Android runtime logs show `PlayerProgress` rejected the packaged GAME-002
  content manifest.
- Covers only the Android-side half of the local-backend flow; does not start the backend itself
  or provision PostgreSQL/the API (`GAME-010`).
- GAME-010 can pass `-ClearAppData` for a clean installation namespace and `-ResultPath` to write
  only the opaque player/device IDs and non-secret diagnostics required by backend persistence
  assertions.

## `scripts/tools/local_backend_save_sync_integration_check.mjs`

Purpose:
- GAME-005/GAME-011 live-backend proof: a standalone Node.js script (no Godot runtime involved) that
  performs genuine HTTP calls against a running local backend with a real generated P-256
  installation key -- real guest challenge/bootstrap, real signed `campaign_completion` /
  `campaign_attempt` / `resource_spend` / `life_state` / `profile_edit` operations, empty sync,
  idempotent replay, two-request multi-batch continuation past the 500-operation limit, and a
  stale-cursor conflict -- against the real protocol-v2 API and PostgreSQL.
- Save requests now select additive protocol v2.1 and include a signed Freezer spend plus a
  fourth-ability checkpoint assertion. The checked-out sibling backend still advertises v2.0, so
  this live branch remains a release dependency until its Freezer contract/catalog publication
  lands; the Godot client continues to accept supported v2.0 responses.
- Reads campaign-level provenance from `configs/backend/content_provenance.json` so
  `campaign_completion`/`campaign_attempt` payloads reference the currently-published development
  configuration.
- Run with `node scripts/tools/local_backend_save_sync_integration_check.mjs` against a backend
  started per `../../sorting-puzzle-backend/docs/LOCAL_DEVELOPMENT.md`
  (`pnpm db:up && pnpm bootstrap:local && pnpm generate:local-secrets && pnpm dev:api`). Optional
  `--base-url` and `--dump-fixtures <dir>` flags; the latter captures every real request/response
  body used to produce `tests/fixtures/save_sync_v2/*.json`.
- Complements the Android-only smoke checks above: proves the server/database half of protocol-v2
  save synchronization directly, independent of the emulator `HTTPRequest` POST reliability issue
  that still blocks a real on-device proof (see the GAME-004/GAME-005 ticket entries).
- GAME-010 adds `--completion-stars`, `--result-file`, and `--redacted-output`. The result file
  contains opaque fixture IDs, cursor/checkpoint facts, and content versions but no session or
  bearer/refresh credentials; redacted output suppresses session IDs and response bodies.

## `scripts/tools/run_local_backend_integration_gate.ps1`

Purpose:
- GAME-010's one-command L4 gate. Starts PostgreSQL, recreates only
  `sorting_puzzle_game010`, migrates/bootstraps development data, generates ignored disposable
  secrets, runs the v1/v1.1/v2 Godot contract manifests, builds/starts/waits for the API, exports
  the Android debug APK, configures `adb reverse` through the identity smoke script, installs the
  APK, clears this package's app data, and proves identity/session resumption.
- Runs two real signed save scenarios with distinct completion scores, invokes the backend worker,
  and asks the backend assertion command to verify player/device/session, cursor/checkpoint,
  checkpoint outbox/consumption, active development catalog, and deterministic leaderboard rows.
- Restores any existing local debug config and defaults to bounded disposable cleanup. Every phase
  and terminal failure carries a stable error code plus one run correlation ID. Detailed logs live
  under ignored `build/game010/`.
- Refuses to start on an occupied API port. `-ApiPort` selects another host port while Android
  continues to use `127.0.0.1:8080` through an adjusted `adb reverse` mapping.

## `tests/backend/test_game_010.gd`

Purpose:
- Godot fixture runner for every document named by the authoritative sibling backend's protocol v1
  `1.0.0`, v1.1 `1.1.6`, and v2 `save-sync-fixtures/1` manifests.
- Round-trips each object through Godot JSON and additionally checks protocol-v2 batch bounds,
  operation format, contiguous device sequence, and previous-operation hash chaining.

## `scripts/backend/backend_transport.gd`

Class:
- `BackendTransport`

Purpose:
- GAME-007 shared authenticated read transport for bodyless authenticated v1 `GET` reads used by
  backend features outside the focused save services (`scripts/save/*`).
- `configure(session_store, active_player_id_provider)` wires an existing `SecureSessionStore` and
  a `Callable` that resolves the current active player id; `PlayerProgress` is the only configured
  owner today (`get_backend_transport()`).
- `get_json(path)` issues one bodyless `GET` at `path` (e.g. `/v1/catalog`) with an
  `Authorization: Bearer` header and a client-generated `X-Correlation-ID`, never an invented
  request body or protocol/app header. Returns `{"ok": true, "data", "meta"}` or
  `{"ok": false, "error": {"code", "category", "message", "retryable", "retry_after_seconds",
  "correlation_id", "http_status"}}`.
- Retries network failures, `429` (honoring `Retry-After` over backoff), and `502`/`503`/`504` up
  to one initial try plus four retries within a 30-second wall-clock budget, matching the backend's
  documented client read retry policy; every other status (`400`/`403`/`404`/`409`/`413`/`415`/
  `426`/`500`, or a malformed envelope) is terminal and never auto-retried.
- Attempts exactly one refresh-and-replay on `401` via `POST /v1/sessions/refresh`, storing the
  refreshed session back through `SecureSessionStore.store_session()`; a second `401` after that
  refresh, a transport failure during refresh, or a malformed/mismatched refresh response are all
  terminal (`auth.*` codes), never retried, mirroring `save_sync_service.gd`'s single-refresh-guard
  reasoning without sharing its persisted mutation-retry state.
- `_send_get`/`_send_post`/`_wait_before_retry` are the only network/timing seams; test doubles
  override them to avoid a real socket or a real delay, the same pattern
  `tests/save/test_game_006.gd` uses for `SaveSyncService`.

Depends on:
- `scripts/save/secure_session_store.gd` for bearer tokens and refresh storage (duck-typed, not a
  static dependency).
- `scripts/save/local_save_codec.gd` for UUID generation and timestamp validation.

Do not use for:
- `POST`/mutation traffic, save-sync idempotency/retry, or guest bootstrap. Those stay in
  `scripts/save/save_sync_service.gd` and `scripts/save/guest_session_bootstrap_service.gd`.

## `scripts/backend/backend_read_operations.gd`

Class:
- `BackendReadOperations`

Purpose:
- GAME-007 closed protocol adapters for the five bodyless authenticated v1 `GET` reads: player
  state, player devices, catalog, one purchase by transaction id, and one leaderboard scope.
- Static `*_path()` builders return the exact request path (including any query string) for
  `BackendTransport.get_json()`; they never invent a request body or protocol/app headers.
- Static `parse_*(data)` functions validate every required field's Godot `Variant` type against the
  backend's `packages/protocol/schemas/v1/protocol.schema.json` definitions, read only the specific
  keys they expose (so additive response fields are ignored by construction), and map unrecognized
  enum values (`account_kind`, `moderation_state`, `avatar_id`, device `platform`, offer `type`/
  `limit_period`, purchase `status`, grant `source`, leaderboard `scope`) to `"unknown"`.
- `parse_purchase()` optionally parses a nested `restriction` and a nested `state` (the same
  `PlayerState` shape as `parse_player_state()`) when the server includes them.

Depends on:
- `scripts/save/local_save_codec.gd` for UUID/opaque-id/timestamp format validation.

Do not use for:
- Issuing HTTP requests (`scripts/backend/backend_transport.gd` owns that), UI presentation, or
  offline caching -- those belong to the catalog (`GAME-008`) and leaderboard (`GAME-009`)
  providers that will consume these adapters.

## `scripts/save_providers/*.gd`

Purpose:
- Legacy provider adapters retained only as migration/test inputs.
- Not used by `PlayerProgress` or release persistence after GAME-001.

Depends on:
- `docs/CLOUD_SAVE.md` for release setup details.

## `scripts/ability_bar.gd`

Class:
- `AbilityBar`

Attached to:
- `scenes/ui/ability_bar.tscn`.

Purpose:
- Owns the four-button visual hierarchy, per-ability remaining-use badges, Lantern/Freezer active
  countdown badges, button enablement, icon lookup, responsive touch-target sizing, and the
  `ability_pressed(ability_id)` signal.
- Keeps gameplay preflight, persistence, purchase, and effect execution out of the UI component.

Key methods:
- `set_uses(ability_uses)`.
- `set_interaction_blocked(is_blocked, freezer_active)`.
- `set_active_seconds(ability_id, seconds_remaining)`.
- `get_icon_texture(ability_id)`.
- `get_ability_button(ability_id)`.
- `apply_responsive_layout(viewport_width)`.

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
- `highlight_outline_width`: screen-pixel thickness of the item outline border, kept even around the item silhouette by the outline shader's dilation.
- `highlight_item_scale`: scale multiplier applied to a highlighted item's sprite and outline so it visually stands out.
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
- `HUD_*`, `ABILITY_BAR_*`, `SHELVES_*`, `RESULT_LABEL_HEIGHT`, `PAUSE_MENU_PANEL_SIZE`, `LEAVE_CONFIRM_PANEL_SIZE`, and `ABILITY_PURCHASE_PANEL_SIZE`: responsive layout constants for positioning the HUD, ability bar, result overlays, pause panel, leave confirmation panel, ability purchase panel, and generated shelf root across portrait viewport sizes, including minimum and maximum shelf layout scale.
- `SHELF_SCENE`: `res://scenes/shelf.tscn`.
- `MOVING_SHELF_ROW_SCENE`: `res://scenes/moving_shelf_row.tscn`.
- `ITEM_SCENE`: `res://scenes/item.tscn`.
- `ITEM_SPRITES_CONFIG`: `res://configs/item_sprites.json`.
- `ABILITY_PURCHASE_PRICES_CONFIG`: `res://configs/ability_purchase_prices.json`.
- `LEVEL_CONFIG_TEMPLATE`: `res://configs/levels/level_%03d.json`.
- `DEFAULT_LEVEL_CONFIG`: fallback level config.
- `LAYOUT_SCENE_TEMPLATE`: `res://scenes/layouts/layout_%s.tscn` path pattern used by `layout_preset`.
- `DEFAULT_LAYOUT_PRESET`: fallback layout preset.
- `MAIN_MENU_SCENE`: default scene returned to after completion.
- `LEVEL_SCENE_PATH`: scene loaded when the completion `Next` button advances normal campaign play to the next level.
- `ITEM_PLACE_SOUND`: short sound played when the player drops or moves an item into a shelf slot.
- `TRIPLE_CLEAR_SOUND`: sound played when a matched triple gathers and disappears.
- `HAMMER_IMPACT_EFFECT_SCENE`: `res://scenes/abilities/hammer_impact_effect.tscn`, spawned when the hammer ability is used.
- `SHUFFLE_BOX_TEXTURE`: `res://assets/abilities/ability_shuffle_box.png`, shown at screen center while the shuffle ability gathers and redistributes items.

Key responsibilities:
- Apply responsive layout with `_apply_responsive_layout()`, including safe-area-aware top HUD placement, ability bar placement over the floor/baseboard transition strip, full-screen overlays, centered pause and leave-confirmation popups, shelf-root scaling, and shelf-root centering between HUD and ability controls.
- Resize the scene-owned `Background` control so its procedural top strip, shop wall, baseboard, and floor bands fill the active viewport.
- Load JSON configs with `_load_json_file()`.
- Instantiate reusable shelf cells with `_add_shelf()`, apply the shared shelf visual scale, assign left/middle/right row placement visuals for static shelves, and ask `Shelf` to add generated back layers.
- Ask each shelf scene to show or hide its placement-specific `TopCeilingCap` when it has no stacked neighbor above. Show each shelf scene's bottom `Shadow` and `RightColumnShadow` whenever the shelf uses full visuals so neighboring shelf bodies and items cover those low-layer cast shadows while exposed wall/background areas still receive them.
- Load `layout_preset` scene templates from `scenes/layouts/`, group authored `ShelfXX` markers into rows by position, and place runtime shelves with derived row-placement visuals.
- Build optional `row_layouts` rows with `_add_row_layout_shelves()`, including horizontal or vertical moving rows and static rows mixed in one level. Moving-row shelves currently use the neutral middle row-placement visual, and moving rows in a level must all use the same axis.
- Build moving rows declared by layout template `MovingRowXX` nodes with `scripts/shelf_layout_row.gd`; their shelves also use the neutral middle row-placement visual.
- Keep moving-row shelves out of drag/drop targeting while they are outside the row's visible window, while abilities still use unlocked shelf items.
- Spawn configured items with `_add_configured_item()`.
- Handle mouse and touch input through `_input()` and the press/motion/release helpers.
- Move items with `_move_item_to_slot()`, `_resolve_move_target_slot()`, `_play_item_move_animation()`, and `_place_item_in_slot()`.
- Hide the active item's contact shadow while the player is dragging it, then restore the shadow when the drag releases, cancels, fails, or completes.
- Redirect moves aimed at an occupied destination slot on another shelf to the nearest free front slot on that destination shelf; same-shelf occupied targets leave the item in its original slot.
- Clear triples with `_clear_matching_shelves()` and `_play_match_clear_animation()`.
- Track the active triple-clear combo with `_extend_combo()`, `_update_combo_timer()`, `_reset_combo()`, and `_update_combo_hud()`, including the shrinking center-slot fill. Combo value increases by 1 per cleared triple, and each cleared triple adds stars equal to the combo value reached by that triple; `_update_star_counter_label()` writes that number into `UI/StarCounterLabel/CountLabel` beside the shared reward star icon.
- Show combo praise words with `_show_combo_praise()` starting at 2x combo, using unique wording through 20x. Labels appear near the cleared triple or hammer impact for two seconds, then fade out; lower combos use thinner calmer outlines, while 10x+ combos use larger gold, violet, and red outlines.
- Play combo reward feedback with `_play_combo_star_reward_animation()`: after the matched items finish `_play_match_clear_animation()`, small `reward_star_34_glossy_b.png` stars drop from the cleared triple, fly into `UI/StarCounterLabel`, and pulse the counter. The number of visual stars matches the combo-earned star amount returned by `_record_triples_cleared()`.
- Track cleared triples and locked shelf accessibility with `_record_triples_cleared()`, `_update_locked_shelves()`, and shelf metadata from `unlock_after_triples`.
- Toggle each shelf scene's lock overlay with the remaining triple count, fit that count to the lock art's center panel, and keep locked shelves out of move, match, promotion, and ability targeting.
- Play placement and triple-clear sound effects with runtime `AudioStreamPlayer` nodes.
- Track clearing items so only disappearing items ignore input and abilities during the animation.
- Track transitioning items so newly promoted back-layer items ignore input and abilities until their forward slide finishes.
- Queue shelf resolution requests made while another match animation is still finishing.
- Promote back layers with `_promote_back_layer()`, `_play_layer_promotion_animation()`, and `_advance_back_layers()`.
- Check win/loss state with `_check_level_completed()`, `_fail_level()`, and `_complete_level()`.
- Spend one campaign life on campaign failure and on confirmed pause-menu Leave through `_spend_campaign_life_for_run()`, guarded so one level run cannot spend twice.
- Save campaign completion through `PlayerProgress`, show `UI/CompletionScreen` with the run's earned star count, and return to the main menu when the completion `Next` button is pressed.
- Return to the configured menu scene when leaving a level or when the dev/test completion `Next` button is pressed.
- Keep the level countdown idle until the first meaningful player action, then format the active timer as zero-padded `MM:SS` text with `_update_timer_label()`.
- Pause and resume active gameplay through the top-right menu button, the instanced `UI/PauseMenuOverlay`, `UI/LeaveConfirmationOverlay`, `Leave`, `Continue`, and red close buttons.
- Initialize item placement and triple-clear sound effects from the shared sound-effects setting and keep them disabled while that toggle is crossed out.
- Manage Hammer, Shuffle, Lantern/highlight, and Freezer abilities. Campaign levels read and
  spend saved ability counts through `PlayerProgress`; dev/test levels use isolated temporary
  counts.
- Keep zero-use ability buttons pressable during active gameplay so `_open_ability_purchase_menu()` can pause the level and show `UI/AbilityPurchaseOverlay` with the tapped ability icon, configured coin price, and current affordability state.
- Apply paid ability uses through `_can_apply_ability()`, `PlayerProgress.spend_coins()`, and
  `_apply_paid_ability()`: the local spend commits after successful preflight and before the
  gameplay effect starts, without adding saved ability inventory.
- Hammer targets visible/front triples first, then can supplement visible/front matches with first-back-layer copies of the same item type when no visible item type has three available copies.
- Hammer now gathers the chosen three targets into one item at the screen center, plays a fullscreen impact animation there, destroys the merged item on the effect's `impact` signal, and then drops combo reward stars from the impact point.
- Shuffle now pauses moving shelf rows, shows the center-screen delivery box, flies visible unlocked items into the box, changes unlocked item identity assignments while they are hidden, flies them back to their original slots, and resolves shelves only after the return animation completes.
- Count hammer destroys as cleared triples for shelf unlocking.
- Let highlight uses start their timed window even when no immediate triple can currently be highlighted.
- Find items to highlight with `_find_immediate_triple_items()`: prefer a shelf that is one item away from a full match plus a loose match elsewhere (single-move triple), otherwise fall back to any visible items sharing a type. Only one item type is ever highlighted at a time even when several types qualify, but every visible item of that chosen type is highlighted, not just three.
- After every move, `_refresh_ability_highlights()` calls `_find_current_highlight_type_items()` first so the highlighted item type stays put as long as it still has enough visible matches; it only calls `_find_immediate_triple_items()` for a new type once the current one can no longer complete a triple. This stops the highlight from jumping to an unrelated item type after an unconnected move.
- Apply highlight ability visuals through `ShelfItem.set_outline()` and `ShelfItem.set_highlight_scale()` so highlighted items get an even border and a slightly larger sprite, and update the highlight button countdown label while that window is active.
- Activate Freezer for exactly 30 seconds of active gameplay. Only `_time_remaining` is gated;
  item interaction, combo expiry, Lantern expiry, moving shelf rows, animations, matching, and
  other abilities continue. Pause menus, the ability-purchase modal, and application interruption
  suspend only the Freezer window. A partial expiry delta suppresses only its frozen portion.
- Treat Freezer activation before the first move as the first meaningful action, disable only its
  button while active, and clear runtime state/visuals on level load, completion, failure, leave,
  application scene teardown, or a new level configuration.

Depends on:
- `level.tscn` node names and paths.
- `scenes/shelf.tscn` slot names and item snap marker names.
- `scripts/shelf.gd` for generated back-layer preview setup.
- `scenes/shelf.tscn` `LockedOverlay/RemainingLabel` for locked shelf progress display on the lock image.
- `scenes/moving_shelf_row.tscn` for optional row-layout movement and clipping.
- `scenes/layouts/layout_*.tscn` for named layout preset placement.
- `scenes/pause_menu.tscn` button node names used under `UI/PauseMenuOverlay`.
- `scenes/ui/level_completion_screen.tscn` for completed-level reward UI and its `next_pressed` signal.
- `scenes/item.tscn` and `ShelfItem`.
- `assets/audio/item_place.wav` and `assets/audio/triple_clear.wav`.
- `configs/item_sprites.json` item IDs and texture paths.
- `configs/ability_purchase_prices.json` paid-use prices for zero-use ability purchases.
- `configs/levels/level_*.json` shelf schema.
- `PlayerProgress` autoload for campaign progress, lives, coin spending, and ability inventory.
- `scenes/leave_confirmation_menu.tscn` button and star-count node names used under `UI/LeaveConfirmationOverlay`.
- `scenes/ability_purchase_menu.tscn` button, icon, and price node names used under `UI/AbilityPurchaseOverlay`.
- `scenes/ui/ability_bar.tscn` for button visuals, use badges, and timed badges.

Do not use for:
- Offline level generation or solvability search. Keep that in `scripts/tools/`.
- Save data ownership. Keep that in `scripts/save/local_save_store.gd`; route gameplay access
  through `PlayerProgress`.

## `scripts/hammer_impact_effect.gd`

Class:
- `HammerImpactEffect`

Attached to:
- `scenes/abilities/hammer_impact_effect.tscn` root `HammerImpactEffect`.

Purpose:
- Thin runtime controller for the hammer ability's fullscreen visual strike.
- Positions and scales the scene over a provided screen-space target point, plays the scene-owned `AnimationPlayer` `strike` timeline, and draws a short procedural burst based on the animated burst amount.
- Emits `impact` on the visual hit frame and `finished` after the hammer fades out.

Exports:
- `base_hammer_scale`: base visual size before responsive viewport scaling.

Depends on:
- `assets/abilities/ability_hammer_swing_*.png` for the four pseudo-3D angle frames.
- `scenes/abilities/hammer_impact_effect.tscn` `AnimationPlayer` keyframes for hammer motion, opacity, texture swaps, burst amount, and signal callbacks.
- `scripts/level.gd` for runtime instancing and gameplay response to `impact`.

Do not use for:
- Ability inventory, target selection, item deletion, score/star rules, or shelf resolution.

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
- `motion_type`: `horizontal_wrap` or `vertical_wrap`.
- `speed_pixels_per_second`: row motion speed.
- `direction`: `right` or `left` for horizontal motion, `down` or `up` for vertical motion.
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
- Clips a moving shelf group to a visible window.
- Moves child shelves horizontally or vertically and wraps them when they pass the row bounds.
- Reports whether a shelf center is inside the visible window for drag/drop targeting.

Exports:
- `visible_shelf_count`: number of shelf positions in the clipped row window.
- `shelf_cell_size`: shelf cell bounds supplied by `scripts/level.gd`.
- `shelf_step`: packed shelf spacing supplied by `scripts/level.gd`.
- `motion_type`: `horizontal_wrap` or `vertical_wrap`.
- `speed_pixels_per_second`: row motion speed.
- `direction`: `1` for rightward or downward motion, `-1` for leftward or upward motion.

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
- Owns shared settings-button visual state, initialized from and saved through `PlayerProgress`.
- Toggles a crossed-out overlay on the music, sound effects, and vibration square icon buttons when clicked.
- Emits `setting_toggled(setting_id, is_disabled)` so owning runtime scripts can apply supported settings.
- Also powers the matching visual toggles in the main-menu settings popup, which intentionally keeps the same `PauseMenuPanel/InnerPanel/IconRow` button paths.
- Initializes every pause-menu and main-menu settings instance from the saved disabled-state dictionary so matching buttons stay visually synchronized after game restarts.

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
- `outline_width`: desired on-screen outline thickness in pixels; converted to a source-texture texel radius for the outline shader so thickness stays constant regardless of the item's current scale.
- `outline_alpha_threshold`: alpha cutoff used to detect the item silhouette.

Key methods:
- `_ready()`: applies current texture and scale.
- `_apply_texture()`: updates `Sprite2D.texture` and hides the soft contact shadow when the item has no texture.
- `_apply_visual_scale()`: updates `Sprite2D`, `OutlineSprite`, and contact-shadow scale from `visual_scale * highlight scale multiplier`, then refreshes the outline.
- `set_outline(enabled, color, width)`: enables or disables the sprite border highlight.
- `set_highlight_scale(multiplier)`: scales the sprite and outline up (without changing the persistent `visual_scale`) while an item is highlighted by the Lantern ability.
- `set_contact_shadow_enabled(enabled)`: toggles the item contact shadow while still respecting texture availability; used by back-layer previews and active player dragging.
- `_apply_outline()`: sends outline color/threshold and the computed dilation radius to the `OutlineSprite` shader material, and keeps the outline node visible only while enabled. The `OutlineSprite` shader dilates the alpha mask by sampling a ring of points around each pixel (in source-texture texels) rather than scaling the whole sprite up, so the border thickness stays even around irregular silhouettes.

Depends on:
- Child node `Sprite2D`.
- Child node `OutlineSprite`.
- Child node `Shadow`.
- `scenes/item.tscn` outline `ShaderMaterial`.

Do not use for:
- Input ownership, matching rules, abilities, or shelf promotion.

## `scripts/tools/generate_level_shelves.py`

Purpose:
- Generates abstract level-template `shelves` arrays or complete template JSON from CLI arguments.
- Uses logical `item_NN` identities and never reads the item-art catalog.

Key inputs:
- Shelf count, layer count, filled layer count, difficulty, seed, layout preset, optional explicit
  `--item-type-count`, and optional solvability requirements.
- When `--item-type-count` is omitted, the generator infers it as
  `ceil(target_filled_slots / preferred_copies_per_type)`. `--preferred-copies-per-type` accepts
  fractional values of at least `3` and defaults to `6`; an explicit type count takes precedence.
- Layout preset values mirror the runtime layout template names in `scenes/layouts/`, including fixed-count staggered presets for 14-shelf `staggered_5_4_5`, 13-shelf `staggered_4_5_4`, and 14-shelf `grid_3x3_moving_5_bottom` layouts.

Generation constraints:
- Difficulty presets cap how many copies of the same item can appear on one filled layer.
- The generator uses all requested logical types when the board contains enough triples and
  distributes triples evenly across them.
- Inferred type counts target the requested average copies per type, while actual per-type counts
  remain multiples of three.
- `--max-items-per-type` adds an explicit global cap for special levels that need less overall
  repetition. Without it, the target filled-slot count is not reduced merely because a progression
  pool is small.
- `--min-front-visible-triples` defaults to `1` and guarantees at least that many item types have three visible front-layer copies somewhere across shelves, which gives generated levels an intuitive starting move without requiring a completed shelf match. Use `0` to disable the guarantee.
- `--locked-shelves` can add per-shelf `unlock_after_triples` requirements using 1-based shelf numbers such as `7:3,8:5`.
- When the logical item set cannot satisfy the target filled-slot count within an explicit
  per-type cap, the generator adds extra empty slots instead of exceeding the cap.
- Generated layouts reshuffle shelf slots to reduce same-item concentration on a single filled layer, using an adaptive per-layer limit so constrained levels remain possible.
- Expert difficulty avoids shelves that start with a complete front-layer match.

Depends on:
- `scripts/tools/level_item_progression.py` for canonical logical item IDs.
- `scripts/tools/validate_level_solvable.py` for validation and optional solvability checks.

Use when:
- Creating or regenerating level shelf layouts.

Do not use for:
- Runtime game logic.

## `scripts/tools/level_item_progression.py`

Purpose:
- Validates the item catalog and cumulative milestone config.
- Selects a deterministic level-specific subset from the available item pool.
- Maps template `item_NN` identities one-to-one into concrete item IDs.
- Provides a single-template materialization CLI.

Key behavior:
- Rejects unknown, duplicated, or unscheduled catalog items.
- Rejects concrete item IDs inside templates and templates that require more identities than their
  campaign-level pool provides.
- Hash-selects the concrete subset using `mapping_salt` and campaign level, then assigns the subset
  in stable item-ID order so solvability and deterministic replay tie-breaking are preserved.

Depends on:
- `configs/item_progression.json`.
- `configs/item_sprites.json`.

## `scripts/tools/materialize_level_templates.py`

Purpose:
- Materializes every `configs/level_templates/level_*.json` file into the matching
  `configs/levels/level_*.json` runtime file.
- Supports `--check` for CI and pre-publication stale-output detection.

Use when:
- A template, item milestone, mapping salt, or item catalog changes.

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
