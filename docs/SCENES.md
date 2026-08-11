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
  otherwise the destination Shop returns to Main Menu and the in-level Shop variant returns to
  Ability Purchase.
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

## Shared Gameplay UI Roles (UI-003)

The playable level (`level.tscn`'s HUD, ability bar, Pause, Leave Confirmation, Ability Purchase,
Completion, and Failure) uses its own intentional system, separate from the menu-scope tokens
above: the level intentionally keeps a denser, higher-contrast gameplay presentation (per
`docs/UI_003_LEVEL_UI_CONSISTENCY_TICKET.md`'s Objective), so equivalent concepts share gameplay-
scoped colors/shapes/components instead of either scene-local approximations or the menu system's
brighter cream/red palette. Reused directly where the semantic role already matches exactly:
`style_box_green_primary_button.tres` (positive: Continue/Buy) and
`style_box_disabled_action_button.tres` (unavailable: disabled Buy, the dev-preview Watch-Ad
placeholder).

**Shared gameplay style resources** -- new `assets/themes/style_box_gameplay_*.tres` files, each a
single role reused by reference (no more copy-pasted `StyleBoxFlat`/`StyleBoxTexture` sub-resources
inside gameplay `.tscn` files):

- `style_box_gameplay_modal_shade.tres` / `style_box_gameplay_result_shade.tres`: the two shade
  roles the ticket calls for -- one modal dim (`Color(0.02, 0.025, 0.03, 0.66)`, shared by Pause/
  Leave Confirmation/Ability Purchase) and one stronger terminal-result shade
  (`Color(0.04, 0.035, 0.045, 0.76)`, shared by Completion and Failure -- unified from Completion's
  and Failure's previously-different 0.76/0.68 values onto Completion's, the more deliberately tuned
  of the two).
- `style_box_gameplay_modal_outer_panel.tres` / `style_box_gameplay_modal_inner_panel.tres`: the
  terracotta outer panel and cream inner panel shared by every gameplay modal. The outer panel is
  now radius 24 (the large-panel role), not the previous locally-duplicated radius 30.
- `style_box_gameplay_close_button_{normal,pressed,hover}.tres`: the true-circular red close action
  (72px control, radius 36 -- was 32, i.e. not actually a true circle before) shared by every
  gameplay modal's close button.
- `style_box_gameplay_hud_icon_{normal,pressed,hover,disabled}.tres`: the circular ability-button
  role used by all four abilities. One set of four styles (not one set per size) covers both the
  compact (82px) and regular (96px) sizes: each uses a deliberately
  oversized `corner_radius`, which Godot clamps to half the control's smaller dimension, so it
  renders as a true circle at either size without needing size-specific resources. Includes an
  explicit `disabled` style so blocked abilities never fall back to Godot's default square style.
- `style_box_warm_icon_{normal,pressed}.tres`: the top-HUD Pause control deliberately reuses the
  Main Menu settings-button role at 72x64, including its dark-brown scene-authored pause bars. Its
  explicit disabled override points at the warm normal resource, preventing default-style fallback.
- `style_box_gameplay_count_badge.tres`: the shared inventory/count badge used by ability-bar
  remaining-use counts and Leave Confirmation's loss counts. Same oversized-radius trick for a
  true pill/circle at any authored size.
- `style_box_gameplay_timer_badge.tres`: the documented navy/cyan timed-status badge exception
  (Lantern/Freezer countdown badges on the ability bar), extracted from a previously-duplicated
  local sub-resource with no visual change.
- `style_box_gameplay_status_pill.tres`: the level's star-total pill (`level_top_hud.tscn`'s
  `%StarCounter`), keeping its existing dark-navy/gold gameplay palette but now a true pill via the
  oversized-radius trick -- distinct from the menu system's cream/red `style_box_status_counter_pill.tres`
  (different visual language, same "pill" shape rule).
- `style_box_gameplay_destructive_action.tres`: the shared red Leave action (`StyleBoxTexture`
  wrapping `level_button_blank_red_new.png`), replacing duplicated local copies in Pause and Leave
  Confirmation.
- `style_box_gameplay_item_slot.tres`: the shared "cell" role (radius 20, the menu system's rows/
  cells geometry) for the Ability Purchase icon slot and the Leave Confirmation loss slots,
  unifying their previously-mismatched local 30/20 radii.

**`scripts/gameplay_ui_theme.gd`** (`GameplayUITheme`) is the gameplay-scope equivalent of
`scripts/destination_screen_layout.gd`: HUD icon compact/regular sizes and breakpoint, modal
safe-fit geometry, modal-title regular/long typography sizes, and the terminal-result hero title
role + responsive scale. See `docs/SCRIPTS.md` for its full API.

**`scenes/ui/gameplay_modal_shell.tscn`** (`scripts/gameplay_modal_shell.gd`) and
**`scenes/ui/gameplay_result_shell.tscn`** (`scripts/gameplay_result_shell.gd`) are the two shared
shells -- see their own entries below and in `docs/SCRIPTS.md` for the full ownership split (shell
owns shade/panel/title/close/safe-area/motion; the owning scene keeps its own content and signals).
The modal shell preserves the authored 520x500 composition and uniformly scales the complete panel
subtree when safe insets leave less room; this keeps title, close cutout, content, and action-row
minimum sizes inside the same fitted rect instead of shrinking only the outer panel. Owners set a
compact content-region height (224px for Pause/Purchase, 240px for Leave Confirmation) so the cream
panel fits its content instead of stretching to fill the outer shell.

