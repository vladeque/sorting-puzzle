# Scenes

This file maps scenes to their responsibilities, scripts, important nodes, and runtime relationships.

## `scenes/main_menu.tscn`

Root:
- `ProductionMainMenu` (`Control`)

Script:
- `scripts/production_main_menu.gd`

Purpose:
- Main project entry scene.
- Displays `assets/backgrounds/main_menu.jpeg` as a fullscreen production menu background.
- Provides a top status row for profile, saved gold coins, saved campaign lives, and settings.
- Shows a left-side reward chest widget under the profile icon with saved star progress toward the active configured chest goal.
- After a completed level returns here, launches one clover coin per earned star from the background house into the reward chest and advances the visible chest count on impact.
- Provides a bottom `%LevelButton` labeled with the saved campaign level, such as `Level 1`, or disabled as `No Lives` when lives are empty.
- Opens the player profile menu when the profile widget is pressed.
- Opens the main settings menu when the settings widget is pressed.
- Opens the reward chest detail modal when the reward chest widget is pressed.
- Starts the saved campaign level when the bottom button is pressed.
- Opens `scenes/ui/leaderboard_screen.tscn` when the bottom navigation trophy is pressed.
- Opens `scenes/ui/shop_screen.tscn` when the bottom navigation cart is pressed.

Important nodes:
- `Background`: fullscreen `TextureRect` using `assets/backgrounds/main_menu.jpeg`.
- `TopStatusBar`: top-anchored container that places `scenes/ui/main_menu_top_status.tscn` inside the display's top inset region while avoiding exact camera cutouts.
- `RewardChest`: left-side `scenes/ui/main_menu_reward_chest.tscn` instance positioned by `scripts/production_main_menu.gd`.
- `HouseRewardOrigin`: responsive marker over the background house used as the reward animation origin.
- `RewardCoinFlyer`: fullscreen `scenes/ui/main_menu_reward_coin_flyer.tscn` effect layer.
- `BottomBar`: bottom-anchored responsive container for the play button.
- `BottomBar/LevelButton`: `scenes/ui/level_button.tscn` instance that launches the saved campaign level.
- Runtime child `scenes/ui/profile_menu.tscn`: centered pause-style profile editor window created when `ProfileWidget` is pressed.
- Runtime child `scenes/ui/settings_menu.tscn`: centered pause-style settings window created when `SettingsWidget/SettingsButton` is pressed.
- Runtime child `scenes/ui/reward_chest_menu.tscn`: centered pause-style reward chest detail modal created when the `RewardChest` widget emits `chest_pressed`.

Depends on:
- `level.tscn` through `scripts/production_main_menu.gd`.
- `PlayerProgress` autoload for the saved campaign level, gold coins, lives count, life restore countdown, and reward chest progress.
- `assets/backgrounds/main_menu.jpeg`.
- `scenes/ui/main_menu_top_status.tscn` for top status icons and labels.
- `scenes/ui/main_menu_reward_chest.tscn` for the side reward chest icon and progress bar.
- `scenes/ui/main_menu_reward_coin_flyer.tscn` for the clover-coin flight effect.
- `scenes/ui/profile_menu.tscn` for profile name and avatar editing.
- `scenes/ui/settings_menu.tscn` for the main-menu settings popup.
- `scenes/ui/reward_chest_menu.tscn` for the reward chest detail modal.
- `scenes/ui/level_button.tscn` for the reusable production level button visuals.
- `scenes/ui/leaderboard_screen.tscn` for the dedicated ranking destination.

Do not use for:
- Dev/test level selection. Use `scenes/main_menu_testing.tscn`.
- Runtime puzzle rules or shelf state. Put those in `level.tscn` and `scripts/level.gd`.

## `scenes/ui/leaderboard_screen.tscn`

Root:
- `LeaderboardScreen` (`Control`)

Script:
- `scripts/leaderboard_screen.gd`

Purpose:
- Owns the dedicated leaderboard destination reached from the production menu trophy tab.
- Shows the required `Leaderboard` title and Weekly, Country, and World segmented buttons.
- Gives the central `LeaderboardScroll` the remaining vertical space between the tabs and the reusable bottom navigation.
- Builds up to 50 mock ranking rows in `RowsContainer` and keeps the local player visible through `PinnedPlayerRow` when outside that range.
- Shows a weekly reset countdown, all-time scope descriptions, loading state, empty state, and retryable error state.
- Centers content to a 720-pixel maximum logical width, compacts rows on short viewports, and applies Android/iOS safe-area padding.

Important nodes:
- `%WeeklyButton`, `%CountryButton`, `%WorldButton`: leaderboard scope controls.
- `%PeriodLabel`: weekly countdown or all-time scope description.
- `%LeaderboardScroll`: vertical-only ranking list.
- `%RowsContainer`: runtime parent for reusable row instances.
- `%StatusContainer`, `%StatusLabel`, `%RetryButton`: loading, empty, and error presentation.
- `%PinnedPlayerRow`: highlighted local-player entry outside the scroll view.
- `%BottomNavigation`: shared navigation instance with Leaderboard selected.

Depends on:
- `scenes/ui/leaderboard_row.tscn`.
- `scenes/ui/main_menu_bottom_navigation.tscn`.
- `scripts/leaderboards/leaderboard_service.gd`.
- `PlayerProgress` for the local player's name, avatar, lifetime stars, and weekly stars.

## `scenes/ui/leaderboard_row.tscn`

