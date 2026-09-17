# Scenes

This file maps scenes to their responsibilities, scripts, important nodes, and runtime relationships.

## Level loading transition

- `scenes/ui/level_loading_screen.tscn` is a full-screen `CanvasLayer` that survives the swap from
  either Main Menu or a failed level into a fresh `level.tscn` instance. Its root blocks pointer and
  back input for the entire transition.
- `%Backdrop` uses `assets/shaders/loading_iris.gdshader` for the blue gradient, subtle dot pattern,
  and closing/opening circular mask. `%HeroHolder` presents the selected cat artwork from
  `assets/ui/loading/loading_cat.png`; `%LoadingDots` provides the compact activity indicator.
- The scene scales through full-rect anchors and keep-aspect texture placement across portrait phone
  and tablet layouts. `scripts/tools/captures/level_loading_screen_setup.gd` holds its review state.
- Runtime orchestration belongs to the `LevelTransition` autoload, while `scripts/level.gd` owns the
  gameplay activation gate. See [LEVEL_LOADING_SCREEN.md](LEVEL_LOADING_SCREEN.md).

## Sticky items and comparison scene

- `scenes/ui/sticky_item_indicator.tscn` is instanced by `scenes/item.tscn`. Its single sprite draws
  pink gum or amber glue beneath the item artwork. Ordinary and back-layer items hide the component;
  sticky items reveal it after promotion to the front finishes.
- `scenes/ui/sticky_blocked_feedback.tscn`, also instanced by each item, owns tap wobble and held
  finger-resistance timing in `scripts/sticky_blocked_feedback.gd`. It emits presentation channels;
  `item.gd` composes body/outline rotation and stretch around the artwork's ground line and passes
  squash/skew to the gum indicator, leaving the root, collision and grounded shadow unchanged.
  `level.gd` owns the blocked pointer separately from ordinary selection/drag and cancels feedback
  when the item becomes unavailable. Only active effects join `active_sticky_feedback` for checks.
- `scenes/testing/sticky_items_preview.tscn` inherits `level.tscn`, uses a dedicated dev-mode board,
  and preserves the selected artwork on reset/retry without advancing campaign progress.
- `scenes/ui/sticky_preview_controls.tscn` owns Pink, Amber, Both, and Reset controls, with safe-area
  placement below the ability bar. A debug button in `scenes/main_menu_testing.tscn` launches it.

See [STICKY_ITEMS.md](STICKY_ITEMS.md) for ownership, rules, capture commands, and verification limits.

## Reward chest fill preview

- `scenes/testing/reward_chest_fill_preview.tscn` is a standalone F6 preview for the production
  `main_menu_reward_chest.tscn` and `main_menu_reward_star_flyer.tscn` components.
- It automatically flies twelve stars into an empty chest, advances the visible count on each
  impact, pulses the real chest widget, and requests `reward_chest_star_arrival` through SfxManager.
- Replay and Reset make sound comparisons repeatable. The preview owns presentation state only and
  never reads or writes `PlayerProgress`.
- `tests/ui/test_reward_chest_fill_preview.gd` runs a complete twelve-star flight and verifies the
  visible fill, per-impact semantic audio requests, and unchanged saved progress.

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
(targets `ProfileAvatarView`), `RewardChest`'s `%ChestButton` (targets a `Visual` wrapper around the
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

## Shared Sound-Effect Roles (AUDIO-001)

Sound effects are owned globally, not by scenes. The `SfxManager` autoload
(`scripts/audio/sfx_manager.gd`) holds the only shared `AudioStreamPlayer` pool, routed to the
dedicated `SFX` bus in `assets/audio/default_bus_layout.tres`, and
`scripts/audio/sfx_catalog.gd` holds the one event catalog. See `docs/SCRIPTS.md` for the full
API, `docs/AUDIO_LOUDNESS_STANDARD.md` for the required loudness/true-peak policy, and
`docs/AUDIO_001_GODOT_ONLY_SFX_TICKET.md` for the approved event scope. The SFX bus sends to
Master, whose enabled `AudioEffectHardLimiter` has a -1 dB ceiling as final overlap protection.

**No scene authors an `AudioStreamPlayer` for a shared cue.** Hammer's former five-player local mix
has also moved into the catalog as one authored `ability_hammer` cue, so disabling sound effects and
pool limits now have one owner for every gameplay sound.

**Generic button click.** Every enabled, visible `BaseButton` in every scene plays `ui_click` on its
accepted `pressed` action, bound automatically by `scripts/audio/ui_click_binder.gd`. Scenes do not
wire it, and must not add a second click of their own.

**Suppressing the generic click.** Mark a button through
`SfxManager.set_button_click_suppressed(button)` when it is a documented no-op or owns a complete
replacement cue. Current users:
- the already-active bottom-navigation tab (`scripts/main_menu_bottom_navigation.gd`), because
  retapping the active destination does nothing -- see "Active-Tab Reselection Rule" below;
- `scenes/pause_menu.tscn`'s `SoundEffectsButton` (and the same button in
  `scenes/ui/settings_menu.tscn`), because turning sound effects off has to acknowledge the accepted
  press *before* muting, and turning them on has to acknowledge *after* enabling.

**Scene-owned hooks.** Two components expose the moment their own animation accepts something, so
the owning screen can play a cue at exactly that beat rather than guessing at it:
- `scenes/ui/level_top_hud.tscn` emits `critical_second_pulsed(displayed_seconds)` from the same
  decision that starts its critical-second pulse; `scripts/level.gd` uses that state to start the
  supplied 30-second `timer_critical_tick` bed once and seek it after pause or Freezer.
- `scenes/ui/main_menu_reward_star_flyer.tscn` already emitted `star_arrived` per landed star;
  `scripts/production_main_menu.gd`'s handler now plays `reward_chest_star_arrival` in the same
  callback that advances the visible chest count and starts its receive pulse.

**Captures and tests.** `scripts/tools/capture_scene.gd` mutes `SfxManager` for every capture, and a
headless run starts muted, so neither needs an audio device.

## Shared Gameplay UI Roles (UI-003)

