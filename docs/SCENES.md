# Scenes

This file maps scenes to their responsibilities, scripts, important nodes, and runtime relationships.

All UI scenes inherit the project typography theme from
`assets/themes/game_typography.tres`. Scene labels select semantic variations
such as `GameTitleLabel`, `GameNumberLabel`, and `GameBodyLabel`; see
`docs/TYPOGRAPHY.md`. Scene-owned color, size, outline, and shadow overrides
remain responsible for contrast against each component's art.

## Shared UI Style Tokens

`assets/themes/` also holds standalone style resources shared by Main Menu, Shop, Leaderboard,
and Chapter Selection instead of near-duplicate scene-local `StyleBoxFlat`/`StyleBoxTexture`
copies:

- `style_box_green_primary_button.tres`: glossy textured positive-action style
  (`assets/ui/level_button_blank_new.png`) for the **regular** (58 px tall) button tier. Used by
  Shop's bundle/coin-offer purchase buttons. The
  **hero** tier is `scenes/ui/level_button.tscn` itself (153 px tall; Main Menu Play and Level
  Completion `Next`), which keeps its own outlined font treatment for legibility over
  photographic backgrounds.
- `style_box_disabled_action_button.tres`: neutral gray "unavailable" style for a disabled action
  that is not retryable, such as a Chapter cover card's `Locked`/`Coming Soon` state. Deliberately
  not green: a shiny positive-looking button that is actually inert is a worse affordance than a
  neutral one.
- `style_box_orange_utility_normal.tres` / `style_box_orange_utility_pressed.tres`: shared orange
  for retry/dismiss/secondary actions -- the Shop/Leaderboard status Retry button
  (`scenes/ui/destination_status_panel.tscn`) and both purchase/reward dialog Close buttons.
  The Main Menu Chapter button (`scenes/ui/main_menu_chapter_button.tscn`) fills a related but
  visually distinct **glossy textured** secondary/alternative-CTA role
  (`assets/ui/level_button_blank_yellow_orange_new.png`) -- the same role and art the in-level
  `Watch ad` button already uses (`scenes/ability_purchase_menu.tscn`'s `WatchAdButton`), so this
  is a documented shared role, not a fresh exception. Both use white text with the same warm-brown
  outline and do not shift to a cool text color while pressed.
- `style_box_warm_icon_normal.tres` / `style_box_warm_icon_pressed.tres`: shared cream/gold 16 px
  icon-button pair used by Main Menu Settings, Chapter Selection Back, and both pager arrows.
- `style_box_status_panel.tres`: shared burgundy/gold bordered panel for the loading/empty/error
  presentation in `scenes/ui/destination_status_panel.tscn`.
- `style_box_pager_dot_inactive.tres` / `style_box_pager_dot_active.tres`: circular inactive dot /
  rounded active capsule for `scenes/ui/horizontal_pager.tscn`'s `%Dots`.

Corner-radius roles: 16 px for buttons, 20 px for rows/cells, 24 px for large panels.

`assets/themes/game_typography.tres` (the project's global `theme/custom`) also defines
`VScrollBar`/`HScrollBar` styles -- a slim rounded semi-transparent grabber over a near-invisible
track -- so `ScrollContainer`s such as `%ShopScroll` and `%LeaderboardScroll` never show the
engine-default gray scrollbar.

## Shared Interaction Roles (UI-002)

Every visible action across Main Menu, Shop, Leaderboard, and Chapter Selection uses one shared
interaction owner and one small motion vocabulary instead of ad hoc scaling, color-only feedback,
or no feedback at all. See `docs/UI_002_INTERACTION_MOTION_TICKET.md` for the original requirements.

**Interaction owner** -- `scripts/press_scale_button.gd` (`PressScaleButton`, a `Button` subclass).
By default it animates its own scale (the whole button is the visual, matching every CTA-style
consumer: Main Menu Play, Chapter CTA/back/arrows, Main Menu Settings, Shop purchase buttons).
Setting `visual_target_path` to a sibling/child `Control` instead lets an invisible or full-rect hit
target shrink a designated visual child on press without shrinking or moving its own touch
rectangle -- used by every art-only or full-cell control in scope: Main Menu's `ProfileWidget`
(targets `AvatarTexture`), `RewardChest`'s `%ChestButton` (targets a `Visual` wrapper around the
chest icon and progress track), each bottom-navigation button (targets its own `Icon`), and each
Shop ability-reward cell's transparent info button (targets the sibling `Stack`).

Recommended held scales (set via the `held_scale` export, default `0.94`):
- `0.94` -- primary/secondary CTA buttons and Retry/dialog-dismiss buttons (Main Menu Play,
  Chapter CTA, Shop/Leaderboard purchase and Retry buttons, Shop purchase-dialog and Leaderboard
  reward-dialog Close).
- `0.97` -- compact tabs, bottom navigation, icon buttons, and clickable cells (bottom-navigation
  icons, Leaderboard's Weekly/Country/World tabs, Main Menu `ProfileWidget`/`RewardChest`, Shop
  ability info cells).

`PressScaleButton` always restores the released scale on: a normal release (`button_up`, which
Godot reports identically whether the release happened inside or outside the button), disabling
mid-press (polled every frame only while held, since `Button.disabled` does not itself emit a
signal), hiding, exiting the scene tree, and the application losing focus (backgrounded mid-press).
Every restore except the normal release is immediate with no animation, matching "disabled controls
must not... animate". Press-in and release both animate through a killable tween (see Motion Tokens
below) instead of snapping, and any in-flight tween is always killed before a new one starts, so
rapid repeated presses never accumulate scale.