Root:
- `LeaderboardRow` (`Control`)

Script:
- `scripts/leaderboard_row.gd`

Purpose:
- Reusable ranking entry with rank, circular-clipped avatar, ellipsized player name, reward-star icon, and formatted score.
- Keeps normal cream row art and the green local-player highlight authored in the scene.
- Supports regular and compact heights selected by the owning leaderboard screen.

Depends on:
- `assets/ui/avatars/*.png`.
- `assets/ui/avatar_circle_clip.gdshader`.
- `assets/ui/reward_star_34_glossy_b.png`.

## `scenes/ui/shop_screen.tscn`

Root:
- `ShopScreen` (`Control`)

Script:
- `scripts/shop_screen.gd`

Purpose:
- Owns the dedicated Shop destination with the `Shop` title, live coin balance, scrollable bundle and coin-offer sections, loading/error states, purchase result dialog, and shared bottom navigation.
- Builds offer views from `StoreService.load_catalog()`, which sources offers from `configs/shop_catalog.json` by default or from the authenticated backend development catalog when `application/config/shop_catalog_source` is `backend` (GAME-008), and always attaches the mock provider's formatted regional prices.
- Centers content to a 720-pixel maximum logical width, compacts offers below 1100 logical pixels high, and applies mobile safe-area margins.

Runtime children:
- `shop_bundle_card.tscn` for each bundle.
- `shop_coin_offer_row.tscn` for each coin-only offer.

## `scenes/ui/shop_bundle_card.tscn`

- Reusable full-width featured offer card with title, purchase button, and fixed reward cells for
  Hammer, Shuffle, Lantern (`highlight` internally), Freezer, and coins.
- The scene owns reward art and styling; `scripts/shop_bundle_card.gd` binds quantities and the store-formatted price.
- The Freezer reward cell uses an explicit art-review placeholder until the generated icon
  candidate is approved; no generated artwork is referenced yet.

## `scenes/ui/shop_coin_offer_row.tscn`

- Reusable compact row with coin art, formatted coin quantity, and store-formatted purchase button.
- `scripts/shop_coin_offer_row.gd` emits the bound offer id without granting rewards itself.

## `scenes/ui/coin_balance_widget.tscn`

- Reusable clover-coin pill used by the Shop header and updated from `PlayerProgress.get_coins()`.

## `scenes/ui/shop_purchase_dialog.tscn`

- Dedicated modal overlay for mock purchase success and error results.
- Keeps dialog hierarchy and button wiring out of `shop_screen.gd`.

## `scenes/shop_verification.tscn`

- Automated verification entry scene for regional prices, required viewport sizes, five-cell
  starter reward layout, offer counts, mock grants (including three Freezers), purchase dialog
  display, and duplicate-transaction handling.

## `scenes/ui/main_menu_reward_coin_flyer.tscn`

Root:
- `MainMenuRewardCoinFlyer` (`Control`)

Script:
- `scripts/main_menu_reward_coin_flyer.gd`

Purpose:
- Owns the fullscreen completed-level reward effect on the production menu.
- Creates one `clover_coin_transparent_96x96.png` view per earned star, staggers flights from the house marker to the reward chest, and emits an arrival for each coin so the menu can advance the count.

Do not use for:
- Saving or calculating reward chest progress. Those remain in `PlayerProgress`.

## `scenes/ui/main_menu_bottom_navigation.tscn`

Root:
- `MainMenuBottomNavigation` (`MarginContainer`)

Script:
- `scripts/main_menu_bottom_navigation.gd`

Purpose:
- Owns the compact 96-pixel-high, full-width, icon-led bottom navigation bar on the production main menu.
- Presents Shop, Home, and Leaderboard as equal-width segments on one warm coral-orange bar, separated by strong outlines and identifiable icons.
- Uses enlarged scene-owned `TextureRect` icon controls without hover, focus, or pressed visual effects; the button hit areas remain fully interactive.
- Raises the active screen's icon above the bar height and reveals its small `Shop`, `Home`, or `Leaderboard` label underneath; inactive icons remain centered with labels hidden.
- Defaults to Home and exposes `set_active_tab(tab_name)` so Shop and Leaderboard screens can select their matching visual state.
- Adds bottom safe-area padding supplied by the production menu without narrowing the full-width background.
- Emits focused button signals so each destination can route without moving navigation ownership into the shared component.

Depends on:
- `assets/ui/shopping_cart_icon_128x128.png`.
- `assets/ui/home_navigation_icon_1_128x128.png`.
- `assets/ui/trophy_icon_128x128.png`.

Do not use for:
- Owning destination scenes. The production menu, Shop, and Leaderboard screens connect the signals and perform navigation.

## `scenes/ui/main_menu_reward_chest.tscn`

Root:
- `MainMenuRewardChest` (`Control`)

Script:
- `scripts/main_menu_reward_chest.gd`

Purpose:
- Reusable side-screen reward chest widget for the production main menu.
- Displays `assets/ui/main_menu_reward_chest.png` above a compact progress bar.
- Shows the saved current star amount versus the active reward chest goal, such as `250/500`.
- Emits `chest_pressed` when tapped so the owning menu can open `scenes/ui/reward_chest_menu.tscn`.

Important nodes:
- `ChestIcon`: selected transparent treasure chest PNG.
- `ProgressTrack`: framed bar container under the chest.
- `ProgressTrack/ProgressBar`: fill amount controlled by the script.
- `ProgressTrack/AmountLabel`: centered `current/goal` label with dynamic font sizing.
- `ChestButton`: full-rect flat, focus-less tap target layered above the icon and progress bar (the
  other nodes stay `mouse_filter = Ignore`); forwards its `pressed` signal as `chest_pressed`.