The playable level (`level.tscn`'s HUD, ability bar, Pause, Leave Confirmation, Ability Purchase,
Completion, and Failure) uses its own intentional system, separate from the menu-scope tokens
above: the level intentionally keeps a denser, higher-contrast gameplay presentation (per
`docs/UI_003_LEVEL_UI_CONSISTENCY_TICKET.md`'s Objective), so equivalent concepts share gameplay-
scoped colors/shapes/components instead of either scene-local approximations or the menu system's
brighter cream/red palette. Reused directly where the semantic role already matches exactly:
`style_box_green_primary_button.tres` (positive: Continue/Buy/Retry) and
`style_box_disabled_action_button.tres` (unavailable: disabled Buy, the dev-preview Watch-Ad
placeholder).

**Shared gameplay style resources** -- new `assets/themes/style_box_gameplay_*.tres` files, each a
single role reused by reference (no more copy-pasted `StyleBoxFlat`/`StyleBoxTexture` sub-resources
inside gameplay `.tscn` files):

- `style_box_gameplay_modal_shade.tres` / `style_box_gameplay_result_shade.tres`: the two shade
  roles the ticket calls for -- one modal dim (`Color(0.02, 0.025, 0.03, 0.66)`, shared by Pause/
  Leave Confirmation/Ability Purchase) and one stronger terminal-result shade
  (`Color(0.04, 0.035, 0.045, 0.76)`, retained by Completion after Failure moved to the modal shell --
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
  compact (98.4px) and regular (115.2px) sizes: each uses a deliberately
  oversized `corner_radius`, which Godot clamps to half the control's smaller dimension, so it
  renders as a true circle at either size without needing size-specific resources. Includes an
  explicit `disabled` style so blocked abilities never fall back to Godot's default square style.
- `style_box_warm_icon_{normal,pressed}.tres`: the top-HUD Pause control deliberately reuses the
  Main Menu settings-button role at 72x64, including its dark-brown scene-authored pause bars. Its
  explicit disabled override points at the warm normal resource, preventing default-style fallback.
- `style_box_gameplay_count_badge.tres`: the shared inventory/count badge used by ability-bar
  remaining-use counts, locked-shelf remaining-clear counts, and Leave Confirmation's loss counts.
  Same oversized-radius trick for a true pill/circle at any authored size.
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
compact content-region height (224px for Purchase/Out of Lives, 234px for Pause, 240px for Leave
Confirmation, and 336px inside Failure's taller 520x620 panel) so the cream panel fits its content
instead of stretching to fill the outer shell.

**Interaction/motion** -- every gameplay button now uses `press_scale_button.gd`: `0.94` for CTAs
(including Pause's warm settings-role control, Leave/Continue/Buy/Watch-Ad/Completion's Continue/
Failure's orange Retry action), `0.97` for ability and modal-close icon buttons. Every gameplay-owned
control is `FOCUS_NONE` with the pointing-hand cursor
while enabled and the arrow cursor while disabled, matching the menu system's touch-only policy.
Modal/result open and close fade via
`scripts/ui_motion.gd` (`OVERLAY_DURATION`) instead of snapping between `visible` states, and every
shell exposes `is_transitioning()` so `scripts/level.gd`'s button handlers and `ui_cancel` chain can
ignore duplicate input until a fade settles. Owner wrappers also verify that their shell remained
closed before hiding their root, so an interrupted close cannot hide a freshly reopened modal.

**`ui_cancel` back stack** -- `scripts/level.gd::_unhandled_input()` (there was no back-button
handling at all during gameplay before this ticket) implements one topmost-state-first order: the
retry Out of Lives returns to the main menu; the in-level Shop returns to Ability Purchase; Leave Confirmation returns to Pause; Ability Purchase
closes and restores the state it opened from (Pause if opened from Pause, otherwise resumes
gameplay); Pause resumes; Completion invokes its `Continue` route and Failure its close/main-menu
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
interrupted modal close/reopen behavior, Failure's shared modal-resource identity, and locked-shelf
count-pulse/unlock-animation feedback. `tests/ui/test_level_failure_screen.gd` separately covers
immediate Retry, the zero-life offer, decline-to-menu, successful life purchase + same-level
restart, and an unaffordable purchase returning to the menu.

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
- Opens the lives modal when the top status bar's lives widget is pressed, at any life count. This
  entry point only reports and sells lives: unlike the zero-lives launch case it never resumes a
  campaign launch afterwards, and never closes itself when a countdown restores a life.
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
- `PlayerProgress` for the local player's name, avatar, avatar frame, lifetime stars, and weekly
  stars, and for the selected chapter id.

## `scenes/ui/leaderboard_row.tscn`

Root:
- `LeaderboardRow` (`Control`)

Script:
- `scripts/leaderboard_row.gd`

Purpose:
- Reusable ranking entry with rank, authoritative composed avatar/frame, ellipsized player name,
  reward-star icon, and formatted score.
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
- `assets/ui/avatar_frames/*.png` and `scenes/ui/profile_avatar_view.tscn`, which compose the same
  sanitized avatar/frame presentation used by the Main Menu and profile editor. The avatar layer
  uses symmetric 7 px insets so it stays centered while overlapping the frame's inner rim enough
  to prevent a visible seam at regular and compact leaderboard sizes.
- `assets/ui/avatar_circle_clip.gdshader`, which keeps the circular crop while rendering avatar
  content beneath the frame's transparent opening.
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
- Its root uses canvas `z_index = 2`, keeping the full-screen Shop above the ability bar's
  `z_index = 1` count/timer badges instead of letting those gameplay labels leak through.
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
- Reusable campaign-lives modal. The Main Menu opens it after a zero-life launch request or from the
  top status bar's `LivesWidget`; `level.tscn` also opens it while closing Failure when Retry is
  pressed after the failed run consumed the last life.
- Composes `scenes/ui/gameplay_modal_shell.tscn` for the shared shade, cream content region, title,
  close action, responsive safe-area fitting, and fade motion.
- Renders one of two states, chosen entirely from the count `set_offer()` receives, so a countdown
  that restores the last missing life switches the open modal in place:
  - **Below the cap**: `assets/ui/main_menu_lives.png` with the live count, the `MM:SS` restoration
	countdown, a green clover-coin price action, and a production-visible disabled `Coming Soon`
	action. Titled `OUT OF LIVES` at zero lives and `GET MORE LIVES` above it -- the zero-lives
	wording belongs to the interrupted-launch case that opens the modal to explain a blocked play.
  - **At the cap**: the countdown swaps to the full-lives message and both purchase actions swap to
	a single dismissing `Got it`, under the title `LIVES FULL`. Nothing is for sale at the cap, so
	offering a purchase action there would be an inert affordance.
- Emits purchase/close intent only. `production_main_menu.gd` owns its Main Menu behavior;
  `scripts/level.gd` owns retry purchase/restart/decline behavior; `PlayerProgress` owns the atomic
  offline economy mutation. `Got it` reuses `close_requested`, since dismissing is exactly what the
  shell's close action already does.

Important nodes:
- `%LifeCountLabel`, `%CountdownLabel`, and `%PriceLabel`: state supplied by the Main Menu.
- `%TimerCenter` / `%MessageCenter`: the two mutually exclusive right-hand content columns beside
  the heart (countdown vs. `%FullLivesLabel`), occupying the same 190x154 slot so the heart never
  moves between states.
- `%PurchaseButton`: green 194x76 coin-price action using the shared primary style.
- `%ComingSoonButton`: always-disabled neutral placeholder, visible below the cap.
- `%GotItButton`: 194x76 dismiss action, visible only at the cap. Deliberately shares
  `style_box_green_primary_button.tres` with `%PurchaseButton` rather than taking the orange
  dismiss role (see "Shared UI Style Tokens"): it is the modal's only action in that state, so it
  reads as the primary action rather than as the secondary half of a pair. It carries the same
  white/dark-green-outlined text treatment the Pause menu's `Continue` uses on that art.

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
- Because that retap is a no-op, `set_active_tab()` also marks the active button
  `sfx_click_suppressed`, keeping it silent while the other two keep the generic click (see
  "Shared Sound-Effect Roles" above).

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
- Provides a clickable `ProfileWidget` button whose reusable avatar/frame view is updated from the
  saved `PlayerProgress` profile customization.

Important nodes:
- `ProfileWidget`: circular avatar button; `press_scale_button.gd` with `visual_target_path` set to
  `ProfileAvatarView` (0.97 held scale), so the avatar visibly presses without shrinking the 76x76 tap
  target (see "Shared Interaction Roles" above) -- it had no press feedback at all before UI-002.
- `ProfileWidget/ProfileAvatarView`: `scenes/ui/profile_avatar_view.tscn` instance showing the saved
  avatar and local cosmetic frame; its 92x92 visual is centered over the 76x76 touch target so
  scene-specific enlargement cannot shift the animal or frame off-axis.
- `CoinsWidget`: `scenes/ui/main_menu_coin_shortcut.tscn` instance (compact coin balance + "+"
  badge, tappable to open the Shop). Kept named `CoinsWidget` so `scripts/main_menu_top_status.gd`'s
  `$CoinsWidget` center-exclusion-width lookup is unchanged.
- `Spacer02`: non-expanding center exclusion corridor resized around camera cutouts.
- `LivesWidget`: generated heart icon, current life count label, and `Full` or `MM:SS` countdown
  status label, vertically centered within the pill. Its compact pill background matches `CoinsWidget` through the shared
  `assets/themes/style_box_status_counter_pill.tres` resource and matching 118x44 geometry. A flat
  `Button` (`FOCUS_NONE`, pointing-hand cursor, `press_scale_button.gd` at 0.97) that opens the
  owning menu's lives modal, matching the `CoinsWidget` shortcut precedent. Its child labels stay
  direct children with `MOUSE_FILTER_IGNORE`, so the `LivesWidget/LifeCount` and
  `LivesWidget/LifeStatus` paths the owning menu writes into are unchanged.
- `SettingsWidget`: warm rounded settings button matching the chapter selection screen's `BackButton` styling and held-press behavior; `FOCUS_NONE` with the pointing-hand cursor.

Depends on:
- `assets/ui/avatars/avatar_cat.png` for the default editor/display texture. The owning menu script replaces it with the saved avatar at runtime.
- `assets/ui/avatar_circle_clip.gdshader` for the circular crop and 90% content scale that reveals
  more of each avatar's original background.
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
- Applying actual music, support, or language settings. Sound effects and vibration are applied by
  their global runtime managers through `scripts/pause_menu.gd`.

## `scenes/ui/profile_menu.tscn`

Root:
- `ProfileMenu` (`Control`)

Script:
- `scripts/profile_menu.gd`

Purpose:
- Centered pause-style profile window opened from the production main menu over a dimmed modal background.
- Shows a live avatar/frame preview beside the saved player name and a compact pencil edit button.
- Provides segmented Avatar and Frame tabs backed by one edge-filling, touch-scrollable
  three-column choice grid without a visible scrollbar.
- Shows all 18 supplied avatar assets and all configured cosmetic frames, with a check badge on the
  pending selection.
- Saves the entered player name, selected avatar, and local frame through `PlayerProgress` only when
  the bottom Save button is pressed; Close discards the pending values.

Important nodes:
- `ProfileMenuPanel`: centered rounded panel using the pause-menu visual treatment.
- `CloseButton`: protruding red close button that dismisses without saving.
- `ProfileSummary/ProfilePreview`: reusable avatar/frame view that updates before saving.
- `ProfileSummary/NameDisplayRow`: an always-visible, input-styled `%NameLineEdit` plus the compact
  pencil button; `%PencilIcon` displays the generated transparent `assets/ui/pencil_icon.png`
  texture, and the field stays locked until the button enables keyboard editing.
- `SelectorPanel/TabRow`: mutually exclusive Avatar and Frame buttons.
- `SelectorPanel/ChoiceScroll/ChoiceGrid`: touch-scrollable `GridContainer` with `columns = 3` that
  fills the light panel width; the scrollbar is intentionally hidden and reusable choice tiles are
  generated by the script.
- `ButtonRow/SaveButton`: `scenes/ui/level_button.tscn` instance labeled `Save`.

Depends on:
- `assets/ui/pencil_icon.png`, the generated minimal pencil texture used by the name edit button.
- `assets/ui/avatars/*.png`, the supplied standalone circular avatar art with no decorative frame.
- `assets/ui/avatar_frames/*.png`, the supplied frame geometry plus its color variants, rendered as
  a separate layer above the avatar.
- `assets/ui/avatar_circle_clip.gdshader`, which keeps the circular crop while rendering avatar
  content at 90% and extending its outer background colors to the frame edge.
- `configs/profile_frames.json`.
- `scenes/ui/profile_avatar_view.tscn` and `scenes/ui/profile_choice_tile.tscn`.
- `scenes/ui/level_button.tscn`.
- `PlayerProgress` for available avatar/frame IDs, texture paths, current customization, generated
  defaults, and saving.

Do not use for:
- Campaign level launch, lives display, or profile data ownership. Those stay in `scripts/production_main_menu.gd` and `scripts/player_progress.gd`.

## `scenes/ui/profile_avatar_view.tscn`

Purpose:
- Reusable two-texture composition of a circular-clipped avatar below a catalog-driven transparent
  cosmetic frame.
- Used by the editor preview, choice tiles, and Main Menu profile widget so the saved combination is
  rendered consistently.

Script:
- `scripts/profile_avatar_view.gd`.

## `scenes/ui/profile_choice_tile.tscn`

Purpose:
- Reusable profile-editor choice button containing `ProfileAvatarView` and a green selected badge.
- Previews an avatar with the pending frame on the Avatar tab, or the pending avatar with each frame
  on the Frame tab.

Script:
- `scripts/profile_choice_tile.gd`.

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
- `level.tscn` through the `LevelTransition` autoload.
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
- `Background`: fullscreen gameplay backdrop. Chapter 1 combines a scene-authored shop wall and baseboard with the generated diagonal-terracotta texture in `assets/backgrounds/chapter_01_floor_terracotta_diagonal.png`; artwork-mode chapters use `Background/ChapterArtwork` instead.
- `Background/Baseboard`: 68 design pixels tall (twice its original 34), anchored above the unchanged
  floor edge at 156 pixels from the bottom. Its top is 224 pixels from the bottom, taking 34 pixels
  from the play wall; `scripts/level.gd` uses that boundary to fit and center shelves. Floor and
  ability-bar placement stay unchanged.
- `Background/HudCenterSlot/ComboFill`: rounded green combo-window strip that shrinks as the time left to extend the combo runs out.
- `Background/HudCenterSlot/ComboLabel`: hidden until the player clears a triple, then shows the active combo count.
- `Shelves`: parent for generated shelf nodes and optional moving shelf row containers; `scripts/level.gd` scales and centers it in the available play area for the current viewport size.
- `DragLayer`: temporary parent for dragged items, drawn above shelves.
- `LanternScreenEffect`: `scenes/abilities/lantern_screen_effect.tscn` instance on canvas layer 4;
  Focus Mode shades non-target gameplay and tracks bright pools to highlighted items while
  remaining below Freezer, the HUD, and modal shades.
- `FreezerScreenEffect`: `scenes/abilities/freezer_screen_effect.tscn` instance whose main frame
  renders on canvas layer 5 below UI and whose top-edge-only copy renders on layer 11 over `TopHud`.
  Both use a texture-free wide blue edge glow plus synchronized, short-lived snowflakes and never
  recolor the level center.
- `UI`: `CanvasLayer` for gameplay labels, the reusable ability bar, and overlays; top-level
  controls are anchored or positioned at runtime for non-720x1280 portrait screens.
- `UI/TimerLabel`: countdown display.
- `UI/LevelLabel`: current level display.
- `UI/StarCounterLabel`: top HUD star total panel, positioned between the timer area and pause button, with a small `reward_star.png` icon and numeric `CountLabel`.
- `UI/PauseMenuButton`: circular top-right button that pauses the active level and opens the pause menu overlay.
- `UI/AbilityBar`: `scenes/ui/ability_bar.tscn` instance; its focused owner script owns all four
  buttons, use badges, timed badges, touch-target sizing, and the `ability_pressed` signal.
- `UI/TimeUpTransition`: `scenes/ui/time_up_transition.tscn` instance; blocks input and owns the
  timer-origin alarm ring/dark-red shade between an eligible `00:00` and the extension offer.
- `UI/TimeUpExtensionOverlay`: `scenes/ui/time_up_extension_modal.tscn` instance opened after that
  transition when the attempt still has an extension route.
- `UI/FailureScreen`: shown after the offer is declined or immediately on an ineligible later
  timeout.
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
- `scenes/ui/time_up_transition.tscn`
- `scenes/ui/time_up_extension_modal.tscn`
- `assets/audio/<event>/*.{wav,mp3}`
- `configs/item_sprites.json`
- `configs/ability_purchase_prices.json`
- `configs/levels/level_*.json`
- `assets/abilities/*.png`
- `scenes/abilities/hammer_impact_effect.tscn` for the hammer ability's fullscreen strike animation.
- `scenes/abilities/lantern_screen_effect.tscn` for the Lantern ability's persistent Focus Mode.
- `scenes/abilities/freezer_screen_effect.tscn` for the Freezer ability's persistent perimeter ice.

Do not use for:
- Static shelf cell visuals. Put those in `scenes/shelf.tscn`.

## `scenes/ui/ability_bar.tscn`

Root:
- `AbilityBar` (`Control`)

Script:
- `scripts/ability_bar.gd`

Purpose:
- Reusable four-ability gameplay control extracted from `level.tscn`.
- Owns Hammer, Shuffle, Lantern/highlight, and Freezer buttons; each has a 98.4x98.4 compact
  touch target and a 115.2x115.2 regular target -- the circular ability icon-button role (UI-003, see
  "Shared Gameplay UI Roles" above).
- Displays the four transparent 128x128 ability textures in one cozy, simplified illustration
  style with distinct per-ability palettes; Freezer uses the blue/periwinkle clock variant with
  four snowflakes and a complete 12-mark dial.
- Keeps the icon controls equal-sized but uses small per-texture optical offsets verified from the
  rendered button row, so asymmetric Hammer, Lantern, and Freezer silhouettes read as centered
  inside the circular button rather than merely centering their square canvases.
- Owns remaining-use badges (`style_box_gameplay_count_badge.tres`) plus independent Lantern and
  Freezer active countdown badges (`style_box_gameplay_timer_badge.tres`).
- Disables both Lantern and Freezer controls while either timed effect is active; the controls are
  restored together when that effect finishes.
- Emits `ability_pressed(ability_id)` and exposes focused state/layout methods; `scripts/level.gd`
  remains the gameplay/economy orchestrator.
- All four buttons use `press_scale_button.gd` (0.97 held scale) and carry a `tooltip_text`; Freezer
  no longer sets unique visible button text, so all four read as icon-only.
- `apply_responsive_layout(usable_width)` rescales each button's Icon/UsesLabel/TimerLabel rects
  proportionally to the actual button size (UI-003), not only the parent button's
  `custom_minimum_size` -- previously those children stayed at their regular authored offsets and
  overflowed the compact button.

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
- Reusable level-failure modal instanced by `level.tscn`. Composes
  `scenes/ui/gameplay_modal_shell.tscn` for its dimmed backdrop, safe-area-fitted 520x620 panel,
  chapter-local `LEVEL N` title, circular close action, 336px content region, action row, and fade.
- Shows the transparent `assets/ui/broken_heart.png` art above the `LEVEL FAILED` message.
- Emits `retry_pressed` from its green primary Retry action and preserves `main_menu_pressed` for the
  shared X. `scripts/level.gd` owns the resulting run/economy/navigation behavior.

Important nodes:
- `Shell`: the shared gameplay modal shell instance, including `%CloseButton`.
- `FailureContent`: reparented into `Shell`'s cream content region; owns `%BrokenHeartImage` and
  `%MessageLabel`.
- `%RetryButton`: green 250x76 primary action, reparented into `Shell`'s action row, with
  `scripts/press_scale_button.gd` (0.94 held scale).

Depends on:
- `scenes/ui/gameplay_modal_shell.tscn`.
- `assets/ui/broken_heart.png`.
- The shared `style_box_green_primary_button.tres` resource.
- `scripts/press_scale_button.gd`, `scripts/gameplay_ui_theme.gd`.
- `tests/ui/test_level_failure_screen.gd` for retry/life-purchase/navigation coverage.
- `scripts/tools/captures/level_failure_setup.gd` and
  `level_failure_out_of_lives_setup.gd` for rendered responsive states.

Do not use for:
- Retry/run lifecycle, life availability, the purchase transaction, or navigation. Those stay in
  `scripts/level.gd` and `PlayerProgress`.

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

## `scenes/abilities/lantern_screen_effect.tscn`

Root:
- `LanternScreenEffect` (`CanvasLayer`, layer 4)

Script:
- `scripts/lantern_screen_effect.gd`

Purpose:
- Reusable fullscreen Lantern Focus Mode presentation owned separately from `scripts/level.gd`.
- Uses `lantern_searchlight.gdshader` for a clearly visible warm shade over non-target gameplay,
  sixteen-capacity target-position uniform array, pulsing item-centered light pools, perimeter
  glow, and an expanding activation wave from the Lantern button area.
- When no immediate target exists, replaces the target pools with a continuous diagonal search beam.
- Ignores mouse/touch input and stays below both the layer-5 Freezer effect and layer-10 gameplay UI.

Important nodes:
- `Overlay/SearchlightWash`: fullscreen texture-free procedural shader pass.

Verification:
- `tests/gameplay/test_lantern_screen_effect.gd` checks layering, input pass-through, Focus Mode
  contrast values, target normalization, idempotent activation, fade cleanup, and level integration.
- `scripts/tools/captures/lantern_effect_setup.gd` activates Lantern for responsive rendered
  captures of `level.tscn`.

Do not use for:
- Lantern timing, highlighted-item selection, inventory spending, or persistence. Those remain in
  `scripts/level.gd` and `PlayerProgress`.

## `scenes/abilities/freezer_screen_effect.tscn`

Root:
- `FreezerScreenEffect` (`CanvasLayer`, layer 5), with a nested layer-11 HUD pass

Script:
- `scripts/freezer_screen_effect.gd`

Purpose:
- Reusable fullscreen Freezer presentation owned by a separate scene instead of `scripts/level.gd`.
- Adds a large cyan-blue halo along all four screen edges, with a concentrated bright rim nearest
  the screen boundary; its width scales from the shorter viewport dimension so it remains visually
  even across portrait aspect ratios. The glow does not sample, tint, blur, or replace the current
  chapter background.
- Expands the glow inward when Freezer starts and continuously emits dense procedural snowflakes
  from all four edges. Flakes rotate gently, drift inward at 28-52 design pixels per second, and
  disappear within 1.6-2.4 seconds.
- Fades the glow, stops emission, and shortens remaining flake lifetimes when Freezer ends.
- Ignores mouse/touch input. The full frame stays below UI; only a top-height-clipped copy renders
  over `TopHud`, leaving ability buttons and central modal content unobstructed.
- Mirrors the shared gameplay modal shade and 0.2-second fade into that layer-11 copy whenever the
  level is paused, keeping its glow and flakes the same brightness as the shaded main pass.

Important nodes:
- `Overlay`: fullscreen, mouse-ignored control that follows the live viewport.
- `Overlay/EdgeGlow`: uses `freezer_edge_glow.gdshader` for the aspect-correct four-sided halo.
- `Overlay/SnowflakeField`: owns the bounded snowflake simulation below normal UI.
- `HudOverlayLayer/HudClip/HudEdgeGlow`: layer-11 glow duplicate kept at full viewport scale and
  clipped to the safe-area-aware `TopHud` height.
- `HudOverlayLayer/HudClip/HudSnowflakeField`: draws the main field's same particle data above the
  TopHud, clipped to the same strip.

Verification:
- `tests/gameplay/test_freezer_screen_effect.gd` checks layering, input pass-through, idempotent
  active-state refresh, activation, pause/resume shade synchronization, thaw cleanup, and
  `level.tscn` integration.
- `scripts/tools/captures/freezer_effect_setup.gd` activates Freezer for responsive rendered
  captures of `level.tscn`.
- `scripts/tools/captures/freezer_paused_setup.gd` activates Freezer and opens Pause to verify both
  render passes receive the same dimming at responsive sizes.

Do not use for:
- Freezer timing, inventory spending, timer gating, or persistence. Those remain in
  `scripts/level.gd` and `PlayerProgress`.

## `scenes/abilities/freezer_snowflake_field.tscn`

Root:
- `FreezerSnowflakeField` (`Control`)

Script:
- `scripts/freezer_snowflake_field.gd`

Purpose:
- Focused, reusable owner for the Freezer's procedural six-armed snowflake animation.
- Can run the bounded source simulation or mirror another field's data for a clipped render pass.
- Has no texture children, does not intercept input, and scales flake size/speed from the shorter
  viewport dimension.

## `scenes/abilities/hammer_impact_effect.tscn`

Root:
- `HammerImpactEffect` (`Control`)

Script:
- `scripts/hammer_impact_effect.gd`

Purpose:
- Reusable fullscreen hammer strike effect spawned by `scripts/level.gd` when the hammer ability is used.
- Displays the transparent supplied hammer poses in exact
  `1, 1.3, 1.7, 2, 3, 4, 5, 5.3, 5.7, 6, 7` order. The fractional frames subdivide the original
  `1 → 2` and `5 → 6` intervals without extending the strike timeline.
- Owns the editable 1.34 second `AnimationPlayer` `strike` animatic, played at `1.3x` speed for an
  effective duration of about 1.03 seconds. Poses 1–3 still switch quickly, but pose 3 remains on
  screen while the hammer completes its 320 ms flight from the live bottom-left ability button to
  the item; frames 4–6 then lead into the final frame-7 contact. It owns the
  immediate hammer hide, subtle frame-derived afterimages, layered impact amounts, and gameplay
  signal timing. The replacement Hammer cue is owned by the shared SFX catalog.
- Softens non-impact texture changes with a 55 ms outgoing-pose crossfade and small backward smear;
  frame 7 bypasses this blend so the contact silhouette remains crisp.
- Hides the hammer by authored time 580 ms, immediately after frame 7 makes contact at 560 ms, while
  the enlarged burst, glow, flash, and debris continue through the remaining VFX tail.
- Emits `pre_impact` at authored time 480 ms (about 369 ms into playback) for item compression and
  `impact` on frame 7 at authored time 560 ms (about 431 ms into playback) so gameplay hides and
  frees the merged item on the visual hit frame. Reward stars begin 140 ms later, during the
  remaining recoil/VFX tail.
- Owns no audio players. `scripts/level.gd` starts the catalogued `hammer.wav` cue with the strike,
  and `SfxManager` handles settings, muting, and bounded playback.

Important nodes:
- `ImpactAnchor`: moves from the runtime Hammer-button screen centre to the exact impact point during
  the first 320 authored milliseconds, then remains at the impact point for the strike.
- `ImpactAnchor/HammerPivot`: keyframed by `AnimationPlayer` for wind-up rotation, scale, and
  visibility.
- `ImpactAnchor/HammerPivot/PreviousPose`: medium-alpha outgoing texture retained for 55 ms behind the
  live sprite during non-impact pose changes.
- `ImpactAnchor/HammerPivot/HammerSprite`: transparent hammer sprite whose texture is value-keyframed
  by the `strike` animation. Its position is not keyframed — the script derives it each frame from
  `POSE_HEAD_OFFSETS` so every frame's head centre stays on the pivot the impact VFX are drawn
  around.
- `ImpactAnchor/HammerPivot/AfterimageEarly` / `AfterimageLate`: subtle low-alpha tinted copies of
  frames 5 and 6 behind the live hammer during the descent, sharing one additive canvas material.
- `AnimationPlayer`: owns only the visual and gameplay-signal timeline; Hammer sound is no longer
  assembled from scene-local players.
- `AnimationPlayer`: owns the `strike` animation; edit this timeline for most hammer motion and timing adjustments.

Depends on:
- `assets/abilities/ability_hammer_swing_1.png` through `ability_hammer_swing_7.png`, plus fractional
  transition frames `1.3`, `1.7`, `5.3`, and `5.7`, in strike playback order.
- `assets/audio/ability_hammer/hammer.wav`, played through the global semantic SFX catalog.
- Runtime instancing and target positioning from `scripts/level.gd`.
- `tests/gameplay/test_hammer_animation.gd` for deterministic timing/integration verification and optional movie capture.
- `scripts/tools/captures/hammer_effect_setup.gd` for responsive in-level impact-pose screenshots.

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

Naming:
- `grid_<columns>x<rows>` is a full rectangle of markers; a suffix such as `_hollow` names the cells it omits.
- `staggered_rows_<a>_<b>_...` lists shelves per row, top to bottom, for layouts whose rows differ in width and interlock by half a column step.
- `staggered_columns_<a>_<b>_<c>` lists shelves per column, left to right, for layouts whose columns differ in height and interlock by half a row step.
- `_moving_<count>_<placement>` marks a preset's moving rows, as in `grid_3x3_moving_5_bottom`.
- Row and column counts in a preset name always describe the authored markers, so a name plus the shelf count is enough to tell whether a level fits the preset.

Authored geometry:
- Markers retain the original shelf grid: `228.96` between columns (`114.48` for a half-step
  stagger) and `134.62` between static rows. Runtime preserves marker shapes while adding the
  taller standard frame's scaled `10.282` px extension per logical row, making the effective
  standard row step `144.902`. A half-row vertical stagger receives half that extension, so
  staggered-column shelves stay interlocked instead of developing wall and floor seams.
- Moving shelf bodies are `15` design pixels narrower than a standard shelf cell while their centers
  keep the authored `228.96` step, leaving a `6.52` pixel visual gap instead of an interlocked edge.
- Their `FloorSurface` and `FloorFrontLip` terminate at the same horizontal edges; the front lip's
  authored static-shelf overhang is removed only when the shelf belongs to a moving row.
- A moving row is `50.88` taller than a static one (`MovingShelfRow.ROW_HEIGHT_PADDING`). After the
  runtime height extension, a static row and an adjacent moving row are placed about `186.77` apart
  and two adjacent moving rows about `195.78` apart. Both keep the intended visual gap.

Static presets:
- `scenes/layouts/layout_grid_2x3.tscn` (6 shelves)
- `scenes/layouts/layout_grid_3x2.tscn` (6)
- `scenes/layouts/layout_grid_3x3.tscn` (9)
- `scenes/layouts/layout_grid_3x4.tscn` (12)
- `scenes/layouts/layout_grid_3x5.tscn` (15)
- `scenes/layouts/layout_grid_4x3.tscn` (12)
- `scenes/layouts/layout_grid_4x4_hollow.tscn` (12; a 4x4 field without its four inner cells)
- `scenes/layouts/layout_staggered_rows_2_3_2.tscn` (7)
- `scenes/layouts/layout_staggered_rows_3_2_3.tscn` (8)
- `scenes/layouts/layout_staggered_rows_2_3_3_2.tscn` (10)
- `scenes/layouts/layout_staggered_rows_3_4_4_3.tscn` (14; three-wide and four-wide rows in a brick bond)
- `scenes/layouts/layout_staggered_columns_4_3_4.tscn` (11)
- `scenes/layouts/layout_staggered_columns_4_5_4.tscn` (13)
- `scenes/layouts/layout_staggered_columns_5_4_5.tscn` (14)

Presets with moving rows:
- `scenes/layouts/layout_grid_3x2_moving_4_bottom.tscn` (10; two static rows over one 4-shelf belt, 3 visible, 60 px/s right)
- `scenes/layouts/layout_grid_3x3_moving_4_middle.tscn` (13; a 4-shelf belt between the top static row and the two below it, 3 visible, 60 px/s right)
- `scenes/layouts/layout_grid_3x2_moving_4_4_center.tscn` (14; two counter-running 4-shelf belts between two static rows, 3 visible each, 60 px/s)
- `scenes/layouts/layout_grid_3x3_moving_5_bottom.tscn` (14; a 3x3 static grid over one 5-shelf belt, 3 visible, 60 px/s right)
- `scenes/layouts/layout_staggered_columns_4_moving_6_4.tscn` (14; a vertical 6-shelf belt between two static columns of four, 3 visible, 60 px/s down)
- `scenes/layouts/layout_staggered_columns_5_moving_6_5.tscn` (16; a vertical 6-shelf belt between two static columns of five, 4 visible, 60 px/s down)
- `scenes/layouts/layout_grid_2x4_moving_6_left.tscn` (14; a vertical 6-shelf belt down the left edge beside a static 2x4 block, 4 visible, 60 px/s down)
- `scenes/layouts/layout_grid_1x4_moving_6_6_sides.tscn` (16; two vertical 6-shelf belts around a static column of four, 4 visible each, 60 px/s, left down and right up)

Vertical belts:
- A `vertical_wrap` row carries at least six shelves. Fewer makes the hidden part of the belt shorter
  than the window it wraps around, so a shelf leaving the bottom is still on screen as it re-enters
  at the top.

Depends on:
- Runtime shelf instantiation from `scripts/level.gd`.
- `scripts/shelf_layout_row.gd` for moving-row template metadata.

Do not use for:
- Shelf contents, item layers, locks, matching rules, or runtime state. Those stay in level JSON and `scripts/level.gd`.

## `scenes/moving_shelf.tscn`

One independently editable moving shelf, separate from both the static `scenes/shelf.tscn` art and
the belt container `scenes/moving_shelf_row.tscn`. This is a standalone scene, not an inherited
instance of the static shelf. Moving rows in both layout presets and `row_layouts` instantiate it.

Root and behavior:
- `MovingShelf` (`Node2D`) uses `scripts/moving_shelf.gd`, extending the shared `Shelf` helpers.
- Opens as the current floor-only moving shelf. Its optional hidden frame is retained for existing
  configs that request `visual_variant: "full"`; the script restores that frame when requested.
- Owns its artwork, `Slot01`–`Slot03`, and each slot's `ItemSlotXX` marker. Keep those slot names and
  marker positions when changing artwork so item placement, back layers, and touch targets stay aligned.

Customize the moving shelf here:
- Edit `FloorSurface`, `FloorSurface/Shade`, and `FloorFrontLip` for the default moving appearance.
  Add decorations as children of this scene, not of the moving-row container.
- Current body narrowing, trimmed lip, and polygon antialiasing are authored into the scene for an
  accurate standalone preview. Row registration reapplies the existing horizontal visual scale;
  customize polygon points/textures rather than relying on a different X scale for these nodes.
- The initial wood texture is shared with static shelves. Assign a separate texture resource here
  if the texture itself should change only on moving shelves.
- Movement, wrapping, clipping, and edge pickup remain owned by the row and level scripts.

Preview (no setup script required):

```powershell
& .\scripts\tools\capture_ui.ps1 -Scene scenes/moving_shelf.tscn -Name single_moving_shelf `
	-Zoom 3 -Background '#2b2f3a'
```

## `scenes/moving_shelf_row.tscn`

Runtime travel spans the playable background along the motion axis. `scripts/level.gd` supplies
the safe screen width for horizontal rows and the wall height below the HUD for vertical rows;
`scripts/moving_shelf_row.gd` owns clipping and wrapping. Authored `visible_count` remains the board
fitting footprint, while the runtime window may show additional configured shelves on larger
screens. Static shelf placement, lane position across the motion axis, and shelf spacing do not change.

Root:
- `MovingShelfRow` (`Control`)

Script:
- `scripts/moving_shelf_row.gd`

Purpose:
- Runtime row container for shelf groups with horizontal or vertical wrap motion.
- Clips child shelf rendering to the runtime travel window supplied by the level.
- Shortens each shelf body by `15` design pixels without scaling its items, slots, or hit areas, so
  adjacent shelves remain visually separate.
- Keeps moving-row bounds separate from individual shelf cell visuals.

Important properties:
- `clip_contents`: enabled so off-window shelves are hidden by the row rectangle.
- `mouse_filter`: ignored so gameplay input remains owned by `scripts/level.gd`.

Runtime-created nodes:
- `ShelfXX`: `scenes/moving_shelf.tscn` instances parented under the row and registered with `MovingShelfRow.add_shelf()`.

Depends on:
- Runtime configuration from `scripts/level.gd`.
- Child shelf scenes from `scenes/moving_shelf.tscn`.

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
- `open(with_pop = true)` adds a fitted 90% -> 102% -> 100% panel settle without changing any
  owner's authored panel size. The Time Up offer uses this variant after its dedicated lead-in;
  ordinary modal opens keep the standard fade.

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
- Terminal-result shell retained for Completion. Owns the full-screen result shade, hero title
  role, action-button placement, safe-area layout, and open/close motion. Failure now uses the
  centered `gameplay_modal_shell.tscn` instead.
- `scenes/ui/level_completion_screen.tscn` instances this as `Shell` and keeps its reward star,
  earned-count, and sparkle content in the exposed content region.

Important nodes:
- `ResultShade`: full-rect `Panel`, `style_box_gameplay_result_shade.tres`.
- `%TitleLabel`: `GameTitleLabel`, the result-hero size (58), responsively scaled by
  `GameplayUITheme.get_result_title_scale()`.
- `%ContentRegion`: full-viewport-sized passthrough; the owning scene positions its own content
  within it.
- `%ActionRegion`: Completion's single `Continue` CTA slot; the owning scene reparents its button
  here and anchors it full-rect.

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
  overlap either side. The strip uses a 132px base height before any safe-top inset is added, and
  the combo slot remains attached to its lower edge with a 20px inset and 9px overhang. The timer,
  level label, star pill, and Pause read as one aligned status row;
  the star pill and Pause retain the authored 60px row center. The star pill keeps a deliberately
  wide 36px regular-width gap from Pause (30px compact) so the status readout and the control read
  as two roles rather than one cluster.
- During the final 30 active countdown seconds, `%TimerLabel` turns alarm red over a dark maroon
  outline and pulses once when each new integer second is displayed. The outline is load-bearing:
  red alone sits too close to the warm terracotta strip to stay readable. The red treatment persists
  but goes motionless under Pause. Freezer's cyan digits take the label over while they are active,
  because both states now speak through the same channel and a held countdown is not an active
  alarm; the red returns on the next update after Freezer ends if the timer is still under 30s.
- On an accepted timeout, the same label owns the opening `00:00` beat: a red 1.35x snap plus a
  restrained horizontal shake. It also exposes its global center to `TimeUpTransition`, keeping
  the expanding alarm ring attached to the responsive HUD position.
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
- `%TimerLabel`: the countdown digits, and the single surface for every countdown state;
  `set_timer_state()` gates the critical recolor/pulse on started countdown state, and
  `reset_timer_attention()` clears it at run boundaries. `%LevelLabel` is the chapter-local level
  number.
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

## `scenes/ui/time_up_transition.tscn`

Root:
- `TimeUpTransition` (`Control`).

Script:
- `scripts/time_up_transition.gd`.

Purpose:
- Reusable fullscreen timeout punctuation between an eligible `00:00` and
  `TimeUpExtensionOverlay`. It owns a responsive timer-origin alarm ring, dark-red board shade,
  and input block, then crossfades away once the modal starts its pop reveal.
- It owns no sound player: `scripts/level.gd` starts the semantic `time_up` catalog event on the
  same frame as `play()`.

Important nodes:
- `%Shade`: behind-parent `ColorRect` so the root's procedural ring renders above it.

Do not use for:
- Extension eligibility, purchases, timer mutation, or terminal failure; those remain in
  `scripts/level.gd`.

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
  `SoundEffectsButton` is additionally marked `sfx_click_suppressed` so it can own its complete
  acknowledge-then-mute cue (see "Shared Sound-Effect Roles" above); the other two toggles keep
  the generic click.
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
- Timer state, scene navigation, gameplay pause rules, music playback, or vibration playback. Those
  stay in owning runtime systems; this scene only exposes the saved toggle through `pause_menu.gd`.

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
- Draws four instances of the selected seven-link C2-7A chain over a softened shelf shade. The art
  alternates four crosswise and three front-facing links and includes a shallow baked sag. Every arm
  is fitted between an endpoint embedded beneath a side wall and an endpoint over the padlock
  shackle, with small authored per-arm slope differences instead of a perfectly mirrored X.
- Layers the lock between the chain pairs: `BottomLeftArm` and `BottomRightArm` draw behind it while
  the top pair crosses in front. The shared orange-red/gold gameplay count badge stays above the
  whole assembly; decorative `AD` and the remaining-clear count remain crisp live Godot labels.
- Owns decrement feedback (badge pop, fixed-wall inward chain tension, hanging-lock swing) and the
  final release (each arm collapses/fades into its wall, the lock drops, and the shade fades). The
  owning level changes gameplay eligibility immediately; none of these visuals can delay an
  unlocked shelf.
- Exposes standard and compact layouts through `overlay_half_width`, vertical shade/wall-cover
  bounds, and `compact_layout`, letting the open dispenser cradle reuse the exact component without
  duplicating its hierarchy or animation logic.

Important nodes:
- `Shade`: shelf-local darkening layer whose horizontal and vertical bounds follow the owning shelf's
  exported overlay geometry.
- `VisualRig/ChainRig/TopLeftArm`, `TopRightArm`, `BottomLeftArm`, and `BottomRightArm`: independently
  fitted instances of C2-7A at legacy path `assets/ui/shelf_lock_chain_arm_a.png`, running from wall
  anchors to the lock. Their scene transforms are the standard-layout authoring preview; runtime
  derives the same transforms from the endpoint constants in `scripts/shelf_lock_overlay.gd`.
- `VisualRig/WallAttachmentCovers`: reusable left/right wood strips drawn above chain endpoints so
  terminal links disappear beneath the actual shelf frame.
- `VisualRig/LockRig`: drawn between the bottom and top arm depth layers; contains the lock sprite
  and decorative `AdLabel`.
- `VisualRig/CountdownBadge/RemainingLabel`: uses the same shared 40px count-badge style and numeric
  fitting contract as `AbilityBar/UsesLabel`, positioned above the chain intersection.

Depends on:
- `assets/ui/shelf_lock_chain_arm_a.png`, the legacy resource path containing selected ImageGen
  C2-7A, prepared with the ImageGen skill's chroma-key helper and normalized to 512x112.
- `assets/ui/lock_shelf_cutout.png` for the hanging orange padlock.
- `assets/themes/style_box_gameplay_count_badge.tres` for the shared remaining-count presentation.
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
- Uses slightly darker opaque pre-blended shelf shadows so neighboring shelf shadows remain a
  consistent tone where they intersect. Item contact shadows render later and alpha-blend over
  them, so item/shelf overlap still becomes visibly darker.
- Instances the reusable hidden `scenes/ui/shelf_lock_overlay.tscn` when a level config gates the
  shelf behind cleared triples.
- Uses wide cell bounds so three generated shelves span most of the 720 px gameplay viewport with
  compact row spacing. Its floor-anchored interior opening is 106.7 px tall (10% above the original
  97 px), while item snap points and the 224x135 cell footprint remain unchanged. Runtime adds the
  scaled 10.282 px height extension between rows so lower shelves are not covered by upper ones.
- Runtime shelf instances are scaled slightly by `scripts/level.gd`, with layout template markers and moving-row windows authored to match the scaled cell footprint.
- Can be switched by `scripts/level.gd` to a `floor_only` visual variant for moving rows by hiding wall and ceiling nodes at runtime.
- Can be switched by `scripts/level.gd` to `left`, `middle`, or `right` row-placement visuals for static shelves. Moving-row shelves currently stay on the neutral `middle` row-placement visual.
- Uses `assets/shelves/standard_shelf_light_oak.png` on its existing `Polygon2D` frame faces. Broad
  faces sample the grain horizontally, while the side-wall UVs rotate it vertically; keeping the
  faces separate preserves their placement visibility and item/back-layer z-order. The dispenser
  shelf shares this material but owns UV mappings and shading for its compact open-cradle geometry.

Important nodes:
- `BackWall`: muted panel behind shelf items.
- `BackWallTopShade`: soft interior wall shadow layer behind items.
- `PlacementVisuals`: editable role-specific shelf art groups toggled by `scripts/shelf.gd`.
- `PlacementVisuals/Left`: left shelf role visuals. Contains `BackWallLeftShade`, `LeftWall`, `RightWall`, and the left-specific `TopCeilingCap`.
- `PlacementVisuals/Middle`: middle shelf role visuals. Contains row divider art and the middle-specific `TopCeilingCap`.
- `PlacementVisuals/Right`: right shelf role visuals. Contains right edge art and the right-specific `TopCeilingCap`.
- `Ceiling`: shared image-textured wooden top frame. Placement-specific `TopCeilingCap/BackBoard`
  faces use the same light-oak material and are shown at runtime only for top shelves.
- `Shadow` and `RightColumnShadow`: opaque pre-blended perspective cast shadows, shown at runtime
  for full shelf visuals and drawn below shelf bodies, items, and generated back-layer item
  previews. Shelf/shelf intersections stay flat while later item shadows darken their overlap.
- `FloorSurface` and `FloorFrontLip`: image-textured wooden floor where items visually rest.
- `FloorGrain*`: retained hidden as legacy editable guides; the image texture now supplies visible
  grain. Generated back-layer item previews still draw above the floor, while active front items
  draw above back-layer previews.
- `LockedOverlay`: standard-layout instance of `scenes/ui/shelf_lock_overlay.tscn`; the component owns
  its four chain arms, hanging lock, decorative `AD`, remaining-clears badge, and feedback motion.
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
- The narrow, source-only shelf type: one item slot, 2-4 stacked layers, and an integrated
  count/segmented-stock readout showing how many items are left. Instantiated by `scripts/level.gd`
  for any level-config shelf with `"type": "dispenser"`.
- Uses a short open wooden cradle whose item protrudes above its recessed back panel. Chunky beveled
  guards, a frame-level cast shadow, an ability-style circular count badge, and a wide segmented
  stock rail identify the one-way source while keeping the standard shelf palette and item resting
  position.
- Uses `assets/shelves/standard_shelf_light_oak.png` across the back, floor, front lip, lower panel,
  and every guard face. Horizontal UVs suit broad planes, rotated UVs run grain along the vertical
  supports, and face-specific tint/shade overlays preserve the inset depth.
- Its root authors a `Vector2(0, -10)` position that `scripts/level.gd::_add_shelf()` preserves as a
  per-scene layout offset, keeping the complete dispenser 10px above a standard neighbour.

Important nodes:
- `FrameShadow`, `BackWall`, `BackWallLowerPanel`, and the `BackWall*Shade`/`*ShadowEdge` nodes:
  the recessed back and cast-depth treatment of the compact cradle. Its cast/back-wall shadows use
  opaque pre-blended colors, matching the standard shelf's non-compounding shelf/shelf behavior.
- `LeftWall*` and `RightWall*`: semantically paired upper/lower faces, top/lower bevels, and inner
  faces for the two chunky image-textured side guards. Each bevel/inner-face node owns a translucent
  local `Shade` child. The right upper face, top bevel, inner face, and lower bevel render above item
  shadows so the up-right contact projection cannot stain the guard; item shadows remain above the
  floor and level background.
- `FloorSurface`, `FloorFrontLip`, and hidden legacy `FloorGrain*`: the textured item floor and front
  lip inside the 96-wide packing cell. There is intentionally no `Ceiling` or `TopCeilingCap`.
- `LayerIndicator`: `scenes/shelf_layer_indicator.tscn` instance overlapping the front lip; its
  compact circular badge shows the exact count and its wide, thin-outlined rail shows one cell per
  authored item with narrow straight seams like one continuous segmented strip.
- `LockedOverlay`: compact-layout instance of `scenes/ui/shelf_lock_overlay.tscn`, with a narrower
  shade and scaled chain/lock/badge rig for the one-slot cell.
- `Slot01`/`Slot01/ItemSlot01`: the single front slot and its snap marker, at the same vertical
  position as a standard shelf's so items rest identically.

Depends on:
- `assets/shelves/standard_shelf_light_oak.png`.
- `scenes/ui/shelf_lock_overlay.tscn`, `scenes/shelf_layer_indicator.tscn`.

Do not use for:
- Move validation, ability targeting, or queue promotion timing. Those stay in `scripts/level.gd`.

## `scenes/shelf_layer_indicator.tscn`

Root:
- `ShelfLayerIndicator` (`Node2D`)

Script:
- `scripts/shelf_layer_indicator.gd`

Purpose:
- The dispenser's exact circular count badge and attached segmented stock rail.
- `CountLabel` is authored with `style_box_gameplay_count_badge.tres`, matching ability counters.
  `TrackBacking` and all four supported `Segment##` node hierarchies are also authored in the scene,
  so their colors, polygons, layering, and gloss are directly editable in Godot.
- Each segment owns `Light/Body` and `Light/Gloss`; the shared backing is the visible empty state.
  At runtime the script only fits the authored nodes to the configured 2-4 capacity and controls
  which `Light` nodes stay lit.
- Track and outer-segment capsule ends use eight polygon subdivisions per quarter arc, keeping the
  small 13-15px-high curves circular after shelf and responsive board scaling.
- Rail size, border width, center, gap, corner radius, and gloss dimensions are exposed under the
  root node's `Rail Layout` inspector group.

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
- `OutlineSprite`: hidden sprite used by `ShelfItem` to draw alpha-based borders. Lantern enables it
  in gold; ordinary tap selection enables the same silhouette treatment in white and takes color
  priority when both states apply.
- `Sprite2D`: main item sprite; texture and visual scale are controlled by `ShelfItem`.
- `StickyItemIndicator`: pink gum (primary) or amber glue, drawn behind front-layer items only.
- `StickyBlockedFeedback`: reusable visual controller for taps and held pulls. Its exported tuning
  controls the lean cap, resistance distance, return timing, and cooldown. The dedicated blocked
  pose composes with landing/highlight state without moving the item root or collision shape.
- `CollisionShape2D`: rectangular item hitbox used by runtime interaction. Tap selection shifts it
  down with the sprite, outline, and shadow so the item reads closer to the shelf lip without
  moving its logical slot anchor or leaving the visible art outside its touch target.

Depends on:
- Texture assignment from `scripts/level.gd`.
- Highlight outline color and width assignment from `scripts/level.gd`.
- Item IDs defined in `configs/item_sprites.json`.

Do not use for:
- Shelf placement rules, matching logic, or level progression.