**Interaction/motion** -- every gameplay button now uses `press_scale_button.gd`: `0.94` for CTAs
(including Pause's warm settings-role control, Leave/Continue/Buy/Watch-Ad/Completion's Continue/
Failure's Main Menu action), `0.97` for ability and modal-close icon buttons. Every gameplay-owned
control is `FOCUS_NONE` with the pointing-hand cursor
while enabled and the arrow cursor while disabled, matching the menu system's touch-only policy.
Modal/result open and close fade via
`scripts/ui_motion.gd` (`OVERLAY_DURATION`) instead of snapping between `visible` states, and every
shell exposes `is_transitioning()` so `scripts/level.gd`'s button handlers and `ui_cancel` chain can
ignore duplicate input until a fade settles. Owner wrappers also verify that their shell remained
closed before hiding their root, so an interrupted close cannot hide a freshly reopened modal.

**`ui_cancel` back stack** -- `scripts/level.gd::_unhandled_input()` (there was no back-button
handling at all during gameplay before this ticket) implements one topmost-state-first order: the
in-level Shop returns to Ability Purchase; Leave Confirmation returns to Pause; Ability Purchase
closes and restores the state it opened from (Pause if opened from Pause, otherwise resumes
gameplay); Pause resumes; Completion invokes its `Continue` route and Failure its `Main Menu`
route; otherwise (active gameplay) opens Pause. Every branch
reuses the exact handler its equivalent button already calls, so it can never spend a life, coin, or
star by itself, and a press during any overlay/result screen's in-flight transition is dropped
rather than acted on.

**Rewarded-ad placeholder policy** -- `WatchAdButton` (`scenes/ability_purchase_menu.tscn`) is never
an enabled no-op. It is hidden entirely outside a debug build; inside one it stays visible but
disabled with `"Coming Soon"` copy and the shared unavailable style, mirroring
`scripts/main_menu.gd`'s existing `DEV_LEVEL_SELECT_SETTING` debug-build-gate convention.

**Verification** -- `tests/ui/test_level_ui_consistency.gd` (run via
`scripts/tools/run_isolated_godot_test.ps1`) covers shared gameplay resource identity, explicit
disabled styles (no engine-default fallback), the `FOCUS_NONE`/pointing-hand-cursor sweep, the
rewarded-ad placeholder never being an enabled no-op, Completion/Failure copy and signal routing,
the full `ui_cancel` chain including a dropped in-flight-transition press, safe-area layout at
fabricated insets using post-layout rendered rectangles (including a tight viewport that must fit
the modal's action and close controls instead of only shrinking its outer panel),
regular/compact ability icon+badge bounds, long-value formatting (`LEVEL 99`, `59:59`, a six-digit
star total, a six-digit ability count, an active ability timer), disabled cursor restoration,
interrupted modal close/reopen behavior, shared Completion/Failure CTA identity, and locked-shelf
count-pulse/unlock-animation feedback.

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
  `Level 1`; zero lives keeps it enabled and opens Out of Lives, while completed/unavailable
  chapters remain disabled as `Chapter Complete` or `Coming Soon`.
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
- `%OutOfLivesMenu`: hidden `scenes/ui/out_of_lives_menu.tscn` instance on the shared modal z-index.
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
- Owns the reusable Shop presentation with the `Shop` title, live coin balance, scrollable bundle
  and coin-offer sections, loading/error states, and purchase result dialog. Destination mode shows
  shared bottom navigation; in-level overlay mode hides it and shows `%OverlayCloseButton`.
- Builds offer views from `StoreService.load_catalog()`, which sources offers from `configs/shop_catalog.json` by default or from the authenticated backend development catalog when `application/config/shop_catalog_source` is `backend` (GAME-008), and always attaches the mock provider's formatted regional prices.
- Centers content to a 720-pixel maximum logical width, compacts offers below 1100 logical pixels high, and applies mobile safe-area margins through `scripts/destination_screen_layout.gd` (shared with Leaderboard).
- Follows the selected chapter's background through `%DestinationShell` (`scenes/ui/destination_screen_shell.tscn`) instead of a fixed Chapter 1 image.
- Fades in on `_ready()`; retapping the already-active Shop bottom-navigation tab is a no-op
  (catalog refresh stays available only through `%StatusPanel`'s Retry); `ui_cancel` closes an open
  `%PurchaseDialog` first if one is showing, otherwise returns to Main Menu; a duplicate
  cross-destination press while a scene transition is in flight is ignored (see "Shared Interaction
  Roles" above).
- In-level overlay mode exposes `open()`/`close()`/`is_transitioning()`, emits
  `close_requested`/`closed`, and reserves only the safe-bottom inset instead of the absent bottom
  navigation. Its X and `ui_cancel` both return through the Level-owned overlay stack.

Important nodes:
- `%DestinationShell`: shared fullscreen background + shade.
- `%OverlayCloseButton`: safe-area-contained red circular X, hidden in destination mode and shown
  in in-level overlay mode.
- `%StatusPanel`: shared loading/error presentation (`scenes/ui/destination_status_panel.tscn`);
  the former "no offers for this region" case still resolves to the Retry-bearing error state.

Runtime children:
- `shop_bundle_card.tscn` for each bundle.
- `shop_coin_offer_row.tscn` for each coin-only offer.

## `scenes/ui/in_level_shop_screen.tscn`

- Dedicated inherited Shop variant configured with `ShopScreen.IN_LEVEL_OVERLAY`.
- Instanced by `level.tscn` above Ability Purchase when the player presses its coin-price action
  without enough coins.
- Reuses the exact destination Shop catalog, StoreService purchase flow, balance widget, offer
  scenes, selected-chapter background, loading/error state, and purchase-result dialog.
- Has no Bottom Navigation; X/system back closes it and restores Ability Purchase without spending
  coins or applying the pending ability.

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

## `scenes/ui/out_of_lives_menu.tscn`

Root:
- `OutOfLivesMenu` (`Control`)

Script:
- `scripts/out_of_lives_menu.gd`

Purpose:
- Main-menu modal shown after the player requests a campaign level with zero lives.
- Composes `scenes/ui/gameplay_modal_shell.tscn` for the shared shade, cream content region, title,
  close action, responsive safe-area fitting, and fade motion.
- Shows `OUT OF LIVES`, `assets/ui/main_menu_lives.png` with a zero count, the live `MM:SS`
  restoration countdown, a green clover-coin price action, and a production-visible disabled
  `Coming Soon` action.
- Emits purchase/close intent only; `production_main_menu.gd` owns navigation while
  `PlayerProgress` owns the atomic offline economy mutation.

Important nodes:
- `%LifeCountLabel`, `%CountdownLabel`, and `%PriceLabel`: state supplied by the Main Menu.
- `%PurchaseButton`: green 194x76 coin-price action using the shared primary style.
- `%ComingSoonButton`: always-visible, always-disabled neutral placeholder.

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn`, `assets/ui/main_menu_lives.png`, the canonical clover coin
  art, and the shared green/disabled action styles.

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
- `UI/CompletionScreen`: `scenes/ui/level_completion_screen.tscn` instance whose reveal begins 1.35
  seconds after all items clear, while the longer confetti fall continues.
- `UI/CompletionConfetti`: `scenes/effects/level_completion_confetti.tscn` instance, kept last in the
  `UI` layer so its foreground paper pieces bridge the cleared board and reward overlay.
- `UI/PauseMenuOverlay`: `scenes/pause_menu.tscn` instance used for the modal pause menu.
- `UI/LeaveConfirmationOverlay`: `scenes/leave_confirmation_menu.tscn` instance shown after the pause menu's Leave button, before spending a campaign life and returning to the menu.
- `UI/AbilityPurchaseOverlay`: `scenes/ability_purchase_menu.tscn` instance shown when the player taps an ability with zero saved uses remaining.
- `UI/InLevelShopOverlay`: `scenes/ui/in_level_shop_screen.tscn` instance shown above Ability
  Purchase when its configured coin price is unaffordable.

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
- `scenes/ui/in_level_shop_screen.tscn`
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
  touch target and a 96x96 regular target -- the circular ability icon-button role (UI-003, see
  "Shared Gameplay UI Roles" above).
- Owns remaining-use badges (`style_box_gameplay_count_badge.tres`) plus independent Lantern and
  Freezer active countdown badges (`style_box_gameplay_timer_badge.tres`).
- Emits `ability_pressed(ability_id)` and exposes focused state/layout methods; `scripts/level.gd`
  remains the gameplay/economy orchestrator.
- All four buttons use `press_scale_button.gd` (0.97 held scale) and carry a `tooltip_text`; Freezer
  no longer sets unique visible button text, so all four read as icon-only.
- `apply_responsive_layout(usable_width)` rescales each button's Icon/UsesLabel/TimerLabel rects
  proportionally to the actual button size (UI-003), not only the parent button's
  `custom_minimum_size` -- previously those children stayed at their 96px-authored offsets and
  overflowed the 82px compact button.

Important nodes:
- `ButtonRow/HammerButton`
- `ButtonRow/ShuffleButton`
- `ButtonRow/HighlightButton/TimerLabel`
- `ButtonRow/FreezerButton/TimerLabel`

Depends on:
- `scripts/gameplay_ui_theme.gd` for the shared compact/regular size and breakpoint.
- `scripts/press_scale_button.gd`.

Do not use for:
- Mutating inventory/economy state or applying gameplay effects. Main Menu may route its own
  Out-of-Lives purchase intent, but persistence remains in `PlayerProgress`; in-level ability
  purchasing/effects remain in `scripts/level.gd`.

## `scenes/ability_purchase_menu.tscn`

Root:
- `AbilityPurchaseOverlay` (`Control`; was a `ColorRect` before it composed the shared shell for its
  own shade)

Script:
- `scripts/ability_purchase_menu.gd`

Purpose:
- Reusable in-level purchase modal shown by `scripts/level.gd` when the player tries to use
  hammer, shuffle, highlight/Lantern, or Freezer with zero remaining uses.
- Composes `scenes/ui/gameplay_modal_shell.tscn` (`Shell`) for the shared shade, outer panel, title,
  close button, content region, and action row (UI-003; see "Shared Gameplay UI Roles" above),
  instead of locally repeating the leave-confirmation modal's styling.
- Shows the `USE ABILITY` title (was `GET MORE ITEMS`), the selected ability icon in a centered
  slot, a green coin-price image button, and the hidden-in-production `Watch ad` action. The
  redundant `USE NOW` badge was removed; the title and price action already communicate the flow.

Important nodes:
- `Shell`: the shared modal shell instance.
- `PurchaseContent`: reparented into `Shell`'s compact 224px content region at `_ready()`; holds
  `AbilitySlot` (`style_box_gameplay_item_slot.tres`) and `%AbilityIcon`.
- `%BuyButton`: reparented into `Shell`'s action row; its child `PriceRow` shows the canonical
  `assets/ui/clover_coin_transparent_96x96.png` and the configured price. It remains an enabled
  green action when unaffordable so `scripts/level.gd` can open the in-level Shop; only a successful
  paid-use preflight spends coins or applies the ability.
- `%WatchAdButton`: reparented into `Shell`'s action row; always `disabled = true` with `"Coming
  Soon"` text and the shared disabled style, `visible` set to `OS.is_debug_build()` at `_ready()` --
  hidden in production, visible-but-inert in a debug build. Never an enabled no-op.

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn`.
- `assets/ui/clover_coin_transparent_96x96.png`.
- `assets/themes/style_box_gameplay_item_slot.tres`, `style_box_green_primary_button.tres`,
  `style_box_disabled_action_button.tres`.
- `scripts/press_scale_button.gd`.
- Runtime offer setup, coin spending, and ability execution from `scripts/level.gd`.

Do not use for:
- Price configuration, coin persistence, or ability execution. Those stay in `configs/ability_purchase_prices.json`, `scripts/player_progress.gd`, and `scripts/level.gd`.

## `scenes/ui/level_completion_screen.tscn`

Root:
- `LevelCompletionScreen` (`Control`; was a `ColorRect` before it composed the shared result shell
  for its own shade)

Script:
- `scripts/level_completion_screen.gd`

Purpose:
- Reusable completed-level reward overlay instanced by `level.tscn`.
- Composes `scenes/ui/gameplay_result_shell.tscn` (`Shell`) for the shared terminal shade, hero
  title (`Great job!`), action placement, safe-area layout, and open/close fade (UI-003; see
  "Shared Gameplay UI Roles" above). Keeps its own star image/earned-count placement, which stays
  local since it is state-specific (not shared with `scenes/ui/level_failure_screen.tscn`).
- Pops in the title/reward star, then bounces in the earned count and action; five small tinted
  paper-star nodes flash around the reward and continue a restrained twinkle while the screen waits.
- Displays the reward star image and earned-star count label, and emits `next_pressed` (unchanged
  signal name) so `scripts/level.gd` can advance campaign levels or return dev/test launches to
  their menu. The action button now reads `Continue` (was `Next`) -- same return-to-menu behavior.

Important nodes:
- `Shell`: the shared result shell instance.
- `StarImage`: large `assets/ui/reward_star.png` reward art, reparented into `Shell`'s content region.
- `SparkleLayer` / `Sparkle*`: responsive, input-transparent tinted paper-star glints positioned
  around `StarImage`; their intro and idle twinkle are owned by the screen script.
- `EarnedStarsLabel`: final run star count formatted as `×N`; its responsive center sits 150 design
  pixels below the reward star center. Reparented into `Shell`'s content region.
- `NextButton`: green blank-image button reading `Continue`, reparented into `Shell`'s action row,
  with `scripts/press_scale_button.gd` so it visually shrinks while held.

Depends on:
- `scenes/ui/gameplay_result_shell.tscn`.
- `assets/ui/reward_star.png`, `assets/effects/confetti_paper_star.png`, and the shared
  `style_box_green_primary_button.tres`.
- `scripts/press_scale_button.gd`, `scripts/gameplay_ui_theme.gd`.

Do not use for:
- Puzzle completion checks, campaign save writes, or scene progression. Those stay in `scripts/level.gd`.

## `scenes/ui/level_failure_screen.tscn`

Root:
- `LevelFailureScreen` (`Control`)

Script:
- `scripts/level_failure_screen.gd`

Purpose:
- Reusable level-failure overlay instanced by `level.tscn` (UI-003 P0, new). `level.tscn` previously
  embedded a bare shade + `LEVEL FAILED` label directly with no action at all --
  `scripts/level.gd::_fail_level()` only made it visible, leaving the player in a terminal screen
  with no route forward. This scene gives Failure the same working exit Completion already has.
- Composes `scenes/ui/gameplay_result_shell.tscn` (`Shell`) for the same shared terminal shade, hero
  title (`LEVEL FAILED`), action placement, safe-area layout, and open/close fade Completion uses,
  without merging their state-specific content.
- Emits `main_menu_pressed` so `scripts/level.gd` can return to the main menu.

Important nodes:
- `Shell`: the shared result shell instance.
- `MessageLabel`: short body copy, reparented into `Shell`'s content region.
- `MainMenuButton`: green blank-image button reading `Main Menu` (the same positive/CTA role and
  size as Completion's `Continue`), reparented into `Shell`'s action row, with
  `scripts/press_scale_button.gd` (0.94 held scale).

Depends on:
- `scenes/ui/gameplay_result_shell.tscn`.
- The shared `style_box_green_primary_button.tres`.
- `scripts/press_scale_button.gd`, `scripts/gameplay_ui_theme.gd`.

Do not use for:
- Retry/run-lifecycle behavior (out of this ticket's scope -- Failure exits to Main Menu only).
  Puzzle failure conditions and life spending stay in `scripts/level.gd`.

## `scenes/effects/level_completion_confetti.tscn`

Root:
- `LevelCompletionConfetti` (`Control`, full-rect and input-transparent)

Script:
- `scripts/level_completion_confetti.gd`

Purpose:
- Layered paper-confetti celebration played by `scripts/level.gd` while the cleared board stays on
  screen. The reward overlay begins opening 1.35 seconds into the longer fall, and the effect is kept
  last in the `UI` layer so its foreground pieces visibly bridge both states.
- Extracted rather than assembled in `scripts/level.gd` (see AGENTS.md's Scene Extraction Rule): the
  piece look is scene-authored and tunable without touching gameplay code.

Important nodes:
- `LeftBackCurl` / `RightBackCurl`, `LeftCannon` / `RightCannon`, `LeftFold` / `RightFold`,
  `LeftStars` / `RightStars`, and `LeftFrontCurl` / `RightFrontCurl`: five depth/shape layers per
  corner. They use the four transparent Paper A textures in `assets/effects/`, varied arc heights,
  piece sizes, color ramps, tumble, opacity, and z-indices while keeping side-emitter count at 248.
- `CentralFlash`: short radial gradient flash at the arc intersection.
- `CenterBurst`: delayed 18-piece textured paper-star pop on the same center beat.
- Muzzle positions, direction, launch speed, gravity, and responsive sprite scale are recomputed for
  the live viewport on every `play()`; the scene values are design-resolution defaults.

Depends on:
- `scripts/level.gd` for playback on completion.
- `tests/gameplay/test_level_completion_confetti.gd` for celebration-window and aim verification.

Do not use for:
- Star awards, completion rules, or the reward screen. Those stay in `scripts/level.gd` and
  `scenes/ui/level_completion_screen.tscn`.

## `scenes/abilities/hammer_impact_effect.tscn`

Root:
- `HammerImpactEffect` (`Control`)

Script:
- `scripts/hammer_impact_effect.gd`

Purpose:
- Reusable fullscreen hammer strike effect spawned by `scripts/level.gd` when the hammer ability is used.
- Displays the normalized transparent versions of the supplied numbered hammer frames in exact
  1-through-8 order. Frames 1-6 share a 680x680 canvas; the portrait source canvases for frames 7-8
  become 453x680 so their intended closer head framing is retained.
- Owns the editable 1.26 second `AnimationPlayer` `strike` animatic: raised upper-right approach,
  eight evenly readable texture swaps, accelerating center descent, final-frame impact, short
  recoil/dissolve, subtle frame-derived afterimages, layered impact amounts, audio callbacks, and
  gameplay signal timing.
- Ends the hammer with a fade-and-flare dissolve rather than a rebound, so the head does not sit
  over the cell it just cleared while the burst plays.
- Emits `pre_impact` at 400 ms for item compression and `impact` at 580 ms so gameplay hides and
  frees the merged item on the visual hit frame. Reward stars begin 140 ms later, during the
  remaining recoil/VFX tail.
- Owns the entrance/downstroke, impact-thump/magic, and sparkle-tail `AudioStreamPlayer` nodes. The
  level passes the current sound setting into `play()` and can mute an active effect through the
  `hammer_impact_effect` group.

Important nodes:
- `ImpactAnchor`: runtime-positioned at the exact viewport center after the three selected items
  finish converging and settle as one visible item; scales the full hammer for the current
  viewport. Its `scale.x` flips to `-1` for reusable targets past
  `MIRROR_THRESHOLD_RATIO` so right-side strikes approach from the left instead of hanging the
  raised pose off the viewport edge.
- `ImpactAnchor/HammerPivot`: keyframed by `AnimationPlayer` for wind-up, strike, and dissolve motion.
- `ImpactAnchor/HammerPivot/HammerSprite`: transparent hammer sprite whose texture is value-keyframed
  by the `strike` animation. Its position is not keyframed — the script derives it each frame from
  `POSE_HEAD_OFFSETS` so every frame's head centre stays on the pivot the impact VFX are drawn
  around.
- `ImpactAnchor/HammerPivot/AfterimageEarly` / `AfterimageLate`: subtle low-alpha tinted copies of
  frames 5 and 6 behind the live hammer during the descent, sharing one additive canvas material.
- `WindupAudio`, `DownstrokeAudio`, `ImpactLowAudio`, `ImpactMagicAudio`, and `SparkleTailAudio`:
  scene-owned layered cues built from the project's existing short SFX palette.
- `AnimationPlayer`: owns the `strike` animation; edit this timeline for most hammer motion and timing adjustments.

Depends on:
- `assets/abilities/ability_hammer_swing_*.png` for the normalized supplied frames 1 through 8. The
  `rebound` and `rebound_transition` art is no longer referenced.
- `assets/audio/item_place.wav`, `assets/audio/triple_clear.wav`, and
  `assets/audio/A_short_satisfying_i_#3-1782529645197.wav`, layered with scene-specific pitch and
  volume settings.
- Runtime instancing and target positioning from `scripts/level.gd`.
- `tests/gameplay/test_hammer_animation.gd` for deterministic timing/integration verification and optional movie capture.

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

## `scenes/ui/gameplay_modal_shell.tscn`

Root:
- `GameplayModalShell` (`Control`)

Script:
- `scripts/gameplay_modal_shell.gd`

Purpose:
- Shared gameplay modal shell (UI-003): fullscreen shade + input blocker, safe-area-fitted centered
  outer panel, title region (regular/long variant), true-circular close action, cream content
  region, and bottom action row. See "Shared Gameplay UI Roles" above for the full role rationale.
- `scenes/pause_menu.tscn`, `scenes/leave_confirmation_menu.tscn`, and
  `scenes/ability_purchase_menu.tscn` each instance this as their first child (`Shell`) and
  reparent their own content/action buttons into its slots at `_ready()`, instead of each repeating
  shade/panel/close-button styling locally. Composed (instanced as a child), not Godot scene
  inheritance -- matches the existing `scenes/ui/destination_screen_shell.tscn` pattern.

Important nodes:
- `Shade`: full-rect `Panel`, `style_box_gameplay_modal_shade.tres`.
- `%OuterPanel`: centered `Panel`, `style_box_gameplay_modal_outer_panel.tres`; sized/positioned by
  `apply_safe_layout()`.
- `%TitleLabel`: `GameTitleLabel`, regular (44) or long (40) size via `configure()`.
- `%CloseButton`: true-circular red close (72px, radius 36), `press_scale_button.gd` (0.97 held scale).
- `%ContentRegion`: cream `Panel`, `style_box_gameplay_modal_inner_panel.tres`; owning scenes
  reparent their own content here.
- `%ActionRow`: `HBoxContainer`; owning scenes reparent their own action buttons here.

Depends on:
- `assets/themes/style_box_gameplay_modal_shade.tres`, `style_box_gameplay_modal_outer_panel.tres`,
  `style_box_gameplay_modal_inner_panel.tres`, `style_box_gameplay_close_button_{normal,pressed,hover}.tres`.
- `scripts/ui_motion.gd`, `scripts/gameplay_ui_theme.gd`, `scripts/press_scale_button.gd`.

Do not use for:
- Modal content, gameplay data, or signal ownership. Those stay in the owning scene's own script.

## `scenes/ui/gameplay_result_shell.tscn`

Root:
- `GameplayResultShell` (`Control`)

Script:
- `scripts/gameplay_result_shell.gd`

Purpose:
- Shared terminal-result shell (UI-003) for a level's two end states, Completion and Failure. Owns
  the shared result shade, hero title role, action-button placement, safe-area layout, and
  open/close motion. See "Shared Gameplay UI Roles" above.
- `scenes/ui/level_completion_screen.tscn` and `scenes/ui/level_failure_screen.tscn` each instance
  this as their first child (`Shell`) and keep their own state-specific content (star/earned-count,
  body copy) in the content region it exposes, so shade/title/action/safe-area/motion are shared
  without merging that content.

Important nodes:
- `ResultShade`: full-rect `Panel`, `style_box_gameplay_result_shade.tres`.
- `%TitleLabel`: `GameTitleLabel`, the result-hero size (58), responsively scaled by
  `GameplayUITheme.get_result_title_scale()`.
- `%ContentRegion`: full-viewport-sized passthrough; the owning scene positions its own content
  within it.
- `%ActionRegion`: the single CTA slot (Completion's `Continue`, Failure's `Main Menu`); the owning
  scene reparents its own button here and anchors it full-rect.

Depends on:
- `assets/themes/style_box_gameplay_result_shade.tres`.
- `scripts/ui_motion.gd`, `scripts/gameplay_ui_theme.gd`.

Do not use for:
- Result content, gameplay data, or signal ownership. Those stay in the owning scene's own script.

## `scenes/ui/level_top_hud.tscn`

Root:
- `LevelTopHud` (`Control`)

Script:
- `scripts/level_top_hud.gd`

Purpose:
- Extracted top HUD (UI-003): one owner for the top strip background, combo slot, timer, level
  label, star pill, and Pause button, replacing `level.tscn` embedding them piecemeal across the
  `Background` control and the `UI` canvas layer. See "Shared Gameplay UI Roles" above.
- The background strip height and the combo slot both grow/shift with the safe-top inset (before,
  only the timer/level/star/pause row did). The timer stays centered but is kept clear of the level
  label and star/pause cluster so long values (`LEVEL 99`, `59:59`, large star totals) can never
  overlap either side. Timer, star pill, and Pause share the authored 60px row center, and the star
  pill keeps a deliberately wide 36px regular-width gap from Pause (30px compact) so the status
  readout and the control read as two roles rather than one cluster.
- `%PauseButton` matches the Main Menu settings-button role: 72x64 with the shared warm normal/
  pressed resources, a matching 0.94 held scale, and an explicit warm disabled override. Its pause
  mark is the `"II"` text glyph, authored in the same dark brown as the settings button for every
  state -- including `font_disabled_color`, because Pause is disabled for the whole completion
  celebration, where the frozen board leaves it in plain sight instead of behind an overlay. At
  extreme safe-inset widths the control scales proportionally while preserving those
  settings-button proportions.

Important nodes:
- `%Strip`: full-rect `Panel`, the top strip background.
- `%HudCenterSlot`, `%ComboFill`, `%ComboLabel`: the combo count/timer pill.
- `%TimerLabel`, `%LevelLabel`: the countdown and chapter-local level number.
- `%StarCounter` (`style_box_gameplay_status_pill.tres`, a true pill), `%StarCountLabel`: the run's
  star total; `get_star_counter_global_center()` is the reward-star flight's landing point and
  `play_star_receive_pulse()`/`reset_star_pulse()` own its receive-pulse animation. The pulse
  scales the pill's star `Icon`, never the pill: the pill's 2px gold border and 6px drop shadow
  thicken and its rasterized count blurs when the panel itself is scaled.
- `%PauseButton`: the warm Main Menu settings-button role with the `"II"` pause glyph;
  `press_scale_button.gd` (0.94 held scale).

Depends on:
- `assets/themes/style_box_gameplay_status_pill.tres`,
  `style_box_warm_icon_{normal,pressed}.tres`.
- `scripts/gameplay_ui_theme.gd`, `scripts/press_scale_button.gd`, `scripts/ui_motion.gd`.

Do not use for:
- Gameplay timer/star/combo state ownership, or ability-bar layout. Those stay in
  `scripts/level.gd` and `scenes/ui/ability_bar.tscn` respectively.

## `scenes/pause_menu.tscn`

Root:
- `PauseMenuOverlay` (`Control`; was a `ColorRect` before it composed the shared modal shell for its
  own shade)

Script:
- `scripts/pause_menu.gd`

Purpose:
- Reusable in-level pause menu overlay instanced by `level.tscn`.
- Composes `scenes/ui/gameplay_modal_shell.tscn` (`Shell`) for the shared shade, outer panel, title
  (`PAUSE`), close button, content region, and action row (UI-003; see "Shared Gameplay UI Roles"
  above), instead of owning local shade/panel/close-button styling.
- Owns music / sound-effects / vibration square icon buttons, their crossed-out toggle visuals
  (now scene-authored `CrossOut` children, not only created at runtime -- see "Important nodes"),
  and `Leave` / `Continue` buttons.

Important nodes:
- `Shell`: the shared modal shell instance.
- `SettingsContent`: reparented into `Shell`'s compact 224px content region at `_ready()`; holds
  `InnerTitleLabel` (`SETTINGS`) and `IconRow`; the row starts at y=64 to keep the icons close to
  the inner title.
- `IconRow/MusicOption/MusicButton`, `SoundEffectsOption/SoundEffectsButton`,
  `VibrationOption/VibrationButton`: square toggle buttons with shadow-only button styling,
  held-press scaling, and a scene-authored hidden `CrossOut` child (`Border` + `Slash` ColorRects)
  toggled by `scripts/pause_menu.gd` instead of being built at runtime (UI-003 P3).
- `LeaveButton`, `ContinueButton`: reparented into `Shell`'s action row at `_ready()`. `LeaveButton`
  uses the shared `style_box_gameplay_destructive_action.tres`; `ContinueButton` uses the shared
  `style_box_green_primary_button.tres`.

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn`.
- `assets/ui/icon_music.png`, `assets/ui/icon_sound_effects.png`, and `assets/ui/icon_vibration.png` as square textures containing warm rectangular tile art for the settings buttons.
- `assets/themes/style_box_gameplay_destructive_action.tres`, `style_box_green_primary_button.tres`.
- `scripts/press_scale_button.gd` for the default held-press shrink on settings icon buttons and bottom image buttons.
- `assets/ui/pause_menu_option_a_sheet.png` and `assets/ui/pause_menu_option_b_sheet.png` are archived alternate visual directions for these icons.
- Runtime button wiring from `scripts/level.gd` via `scripts/pause_menu.gd`'s
  `leave_pressed`/`continue_pressed`/`setting_toggled` signals.
- Shared settings-button visual toggles from `scripts/pause_menu.gd`, persisted through `PlayerProgress`.

Do not use for:
- Timer state, scene navigation, gameplay pause rules, music playback, or actual vibration settings. Those stay in owning runtime systems.

## `scenes/leave_confirmation_menu.tscn`

Root:
- `LeaveConfirmationOverlay` (`Control`; was a `ColorRect` before it composed the shared modal shell
  for its own shade)

Script:
- `scripts/leave_confirmation_menu.gd` (new -- this scene previously had no script of its own, and
  `scripts/level.gd` reached its Leave/Continue buttons and star-count label directly by child path)

Purpose:
- Reusable in-level leave confirmation overlay instanced by `level.tscn`.
- Composes `scenes/ui/gameplay_modal_shell.tscn` (`Shell`) for the shared shade, outer panel, title
  (`LEAVING THE LEVEL`, the long-title role), close button, content region, and action row.
- Shows warning text, crossed-out life and star reward icons, readable bottom-right count badges
  layered above the icons, and red `Leave` / green `Continue` image buttons.
- Close/system-back (the shell's shared X button, forwarded as `close_requested`) returns to Pause;
  the explicit `Continue` action resumes gameplay directly (UI-003 -- these two used to collapse
  into the same "resume gameplay" outcome before `scripts/level.gd` told them apart).

Important nodes:
- `Shell`: the shared modal shell instance.
- `LossContent`: reparented into `Shell`'s compact 240px content region at `_ready()`; holds
  `MessageLabel` and `LossRow`; the centered row uses a -40px top offset to keep the loss icons
  close to the message.
- `LossRow/LifeLoss`, `LossRow/StarLoss`: `style_box_gameplay_item_slot.tres` cells with a
  `style_box_gameplay_count_badge.tres` count badge each; `StarLoss`'s `%CountLabel` is the current
  run star count written by `scripts/leave_confirmation_menu.gd::set_star_count()`.
- `ConfirmLeaveButton`, `ContinueButton`: reparented into `Shell`'s action row at `_ready()`.
  `ConfirmLeaveButton` uses the shared `style_box_gameplay_destructive_action.tres`; `ContinueButton`
  uses the shared `style_box_green_primary_button.tres`.

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn`.
- `assets/ui/main_menu_lives.png`, `assets/ui/reward_star_84x84.png`.
- `assets/themes/style_box_gameplay_item_slot.tres`, `style_box_gameplay_count_badge.tres`,
  `style_box_gameplay_destructive_action.tres`, `style_box_green_primary_button.tres`.
- `scripts/press_scale_button.gd`, `scripts/gameplay_ui_theme.gd`.
- Runtime data/signal wiring from `scripts/level.gd` via
  `leave_pressed`/`continue_pressed`/`close_requested`/`set_star_count()`.

Do not use for:
- Spending lives, scene navigation, or pause state ownership. Those stay in `scripts/level.gd`.

## `scenes/ui/shelf_lock_overlay.tscn`

Root:
- `ShelfLockOverlay` (`Node2D`)

Script:
- `scripts/shelf_lock_overlay.gd`

Purpose:
- Reusable visual owner instanced as `LockedOverlay` by both standard and dispenser shelves.
- Draws two crossed instances of the selected C2 chain texture over a softened shelf shade, with the
  existing orange padlock hanging at their intersection.
- Keeps the decorative `AD` copy and the green circular remaining-clears badge as live Godot labels,
  so text stays crisp and 1-, 2-, and 3+-digit counts can resize independently from the raster art.
- Owns decrement feedback (badge pop, chain shake, hanging-lock swing) and the final release (chains
  recoil/fade, lock drops, shade fades). The owning level changes gameplay eligibility immediately;
  none of these visuals can delay an unlocked shelf.
- Exposes standard and compact layouts through `overlay_half_width` and `compact_layout`, letting the
  dispenser reuse the exact component without duplicating its hierarchy or animation logic.

Important nodes:
- `Shade`: shelf-local darkening layer whose horizontal bounds follow `overlay_half_width`.
- `VisualRig/ChainRig/ChainBack` and `ChainFront`: crossed, rotated instances of
  `assets/ui/shelf_lock_chain_c2.png`.
- `VisualRig/LockRig`: pivot at the shackle attachment point; contains the existing lock sprite and
  decorative `AdLabel`.
- `VisualRig/CountdownBadge`: true circular green panel and `RemainingLabel`, positioned above the
  chain intersection.

Depends on:
- `assets/ui/shelf_lock_chain_c2.png`, prepared from the selected ImageGen C2 candidate with an alpha
  background.
- `assets/ui/lock_shelf_cutout.png` for the hanging orange padlock.
- `scripts/ui_motion.gd` for replacement-safe tweens.

Do not use for:
- Counting cleared triples, deciding whether a shelf is locked, or changing item input. Those remain
  authoritative in `scripts/level.gd`.

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
- Instances the reusable hidden `scenes/ui/shelf_lock_overlay.tscn` when a level config gates the
  shelf behind cleared triples.
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
- `LockedOverlay`: standard-layout instance of `scenes/ui/shelf_lock_overlay.tscn`; the component owns
  its crossed chains, hanging lock, decorative `AD`, remaining-clears badge, and feedback motion.
- `Slot01`, `Slot02`, `Slot03`: front slots used by runtime movement and matching logic, positioned so default item silhouettes sit next to each other.
- `SlotXX/ItemSlotXX`: marker positions used by `scripts/level.gd` for snap targeting.

Depends on:
- `scripts/shelf.gd` for generated back-layer preview setup.
- `scenes/ui/shelf_lock_overlay.tscn` for triple-gate presentation.
- Runtime item spawning from `scripts/level.gd`.

Do not use for:
- Level timing, matching, input handling, lock progression, item identity assignment, or back-layer promotion timing. Those stay in `scripts/level.gd`.

## `scenes/dispenser_shelf.tscn`

Root:
- `DispenserShelf` (`Node2D`)

Script:
- `scripts/dispenser_shelf.gd`

Purpose:
- The narrow, source-only shelf type: one item slot, 2-4 stacked layers, and a `LayerIndicator`
  underneath showing how many items are left. Instantiated by `scripts/level.gd` for any level-config
  shelf with `"type": "dispenser"`.
- Carries a complete self-contained frame (both side walls plus its own ceiling cap) instead of the
  `PlacementVisuals` left/middle/right variants standard cells share with their neighbours, so it
  reads as a standalone unit wherever it sits in a row.

Important nodes:
- `BackWall`, `BackWallTopShade`, `BackWallLeftShade`, `LeftWall`, `RightWall`, `Ceiling`,
  `TopCeilingCap`, `FloorSurface`, `FloorFrontLip`, `FloorGrain*`: the same art vocabulary as
  `scenes/shelf.tscn`, narrowed to the 96-wide cell.
- `LayerIndicator`: `scenes/shelf_layer_indicator.tscn` instance positioned below the floor lip.
- `LockedOverlay`: compact-layout instance of `scenes/ui/shelf_lock_overlay.tscn`, with a narrower
  shade and scaled chain/lock/badge rig for the one-slot cell.
- `Slot01`/`Slot01/ItemSlot01`: the single front slot and its snap marker, at the same vertical
  position as a standard shelf's so items rest identically.

Depends on:
- `scenes/ui/shelf_lock_overlay.tscn`, `scenes/shelf_layer_indicator.tscn`.

Do not use for:
- Move validation, ability targeting, or queue promotion timing. Those stay in `scripts/level.gd`.

## `scenes/shelf_layer_indicator.tscn`

Root:
- `ShelfLayerIndicator` (`Node2D`)

Script:
- `scripts/shelf_layer_indicator.gd`

Purpose:
- The green segmented bar and round count badge under a dispenser shelf.
- Only `CountLabel` is authored. The track backing, badge art, and one socket per authored item are
  generated at runtime, because the socket count comes from the level config and the sockets share a
  fixed track width.

Do not use for:
- Anything that owns the count. The number lives on `DispenserShelf`; this scene only renders it.

## `scenes/shadow_style_preview.tscn`

Root:
- `ShadowStylePreview` (`Node2D`)

Script:
- `scripts/shadow_style_preview.gd`

Purpose:
- Throwaway harness for tuning the item ground shadow. Run the scene directly: it lays the same
  contrasting silhouettes (tall bottle, squat tub, irregular cupcake) out on real `scenes/shelf.tscn`
  shelves at three lift values -- resting, mid-grab, and carried -- plus an off-shelf copy of each
  that animates continuously between them, so the grab and drop transitions can be judged as motion.
- Reproduces chapter_01's `legacy` flat wall/floor background colors from `level.tscn`, since that
  is what every currently playable level renders behind its shelves.
- Accepts `-- --capture <path>` on the command line to save a screenshot and quit, for reviewing the
  shadow without watching the window.

Do not use for:
- Anything shipped. Delete this scene and its script once the shadow is signed off.

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
- `Shadow`: translucent ground shadow drawn from the item's own texture, so each item's silhouette
  shapes its own shadow. The `shadow_material` shader (exported on the root) builds a soft mask from
  a ring average of the texture alpha, clips it to the source-alpha envelope so the shadow does not
  exceed the item's size, then flattens the result to one translucent color that reads on both the
  wooden shelf floor and the lighter level background. The carried state adds a weighted
  source-alpha core to that mask, preserving narrow necks, handles and irregular edges without
  requiring per-item shadow art.
  `scripts/item.gd` anchors the sprite on the art's ground line (canvas y=120, see
  `docs/ITEM_ASSET_REQUIREMENTS.md`). Generated back-layer previews and clearing items disable it.
- The shadow has two readings, blended by `ShelfItem.shadow_lift`. **Resting**: a broad alpha-mask
  transition produces a soft, low-opacity, item-sized silhouette just up-right of the item, as if
  it were cast onto the shelf's nearby back wall. The offset exposes enough of the shadow to remain
  recognizable without crowding adjacent items, and the shadow follows both axes of the landing
  squash. **Carried**: while the player drags the item, the silhouette separates farther down-right.
  Its smaller filtered fill and weighted source-alpha core keep the carried shadow close to the
  item's recognizable shape, while reduced opacity prevents it from reading as a dark duplicate.
  Compare and tune both in `scenes/shadow_style_preview.tscn`.
- `OutlineSprite`: hidden sprite used by `ShelfItem` to draw alpha-based highlight borders.
- `Sprite2D`: main item sprite; texture and visual scale are controlled by `ShelfItem`.
- `CollisionShape2D`: rectangular item hitbox used by runtime interaction.

Depends on:
- Texture assignment from `scripts/level.gd`.
- Highlight outline color and width assignment from `scripts/level.gd`.
- Item IDs defined in `configs/item_sprites.json`.

Do not use for:
- Shelf placement rules, matching logic, or level progression.