Depends on:
- `assets/ui/main_menu_reward_chest.png`.
- `scripts/main_menu_reward_chest.gd`.
- Owning menu script for placement and progress data.

Do not use for:
- Persisting reward stars or choosing the active goal. Those stay in `scripts/player_progress.gd` and `configs/reward_chest_goals.json`.
- Owning the detail modal's layout. That is `scenes/ui/reward_chest_menu.tscn`.

## `scenes/ui/reward_chest_menu.tscn`

Root:
- `RewardChestMenu` (`Control`)

Script:
- `scripts/reward_chest_menu.gd`

Purpose:
- Centered pause-style detail modal opened from the main menu's reward chest widget.
- Reads live progress from `PlayerProgress.get_reward_chest_progress()` itself in `_ready()`, the
  same way `scenes/ui/profile_menu.tscn` reads its own data; the opening menu does not push data in.
- Shows the `Chest rewards` title, a large decorative chest illustration, the same `current/goal`
  progress bar shown by the side widget (scaled up), a `stars to go` caption, and the coin payout
  waiting at the active goal.
- Purely informational: coins are still granted automatically on goal rollover in
  `scripts/player_progress.gd`, so there is no claim/collect action here.
- The `ChestStage` uses the dedicated generated
  `assets/ui/reward_chest_menu_illustration.png` artwork. The small main-menu reward chest keeps
  its separate `assets/ui/main_menu_reward_chest.png` icon.

Important nodes:
- `RewardChestPanel`: centered outer popup panel, styled like `scenes/ui/profile_menu.tscn`'s panel.
- `CloseButton`: protruding red circular close button; the script wires it to `queue_free()`.
- `InnerPanel/ContentStack/ChestStage`: fixed-size (360x300) illustration area containing one
  aspect-covered `TextureRect`.
- `InnerPanel/ContentStack/ProgressTrack/ProgressBar`, `.../AmountLabel`: bound to the active goal.
- `InnerPanel/ContentStack/GoalCaptionLabel`: `"<n> stars to go"`.
- `InnerPanel/ContentStack/NextRewardRow/NextRewardLabel`: `"Next reward: +<n> coins"` from the
  active goal's `coin_reward`.

Depends on:
- `assets/ui/reward_chest_menu_illustration.png`, `assets/ui/main_menu_coin.png`.
- `PlayerProgress` for `get_reward_chest_progress()`.

Do not use for:
- Saving stars, loading goal config, or awarding completion stars. Those stay in
  `scripts/player_progress.gd` and `configs/reward_chest_goals.json`.

## `scenes/ui/main_menu_top_status.tscn`

Root:
- `MainMenuTopStatus` (`HBoxContainer`)

Script:
- `scripts/main_menu_top_status.gd`

Purpose:
- Reusable top status row for the production main menu.
- Displays four UI groups from left to right: player profile, gold coins, lives remaining, and settings.
- Keeps a runtime-sized center corridor clear for a camera cutout while the owning menu positions the row.
- Provides labels that the owning menu script updates for campaign lives and life restore status.
- Provides a clickable `ProfileWidget` button whose avatar texture is updated from `PlayerProgress.avatar_id`.

Important nodes:
- `ProfileWidget`: circular avatar button.
- `ProfileWidget/AvatarTexture`: saved player avatar texture, clipped to a circle at runtime.
- `CoinsWidget`: generated gold coin icon, saved coin amount label, and plus badge.
- `Spacer02`: non-expanding center exclusion corridor resized around camera cutouts.
- `LivesWidget`: generated heart icon, current life count label, and `Full` or `MM:SS` countdown status label.
- `SettingsWidget`: smaller `PauseMenuButton`-style button with a small alert badge.

Depends on:
- `assets/ui/avatars/avatar_cat.png` for the default editor/display texture. The owning menu script replaces it with the saved avatar at runtime.
- `assets/ui/avatar_circle_clip.gdshader` for hiding the opaque square corners in avatar PNGs.
- `assets/ui/main_menu_coin.png`.
- `assets/ui/main_menu_lives.png`.
- Owning menu scene for placement and safe-area layout.

Do not use for:
- Player inventory, avatar selection logic, player-name editing, lives logic, settings behavior, or profile data ownership. The owning menu script writes display values.

## `scenes/ui/settings_menu.tscn`

Root:
- `MainMenuSettingsOverlay` (`ColorRect`)

Script:
- `scripts/pause_menu.gd`

Purpose:
- Centered pause-style settings window opened from the production main menu over a dimmed modal background.
- Reuses the pause menu visual treatment for the warm outer panel, cream inner panel, `Settings` title, protruding red close button, and saved music / sound-effects / vibration icon toggles.
- Adds two no-op wide green blank-image buttons labeled `Support` and `Language` under the settings toggles.

