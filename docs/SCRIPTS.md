# Scripts

## Sticky item mechanic

`scripts/sticky_item_rules.gd` validates one sticky item per shelf layer and reserves matching
partners from Hammer. `scripts/level.gd` loads flags, rejects sticky move sources, and filters ability
targets/hints; `scripts/item.gd` owns instance state. `scripts/sticky_item_indicator.gd` owns the two
marker variants and blocked feedback. `scripts/sticky_items_preview.gd` and
`scripts/sticky_preview_controls.gd` own the isolated playable art comparison and controls.
Python validation is shared through `scripts/tools/sticky_items.py`, with generator/solver and
materialization support in their existing tools. See [STICKY_ITEMS.md](STICKY_ITEMS.md) for the
contract, CLI, tests, and release boundary.

This file documents what each script owns. Keep script docs focused on responsibilities, exports, dependencies, and boundaries.

## `scripts/ads/*.gd`

- `ad_service.gd`: `AdService` autoload and sole gameplay-facing API. It coordinates lifecycle,
  consent/privacy options, preload/show, one active request, audio restoration, normalized results,
  diagnostics, and local pacing persistence.
- `ad_policy.gd`: pure, bounded, fail-closed rewarded/interstitial eligibility rules.
- `ad_pacing_state.gd`: schema/sanitizer and transition helpers for non-economic local counters and
  timestamps.
- `interstitial_completion_gate.gd`: ADS-007's level-scoped one-shot owner. It counts a committed
  campaign completion once and makes at most one best-effort request at the completion-to-menu
  transition.
- `ad_release_readiness.gd`: ADS-008's pure, fail-closed evaluator for launch policy, injected
  runtime identifiers, and evidence-backed legal/store/device approvals.
- `ad_provider.gd`: disabled provider contract; `mock_ad_provider.gd` is the deterministic test
  implementation; `admob_provider.gd` adapts the pinned native bridge without reward authority and
  keeps loaded rewarded inventory isolated by placement/ad unit.
- `rewarded_time_extension_client.gd`: shared protocol-1.4 run owner for ADS-003 and ADS-005. It
  forwards opaque SSV custom data, accepts only exact settled time/ability effects, and binds the
  issued authorization set plus one rewarded immediate ability use into terminal settlement.
- `rewarded_life_client.gd`: ADS-004 protocol-1.4 player-scoped intent/status owner. It forwards
  only opaque SSV custom data and returns the authoritative capped life state only after settlement.
- `scripts/tools/check_ad_release_readiness.gd`: command-line ADS-008 release audit; the committed
  development configuration is expected to fail until owner evidence and release settings exist.

See [ADS_002_CLIENT_AD_INFRASTRUCTURE.md](ADS_002_CLIENT_AD_INFRASTRUCTURE.md) for release gates and
the backend reward boundary, and
[ADS_003_REWARDED_TIME_EXTENSION.md](ADS_003_REWARDED_TIME_EXTENSION.md) and
[ADS_004_REWARDED_LIFE.md](ADS_004_REWARDED_LIFE.md) and
[ADS_005_REWARDED_ABILITY.md](ADS_005_REWARDED_ABILITY.md) for implemented placements, plus
[ADS_007_INTERSTITIAL_PACING.md](ADS_007_INTERSTITIAL_PACING.md) and
[ADS_008_COMPLIANCE_RELEASE_VALIDATION.md](ADS_008_COMPLIANCE_RELEASE_VALIDATION.md).

## `scripts/testing/reward_chest_fill_preview.gd`

Attached to `scenes/testing/reward_chest_fill_preview.tscn`. It drives the production reward chest
and star flyer in an isolated, replayable F6 preview, updates a local-only progress count, and plays
the semantic chest-arrival event on each impact. It never touches saved progression.

## `scripts/production_main_menu.gd`

Attached to:
- `scenes/main_menu.tscn` root `ProductionMainMenu`.

Purpose:
- Shows the production campaign entry point over the selected chapter's configured menu background.
- Labels the bottom button with the saved current level.
- Displays saved campaign lives in the top status bar and keeps campaign play pressable at zero
  lives so the dedicated lives modal can explain recovery and purchase options.
- Opens that same modal from the top status bar's lives widget at any life count. The two entry
  points differ only in what follows: a launch-interrupted open resumes the requested level once a
  life exists, while a widget open stays on the Main Menu.
- Displays saved gold coins in the top status bar.
- Displays the saved profile avatar and opens the profile editor from the top status bar.
- Displays the saved reward chest star progress in a separate left-side widget under the profile icon.
- Consumes completed-level reward payloads, displays the pre-reward chest value, and advances it once for each reward star that reaches the chest.
- `_on_reward_star_arrived()` is the one accepted-arrival callback: it advances the visible count,
  starts the chest receive pulse, and plays `reward_chest_star_arrival` together (AUDIO-001). An
  arrival that crosses a chest goal layers exactly one `coin_gain` for the completed goal, read
  through `PlayerProgress.get_reward_chest_goal_coin_reward_at_index()`. Silent state
  reconciliation (`_update_reward_chest_status()`, `_prepare_pending_reward_animation()`) plays
  nothing.
- Opens the reward chest detail modal when the reward chest widget emits `chest_pressed`.
- Opens the main-menu settings popup from the top status bar, routes its policy-driven privacy
  choices/privacy-policy action, and presents the native support FAQ above Settings when requested.
- Adds every main-menu modal through a shared overlay helper so no menu action can render or receive
  input above an open modal; each overlay fades in on open and out before it closes.
- Launches the first incomplete level in the selected unlocked chapter.
- Opens the chapter selection screen and refreshes the level/chapter actions and fullscreen
  background after selection.
- Opens the dedicated leaderboard scene from the bottom navigation trophy signal.
- Opens the dedicated Shop scene when the top-status coin balance shortcut is pressed (in addition
  to the bottom navigation cart).
- Consumes `PlayerProgress.consume_pending_leaderboard_reward()` and shows `%LeaderboardRewardDialog` when a weekly leaderboard rollover granted a coin reward since the last launch.
  That presentation plays one `coin_gain`; the pending reward is consumed once, so it is a visible
  accepted payout rather than initial balance population.
- A successful life purchase from the out-of-lives modal plays `coin_spend`; a rejected purchase
  stays silent.