Persistent selection (Leaderboard's active scope tab, the bottom-navigation active icon/label) stays
a separate, always-visible color/position state independent of the momentary press scale, so the two
never read as the same thing.

**Motion tokens** -- `scripts/ui_motion.gd` (`UIMotion`, `RefCounted`, all `static func`, preloaded
like `scripts/destination_screen_layout.gd`):
- `PRESS_IN_DURATION` (0.09s) / `RELEASE_DURATION` (0.12s): `PressScaleButton`'s press/release tween.
- `NAV_ACTIVE_CHANGE_DURATION` (0.165s): the bottom-navigation active icon/label transition.
- `OVERLAY_DURATION` (0.2s): destination-screen and modal-overlay fade in/out.
- `fade_in(node, duration, target_alpha)` / `fade_out(node, duration)`: tween a `CanvasItem`'s
  `modulate.a`, killing any tween already animating it first.
- `retween(node, meta_key)` / `stop_tween(node, meta_key)`: kill whichever tween a given
  `(node, meta_key)` pair last started (if still running) before starting or stopping one, tracked
  via node metadata -- the shared primitive behind every per-node animation in this system (nav-icon
  moves, the status panel's loading pulse, fades) so rapid repeated triggers never accumulate
  competing tweens on the same property.
- `close_with_fade(node, on_finished, duration)`: fades `node` out, then calls `on_finished`
  (`queue_free` for a one-shot modal, `hide` for a reusable dialog) exactly once. Safe to call again
  while already closing (a repeat call is ignored). Waits on a plain timer rather than the fade
  tween's own `finished` signal -- `fade_in()` is allowed to kill that tween mid-flight if the same
  node is legitimately re-shown before its previous close finished (a reusable dialog can be shown
  again quickly), and a killed tween never emits `finished`, which would otherwise strand the
  closing coroutine forever. A generation token detects that supersession: a stale close whose
  token no longer matches quietly does nothing instead of hiding/freeing a node someone re-opened.

The chapter pager's ~320 ms quadratic-ease-out snap (`scripts/horizontal_pager.gd`) already met the
motion-token target before UI-002 and stays local to that script rather than duplicated here.

**Active-tab reselection rule** -- retapping the already-active bottom-navigation tab is a no-op on
every screen: Shop's `shop_pressed` handler, Leaderboard's `leaderboard_pressed` handler, and Main
Menu's `home_pressed` handler are all wired to a documented no-op method rather than to a
reload/navigate action. Catalog and ranking refresh remain available only through each screen's
explicit status-panel Retry action, never through a hidden tab-retap convention. Cross-destination
navigation (tapping a *different* bottom-navigation tab, or the Main Menu coin shortcut that also
opens Shop) is guarded by an `_is_navigating` flag on each of `production_main_menu.gd`,
`shop_screen.gd`, and `leaderboard_screen.gd`, so a duplicate press while `change_scene_to_file()`
is still in flight is ignored instead of calling it twice. The same guard also sets
`process_mode = PROCESS_MODE_DISABLED` on the outgoing screen, so none of its descendants (not
just the navigation buttons) can react to further mouse/touch/keyboard input during the brief
window before the deferred scene swap resolves.

**Back/`ui_cancel` behavior** -- `ui_cancel` closes the topmost open scoped overlay before it can
navigate a screen away:
- Chapter Selection (`scripts/chapters/chapter_selection_screen.gd`) closes itself; this is
  unchanged from before UI-002.
- Shop (`scripts/shop_screen.gd`) closes an open purchase-result dialog first if one is showing;
  otherwise it returns to Main Menu.
- Leaderboard (`scripts/leaderboard_screen.gd`) has no overlay of its own, so `ui_cancel` always
  returns to Main Menu.
- Main Menu (`scripts/production_main_menu.gd`) closes whichever of the profile modal, settings
  modal, reward-chest modal, or leaderboard reward dialog is open (one per press), explicitly
  skipping its own handling while Chapter Selection is open (Chapter Selection owns that press
  itself, avoiding a double-handling race regardless of the engine's `_unhandled_input` dispatch
  order between the two). With nothing open, `ui_cancel` on Main Menu intentionally does nothing --
  it must not quit or navigate without a separately approved exit flow.

**Focus policy** -- `FOCUS_NONE`, consistently, across every interactive control in the four-screen
scope. This project is mouse/touch-first (`project.godot`'s `config/features` includes `"Mobile"`,
there is no `[input]` section customizing gamepad/keyboard bindings, and nothing else in the
codebase supports keyboard/gamepad menu navigation), so this is the documented touch-only exception
UI-002 allows instead of adopting `FOCUS_ALL` with a new visible focus-ring style and per-screen
focus-order/off-page-exclusion work. Before UI-002 this was inconsistent (a mix of `FOCUS_NONE`,
`FOCUS_CLICK`, and the engine's default `FOCUS_ALL` with no visible focus style); every control in
scope is now `FOCUS_NONE`. All enabled clickable controls in scope also use
`mouse_default_cursor_shape = 2` (pointing hand) on desktop.

**Reward-progress semantics** -- `scenes/ui/main_menu_reward_star_flyer.tscn` (`RewardStarFlyer` in
`main_menu.tscn`, formerly named `main_menu_reward_coin_flyer.tscn`/`RewardCoinFlyer`) always
represents *earned stars* advancing reward-chest progress, never spendable coins, so it flies the
shared reward-star art (`assets/ui/reward_star_84x84.png`, the same art `reward_chest_menu.tscn`
already uses for this concept) instead of the clover-coin art `coin_balance_widget.tscn` uses for
actual spendable currency. See `scenes/ui/main_menu_reward_star_flyer.tscn`'s entry below.

**Verification** -- `tests/ui/test_interaction_motion.gd` (run via
`scripts/tools/run_isolated_godot_test.ps1`) covers `PressScaleButton`'s restore-on-disable/hide/
exit/release-outside contract and `visual_target_path` hit-rect stability, active-tab reselection,
`ui_cancel` with and without an overlay, the `FOCUS_NONE`/pointing-hand-cursor sweep, rapid
Leaderboard scope switching and Shop reloads/purchase-dialog dismissal leaving no stale animation
state, the reward-chest flight's star art and untouched `PlayerProgress` values, and the duplicate
navigation guard.

## `scenes/main_menu.tscn`

Root:
- `ProductionMainMenu` (`Control`)

Script:
- `scripts/production_main_menu.gd`

Purpose:
- Main project entry scene.
- Displays the selected chapter's configured `selection_preview` as a fullscreen production menu
  background; Chapter 1 defaults to `assets/backgrounds/main_menu.jpeg`. The whole screen fades in
  on `_ready()` (see "Shared Interaction Roles" above).
- Places all runtime modal windows and the embedded leaderboard reward dialog on a shared overlay
  z-index above the complete main-menu action stack, fading each in on open and out before it
  closes (`_add_main_menu_overlay()`/each overlay's own `close()`/`_close()`).
- Provides a top status row for profile, saved gold coins, saved campaign lives, and settings.
- Shows a left-side reward chest widget under the profile icon with saved star progress toward the active configured chest goal.
- After a completed level returns here, launches one reward star per earned star from the
  background house into the reward chest and advances the visible chest count on impact (see
  "Reward-Progress Semantics" above -- this used to fly clover-coin art).
- Provides a bottom `%LevelButton` labeled with the selected chapter's next local level, such as
  `Level 1`, or disabled as `No Lives`, `Chapter Complete`, or `Coming Soon`.
- Places a small yellow-orange `%ChapterButton` directly against the level button and opens the
  dedicated chapter selection screen.
- Opens the player profile menu when the profile widget is pressed.
- Opens the main settings menu when the settings widget is pressed.
- Opens the reward chest detail modal when the reward chest widget is pressed.
- Starts the saved campaign level when the bottom button is pressed.
- Opens `scenes/ui/leaderboard_screen.tscn` when the bottom navigation trophy is pressed.
- Opens `scenes/ui/shop_screen.tscn` when the bottom navigation cart is pressed.
- Shows `LeaderboardRewardDialog` on launch when a weekly leaderboard rollover granted a reward
  since the app was last opened.
- Retapping the already-active Home tab is a no-op; `ui_cancel` closes the topmost open overlay (or
  does nothing with none open) instead of quitting or navigating -- see "Back/ui_cancel Behavior"
  above.

Important nodes:
- `%Background`: fullscreen `TextureRect` updated from the selected chapter's
  `ChapterCatalog.get_selection_preview_path()` value on scene entry and after chapter selection.
- `TopStatusBar`: top-anchored container that places `scenes/ui/main_menu_top_status.tscn` inside the display's top inset region while avoiding exact camera cutouts.
- `RewardChest`: left-side `scenes/ui/main_menu_reward_chest.tscn` instance positioned by `scripts/production_main_menu.gd`.
- `HouseRewardOrigin`: responsive marker over the background house used as the reward animation origin.
- `RewardStarFlyer`: fullscreen `scenes/ui/main_menu_reward_star_flyer.tscn` effect layer.
- `BottomBar/ActionColumn`: bottom-anchored responsive stack for campaign actions. Its small
  negative separation cancels the transparent edge padding in the two button textures so their
  painted edges sit together without a visible gap.
- `BottomBar/ActionColumn/LevelButton`: launches the selected chapter's first incomplete level.
- `BottomBar/ActionColumn/ChapterButton`: selected-chapter button using
  `assets/ui/level_button_blank_yellow_orange_new.png` through
  `scenes/ui/main_menu_chapter_button.tscn`; see "Shared UI Style Tokens" above for why
  yellow-orange is the intentional secondary/alternative-action role here, with the same
  white/warm-brown text treatment as the in-level `Watch ad` button, not drift. `FOCUS_NONE`
  (was `FOCUS_CLICK` before UI-002's focus-policy normalization; see "Focus Policy" above).
- `LeaderboardRewardDialog`: `scenes/ui/leaderboard_reward_dialog.tscn` instance, hidden until a
  weekly reward is pending.
- Runtime child `scenes/ui/profile_menu.tscn`: centered pause-style profile editor window created when `ProfileWidget` is pressed.
- Runtime child `scenes/ui/settings_menu.tscn`: centered pause-style settings window created when `SettingsWidget/SettingsButton` is pressed.
- Runtime child `scenes/ui/reward_chest_menu.tscn`: centered pause-style reward chest detail modal created when the `RewardChest` widget emits `chest_pressed`.
- Runtime child `scenes/ui/chapter_selection_screen.tscn`: full-screen chapter picker showing one
  swipeable `chapter_cover_card.tscn` cover at a time, with selected/locked states and exact
  prerequisite progress.

Depends on:
- `level.tscn` through `scripts/production_main_menu.gd`.
- `PlayerProgress` autoload for the saved campaign level, gold coins, lives count, life restore countdown, and reward chest progress.
- `configs/chapters.json` and `ChapterCatalog` for the selected chapter's menu background.
- `scenes/ui/main_menu_top_status.tscn` for top status icons and labels.
- `scenes/ui/main_menu_reward_chest.tscn` for the side reward chest icon and progress bar.
- `scenes/ui/main_menu_reward_star_flyer.tscn` for the reward-star flight effect.
- `scenes/ui/profile_menu.tscn` for profile name and avatar editing.
- `scenes/ui/settings_menu.tscn` for the main-menu settings popup.
- `scenes/ui/reward_chest_menu.tscn` for the reward chest detail modal.
- `scenes/ui/level_button.tscn` for the reusable production level button visuals.
- `scenes/ui/main_menu_chapter_button.tscn`, `scenes/ui/chapter_selection_screen.tscn`,
  `scenes/ui/chapter_cover_card.tscn`, and `scenes/ui/horizontal_pager.tscn` for chapter navigation.
- `scenes/ui/leaderboard_reward_dialog.tscn` for the weekly reward notification.
- `scenes/ui/leaderboard_screen.tscn` for the dedicated ranking destination.

Do not use for:
- Dev/test level selection. Use `scenes/main_menu_testing.tscn`.
- Runtime puzzle rules or shelf state. Put those in `level.tscn` and `scripts/level.gd`.

## `scenes/ui/chapter_selection_screen.tscn`

Root:
- `ChapterSelectionScreen` (`Control`)

Script:
- `scripts/chapters/chapter_selection_screen.gd`

Purpose:
- Full-screen chapter picker opened from the main menu's `%ChapterButton`.
- Uses a dedicated overlay z-index above the production menu actions so the level and chapter
  buttons cannot render through the full-screen picker.
- Builds one `scenes/ui/chapter_cover_card.tscn` instance per `configs/chapters.json` entry and
  hands each to a `scenes/ui/horizontal_pager.tscn` instance as a page.
- Lets every cover own the entire viewport so swiping or pressing an arrow replaces its background
  artwork and chapter information together. Chapter 1 intentionally reuses
  `assets/backgrounds/main_menu.jpeg` as its selection artwork.
- Opens directly on the currently selected chapter's cover.
- Emits `chapter_selected(chapter_id)` and persists the pick through `PlayerProgress.select_chapter()`
  when a cover's CTA button is pressed.
- Closes on the back button, `ui_cancel`, or a successful selection, fading out before it frees
  itself (`_close()`) and then emitting `closed`. Owns its own `ui_cancel` handling independently of
  Main Menu's (see "Back/ui_cancel Behavior" above); Main Menu's own handler explicitly skips acting
  while this screen is open rather than risk double-handling the same press.
- Reuses `DestinationScreenLayout.get_safe_area_margins()`/`get_title_font_size()` (the same helper
  Shop and Leaderboard use) so the header/title/pager overlays respect device safe-area insets and
  the 48/40 regular/compact title size, while the full-bleed chapter art itself is never inset.

Important nodes:
- `%BackButton`: safe-margin overlay above the full-screen covers; `FOCUS_NONE` with the
  pointing-hand cursor, like every control in the four-screen scope (see "Focus Policy" above).
- `%ChaptersTitleLabel`: centered `CHAPTERS` title between the back button and a same-width
  trailing spacer, so it stays centered on the viewport over the full-bleed art.
- `%HeaderMargins`: repositioned by `_apply_safe_margins()` on top of its authored padding.
- `%Pager`: the `scenes/ui/horizontal_pager.tscn` instance holding one `chapter_cover_card` per
  chapter; this screen sets `peek_width` to zero so every background fills the viewport, and calls
  `set_safe_margins()` on it and on every card.

Depends on:
- `ChapterCatalog` autoload for chapter order and metadata.
- `PlayerProgress` autoload for selection state and per-chapter progress (`get_chapter_progress()`,
  `get_selected_chapter_id()`, `select_chapter()`).
- `scenes/ui/chapter_cover_card.tscn`, `scenes/ui/horizontal_pager.tscn`.
- `scripts/destination_screen_layout.gd` for safe-area margins and title sizing.
- `scripts/ui_motion.gd` for the close fade.

## `scenes/ui/horizontal_pager.tscn`

Root:
- `HorizontalPager` (`Control`)

Script:
- `scripts/horizontal_pager.gd`

Purpose:
- Generic, content-agnostic swipeable pager: holds arbitrary `Control` pages side by side and lets
  the player drag/swipe or tap the arrow buttons to move between them, snapping to the nearest page
  on release. Not chapter-specific — reusable anywhere a one-item-at-a-time browsing UI is needed
  (e.g. Shop or Rewards).
- Applies a small bounded overscroll at the first and last page rather than allowing the track to
  drift beyond the available content.

Important nodes:
- `%Clip`: clips `%Track` to the pager's bounds.
- `%Track`: absolutely positions each added page edge to edge; its `position.x` is tweened to snap
  between pages.
- `%PrevArrow`, `%NextArrow`: `press_scale_button.gd` buttons, hidden at the first/last page,
  `FOCUS_NONE` with the pointing-hand cursor (see "Focus Policy" above).
- `%Dots`: paging indicator with one circular inactive dot per page and a rounded capsule for the
  active page, styled from `style_box_pager_dot_inactive/active.tres` (see "Shared UI Style
  Tokens").

Public API:
- `add_page(control: Control)`: appends a page.
- `go_to_page(index: int, animate: bool = true)`: jumps to a page, optionally animated.
- `get_current_page()`: returns the active zero-based page index.
- `set_safe_margins(margins: Vector4)`: insets `%PrevArrow`/`%NextArrow`/`%Dots` only, leaving
  `%Clip`/`%Track`/pages full-bleed. Defaults to zero (no-op) so other consumers of this generic
  pager are unaffected unless they opt in.
- `page_changed(index: int)` signal.

Depends on:
- `scripts/press_scale_button.gd` for the arrow buttons.

## `scenes/ui/chapter_cover_card.tscn`

Root:
- `ChapterCoverCard` (`Control`)

Script:
- `scripts/chapters/chapter_cover_card.gd`

Purpose:
- One full-screen chapter "cover": chapter art, a light atmosphere gradient, and a warm bottom
  information panel containing chapter number, title, labeled progress bar, availability status,
  and a single CTA button.
- `configure(chapter, progress, is_selected)` mirrors the three states the retired `chapter_card.gd`
  used: locked, unlocked-with-no-levels-yet ("coming soon"), and unlocked-with-levels. CTA text is
  `Play`, `Continue`, `Locked`, or `Coming Soon` (title case, per `docs/TYPOGRAPHY.md`).
- Emits `selected(chapter_id)` when its CTA is pressed; the CTA stays disabled while locked.
- Uses pass-through mouse filtering in its non-interactive hierarchy so swipes begun over the art
  or information panel reach the pager while the CTA remains independently clickable.
- `%InfoPanel` uses a 294 px unlocked height and a 340 px locked height, each 50 px taller than
  before; expanded vertical padding and spacing keep its content balanced within the extra room.
- `%CtaButton` uses scene-local flat green normal/hover/pressed styles sampled from
  `level_button_blank_new.png`, with the same border and 16 px corner geometry as
  `style_box_disabled_action_button.tres`; it switches to that shared neutral style while
  `Locked`/`Coming Soon`.
- `set_safe_margins(margins: Vector4)` insets `%InfoMargins`' left/right/bottom by a device
  safe-area margin on top of its authored padding; `%Art`/`%Atmosphere` are never inset, so cover
  art stays full-bleed under notches and display cutouts.

Important nodes:
- `%Art`, `%InfoPanel`, `%InfoMargins`, `%LockIcon`, `%StatusLabel`, `%EyebrowLabel`, `%TitleLabel`,
  `%ProgressLabel`, `%ProgressValueLabel`, `%ProgressBar`, `%CtaButton`.
- `%CtaButton`: `FOCUS_NONE` with the pointing-hand cursor (was `FOCUS_CLICK` with no cursor before
  UI-002's focus-policy normalization; see "Focus Policy" above).

Depends on:
- `ChapterCatalog.get_selection_preview_path()` for the cover art.
- `assets/ui/lock_shelf_cutout.png`, `scripts/press_scale_button.gd`.
- `assets/themes/style_box_disabled_action_button.tres`.

## `scenes/ui/destination_screen_shell.tscn`

Root:
- `DestinationScreenShell` (`Control`)

Script:
- `scripts/destination_screen_shell.gd`

Purpose:
- Shared fullscreen background + secondary-screen shade for Shop and Leaderboard, instanced as
  `%DestinationShell` (first child) in each. Owns only the background policy; catalog, purchase,
  leaderboard, ranking, and progression logic all stay in the owning screen's own script.
- `set_background_for_chapter(chapter_id)` follows the selected chapter's configured background
  through `MenuBackgroundResolver`, the same policy Main Menu uses -- fixes Shop/Leaderboard
  previously always showing the Chapter 1 background regardless of the player's selection.

Important nodes:
- `Background`: fullscreen `TextureRect`, default `assets/backgrounds/main_menu.jpeg`.
- `BackgroundShade`: fullscreen `ColorRect`, the canonical secondary-screen shade
  `Color(0.13, 0.025, 0.045, 0.66)`.

Depends on:
- `scripts/chapters/menu_background_resolver.gd`.

Do not use for:
- `%ContentMargin`, `%TitleLabel`, or `%BottomNavigation`. Those stay directly authored in each
  owning screen's own scene (`shop_screen.tscn`/`leaderboard_screen.tscn`) because Godot's
  `%unique_name` lookup cannot cross into a child instanced scene, and both headless verifiers
  (`scripts/tools/verify_shop.gd`/`verify_leaderboard.gd`) reach those nodes directly.

## `scenes/ui/destination_status_panel.tscn`

Root:
- `DestinationStatusPanel` (`CenterContainer`)

Script:
- `scripts/destination_status_panel.gd`

Purpose:
- Shared loading/empty/error/Retry presentation for Shop and Leaderboard, instanced as
  `%StatusPanel`. Leaderboard's previous plain, unbordered status text now matches Shop's
  bordered-panel treatment, and gains a genuine empty state ("No scores yet", no Retry) distinct
  from a retryable load error.
- Purely presentational: `show_loading(message)`, `show_empty(message)`, `show_error(message)`
  (shows Retry), `hide_status()`; emits `retry_pressed` for the owning screen to handle.
- `show_loading()` pulses `%StatusMessageLabel`'s opacity in a loop (`UIMotion` tokens) so an
  in-progress load reads as active rather than frozen; the pulse stops on every other state and on
  leaving the tree, and killing any previously tracked pulse first means repeated reloads (Shop
  Retry, Leaderboard scope switching) never accumulate loop tweens. Purely visual -- never blocks
  `ui_cancel` or bottom navigation.

Important nodes:
- `%StatusPanelBackground`: bordered panel using `style_box_status_panel.tres`.
- `%StatusMessageLabel`: pulses while loading (above).
- `%StatusRetryButton`: styled from the shared orange utility styleboxes (see "Shared UI Style
  Tokens") and uses `press_scale_button.gd` (0.94 held scale) for press feedback.

Depends on:
- `scripts/press_scale_button.gd`, `scripts/ui_motion.gd`.

## `scenes/ui/leaderboard_screen.tscn`

Root:
- `LeaderboardScreen` (`Control`)

Script:
- `scripts/leaderboard_screen.gd`

Purpose:
- Owns the dedicated leaderboard destination reached from the production menu trophy tab.
- Shows the required `Leaderboard` title and Weekly, Country, and World segmented buttons.
- Gives the central `LeaderboardScroll` the remaining vertical space between the tabs and the reusable bottom navigation.
- Builds up to 50 mock ranking rows in `RowsContainer` and keeps the local player visible through `PinnedPlayerRow` whenever their rank is absent or beyond the "visible without scrolling" threshold.
- Shows a weekly reset countdown, all-time scope descriptions, loading state, empty state, and retryable error state through `%StatusPanel` (`scenes/ui/destination_status_panel.tscn`).
- Centers content to a 720-pixel maximum logical width, compacts rows on short viewports, and applies Android/iOS safe-area padding through `scripts/destination_screen_layout.gd` (shared with Shop); the title now uses the same 48/40 regular/compact size as Shop instead of its previous 44/36.
- Follows the selected chapter's background through `%DestinationShell` (`scenes/ui/destination_screen_shell.tscn`) instead of a fixed Chapter 1 image.
- Fades in on `_ready()`; retapping the already-active Leaderboard bottom-navigation tab is a
  no-op (ranking refresh stays available only through `%StatusPanel`'s Retry); `ui_cancel` always
  returns to Main Menu, since Leaderboard has no scoped overlay of its own; a duplicate
  cross-destination press while a scene transition is in flight is ignored (see "Shared Interaction
  Roles" above).

Important nodes:
- `%DestinationShell`: shared fullscreen background + shade.
- `%WeeklyButton`, `%CountryButton`, `%WorldButton`: leaderboard scope controls; `press_scale_button.gd`
  (0.97 held scale) for momentary press feedback plus the existing persistent toggle-color for the
  selected scope, `FOCUS_NONE`. Hover now reuses the normal style, like every other control in
  scope, instead of the distinct hover color used before UI-002.
- `%PeriodLabel`: weekly countdown or all-time scope description.
- `%ListBackground`: gold-bordered backdrop panel behind the rows; hidden while `%StatusPanel` is showing so error/loading never nests two bordered panels.
- `%LeaderboardScroll`: vertical-only ranking list.
- `%RowsContainer`: runtime parent for reusable row instances.
- `%StatusPanel`: shared loading/empty/error/Retry presentation (`scenes/ui/destination_status_panel.tscn`).
- `%PinnedPlayerRow`: highlighted local-player entry outside the scroll view.
- `%BottomNavigation`: shared navigation instance with Leaderboard selected.

Depends on:
- `scenes/ui/leaderboard_row.tscn`.
- `scenes/ui/main_menu_bottom_navigation.tscn`.
- `scenes/ui/destination_screen_shell.tscn`, `scenes/ui/destination_status_panel.tscn`.
- `scripts/destination_screen_layout.gd`, `scripts/ui_motion.gd`, `scripts/press_scale_button.gd`.
- `scripts/leaderboards/leaderboard_service.gd`.
- `PlayerProgress` for the local player's name, avatar, lifetime stars, and weekly stars, and for the selected chapter id.

## `scenes/ui/leaderboard_row.tscn`

Root:
- `LeaderboardRow` (`Control`)

Script:
- `scripts/leaderboard_row.gd`

Purpose:
- Reusable ranking entry with rank, circular-clipped avatar, ellipsized player name, reward-star icon, and formatted score.
- Keeps normal cream row art and the green local-player highlight authored in the scene.
- `RankSlot` layers three hidden gold/silver/bronze medal circles behind `RankLabel`; exactly one
  shows for rank 1/2/3 (with the label reading a bare "1"/"2"/"3"), none for rank 4+ (label reads
  "#4" as before). Independent of the current-player highlight, so a top-3 row that is also the
  local player shows both.
- Instances `%RankReward` from `scenes/ui/leaderboard_rank_reward.tscn`. The owning screen binds it
  only for Weekly ranks 1-3; it remains hidden for all other rows and scopes.
- Supports regular and compact heights selected by the owning leaderboard screen.

Depends on:
- `assets/ui/avatars/*.png`.
- `assets/ui/avatar_circle_clip.gdshader`.
- `assets/ui/reward_star_34_glossy_b.png`.
- `scenes/ui/leaderboard_rank_reward.tscn`.

## `scenes/ui/leaderboard_rank_reward.tscn`

Root:
- `LeaderboardRankReward` (`PanelContainer`)

Script:
- `scripts/leaderboard_rank_reward.gd`

Purpose:
- Focused compact reward cell with a subtle translucent brown background that darkens the owning
  row, a transparent clover-coin pile that fills the available cell, and a formatted coin amount
  layered above the lower part of the artwork.
- Exposes regular and compact sizing for use inside responsive leaderboard rows.
- Starts hidden and is presentation-only; payout eligibility and amounts remain owned by the
  leaderboard screen and `PlayerProgress` reward-tier configuration.

## `scenes/ui/leaderboard_reward_dialog.tscn`

Root:
- `LeaderboardRewardDialog` (`Control`)

Script:
- `scripts/leaderboard_reward_dialog.gd`

Purpose:
- Dedicated modal overlay announcing a granted weekly leaderboard reward, structurally identical
  to `scenes/ui/shop_purchase_dialog.tscn` (title/message/close) but kept as its own scene since
  it lives on the main menu, not the Shop.
- Instantiated once as `main_menu.tscn`'s `%LeaderboardRewardDialog`.
- `show_reward()` fades in; `close()` (the Close button, or Main Menu's `ui_cancel` handling) fades
  out then hides, like `shop_purchase_dialog.tscn`. `%CloseButton` uses `press_scale_button.gd`
  (0.94 held scale) for press feedback and the same shared orange utility normal/pressed resources
  as the Shop purchase-result dialog and destination Retry action.

Depends on:
- `scripts/ui_motion.gd`, `scripts/press_scale_button.gd`.

## `scenes/ui/shop_screen.tscn`

Root:
- `ShopScreen` (`Control`)

Script:
- `scripts/shop_screen.gd`

Purpose:
- Owns the dedicated Shop destination with the `Shop` title, live coin balance, scrollable bundle and coin-offer sections, loading/error states, purchase result dialog, and shared bottom navigation.
- Builds offer views from `StoreService.load_catalog()`, which sources offers from `configs/shop_catalog.json` by default or from the authenticated backend development catalog when `application/config/shop_catalog_source` is `backend` (GAME-008), and always attaches the mock provider's formatted regional prices.
- Centers content to a 720-pixel maximum logical width, compacts offers below 1100 logical pixels high, and applies mobile safe-area margins through `scripts/destination_screen_layout.gd` (shared with Leaderboard).
- Follows the selected chapter's background through `%DestinationShell` (`scenes/ui/destination_screen_shell.tscn`) instead of a fixed Chapter 1 image.
- Fades in on `_ready()`; retapping the already-active Shop bottom-navigation tab is a no-op
  (catalog refresh stays available only through `%StatusPanel`'s Retry); `ui_cancel` closes an open
  `%PurchaseDialog` first if one is showing, otherwise returns to Main Menu; a duplicate
  cross-destination press while a scene transition is in flight is ignored (see "Shared Interaction
  Roles" above).

Important nodes:
- `%DestinationShell`: shared fullscreen background + shade.
- `%StatusPanel`: shared loading/error presentation (`scenes/ui/destination_status_panel.tscn`);
  the former "no offers for this region" case still resolves to the Retry-bearing error state.

Runtime children:
- `shop_bundle_card.tscn` for each bundle.
- `shop_coin_offer_row.tscn` for each coin-only offer.

## `scenes/ui/shop_bundle_card.tscn`

- Reusable full-width featured offer card with title, purchase button, and fixed reward cells for
  coins, Hammer, Shuffle, Lantern (`highlight` internally), and Freezer, in that display order
  (coins first, as the bundle's headline reward).
- The scene owns reward art and styling; `scripts/shop_bundle_card.gd` binds quantities and the store-formatted price.
- The purchase button uses `assets/ui/level_button_blank_new.png` for its normal, hover, pressed, and disabled backgrounds, plus `scripts/press_scale_button.gd` for the same centered held-press shrink as the main-menu level button.
- The root is `ShopBundleCard(PanelContainer) > CardBody(Control) > [CardStack, DiscountBadge]` so
  `DiscountBadge` can overlap the card's top-left corner instead of being confined to `CardStack`'s
  normal vertical flow.
- `DiscountBadge` is a slightly rotated, pinned red-and-gold tag using
  `assets/ui/discount_badge_pinned.png`, with live Godot labels showing "X% / OFF" so catalog
  discounts remain dynamic; a struck-through `CompareAtPriceLabel` above the purchase button
  shows the "was" price. Both stay hidden when the bound offer has no
  `discount_percent`/`compare_at_formatted_price`. A `TitleSpacer` before the title label is widened
  by `scripts/shop_bundle_card.gd` whenever the badge is showing, so the badge never overlaps the
  bundle title text.
- Each of the four ability reward cells (not coins) carries a transparent full-cell `*InfoButton`
  overlay so tapping the icon emits `ShopBundleCard.info_requested(ability_id)`; a small `InfoHint`
  caption below the rewards row tells the player they can tap for details. Each `*InfoButton` uses
  `press_scale_button.gd` with `visual_target_path` set to its sibling `Stack` (0.97 held scale), so
  the icon+count visibly presses without shrinking the full-cell tap target (see "Shared Interaction
  Roles" above) -- these cells had no press feedback at all before UI-002.

## `scenes/ui/shop_coin_offer_row.tscn`

- Reusable compact row with amount-scaled coin-pile art, formatted coin quantity, and store-formatted purchase button.
- The purchase button uses `assets/ui/level_button_blank_new.png` for its normal, hover, pressed, and disabled backgrounds, plus `scripts/press_scale_button.gd` for the same centered held-press shrink as the main-menu level button.
- `scripts/shop_coin_offer_row.gd` emits the bound offer id without granting rewards itself.
- `%CoinIcon` selects one of the seven transparent A1 clover-coin assets under
  `assets/ui/shop_coin_offers/` from the bound `rewards.coins` amount. The tier ceilings are 100,
  300, 750, 1,600, 3,500, and 13,000 coins; larger offers use the seventh overflowing-pouch tier.
- An optional `TagBanner` pill above the row content shows a short promotional tag (for example
  "BEST VALUE"); it stays hidden when the bound offer has no `tag`.

## `scenes/ui/coin_balance_widget.tscn`

- Reusable clover-coin pill used by the Shop header (regular, 158x68) and, through
  `scenes/ui/main_menu_coin_shortcut.tscn`, the Main Menu top status row (compact, 142x60).
  `set_compact(bool)` selects the variant; both reuse the exact same `%Pill` stylebox, `%CoinIcon`
  texture, and `GameNumberLabel` styling, so the two screens show the same palette/border/shape/
  icon and only differ in size. The pill uses the shared
  `assets/themes/style_box_status_counter_pill.tres` resource also consumed by the Main Menu lives
  counter. Updated from `PlayerProgress.get_coins()` via `set_amount()`.

## `scenes/ui/main_menu_coin_shortcut.tscn`

Root:
- `MainMenuCoinShortcut` (`Button`, extends `PressScaleButton`)

Script:
- `scripts/main_menu_coin_shortcut.gd`

Purpose:
- Wraps a compact `coin_balance_widget.tscn` instance with the Main Menu's green "+" badge inside
  a real tap target (`flat = true`, art-only hit target like `MainMenuTopStatus/ProfileWidget`).
- `production_main_menu.gd` connects the native `pressed` signal to `_open_shop()`, so tapping the
  coin balance opens the Shop (the same destination as the bottom-navigation Shop tab).
- Instanced as `main_menu_top_status.tscn`'s `CoinsWidget` node (name preserved so
  `main_menu_top_status.gd`'s `$CoinsWidget` center-exclusion-width lookup is unaffected).

Depends on:
- `scenes/ui/coin_balance_widget.tscn`.
- `scripts/press_scale_button.gd`.

## `scenes/ui/shop_purchase_dialog.tscn`

- Dedicated modal overlay for mock purchase success/error results and ability info lookups (a
  titled message with a configurable close-button label).
- Keeps dialog hierarchy and button wiring out of `shop_screen.gd`.
- `%CloseButton` uses the shared `style_box_orange_utility_normal/pressed.tres` (see "Shared UI
  Style Tokens") plus `press_scale_button.gd` (0.94 held scale) for press feedback -- it had none
  before UI-002.
- `show_result()` fades in; `close()` (the Close button, or Shop's `ui_cancel` handling) fades out
  then hides rather than freeing, since `shop_screen.gd` reuses the same instance for every
  purchase result.

Depends on:
- `scripts/ui_motion.gd`, `scripts/press_scale_button.gd`.

## `scenes/shop_verification.tscn`

- Automated verification entry scene for regional prices, required viewport sizes, five-cell
  starter reward layout, offer counts, amount-based coin-pile icon selection, the starter bundle's
  discount ribbon/compare-at price, the best-value coin tag, the ability info dialog, mock grants
  (including three Freezers), purchase dialog display, and duplicate-transaction handling.
- Also verifies the shared destination shell's background actually follows a chapter-id change
  (not just visually similar to Chapter 1) and that the status panel's Retry button resolves to
  the shared `style_box_orange_utility_normal.tres` resource instance.
- Must be launched with `scripts/tools/run_isolated_godot_test.ps1`; its verifier refuses the live
  `SortingPuzzle` project identity so mock purchases cannot mutate development player data.

## `scenes/leaderboard_verification.tscn`

- Automated verification entry scene for Weekly top-three reward images and configured amounts,
  Country reward hiding, removal of the former tier-summary label, and required portrait viewport
  bounds.
- Also verifies the shared destination shell's background follows a chapter-id change, the status
  panel's Retry button resolves to the shared orange utility style resource, the title label reads
  the shared regular size (48) at all five required resolutions, and (directly against
  `DestinationScreenLayout.get_title_font_size()`, since no required resolution produces a
  sub-1100 logical height under this project's `keep_width` stretch mode) the compact size (40).
- Must be launched with `scripts/tools/run_isolated_godot_test.ps1`; its verifier refuses the live
  `SortingPuzzle` project identity because it resets progress while preparing leaderboard data.

## `scenes/ui/main_menu_reward_star_flyer.tscn`

Root:
- `MainMenuRewardStarFlyer` (`Control`)

Script:
- `scripts/main_menu_reward_star_flyer.gd`

Purpose:
- Owns the fullscreen completed-level reward effect on the production menu.
- Creates one `reward_star_84x84.png` view per earned star, staggers flights from the house marker
  to the reward chest, and emits `star_arrived` for each one so the menu can advance the count.
- Renamed from `main_menu_reward_coin_flyer.tscn`/`MainMenuRewardCoinFlyer` (UI-002): this always
  represents earned stars, never spendable coins, and previously flew clover-coin art -- see
  "Reward-Progress Semantics" in "Shared Interaction Roles" above. Neither this file nor its script
  used `uid://` references, so the rename and every reference to it (`main_menu.tscn`,
  `production_main_menu.gd`) updated together with no risk of a stale resource link.

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
- Uses enlarged scene-owned `TextureRect` icon controls; each button's `Icon` is a `press_scale_button.gd` `visual_target_path` (0.97 held scale) so the whole 96px hit area stays full-size while only the icon visibly presses (see "Shared Interaction Roles" above).
- Raises the active screen's icon above the bar height and reveals its small `Shop`, `Home`, or `Leaderboard` label underneath, animating the icon's raise/lower and the label's fade over `UIMotion.NAV_ACTIVE_CHANGE_DURATION` instead of jumping; inactive icons remain centered with labels hidden. Screens never live-switch their own bottom nav's active tab (Home/Shop/Leaderboard are separate scenes), so this animates once, on scene entry.
- Defaults to Home and exposes `set_active_tab(tab_name)` so Shop and Leaderboard screens can select their matching visual state.
- Adds bottom safe-area padding supplied by the production menu without narrowing the full-width background.
- Emits focused button signals so each destination can route without moving navigation ownership into the shared component; `pressed` always forwards regardless of prior state; whether retapping the already-active destination does anything is up to the owning screen (a documented no-op everywhere -- see "Active-Tab Reselection Rule" above).

Depends on:
- `assets/ui/shopping_cart_icon_128x128.png`.
- `assets/ui/home_navigation_icon_1_128x128.png`.
- `assets/ui/trophy_icon_128x128.png`.
- `scripts/press_scale_button.gd`, `scripts/ui_motion.gd`.

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
- `Visual`: full-rect wrapper around `ChestIcon`/`IconShadow`/`ProgressTrack` -- `ChestButton`'s
  `press_scale_button.gd` `visual_target_path` (0.97 held scale), so the chest visibly presses
  without shrinking `ChestButton`'s own full-rect touch area (see "Shared Interaction Roles" above).
- `Visual/ChestIcon`: selected transparent treasure chest PNG.
- `Visual/ProgressTrack`: framed bar container under the chest.
- `Visual/ProgressTrack/ProgressBar`: fill amount controlled by the script.
- `Visual/ProgressTrack/AmountLabel`: centered `current/goal` label with dynamic font sizing.
- `ChestButton`: full-rect flat, focus-less tap target layered above `Visual` (its former
  siblings now live inside `Visual`, still `mouse_filter = Ignore`); forwards its `pressed` signal
  as `chest_pressed`.

Depends on:
- `assets/ui/main_menu_reward_chest.png`.
- `scripts/main_menu_reward_chest.gd`, `scripts/press_scale_button.gd`.
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
- Shows the `Chest rewards` title, a star-to-chest `current/goal` progress row, explanatory copy
  between the progress row and bordered hero illustration, the coin payout waiting at the active
  goal, and a large `Continue` button.
- Purely informational: coins are still granted automatically on goal rollover in
  `scripts/player_progress.gd`, so `Continue` only closes the modal and does not claim anything.
- The 640x900 logical-pixel outer panel occupies most of the 720-wide design viewport while still
  fitting the shorter tablet-like logical viewport produced by the project's `keep_width` stretch.
- The `ChestStage` uses `assets/ui/Treasure_chest_with_game_items_202607280535.jpeg`. The small
  main-menu reward chest remains a separate icon and also marks the goal end of the progress row.

Important nodes:
- `RewardChestPanel`: centered outer popup panel, styled like `scenes/ui/profile_menu.tscn`'s panel.
- `CloseButton`: protruding red circular close button; the script wires it to `queue_free()`.
- `InnerPanel/ContentStack/ProgressRow`: star icon, progress column, and reward-chest goal icon.
- `ProgressRow/ProgressColumn/ProgressTrack/ProgressBar` and `.../AmountLabel`: bound to the active
  goal; `ProgressColumn/GoalCaptionLabel` shows `"<n> stars to go"`.
- `InnerPanel/ContentStack/HeroBodyLabel`: centered unlock guidance between the progress row and
  hero image.
- `InnerPanel/ContentStack/ChestStage`: bordered, aspect-covered hero image with a translucent
  headline overlay and bottom reward badge. The image uses
  `assets/ui/rounded_texture_clip.gdshader` with a 16-pixel image radius inside the frame's
  8-pixel inset, keeping it concentric with the frame's 24-pixel radius.
- `ChestStage/RewardBadge/NextRewardRow/NextRewardLabel`: `"Reward: +<n> coins"` from the active
  goal's `coin_reward`.
- `ContinueButton`: large green action in the outer panel's reserved footer area; closes the modal
  like `CloseButton`.

Depends on:
- `assets/ui/Treasure_chest_with_game_items_202607280535.jpeg`,
  `assets/ui/reward_star_84x84.png`, `assets/ui/main_menu_reward_chest.png`,
  `assets/ui/main_menu_coin.png`, `assets/ui/level_button_blank_new.png`, and
  `assets/ui/rounded_texture_clip.gdshader`.
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
- `ProfileWidget`: circular avatar button; `press_scale_button.gd` with `visual_target_path` set to
  `AvatarTexture` (0.97 held scale), so the avatar visibly presses without shrinking the 76x76 tap
  target (see "Shared Interaction Roles" above) -- it had no press feedback at all before UI-002.
- `ProfileWidget/AvatarTexture`: saved player avatar texture, clipped to a circle at runtime.
- `CoinsWidget`: `scenes/ui/main_menu_coin_shortcut.tscn` instance (compact coin balance + "+"
  badge, tappable to open the Shop). Kept named `CoinsWidget` so `scripts/main_menu_top_status.gd`'s
  `$CoinsWidget` center-exclusion-width lookup is unchanged.
- `Spacer02`: non-expanding center exclusion corridor resized around camera cutouts.
- `LivesWidget`: generated heart icon, current life count label, and `Full` or `MM:SS` countdown
  status label, vertically centered within the pill. Its compact pill background matches `CoinsWidget` through the shared
  `assets/themes/style_box_status_counter_pill.tres` resource and matching 118x44 geometry.
- `SettingsWidget`: warm rounded settings button matching the chapter selection screen's `BackButton` styling and held-press behavior; `FOCUS_NONE` with the pointing-hand cursor.

Depends on:
- `assets/ui/avatars/avatar_cat.png` for the default editor/display texture. The owning menu script replaces it with the saved avatar at runtime.
- `assets/ui/avatar_circle_clip.gdshader` as a defensive runtime clip around the alpha-cleaned avatar PNGs.
- `scenes/ui/main_menu_coin_shortcut.tscn`.
- `assets/ui/main_menu_lives.png`.
- `scripts/press_scale_button.gd`.
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
- `assets/ui/avatars/*.png`, stored with transparent pixels outside each circular badge.
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
- `LevelButton`: clickable button root with the generated texture style, white outlined text, and dynamic pressed/hover/disabled states; `FOCUS_NONE` with the pointing-hand cursor (see "Focus Policy" above; the cursor was missing before UI-002).

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