Important nodes:
- `PauseMenuPanel`: centered popup panel kept named for reuse with `scripts/pause_menu.gd`.
- `PauseMenuPanel/CloseButton`: protruding red close button wired by `scripts/production_main_menu.gd` to dismiss the settings popup.
- `PauseMenuPanel/InnerPanel/IconRow/MusicOption/MusicButton`: square music toggle button with shadow-only button styling and held-press scaling.
- `PauseMenuPanel/InnerPanel/IconRow/SoundEffectsOption/SoundEffectsButton`: square sound effects toggle button with shadow-only button styling and held-press scaling.
- `PauseMenuPanel/InnerPanel/IconRow/VibrationOption/VibrationButton`: square phone vibration toggle button with shadow-only button styling and held-press scaling.
- `PauseMenuPanel/InnerPanel/ActionColumn/SupportButton`: wide no-op button using `assets/ui/level_button_blank_new.png`.
- `PauseMenuPanel/InnerPanel/ActionColumn/LanguageButton`: wide no-op button using `assets/ui/level_button_blank_new.png`.

Depends on:
- `scripts/pause_menu.gd` for the same crossed-out toggle visuals and shared disabled state used by the in-level pause menu.
- `assets/ui/icon_music.png`, `assets/ui/icon_sound_effects.png`, and `assets/ui/icon_vibration.png` as square textures containing warm rectangular tile art for the settings buttons.
- `assets/ui/level_button_blank_new.png`.
- `scripts/press_scale_button.gd` for held-press visuals on the settings icon and wide buttons.
- Runtime open/close wiring from `scripts/production_main_menu.gd`.

Do not use for:
- Applying actual music, sound effects, vibration, support, or language settings. Those runtime systems are not implemented yet.

## `scenes/ui/profile_menu.tscn`

Root:
- `ProfileMenu` (`Control`)

Script:
- `scripts/profile_menu.gd`

Purpose:
- Centered pause-style profile window opened from the production main menu over a dimmed modal background.
- Shows an editable player-name section above the avatar picker.
- Shows all 18 generated avatar assets in a scrollable grid with exactly three avatars per row.
- Highlights the currently selected avatar.
- Saves the entered player name and selected avatar through `PlayerProgress` when the bottom `Save` button is pressed.

Important nodes:
- `ProfileMenuPanel`: centered rounded panel using the pause-menu visual treatment.
- `CloseButton`: protruding red close button that dismisses without saving.
- `InnerPanel/ContentStack/NameSection/NameLineEdit`: editable field populated with the saved or generated player name.
- `InnerPanel/ContentStack/AvatarScroll/AvatarGrid`: scrollable `GridContainer` with `columns = 3`; avatar buttons are generated by the script.
- `ButtonRow/SaveButton`: `scenes/ui/level_button.tscn` instance labeled `Save`.

Depends on:
- `assets/ui/avatars/*.png`.
- `assets/ui/avatar_circle_clip.gdshader`.
- `scenes/ui/level_button.tscn`.
- `PlayerProgress` for available avatar ids, texture paths, current avatar, current player name, generated defaults, and saving.

Do not use for:
- Campaign level launch, lives display, or profile data ownership. Those stay in `scripts/production_main_menu.gd` and `scripts/player_progress.gd`.

## `scenes/ui/level_button.tscn`

Root:
- `LevelButton` (`Button`)

Purpose:
- Reusable production level-entry button.
- Owns the generated glossy green rounded-button texture inspired by the selected generated concept.
- Keeps the button text dynamic through the normal Godot `Button.text` property, so callers can set labels such as `Level 1` or `Complete`.
- Uses `scripts/press_scale_button.gd` so the button scales slightly smaller from its center while a click or touch is held.

Important nodes:
- `LevelButton`: clickable button root with the generated texture style, white outlined text, and dynamic pressed/hover/disabled states.

Depends on:
- `assets/ui/level_button_blank_new.png`.
- `assets/ui/level_button_blank_red_new.png`, `assets/ui/level_button_blank_light_blue_new.png`, and `assets/ui/level_button_blank_yellow_orange_new.png` are matching alternate color blanks for future button states or variants.
- `scripts/press_scale_button.gd` for the default held-press scale behavior expected by future visible game UI buttons.
- Caller scenes or scripts for placement, click wiring, and label updates.

Do not use for:
- Scene navigation, campaign progress lookup, or level launching. Those stay in the owning menu script.

## `scenes/main_menu_testing.tscn`

Root:
- `MainMenu` (`Control`)

Script:
- `scripts/main_menu.gd`

Purpose:
- Preserves the previous testing menu layout.
- Displays title and campaign progress.
- Provides a campaign play button.
- Provides a `%LevelGrid` container that the script fills with isolated dev/test level buttons when dev selection is enabled.

Important nodes:
- `Background`: fullscreen menu background.
- `ShelfBackdrop` and `ShelfLip`: static decorative shelf art.
- `Content`: centered menu layout container.
- `Content/SelectorLabel`: campaign current-level label in normal flow, or dev selector label in dev/test mode.
- `Content/PlayButton`: unique-name button that launches the saved campaign level from the testing menu.
- `Content/LevelGrid`: unique-name `GridContainer` used by the script for dev/test level selection.

Depends on:
- `level.tscn` through `scripts/main_menu.gd`.
- `PlayerProgress` autoload for the saved campaign level and lives gate.

Do not use for:
- Runtime puzzle rules or shelf state. Put those in `level.tscn` and `scripts/level.gd`.

## `level.tscn`

Root:
- `Level` (`Node2D`)

Script:
- `scripts/level.gd`

Purpose:
- Playable puzzle scene.
- Provides stable top-level nodes that `scripts/level.gd` fills and controls at runtime.
- Normal campaign launches atomically commit the snapshot and completion journal operation before
  showing the completion reward overlay, then wait on `Next` before loading the next level. A failed
  local commit keeps the level active and does not render success. Dev/test launches return to their
  configured menu and do not touch campaign save data.