- Fades the whole screen in on `_ready()`; retapping the already-active Home bottom-navigation tab
  is a documented no-op; `ui_cancel` closes the topmost open overlay (skipping its own handling
  entirely while Chapter Selection is open, since that screen owns its own `ui_cancel`) or does
  nothing with none open; a duplicate cross-destination navigation press while a scene transition is
  in flight is ignored (see `docs/SCENES.md`'s "Shared Interaction Roles").

Key constants:
- `PROFILE_MENU_SCENE`: preloads `res://scenes/ui/profile_menu.tscn`.
- `SETTINGS_MENU_SCENE`: preloads `res://scenes/ui/settings_menu.tscn`.
- `SUPPORT_SCREEN_SCENE`: preloads `res://scenes/ui/support_screen.tscn`.
- `REWARD_CHEST_MENU_SCENE`: preloads `res://scenes/ui/reward_chest_menu.tscn`.
- `MenuBackgroundResolverScript`: preloads `res://scripts/chapters/menu_background_resolver.gd`,
  the same chapter-background policy Shop/Leaderboard use through their shared destination shell.
- `UIMotionScript`: preloads `res://scripts/ui_motion.gd` for the destination/overlay fades.
- `PRODUCTION_MENU_SCENE`: return path assigned to campaign level instances.
- `LEADERBOARD_SCENE`: destination path for the trophy tab.
- `LIFE_STATUS_REFRESH_SECONDS`: cadence for refreshing the lives countdown while the menu is visible.
- `MAIN_MENU_OVERLAY_Z_INDEX`: shared layer for runtime modals and the embedded leaderboard reward
  dialog, above every production-menu action.
- `TOP_MARGIN`: preferred distance from the physical top edge for the status row.
- `CAMERA_CUTOUT_PADDING`: empty space reserved around each reported display cutout.
- `BOTTOM_BAR_*`, `SIDE_MARGIN`, `LEVEL_BUTTON_MAX_WIDTH`, and `CHAPTER_BUTTON_MAX_WIDTH`:
  responsive bottom-button layout values.

Important nodes:
- `%TopStatusBar`: top-anchored container positioned inside the display's top inset region while avoiding exact camera cutout rectangles.
- `%RewardChest`: side-screen `scenes/ui/main_menu_reward_chest.tscn` instance positioned under the profile icon.
- `%HouseRewardOrigin`: normalized marker over the background house.
- `%RewardStarFlyer`: dedicated fullscreen completed-level reward-star effect (renamed from
  `%RewardCoinFlyer` in UI-002; see `docs/SCENES.md`'s "Reward-Progress Semantics").
- `MainMenuTopStatus/ProfileWidget`: opens the profile menu.
- `MainMenuTopStatus/ProfileWidget/ProfileAvatarView`: displays the saved avatar and local frame.
- `MainMenuTopStatus/CoinsWidget`: `scenes/ui/main_menu_coin_shortcut.tscn` instance; shows the
  saved gold coin balance and opens the Shop when pressed.
- `MainMenuTopStatus/SettingsWidget/SettingsButton`: opens the main-menu settings popup.
- `MainMenuTopStatus/LivesWidget`: flat button that opens `%OutOfLivesMenu` informationally
  (`_open_out_of_lives_menu(false)`), the lives counterpart of the `CoinsWidget` shortcut.
- `MainMenuTopStatus/LivesWidget/LifeCount`: shows current campaign lives; the owning scene's
  `LivesPill` shares `assets/themes/style_box_status_counter_pill.tres` and compact 118x44 geometry
  with the coin balance background.
- `MainMenuTopStatus/LivesWidget/LifeStatus`: shows `Full` or the `MM:SS` countdown until the next restored life.
- `%BottomBar`: bottom-anchored container positioned at runtime with safe-area padding.
- `%LevelButton`: `scenes/ui/level_button.tscn` instance that starts the saved campaign level.
- `%OutOfLivesMenu`: persistent hidden `scenes/ui/out_of_lives_menu.tscn` instance shown when a
  launch request finds zero lives, or when the top-status lives widget is pressed.
- `%ChapterButton`: compact yellow-orange selected-chapter button that opens
  `chapter_selection_screen.tscn`; see `docs/SCENES.md` "Shared UI Style Tokens" for why
  yellow-orange is the intentional secondary/alternative-action role here.
- `%BottomNavigation`: full-width `scenes/ui/main_menu_bottom_navigation.tscn` instance aligned to the viewport bottom and extended through the device safe area.

Key methods:
- `_ready()`: fades the screen in, loads progress, wires level, bottom-navigation, and
  coin-shortcut buttons, refreshes the saved coin balance, selects Home, and applies responsive
  layout.
- `_process(delta)`: refreshes the lives display and play button state once per elapsed real-time second while the menu is open.
- `_unhandled_input(event)`: closes the topmost open scoped overlay on `ui_cancel` (profile,
  settings, or reward-chest modal, then the leaderboard reward dialog), one per press; explicitly
  skips entirely while Chapter Selection is open (it owns its own `ui_cancel` handling); does
  nothing with no overlay open.
- `_apply_responsive_layout()`: keeps the top status row cutout-aware and the bottom button inside the viewport safe area.
- `_layout_top_status_bar()`: places the status row at `TOP_MARGIN`, expands its center exclusion gap around camera cutouts, and falls below a cutout only when the row cannot fit around it.
- `_layout_reward_chest()`: positions the side reward chest under the profile icon without putting it in the top status scene.
- `_layout_bottom_navigation()`: sizes the full-width navigation bar and passes its safe-bottom inset to the scene-owned layout.
- `_update_level_button()`: displays the saved current level or complete/unavailable state; zero
  lives no longer disables or relabels a playable campaign action.
- `_update_chapter_background(chapter_id)`: thin wrapper around
  `MenuBackgroundResolverScript.apply_background()`, the same policy Shop/Leaderboard use through
  their shared destination shell.
- `_update_coin_balance()`: forwards the saved gold coin balance to the coin shortcut's `set_amount()`.
- `_update_lives_status()`: writes current lives and the next-life `MM:SS` countdown into the top status labels.
- `_update_reward_chest_status()`: writes `PlayerProgress` reward chest progress into the side widget.
- `_play_pending_reward_animation()`: flies earned reward stars from the house to the chest after
  scene entry (UI-002 corrected this from flying clover-coin art; see `docs/SCENES.md`'s
  "Reward-Progress Semantics").
- `_on_reward_star_arrived()`: advances the displayed chest count and handles configured goal rollover on impact (renamed from `_on_reward_coin_arrived`).
- `_on_reward_star_animation_finished()`: reconciles the displayed chest value with saved progress once the flight finishes (renamed from `_on_reward_coin_animation_finished`).
- `_on_home_tab_reselected()`: documented no-op for retapping the already-active Home tab.
- `_format_life_restore_time(seconds_remaining)`: formats the next-life restore timer as zero-padded minutes and seconds.
- `_update_profile_customization()`: loads the saved avatar/frame combination into the top status
  profile widget.
- `_open_profile_menu()`: creates the centered profile menu window and listens for saved avatar changes.
- `_open_settings_menu()`: creates the centered settings popup and wires its close button.
- `_close_settings_menu()`: fades the settings popup out, then frees it.
- `_open_support_screen()`: creates the full-screen native FAQ overlay above the still-open Settings
  modal so Back returns to the same Settings context.
- `_open_reward_chest_menu()`: creates the centered reward chest detail modal; the modal reads its own progress and wires its own close button.
- `_add_main_menu_overlay(overlay)`: places a runtime modal on the shared overlay z-index, adds it
  to the production menu, and fades it in.
- `_open_leaderboard()` / `_open_shop()`: request navigation to the dedicated leaderboard/Shop
  scene through `_begin_navigation()`.
- `_begin_navigation(scene_path)`: guarded `change_scene_to_file()` wrapper -- ignores a duplicate
  call while `_is_navigating` is already true, so a rapid double-tap (including via the top-status
  coin shortcut) can never call it twice, and disables this screen's own `process_mode` so no
  descendant can react to further input before the deferred scene swap resolves.
- `_on_profile_saved(avatar_id, avatar_frame_id)`: refreshes the top status customization after the
  profile menu saves.
- `_launch_campaign_level()`: resolves the selected chapter's next incomplete global level,
  opens Out of Lives when needed, and resumes the same launch after a successful life recovery;
  otherwise sends the accepted request and campaign metadata to `LevelTransition`.
- `_refresh_out_of_lives_offer()`: keeps the modal's life count, cap, configured price, and
  next-life countdown current, which is also what switches an open modal between its below-cap and
  full-lives states; resumes an interrupted launch exactly once if time restores a life, and leaves
  a widget-opened modal alone.
- `_open_out_of_lives_menu(is_launch_pending)`: opens the lives modal and records which entry point
  it came from in `_out_of_lives_launch_pending`.
- `_close_out_of_lives_menu()`: single close path for the modal; clears the pending-launch flag
  before awaiting the fade so no route can leave a stale launch to resume later.
- `_on_out_of_lives_purchase_requested()`: ignores a stale press at the life cap, opens Shop when
  unaffordable, otherwise persists one atomic offline life purchase and closes the modal; it
  launches the originally requested level only when a campaign launch was pending.
- `_on_out_of_lives_rewarded_ad_requested()`: waits for authoritative rewarded-life settlement,
  mirrors its life state without a local purchase operation, and uses the same one-time completion
  route as coin/restoration recovery.

## `scripts/level_transition.gd`

Attached to:
- The `LevelTransition` autoload registered in `project.godot`.

Purpose:
- Owns every normal level start and retry across scene boundaries.
- Starts a threaded load of `level.tscn`, keeps the loading overlay alive while scenes swap, rejects
  duplicate requests, transfers launch properties, and activates gameplay after the reveal.

Depends on:
- `scenes/ui/level_loading_screen.tscn`.
- `scripts/level.gd` transition preparation and activation methods.

## `scripts/level_loading_screen.gd`

Attached to:
- `scenes/ui/level_loading_screen.tscn` root `LevelLoadingScreen`.

Purpose:
- Owns the iris close/reveal, mascot entrance/exit, animated loading dots, responsive shader size,
  minimum visible duration, and full-screen input interception.
- Exposes `show_preview()` for the responsive capture setup.

## `scripts/chapters/*.gd`

Purpose:
- `chapter_catalog.gd` validates `configs/chapters.json` and exposes global-to-chapter/local-level
  lookup; it is registered as the `ChapterCatalog` autoload before `PlayerProgress`.
- `chapter_selection_screen.gd` builds one `chapter_cover_card.gd` page per chapter into a shared
  `scripts/horizontal_pager.gd` pager, opens on the currently selected chapter, and persists a new
  pick through `PlayerProgress`. `_apply_responsive_layout()`/`_apply_safe_margins(margins)` reuse
  `DestinationScreenLayout.get_safe_area_margins()`/`get_title_font_size()` to keep `%HeaderMargins`,
  the centered `%ChaptersTitleLabel`, and every page's pager/card overlays inside the device safe
  area; `_apply_safe_margins()` is split out so tests can exercise a fabricated inset directly,
  since the real safe-area lookup is always zero on desktop/headless. `_close()` (the back button,
  `ui_cancel`, or a successful selection) fades the screen out via `scripts/ui_motion.gd` before
  freeing it; owns its own `ui_cancel` handling independently of Main Menu's, which explicitly
  skips acting while this screen is open instead of risking a double-handling race.
- `main_menu_chapter_button.gd` labels the compact main-menu chapter button and exposes the full
  chapter title in its tooltip. `chapter_cover_card.gd` owns full-screen art plus a bottom
  information panel with completion counts, selected state, exact lock progress, a labeled linear
  progress bar, contextual status (`Play`/`Continue`/`Locked`/`Coming Soon`, title case per
  `docs/TYPOGRAPHY.md`), and CTA. Its 294 px unlocked and 340 px locked `%InfoPanel` heights give
  the content more vertical breathing room, and `%CtaButton` uses scene-local flat green active
  styles with the shared
  neutral disabled style for `Locked`/`Coming Soon` (see `docs/SCENES.md`).
  `set_safe_margins(margins)` insets `%InfoMargins`
  without touching the full-bleed `%Art`.
- `chapter_level_background.gd` loads the selected level's configured chapter artwork.
- `menu_background_resolver.gd` (`class_name MenuBackgroundResolver`) is the shared "selected
  chapter -> menu background texture" policy: `apply_background(background, chapter_id)`, silently
  keeping the caller's current texture when the chapter has no valid configured
  `selection_preview`. Used by Main Menu directly and by Shop/Leaderboard through
  `scenes/ui/destination_screen_shell.tscn`, so the three screens can never drift out of sync
  again. Consumers `preload` it and call it by the preloaded constant, matching the convention in
  `scripts/backend/backend_read_operations.gd`, rather than relying on the bare global class name.

Depends on:
- `level.tscn`
- `scenes/ui/settings_menu.tscn`
- `scripts/level.gd` export `selected_level`
- `scripts/level.gd` export `launched_from_dev_mode`
- `scripts/level.gd` export `return_menu_scene_path`
- `scripts/horizontal_pager.gd`
- `scripts/destination_screen_layout.gd`
- `scripts/ui_motion.gd`
- `PlayerProgress` autoload

Do not use for:
- Developer/test level selection. Put that in `scripts/main_menu.gd`.
- Persistent save data ownership. Put that in `scripts/save/local_save_store.gd`; use
  `PlayerProgress` only as the gameplay facade.
- Puzzle runtime logic.

## `scripts/horizontal_pager.gd`

Class:
- `HorizontalPager`

Attached to:
- `scenes/ui/horizontal_pager.tscn` root `HorizontalPager`.

Purpose:
- Generic, content-agnostic swipeable pager. Holds arbitrary `Control` pages side by side inside a
  clipped track, and lets the player drag/swipe or tap the built-in arrow buttons to move between
  them, snapping to the nearest page on release. Not chapter-specific.
- Input handling mirrors `scripts/level.gd`'s press/motion/release drag idiom (a slop distance before
  a press becomes a drag, `accept_event()` on every handled branch) adapted to `Control._gui_input`.
- First/last-page dragging is limited to a small overscroll allowance so edge swipes remain tactile
  without exposing an unbounded empty track.
- `%Dots` are `Panel`s styled from `style_box_pager_dot_inactive/active.tres` (a circle at rest, a
  rounded capsule for the active page) instead of a literally-square `ColorRect`.

Exports:
- `peek_width`: how much of the neighboring page is visible at the pager's edges.
- `drag_start_distance`: pointer travel required before a press becomes a drag.
- `commit_fraction`: fraction of a page's width a drag must cross to commit to the next/previous page
  instead of snapping back.

API:
- `add_page(page: Control)`: appends a page.
- `go_to_page(index: int, animate: bool = true)`: jumps to a page, optionally animated.
- `get_current_page()`: returns the active zero-based page index.
- `set_safe_margins(margins: Vector4)`: insets `%PrevArrow`/`%NextArrow`/`%Dots` from their
  authored offsets, leaving `%Clip`/`%Track`/pages untouched. Defaults to `Vector4.ZERO` (no-op),
  so this stays a no-behavior-change opt-in for every other consumer of this generic pager.
- `page_changed(index: int)` signal.

Use when:
- Browsing one item at a time out of a small set (chapter covers today; Shop or Rewards could reuse
  it later).

Do not use for:
- Long scrollable lists. Use a `ScrollContainer` instead.

## `scripts/progress_ring.gd`

Class:
- `ProgressRing`

Attached to:
- No current production scene. Kept as a reusable circular progress utility; chapter covers use a
  linear `ProgressBar` so exact current and total values remain legible in the bottom panel.

Purpose:
- Draws a circular progress readout with `Control._draw()`/`draw_arc()`: a full track circle plus a
  partial fill arc starting at the top. The only percentage-driven `_draw()` component in the
  project, and now the only `draw_arc()` usage.
- Recomputes its radius from `size` on `NOTIFICATION_RESIZED`, so it stays correct across the five
  responsive test resolutions without a hardcoded pixel radius.

Exports:
- `ring_width`, `track_color`, `fill_color`.

API:
- `set_progress(current: int, total: int)`: sets the fill fraction; `total <= 0` draws an empty ring.
- `get_progress_current()`, `get_progress_total()`: the exact values passed to `set_progress()`, for
  callers (including tests) that need to assert on the numbers rather than the derived fraction.

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
- Wires the three scene-owned icon buttons to `shop_pressed`, `home_pressed`, and
  `leaderboard_pressed` signals. `pressed` is a native Button signal and always forwards regardless
  of prior state; the owning screen decides whether its own matching signal actually does anything
  (a documented no-op when it matches the screen's own destination -- see `docs/SCENES.md`'s
  "Active-Tab Reselection Rule").
- Applies runtime bottom safe-area padding while preserving three equal-width button segments.
- Owns the reusable active-tab presentation: `set_active_tab(tab_name)` raises the selected icon
  beyond the bar height, shows its label, and restores the other icons to centered unlabeled
  states, animating the icon raise/lower and label fade over
  `UIMotion.NAV_ACTIVE_CHANGE_DURATION` (via `_set_tab_active()`) instead of jumping. Kills any
  tween already in flight per icon/label first, so rapid re-entry never accumulates offsets or
  opacity. Screens never live-switch their own bottom nav's active tab -- Home, Shop, and
  Leaderboard are separate scenes -- so scene entry is the only moment this animation is visible.
- `_apply_active_tab()` also marks the active tab's button `sfx_click_suppressed` through
  `SfxManager.set_button_click_suppressed()` and clears it on the other two. A global click policy
  cannot know that retapping the active tab is a no-op, so it is declared here (AUDIO-001).

Depends on:
- `scripts/ui_motion.gd`.

Do not use for:
- Loading destination scenes or owning menu progression.

## `scripts/destination_screen_layout.gd`

Class:
- `DestinationScreenLayout` (`RefCounted`, all `static func`, no instance needed)

Purpose:
- Shared responsive-layout math for Shop/Leaderboard-style destination screens: safe-area-aware
  content margins capped to a 720px maximum logical width, compact/regular title sizing (40/48
  below/at-or-above 1100 logical viewport height), and bottom-navigation placement. Replaces what
  used to be two near-identical ~60-line copies in `shop_screen.gd` and `leaderboard_screen.gd`.
- `get_safe_area_margins()` is also reused by `chapter_selection_screen.gd` on its own (Chapter
  Selection's full-bleed layout is not a fixed-content-rect screen, so the rest of this helper does
  not apply there).
- Consumers `preload` this script and call its static funcs by the preloaded constant, matching the
  convention in `scripts/backend/backend_read_operations.gd` and `scripts/save/local_save_codec.gd`,
  rather than relying on the bare global class name.

API:
- `get_safe_area_margins(viewport_size)`: `Vector4` (left/top/right/bottom), zero outside
  Android/iOS.
- `get_bottom_reserved(safe_margins)` / `get_overlay_bottom_reserved(safe_margins)`: reserve the
  bottom-navigation footprint or only the safe-bottom gap respectively.
- `apply_content_rect(content_margin, viewport_size, safe_margins, bottom_reserved)`: positions a
  full-rect `MarginContainer` inside the safe area.
- `is_compact_viewport(viewport_size)`, `get_title_font_size(viewport_size)`.
- `layout_bottom_navigation(nav, safe_margins)`: positions a `main_menu_bottom_navigation.tscn`
  instance and forwards its safe-bottom margin.

## `scripts/destination_screen_shell.gd`

Attached to:
- `scenes/ui/destination_screen_shell.tscn` root `DestinationScreenShell`.

Purpose:
- Owns the shared fullscreen background + secondary-screen shade for Shop/Leaderboard's
  `%DestinationShell` instance. `set_background_for_chapter(chapter_id)` delegates to
  `menu_background_resolver.gd`.

## `scripts/destination_status_panel.gd`

Attached to:
- `scenes/ui/destination_status_panel.tscn` root `DestinationStatusPanel`.

Purpose:
- Shared loading/empty/error/Retry presentation for Shop/Leaderboard's `%StatusPanel` instance.
  `show_loading(message)`/`show_empty(message)` hide Retry (an in-progress load or a legitimately
  empty result is not a failure); `show_error(message)` shows it; `hide_status()` hides the panel.
  Emits `retry_pressed`; the owning screen decides what retrying actually does.
- `show_loading()` starts a looping opacity pulse on `%StatusMessageLabel` (`UIMotion` tokens, via
  `retween()`) so an in-progress load reads as active rather than frozen; every other state and
  leaving the tree stop it (`stop_tween()`), so reloads never accumulate loop tweens. Purely
  visual -- never blocks `ui_cancel` or bottom navigation.

Depends on:
- `scripts/ui_motion.gd`.

## `scripts/leaderboard_screen.gd`

Attached to:
- `scenes/ui/leaderboard_screen.tscn` root `LeaderboardScreen`.

Purpose:
- Owns Weekly, Country, and World selection and asynchronous provider requests.
- Builds ranking rows from provider dictionaries and pins the local player via `%PinnedPlayerRow`
  when absent from the returned entries or ranked beyond `PINNED_ROW_RANK_THRESHOLD` (10) -- being
  technically present on a 50-row page doesn't mean the player is visible without scrolling.
- Updates the weekly reset countdown and loading, empty, and retry states through `%StatusPanel`,
  hiding `%ListBackground` while the status panel is showing so error/loading never nests two
  bordered panels.
- Reports the player's Weekly rank to `PlayerProgress.record_weekly_leaderboard_rank()` after every
  successful Weekly fetch. For Weekly ranks 1-3 it binds the configured reward amount and the
  requested rank-specific Shop coin-pile art to each row; Country/World remain reward-free because
  those all-time boards have no reset/payout moment.
- Applies responsive content width, compact row sizing, bottom-navigation placement, and mobile
  safe-area margins through `scripts/destination_screen_layout.gd` (shared with Shop); the title
  now uses the same 48/40 regular/compact size as Shop instead of its previous local 44/36.
- Follows the selected chapter's background through `%DestinationShell` in `_ready()` instead of a
  fixed Chapter 1 image.
- Routes the shared Home tab back to `scenes/main_menu.tscn`.
- Routes the shared Shop tab to `scenes/ui/shop_screen.tscn`.
- Fades the whole screen in on `_ready()`; retapping the already-active Leaderboard
  bottom-navigation tab is a documented no-op (`_on_leaderboard_tab_reselected()`; ranking refresh
  stays available only through `%StatusPanel`'s Retry); `ui_cancel` always returns to Main Menu,
  since Leaderboard has no scoped overlay of its own; `_begin_navigation()` guards `_return_to_main_menu()`/`_open_shop()` against a duplicate press while a transition is already in flight.

Depends on:
- `scripts/leaderboards/leaderboard_service.gd`.
- `scripts/destination_screen_layout.gd`, `scripts/ui_motion.gd`.
- `scenes/ui/leaderboard_row.tscn`, `scenes/ui/destination_screen_shell.tscn`,
  `scenes/ui/destination_status_panel.tscn`.
- `PlayerProgress` leaderboard, profile, and selected-chapter getters.

## `scripts/shop_screen.gd`

- `ShopScreen` supports destination and in-level-overlay presentation modes without duplicating
  catalog or purchase logic.
- Owns Shop loading/error states, creates reusable offer scenes, coordinates one purchase at a time, and routes the shared navigation.
- Passes purchase results and their offer ids to `PlayerProgress.apply_shop_purchase()`, refreshes
  the visible balance after a grant, and reloads the catalog so a claimed one-time offer disappears.
- `_play_purchase_success_feedback(grant_result)` ties audio and haptics to rewards actually
  landing rather than to the button or the dialog (AUDIO-001): it plays `shop_purchase_success`
  only when the grant reports `applied`, layers one `coin_gain` when the grant included coins,
  and stays silent for a duplicate transaction (`ok` with `applied` false) or a failed grant.
  Ability-only bundles get the confirmation alone; there is no purchase-failure cue.
- Applies maximum content width, compact offer sizing, fixed bottom navigation, and mobile
  safe-area margins through `scripts/destination_screen_layout.gd` (shared with Leaderboard); loading/error states go through `%StatusPanel`.
- Follows the selected chapter's background through `%DestinationShell` in `_ready()` instead of a
  fixed Chapter 1 image.
- Owns the `ABILITY_INFO` display copy (name + one-line description) for Hammer/Shuffle/Lantern/
  Freezer and shows it through `%PurchaseDialog` when a bundle card's `info_requested` signal fires.
- Fades the whole screen in on `_ready()`; retapping the already-active Shop bottom-navigation tab
  is a documented no-op (`_on_shop_tab_reselected()`; catalog refresh stays available only through
  `%StatusPanel`'s Retry); `ui_cancel` closes an open `%PurchaseDialog` first via its `close()`
  method if one is showing, otherwise returns to Main Menu; `_begin_navigation()` guards
  `_return_to_main_menu()`/`_open_leaderboard()` against a duplicate press while a transition is
  already in flight.
- In overlay mode it hides `%BottomNavigation`, shows `%OverlayCloseButton`, uses the extra vertical
  content space, and exposes `open()`/`close()`/`is_transitioning()` plus
  `close_requested`/`closed`. `handle_back()` closes `%PurchaseDialog` first, then requests return
  to Ability Purchase through `scripts/level.gd`, regardless of which embedded node receives
  `ui_cancel` first.

Depends on:
- `scripts/destination_screen_layout.gd`, `scripts/ui_motion.gd`.
- `scenes/ui/destination_screen_shell.tscn`, `scenes/ui/destination_status_panel.tscn`.
- `PlayerProgress` for the selected chapter id.

## Shop component scripts

- `scripts/shop_bundle_card.gd`: binds one bundle's title, coin/Hammer/Shuffle/Lantern/Freezer
  rewards (coins shown first), formatted price, and purchase signal. Also binds the optional
  discount starburst badge/compare-at price from
  `offer.discount_percent`/`offer.store.compare_at_formatted_price` and widens `%TitleSpacer` while
  the badge is visible so it never overlaps the title, and emits `info_requested(ability_id)` when a
  reward cell's transparent info button is tapped. Its purchase button uses the shared
  `style_box_green_primary_button.tres` at the "regular" 58px height, also used by the flat-styled
  Chapter CTA. Each
  reward cell's info button uses `press_scale_button.gd` with `visual_target_path` set to its
  sibling `Stack` (0.97 held scale), so it visibly presses without shrinking the full-cell tap
  target -- these had no press feedback at all before UI-002.
- `scripts/shop_coin_offer_row.gd`: binds a coin quantity, its amount-scaled seven-tier clover-coin
  pile texture, formatted price, and purchase signal. The texture ladder uses 100, 300, 750, 1,600,
  3,500, and 13,000 as upper bounds before the largest overflowing-pouch fallback. Also binds an
  optional `tag` banner (for example "BEST VALUE"). Purchase button height matches the shared
  "regular" 58px tier (previously a locally-different 64px).
- `scripts/coin_balance_widget.gd` (`class_name CoinBalanceWidget`): formats and displays a
  non-negative coin balance. `set_compact(bool)` selects between the Shop header's regular size
  (158x68) and the Main Menu coin shortcut's compact size (142x60); both variants reuse the exact
  same `%Pill` stylebox, `%CoinIcon` texture, and `GameNumberLabel` styling, so only geometry
  differs between the two screens.
- `scripts/shop_purchase_dialog.gd`: shows and dismisses a focused result modal; `show_result()`
  takes an optional `button_text` (defaults to "Continue") so the same dialog reads correctly for
  both purchase results and ability info lookups ("Got it"). `%CloseButton` uses the shared orange
  utility style plus `press_scale_button.gd` for press feedback (it had none before UI-002).
  `show_result()` fades in; `close()` fades out then hides (never frees -- the same instance is
  reused for every purchase result).

## `scripts/main_menu_coin_shortcut.gd`

Attached to:
- `scenes/ui/main_menu_coin_shortcut.tscn` root `MainMenuCoinShortcut` (extends `PressScaleButton`).

Purpose:
- Wraps a compact `coin_balance_widget.tscn` instance with the Main Menu's "+" badge inside a real
  tap target. `set_amount(amount)` forwards to the wrapped widget;
  `scripts/production_main_menu.gd` connects the native `pressed` signal to open the Shop.

## Store scripts

- `scripts/store/store_provider.gd`: provider contract for product loading and purchase requests.
- `scripts/store/mock_store_provider.gd`: resolves config prices for `application/config/mock_store_country` and returns unique mock transaction ids after a short asynchronous delay. Also resolves an offer's optional `compare_at_prices` into `compare_at_formatted_price` the same way it resolves `mock_prices` into `formatted_price`; omitted when the offer has no compare-at price.
- `scripts/store/store_service.gd`: selects a catalog source via `application/config/shop_catalog_source` (`local` default or `backend`), joins its offers with `_provider` (always the mock provider), and returns normalized purchase results. Local/mock offers marked with a lifetime purchase limit of one are filtered against `PlayerProgress` on load and checked again before purchase. This is the client replacement point for later platform integrations.
- `scripts/store/backend_catalog_source.gd` (GAME-008): `shop_catalog_source=backend`'s offer source. Reads the authenticated backend development catalog (`GET /v1/catalog`) through the shared `BackendTransport`/`BackendReadOperations` (GAME-007), keeps only offers with `eligible: true`, maps the backend `type` enum to the UI's `bundle`/`coins` grouping, and joins each offer to `configs/backend/shop_catalog_prices.json` by `platform_product_id` for its display title and mock regional price via the same `MockStoreProvider.load_products()` the local catalog uses. Also carries that presentation entry's optional `compare_at_prices` (through the same price-provider resolution), `discount_percent`, and `tag` onto the joined offer, so the Shop's discount badge and value tag work the same regardless of `shop_catalog_source`. Offers with an unrecognized type or no local price-table entry are silently excluded rather than rendered without a price. Any failed read (unavailable, unauthorized, malformed, or an empty local `backend_base_url`) falls back to `BackendCatalogCache`; only surfaces an error when no cache exists either.
- `scripts/store/backend_catalog_cache.gd` (GAME-008): persists the last successfully joined/priced backend catalog to `user://shop_catalog_backend_cache.json` (offers/prices only, never a token or signature) for the offline-cache fallback above.

## `scripts/tools/run_isolated_godot_test.ps1`

- Runs a Godot test scene or script under a generated `SortingPuzzleTest_<id>` project name, which
  gives the process a unique `user://` directory instead of the live `SortingPuzzle` player data.
- Copies the existing `.godot` import cache into a temporary project, links only the runtime/test
  resource directories, and deliberately leaves out `local/backend_debug.cfg`.
- Removes the temporary project and test user data after the process exits; pass `-KeepArtifacts`
  only when the isolated files are needed for diagnosis.
- Use this wrapper for save-aware headless tests. This Godot build does not support the previously
  documented `--user-data-dir` argument; the ignored argument allowed verification data to reach
  the live development save.

Examples:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Scene scenes/shop_verification.tscn
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/save/test_player_progress_facade.gd -GodotArguments '--verbose'
```

## `scripts/tools/verify_shop.gd`

- Runs through `scenes/shop_verification.tscn` with the isolated test wrapper above and refuses to
  run under the production `SortingPuzzle` project identity.
- Verifies US, Ukrainian, German, and Japanese mock price strings; five representative portrait
  viewports; the five-reward starter layout (coins first), its loaded discount badge texture, and
  compare-at price; offer population; the `coins_3500` best-value tag (and that untagged offers
  stay untagged); the ability info dialog opening with the right title when a reward icon is
  tapped; coin and bundle purchases including the 2,500-coin New Player Bundle; lifetime
  one-time visibility across a reload; three Freezers per bundle; and duplicate transaction
  protection.
- Also verifies the shared `%DestinationShell`'s background actually changes when the selected
  chapter id changes (proving Shop no longer silently stays on the Chapter 1 image), and that
  `%StatusPanel`'s Retry button resolves to the same `style_box_orange_utility_normal.tres`
  resource instance as the shared token, not just a visually similar local copy.

Run:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Scene scenes/shop_verification.tscn
```

Prints `SHOP VERIFICATION PASSED` and exits `0` on success; otherwise prints each failed check and exits `1`.

## `scripts/leaderboard_row.gd`

Class:
- `LeaderboardRow`

Attached to:
- `scenes/ui/leaderboard_row.tscn` root `LeaderboardRow`.

Purpose:
- Binds one provider entry to rank, composed avatar/frame, display name, and comma-formatted star
  score controls.
- Toggles the scene-authored current-player highlight.
- Toggles the scene-authored gold/silver/bronze `RankSlot` medal circle for rank 1/2/3 and switches
  `RankLabel` between a bare number (top 3) and "#N" (rank 4+).
- Forwards reward image/amount binding and compact sizing to the focused `%RankReward` component.
- Applies compact or regular row and font sizing, including `RankSlot` and the reusable
- Relies on `ProfileAvatarView`'s symmetric 7 px avatar-layer insets so the avatar remains centered
  and slightly overlaps the inner rim of every returned frame at both row sizes.

## `scripts/leaderboard_rank_reward.gd`

Class:
- `LeaderboardRankReward`

Attached to:
- `scenes/ui/leaderboard_rank_reward.tscn` root `LeaderboardRankReward`.

Purpose:
- Shows or clears one rank reward's coin-pile texture and comma-formatted amount.
- Applies the component's regular or compact panel and overlaid-label sizing; the scene-authored
  coin image fills the available content area in both modes.

## `scripts/tools/verify_leaderboard.gd`

- Runs through `scenes/leaderboard_verification.tscn` with the isolated test wrapper above and
  refuses to run under the production `SortingPuzzle` project identity.
- Verifies that the old reward summary label is gone, Weekly ranks 1-3 show 500/300/300 with tier
  04/03/02 artwork respectively, rank 4 has no preview, Country rows hide Weekly rewards, and the
  leaderboard remains within bounds at five representative portrait resolutions.
- Also verifies the shared `%DestinationShell`'s background follows a chapter-id change,
  `%StatusPanel`'s Retry button resolves to the shared orange utility style resource, the title
  reads the shared regular size (48) at all five required resolutions, and -- directly against
  `DestinationScreenLayout.get_title_font_size()`, since no required resolution produces a
  sub-1100 logical height under this project's `keep_width` stretch mode -- the compact size (40).

Run:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Scene scenes/leaderboard_verification.tscn
```

Prints `LEADERBOARD VERIFICATION PASSED` and exits `0` on success; otherwise prints each failed
check and exits `1`.

## `scripts/leaderboard_reward_dialog.gd`

Class:
- `LeaderboardRewardDialog`

Attached to:
- `scenes/ui/leaderboard_reward_dialog.tscn` root `LeaderboardRewardDialog`.

Purpose:
- Generic titled-message modal shown once per granted weekly reward, mirroring
  `shop_purchase_dialog.gd`'s structure. `show_reward(rank, coin_reward)` builds the message from
  the actual granted values; `scripts/production_main_menu.gd` is the only caller.
- `%CloseButton` uses `press_scale_button.gd` for press feedback (it had none before UI-002).
  `show_reward()` fades in; `close()` fades out then hides.

Depends on:
- `scripts/ui_motion.gd`, `scripts/press_scale_button.gd`.

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

## `scripts/main_menu_reward_star_flyer.gd`

Attached to:
- `scenes/ui/main_menu_reward_star_flyer.tscn` root `MainMenuRewardStarFlyer`.

Purpose:
- Creates and animates one reward star for every star earned in the just-completed level.
- Staggers arcing star tweens between menu-provided global positions.
- Emits `star_arrived` for count updates and `animation_finished` for final saved-state
  reconciliation.
- Renamed from `main_menu_reward_coin_flyer.gd`/`MainMenuRewardCoinFlyer` and its `coin_arrived`
  signal (UI-002): this always represents earned stars, never spendable coins, and previously flew
  clover-coin art -- see `docs/SCENES.md`'s "Reward-Progress Semantics".

Depends on:
- `assets/ui/reward_star_84x84.png`.
- The production menu for start and target positions.

## `scripts/main_menu_reward_chest.gd`

Attached to:
- `scenes/ui/main_menu_reward_chest.tscn` root `MainMenuRewardChest`.

Purpose:
- Owns the visual state of the main-menu reward chest progress widget.
- Updates the progress bar value and centered `current/goal` label.
- Shrinks the label font for longer progress text so it stays inside the bar.
- Emits `chest_pressed` when the widget's full-rect `%ChestButton` overlay is tapped; `%ChestButton`
  uses `press_scale_button.gd` with `visual_target_path` set to the `Visual` wrapper around the
  chest icon and progress track (0.97 held scale, UI-002 -- it had no press feedback at all
  before), which along with the icon and progress bar stays `mouse_filter = Ignore` and never
  receives input directly.

Key methods:
- `set_reward_progress(current_stars, goal_stars)`: clamps the displayed value to the active goal and updates the bar and label.
- `get_reward_target_global_position()`: returns the center of the chest art for reward flights
  (renamed from `get_coin_target_global_position()` in UI-002 -- this is the chest's landing point
  for any reward flight, not specifically a coin concept).
- `play_receive_pulse()`: briefly pulses the whole widget when a reward star arrives (independent
  of, and composes fine with, `%ChestButton`'s own press-scale animation on `Visual`).

Depends on:
- `scenes/ui/main_menu_reward_chest.tscn` node names `Visual`, `%ProgressBar`, `%AmountLabel`, and `%ChestButton`.
- `scripts/press_scale_button.gd`.

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
  buttons call the shared `close()` method, which fades the modal out before freeing it (a repeat
  call while already closing -- both buttons pressed, or Main Menu's `ui_cancel` handling arriving
  mid-close -- is ignored; see `docs/SCENES.md`'s "Shared Interaction Roles").

Key methods:
- `close()`: fades this modal out via `scripts/ui_motion.gd`, then frees it.
- `_apply_reward_progress(progress)`: writes the clamped `current/goal` values into the progress bar
  and label, the remaining-stars caption, and the hero image's reward badge.
- `_sync_illustration_corner_mask()`: updates the image shader with the illustration's actual
  runtime size and 16-pixel corner radius whenever container layout resizes it.

Depends on:
- `scenes/ui/reward_chest_menu.tscn` node names `%CloseButton`, `%ContinueButton`, `%ProgressBar`,
  `%Illustration`, `%AmountLabel`, `%GoalCaptionLabel`, and `%NextRewardLabel`.
- `PlayerProgress.get_reward_chest_progress()`.
- `scripts/ui_motion.gd`.

Do not use for:
- Persisting reward stars, loading goal config, or awarding completion stars. Those stay in
  `scripts/player_progress.gd` and `configs/reward_chest_goals.json`.

## `scripts/profile_menu.gd`

Attached to:
- `scenes/ui/profile_menu.tscn` root `ProfileMenu`.

Purpose:
- Builds the draft-based name, avatar, and frame profile editor.
- Switches one three-column choice grid between the 18 avatars and configured cosmetic frames.
- Updates the summary preview immediately while deferring persistence until Save.
- Emits `profile_saved(avatar_id, avatar_frame_id)` after the complete customization saves so the
  main menu can refresh its reusable profile view.

Key constants:
- `GRID_COLUMNS`: fixed to `3`.
- `PANEL_MAX_WIDTH`, `PANEL_MAX_HEIGHT`, and `PANEL_MIN_MARGIN`: centered popup panel bounds.
- `TILE_MIN_SIZE` and `TILE_MAX_SIZE`: responsive shared choice-tile bounds.
- `SAVE_BUTTON_MAX_WIDTH`: width cap for the bottom `Save` button.

Important nodes:
- `%ProfileMenuPanel`: centered pause-style popup panel resized by the script.
- `%ProfilePreview`: live pending avatar/frame composition.
- Always-visible `%NameLineEdit` and compact pencil `%EditNameButton`: the field is visually an
  input at all times but remains locked until the pencil enables editing.
- `%AvatarTab` and `%FrameTab`: segmented selector controls.
- `%ChoiceGrid`: full-width `GridContainer` populated with reusable avatar or frame tiles inside a
  touch-scrollable container whose visual scrollbar is hidden.
- `%SaveButton`: `scenes/ui/level_button.tscn` instance labeled `Save`.
- `%CloseButton`: dismisses the picker without saving, through the shared `close()` method.

Key methods:
- `close()`: fades this modal out via `scripts/ui_motion.gd`, then frees it. Safe to call more than
  once (Close pressed, Save pressed, or Main Menu's `ui_cancel` handling can all reach here) -- a
  repeat call while already closing is ignored.
- `_switch_tab(tab_id)`: updates segmented control state and rebuilds the shared grid.
- `_select_choice(choice_id)`: updates the pending avatar or frame and live preview.
- `_begin_name_edit()` / `_finish_name_edit()`: enter and leave inline name editing without saving
  or closing the modal.
- `_save_selection()`: commits the complete customization through
  `PlayerProgress.set_profile_customization()` and calls `close()`.
- `_apply_responsive_layout()`: updates panel bounds, choice-tile sizes, and Save width.

Depends on:
- `PlayerProgress`
- `scripts/ui_motion.gd`.
- `assets/ui/avatars/*.png`
- `assets/ui/avatar_frames/*.png`
- `assets/ui/avatar_circle_clip.gdshader`
- `configs/profile_frames.json`
- `scenes/ui/profile_avatar_view.tscn`
- `scenes/ui/profile_choice_tile.tscn`
- `scenes/ui/level_button.tscn`

Do not use for:
- Owning saved profile data, campaign progress, lives state, or main menu navigation.

## `scripts/profile_avatar_view.gd`

Attached to:
- `scenes/ui/profile_avatar_view.tscn` root `ProfileAvatarView`.

Purpose:
- Composes an avatar texture and catalog-driven transparent frame texture as one reusable profile
  visual.
- Owns the defensive circular clipping material used by every instance.

Public methods:
- `set_profile(avatar_id, frame_id)`: updates both layers together.
- `set_avatar(avatar_id)` and `set_frame(frame_id)`: update one layer while preserving the other.

Rendering:
- `assets/ui/avatar_circle_clip.gdshader` scales avatar content to 90% and extends the source image's
  outer background colors to the frame edge, revealing more backdrop without shrinking the frame.

## `scripts/profile_choice_tile.gd`

Attached to:
- `scenes/ui/profile_choice_tile.tscn` root `ProfileChoiceTile`.

Purpose:
- Configures the avatar/frame preview for one editor choice and owns its normal, hover, pressed,
  selected, and check-badge state.
- Emits `choice_selected(choice_id)` without deciding whether the ID represents an avatar or frame.

## `scripts/profile_frame_catalog.gd`

Purpose:
- Loads and validates the ordered `configs/profile_frames.json` catalog on first use.
- Sanitizes unknown saved frame IDs to the configured default and resolves matching frame-texture
  paths for `ProfileAvatarView`.

Do not use for:
- Backend allowlisting or synchronization. That boundary is tracked in
  `docs/BACKEND_PROFILE_FRAMES_TICKET.md`.

## `scripts/main_menu.gd`

Attached to:
- `scenes/main_menu_testing.tscn` root `MainMenu`.

Purpose:
- Shows the testing-menu campaign play entry point for the saved current level.
- Builds the developer/test level selection grid when dev level select is enabled.
- Launches campaign or isolated dev/test levels.

Key constants:
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
- `_launch_level(level_number, launched_from_dev_mode)`: sends the accepted request, return route,
  and dev-mode metadata to `LevelTransition`.

Depends on:
- `LevelTransition` autoload
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

Attached to (self-scaling, no `visual_target_path` -- the whole button is the visual):
- `scenes/ui/level_button.tscn` root `LevelButton`.
- `scenes/ui/level_completion_screen.tscn` `NextButton`, `scenes/ui/level_failure_screen.tscn`
  `RetryButton` (UI-003; 0.94, the CTA role).
- `scenes/ui/gameplay_modal_shell.tscn` `%CloseButton` (UI-003; 0.97, the gameplay icon/close role
  -- shared by Pause, Leave Confirmation, Ability Purchase, Out of Lives, and Failure).
- `scenes/ui/level_top_hud.tscn` `%PauseButton` (UI-003; 0.97, the gameplay HUD icon-button role
  shared with the four ability buttons).
- `scenes/ui/ability_bar.tscn` `%HammerButton`/`%ShuffleButton`/`%HighlightButton`/`%FreezerButton`
  (UI-003; 0.97 -- previously had no press feedback at all).
- `scenes/pause_menu.tscn` settings icon buttons (`MusicButton`/`SoundEffectsButton`/`VibrationButton`,
  located by name via `scripts/pause_menu.gd`'s `find_child()` rather than a fixed path) and
  `LeaveButton`/`ContinueButton` (UI-003; 0.94, reparented into the shared modal shell's action row
  at runtime).
- `scenes/ui/settings_menu.tscn` settings icon buttons (same script, unrelated unchanged layout).
- `scenes/leave_confirmation_menu.tscn` `%ConfirmLeaveButton` and `%ContinueButton` (UI-003; 0.94,
  reparented into the shared modal shell's action row at runtime).
- `scenes/ability_purchase_menu.tscn` `%BuyButton` and `%WatchAdButton` (UI-003; 0.94, reparented
  into the shared modal shell's action row at runtime; `WatchAdButton` stays disabled always -- see
  docs/SCENES.md "Shared Gameplay UI Roles").
- `scenes/ui/horizontal_pager.tscn` `%PrevArrow` and `%NextArrow`.
- `scenes/ui/chapter_cover_card.tscn` `%CtaButton`.
- `scenes/ui/chapter_selection_screen.tscn` `%BackButton`.
- `scenes/ui/main_menu_chapter_button.tscn` root `ChapterButton`.
- `scenes/ui/shop_bundle_card.tscn`/`shop_coin_offer_row.tscn` `%PurchaseButton`.
- `scenes/ui/destination_status_panel.tscn` `%StatusRetryButton` (UI-002).
- `scenes/ui/shop_purchase_dialog.tscn`/`leaderboard_reward_dialog.tscn` `%CloseButton` (UI-002).
- `scenes/ui/leaderboard_screen.tscn` `%WeeklyButton`/`%CountryButton`/`%WorldButton` (UI-002).

Attached to (`visual_target_path` set -- an invisible or full-rect hit target animates a sibling/
child visual instead of itself, so its own touch rectangle never shrinks; all added in UI-002):
- `scenes/ui/main_menu_top_status.tscn` `ProfileWidget` (target `ProfileAvatarView`).
- `scenes/ui/main_menu_reward_chest.tscn` `%ChestButton` (target `Visual`).
- `scenes/ui/main_menu_bottom_navigation.tscn` `%ShopButton`/`%HomeButton`/`%LeaderboardButton`
  (each targets its own `Icon`).
- `scenes/ui/shop_bundle_card.tscn` `%HammerInfoButton`/`%ShuffleInfoButton`/`%LanternInfoButton`/
  `%FreezerInfoButton` (each targets its sibling `Stack`).

Purpose:
- Shared press-feedback owner for every interactive role in the UI-002 interaction system (see
  `docs/SCENES.md`'s "Shared Interaction Roles"). Animates press-in/release through a killable
  tween using `scripts/ui_motion.gd`'s `PRESS_IN_DURATION`/`RELEASE_DURATION` (previously an instant
  snap) instead of `button_down`/`button_up` directly setting `scale`.
- Restores the released scale -- with no animation -- on: disabling mid-press (polled every frame
  only while held, since `Button.disabled` emits no signal of its own), hiding, exiting the scene
  tree, and the application losing focus (backgrounded mid-press). A normal release, including
  release outside the button (Godot reports `button_up` the same either way), animates back instead
  of snapping. Any in-flight tween is always killed before a new one starts, so rapid repeated
  presses never accumulate scale.

Exports:
- `held_scale`: visual scale multiplier while the pointer or touch is held down, defaulting to
  `0.94` (the primary/secondary CTA and Retry/dialog-dismiss role). Compact tabs, bottom
  navigation, icon buttons, and clickable cells set `0.97` explicitly in their scene. The gameplay
  scope (UI-003) follows the same two roles: `0.94` for CTAs and the warm Pause/settings control
  (Leave/Continue/Buy/WatchAd/completion and failure actions), `0.97` for ability and gameplay-modal
  close icon buttons.
- `visual_target_path`: optional `NodePath`, relative to the button, of the `Control` to animate
  instead of the button itself. Empty (the default) animates the button's own scale.

Use when:
- Adding future visible game UI buttons, including image buttons, icon toggles, and generated scene buttons that should visually press inward while held.
- Wrapping an art-only or full-cell tap target: set `visual_target_path` to the sibling/child that
  should visibly react, so the touch rectangle and responsive layout never shrink.

Do not use for:
- Text input controls or non-button puzzle item input.

## `scripts/ui_motion.gd`

Class:
- `UIMotion` (`RefCounted`, all `static func`, no instance needed)

Purpose:
- Shared motion tokens and small tween helpers for UI-002's interaction system (Main Menu, Shop,
  Leaderboard, Chapter Selection) and UI-003's gameplay overlay/result/locked-shelf motion
  (`scripts/gameplay_modal_shell.gd`, `scripts/gameplay_result_shell.gd`, and
  `scripts/shelf_lock_overlay.gd`). Consumers `preload` this script and call its static consts/funcs
  by the preloaded constant, matching the convention in `scripts/destination_screen_layout.gd` and
  `scripts/chapters/menu_background_resolver.gd`, rather than relying on the bare global class name.

Constants:
- `PRESS_IN_DURATION` (0.09s), `RELEASE_DURATION` (0.12s): `scripts/press_scale_button.gd`'s
  press/release tween durations.
- `NAV_ACTIVE_CHANGE_DURATION` (0.165s): the bottom-navigation active icon/label transition.
- `OVERLAY_DURATION` (0.2s): destination-screen and modal-overlay fade in/out.

API:
- `fade_in(node, duration = OVERLAY_DURATION, target_alpha = 1.0)` / `fade_out(node, duration =
  OVERLAY_DURATION)`: tween a `CanvasItem`'s `modulate.a` via `retween()`. `fade_in()` also cancels
  any `close_with_fade()` still in flight for `node` (see below) and calls `show()`.
- `retween(node, meta_key)`: kills whichever tween the same `(node, meta_key)` pair last started (if
  still running, tracked via node metadata) and returns a freshly created, identically-tagged tween.
  The shared primitive behind every per-node animation in this system, so rapid repeated triggers
  never accumulate competing tweens on the same property. Use a distinct `meta_key` per independent
  concern when one node needs more than one concurrently-running animation.
- `stop_tween(node, meta_key)`: kills and clears a `retween()`-tracked tween without starting a
  replacement -- used to explicitly stop a looping animation (the status panel's loading pulse).
- `close_with_fade(node, on_finished, duration = OVERLAY_DURATION)`: fades `node` out, then calls
  `on_finished` (`queue_free` for a one-shot modal, `hide` for a reusable dialog) exactly once. A
  repeat call while already closing is ignored. Waits on a plain timer rather than the fade tween's
  own `finished` signal, because `fade_in()` is allowed to kill that tween mid-flight if `node` is
  legitimately re-shown before its previous close finished, and a killed tween never emits
  `finished` -- which would otherwise strand this coroutine (and its "closing" guard) forever. A
  generation token detects that supersession: a stale close whose token no longer matches quietly
  does nothing instead of hiding/freeing a node someone already reopened. Also guards against `node`
  itself being freed while this coroutine is still awaiting its timer (a `queue_free()` elsewhere,
  or the owning scene tearing down): `is_instance_valid(node)` is checked before touching it again,
  so a freed node is treated the same as any other stale/superseded close -- a quiet no-op instead
  of a script error trying to read metadata off a freed object.

Used by:
- `scripts/press_scale_button.gd` (press/release timing).
- `scripts/main_menu_bottom_navigation.gd` (active icon/label transition).
- `scripts/destination_status_panel.gd` (loading pulse).
- `scripts/gameplay_modal_shell.gd`, `scripts/gameplay_result_shell.gd`, and
  `scripts/shelf_lock_overlay.gd`'s chain/count/lock feedback.
- `scripts/production_main_menu.gd`, `scripts/chapters/chapter_selection_screen.gd`,
  `scripts/profile_menu.gd`, `scripts/reward_chest_menu.gd`, `scripts/shop_purchase_dialog.gd`,
  `scripts/leaderboard_reward_dialog.gd`, `scripts/shop_screen.gd`, `scripts/leaderboard_screen.gd`
  (overlay/destination fade in/out).

## `scripts/haptics/haptics_manager.gd`

Registered as:
- The `HapticsManager` autoload in `project.godot`, after `PlayerProgress` (it reads the saved
  device-local vibration setting).

Purpose:
- Accepts semantic `play(event_id, context)` requests from gameplay and economy UI instead of
  allowing scenes to call `Input.vibrate_handheld()` directly.
- Runs only one pattern at a time. Higher-priority events invalidate the queued remainder of lower-
  priority feedback; lower-priority requests are dropped until the important pattern finishes.
- Applies per-event cooldowns, optional bounded count-based amplitude scaling, and an independent
  capture/test mute. Headless runs start muted.
- Emits `event_played` once per accepted event and `pulse_played` for each realized pattern step.
  Tests inject a `(duration_ms, amplitude)` provider through `set_vibration_provider()`; production
  falls back to `Input.vibrate_handheld()` on mobile/Web.
- `acknowledge_vibration_toggle()` previews enabling normally and permits one forced final pulse
  after disabling. `cancel_active_pattern()` invalidates delayed pulses immediately.

## `scripts/haptics/haptics_catalog.gd`

Purpose:
- Defines the approved event ids and their fallback pulse patterns, priority, cooldown, and
  optional match-count scaling in one data-only owner.
- Keeps each pulse at or below 70 ms and 0.75 amplitude. Native platform bridges can preserve these
  semantic ids while mapping them to device-tuned selection, impact, success, and warning effects.
- See `docs/HAPTICS.md` for the complete event policy and physical-device verification boundary.

## `scripts/audio/sfx_manager.gd`

Registered as:
- The `SfxManager` autoload in `project.godot`, after `PlayerProgress` (it reads the saved
  sound-effects setting).

Purpose:
- The single sound-effect playback owner for the whole game (AUDIO-001). Gameplay, Main Menu,
  Chapter Selection, Shop, Leaderboard, and every modal reach playback through
  `SfxManager.play(event_id, context)`. Nothing else creates an `AudioStreamPlayer` for a shared
  cue, so there is exactly one path that can double-trigger, one place that honours the saved
  setting, and one pool that bounds how many transients overlap.
- Owns a fixed pool of 16 `AudioStreamPlayer` children, all routed to the dedicated `SFX` bus from
  `assets/audio/default_bus_layout.tres`. The bus sends to Master, whose enabled hard limiter has a
  -1 dB ceiling; tests treat that as emergency overlap protection, not as a substitute for a
  balanced pre-limiter mix.

Playback rules:
- Every request re-reads `PlayerProgress.is_setting_disabled(&"sound_effects")`, so a setting
  changed on any screen applies immediately and survives scene changes and restart.
- Disabling sound effects also stops everything currently sounding.
- A pool with no free player reclaims the requesting event's own oldest instance first, so a rapid
  burst keeps its newest cue rather than its oldest; only then does it reclaim the globally oldest.
- Variant pools never repeat the immediately previous variant, and pitch variation stays inside the
  catalog's narrow per-event window. A pool may declare `stream_volume_offsets_db`; the manager
  applies the selected stream's correction before bounded random variation so variants can be
  loudness-matched without duplicating semantic events.
- A missing event id or unloadable stream warns once and returns null; it never blocks the gameplay
  or UI action that asked for it.

Key methods:
- `play(event_id, context = {})`: returns the started player or null. `context` accepts `count`
  (count-scaled reward cue), `volume_offset_db`, `pitch_scale`, `force` (bypasses the mute check --
  only the sound-effects toggle acknowledgement uses it), `bypass_cooldown`, and
  `start_position_seconds` for synchronizing a long authored cue to gameplay state.
- `stop_all(except_player = null)`: stops every sounding cue, optionally sparing one acknowledgement.
- `stop_event(event_id)`: stops one semantic cue without cutting off unrelated feedback; the level
  uses it to suspend the 30-second critical-timer bed during pause, Freezer, and terminal states.
- `is_enabled()` / `set_muted(is_muted)` / `is_muted()`: `set_muted` is the capture/test mute,
  independent of the player-facing setting. A headless run starts muted, so automated tests never
  need an audio device; `scripts/tools/capture_scene.gd` mutes explicitly because captures run
  windowed. Audio tests opt back in with `set_muted(false)`.
- `notify_sound_effects_setting_changed()`: silences active cues after a disable.
- `acknowledge_sound_effects_toggle(is_disabled)`: the deliberate settings-toggle behavior --
  switching Off acknowledges the accepted press and then mutes everything else; switching On
  acknowledges immediately after enabling.
- `set_button_click_suppressed(button, is_suppressed = true)` / `is_button_click_suppressed(button)`:
  the scene-facing way to keep the generic click off a button.
- `get_active_play_count(event_id = &"")`, `get_player_pool_size()`, `reset_playback_state()`:
  observable bookkeeping used by the audio tests instead of asserting on audible output.

Signals:
- `event_played(event_id, context)`: emitted only when a request actually starts sounding, after the
  mute, cooldown, catalog, and pool checks.

## `scripts/audio/sfx_catalog.gd`

Purpose:
- The one AUDIO-001 event catalog: every sound effect the game can play with its streams, mix trim,
  volume/pitch variation, cooldown, and polyphony budget. Gameplay and UI scripts never preload an
  `AudioStream`; they pass `SfxCatalogScript.EVENT_*` to `SfxManager.play()`, so rebalancing the mix
  or swapping a variant pool is a change to this file alone.
- Holds the original eleven AUDIO-001 events: `item_select`, `item_place_valid`, `match_clear`,
  `star_hud_arrival`, `timer_critical_tick`, `time_up`, `coin_gain`, `coin_spend`,
  `shop_purchase_success`, `reward_chest_star_arrival`, `ui_click`; plus semantic authored-source
  events for sticky rejection, shelf unlock, Hammer, Shuffle, Lantern, Freezer, level completion,
  and level failure.
- Every event declares a `loudness_class` from `scripts/audio/sfx_loudness_standard.gd` and
  `docs/AUDIO_LOUDNESS_STANDARD.md`. `volume_db` places the whole event in that hierarchy, while
  optional `stream_volume_offsets_db` corrects only differences inside a variant pool.
- `item_place_valid` and `match_clear` keep the project's existing source recordings
  (`assets/audio/item_place_valid/item_place.wav`,
  `assets/audio/match_clear/triple_clear.wav`). Every source lives in the folder named for its
  catalog event; only paths listed by `assets/audio/generated_sfx_manifest.json` are owned by the
  deterministic generator.
- Runtime `time_up` uses the supplied authored `assets/audio/time_up/times_up2.mp3`, synchronized
  to the HUD snap and modal settle. The generator-owned `time_up.wav` remains reproducible and
  validated as part of the original palette but is no longer the catalog stream.
- Runtime `coin_gain` uses the selected authored Epidemic Sound WAV at
  `assets/audio/coin_gain/coin_gain.wav`. It retains its original stereo 96 kHz/24-bit PCM source
  and is deliberately excluded from `generated_sfx_manifest.json` so regeneration cannot replace
  it.
- `cartoon_gum_pop.wav` retains its supplied 48 kHz, 16-bit mono PCM encoding.
  `purchase_successful.wav`, `shuffle.wav`, and `timer_tick.wav` are committed as 48 kHz, 16-bit
  PCM because Godot 4.6.2 could not import their supplied 96 kHz, 24-bit WAVE-Extensible encoding.
  Their channels and audible content are otherwise retained.
- `star_hud_arrival` carries a `count_scaling` block so a multi-star reward becomes one bigger cue
  instead of one full-volume sound per star.
- `reward_chest_star_arrival` uses a 200 ms, smoothly faded derivative of `star_hud_arrival.wav`
  while retaining its own per-impact volume variation, cooldown, and polyphony settings. Its narrow
  0.995–1.005 pitch window avoids a random tonal cluster during rapid arrivals.

## `scripts/audio/sfx_loudness_standard.gd`

Purpose:
- Machine-readable master, source-peak, runtime-peak, variant-spread, and per-category maximum
  momentary loudness targets. It is the test-facing counterpart to
  `docs/AUDIO_LOUDNESS_STANDARD.md`; both must change together.
- Defines ordinary-play ranges separately from burst ceilings so pitch/volume variation and bounded
  count scaling cannot silently turn a compliant base event into an oversized burst.

## `scripts/audio/ui_click_binder.gd`

Owned by:
- `scripts/audio/sfx_manager.gd`, which instantiates it as its `UiClickBinder` child.

Purpose:
- The single generic `ui_click` policy. It watches `SceneTree.node_added` and binds every
  `BaseButton` -- authored in a scene or created at runtime -- exactly once, so no screen has to
  remember to wire a click and no button can end up with two generic owners.
- Plays on the accepted `pressed` action, never on pointer-down, so a press released outside the
  button stays silent. Disabled buttons never emit `pressed`, and a button that is not visible in
  the tree is ignored.
- Binding is recorded on the button itself, so rebinding, reparenting, pooling, or re-entering the
  tree cannot produce a second click.
- A button carrying the `sfx_click_suppressed` meta stays silent. Set it through
  `SfxManager.set_button_click_suppressed()`. Current users: the already-active destination tab in
  `scripts/main_menu_bottom_navigation.gd` (a documented no-op) and the `SoundEffectsButton` in
  `scripts/pause_menu.gd` (which owns a complete replacement cue).

## `scripts/tools/generate_core_sfx.gd`

Purpose:
- Writes the project-owned, deterministic core SFX palette to event-named folders under
  `assets/audio/` and records their relative paths in `assets/audio/generated_sfx_manifest.json`.

Regenerate with:

```powershell
& 'D:\Godot\godot.exe' --headless --path . --script res://scripts/tools/generate_core_sfx.gd -- --regenerate
& 'D:\Godot\godot.exe' --headless --path . --import
```

- The second command re-imports the new WAVs. A generation without an import leaves the catalog
  pointing at stale audio.
- Options after the `--` separator: `--regenerate` allows replacing outputs recorded under a
  different generator version; `--output-dir=<res path>` writes elsewhere.
- Refuses to overwrite outputs whose `generated_sfx_manifest.json` records a different generator
  version (or WAV files with no manifest at all) unless `--regenerate` is supplied.
- Prints every output path, duration, sample rate, peak level, and DC offset, and fails if any cue
  exceeds the -1 dBFS ceiling.
- Deliberately does not synthesize replacements for `item_place.wav`, `triple_clear.wav`, the
  authored `coin_gain.wav`, the authored 30-second timer bed, or the authored shop-purchase
  confirmation.

## `scripts/tools/export_sfx_loudness_manifest.gd`

Purpose:
- Serializes the typed SFX catalog and machine-readable loudness classes to a temporary JSON file
  for the PowerShell/FFmpeg audit. It keeps the audit from parsing GDScript source text and is not
  part of the shipped game.

## `scripts/tools/audit_sfx_loudness.ps1`

Purpose:
- Inventories every WAV/MP3/Ogg/FLAC/M4A/AAC/Opus file under `assets/audio`, measures 400 ms maximum
  momentary and integrated BS.1770 loudness, RMS/sample peak, decoded true peak, duration, and hash,
  then applies catalog event and per-stream gains to validate every runtime cue against its class.
- Enforces the -1 dBTP source ceiling, one-LU variant spread, class ordinary/burst ranges, and the
  committed `assets/audio/sfx_loudness_measurements.json` hashes.
- Renders the required pre-limiter overlap scenarios with catalog gains, count scaling, variation,
  cooldown spacing, and polyphony. A scenario fails above 0 dBTP or -14 LUFS-M.
- Requires `ffmpeg` and `ffprobe`; pass `-FfmpegPath`/`-FfprobePath` when they are not on `PATH`.
  `-UpdateSnapshot` rewrites the committed measurement snapshot only after review, and
  `-SkipOverlap` narrows a diagnostic run without changing the normal gate.

## `scripts/tools/build_reward_chest_arrival.ps1`

Purpose:
- Deterministically derives the short per-impact reward-chest cue from the authored
  `star_hud_arrival.wav` without changing the HUD source.
- Keeps 200 ms and applies a raised-cosine fade from 160–200 ms so the cue reaches silence before the
  event's three-voice limit would need to cut a tail during the standard 90 ms arrival cadence.

Run from the repository root with:

```powershell
& .\scripts\tools\build_reward_chest_arrival.ps1
& 'D:\Godot\godot.exe' --headless --path . --import
```

## `scripts/tools/core_sfx_synthesis.gd`

Purpose:
- All synthesis for the generated palette: the committed cue table (name, recipe, variant, seed,
  duration, authored peak), the recipes, the WAV encoder, and the measurement helpers.
- Tool-side only -- nothing in the shipped game loads it. `tests/audio/test_core_sfx_assets.gd`
  re-renders the same cues in memory and compares them byte-for-byte with the committed files.
- Self-contained arithmetic (a fixed xorshift PRNG, additive partials, one-pole filters) so the same
  seeds and parameters produce the same PCM on every run. Do not introduce Godot's global RNG, time,
  or frame state.
- Every cue is mono 16-bit PCM at 44.1 kHz, DC-blocked, edge-faded, and scaled to its own authored
  peak. Cues are deliberately not loudness-matched; relative balance remains intentional before
  catalog trims.
- `GENERATOR_VERSION` gates the generator's overwrite guard. Bump it whenever a recipe, seed, or
  parameter changes.

## `tests/audio/*.gd`

- `tests/audio/test_core_sfx_assets.gd`: generator determinism, the committed files matching a fresh
  render, the manifest, and per-file encoding/duration/peak/DC/fade constraints, plus catalog
  completeness, retained source recordings, and the absence of orphan generated assets. It also
  binds `assets/audio/sfx_loudness_measurements.json` to every committed audio file by SHA-256 and
  enforces the source true-peak ceiling, event-class ranges, burst ceilings, and variant spread
  without needing FFmpeg during the Godot test.
- `tests/audio/test_sfx_manager.gd`: bus routing, pool reuse, per-event polyphony and cooldown,
  variant selection, missing-event/missing-stream safety, count scaling, both mute paths, setting
  persistence across a scene change, and the generic button-click policy.
- `tests/audio/test_sfx_event_wiring.gd`: which owner asks for which event -- accepted landings
  versus invalid returns, item selection, the HUD-driven critical countdown and its final-five
  accent, one `time_up` per accepted expiry, coin spending, Shop grant routing, and reward-chest
  arrivals versus silent reconciliation.

All three run through `scripts/tools/run_isolated_godot_test.ps1 -Script <path>`.

## `scripts/level_completion_screen.gd`

Class:
- `LevelCompletionScreen`

Attached to:
- `scenes/ui/level_completion_screen.tscn` root `LevelCompletionScreen`.

Purpose:
- Owns the completed-level reward overlay UI shown by `level.tscn` after all items clear.
- Composes `scenes/ui/gameplay_result_shell.tscn` for the shared terminal shade, hero title, action
  placement, safe-area layout, and open/close fade (UI-003; see docs/SCENES.md "Shared Gameplay UI
  Roles"). Keeps its own star image/earned-count placement, which stays local rather than moving
  into the shell since it is state-specific (not shared with `scripts/level_failure_screen.gd`).
- Sizes the earned-star label for longer totals and emits `next_pressed` when the player taps the
  action button, which now reads `Continue` (same return-to-menu behavior as before -- signal name
  unchanged to minimize churn in `scripts/level.gd`).
- Plays the Completion-specific motion sequence: title pop, reward-star overshoot/rotation, earned
  count bounce, action rise, and five responsive colored paper-star glints. The action stays disabled
  until the 0.92-second intro settles, then the glints enter a restrained idle twinkle.

Key methods:
- `apply_safe_layout(safe_margins, viewport_size)`: delegates shade/title/action placement to the
  shell, then positions the star image/earned-count label using the shell's shared
  `GameplayUITheme.get_result_title_scale()` responsive scale (renamed from
  `apply_responsive_layout(safe_margins)` for a consistent signature across every level
  overlay/result screen).
- `set_earned_stars(stars)`: updates the `×N` reward label and reduces font size when the value is long.
- `is_transitioning()` / `open()` / `close()`: combine the shell fade and Completion intro state;
  opening resets/restarts all focused tweens, while closing kills intro/idle glint tweens before the
  shell fade.

Depends on:
- `scenes/ui/gameplay_result_shell.tscn` (`scripts/gameplay_result_shell.gd`).
- `scripts/gameplay_ui_theme.gd` for the shared responsive scale.
- `scripts/press_scale_button.gd` on `NextButton`.
- `assets/ui/reward_star.png`, `assets/effects/confetti_paper_star.png`, and the shared
  `style_box_green_primary_button.tres`.

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
- `completion_stars_by_level`: explicit completed global-level set and earned stars; source of truth
  for chapter progress and replay prevention.
- `selected_chapter_id`: currently selected unlocked chapter, stored with device preferences.
- `lives`: current campaign lives, clamped from `0` to `5`.
- `next_life_restore_unix`: Unix timestamp for the next hourly life restore, or `0` when lives are full.
- `coins`: current gold coin balance. Fresh saves start at `300`.
- `ability_uses`: remaining campaign uses for hammer, shuffle, highlight/Lantern, and Freezer.
- `processed_shop_purchase_ids`: transaction ids whose Shop rewards were already applied locally.
- `purchased_shop_offer_ids`: offer ids purchased through the local/mock Shop, used to persist
  once-per-account lifetime eligibility across reloads.
- `avatar_id`: selected profile avatar id. Fresh and legacy saves default to `avatar_cat`.
- `avatar_frame_id`: authoritative public cosmetic frame. Schema-7 and older saves default to
  `frame_classic`; a non-default schema-8 local selection migrates once into a signed frame-only
  `profile_edit`.
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
- `get_completed_level_stars()` / `is_level_completed()`: expose the explicit completion set.
- `get_selected_chapter_id()` / `select_chapter()`: read or persist an unlocked chapter selection.
- `is_chapter_unlocked()`, `get_completed_level_count()`, `get_next_level_for_chapter()`, and
  `get_chapter_progress()`: derive chapter access and UI progress from explicit completions.
- `get_ability_uses()`: returns remaining campaign ability uses.
- `get_coins()`: returns the saved gold coin balance.
- `get_total_earned_stars()`: returns the lifetime leaderboard score.
- `get_weekly_earned_stars()`: resets an expired weekly period when needed and returns the current weekly score.
- `get_current_leaderboard_week_start_unix()`: returns the current Monday 00:00 UTC boundary.
- `get_current_leaderboard_week_end_unix()`: returns the next Monday boundary used by the UI countdown.
- `spend_coins(amount, reason)`: atomically subtracts coins and appends a resource-spend operation;
  `time_extension` is the dedicated reason for the recoverable-timeout purchase.
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
- `get_reward_chest_goal_coin_reward_at_index(goal_index)`: the coin reward attached to one
  specific goal, for owners animating past goals the player has already crossed (the Main Menu's
  staggered star flight). Read-only; the grant itself still happens once inside the chest-star
  application.
- `get_reward_chest_progress()`: returns the saved reward chest stars, active goal, and goal index.
- `get_reward_chest_goal_at_index(goal_index)`: exposes a configured goal threshold for menu animation rollover.
- `consume_pending_reward_chest_animation()`: returns and clears the in-memory completed-level animation payload.
- `add_reward_chest_stars(star_count)`: adds stars to the reward chest and rolls over reached goals.
- `get_available_avatar_ids()`: returns the 18 valid profile avatar ids.
- `get_available_avatar_frame_ids()`: returns the ordered frame IDs from
  `configs/profile_frames.json`.
- `get_avatar_id()`: returns the selected avatar id, sanitized to `avatar_cat` when needed.
- `get_avatar_frame_id()`: returns the selected frame id, sanitized to the configured default.
- `get_avatar_texture_path(avatar_id)`: returns the resource path for a valid or sanitized avatar id.
- `get_player_name()`: returns a non-empty saved or generated player name.
- `get_disabled_settings()`: returns saved disabled states for the settings buttons.
- `is_setting_disabled(setting_id)`: returns one saved settings-button disabled state.
- `set_setting_disabled(setting_id, is_disabled)`: validates, stores, and saves one settings-button disabled state.
- `set_avatar_id(avatar_id)`: validates, stores, and saves the selected profile avatar.
- `set_player_name(player_name)`: trims, stores, and saves a non-empty player name.
- `set_profile(avatar_id, player_name)`: backward-compatible avatar/name save that preserves the
  current frame.
- `set_profile_customization(avatar_id, avatar_frame_id, player_name)`: atomically saves all three
  authoritative public fields and journals the exact changed subset, including frame-only edits.
- `get_lives()`: refreshes and returns current campaign lives.
- `get_max_lives()`: returns the lives cap.
- `get_life_purchase_coin_price()`: returns the positive bundled value from
  `configs/life_purchase.json` (500 by default).
- `purchase_life()`: atomically spends the configured coins, grants exactly one life, preserves the
  active restore deadline unless the cap is reached, and appends one `life_purchase` journal entry.
- `get_next_life_restore_seconds_remaining()`: returns seconds until the next life restore, or `0` when full.
- `refresh_lives()`: restores one life per elapsed real-time hour while lives are not full.
- `spend_life(level_number, outcome)`: atomically appends the attempt and resulting life state.
- `apply_authoritative_life_state(life_state)`: mirrors a life state already committed by an online
  run without appending a duplicate local-first spend operation.
- `spend_ability(ability_id)`: validates one of the four canonical ability ids, then immediately
  spends, journals, and saves one campaign ability use.
- `complete_level(level_number, earned_stars)`: accepts only the next incomplete level in an
  unlocked chapter, rejects replay, and atomically records completion, advancement,
  lifetime/weekly/chest totals, immediate chest coins, and reward-animation metadata.
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
- `configs/life_purchase.json`
- `ChapterCatalog` autoload and `configs/chapters.json`

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
  checkpoint with no Freezer field preserves the local schema-5-or-newer Freezer balance before replaying
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
  complete Chapter 1 levels 1-10 mapping at runtime.
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
- GAME-007 shared authenticated transport for bodyless v1 `GET` reads, extended by ADS-003 with a
  standard body-bearing protocol POST used by online-run and reward-intent contracts.
- `configure(session_store, active_player_id_provider)` wires an existing `SecureSessionStore` and
  a `Callable` that resolves the current active player id; `PlayerProgress` is the only configured
  owner today (`get_backend_transport()`).
- `get_json(path)` issues one bodyless `GET` at `path` (e.g. `/v1/catalog`) with an
  `Authorization: Bearer` header and a client-generated `X-Correlation-ID`, never an invented
  request body or protocol/app header. Returns `{"ok": true, "data", "meta"}` or
  `{"ok": false, "error": {"code", "category", "message", "retryable", "retry_after_seconds",
  "correlation_id", "http_status"}}`.
- `post_json(path, protocol_version, data, expected_state_version, idempotency_key,
  retry_transient)` builds the device/session/app envelope, retains a stable request id and
  idempotency key across bounded transient retries, validates the echoed request/protocol and
  authoritative state version, and performs the same single refresh-and-replay on `401`.
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
- Save-sync journal mutation traffic or guest bootstrap. Those retain their dedicated persisted
  retry/state machines in `scripts/save/save_sync_service.gd` and
  `scripts/save/guest_session_bootstrap_service.gd`.

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
- All four buttons share the circular ability icon-button role
  (`style_box_gameplay_hud_icon_*.tres`, including an explicit disabled state), use
  `press_scale_button.gd` (0.97 held scale -- these had no press feedback at all before UI-003),
  and carry a `tooltip_text` (Freezer no longer has unique visible button text; all four are
  icon-only). Use-count badges and Lantern/Freezer timer badges use the shared
  `style_box_gameplay_count_badge.tres`/`style_box_gameplay_timer_badge.tres` resources.

Key methods:
- `set_uses(ability_uses)`: fits longer numeric values down to the shared badge minimum font size
  after both regular and compact layout changes, using `GameplayUITheme.COUNT_BADGE_*` constants
  shared with locked-shelf counters.
- `set_interaction_blocked(is_blocked, lantern_active, freezer_active)`: updates disabled state,
  mutually locks the two timed abilities while either is active, and restores the arrow cursor for
  blocked actions.
- `set_active_seconds(ability_id, seconds_remaining)`.
- `get_icon_texture(ability_id)`.
- `get_ability_button(ability_id)`.
- `apply_responsive_layout(usable_width)`: switches between `GameplayUITheme`'s compact (98.4px),
  safe-inset-scaled compact, and regular (115.2px) ability icon sizes. Also captures each button's
  authored regular Icon/UsesLabel/TimerLabel rects once at
  `_ready()` and rescales them proportionally to the actual button size (UI-003) -- previously only
  the parent button resized, so the icon and both badge types stayed at their regular offsets and
  overflowed the smaller compact button. `scripts/level.gd` passes the safe-inset-adjusted usable
  width, not raw viewport width.

Depends on:
- `scripts/gameplay_ui_theme.gd` for the shared compact/regular HUD icon sizes and breakpoint.
- `scripts/press_scale_button.gd`.

## `scripts/level.gd`

Attached to:
- `level.tscn` root `Level`.

Purpose:
- Owns active level state, runtime shelf creation, item spawning, input handling, matching, abilities, timer, failure, and completion.
- Exposes the `prepare_for_loading_transition()` / `activate_after_loading_transition()` gate used by
  `LevelTransition`; while pending it blocks input and frame updates, pauses moving shelf rows, and
  postpones the initial shelf resolution until the board is fully revealed.

Audio (AUDIO-001):
- Plays no audio itself. `_play_sfx(event_id, context)` is the level's only route to sound and
  forwards to the `SfxManager` autoload; the retired per-level `ItemPlaceAudio`/`TripleClearAudio`
  players are gone, along with their volume exports (the mix now lives in
  `scripts/audio/sfx_catalog.gd`).
- `_sound_effects_enabled` remains as the level-local gate that automated captures and tests set
  (`scripts/tools/captures/*.gd`). The saved sound-effects preference is applied on top of it by
  `SfxManager`, including Hammer's replacement shared cue.
- `item_select` fires from `_handle_release_at()` only when a finished tap actually selected an
  eligible item; a press that became a drag or targeted an ineligible shelf never reaches it.
- `item_place_valid` fires from `_place_item_in_slot(..., should_play_landing = true)` and from
  `_play_item_move_animation(..., is_accepted_landing = true)`. `_return_item_to_origin_after_animation()`
  passes `false`: an invalid or no-target return still plays the visible landing impact but must
  never sound like an accepted move.
- `match_clear` stays on the existing post-gather disappearance beat in `_clear_matching_shelves()`.
- `star_hud_arrival` fires once per reward with `{"count": star_count}` as the HUD receive pulse
  begins, so a multi-star combo is one count-scaled cue rather than one sound per star.
- `timer_critical_tick` is now the supplied 30-second authored bed. It starts once on critical-range
  entry, seeks to the displayed countdown offset after pause/Freezer, and is stopped during pause,
  Freezer, interruption, time-up, completion, failure, and scene teardown.
- `time_up` fires once when expiry opens the time-extension offer. A terminal expiry goes straight
  to the dedicated `level_failed` cue so the two result sounds never stack.
- `sticky_move_blocked` fires the short cartoon gum-pop cue only from the exposed-sticky input
  branch. Ordinary rejected drops remain silent. `shelf_unlock` fires once per threshold crossing
  even if several shelves unlock.
- Successful Lantern and Freezer starts fire `ability_lantern` or `ability_freezer`. Hammer fires
  `ability_hammer` on its authored `impact` signal, while Shuffle fires `ability_shuffle` when its
  items begin flying into the visible box; terminal transitions fire `level_complete` or
  `level_failed` once.
- `coin_spend` fires only after a successful `PlayerProgress.spend_coins()` (ability purchase,
  time extension) or `purchase_life()` (out-of-lives retry).

Collapsing columns (`gameplay_mode: "collapsing_columns"`):
- `_apply_level_config()` validates the mode through `scripts/collapsing_column_rules.gd` before any
  state is reset and fails closed on an invalid contract: it reports `_level_config_error`, builds
  nothing, and never falls back to a grid preset.
- `_add_collapsing_column_shelves()` instances `scenes/collapsing_shelf_board.tscn`, consumes the flat
  `shelves` array column by column and bottom to top, creates each shelf through the ordinary
  `_add_shelf()` / `_configure_shelf_from_config()` factory, and registers it with its authored
  index as a stable shelf ID. `_collapsing_board` is null for classic levels, and every collapsing
  branch is skipped.
- `_resolve_collapsing_visible_count()` resolves the window once per build from the same play area
  `_layout_shelves()` fits into (`_get_shelves_play_rect()`), capped by
  `max_collapsing_visible_shelves` when that is non-zero. `_get_shelves_root_child_bounds()` fits
  the board's fixed footprint, never its hidden depth.
- `_is_shelf_gameplay_available()` is the one availability rule for input, matching, promotion,
  and abilities. On a classic board it is exactly "not locked", so classic behavior is unchanged; on
  a collapsing board it also requires `CollapsingShelfBoard.is_shelf_active()`. Every former lock
  check in `_is_shelf_move_source_eligible()`, `_move_item_to_slot()`,
  `_resolve_move_target_slot()`, `_clear_matching_shelves()`, `_promote_empty_front_layers()`,
  `_find_immediate_triple_items()`, and the `_get_unlocked_items()` / `_get_visible_items()` /
  `_get_first_back_layer_items()` enumerators goes through it. Moving-row window reachability stays
  in the input helpers, because abilities deliberately still reach off-window moving shelves.
- `_resolve_shelves()` registers a whole request before starting any resolver, so a resolver that
  finishes synchronously can never declare resolution drained while the rest of its request -- for
  example the target of the move that emptied it -- has not started.
- When every resolver has drained, `_on_shelf_resolution_drained()` runs
  `_collapse_emptied_shelves()` on a collapsing board: it finds active shelves with no committed
  items (a drag origin is never empty), cancels any active drag or selection, releases every
  reference to the shelves, and awaits one `CollapsingShelfBoard.collapse_shelves()` batch. Revealed
  shelves, plus any resolution requested while the collapse ran, go back through `_resolve_shelves()`,
  whose drain returns here, so the loop repeats until nothing is left empty. It skips while Shuffle
  has items parked in the drag layer; Shuffle re-resolves the whole board when it ends.
- `_is_collapse_in_progress()` blocks `_input()`, ability buttons, `_can_apply_ability()` (before any
  use is spent), and completion. It is not an ability effect, so the countdown keeps running exactly
  as it does through match-clear animations, and Freezer does not stop column movement.
- `_check_level_completed()` completes a collapsing level only when the board reports no surviving
  shelf and nothing is resolving or collapsing, so the last shelf's destruction plays first.
- Pause and backgrounding follow the existing policy for gameplay animations: the collapse keeps
  running under the pause menu. The new order is committed before any tween starts, so every
  interruption point leaves a consistent board. Retry rebuilds the board from config.

Important exports:
- `slot_snap_distance`: maximum snap distance for drag or tap placement, sized for the wider shelf spacing.
- `item_pick_size`: rectangle used to detect clicked or touched visible items at the default item scale.
- `drag_start_distance`: pointer movement required to convert a press into a drag.
- `layer_promotion_duration_seconds`: duration for back-layer items to slide forward into active front slots.
- `item_move_duration_seconds`: duration for moved items to slide into destination slots after tap or drag placement, including invalid drag returns.
- `highlight_outline_color`: border color used by the highlight ability.
- `selected_outline_color`: white silhouette-border color used by ordinary tap selection; it takes visual priority if Lantern also highlights the selected item.
- `highlight_outline_width`: screen-pixel thickness of the item outline border, kept even around the item silhouette by the outline shader's dilation.
- `selected_item_forward_offset`: local downward offset that moves selected or Lantern-highlighted item art, outline, shadow, and hit area toward the shelf's front edge without changing its logical slot position.
- `match_gather_duration_seconds`: duration for side items to pull into the center item when a triple clears.
- `match_shrink_duration_seconds`: duration for the center item shrink-out after a triple gathers.
- `combo_window_seconds`: time allowed after a triple clear to extend the active combo before the center HUD combo label and fill disappear.
- `level_duration_seconds`: fallback duration if config does not define `time_seconds`.
- `selected_level`: global campaign level ID loaded from `configs/levels/level_%03d.json`; the HUD
  displays its chapter-local level number.
- `max_collapsing_visible_shelves`: caps how many shelves per column a collapsing board may reveal
  when the screen has room for more; `0` lets the screen decide. It never lowers a level below its
  authored `visible_shelves_per_column`. Tests and captures use it to pin the window.
- `launched_from_dev_mode`: makes a level use isolated temporary ability counts and return to the menu instead of saving campaign progress.
- `return_menu_scene_path`: menu scene path used by Leave and dev/test completion returns.

Important constants:
- `SLOT_COUNT`: currently three items per shelf front layer.
- `SLOT_ITEM_POSITION`: item local position that matches `scenes/shelf.tscn` item snap markers.
- `SHELF_CELL_VISUAL_SCALE`: slight runtime scale applied to generated shelf instances so shelf art and item children enlarge together.
- `SHELF_BASE_CELL_SIZE`: unscaled reusable shelf scene bounds from `scenes/shelf.tscn`.
- `SHELF_CELL_SIZE`: scaled reusable shelf scene bounds; three cells in a row are packed to fill most of the 720 px gameplay viewport, with compact vertical row spacing.
- `SHELF_SHARED_EDGE_THICKNESS`: shelf boundary thickness that neighboring cells overlap.
- `SHELF_AUTHORED_GRID_STEP`: original interlocked layout-template step before the taller-frame
  allowance is applied.
- `SHELF_ROW_HEIGHT_EXTENSION`: scaled 10.282 px vertical allowance for the standard frame's 10%
  taller opening.
- `SHELF_GRID_STEP`: packed layout spacing after overlapping shared shelf edges and adding the
  taller-frame allowance vertically; its effective Y step is 144.902 px.
- `DISPENSER_LOWER_CLEARANCE`: per-dispenser upward offset used when another row follows, leaving
  room for the attached stock meter without moving standard neighbours out of the interlocked grid;
  this 32px conditional clearance is additional to the dispenser scene's authored 10px root lift.
- `LAYOUT_ROW_VERTICAL_EPSILON`: tolerance used to group authored layout-template shelf markers into horizontal rows before assigning left/middle/right/single shelf visuals. Dispenser markers are excluded from the standard-shelf edge ordering because dispensers carry complete independent frames.
- `ABILITY_BAR_*`, `SHELVES_*`: responsive layout constants for positioning the ability bar and
  generated shelf root across portrait viewport sizes, including the back-wall bottom boundary and
  minimum/maximum shelf layout scale. `SHELVES_BACK_WALL_BOTTOM_MARGIN` is 224 design pixels,
  matching the top of the doubled-height (68 px) baseboard in `level.tscn`; the playable area loses
  34 pixels vertically without moving the floor or ability bar. Shelf boards center against the visible back wall instead of
  being pulled upward by the floor-level ability overlay. The top HUD, gameplay modals, and terminal result screens now own their own responsive
  layout (UI-003) -- see `scripts/level_top_hud.gd`, `scripts/gameplay_modal_shell.gd`, and
  `scripts/gameplay_result_shell.gd` below; `level.gd` only calls each one's
  `apply_safe_layout(safe_margins, viewport_size)`.
- `SHELF_SCENE`: `res://scenes/shelf.tscn`.
- `MOVING_SHELF_ROW_SCENE`: `res://scenes/moving_shelf_row.tscn`.
- `MOVING_SHELF_SCENE`: `res://scenes/moving_shelf.tscn`, the independent art/slot scene used by
  `_add_moving_shelf_row()` via `_add_shelf()`'s scene override. Static and dispenser creation keep
  their existing scene paths; this adds no new level-config shelf type.
- `ITEM_SCENE`: `res://scenes/item.tscn`.
- `ITEM_SPRITES_CONFIG`: `res://configs/item_sprites.json`.
- `ABILITY_PURCHASE_PRICES_CONFIG`: `res://configs/ability_purchase_prices.json`.
- `TIME_EXTENSION_CONFIG`: `res://configs/time_extension.json`; client launch defaults matching the
  versioned backend economy policy (60 seconds, 500 coins, one coin use and one ad use per attempt,
  with the compiled rewarded placement enabled but provider/policy release gates still independent).
- `LEVEL_CONFIG_TEMPLATE`: `res://configs/levels/level_%03d.json`.
- `DEFAULT_LEVEL_CONFIG`: fallback level config.
- `LAYOUT_SCENE_TEMPLATE`: `res://scenes/layouts/layout_%s.tscn` path pattern used by `layout_preset`.
- `DEFAULT_LAYOUT_PRESET`: fallback layout preset.
- `MAIN_MENU_SCENE`: default scene returned to after completion.
- `SfxCatalogScript`: `res://scripts/audio/sfx_catalog.gd`, the source of the `EVENT_*` ids this
  script passes to `SfxManager` (AUDIO-001). The level no longer preloads audio streams.
- `HAMMER_IMPACT_EFFECT_SCENE`: `res://scenes/abilities/hammer_impact_effect.tscn`, spawned when the hammer ability is used.
- `COMPLETION_REVEAL_SECONDS`: 1.35-second cleared-board lead-in before the reward overlay begins;
  the longer confetti effect continues independently across that reveal.
- `SHUFFLE_BOX_TEXTURE`: `res://assets/abilities/ability_shuffle_box.png`, shown at screen center while the shuffle ability gathers and redistributes items.

Key responsibilities:
- Apply responsive layout with `_apply_responsive_layout()`: delegates the top HUD, ability bar,
  Failure/Completion result screens, and Pause/Leave Confirmation/Ability Purchase modals to their
  own `apply_safe_layout(safe_margins, viewport_size)` (UI-003 -- each owns its own safe-area
  fitting instead of `level.gd` reaching into fixed panel sizes and child paths), then scales and
  centers the generated shelf root on the room's visible back wall.
- Read display-server safe areas only on mobile platforms and only when the rectangle is contained
  by the current window. Desktop monitor work areas are not mobile insets and no longer lift the
  board and ability bar during responsive window or capture resizes.
- Keep insufficient-coins stacks paused: Ability Purchase or Time Up stays beneath
  `InLevelShopOverlay`; closing Shop restores the originating modal, while opening it never spends
  coins or consumes the pending action.
- Resize the scene-owned `Background` control. Chapter 1 restores the scene-authored wall,
  play wall, baseboard, and generated terracotta floor texture; chapters configured for `artwork` use
  `Background/ChapterArtwork`. The HUD strip remains scene-owned above either presentation.
- Load JSON configs with `_load_json_file()`.
- Instantiate reusable shelf cells with `_add_shelf()`, preserve each scene root's authored position
  as a per-type offset from the generated grid position, apply the shared shelf visual scale, assign
  left/middle/right row placement visuals for static shelves, and ask `Shelf` to add generated back
  layers. `scenes/dispenser_shelf.tscn` uses this offset to sit 10px higher than standard shelves.
- Ask each shelf scene to show or hide its placement-specific `TopCeilingCap` when it has no stacked
  neighbor above. Full-shelf bottom/right casts are handed to one level-owned
  `ShelfOuterShadowGroup`: it mirrors complete authored polygons into a shared coverage layer and
  applies the final translucency once, so staggered or irregular layouts do not need pairwise
  midpoint cuts and overlapping casts cannot double the final shadow strength.
- Load `layout_preset` scene templates from `scenes/layouts/`, group authored `ShelfXX` markers into
  rows by position, expand their logical row distances by the taller-frame allowance around the
  layout center (including proportional half-row expansion for staggered columns), and place
  runtime shelves with derived row-placement visuals.
- Build optional `row_layouts` rows with `_add_row_layout_shelves()`, including horizontal or vertical moving rows and static rows mixed in one level. Moving-row shelves currently use the neutral middle row-placement visual, and moving rows in a level must all use the same axis.
- Build moving rows declared by layout template `MovingRowXX` nodes with `scripts/shelf_layout_row.gd`; their shelves also use the neutral middle row-placement visual.
- Keep moving-row shelves out of drag/drop targeting while they are outside the row's visible window, while abilities still use unlocked shelf items.
- Spawn configured items with `_add_configured_item()`.
- Handle mouse and touch input through `_input()` and the press/motion/release helpers.
- Move items with `_move_item_to_slot()`, `_resolve_move_target_slot()`, `_play_item_move_animation()`, and `_place_item_in_slot()`.
- Treat a second tap on the selected item as a deselect through `_deselect_item_in_place()`, which `_handle_press_at()` takes before any move is attempted whenever the tapped slot is the selected item's own slot. The item settles back with the usual landing feedback and nothing moves. Routing this through `_move_item_to_slot()` instead would work only on shelves that accept dropped items, so a source-only shelf such as `scenes/dispenser_shelf.tscn` would refuse the move and the release would immediately reselect the item.
- Finish every player-visible drop with `ShelfItem.play_land_impact()`, the landing squash-and-stretch owned by `scripts/item.gd`. It fires from `_play_item_move_animation()` after the eased travel settles and from `_place_item_in_slot()` when `should_play_landing` is set. The call is never awaited, so a landing does not delay `_resolve_shelves()` and its match clears. Silent forced restores (level failure, ability interrupt) pass `should_play_landing = false` and stay unanimated. Back-layer promotion is deliberately excluded: `_play_layer_promotion_animation()` already lands with its own `TRANS_BACK` overshoot on `visual_scale`.
- Cancel a pending bounce with `ShelfItem.reset_land_impact()` before re-grabbing an item in `_begin_drag()` and before the gather in `_play_match_clear_animation()`, so the next animation never starts from a deformed pose.
- Lift the active item's ground shadow with `ShelfItem.set_drag_lifted(true)` while the player is dragging it, and settle it again when the drag releases, cancels, fails, or completes. The shadow stays parented to the item so it travels with the finger; the lift separates the silhouette farther down-right and blends in a source-alpha core so the carried shadow keeps the item's recognizable outline. `_place_item_in_slot()` also clears the lift as a safety net for paths that land an item without going through `_finish_active_drag()`.
- The level only switches an item's shadow between its resting and carried readings through
  `ShelfItem.shadow_lift`; compare the resting, mid-grab, and carried states together in
  `scenes/shadow_style_preview.tscn`.
- Redirect moves aimed at an occupied destination slot on another shelf to the nearest free front slot on that destination shelf; same-shelf occupied targets leave the item in its original slot.
- Clear triples with `_clear_matching_shelves()` and `_play_match_clear_animation()`.
- Track the active triple-clear combo with `_extend_combo()`, `_update_combo_timer()`, `_reset_combo()`, and `_update_combo_hud()`, including the shrinking center-slot fill (now rendered by `scripts/level_top_hud.gd::set_combo()`). Combo value increases by 1 per cleared triple, and each cleared triple adds stars equal to the combo value reached by that triple; `_update_star_counter_label()` forwards that number to `LevelTopHud.set_star_count()`, which owns the star pill (now a true pill, `style_box_gameplay_status_pill.tres`).
- Show combo praise words with `_show_combo_praise()` starting at 2x combo, using unique wording through 20x. Labels appear near the cleared triple or hammer impact for two seconds, then fade out; lower combos use thinner calmer outlines, while 10x+ combos use larger gold, violet, and red outlines.
- Play combo reward feedback with `_play_combo_star_reward_animation()`: after the matched items finish `_play_match_clear_animation()`, small `reward_star_34_glossy_b.png` stars drop from the cleared triple, fly into `UI/StarCounterLabel`, and pulse the counter. The number of visual stars matches the combo-earned star amount returned by `_record_triples_cleared()`.
- Track cleared triples and locked shelf accessibility with `_record_triples_cleared()`, `_update_locked_shelves()`, and shelf metadata from `unlock_after_triples`.
- Keep locked shelves out of move, match, promotion, and ability targeting, and pass remaining triple
  counts/state to their extracted `ShelfLockOverlay`. `_update_shelf_input_pickable()` remains
  independent from `play_unlock()`, so chain release never delays interaction. Hammer destruction
  continues to call `_record_triples_cleared()` and therefore decrements the same counters.
- Own ADS-006's rewarded locked-shelf unlock. `_add_shelf()` stamps `SHELF_CONFIG_ID_META` (the
  shelf's 1-based index in the level definition's `shelves` array) so a claim binds to configured
  identity rather than a node instance or screen position. `_refresh_shelf_unlock_offers()` --
  driven by `_update_ability_interaction_state()`, so it follows the same "ordinary gameplay is
  running" rule as the ability bar -- offers or withdraws each `ShelfLockOverlay`'s `AD` plate.
  `_on_shelf_unlock_requested()` answers a plate tap by opening `UI/ShelfUnlockOverlay` rather than
  an ad, and `_apply_rewarded_shelf_unlock()` records one entry in the per-attempt
  `_ad_unlocked_shelf_ids` and then reuses `_update_locked_shelves()` and `_resolve_shelves()`.
  `_triples_cleared`, stars, combo, and every shelf's configured `unlock_after_triples` are
  untouched, so other shelves keep an unchanged visible countdown.
- Play placement and triple-clear sound effects with runtime `AudioStreamPlayer` nodes.
- Track clearing items so only disappearing items ignore input and abilities during the animation.
- Track transitioning items so newly promoted back-layer items ignore input and abilities until their forward slide finishes.
- Queue shelf resolution requests made while another match animation is still finishing.
- Promote back layers with `_promote_back_layer()`, `_play_layer_promotion_animation()`, and `_advance_back_layers()`.
- Check win/loss state with `_check_level_completed()`, `_fail_level()`, and `_complete_level()`.
  Both call `open()` on their extracted screen instead of snapping `.visible = true`.
  `_fail_level()` passes the chapter-local level number into the centered `UI/FailureScreen`
  modal (`scripts/level_failure_screen.gd`);
  `_complete_level()` starts the layered paper-confetti effect, then shows `UI/CompletionScreen`
  after `COMPLETION_REVEAL_SECONDS` while pieces continue falling. The screen receives the run's
  earned star count and its action reads `Continue` (`next_pressed` signal unchanged).
- Spend one campaign life on campaign failure and on confirmed pause-menu Leave through `_spend_campaign_life_for_run()`, guarded so one level run cannot spend twice.
- Return to the configured menu scene when leaving a level, when Completion's `Continue` is
  pressed, when Failure's X is pressed, or when the retry Out of Lives offer is declined.
- Handle Failure Retry through `_on_failure_retry_pressed()`: restart immediately when a campaign
  life remains (or for dev mode), otherwise open the reusable `UI/OutOfLivesOverlay`. A successful
  `PlayerProgress.purchase_life()` restarts the same level; close/Back or a failed purchase returns
  to the originating main menu. `_restart_level()` creates a fresh `level.tscn` while preserving
  `selected_level`, `launched_from_dev_mode`, and `return_menu_scene_path`, so no failed-run shelf,
  timer, effect, or one-run life-spend state leaks into the retry.
- Keep the level countdown idle until the first meaningful player action, then format the active
  timer as zero-padded `MM:SS` text with `_update_timer_label()`, forwarded with its displayed
  integer seconds and started state to `LevelTopHud.set_timer_state()`. The HUD enters its critical
  treatment at `00:30`, so a level configured at 30 seconds or less does not alarm before the first
  player action.
- Pause and resume active gameplay through the top HUD's Pause button (`scripts/level_top_hud.gd`'s
  `pause_pressed` signal), and the instanced `UI/PauseMenuOverlay`
  (`scripts/pause_menu.gd`)/`UI/LeaveConfirmationOverlay` (`scripts/leave_confirmation_menu.gd`),
  each composing `scenes/ui/gameplay_modal_shell.tscn` (UI-003) and exposing
  `leave_pressed`/`continue_pressed`/`close_requested` signals instead of `level.gd` reaching into
  their buttons by child path. `_unhandled_input()` implements the `ui_cancel` back stack: retry
  Out of Lives returns to the main menu; Leave
  Confirmation returns to Pause; Ability Purchase restores the state it opened from (Pause if
  opened from Pause, otherwise resumes gameplay); Pause resumes; Completion/Failure invoke their
  routes; otherwise active gameplay opens Pause. Every branch reuses the exact handler its
  equivalent button already calls, and `_is_any_overlay_transitioning()` drops the press while any
  overlay/result screen is mid fade so a rapid double-press can never double-navigate.
- Initialize item placement and triple-clear sound effects from the shared sound-effects setting and keep them disabled while that toggle is crossed out.
- Manage Hammer, Shuffle, Lantern/highlight, and Freezer abilities. Campaign levels read and
  spend saved ability counts through `PlayerProgress`; dev/test levels use isolated temporary
  counts.
- Intercept the first eligible timer expiry with `_handle_level_time_expired()`: cancel the active
  drag, freeze moving shelves, keep the timer at zero, play the input-blocking
  `TimeUpTransition`, and only then pop open `TimeUpExtensionModal` before the run becomes
  terminal. The transition and supplied one-second `time_up` cue start together; its shade
  crossfades into the modal shade without exposing a bright board frame. A successful 500-coin
  request is committed with resource-spend reason `time_extension`, consumes the attempt's single
  coin slot, sets the timer to 60 seconds, and resumes the same board. Decline proceeds to normal
  Failure. The rewarded route remains paused while ADS-003 creates a server intent, shows the ad,
  and reconciles SSV; it consumes its slot and grants 60 seconds only after authoritative
  settlement. A later timeout fails immediately when both slots are consumed or unavailable.
- Keep one coin slot and one rewarded-ad slot as per-attempt runtime state, reset only when a new
  level attempt is configured. The ad action requires the placement config, `AdService`
  policy/consent/readiness, and an authenticated backend; otherwise it stays disabled and the coin
  route remains independent.
- Keep zero-use ability buttons pressable during active gameplay so `_open_ability_purchase_menu()` can pause the level and show `UI/AbilityPurchaseOverlay` (`scripts/ability_purchase_menu.gd`, composing the same shared modal shell) with the tapped ability icon, configured coin price, and current affordability state via `set_offer()`.
- Apply paid ability uses through `_can_apply_ability()`, `PlayerProgress.spend_coins()`, and
  `_apply_paid_ability()`: the local spend commits after successful preflight and before the
  gameplay effect starts, without adding saved ability inventory. The purchase menu presents this
  as "USE ABILITY" (UI-003), not an inventory acquisition.
- `_close_ability_purchase_menu(should_resume)`: `should_resume=true` (the close button and
  `ui_cancel`) restores whatever state Ability Purchase was opened from -- re-opens Pause if it was
  opened from Pause, otherwise resumes gameplay (fixed a real bug: this used to leave `_level_paused`
  true with neither Pause nor Ability Purchase shown whenever the purchase menu was opened from
  Pause and then closed, a silent soft-lock since the Pause button also disables itself while
  paused). `should_resume=false` (a successful paid purchase) deliberately leaves gameplay running
  regardless of where it was opened from, since the caller already resumed gameplay before applying
  the ability.
- Hammer targets visible/front triples first, then can supplement visible/front matches with first-back-layer copies of the same item type when no visible item type has three available copies.
- Hammer flies all three chosen targets to the exact viewport center, removes the two duplicate
  visuals, and gives the remaining merged item a short 120 ms settle pop. Only after that merge is
  visibly complete does it start the fullscreen eleven-pose hammer strike from the live bottom-left
  Hammer ability button. The merged item
  compresses on the authored 480 ms `pre_impact` signal (about 369 ms into playback), becomes
  invisible and is freed on the frame-7 authored 560 ms `impact` signal (about 431 ms into
  playback), and the combo reward starts 140 ms later while the roughly 1.03 second VFX playback is
  still fading.
  Gameplay scoring, shelf resolution, and ability input lock rules are unchanged.
- Hammer requests its shared cue from `scripts/level.gd` on the same authored `impact` signal that
  destroys the merged item and starts the screen shake. Disabling sound while the strike is active
  stops the cue through `SfxManager`; `level.gd` requests the `ability_hammer` pattern from
  `HapticsManager` on that same impact signal. The exported `hammer_haptics_enabled` flag remains a
  local capture/test gate, while the manager applies the saved player preference.
- Shuffle now pauses moving shelf rows, shows the center-screen delivery box, then starts its shared
  cue with the first frame of item flight into the box so the single authored sound spans the fly-in
  and fly-out sequence. It changes unlocked item identity assignments while they are hidden and
  flies them back to their original slots. The box begins its outro 0.3 seconds before the item-return
  phase finishes, while shelf resolution still waits for every item to land.
- Count hammer destroys as cleared triples for shelf unlocking.
- Let highlight uses start their timed window even when no immediate triple can currently be highlighted.
- Find items to highlight with `_find_immediate_triple_items()`: prefer a shelf that is one item away from a full match plus a loose match elsewhere (single-move triple), otherwise fall back to any visible items sharing a type. Only one item type is ever highlighted at a time even when several types qualify, but every visible item of that chosen type is highlighted, not just three.
- After every move, `_refresh_ability_highlights()` calls `_find_current_highlight_type_items()` first so the highlighted item type stays put as long as it still has enough visible matches; it only calls `_find_immediate_triple_items()` for a new type once the current one can no longer complete a triple. This stops the highlight from jumping to an unrelated item type after an unconnected move.
- Apply highlight ability visuals through `ShelfItem.set_outline()` and `ShelfItem.set_selection_forward_offset()` so highlighted items get an even border and move toward the shelf's front edge without growing, matching ordinary tap-selection depth feedback. Update the highlight button countdown label while that window is active.
- Mirror the Lantern timer and highlighted items' live viewport positions into `LanternScreenEffect`:
  Focus Mode shades non-target gameplay, tracks bright pulsing pools to the targets, and shows a
  searching beam when none currently exist. It renders above gameplay
  but below Freezer and the HUD, fades with normal expiry/cancellation, and clears immediately on a
  new level configuration.
- Activate Freezer for exactly 30 seconds of active gameplay. Only `_time_remaining` is gated;
  item interaction, combo expiry, moving shelf rows, animations, matching, and non-Lantern
  abilities continue. Pause menus, the ability-purchase modal, and application interruption
  suspend only the Freezer window. A partial expiry delta suppresses only its frozen portion.
- Refresh the ability bar when Freezer expires so its anti-stacking disabled state is removed and
  another remaining use can be activated immediately.
- Mirror that active state into the reusable `FreezerScreenEffect`: its large blue perimeter glow
  expands once on activation and continuously emits sparse, short-lived snowflakes inward from all
  four sides without tinting the level center. Keep the main pass below normal UI and repeat only
  the clipped top strip above `TopHud`. When a pause/modal shade covers the main pass, synchronize
  that shade's fade into the upper copy so both remain equally tinted. The effect fades on
  expiry/failure/completion; level rebuild and teardown paths clear it immediately.
- Treat Freezer activation before the first move as the first meaningful action. While Lantern or
  Freezer is active, disable both timed-ability buttons and reject direct activation of either one;
  re-enable them only after the active effect ends. Clear runtime state/visuals on level load,
  completion, failure, leave, application scene teardown, or a new level configuration.

Depends on:
- `level.tscn` node names and paths.
- `scenes/shelf.tscn` slot names and item snap marker names.
- `scripts/shelf.gd` for generated back-layer preview setup.
- `scenes/ui/shelf_lock_overlay.tscn` (`scripts/shelf_lock_overlay.gd`) for locked shelf visuals and
  feedback motion.
- `scenes/moving_shelf_row.tscn` for optional row-layout movement and clipping.
- `scenes/layouts/layout_*.tscn` for named layout preset placement.
- `scenes/ui/level_top_hud.tscn` (`scripts/level_top_hud.gd`) for the top HUD strip, combo slot,
  timer, level label, star pill, and Pause button.
- `scenes/pause_menu.tscn` (`scripts/pause_menu.gd`) for the Pause overlay's
  `leave_pressed`/`continue_pressed`/`setting_toggled` signals and `open()`/`close()`/
  `apply_safe_layout()`.
- `scenes/leave_confirmation_menu.tscn` (`scripts/leave_confirmation_menu.gd`) for the Leave
  Confirmation overlay's `leave_pressed`/`continue_pressed`/`close_requested` signals, `set_star_count()`,
  and `open()`/`close()`/`apply_safe_layout()`.
- `scenes/ui/shelf_unlock_menu.tscn` (`scripts/shelf_unlock_menu.gd`) for ADS-006's rewarded
  locked-shelf confirmation, opened from `ShelfLockOverlay.unlock_requested`.
- `scenes/ability_purchase_menu.tscn` (`scripts/ability_purchase_menu.gd`) for the Ability Purchase
  overlay's `close_pressed`/`buy_pressed`/`ad_pressed` signals, `set_offer()`, and
  `open()`/`close()`/`apply_safe_layout()`.
- `scenes/ui/time_up_extension_modal.tscn` (`scripts/time_up_extension_modal.gd`) for the recoverable
  timeout offer and its `declined`/`coin_requested`/`ad_requested` intents.
- `scenes/ui/level_completion_screen.tscn` (`scripts/level_completion_screen.gd`) for completed-level
  reward UI, its `next_pressed` signal, and `set_earned_stars()`/`open()`/`close()`/`apply_safe_layout()`.
- `scenes/ui/level_failure_screen.tscn` (`scripts/level_failure_screen.gd`) for the failure result
  modal, its `retry_pressed`/`main_menu_pressed` signals, `set_level_number()`, and
  `open()`/`close()`/`apply_safe_layout()`.
- `scenes/ui/out_of_lives_menu.tscn` (`scripts/out_of_lives_menu.gd`) for the zero-life retry offer;
  the scene emits intent while `level.gd` owns purchase/restart/menu routing.
- `scenes/item.tscn` and `ShelfItem`.
- `assets/audio/item_place_valid/item_place.wav` and
  `assets/audio/match_clear/triple_clear.wav`.
- `configs/item_sprites.json` item IDs and texture paths.
- `configs/ability_purchase_prices.json` paid-use prices for zero-use ability purchases.
- `configs/time_extension.json` launch-default grant, price, per-attempt limits, and ad availability.
- `configs/levels/level_*.json` shelf schema.
- `ChapterCatalog` for chapter-local numbering and gameplay background selection.
- `PlayerProgress` autoload for campaign progress, lives, coin spending, and ability inventory.
- `scenes/ui/ability_bar.tscn` for button visuals, use badges, and timed badges.

Do not use for:
- Offline level generation or solvability search. Keep that in `scripts/tools/`.
- Save data ownership. Keep that in `scripts/save/local_save_store.gd`; route gameplay access
  through `PlayerProgress`.

## `scripts/shelf_lock_overlay.gd`

Class:
- `ShelfLockOverlay`

Attached to:
- `scenes/ui/shelf_lock_overlay.tscn` root `ShelfLockOverlay`.

Purpose:
- Owns the visual hierarchy and replacement-safe feedback tweens for standard and compact locked
  shelves, keeping those details out of `scripts/level.gd`.
- Applies exported horizontal/vertical shade bounds and wall-cover bounds at `_ready()`, plus
  `compact_layout` to the chain, lock, and badge rig. This lets the open dispenser cradle reuse the
  overlay without inheriting the standard closed shelf's height.
- Reuses selected seven-link C2-7A art as four independent `Sprite2D` arms. The texture alternates
  crosswise/front-facing links and includes a shallow baked sag. The script computes each transform
  from a fixed wall endpoint and a lock-shackle endpoint, adds small per-arm slope differences,
  configures overlay-owned wall covers from `overlay_half_width`, and layers the bottom pair behind
  the lock while the top pair crosses in front.
- `STANDARD_WALL_ANCHORS_FROM_EDGE` and `STANDARD_LOCK_ANCHORS` are the authoritative standard-layout
  endpoints. Runtime intentionally derives every arm's position, rotation, and horizontal scale from
  them; direct `.tscn` transform edits must be transferred to these constants to appear in a level.
- Keeps `AD` and the remaining count scene-native; the count uses the shared ability/inventory badge
  resource and `GameplayUITheme.COUNT_BADGE_*` fitting contract.
- Owns the `AD` plate's input (ADS-006). It is this component's one intentional input owner: a
  press and release inside the plate's rect emits `unlock_requested` and nothing else. It never
  starts an ad, decides eligibility, or unlocks a shelf -- `scripts/level.gd` answers the signal
  with its own confirmation modal.

API:
- `show_locked(remaining)`: shows a clean locked state, fits 1-, 2-, or 3+-digit copy in the circular
  badge, and plays a badge pop + inward arm tension + hanging-lock swing only when the value decreased.
- `play_unlock()`: visibly sets the badge to zero, plays the same impact beat, then collapses/fades
  every chain arm into its fixed wall anchor, drops/fades the lock, fades the shade, hides the
  component, and restores every authored transform. Gameplay eligibility is intentionally owned
  and updated by `scripts/level.gd` before this fire-and-forget method runs.
- `reset_visual_state()`: stops tracked tweens and restores authored transforms for safe reuse.
- `set_ad_unlock_available(is_available)` / `is_ad_unlock_available()`: offers or withdraws the
  rewarded `AD` plate. Offering it enables `_input()` and starts a gentle idle pulse on `AdLabel`;
  withdrawing it restores the plate's purely decorative appearance and stops listening entirely.
  `play_unlock()`, `_finish_unlock()`, and `reset_visual_state()` all withdraw it.
- `get_ad_plate_global_rect()`: the plate's hit area in canvas-global coordinates, derived from the
  lock rig's own layout position/scale and clamped to `overlay_half_width`, so it stays correct
  across responsive relayouts and both the standard and compact layouts.

Motion ownership:
- Uses independent `UIMotion.retween()` metadata keys for chain tension, lock swing, badge pop, and
  final unlock release. Tension modifies only shackle endpoints while wall endpoints remain fixed;
  a rapid decrement replaces the same concern's prior tween instead of accumulating transforms.
- Standard motion settles in roughly 0.3 seconds; the final release completes in roughly 0.38
  seconds.

Depends on:
- `scenes/ui/shelf_lock_overlay.tscn` node paths.
- `scripts/ui_motion.gd` for `retween()` / `stop_tween()`.
- `scripts/gameplay_ui_theme.gd` for the shared count-badge fitting contract.
- `assets/ui/shelf_lock_chain_arm_a.png` and `assets/ui/lock_shelf_cutout.png`.
- `assets/themes/style_box_gameplay_count_badge.tres`.

Do not use for:
- Unlock requirements, cleared-triple ownership, Hammer counting, item eligibility, rewarded
  placement eligibility, or shelf resolution. Those remain in `scripts/level.gd`.

## `scripts/level_completion_confetti.gd`

Class:
- `LevelCompletionConfetti`

Attached to:
- `scenes/effects/level_completion_confetti.tscn` root `LevelCompletionConfetti`.

Purpose:
- Layered two-corner paper-confetti burst played across the cleared-board lead-in and reward-overlay
  reveal. Five emitter pairs divide back curls, main tiles, folds, stars, and sparse large foreground
  curls; the scene keeps these at 248 side pieces, near the previous 260-piece budget.
- Owns live-viewport muzzle placement, responsive sprite scale, and a distinct solved trajectory for
  every layer. Their arcs still converge near screen center at every supported portrait resolution.
- Starts a delayed radial flash and 18-piece paper-star center pop 0.22 seconds after launch, giving
  the two streams a shared visual impact beat.
- Uses `CPUParticles2D` rather than `GPUParticles2D`: the piece counts are small and CPU particles
  avoid GPU-particle behavior differences on low-end Android devices.

Exports:
- `muzzle_inset`: where each cannon sits relative to its bottom corner, at the design resolution.
- `center_height_ratio`: responsive vertical position for the flash/star intersection beat.

API:
- `play()`: aims/fires every layer and center beat; awaitable, generation-safe across restarts, and
  emits `finished` once the last piece can no longer be on screen.
- `get_burst_duration()`: maximum emission tail/lifetime across every side layer plus settle margin.

Depends on:
- `scripts/level.gd` for playback on completion.

Verification:
- `tests/gameplay/test_level_completion_confetti.gd` checks textured/emitting layers, the 260-piece
  side budget, center beat, responsive aim, shortened reveal, falling-piece overlap, and back skip.

Do not use for:
- Completion rules, star awards, or the reward screen itself. Those stay in `scripts/level.gd` and
  `scripts/level_completion_screen.gd`.

## `scripts/lantern_screen_effect.gd`

Class:
- `LanternScreenEffect`

Attached to:
- `scenes/abilities/lantern_screen_effect.tscn` root `LanternScreenEffect`.

Purpose:
- Owns the Lantern ability's Focus Mode presentation independently from its gameplay, inventory,
  and timer state.
- Drives a procedural fullscreen wash on canvas layer 4 with a 30% warm non-target shade, expanding
  button-origin wave, pulsing pools for as many as sixteen tracked target centers, and a continuous
  diagonal search beam only while no current target exists.
- `apply_layout()` and `set_target_positions()` keep the shader coordinates responsive, including
  while highlighted items ride moving shelves.
- Keeps repeated `set_active(true)` calls idempotent, fades on normal expiry/cancellation, and offers
  an immediate cleanup path for level rebuilds. The complete effect ignores input and remains under
  Freezer's layer-5 frame and the layer-10 HUD/modal system.

Depends on:
- `assets/abilities/lantern_searchlight.gdshader`: texture-free Focus Mode compositing.
- `scripts/level.gd`: authoritative Lantern timer and visual-state orchestration.

Verification:
- `tests/gameplay/test_lantern_screen_effect.gd`.
- Responsive `level.tscn` capture through `scripts/tools/captures/lantern_effect_setup.gd`.

Do not use for:
- Lantern duration, item selection/highlighting, inventory spending, purchase, or persistence.

## `scripts/freezer_screen_effect.gd`

Class:
- `FreezerScreenEffect`

Attached to:
- `scenes/abilities/freezer_screen_effect.tscn` root `FreezerScreenEffect`.

Purpose:
- Owns the Freezer ability's visual lifecycle independently from gameplay/economy state.
- Drives two synchronized copies of the glow-only shader with short activation and fade-out tweens:
  one full frame on layer 5 below UI and one full-scale render pass clipped to the responsive HUD
  height on layer 11. Repeated `set_active(true)` calls are idempotent because `scripts/level.gd`
  refreshes Freezer visuals every active frame.
- Starts and stops `FreezerSnowflakeField` with the same lifecycle. The layer-11 field mirrors the
  main field's particle data instead of simulating another particle set.
- Mirrors the shared gameplay modal shade resource into only the layer-11 copy with the same
  `UIMotion.OVERLAY_DURATION` fade. The main layer-5 copy receives the real layer-10 shade directly.
- Keeps the effect hidden when inactive and provides an immediate reset path for board rebuild,
  scene teardown, and deterministic verification.

Key methods:
- `set_active(should_be_active, immediate)`: starts one state transition or applies its final state.
- `set_modal_dimmed(should_be_dimmed, immediate)`: synchronizes the layer-11 copy with modal shade.
- `apply_layout(viewport_size, top_hud_height)`: clips the layer-11 copy to the safe-area-aware HUD.
- `is_active()`, `get_activation_amount()`, `get_effect_opacity()`,
  `get_modal_shade_amount()`: focused state/verification accessors.

Depends on:
- `assets/abilities/freezer_edge_glow.gdshader`: texture-free, aspect-correct four-sided blue halo
  with activation width, opacity, and optional modal shade controls; it does not read the screen.
- `scenes/abilities/freezer_snowflake_field.tscn` and
  `scripts/freezer_snowflake_field.gd`: pooled procedural flakes shared by both render passes.
- `assets/themes/style_box_gameplay_modal_shade.tres`: authoritative shade color/opacity mirrored
  by the layer-11 pass.

Verification:
- `tests/gameplay/test_freezer_screen_effect.gd`.
- Responsive `level.tscn` capture through `scripts/tools/captures/freezer_effect_setup.gd`.
- Paused responsive capture through `scripts/tools/captures/freezer_paused_setup.gd`.

Do not use for:
- Freezer duration, timer suppression, inventory, purchase, or save behavior.

## `scripts/freezer_snowflake_field.gd`

Class:
- `FreezerSnowflakeField`

Attached to:
- `scenes/abilities/freezer_snowflake_field.tscn` root `FreezerSnowflakeField`.

Purpose:
- Draws crisp six-armed snowflakes procedurally, so the effect remains resolution-independent and
  needs no bitmap particle asset.
- Reuses a bounded 40-particle array, emits an eighteen-flake activation burst followed by a denser
  trickle, and sends every flake slowly inward from one of the four glowing edges at 28-52 design
  pixels per second. Each flake remains visible for 1.6-2.4 seconds so the motion reads as a gentle
  drift instead of a quick streak.
- Supports a mirror mode that draws the source field's live particle data in the clipped TopHud
  pass without advancing another simulation.
- Shortens remaining lifetimes when emission stops and clears immediately for level teardown.

Key methods:
- `set_emitting(should_emit, immediate)`: starts idempotent emission or stops/clears the field.
- `set_effect_opacity(value)`: synchronizes flake alpha with the parent glow transition.
- `set_modal_shade(color, amount)`: provides the shade used only by the mirrored HUD rendering.
- `is_emitting()`, `get_particle_count()`, `get_maximum_lifetime()`, `get_mirror_source()`:
  focused lifecycle and verification accessors.

## `scripts/hammer_impact_effect.gd`

Class:
- `HammerImpactEffect`

Attached to:
- `scenes/abilities/hammer_impact_effect.tscn` root `HammerImpactEffect`.

Purpose:
- Runtime controller and procedural VFX renderer for the hammer ability's fullscreen strike.
- Positions and scales the scene over a provided screen-space target point, plays the scene-owned
  1.34 second `AnimationPlayer` `strike` animatic at `1.3x` speed (about 1.03 seconds effective),
  and draws mobile-capped swing trails, a radial
  magenta glow, tapered white/warm starburst spikes, a localised hot core, and deterministic
  sparks/debris from five animated scalar amounts. All `_draw()` output uses the root's additive
  canvas material so the burst brightens the board instead of staining the warm background. The
  impact-only burst, glow, flash, and debris use `impact_vfx_scale = 1.25`; a full-screen flash rect
  was removed for the same reason. The effect does not allocate runtime particle emitters.
- Keeps each supplied frame's head centre on the pivot via `POSE_HEAD_OFFSETS`, applied every frame
  in `_process()` (which runs at `process_priority = 1`, after the child `AnimationPlayer`). The
  hammer art is not centred on its head, so without this the impact lands beside the burst it causes.
- Detects texture swaps after `AnimationPlayer` updates, places the outgoing texture in
  `%PreviousPose`, and crossfades it behind the incoming pose for 55 ms with a restrained backward
  smear. The final frame-7 impact skips blending and remains fully opaque.
- Accepts the live Hammer-button screen centre from `scripts/level.gd` and moves `ImpactAnchor`
  from that bottom-left origin to the target during the first 320 authored milliseconds. Texture
  changes through pose 3 retain their fast cadence, then pose 3 holds for the rest of the flight.
- Samples the head's real path into a short ring buffer so the swing trail follows the swing
  instead of a fixed screen-space arc.
- Owns no vibration call. `scripts/level.gd` requests Hammer audio and haptics through their shared
  managers when this effect emits `impact`, keeping the visual component platform-independent.
- Emits `pre_impact` at authored time 480 ms (about 369 ms into playback), `impact` on frame 7 at
  authored time 560 ms (about 431 ms into playback), hides the hammer by authored time 580 ms, and
  emits `finished` after the remaining VFX fade out.

Exports:
- `base_hammer_scale`: `0.2` base visual size before responsive viewport scaling, half the prior
  size so the head covers the converged target without hiding most of the surrounding shelf.
- `impact_vfx_scale`: `1.25` multiplier for the contact burst, glow, flash, and debris; it does not
  enlarge the hammer or its approach trail.
- `strike_playback_speed`: `1.3` playback multiplier for the authored strike while keeping the
  authored animation keys and signal beats together.

Depends on:
- `assets/abilities/ability_hammer_swing_1.png` through `ability_hammer_swing_7.png`, plus fractional
  transition frames `1.3`, `1.7`, `5.3`, and `5.7`, in strike playback order.
- `scripts/level.gd` and `scripts/audio/sfx_catalog.gd` for the shared `hammer.wav` cue.
- `scenes/abilities/hammer_impact_effect.tscn` `AnimationPlayer` keyframes for hammer motion,
  opacity, texture swaps, afterimages, VFX layer amounts, cue callbacks, and gameplay signals.
- `scripts/level.gd` for runtime instancing and gameplay response to `impact`.

Verification:
- `tests/gameplay/test_hammer_animation.gd` checks all eleven base and transitional poses, center
  convergence, the three-to-one merge, deferred strike start, immediate post-impact hammer hide,
  all five procedural VFX tracks, two afterimages, outgoing-pose crossfade, shared audio ownership,
  bottom-left approach, pose-3 flight hold, pre-impact compression, exact-frame target disappearance,
  560 ms frame-7 impact timing, the full tail duration, cleanup, and responsive layout at
  540x960, 720x1280, 1080x1920, 1080x2400, and 900x1200. It also seeks the paused animation to
  verify head-on-pivot alignment and the supplied bottom-left origin for left, centre, and right
  targets. It can render an in-level timing preview with `--write-movie` and the
  `--hammer-animation-preview` user
  argument; use a `.png` movie path, since the `.avi` output is not readable by common ffmpeg builds.

Do not use for:
- Ability inventory, target selection, item deletion, score/star rules, or shelf resolution.

## `scripts/shelf_outer_shadow_group.gd`

Class: `ShelfOuterShadowGroup`, extending `CanvasGroup`.

Purpose:
- Owns the level-wide composite for standard/moving shelves' exterior `Shadow` and
  `RightColumnShadow` polygons.
- `rebuild(shelves)` creates lightweight polygon mirrors beneath the shelf bodies, switches each
  source shelf to composited exterior-shadow visibility, and retains the complete authored cast
  geometry instead of editing it around inferred neighbors.
- Normalizes bottom and right falloff coverage through
  `shelf_composite_cast_shadow*.tres`; the group's `0.16` alpha is then applied once to the merged
  draw. Right casts retain their previous `0.14` standalone maximum through `0.875` mask coverage.
- Tracks source global transforms, modulation, shelf visibility, and destruction fades every frame,
  so moving rows and animated shelf removal keep their cast proxies attached.
- `clear()` restores standalone source visibility before discarding the mirrors. Collapsing shelf
  cells do not register because their board already owns one footprint-wide cast.

Depends on:
- `scripts/shelf.gd` for exterior-shadow eligibility and local/composited visibility.
- `assets/shaders/shelf_linear_shadow.gdshader` through the two normalized mask materials.

## `scripts/shelf.gd`

Class:
- `Shelf`

Attached to:
- `scenes/shelf.tscn` root `Shelf`.

Purpose:
- Owns reusable shelf-cell runtime helpers and back-layer preview presentation.
- Owns shelf visual switching for `full` versus `floor_only` variants.
- Owns row-placement visual switching for `left`, `middle`, and `right` shelf cells by toggling scene-authored `PlacementVisuals` containers.
- Owns the optional scene-authored `CollapsingVisuals` layer. Collapsing boards enable its
  darker vertical-grain back panel and inset shading; standard shelves keep the complete layer
  hidden while retaining the same shared light-oak frame in both modes.
- Creates generated back-layer slot nodes for one shelf.
- Applies back-layer preview item scale, tint, visibility, z-index, and disabled collision state.

Important exports:
- `back_layer_offset`: visual offset for generated hidden/upcoming shelf layers.
- `back_layer_z_index`: z-index used by generated back-layer container nodes, above shelf floor details and below active front items.
- `back_layer_item_z_index`: z-index used by generated back-layer preview items.
- `back_layer_item_scale`: scale multiplier for back-layer item previews.
- `back_layer_item_modulate`: color used for visible back-layer previews.

Shelf-type capabilities (all permissive here; `scripts/dispenser_shelf.gd` is the first type to
override any of them). `scripts/level.gd` branches on these rather than on the shelf's class, so a
new shelf type only overrides what actually differs:
- `get_base_cell_size()`: cell footprint before `SHELF_CELL_VISUAL_SCALE`; drives row packing.
- `get_visual_bounds()`: everything the shelf draws, for the responsive board fit. May exceed the cell.
- `get_slot_count()`: front slots, and therefore the width of every layer in this shelf's config.
- `accepts_dropped_items()`: whether a carried item may be placed here. Separate from being a valid
  pick-up source -- see `_is_slot_move_source_eligible()`/`_is_slot_drop_target_eligible()` in `scripts/level.gd`.
- `forms_triples()`: whether a full front layer of identical items clears.
- `allows_ability_modification()`: whether hammer may destroy or shuffle may rewrite these items.
  Read-only abilities such as highlight ignore it.
- `shows_back_layer_preview()`: whether the first back layer is previewed as dimmed art.

Key methods:
- `set_visual_variant(visual_variant)`: applies `full` or `floor_only` shelf presentation and records the active variant as metadata for `scripts/level.gd` shelf edge and cast-shadow visibility checks.
- `get_visual_variant()`: returns the active shelf visual variant.
- `set_row_placement(row_placement)`: toggles the matching `PlacementVisuals/Left`, `PlacementVisuals/Middle`, or `PlacementVisuals/Right` container and records the active placement as metadata.
- `set_exterior_shadows_composited(should_composite)`: suppresses or restores the shelf-local bottom
  and right casts while `ShelfOuterShadowGroup` mirrors them at level scope.
- `should_show_exterior_shadows()`: reports whether this shelf variant owns exterior casts at all;
  floor-only moving shelves and collapsing cells return false.
- `set_horizontal_visual_scale(horizontal_scale)`: narrows shelf artwork for a moving row, trims the
  static shelf lip overhang to the floor-surface width, enables antialiasing on its moving polygon
  edges, and preserves item, slot, and input proportions.
- `get_row_placement()`: returns the active shelf row placement (`left`, `middle`, `right`, or
  `single`). The `single` state reuses the middle cabinet art and tapers both ends of its exposed top
  backboard.
- `set_collapsing_visuals_enabled(should_enable)`: toggles the collapsing-only cabinet treatment
  without changing shelf geometry, slots, input, or the shared light-oak art used by basic levels;
  it also suppresses each cell's exterior casts because the board owns one combined cast.
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

## `scripts/moving_shelf.gd`

Class: `MovingShelf`, extending `Shelf`.

Attached to `scenes/moving_shelf.tscn`, the standalone visual scene for one shelf on a moving belt.
It starts with the `floor_only` variant and restores the scene's optional hidden frame/cast shadows
when a row explicitly requests `full`. The floor-only variant shows its dedicated soft contact
shadow, while the full variant hides that shadow beneath the restored frame. Art and slots are authored in the scene; shared three-slot
gameplay capabilities, generated back layers, and visual scaling are inherited from `Shelf`.
The script does not move itself: `MovingShelfRow` still owns belt motion and clipping.

Verification: `tests/gameplay/test_moving_shelf_row.gd` loads this actual moving-shelf scene for its
width, slot-proportion, and motion checks; verifies default/full variants; and checks that moving
rows use the new scene while static shelves continue using `scenes/shelf.tscn`. Existing responsive
travel and edge-pickup regressions exercise the extracted scene.

## `scripts/dispenser_shelf.gd`

Class:
- `DispenserShelf` (extends `Shelf`)

Attached to:
- `scenes/dispenser_shelf.tscn` root `DispenserShelf`.

Purpose:
- A source-only shelf: one item slot, 2-4 stacked layers, and an integrated segmented stock readout
  counting the items still on it, the one on display included.
- Reuses `Shelf`'s back-layer machinery for the queue -- with a single front slot, "one hidden item
  per layer, promoted when the front layer empties" already is a dispenser, so there is no separate
  stacking system.
- Owns the authoritative remaining count and forwards it to `LayerIndicator`.

Capability overrides:
- `get_base_cell_size()` -> `DISPENSER_BASE_CELL_SIZE` (96x135, about 43% of a standard cell -- the
  narrowest that fits the canonical item silhouette without clipping).
- `get_visual_bounds()` -> `VISUAL_BOUNDS`, spanning the shorter open cradle and attached meter.
- `get_slot_count()` -> `1`; `accepts_dropped_items()`, `forms_triples()`,
  `allows_ability_modification()`, and `shows_back_layer_preview()` all return `false`.
- `set_row_placement()` and `set_top_ceiling_cap_visible()` are pinned: the frame is self-contained
  rather than sharing edges with neighbours, and the open cradle never grows a ceiling cap.
- Constants are named `DISPENSER_BASE_CELL_SIZE`/`DISPENSER_SLOT_COUNT` because GDScript does not
  let a subclass reuse a parent constant's name.

Key methods:
- `set_capacity(capacity)`: creates one stock cell per authored item and lights them all; called once
  from the level config.
- `take_one()` / `set_remaining_count(remaining)`: records that an item left for good.
- `get_capacity()` / `get_remaining_count()`.

Why the count is state rather than derived: a carried item is reparented out of its slot for the
length of a drag, so a shelf counting its own children would read as emptied the moment the player
picked the item up, and would have to count back up if they dropped it somewhere invalid.
`scripts/level.gd` calls `take_one()` exactly once per committed move onto a different shelf.

Do not use for:
- Level JSON parsing, move validation, or ability targeting. Those stay in `scripts/level.gd`.

## `scripts/shelf_layer_indicator.gd`

Class:
- `ShelfLayerIndicator`

Attached to:
- `scenes/shelf_layer_indicator.tscn` root `ShelfLayerIndicator`.

Purpose:
- Integrated readout of how many items a dispenser still holds. Knows nothing about matching, moves,
  or the level -- `scripts/level.gd` talks to the shelf, never to the indicator.
- Reuses the ability bar's circular count-badge style and drives the wide, minimally outlined rail
  authored in `scenes/shelf_layer_indicator.tscn`. The script caches the scene's four segment nodes,
  fits the active 2-4 cells to the configured capacity, and animates their authored `Light` children;
  it no longer constructs or deletes visual nodes at runtime.
- Exposes the rail's sizing, border, gap, corner, and gloss measurements in the root node's
  `Rail Layout` inspector group. Segment colors and visual layering live on the authored scene nodes.

Key methods:
- `configure(capacity, remaining)`: rebuilds 2-4 capacity cells and snaps them and the count to state.
- `set_remaining(remaining)`: a decrease pops and extinguishes spent rightmost cells and pulses the
  count; anything else snaps, since nothing in the game grows a dispenser back.
- `get_capacity()` / `get_remaining()` / `get_fill_fraction()` / `get_segment_count()` /
  `get_lit_segment_count()`.

Depends on:
- `scripts/ui_motion.gd` for segment-depletion and count-pulse tweens.

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

## `scripts/collapsing_shelf_board.gd`

Class:
- `CollapsingShelfBoard`

Attached to:
- `scenes/collapsing_shelf_board.tscn` root `CollapsingShelfBoard`.

Purpose:
- Owns the columns of a `collapsing_columns` level, the clip window they draw through, the resolved
  visible count, and the single coordinated collapse that removes emptied shelves.
- Is the authority on shelf availability for this mode: `is_shelf_active()` is true only for a shelf
  inside its column's window that has finished arriving, and false for every shelf while a collapse
  runs. Hidden shelves are also invisible, but visibility is never the rule the level relies on.
- Applies left/middle/right shelf art from the column's board position at registration, never from
  how many shelves survive in a row.
- Fits one bottom and one right exterior cast shadow to the resolved board footprint. Individual
  collapsing shelf cells retain inset occlusion but hide their exterior casts, preventing repeated
  translucent layers as rows collapse through the same screen space.
- Reports completion as "no shelf survives anywhere" through `is_cleared()`, which is false while a
  collapse is still running.

Visible count:
- `configure()` takes the authored `visible_shelves_per_column`, the guaranteed minimum.
- `resolve_visible_count(play_size, min_scale, max_scale)` returns the largest window that fits the
  play area at the scale the authored minimum already needs, so extra rows only use spare height and
  never shrink the board or its touch targets. The level calls it once and passes the result to
  `set_visible_count()`, which clamps to the authored minimum, the tallest column, and
  `MAX_VISIBLE_SHELVES_PER_COLUMN` (`8`, mirrored from `scripts/tools/validate_level_solvable.py`).

Key methods:
- `configure(column_heights, visible_count, shelf_step, cell_size, shelf_scale)`: builds the columns.
- `get_column_parent()` / `register_shelf(column_index, authored_shelf_id, shelf)`: construction.
- `get_layout_bounds()`: fixed footprint for responsive fitting; hidden depth never contributes.
- `is_shelf_active()`, `get_active_shelves()`, `get_all_shelves()`, `owns_shelf()`.
- `get_column_index()`, `get_stack_index()`, `get_authored_shelf_id()`.
- `collapse_shelves(shelves)`: coroutine. Removes the given shelves in one batch and returns
  `removed_ids`, `removed_count`, and `revealed` once every affected column has settled.
- `settle_immediately()`: deterministic, animation-free completion of any running collapse.
- `get_remaining_shelf_count()`, `get_remaining_shelf_counts()`, `is_cleared()`, `is_collapsing()`.

Exports:
- `window_outer_margin`: how far the non-top window edges sit outside the footprint.
- `destroy_duration_seconds`, `shift_duration_seconds`, `shift_overlap_seconds`: pushed to every
  column. Zero durations make collapses complete synchronously, which tests use.

Signals:
- `collapse_started`, `collapse_finished(result)`.

Verification:
- `tests/gameplay/test_collapsing_shelf_columns.gd`.

Do not use for:
- Deciding which shelves are empty, move rules, matching, or abilities. Those stay in
  `scripts/level.gd`.

## `scripts/collapsing_columns_preview.gd`

Attached to:
- `scenes/testing/collapsing_columns_preview.tscn` root.

Purpose:
- Extends `scripts/level.gd` only to load `configs/test_levels/collapsing_columns_preview.json`,
  title the HUD `COLUMNS PREVIEW`, and route retry back into the preview and Leave to
  `scenes/main_menu_testing.tscn`. Gameplay is the unmodified level runtime.

## Collapsing-columns capture setups

- `scripts/tools/captures/collapsing_columns_initial_setup.gd`: the fixture as first opened, with
  the window each resolution resolves for itself.
- `scripts/tools/captures/collapsing_columns_progress_setup.gd`: the fixture after twelve moves of
  its recorded solution, with the authored four-shelf window.
- `scripts/tools/captures/collapsing_columns_motion_setup.gd`: a collapse frozen part-way through
  its drop with `Tween.custom_step()`; `SORTING_PUZZLE_CAPTURE_COLLAPSE_PROGRESS` picks the point.
- `scripts/tools/captures/collapsing_columns_destruction_setup.gd`: the preceding wood-snap beat,
  frozen with the same column tween; `SORTING_PUZZLE_CAPTURE_DESTRUCTION_PROGRESS` picks the point.
- `scripts/tools/captures/collapsing_columns_capture_support.gd`: shared build, settle, and replay
  steps, and `SOLUTION_PREFIX`, the fixture's recorded solution moves. The setups rebuild the board
  on every resize, because the level resolves its window only when a board is built, and park
  themselves on the scene so `capture_scene.gd` cannot free them before the resizes happen.

## `scripts/collapsing_column_rules.gd`

Class:
- `CollapsingColumnRules` (static helpers, preloaded by `scripts/level.gd` as `CollapsingRules`).

Purpose:
- Runtime reading of the `gameplay_mode` / `column_layout` contract: `validate_config()`,
  `is_collapsing()`, `get_column_heights()`, and `get_visible_count()`.
- Mirrors the shape rules of `scripts/tools/validate_level_solvable.py`, which stays the
  authoritative validator, so a malformed level fails closed at runtime instead of being guessed at.
- Accepts whole-number floats, because Godot's JSON parser returns every number as a float.

## `scripts/collapsing_shelf_column.gd`

Class:
- `CollapsingShelfColumn`

Attached to:
- `scenes/collapsing_shelf_column.tscn` root `CollapsingShelfColumn`.

Purpose:
- Owns one bottom-to-top shelf order. Stack index is the logical row; the authored shelf ID travels
  with the node as `collapsing_shelf_id` metadata and never changes.
- Removal is logical first. `remove_shelves()` commits the new order and reports revealed shelves
  immediately, ignoring shelves it no longer holds, so no shelf is destroyed twice and the result does
  not depend on discovery order. `start_collapse()` then only moves visuals toward that order, so a
  pause, backgrounding, teardown, or `settle_immediately()` can never leave a half-applied order.
- Destroyed shelves leave the tree as the collapse finishes, not a frame later, so recursive shelf
  discovery never finds one.

Exports:
- `destroy_duration_seconds`, `shift_duration_seconds`, `shift_overlap_seconds`: destruction and
  fall timing, including their short overlap.
- `landing_overshoot`, `landing_rebound`: the local-pixel contact positions around the exact row.

Signals:
- `collapse_settled`: exactly once per collapse, including one cut short by `settle_immediately()`.

Timer and pause policy:
- A collapse is gameplay resolution, not a pause. Like match-clear animations it keeps running under
  the pause menu, and Freezer does not stop it. Because the order is committed before any tween,
  every interruption point leaves a consistent board.

## `scripts/shelf_destruction_effect.gd`

Class:
- `ShelfDestructionEffect`.

Attached to:
- `scenes/effects/shelf_destruction_effect.tscn` root.

Purpose:
- Owns the collapsing shelf's visual break language: a small recoil, separated side walls and
  planks, late fade, warm snap line, dust puffs, and deterministic oak-colored chips.
- `add_to_tween(tween, shelf, duration, break_direction)` contributes all animation to the calling
  column's shared tween. It deliberately creates no independent tween, owns no gameplay state, and
  is freed by the column when the batch settles or is interrupted.

## `scripts/moving_shelf_row.gd`

Class:
- `MovingShelfRow`

Attached to:
- `scenes/moving_shelf_row.tscn` root `MovingShelfRow`.

Purpose:
- Clips a moving shelf group to a visible window. In a level, `_layout_shelves()` supplies the full
  playable background along the motion axis: safe left/right edges for horizontal belts, and
  `SHELVES_TOP_CLEARANCE` through `SHELVES_BACK_WALL_BOTTOM_MARGIN` for vertical belts. The static
  board's side margin does not inset horizontal motion.
- Keeps the authored footprint separate from the travel window; responsive fitting uses
  `get_layout_bounds()` so repeated resizes preserve shelf scale and static placement.
- Preserves shelf spacing and count when the travel window grows. A short belt gains empty loop
  space, allowing every shelf to fully exit before wrapping, without duplicate gameplay nodes.
- Moves child shelves horizontally or vertically and wraps them when they pass the row bounds.
- Advances motion on fixed physics ticks and interpolates the rendered position each display frame,
  preventing uneven stepping when the physics and display refresh rates differ.
- Campaign layout rows use a shared `60` design-pixel-per-second speed, producing an even one-pixel
  cadence at the 720 px design viewport on common 60 Hz displays instead of periodic repeats or
  two-pixel jumps from 45/55/70 px/s authored speeds.
- Narrows each registered shelf body by `SHELF_WIDTH_REDUCTION` (`15` design pixels), leaving a
  visible gap at the unchanged grid step while item art and hit areas keep their proportions.
- Reports whether any of a shelf cell still overlaps the visible window. A shelf remains reachable
  after its center crosses an edge if one of its items is still visible.
- `scripts/level.gd` clips each item's pick rectangle to `get_visible_global_rect()` for pickup and
  press/selection retention. Hidden portions cannot be tapped, and fully hidden items lose selection.
  Drops require a visible slot marker and a pointer inside the moving window; occupied-slot fallback
  also skips hidden neighboring slots. Locked and source-only shelf restrictions remain in force.

Exports:
- `visible_shelf_count`: authored shelf positions used to fit the board and size standalone rows.
  Levels expand the actual travel window to the playable background, which can reveal more shelves.
- `shelf_cell_size`: shelf cell bounds supplied by `scripts/level.gd`.
- `shelf_step`: packed shelf spacing supplied by `scripts/level.gd`.
- `motion_type`: `horizontal_wrap` or `vertical_wrap`.
- `speed_pixels_per_second`: row motion speed.
- `direction`: `1` for rightward or downward motion, `-1` for leftward or upward motion.

Key methods:
- `configure()`: applies runtime row settings from a level config.
- `get_layout_bounds()`: stable authored rectangle, including the configured layout center.
- `set_play_area()`: applies the playable rectangle in shelf-root coordinates along the motion axis.
- `add_shelf()`: registers a child shelf for wrapping layout.
- `set_movement_paused()`: pauses row motion during pause, failure, or completion states.
- `is_shelf_inside_visible_window()`: used by `scripts/level.gd` drag/drop targeting.
- `get_visible_global_rect()`: clipping rectangle in the same global coordinates as item picks and
  slot markers, including the responsive shelf-root scale.

Verification:
- `tests/gameplay/test_moving_shelf_row.gd` checks the exact `15` px reduction, the resulting gap,
  clipping-window width, visual scaling, unchanged slot proportions, fixed-tick advancement, and
  subpixel render interpolation. It also checks complete travel and offscreen wrapping in both axes
  and directions, short belts, full responsive background coverage, safe insets, and repeat-layout
  stability at five phone/tablet sizes. Its optional `--moving-shelf-motion-preview` mode records a real
  Level 8 moving-row sequence for frame-by-frame visual review.
- Edge interaction regression coverage places an item on a partially clipped shelf, taps and drags
  it after the shelf center crosses each horizontal/vertical edge, and checks hidden-item rejection,
  selection cleanup, drop clipping, and hidden-neighbor fallback at all five viewport sizes.
- `scripts/tools/captures/layout_preset_setup.gd` accepts
  `SORTING_PUZZLE_CAPTURE_MOTION_OFFSET` to freeze a belt at a chosen design-pixel offset for visual
  entry/exit review. Capture `level.tscn` with `-Position '0,0'`.

Do not use for:
- Shelf item rules, matching, ability behavior, locking, or level completion. Those stay in `scripts/level.gd`.

## `scripts/pause_menu.gd`

Class:
- `PauseMenu`

Attached to:
- `scenes/pause_menu.tscn` root `PauseMenuOverlay` (Control, UI-003 -- was a `ColorRect` before it
  composed the shared shell for its own shade).
- `scenes/ui/settings_menu.tscn` root `MainMenuSettingsOverlay` (`ColorRect`; compatible since this
  script only requires `Control`, an ancestor of `ColorRect`).

Purpose:
- In `scenes/pause_menu.tscn`, composes `scenes/ui/gameplay_modal_shell.tscn` (`Shell`) for the
  shared shade, outer panel, title (`"PAUSE"`), close button, content region, and action row
  (UI-003; see docs/SCENES.md "Shared Gameplay UI Roles"). At `_ready()`, reparents its own
  `SettingsContent` into the shell's content region and `LeaveButton`/`ContinueButton` into its
  action row. Emits `leave_pressed`/`continue_pressed` (the shell's `close_requested`, i.e. the X
  button, also maps to `continue_pressed` -- Pause's close and Continue are equivalent, unlike Leave
  Confirmation's) instead of `scripts/level.gd` wiring these buttons by path.
- Owns shared settings-button visual state, initialized from and saved through `PlayerProgress`.
- Toggles a crossed-out overlay on the music, sound effects, and vibration square icon buttons when
  clicked. The overlay is now scene-authored in `scenes/pause_menu.tscn` (a hidden `CrossOut` child
  per button, UI-003 P3); `_create_cross_out_marker()` still builds one at runtime as a fallback so
  `scenes/ui/settings_menu.tscn`, which does not author one, keeps working unmodified.
- Emits `setting_toggled(setting_id, is_disabled)` so owning runtime scripts can apply supported settings.
- Settings buttons are located by name (`find_child(name, true, false)`) rather than a fixed
  NodePath, so this one script keeps working for both `scenes/pause_menu.tscn`'s shell-composed
  layout and `scenes/ui/settings_menu.tscn`'s own unrelated `PauseMenuPanel/InnerPanel/IconRow` layout.
- On the Main Menu variant, emits `support_requested` for the restored Support button and
  `ad_privacy_requested` for the optional privacy action. Reporting an ad is owned by the support
  FAQ instead of consuming another Settings slot.
- Initializes every pause-menu and main-menu settings instance from the saved disabled-state dictionary so matching buttons stay visually synchronized after game restarts.
- Owns the deliberate sound-effects toggle audio (AUDIO-001). `SoundEffectsButton` is marked
  `sfx_click_suppressed` so the generic click policy leaves it alone, and
  `_on_setting_button_pressed()` calls `SfxManager.acknowledge_sound_effects_toggle()` after
  emitting `setting_toggled` -- owners react to the new state first, then the acknowledgement
  sounds, so nothing cuts it off. Every other settings toggle keeps the normal click.
- Routes the vibration toggle to `HapticsManager.acknowledge_vibration_toggle()`: enabling previews
  the newly active setting, while disabling forces one final short acknowledgement after saving the
  disabled state. All later semantic haptics remain gated by that saved preference.

Key methods:
- `is_setting_disabled(setting_id)`: returns the shared disabled state for owning scripts such as `scripts/level.gd`.
- `open()` / `close()` / `is_transitioning()` / `apply_safe_layout(safe_margins, viewport_size)`:
  delegate to the shell when present (`scenes/pause_menu.tscn`); fall back to plain `show()`/`hide()`
  when absent (`scenes/ui/settings_menu.tscn`, which `production_main_menu.gd` fades/frees itself
  instead of calling these). `open()`/`close()` show/hide this script's own root immediately around
  the shell's fade (an always-visible root would either skip the fade or become a permanent
  screen-covering input blocker).

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn` (when present).
- `scripts/gameplay_ui_theme.gd` for the modal's preferred size.

Do not use for:
- Applying actual music settings until that runtime system exists.
- Level pause, continue, or leave flow. Those stay in `scripts/level.gd`.

## `scripts/support_screen.gd`

Class:
- `SupportScreen`

Attached to:
- `scenes/ui/support_screen.tscn`

Purpose:
- Owns support-screen responsive layout, Back behavior, single-open accordion coordination, and
  contact/ad-report `mailto:` construction.
- Reads the replaceable `application/config/support_email` value and rejects malformed addresses
  before asking the OS to open an email app.

## `scripts/support_faq_item.gd`

Class:
- `SupportFaqItem`

Attached to:
- `scenes/ui/support_faq_item.tscn`

Purpose:
- Owns one question's expand/collapse state, answer text, chevron state, and optional action signal.
- Contains no navigation or external-contact policy; those stay in `scripts/support_screen.gd`.

## `scripts/gameplay_ui_theme.gd`

Class:
- `GameplayUITheme` (`RefCounted`, all `static func`/consts, no instance needed)

Purpose:
- The gameplay-scope equivalent of `scripts/destination_screen_layout.gd`: shared geometry/
  typography constants and small pure layout helpers for the in-level HUD, ability bar, gameplay
  modals, and terminal result screens (UI-003; see docs/SCENES.md "Shared Gameplay UI Roles"). The
  level generally keeps its own denser, higher-contrast palette; Pause deliberately reuses the
  warm Main Menu settings-button role because both controls open settings/navigation UI. Consumers
  `preload` this script and call its static consts/funcs by the preloaded constant.

Constants:
- `HUD_ICON_COMPACT_SIZE` (98.4x98.4) / `HUD_ICON_REGULAR_SIZE` (115.2x115.2) /
  `HUD_ICON_COMPACT_REFERENCE_WIDTH` (540) /
  `HUD_ICON_COMPACT_VIEWPORT_WIDTH` (620): the circular ability icon-button role's two sizes and
  breakpoint. The top HUD reuses the same compact scale factor for its independently-sized 72x64
  Pause/settings control when unusually narrow safe-area insets require scaling.
- `COUNT_BADGE_MAX_FONT_SIZE` (20) / `COUNT_BADGE_MIN_FONT_SIZE` (8) /
  `COUNT_BADGE_HORIZONTAL_PADDING` (4): shared numeric-fit contract for ability-use and locked-shelf
  remaining-clear badges using `style_box_gameplay_count_badge.tres`.
- `MODAL_MAX_WIDTH` (520) / `MODAL_COMPACT_HEIGHT` (500) / `MODAL_MIN_EDGE_GAP` (20) /
  `CLOSE_BUTTON_SIZE` (72x72): gameplay modal shell geometry.
- `MODAL_TITLE_REGULAR_SIZE` (44) / `MODAL_TITLE_LONG_SIZE` (40): modal-title typography roles
  (regular for short titles like "PAUSE", long for titles needing to fit more text in the same
  width, like "LEAVING THE LEVEL").
- `RESULT_HERO_TITLE_SIZE` (58) / `RESULT_TITLE_SCALE_MIN` (0.75) / `RESULT_TITLE_SCALE_MAX` (1.35):
  Completion's terminal-result hero title role and responsive scale
  clamp applied to the whole result shell (matches Completion's pre-existing formula so its
  on-screen size is unchanged).
- `CTA_HELD_SCALE` (0.94) / `ICON_HELD_SCALE` (0.97): named gameplay-scope aliases for the UI-002
  held-scale roles.

API:
- `get_hud_icon_size(usable_width)`: regular, compact, or safe-inset-scaled compact size for the
  given *usable* width (callers subtract safe-area side insets first).
- `fit_outer_panel_size(preferred_size, safe_margins, viewport_size)`: clamps a modal's preferred
  outer-panel size so it never exceeds the safe content rect minus `MODAL_MIN_EDGE_GAP` on every
  side, at any supported viewport.
- `get_result_title_scale(viewport_size)`: the shared responsive scale for the terminal-result shell.
- `fit_label_font_size(label, available_width, maximum_size, minimum_size)`: finds the largest
  rendered font size that fits a numeric HUD label's current responsive bounds.

## `scripts/gameplay_modal_shell.gd`

Class:
- `GameplayModalShell`

Attached to:
- `scenes/ui/gameplay_modal_shell.tscn` root `GameplayModalShell`.

Purpose:
- Shared gameplay modal shell (UI-003): fullscreen shade + input blocker, safe-area-fitted centered
  outer panel, title region (regular/long variant), true-circular close action
  (`press_scale_button.gd`, 0.97 held scale), cream content region, and bottom action row.
  `scenes/pause_menu.tscn`, `scenes/leave_confirmation_menu.tscn`, and
  `scenes/ability_purchase_menu.tscn` each instance this as their first child (`Shell`) and
  reparent their own content/action buttons into its slots at `_ready()`, instead of each repeating
  shade/panel/close-button styling locally. Composed (instanced as a child), not Godot scene
  inheritance -- matches the existing `destination_screen_shell.tscn` pattern.
- Ownership split: this shell owns presentation, safe-area fitting, and open/close motion. The
  owning scene's own script owns its content, signals, and gameplay data --
  `scripts/level.gd` only sets data, calls `open()`/`close()`, and listens for signals.

Key methods:
- `configure(title, is_long_title = false)`: sets the title text and selects the regular/long
  modal-title typography role.
- `set_preferred_size(size)`: the panel's preferred (unclamped) size; `apply_safe_layout()` fits it.
- `set_content_region_height(height)`: fixes the cream panel to a content-specific authored height
  rather than stretching it with the outer shell; safe fitting still uniformly scales both.
- `get_content_region()` / `get_action_row()`: the slots owning scenes reparent their own nodes into.
- `hide_content_region()`: for modals that only need a title and action row.
- `is_transitioning()`: true while an `open()`/`close()` fade is in flight -- callers (button
  handlers, the `ui_cancel` chain) should ignore duplicate input until this clears.
- `apply_safe_layout(safe_margins, viewport_size)`: centers the panel in the safe content rect and
  uniformly scales its full composed subtree to `GameplayUITheme.fit_outer_panel_size()`; fixed
  child/container minimum sizes therefore cannot overflow a shrunken outer panel.
- `open(with_pop = false)` / `close()`: fade via `scripts/ui_motion.gd`. `with_pop` preserves the
  safe-area-fitted target scale while moving the panel 90% -> 102% -> 100%; the Time Up offer uses
  it to land on its supplied cue. `close()` is a no-op if already hidden; a
  repeat call while already closing is absorbed by `UIMotion.close_with_fade()`'s own generation-token
  guard. Each owning wrapper hides its root only if the shell is still closed after the await, so a
  stale close superseded by `open()` cannot hide the reopened modal.

Depends on:
- `scripts/ui_motion.gd`, `scripts/gameplay_ui_theme.gd`, `scripts/press_scale_button.gd`.
- `assets/themes/style_box_gameplay_modal_shade.tres`, `style_box_gameplay_modal_outer_panel.tres`,
  `style_box_gameplay_modal_inner_panel.tres`, `style_box_gameplay_close_button_{normal,pressed,hover}.tres`.

## `scripts/gameplay_result_shell.gd`

Class:
- `GameplayResultShell`

Attached to:
- `scenes/ui/gameplay_result_shell.tscn` root `GameplayResultShell`.

Purpose:
- Terminal-result shell retained for `scripts/level_completion_screen.gd`. Owns Completion's
  full-screen result shade, hero title role, action-button placement, safe-area layout, and
  open/close motion. Failure now composes `gameplay_modal_shell.gd`.

Key methods:
- `configure(title)`.
- `get_title_label()`: exposes Completion's title to its presentation motion.
- `get_content_region()`: full-viewport-sized passthrough; the owning scene positions its own
  content within it using the same absolute-viewport-relative math it used before this shell
  existed, since the region's rect matches the old root's rect.
- `get_action_region()`: Completion's single Continue CTA slot; the owning scene reparents its
  button here and anchors it full-rect.
- `is_transitioning()` / `apply_safe_layout(safe_margins, viewport_size)` / `open()` / `close()`:
  same contract as `scripts/gameplay_modal_shell.gd`.

Depends on:
- `scripts/ui_motion.gd`, `scripts/gameplay_ui_theme.gd`.
- `assets/themes/style_box_gameplay_result_shade.tres`.

## `scripts/level_top_hud.gd`

Class:
- `LevelTopHud`

Attached to:
- `scenes/ui/level_top_hud.tscn` root `LevelTopHud`.

Purpose:
- Extracted top HUD (UI-003): owns the top strip background, combo slot, timer, level label, star
  pill, and Pause button as one safe-area-aware component, replacing `level.tscn` embedding them
  piecemeal across the `Background` control and the `UI` canvas layer. `scripts/level.gd` only
  supplies data, calls `apply_safe_layout()` on resize, and listens for `pause_pressed`.
- The background strip height and the combo slot both grow/shift with the safe-top inset (before,
  only the timer/level/star/pause row did, so a top inset could push that row below the strip's own
  background). The timer stays centered in a real font-sized center region. At compact widths the
  level, timer, star pill, Pause control, fonts, and gaps scale as one row using safe usable width,
  so Label minimum-size resolution cannot expand the timer into either side after layout. The
  timer is positioned 10px above its former top-strip placement, while the star pill and Pause
  control retain the authored 60px row center.
- The Pause button matches the Main Menu settings-button role at 72x64, consuming the same warm
  normal/pressed resources and 0.94 held scale. Its explicit disabled StyleBox override preserves
  that shape while overlays are open, and its `font_disabled_color` override keeps the `"II"` glyph
  the settings button's dark brown rather than the engine's pale default -- Pause is disabled for
  the whole completion celebration, where the frozen board leaves it visible instead of covered.
  The whole control scales proportionally if extreme side insets require compacting the row.
- Also owns the reward-star flight's landing point and receive pulse, and the Freezer countdown's
  frozen timer-color visual (moved here from `scripts/level.gd` so it does not reach into this
  scene's `TimerLabel` directly).
- Owns the configurable final-30-seconds attention treatment: `%TimerLabel` turns alarm red over a
  dark maroon outline and scales to 1.08, settling once per new displayed second. Repeated frame
  updates cannot restart the tween. Run resets, completion, and failure restore the normal digits
  and the authored scale.
- Every countdown treatment (normal, critical, frozen) is written from one
  `_refresh_timer_label_colors()` derived from `_timer_is_critical`/`_timer_is_frozen`, with frozen
  taking precedence. Callers must not add or remove `TimerLabel` color/outline overrides directly:
  `set_timer_frozen_visual(false)` previously cleared them outright, and because `level.gd` reaches
  it from several routine `_update_freezer_visuals()` refreshes -- not only Freezer expiry -- any
  second writer to that label is dropped without warning.
- Owns the timeout beat on that same timer surface: `play_time_up_pulse()` replaces any in-flight
  critical pulse with a 1.35x red snap and restrained five-pixel shake, while
  `get_timer_global_center()` supplies the fullscreen transition's ring origin.

Signals:
- `pause_pressed`.
- `critical_second_pulsed(displayed_seconds)`: emitted from the same decision that starts the
  critical-second pulse, so `scripts/level.gd` can play `timer_critical_tick` from the HUD's own
  threshold/frozen/counting-down state instead of maintaining a second copy of it (AUDIO-001).

Key methods:
- `set_level_text(text)` / `set_timer_text(text)` / `set_star_count(stars)`.
- `set_timer_state(text, displayed_seconds, is_counting_down)`: updates the formatted timer and
  drives threshold entry/per-second critical feedback without coupling the HUD to gameplay time.
- `reset_timer_attention()`: cancels any active timer pulse and clears its run-local state.
- `play_time_up_pulse()` / `get_timer_global_center()`: the HUD-owned half of the timeout
  transition and the ring's responsive screen-space origin.
- `set_combo(is_combo_active, combo_count, time_ratio)`.
- `set_pause_enabled(is_enabled)`: also switches between pointing-hand and arrow cursors so a
  disabled Pause action does not retain an enabled affordance.
- `get_star_counter_global_center()`: the reward-star flight's landing point.
- `play_star_receive_pulse()`: briefly pulses the star pill's `Icon` when a reward star arrives,
  matching `scripts/main_menu_reward_chest.gd`'s `play_receive_pulse()` convention; kills any prior
  pulse first. It scales the icon rather than the pill on purpose -- scaling the pill runs its
  StyleBoxFlat and glyphs through the scaled transform, visibly thickening the 2px gold border and
  6px drop shadow and blurring the count, which was most obvious during the completion celebration
  where the level-clearing combo's stars land over the frozen board.
- `reset_star_pulse()`: kills any in-flight pulse and resets scale -- used on level (re)start.
- `set_timer_frozen_visual(is_frozen)`: recolors the countdown timer to the frozen cyan treatment
  while Freezer is active.
- `apply_safe_layout(safe_margins, viewport_size)`.

Depends on:
- `scripts/gameplay_ui_theme.gd` for responsive row scaling.
- `assets/themes/style_box_gameplay_status_pill.tres`,
  `style_box_warm_icon_{normal,pressed}.tres`.
- `scripts/press_scale_button.gd` on `%PauseButton`.

## `scripts/level_failure_screen.gd`

Class:
- `LevelFailureScreen`

Attached to:
- `scenes/ui/level_failure_screen.tscn` root `LevelFailureScreen`.

Purpose:
- Reusable centered level-failure modal instanced by `level.tscn`, composing
  `scenes/ui/gameplay_modal_shell.tscn` for the shade, 520x620 panel, title, circular X, safe-area
  fit, action row, and open/close motion.
- Owns the broken-heart image, `LEVEL FAILED` message, and orange Retry button.
- Emits `retry_pressed` from Retry and `main_menu_pressed` from the shared X. The owner decides
  whether Retry starts immediately or opens the life offer.

Key methods:
- `set_level_number(level_number)`: writes the chapter-local `LEVEL N` modal title.
- `apply_safe_layout(safe_margins, viewport_size)` / `is_transitioning()` / `open()` / `close()`:
  delegates to the shared gameplay modal shell.

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn` (`scripts/gameplay_modal_shell.gd`).
- `scripts/gameplay_ui_theme.gd`, `scripts/press_scale_button.gd`.
- `assets/ui/broken_heart.png` and the shared orange utility button styles.

## `scripts/leave_confirmation_menu.gd`

Class:
- `LeaveConfirmationMenu`

Attached to:
- `scenes/leave_confirmation_menu.tscn` root `LeaveConfirmationOverlay` (new script -- this scene
  previously had none, and `scripts/level.gd` reached its Leave/Continue buttons and star-count
  label directly by child path).

Purpose:
- Reusable in-level leave-confirmation overlay shown from Pause's Leave action. Composes
  `scenes/ui/gameplay_modal_shell.tscn` for shade, outer panel, title (`"LEAVING THE LEVEL"`, the
  long-title role), close button, content region, and action row.
- `close_requested` (the shared X button / system back) and `continue_pressed` (the explicit green
  Continue action) are deliberately distinct signals: close/system-back on this screen returns to
  Pause, while the explicit Continue action resumes gameplay directly (UI-003; these used to
  collapse into the same "resume gameplay" outcome before `scripts/level.gd` told them apart).
  `leave_pressed` keeps the existing life-spend-and-return behavior.

Key methods:
- `set_star_count(stars)`: writes the current run's star total into the lost-reward badge, shrinking
  the font for longer values (matches the star HUD counter's own overflow handling).
- `is_transitioning()` / `apply_safe_layout(safe_margins, viewport_size)` / `open()` / `close()`:
  same contract as the other gameplay overlays.

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn`, `scripts/gameplay_ui_theme.gd`.
- The shared `style_box_gameplay_destructive_action.tres`/`style_box_green_primary_button.tres`
  action styles and `style_box_gameplay_item_slot.tres`/`style_box_gameplay_count_badge.tres` for
  the lost-life/lost-star cells.

## `scripts/shelf_unlock_menu.gd`

Class:
- `ShelfUnlockMenu`

Attached to:
- `scenes/ui/shelf_unlock_menu.tscn` root `ShelfUnlockMenu`.

Purpose:
- ADS-006's rewarded locked-shelf confirmation. `scripts/shelf_lock_overlay.gd` reports a tap on a
  shelf's `AD` plate and `scripts/level.gd` answers it by opening this modal, so an incidental shelf
  tap can never start an ad. Composes `scenes/ui/gameplay_modal_shell.tscn` for shade, outer panel,
  title (`"UNLOCK SHELF"`), close button, content region, and action row.
- `scripts/level.gd` supplies the offer and authoritative rewarded state and listens for
  `close_requested`/`rewarded_ad_requested`. This scene never decides eligibility, requests an ad,
  or unlocks a shelf.

Key methods:
- `set_offer(remaining_clears)`: states the offer and the clear count the shelf still requires
  without the ad, so the non-ad path stays visible.
- `set_rewarded_action_state(state, enabled)`: renders `unavailable`/`ready`/`loading`/`verifying`/
  `pending`/`error`. `READY_LABEL` (`"Watch Ad · Unlock Shelf"`) names both the ad and the exact
  reward; `pending` and `error` also show an honest status line.
- `is_transitioning()` / `apply_safe_layout(safe_margins, viewport_size)` / `open()` / `close()`.

Behavior notes:
- `RewardedAdButton` starts hidden-in-effect by being disabled with no authoritative state, matching
  the fail-closed rule the other rewarded CTAs follow.
- `enabled` stays the owner's decision, so a loaded ad the backend cannot yet accept still reads as
  unavailable rather than as a button that will fail.

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn`, `scripts/gameplay_ui_theme.gd`, `scripts/press_scale_button.gd`.
- `assets/ui/lock_shelf_cutout.png`.
- `assets/themes/style_box_green_primary_button.tres`, `style_box_disabled_action_button.tres`.

## `scripts/ability_purchase_menu.gd`

Class:
- `AbilityPurchaseMenu`

Attached to:
- `scenes/ability_purchase_menu.tscn` root `AbilityPurchaseOverlay`.

Purpose:
- Reusable in-level ability-purchase overlay shown when the player taps an ability with zero
  remaining uses. Composes `scenes/ui/gameplay_modal_shell.tscn` for shade, outer panel, title
  (`"USE ABILITY"`), close button, content region, and action row. Buying applies one ability
  immediately -- it is not an inventory purchase, hence `"USE ABILITY"` rather than the previous
  `"GET MORE ITEMS"`/`"×1"`, which read like acquiring inventory. The redundant `"USE NOW"` badge
  was removed from the icon slot.
- `scripts/level.gd` supplies coin and rewarded readiness/request state through the focused API and
  listens for `close_pressed`/`buy_pressed`/`ad_pressed`.

Key methods:
- `set_offer(ability_texture, price, available_coins)`: sets the icon and price and keeps the green
  Buy action enabled. When coins are insufficient, its `buy_pressed` signal opens the in-level Shop
  instead of spending or applying the ability.
- `set_buy_action_enabled(enabled)` and `set_ad_action_state(state, visible, enabled)`: render the
  authoritative request lock plus ready/loading/verifying/pending/error CTA states.
- `is_transitioning()` / `apply_safe_layout(safe_margins, viewport_size)` / `open()` / `close()`.

Behavior notes:
- The coin icon is the canonical `assets/ui/clover_coin_transparent_96x96.png` (was
  `assets/ui/main_menu_coin.png`).
- `WatchAdButton` is hidden and disabled by default. It becomes production-visible only for a
  ready/reconcilable Hammer, Shuffle, or Lantern offer; Freezer remains coin-only. Successful
  settlement applies immediately through the existing paid-use path without coins or inventory.

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn`, `scripts/gameplay_ui_theme.gd`, `scripts/press_scale_button.gd`.
- `assets/ui/clover_coin_transparent_96x96.png`.
- `assets/themes/style_box_gameplay_item_slot.tres`, `style_box_green_primary_button.tres`,
  `style_box_disabled_action_button.tres`.

## `scripts/time_up_transition.gd`

Class:
- `TimeUpTransition`.

Attached to:
- `scenes/ui/time_up_transition.tscn` root `TimeUpTransition`.

Purpose:
- Owns the 660 ms visual state between accepted timeout and the recoverable offer: an expanding
  two-band alarm ring originating at the live HUD timer, a dark-red board shade, and a fullscreen
  input block. It intentionally contains no gameplay, economy, or audio decisions.
- Holds its final shade until `scripts/level.gd` starts the modal's popped reveal, then releases in
  180 ms so the two overlays crossfade without a flash.

Key methods:
- `play(timer_global_center)`: starts the ring/dim sequence and awaits its reveal beat.
- `release()`: fades away after the modal begins opening.
- `reset()`: kills stale tweens and restores the reusable hidden state at run/terminal boundaries.
- `is_transitioning()`: remains true for the full visible/input-blocking lifetime.

## `scripts/time_up_extension_modal.gd`

Class:
- `TimeUpExtensionModal`.

Attached to:
- `scenes/ui/time_up_extension_modal.tscn` root `TimeUpExtensionModal`.

Purpose:
- Owns the recoverable timeout offer's shared-shell composition, configured duration/price copy,
  coin/rewarded button presentation, request-state copy, responsive fitting, and transitions.
- Emits `declined`, `coin_requested`, and `ad_requested` intents without mutating timer or economy
  state; `scripts/level.gd` remains the orchestrator.

Key methods:
- `set_offer(seconds_granted, coin_price, coin_available, rewarded_ad_available,
  rewarded_ad_used)`: formats the `+MM:SS` grant, shows the canonical coin price or `Used`, and
  selects the enabled/used/unavailable ad presentation.
- `set_coin_action_enabled(is_enabled)`: provides an in-flight purchase lock without losing the
  configured per-attempt availability state.
- `set_ad_action_state(state)`: presents loading, verification, retry-verification, retry, ready,
  unavailable, and used states without owning the claim.
- `is_transitioning()` / `apply_safe_layout(safe_margins, viewport_size)` /
  `open(with_pop = false)` / `close()`: same reusable overlay contract as the other gameplay
  modals, with the timeout path selecting the shared shell's fitted pop reveal.

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn`, `scripts/gameplay_ui_theme.gd`, and
  `scripts/press_scale_button.gd`.

## `scripts/item.gd`

Class:
- `ShelfItem`

Attached to:
- `scenes/item.tscn` root `Item`.

Purpose:
- Stores the item ID and applies sprite visuals for one sortable item, and owns the item's landing squash-and-stretch.

Exports:
- `item_id`: item identity used by matching and config loading.
- `texture`: assigned by `scripts/level.gd`; setter updates `Sprite2D.texture`.
- `visual_scale`: scalar applied to `Sprite2D.scale`.
- `outline_color`: color passed to the item outline shader.
- `outline_width`: desired on-screen outline thickness in pixels; converted to a source-texture texel radius for the outline shader so thickness stays constant regardless of the item's current scale.
- `outline_alpha_threshold`: alpha cutoff used to detect the item silhouette.

- `shadow_material`: shared ground-shadow shader material, assigned in `scenes/item.tscn`. Each item renders through its own duplicate, because the shadow shader generates its color from the alpha mask and therefore ignores the node's modulate, leaving the shader uniforms as the only per-item channel for the resting/carried blend.

Runtime properties:
- `land_squash`: non-uniform `Vector2` multiplier layered on top of `visual_scale` and the highlight scale, tweened by `play_land_impact()`. It is a separate channel precisely so `set_highlight_scale()` and `set_outline()` can keep writing their own uniform scale without flattening an in-flight bounce; anything that writes sprite scale must go through `_get_sprite_scale()` rather than assigning a uniform scale directly.
- `shadow_lift`: 0 while the item rests in a slot, 1 while the player carries it, tweened by `set_drag_lifted()`. Blends the shadow between its resting and carried shapes. Its own channel for the same reason `land_squash` is: a lift arriving mid-landing must not fight the bounce.

Key methods:
- `_ready()`: applies current texture and scale.
- `_apply_texture()`: updates `Sprite2D.texture` and refreshes the ground shadow, which hides itself when the item has no texture.
- `_apply_visual_scale()`: updates `Sprite2D` and `OutlineSprite` scale from `visual_scale * highlight scale multiplier * land_squash`, applies the contact pivot offset, then refreshes the shadow and outline.
- `_apply_shadow()`: draws the item's own silhouette as its shadow. Anchors the shadow sprite on the art's ground line (`SHADOW_GROUND_TEXELS`, the 120-64 texel drop every item texture shares per `docs/ITEM_ASSET_REQUIREMENTS.md`), then blends by `shadow_lift` between two readings: **resting**, a full-size, unsheared silhouette displaced slightly up-right by `SHADOW_REST_OFFSET`, softened inside the source-alpha envelope by `SHADOW_REST_BLUR_PX` and the broad `SHADOW_REST_MASK_LOW` transition, and reduced to `SHADOW_REST_ALPHA_SCALE` opacity so neighboring shelf items remain readable; and **carried**, the same-size silhouette displaced farther down-right by `SHADOW_CARRY_OFFSET` and rendered with a compact filtered fill plus `SHADOW_CARRY_SILHOUETTE_WEIGHT` of the original alpha mask. Clipping the filtered mask to the source envelope prevents either state from rendering larger than the item. Both shadow axes follow the landing squash so the silhouette continues to match the item during impact.
- `set_drag_lifted(lifted)`: tweens `shadow_lift`, moving the shadow between its resting and carried shapes instead of hiding it while carried. Node-bound through `UIMotion.retween`, so it dies with the item.

## `scripts/shadow_style_preview.gd`

Purpose:
- Throwaway harness for tuning the item ground shadow. Lays the same contrasting silhouettes out on real shelves at three lift values (resting, mid-grab, carried) over chapter_01's legacy background colors, plus copies that animate between them so the grab and drop transitions can be judged as motion.
- Owns `scenes/shadow_style_preview.tscn`; run that scene directly. `-- --capture <path>` saves a screenshot and quits.

Do not use for:
- Anything shipped. Delete this script and its scene once the shadow is signed off.
- `play_land_impact(strength)`: plays the landing squash-and-stretch (compress ~70 ms, rebound past rest ~70 ms, settle ~90 ms, roughly volume-conserving). Fire-and-forget and node-bound via `UIMotion.retween`, so it dies with the item if a landing immediately completes a triple. Called by `scripts/level.gd` from `_play_item_move_animation()` and from `_place_item_in_slot()` when `should_play_landing` is set.
- `reset_land_impact()`: cancels an in-flight bounce and restores the resting shape; called before re-grabbing a dragged item and before the match-clear gather.
- `_get_sprite_scale()` / `_get_contact_pivot_offset_y()`: compose the squash with the uniform scale and keep the art's ground contact planted so the item does not lift off the shelf while deforming. `CONTACT_ANCHOR_Y` is the landing bounce's pivot and is tuned by eye; it is deliberately not the same value as the shadow's `SHADOW_GROUND_TEXELS` anchor, which is measured from the texture contract.
- `set_outline(enabled, color, width)`: enables or disables the sprite border highlight.
- `set_highlight_scale(multiplier)`: temporary uniform child-visual scale channel retained for effects that must compose with the landing squash; Lantern keeps it at `1.0` and does not enlarge highlighted items.
- `set_selection_forward_offset(offset_y)`: shifts the item sprite, outline, silhouette-derived shadow, and collision shape toward the shelf lip while leaving the root anchored to its logical slot. Ordinary selection and Lantern highlighting share this presentation; the offset returns to zero only when neither state applies, so tap/drag placement math never inherits presentation state.
- `set_contact_shadow_enabled(enabled)`: hard on/off switch for the ground shadow, still respecting texture availability; used by back-layer previews, clearing items, and the shuffle fly-in. Dragging no longer uses it -- see `set_drag_lifted()`.
- `_apply_outline()`: sends outline color/threshold and the computed dilation radius to the `OutlineSprite` shader material, and keeps the outline node visible only while enabled. The `OutlineSprite` shader dilates the alpha mask by sampling a ring of points around each pixel (in source-texture texels) rather than scaling the whole sprite up, so the border thickness stays even around irregular silhouettes.

Depends on:
- Child node `Sprite2D`.
- Child node `OutlineSprite`.
- Child node `Shadow`.
- `scenes/item.tscn` outline `ShaderMaterial`.
- `scripts/ui_motion.gd` for `retween`/`stop_tween` landing-impact tween ownership.

Do not use for:
- Input ownership, matching rules, abilities, or shelf promotion.
- Node-level `scale` animation. `scripts/level.gd` already tweens the item node's own `scale` for the match gather, Hammer, and Shuffle effects; the landing bounce deliberately stays on the child sprites so the two compose instead of fighting.

Verified by:
- `tests/gameplay/test_item_landing_impact.gd` (run through `scripts/tools/run_isolated_godot_test.ps1`).
- `tests/gameplay/test_item_contact_shadow.gd` for the item-sized silhouette-derived ground shadow: the soft upright resting silhouette, carried source-alpha core and compact filtered fill, ground-line anchor, and drag lift travelling with the item.
- `tests/gameplay/test_item_selection_visual.gd` for the white selection outline, shared Lantern shelf-edge offset without enlargement, hit-area alignment, and selection/Lantern visual priority.
- `scripts/tools/captures/item_selection_setup.gd` for responsive rendered selection review on `level.tscn`.

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
- Layout preset values mirror the runtime layout template names in `scenes/layouts/`; `LAYOUT_PRESETS` is the accepted set and `docs/SCENES.md` lists every preset with its shelf count. A preset only accepts a level whose shelf count matches its authored markers.

Generation constraints:
- Difficulty presets cap how many copies of the same item can appear on one filled layer.
- Difficulty presets softly target per-layer triple-ready item ratios: `0.65` for easy, `0.50` for
  medium, `0.40` for hard, and `0.30` for expert. Constrained boards use the closest feasible layout
  instead of failing solely because the preferred ratio cannot be reached.
- Copies outside a preferred local triple spread through adjacent layers first. Each item therefore
  occupies a compact contiguous layer range unless a later hard starter-triple repair is unavoidable.
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
- `--stats` includes each layer's filled count, triple-ready count and ratio, plus any item types whose
  copies ended up on non-adjacent layers.
- Generated layouts preserve adaptive per-layer same-item limits so constrained levels remain possible.
- Expert difficulty avoids shelves that start with a complete front-layer match.

Depends on:
- `scripts/tools/level_item_progression.py` for canonical logical item IDs.
- `scripts/tools/validate_level_solvable.py` for validation and optional solvability checks.

Composition:
- `build_parser()` returns the CLI contract, `parse_args(argv)` validates mode conflicts, and
  `run(args)` performs the generation. `scripts/tools/regenerate_level.py` reuses all three rather
  than restating the flags or shelling out.

Use when:
- Creating or regenerating level shelf layouts.

Do not use for:
- Runtime game logic.

## `scripts/tools/level_item_progression.py`

Purpose:
- Validates the chapter catalog, item catalog, and per-chapter milestone config.
- Selects a deterministic level-specific subset from the available item pool.
- Maps template `item_NN` identities one-to-one into concrete item IDs.
- Provides a single-template materialization CLI.

Key behavior:
- Rejects unknown, unscheduled, or within-chapter duplicated catalog items while allowing an item
  to be reused by different chapter pools.
- Rejects concrete item IDs inside templates and templates that require more identities than their
  campaign-level pool provides.
- Resolves the global level to its chapter/local number, hash-selects the concrete subset using
  `mapping_salt`, then assigns it in stable item-ID order.

Depends on:
- `configs/item_progression.json`.
- `configs/item_sprites.json`.
- `configs/chapters.json`.

## `scripts/tools/materialize_level_templates.py`

Purpose:
- Materializes every `configs/level_templates/level_*.json` file into the matching
  `configs/levels/level_*.json` runtime file.
- Supports `--check` for CI and pre-publication stale-output detection.

Use when:
- A template, item milestone, mapping salt, or item catalog changes.

## `scripts/tools/regenerate_level.py`

Purpose:
- Regenerates one campaign level end to end: generates the template with
  `generate_level_shelves.py`, materializes it, and writes both files.

Key behavior:
- Reuses every generator flag through `generate_level_shelves.build_parser()` as an argparse parent,
  so the two tools cannot drift apart.
- `--level-number` is required and `--output` is rejected; the template path is
  `configs/level_templates/level_NNN.json` and the runtime path is `configs/levels/level_NNN.json`.
- Forces `--full-level`, and forces `--require-solvable` unless `--allow-unsolvable` is given.
- Generates into a temporary file and writes nothing until materialization succeeds, so a rejected
  board contract or an exhausted chapter item pool cannot strand a replaced template against a
  runtime level that was never rewritten.
- Prints every top-level template difference before replacing the file, including hand edits such
  as level 5's `layout_preset` or level 3's `time_seconds`, which regeneration reverts.
- Warns when a runtime level exists with no template behind it, as level 10 does.
- Materializes only the regenerated level; `materialize_level_templates.py` remains the full sweep.
- Records every successful run in `configs/level_templates/generation_manifest.json`, keyed by
  level file name, unless `--no-record` is passed. The manifest name does not match the
  materializer's `level_*.json` glob.
- Records arguments structurally, defaults included, and derives the readable `command` from them;
  a shell string is not the replay contract. Values are the resolved ones, so `--seed` is the seed
  the board came from after any retry and `--layout-preset` is the preset the template carries.
  `template_sha256` lets a later run detect a template that was hand-edited after generation.
- Reads the manifest before generating, so an unusable one stops the run before any file changes.
- `--dry-run` reports the same differences without writing or recording.
- Propagates the generator's exit codes (`2` invalid item counts, `3` no solvable layout) and
  returns `1` for materialization failures.

Depends on:
- `scripts/tools/generate_level_shelves.py` (`build_parser`, `run`, `validate_mode_arguments`).
- `scripts/tools/level_item_progression.py` for progression loading and materialization.

Verification:
- `tests/tools/test_regenerate_level.py`.

Do not use for:
- Regenerating every level at once, or for refreshing `configs/backend/content_provenance.json`,
  which hashes both written files and goes stale on every regeneration.

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