Important nodes:
- `Background`: fullscreen procedural gameplay backdrop with child nodes for the top HUD strip, simple shop wall, baseboard, and bottom floor band.
- `Background/HudCenterSlot/ComboFill`: rounded green combo-window strip that shrinks as the time left to extend the combo runs out.
- `Background/HudCenterSlot/ComboLabel`: hidden until the player clears a triple, then shows the active combo count.
- `Shelves`: parent for generated shelf nodes and optional moving shelf row containers; `scripts/level.gd` scales and centers it in the available play area for the current viewport size.
- `DragLayer`: temporary parent for dragged items, drawn above shelves.
- `UI`: `CanvasLayer` for gameplay labels, the reusable ability bar, and overlays; top-level
  controls are anchored or positioned at runtime for non-720x1280 portrait screens.
- `UI/TimerLabel`: countdown display.
- `UI/LevelLabel`: current level display.
- `UI/StarCounterLabel`: top HUD star total panel, positioned between the timer area and pause button, with a small `reward_star.png` icon and numeric `CountLabel`.
- `UI/PauseMenuButton`: circular top-right button that pauses the active level and opens the pause menu overlay.
- `UI/AbilityBar`: `scenes/ui/ability_bar.tscn` instance; its focused owner script owns all four
  buttons, use badges, timed badges, touch-target sizing, and the `ability_pressed` signal.
- `UI/FailurePanel`: shown when time runs out.
- `UI/CompletionScreen`: `scenes/ui/level_completion_screen.tscn` instance shown after all items clear.
- `UI/PauseMenuOverlay`: `scenes/pause_menu.tscn` instance used for the modal pause menu.
- `UI/LeaveConfirmationOverlay`: `scenes/leave_confirmation_menu.tscn` instance shown after the pause menu's Leave button, before spending a campaign life and returning to the menu.
- `UI/AbilityPurchaseOverlay`: `scenes/ability_purchase_menu.tscn` instance shown when the player taps an ability with zero saved uses remaining.

Runtime-created nodes:
- `ShelfXX`: `scenes/shelf.tscn` instances generated under `Shelves`.
- `UI/StarRewardEffectLayer`: full-screen mouse-ignored effect layer created by `scripts/level.gd`; combo reward stars are spawned here after a triple clear and fly toward `UI/StarCounterLabel`, and 2x+ combo praise labels with tiered colored outlines appear here near the match origin for two seconds.
- `MovingShelfRowXX`: `scenes/moving_shelf_row.tscn` instances generated under `Shelves` when a level config or layout template defines moving rows.
- `ShelfLayerXX`: generated back layers for hidden or upcoming item rows.
- `ShelfItem` instances from `scenes/item.tscn`.
- `ItemPlaceAudio` and `TripleClearAudio`: `AudioStreamPlayer` nodes created by `scripts/level.gd`.

Depends on:
- `scenes/shelf.tscn`
- `scenes/moving_shelf_row.tscn`
- `scenes/layouts/layout_*.tscn`
- `scenes/item.tscn`
- `scenes/pause_menu.tscn`
- `scenes/leave_confirmation_menu.tscn`
- `scenes/ability_purchase_menu.tscn`
- `scenes/ui/ability_bar.tscn`
- `assets/audio/*.wav`
- `configs/item_sprites.json`
- `configs/ability_purchase_prices.json`
- `configs/levels/level_*.json`
- `assets/abilities/*.png`
- `scenes/abilities/hammer_impact_effect.tscn` for the hammer ability's fullscreen strike animation.

Do not use for:
- Static shelf cell visuals. Put those in `scenes/shelf.tscn`.

## `scenes/ui/ability_bar.tscn`

Root:
- `AbilityBar` (`Control`)

Script:
- `scripts/ability_bar.gd`

Purpose:
- Reusable four-ability gameplay control extracted from `level.tscn`.
- Owns Hammer, Shuffle, Lantern/highlight, and Freezer buttons; each has a minimum 82x82 compact
  touch target and a 96x96 regular target.
- Owns remaining-use badges plus independent Lantern and Freezer active countdown badges.
- Emits `ability_pressed(ability_id)` and exposes focused state/layout methods; `scripts/level.gd`
  remains the gameplay/economy orchestrator.
- The Freezer button currently carries an explicit text-only art-review placeholder. The selected
  generated icon will replace it together with the focused Freezer effect scene after product
  approval.

Important nodes:
- `ButtonRow/HammerButton`
- `ButtonRow/ShuffleButton`
- `ButtonRow/HighlightButton/TimerLabel`
- `ButtonRow/FreezerButton/TimerLabel`

Do not use for:
- Spending inventory, opening purchase UI, or applying effects. Those remain in
  `scripts/level.gd` and `PlayerProgress`.

## `scenes/ability_purchase_menu.tscn`

Root:
- `AbilityPurchaseOverlay` (`ColorRect`)

Script:
- `scripts/ability_purchase_menu.gd`

Purpose:
- Reusable in-level purchase modal shown by `scripts/level.gd` when the player tries to use
  hammer, shuffle, highlight/Lantern, or Freezer with zero remaining uses.
- Reuses the leave-confirmation modal treatment with a dimmed fullscreen background, warm outer popup, cream inner content panel, and protruding red close button.
- Shows the `Get more items` title, the selected ability icon in a centered slot, a bottom-right `x1` count badge, a green coin-price image button, and a yellow-orange `Watch ad` image button.

Important nodes:
- `PurchasePanel`: centered popup panel.
- `PurchasePanel/TitleLabel`: title text.
- `PurchasePanel/CloseButton`: red close button wired by `scripts/level.gd` to resume gameplay.
- `PurchasePanel/InnerPanel/AbilitySlot/Icon`: selected ability icon written by `scripts/level.gd`.
- `PurchasePanel/InnerPanel/AbilitySlot/CountLabel`: static `x1` badge.
- `PurchasePanel/ButtonRow/BuyButton`: green image button whose child `PriceRow` shows `assets/ui/main_menu_coin.png` and the configured price.
- `PurchasePanel/ButtonRow/WatchAdButton`: yellow-orange image button labeled `Watch ad`; currently emits a signal but has no gameplay effect.

Depends on:
- `assets/ui/main_menu_coin.png`.
- `assets/ui/level_button_blank_new.png`.
- `assets/ui/level_button_blank_yellow_orange_new.png`.
- `scripts/press_scale_button.gd`.
- Runtime offer setup, coin spending, and ability execution from `scripts/level.gd`.

Do not use for:
- Price configuration, coin persistence, or ability execution. Those stay in `configs/ability_purchase_prices.json`, `scripts/player_progress.gd`, and `scripts/level.gd`.

## `scenes/ui/level_completion_screen.tscn`

Root:
- `LevelCompletionScreen` (`ColorRect`)

Script:
- `scripts/level_completion_screen.gd`

Purpose:
- Reusable completed-level reward overlay instanced by `level.tscn`.
- Displays the `Great job!` title, reward star image, earned-star count label, and green `Next` button.
- Emits `next_pressed` so `scripts/level.gd` can advance campaign levels or return dev/test launches to their menu.

Important nodes:
- `TitleLabel`: completion heading.
- `StarImage`: large `assets/ui/reward_star.png` reward art.
- `EarnedStarsLabel`: final run star count formatted as `xN`; its responsive center sits 150 design pixels below the reward star center.
- `NextButton`: green blank-image button with `scripts/press_scale_button.gd` so it visually shrinks while held.

Depends on:
- `assets/ui/reward_star.png`
- `assets/ui/level_button_blank_new.png`
- `scripts/press_scale_button.gd`

Do not use for:
- Puzzle completion checks, campaign save writes, or scene progression. Those stay in `scripts/level.gd`.

## `scenes/abilities/hammer_impact_effect.tscn`

Root:
- `HammerImpactEffect` (`Control`)

Script:
- `scripts/hammer_impact_effect.gd`

Purpose:
- Reusable fullscreen hammer strike effect spawned by `scripts/level.gd` when the hammer ability is used.
- Displays the selected high-resolution transparent hammer sprite over gameplay using four pseudo-3D angle frames.
- Owns the editable `AnimationPlayer` `strike` timeline for wind-up, fast strike, rebound, fade-out, texture swaps, impact signal timing, and burst amount.
- Emits `impact` exactly when the hammer visually lands so gameplay can destroy the center-screen merged item on the hit frame.

Important nodes:
- `ImpactAnchor`: runtime-positioned target point that scales the full hammer for the current viewport.
- `ImpactAnchor/HammerPivot`: keyframed by `AnimationPlayer` for wind-up, strike, rebound, and exit motion.
- `ImpactAnchor/HammerPivot/HammerSprite`: transparent hammer sprite whose position and texture are value-keyframed by the `strike` animation.
- `AnimationPlayer`: owns the `strike` animation; edit this timeline for most hammer motion and timing adjustments.

Depends on:
- `assets/abilities/ability_hammer_swing_windup.png`.
- `assets/abilities/ability_hammer_swing_mid.png`.
- `assets/abilities/ability_hammer_swing_impact.png`.
- `assets/abilities/ability_hammer_swing_rebound.png`.
- Runtime instancing and target positioning from `scripts/level.gd`.

Do not use for:
- Choosing hammer targets, spending ability inventory, destroying items, or resolving shelves. Those stay in `scripts/level.gd`.

## `scenes/layouts/layout_*.tscn`

Root:
- `Node2D`

Purpose:
- Editor-authored shelf placement templates for `layout_preset` values in level JSON.
- Keep each preset's shelf markers easy to nudge, align, and review visually in Godot.
- Own static shelf marker positions and optional moving-row marker positions.
- Static shelf markers are grouped into horizontal rows by runtime marker position so `scripts/level.gd` can assign left/middle/right shelf visuals from the actual authored layout.

Important nodes:
- `ShelfXX`: `Marker2D` nodes consumed in scene order by `scripts/level.gd`; their positions become runtime `scenes/shelf.tscn` positions.
- `MovingRowXX`: optional `Node2D` nodes with `scripts/shelf_layout_row.gd`; their positions become the visible moving-row center.

Existing presets:
- `scenes/layouts/layout_grid_2x3.tscn`
- `scenes/layouts/layout_grid_3x3.tscn`
- `scenes/layouts/layout_grid_3x4.tscn`
- `scenes/layouts/layout_grid_3x5.tscn`
- `scenes/layouts/layout_grid_4x3.tscn`
- `scenes/layouts/layout_grid_3x3_moving_5_bottom.tscn`
- `scenes/layouts/layout_staggered_5_4_5.tscn`
- `scenes/layouts/layout_staggered_4_5_4.tscn`

Depends on:
- Runtime shelf instantiation from `scripts/level.gd`.
- `scripts/shelf_layout_row.gd` for moving-row template metadata.

Do not use for:
- Shelf contents, item layers, locks, matching rules, or runtime state. Those stay in level JSON and `scripts/level.gd`.

## `scenes/moving_shelf_row.tscn`

Root:
- `MovingShelfRow` (`Control`)

Script:
- `scripts/moving_shelf_row.gd`

Purpose:
- Runtime row container for shelf groups with horizontal or vertical wrap motion.
- Clips child shelf rendering to the configured visible shelf window.
- Keeps moving-row bounds separate from individual shelf cell visuals.

Important properties:
- `clip_contents`: enabled so off-window shelves are hidden by the row rectangle.
- `mouse_filter`: ignored so gameplay input remains owned by `scripts/level.gd`.

Runtime-created nodes:
- `ShelfXX`: `scenes/shelf.tscn` instances parented under the row and registered with `MovingShelfRow.add_shelf()`.

Depends on:
- Runtime configuration from `scripts/level.gd`.
- Child shelf scenes from `scenes/shelf.tscn`.

Do not use for:
- Puzzle rules, item movement rules, matching, abilities, or lock progression. Those stay in `scripts/level.gd`.

## `scenes/pause_menu.tscn`

Root:
- `PauseMenuOverlay` (`ColorRect`)

Script:
- `scripts/pause_menu.gd`

Purpose:
- Reusable in-level pause menu overlay instanced by `level.tscn`.
- Owns the modal dimmer, warm outer popup panel, cream inner settings panel, `Pause` title, protruding top-right red close button, music / sound-effects / vibration square icon buttons, their crossed-out toggle visuals, and `Leave` / `Continue` buttons.
- Uses full-rect overlay anchors and a centered popup panel so it tracks the stretched viewport.

Important nodes:
- `PauseMenuPanel`: centered popup panel.
- `PauseMenuPanel/TitleLabel`: pause menu title.
- `PauseMenuPanel/CloseButton`: protruding top-right red close button wired by `scripts/level.gd` to resume the level.
- `PauseMenuPanel/InnerPanel`: cream settings area inside the warm outer popup.
- `PauseMenuPanel/InnerPanel/IconRow/MusicOption/MusicButton`: square music toggle button with shadow-only button styling and held-press scaling.
- `PauseMenuPanel/InnerPanel/IconRow/SoundEffectsOption/SoundEffectsButton`: square sound effects toggle button with shadow-only button styling and held-press scaling that disables or enables gameplay sound effects.
- `PauseMenuPanel/InnerPanel/IconRow/VibrationOption/VibrationButton`: square phone vibration toggle button with shadow-only button styling and held-press scaling.
- `PauseMenuPanel/ButtonRow/LeaveButton`: red image button wired by `scripts/level.gd` to open leave confirmation.
- `PauseMenuPanel/ButtonRow/ContinueButton`: green image button wired by `scripts/level.gd` to resume the level.
- The settings icon buttons and bottom red/green image buttons use `scripts/press_scale_button.gd` so they visually shrink while held.

Depends on:
- `assets/ui/icon_music.png`, `assets/ui/icon_sound_effects.png`, and `assets/ui/icon_vibration.png` as square textures containing warm rectangular tile art for the settings buttons.
- `assets/ui/level_button_blank_red_new.png` and `assets/ui/level_button_blank_new.png` for pause action buttons.
- `scripts/press_scale_button.gd` for the default held-press shrink on settings icon buttons and bottom image buttons.
- `assets/ui/pause_menu_option_a_sheet.png` and `assets/ui/pause_menu_option_b_sheet.png` are archived alternate visual directions for these icons.
- Runtime button wiring from `scripts/level.gd`.
- Shared settings-button visual toggles from `scripts/pause_menu.gd`, persisted through `PlayerProgress`.

Do not use for:
- Timer state, scene navigation, gameplay pause rules, music playback, or actual vibration settings. Those stay in owning runtime systems.

## `scenes/leave_confirmation_menu.tscn`

Root:
- `LeaveConfirmationOverlay` (`ColorRect`)

Purpose:
- Reusable in-level leave confirmation overlay instanced by `level.tscn`.
- Reuses the pause popup panel treatment with a dimmed fullscreen modal background, warm outer area, cream inner loss area, and an explicitly top-right anchored protruding red close button.
- Shows a `Leaving the Level` title, warning text, crossed-out life and star reward icons, readable bottom-right count badges layered above the icons, and red `Leave` / green `Continue` image buttons.

Important nodes:
- `ConfirmationPanel`: centered popup panel.
- `ConfirmationPanel/TitleLabel`: leave confirmation title.
- `ConfirmationPanel/CloseButton`: protruding top-right red close button wired by `scripts/level.gd` to resume the level.
- `ConfirmationPanel/InnerPanel`: cream content area with warning copy and lost-reward icons.
- `ConfirmationPanel/InnerPanel/MessageLabel`: warning copy shown above the lost-reward icons.
- `ConfirmationPanel/InnerPanel/LossRow/LifeLoss`: rectangular crossed-out life slot with a bottom-right static count of `1`.
- `ConfirmationPanel/InnerPanel/LossRow/StarLoss`: rectangular crossed-out star slot.
- `ConfirmationPanel/InnerPanel/LossRow/StarLoss/CountLabel`: bottom-right current run star count written by `scripts/level.gd`.
- `ConfirmationPanel/ButtonRow/ConfirmLeaveButton`: red image button that confirms leaving.
- `ConfirmationPanel/ButtonRow/ContinueButton`: green image button that resumes the level.
- The bottom red and green image buttons use `scripts/press_scale_button.gd` so they visually shrink while held.

Depends on:
- `assets/ui/main_menu_lives.png`.
- `assets/ui/reward_star.png`.
- `assets/ui/level_button_blank_red_new.png`.
- `assets/ui/level_button_blank_new.png`.
- `scripts/press_scale_button.gd` for the default held-press shrink on the bottom image buttons.
- Runtime button wiring and star-count updates from `scripts/level.gd`.

Do not use for:
- Spending lives, scene navigation, or pause state ownership. Those stay in `scripts/level.gd`.

## `scenes/shelf.tscn`

Root:
- `Shelf` (`Node2D`)

Script:
- `scripts/shelf.gd`

Purpose:
- Reusable shelf cell instantiated by `scripts/level.gd` for each configured shelf.
- Owns the visible shelf back wall, floor, frame, front slot positions, and item snap markers.
- Owns generated back-layer slot layout and preview styling defaults through `scripts/shelf.gd`.
- Owns soft internal left/top wall shadows, the diagonal bottom cast shadow, the hidden top ceiling cap, and the right-column cast shadow toggled by `scripts/level.gd`.
- Uses opaque pre-blended shadow colors so overlapping shadow polygons do not compound into darker patches.
- Owns the hidden locked-shelf overlay visuals shown by `scripts/level.gd` when a level config gates the shelf behind cleared triples.
- Uses wide, slightly shorter cell bounds so three generated shelves span most of the 720 px gameplay viewport with compact row spacing.
- Runtime shelf instances are scaled slightly by `scripts/level.gd`, with layout template markers and moving-row windows authored to match the scaled cell footprint.
- Can be switched by `scripts/level.gd` to a `floor_only` visual variant for moving rows by hiding wall and ceiling nodes at runtime.
- Can be switched by `scripts/level.gd` to `left`, `middle`, or `right` row-placement visuals for static shelves. Moving-row shelves currently stay on the neutral `middle` row-placement visual.

Important nodes:
- `BackWall`: muted panel behind shelf items.
- `BackWallTopShade`: soft interior wall shadow layer behind items.
- `PlacementVisuals`: editable role-specific shelf art groups toggled by `scripts/shelf.gd`.
- `PlacementVisuals/Left`: left shelf role visuals. Contains `BackWallLeftShade`, `LeftWall`, `RightWall`, and the left-specific `TopCeilingCap`.
- `PlacementVisuals/Middle`: middle shelf role visuals. Contains row divider art and the middle-specific `TopCeilingCap`.
- `PlacementVisuals/Right`: right shelf role visuals. Contains right edge art and the right-specific `TopCeilingCap`.
- `Ceiling`: shared wooden top frame. Placement-specific `TopCeilingCap` nodes are shown at runtime only for top shelves.
- `Shadow` and `RightColumnShadow`: solid-color perspective cast shadows, shown at runtime for full shelf visuals and drawn below shelf bodies, items, and generated back-layer item previews so they remain visible only on exposed wall/background areas.
- `FloorSurface` and `FloorFrontLip`: wooden floor where items visually rest.
- `FloorGrain*`: subtle line details on the floor; generated back-layer item previews draw above the floor and grain, while active front items draw above back-layer previews.
- `LockedOverlay`: hidden lock overlay used for triple-gated shelves.
- `LockedOverlay/LockSprite`: transparent lock image from `assets/ui/lock_shelf_cutout.png`, scaled to fit the shelf overlay.
- `LockedOverlay/RemainingLabel`: runtime-updated count of triples still needed to unlock the shelf, optically centered over the lock's clear center panel.
- `Slot01`, `Slot02`, `Slot03`: front slots used by runtime movement and matching logic, positioned so default item silhouettes sit next to each other.
- `SlotXX/ItemSlotXX`: marker positions used by `scripts/level.gd` for snap targeting.

Depends on:
- `scripts/shelf.gd` for generated back-layer preview setup.
- `assets/ui/lock_shelf_cutout.png` for locked shelf overlay art with a clear center panel for the count label.
- Runtime item spawning from `scripts/level.gd`.

Do not use for:
- Level timing, matching, input handling, lock progression, item identity assignment, or back-layer promotion timing. Those stay in `scripts/level.gd`.

## `scenes/item.tscn`

Root:
- `Item` (`Area2D`)

Script:
- `scripts/item.gd`

Purpose:
- Reusable sortable item scene.
- Gives each spawned item a collision area and sprite.
- Uses a default visual scale and hitbox sized for the wide shelf cell slots.
- In generated shelves, the owning shelf cell scale enlarges the item sprite, shadow, and hit area together with the shelf visuals.

Important nodes:
- `Shadow`: solid-color up-right cast shadow behind front-layer item sprites; generated back-layer previews and active player drags disable it.
- `OutlineSprite`: hidden sprite used by `ShelfItem` to draw alpha-based highlight borders.
- `Sprite2D`: main item sprite; texture and visual scale are controlled by `ShelfItem`.
- `CollisionShape2D`: rectangular item hitbox used by runtime interaction.

Depends on:
- Texture assignment from `scripts/level.gd`.
- Highlight outline color and width assignment from `scripts/level.gd`.
- Item IDs defined in `configs/item_sprites.json`.

Do not use for:
- Shelf placement rules, matching logic, or level progression.
