# UI-003 — Unify Level HUD, Gameplay Modals, and Result Screens

**Status:** Implemented and validated

**Type:** UI/Refactor/Behavior

**Primary scope:** `level.tscn` and its player-facing HUD, modal, result, and locked-shelf subscenes

**Depends on:** UI-001 shared visual roles and UI-002 interaction/motion behavior

## Objective

Bring the playable level UI into the same intentional system as the completed menu-screen work.
The level may keep a denser, higher-contrast gameplay presentation, but equivalent concepts must use
shared colors, shapes, component roles, interaction feedback, motion, safe-area rules, and navigation
behavior rather than scene-local approximations.

This ticket is presentation and UI ownership work. It must preserve current level rules, life and
star accounting, coin prices, immediate paid-ability behavior, save behavior, and backend protocol
semantics.

## Audited Scope

- `level.tscn`: top HUD, timer, level label, star counter, pause button, ability-bar placement,
  embedded failure overlay, and overlay instances.
- `scenes/ui/ability_bar.tscn` and `scripts/ability_bar.gd`.
- `scenes/pause_menu.tscn` and `scripts/pause_menu.gd`.
- `scenes/leave_confirmation_menu.tscn`.
- `scenes/ability_purchase_menu.tscn` and `scripts/ability_purchase_menu.gd`.
- `scenes/ui/level_completion_screen.tscn` and `scripts/level_completion_screen.gd`.
- `scenes/shelf.tscn`'s player-facing `LockedOverlay`.
- The overlay orchestration, layout, input, and terminal-state paths in `scripts/level.gd`.
- Existing shared resources in `assets/themes/`, `scripts/press_scale_button.gd`, and
  `scripts/ui_motion.gd` where the gameplay UI should consume them.

The audit included source inspection and runtime review of gameplay, Pause, Leave Confirmation,
Ability Purchase, Completion, and Failure at the 720×1280 design viewport.

## Inconsistencies Found

| Priority | Area | Current inconsistency | Required unification |
| --- | --- | --- | --- |
| P0 | Failure flow | `level.tscn` embeds a shade and `LEVEL FAILED` label with no action. `_fail_level()` only makes it visible, leaving the player in a terminal screen with no route forward. This also violates the project rule that multi-node result screens own separate scenes. | Extract `scenes/ui/level_failure_screen.tscn` with a focused owner script and a working `Main Menu` action. Keep retry/life-policy changes out of this ticket. |
| P1 | Disabled pause button | `PauseMenuButton` has normal, hover, and pressed styles but no disabled style. Opening any overlay disables it and Godot falls back to a square default control, visibly changing the control. | Give Pause an explicit disabled override using the same warm resource as its normal Main Menu settings-button role; keep explicit disabled resources on every ability button. |
| P1 | Rewarded-ad placeholder | `WatchAdButton` looks enabled, scales when pressed, and emits a signal, while `_on_ability_purchase_ad_pressed()` is empty. The authoritative backend requirement says the placeholder grants nothing until a separate rewarded-ad feature is approved. | Do not expose an enabled no-op. Hide it in production until approved; any developer preview must be disabled, use the shared unavailable style, and say `Coming Soon`. |
| P1 | Back behavior | `scripts/level.gd::_input()` has no `ui_cancel` handling and returns immediately while paused. System back therefore does nothing during gameplay and overlays. Close/Continue also collapse the Leave Confirmation directly into gameplay instead of distinguishing “pop this confirmation” from “resume.” | Implement one topmost-overlay back stack: gameplay opens Pause; Pause resumes; Leave Confirmation returns to Pause; Ability Purchase restores its prior state; terminal results use their visible navigation action. |
| P1 | Completion copy | Completion says `Next`, but `_on_completion_next_pressed()` returns to the Main Menu rather than starting the next level. | Use the minimal-risk contract: rename the action to `Continue` and preserve return-to-menu behavior. Starting another authoritative run is not part of this UI ticket. |
| P1 | Ability-purchase copy | `GET MORE ITEMS` and `×1` read like inventory acquisition, but the implementation purchases and applies one ability immediately without adding inventory. | Rename the presentation to `USE ABILITY` and document that the purchase is one immediate use. Do not alter the transaction behavior; avoid a redundant secondary badge. |
| P1 | Interaction feedback | Pause, all four ability buttons, and all three red modal close buttons omit `PressScaleButton`. Several CTAs retain default focus, and scoped controls do not consistently set the desktop pointing-hand cursor. | Apply UI-002 to every action: 0.97 held scale for ability/close icons, 0.94 for the warm Pause/settings role and CTAs, `FOCUS_NONE` under the documented touch-only policy, and pointing-hand cursor only while enabled. |
| P1 | Overlay motion | Pause, Leave Confirmation, Ability Purchase, Completion, and Failure snap between `visible` states. Their scripts do not use the shared motion helper, block repeated transitions, or protect against tween accumulation. | Use the shared 180–220 ms overlay/result transition tokens, replace active tweens safely, and prevent input-through/double navigation during transitions. |
| P2 | Modal duplication | Pause, Leave Confirmation, and Ability Purchase repeat the same shade, terracotta outer panel, cream inner panel, red close-button styles, shadow values, margins, and bottom action-row layout as local subresources. | Extract one gameplay modal shell or inherited base scene with named content/action slots, plus shared `.tres` styles. Individual scenes should own only their content and signals. |
| P2 | Geometry roles | Gameplay modal outer panels use radius 30 while the established large-panel role is 24. Their 72×72 close controls use radius 32 instead of a true circular radius 36. Count badges and item slots use unrelated 18/20/24/30 radii for equivalent concepts. | Reuse the 16/20/24 geometry system; make circular controls/badges mathematically circular. Expose compact/regular/hero sizes as named variants rather than new corner values. |
| P2 | HUD icon-button role | The Pause button and 82/96 px ability buttons used near-matching navy backgrounds despite different semantic roles. Pause also used the font text `II`. | Keep the circular navy role for abilities; make Pause match the Main Menu's 72x64 warm settings control because both open settings/navigation UI. Build the pause mark from two scene-authored bars so it is not dependent on font glyph metrics. |
| P2 | Count/status badges | Ability-use counts use orange-red/gold, modal counts use burgundy/gold, the star counter is not a true pill, and equivalent badge sizes are recreated locally. Timer badges add another local shape without a named semantic role. | Share inventory-count badge resources with named compact/regular sizes, make the star total a true pill, and keep timed-status badges as a documented navy/cyan semantic exception. |
| P2 | Currency asset | Ability Purchase uses `assets/ui/main_menu_coin.png`; Main Menu and Shop now use the canonical spendable-currency art `assets/ui/clover_coin_transparent_96x96.png`. | Use the canonical clover coin anywhere a spendable coin balance or price is shown. |
| P2 | Disabled purchase state | An unaffordable Buy button reuses its enabled green texture and adds `modulate.a = 0.62`, unlike the shared neutral unavailable-action role. | Use a deliberate disabled resource, clear pointer/press feedback, and restore full modulation when enabled. Do not rely on opacity alone. |
| P2 | Result-screen parity | Completion is a dedicated responsive scene with hero content and a CTA; Failure is an embedded label. Their shades are also separate local values (`0.76` versus `0.68`). | Define a shared result-screen shell: result shade, hero title tier, content region, action region, safe-area layout, and entry/exit motion. Completion and Failure remain separate state-specific scenes. |
| P2 | Shade roles | Gameplay modals share a 0.66 shade, Failure uses 0.68, and Completion uses 0.76 without named roles. | Define exactly two resources: modal shade and stronger terminal-result shade. Failure and Completion use the same result shade. |
| P2 | CTA resources | Pause, Leave Confirmation, Ability Purchase, and Completion recreate red, green, and yellow-orange textured `StyleBoxTexture` resources instead of consuming shared semantic action styles. | Reuse shared positive, destructive, alternative, and unavailable styles. Keep regular/modal/hero dimensions as named size tiers, not palette variants. |
| P2 | Typography roles | Pause locally uses a 44 px title, longer modal titles use 40 px, result titles use unrelated 58/70 px values, and none of these tiers is named as a gameplay role. | Define modal-title regular/long variants and one result-hero title role through the theme or shared component. Keep uppercase for headings and title case for actions. |
| P2 | Responsive top HUD | Safe margins move the timer, level label, star counter, and pause button, but the top strip and center/combo slot keep their original height/position. A top inset can therefore push content below its background. The centered timer also owns the full width and has no exclusion zones for long level/star values. | Make the top HUD a safe-area-aware component whose background height, timer region, side regions, and combo slot move together. Add a compact layout that prevents overlap. |
| P2 | Responsive ability bar | Compact mode only changes button minimum size and row separation. Icon, count-badge, and timer-badge offsets remain authored for 96 px buttons, so they overflow 82 px controls. With `keep_width`, the 620 px branch may also be unreachable at the supported logical viewports. | Base the variant on usable logical width after safe insets and resize/reposition every child as part of the variant. Test counts and active timers in both variants. |
| P2 | Modal safe areas | `scripts/level.gd` centers fixed 520×500/560 panels and reaches into each scene by child name. The modal scripts do not own safe-area fitting, compact height, or close-button cutout clearance. | Move layout ownership into the shared modal shell; fit within safe bounds with a maximum width and minimum edge gaps at every supported viewport. `level.gd` should only set data, show/hide, and receive signals. |
| P3 | Freezer button labeling | Freezer alone sets visible button text (`Freeze`) while the other abilities are icon-only. None of the four has a consistent tooltip/accessibility label. | Keep the visual row icon-only and give all four controls consistent tooltip/accessibility names. |
| P3 | Settings disabled marker | `scripts/pause_menu.gd` creates the cross-out marker at runtime with hard-coded colors, position, size, and rotation. It cannot adapt with the scene and duplicates presentation logic used by the Main Menu settings window. | Extract the marker as a scene-owned/shared visual child or reusable component; scripts should only toggle its state. |
| P3 | Locked-shelf feedback | The remaining count changes and the lock overlay disappears instantly, while star, combo, and other gameplay state changes animate. | Use shared short feedback timing for count changes and a one-shot unlock fade/scale. Animation must not delay the actual unlock or input availability. |
| P3 | Reward-star variants | HUD/flying rewards, Leave Confirmation, and Completion use three reward-star rasters without documented semantic size roles. | Document and consistently reference compact, regular, and hero reward-star variants; do not introduce a fourth asset. |

## Required Work

### 1. Extract Shared Gameplay UI Roles

Add reusable resources/components for:

- Modal shade and terminal-result shade.
- Gameplay modal outer panel, inner panel, title, close button, and action row.
- Circular HUD icon button in compact and regular sizes, including disabled state.
- Inventory count badge in compact and regular sizes.
- Timed-status badge.
- Positive, destructive, alternative, and unavailable actions, reusing existing menu resources where
  the semantic role already matches.
- Modal-title regular/long and terminal-result hero typography roles.

Equivalent states must reference the same resource. Do not copy identical `StyleBoxFlat` or
`StyleBoxTexture` definitions into several `.tscn` files.

### 2. Refactor the HUD and Ability Bar

- Extract the top HUD from `level.tscn` when necessary to give it one owner for its strip, level,
  timer, star total, pause action, and combo slot.
- Make the top background grow with the safe-top inset and reserve non-overlapping left, center, and
  right regions.
- Use the shared circular action role for Pause and abilities, including normal, hover, held, and
  disabled states.
- Apply full regular/compact layouts to button size, icon bounds, use badge, and timer badge.
- Keep hit targets usable and prevent badge overflow with 1-, 2-, 3-, and longer-digit counts.
- Replace Pause's `II` text with a scene-authored two-bar icon.
- Remove Freezer's unique visible text and add consistent descriptive metadata to all abilities.

### 3. Extract and Reuse a Gameplay Modal Shell

Create `scenes/ui/gameplay_modal_shell.tscn` or an editable inherited-scene equivalent that owns:

- The fullscreen modal shade and input blocker.
- Safe-area-aware centered outer panel.
- Standard title region with regular/long variants.
- True-circular red close action.
- Optional cream content region.
- Standard bottom action region.
- Open/close motion and transition input gating.

Refactor Pause, Leave Confirmation, and Ability Purchase to inherit or compose that shell. Their
scripts own their data and signals. Remove fixed modal sizes and internal child-path layout from
`scripts/level.gd`.

### 4. Correct Modal Semantics

- Ability Purchase uses the canonical clover coin and says that it applies one ability immediately.
- An unaffordable Buy action uses the shared unavailable state.
- Hide the rewarded-ad action in production while it remains unimplemented.
- Leave Confirmation's close/system-back action returns to Pause; its explicit `Continue` action
  resumes gameplay; `Leave` keeps the existing life-spend and return behavior.
- Move the settings cross-out presentation into the scene/shared component.

Later economy-flow note: the in-level Shop follow-up supersedes the unaffordable Buy action above.
The coin-price action now remains enabled so a press can open the Shop overlay; insufficient coins
still never spend currency or apply the ability.

### 5. Unify Terminal Result Screens

- Extract `scenes/ui/level_failure_screen.tscn` and a focused script.
- Share a result shell/resource set between Completion and Failure without merging their state-specific
  content.
- Completion keeps its earned-star hero treatment and current return-to-menu behavior, but its CTA
  reads `Continue`.
- Failure provides a working `Main Menu` action so the player is never trapped.
- Both results share shade, title role, action placement, safe-area rules, and transition behavior.
- `scripts/level.gd` supplies result data and listens for signals; it does not own result hierarchy.

### 6. Standardize Interaction, Motion, and Back Navigation

- Apply `PressScaleButton` to every enabled visible action with UI-002 scales.
- Apply the touch-only focus policy and enabled pointer cursor consistently.
- Use shared motion tokens for modal/result opening and closing, and replace interrupted tweens rather
  than accumulating them.
- Block gameplay and duplicate UI actions during transitions.
- Implement this `ui_cancel` order:

  1. Leave Confirmation returns to Pause.
  2. Ability Purchase closes and restores the state from which it opened.
  3. Pause closes and resumes active gameplay.
  4. Active gameplay opens Pause.
  5. Completion invokes its `Continue` route; Failure invokes its `Main Menu` route.

### 7. Add Locked-Shelf State Feedback

- Keep the existing lock art and unlock condition.
- Pulse or cross-fade the remaining count when it decreases.
- Fade/scale the overlay once when the shelf unlocks, while making the shelf interactable immediately.
- Kill any prior overlay tween before a new state change and avoid retaining scale/modulate changes
  if the shelf is reconfigured.

## Acceptance Criteria

- Failure is a separate scene with an actionable exit; no terminal level state can trap the player.
- Opening Pause, Leave Confirmation, Ability Purchase, Completion, or Failure never turns the top
  Pause control into a square or exposes an engine-default style.
- Pause matches the Main Menu settings-button size/color/state system; the four ability buttons
  share their own named compact/regular circular role.
- Pause, ability, close, and CTA controls all have consistent held feedback, focus policy, and enabled
  pointer cursor.
- No enabled button performs a no-op. The unimplemented rewarded-ad action is absent from production.
- `ui_cancel` follows the specified topmost-state order and never spends a life, coins, or stars by
  itself.
- Pause, Leave Confirmation, and Ability Purchase consume the same modal shell/resources rather than
  local copies of shade, outer panel, inner panel, close button, and action-row styles.
- Large panels, cells, buttons, pills, and circles follow documented geometry roles; circles are
  actually circular at every named size.
- Ability Purchase uses the canonical clover coin and accurately communicates an immediate paid use.
- Unaffordable Buy state is visually and behaviorally unavailable without alpha-only styling.
- Completion and Failure share terminal shade, title/action layout, safe-area behavior, and motion.
- Completion's action label matches its return-to-menu behavior.
- Modal and result transitions use shared timings, replace interrupted tweens, block input-through,
  and cannot double-navigate.
- Safe top/background geometry stays aligned, and Timer, Level, stars, and Pause never overlap with
  simulated display cutouts or long values.
- Compact ability layout moves/resizes icons and both badge types, not only the parent button.
- Locked-shelf counts remain readable at 1, 2, and 3+ digits and unlock feedback never delays
  gameplay availability.
- Existing star earning, life spending, coin pricing/spending, ability effects, ability inventory,
  and completion/progression results are unchanged.
- No new raster artwork is required.

## Verification

Add an isolated structural/behavior suite, recommended as
`tests/ui/test_level_ui_consistency.gd`, covering:

- Shared resource identity for modal shell, shade, close, Main Menu/Pause warm-button, ability,
  badge, and CTA roles.
- Explicit Pause and ability disabled styles; no engine-default fallback.
- Held-scale restoration after release outside, disable while held, visibility change, and scene exit.
- Focus and cursor policy for every level-owned button.
- Production absence of an enabled rewarded-ad no-op.
- Completion and Failure signal routing and matching action copy.
- `ui_cancel` behavior from gameplay, Pause, Leave Confirmation, Ability Purchase, Completion, and
  Failure.
- Safe-area layout with top, side, and bottom insets.
- Regular/compact ability icon and badge bounds.
- Long level number, `59:59`, large star total, large ability-use counts, and active ability timers.
- Locked-shelf count update and unlock animation restoration.

Run the existing gameplay and save suites affected by `scripts/level.gd` and `PlayerProgress`, plus
the new UI suite through `scripts/tools/run_isolated_godot_test.ps1`.

Perform visual review at:

- 540×960
- 720×1280
- 1080×1920
- 1080×2400
- 1200×1600

At every size capture active gameplay, Pause, Leave Confirmation, affordable and unaffordable
Ability Purchase, Completion, Failure, disabled HUD, active ability timer, and a locked shelf. Also
test rapid taps, release outside, system back, top/side/bottom safe-area insets, application
background/resume, and transition interruption.

## Documentation Updates When Implemented

Update `docs/SCENES.md`, `docs/SCRIPTS.md`, `docs/PROJECT_MAP.md`, and `docs/TYPOGRAPHY.md` with:

- The extracted HUD, modal shell, and failure/result scene ownership.
- Gameplay color, shade, geometry, title, badge, and CTA roles.
- Interaction/motion ownership and `ui_cancel` order.
- Responsive variants and safe-area behavior.
- Immediate paid-ability copy and the hidden rewarded-ad placeholder policy.

## Follow-up Validation Fixes (2026-08-07)

A post-implementation runtime review found and fixed six gaps that the first structural suite did
not exercise:

- Modal button handlers now reject navigation during fades, and owner close coroutines cannot hide
  a shell that was reopened while the close was waiting.
- The safe-area HUD uses a real compact center allocation and scales all top-row roles together;
  tests compare resolved rectangles rather than pre-layout offsets.
- Gameplay modal safe fitting uniformly scales the complete composed panel, including action and
  close controls, rather than shrinking only the outer panel around fixed-size children.
- Six-digit ability counts and large star totals fit their rendered badge/pill bounds.
- Disabled Pause and ability controls restore the arrow cursor.
- Completion and Failure now reference the same positive CTA `StyleBox` resource by identity.

`tests/ui/test_level_ui_consistency.gd` contains direct regressions for each case, including the
rapid Pause -> Leave -> Close transition sequence that previously could leave gameplay paused with
no visible overlay.

## Visual Regression Follow-up (2026-08-07)

A second visual review corrected three regressions introduced by over-unifying different roles:

- Pause now matches the Main Menu settings control exactly in normal sizing and style: 72x64, warm
  normal/pressed resources, dark-brown scene-authored bars, and 0.94 held scale. It retains an
  explicit warm disabled override and scales only when extreme side insets require it.
- Pause, Leave Confirmation, and Ability Purchase now share the compact 520x500 outer-shell size.
  Their cream content regions are content-sized rather than stretched: 224px for Pause/Purchase and
  240px for Leave Confirmation, with the existing whole-shell safe-area scale left intact.
- Ability Purchase no longer shows the redundant `USE NOW` badge. `USE ABILITY`, the selected icon,
  and the coin-price action communicate the immediate-use flow without duplicate copy.

The isolated UI suite now checks all three decisions directly so the role coupling and stretched
inner panels cannot silently return.

## Locked-Shelf Chain Refresh (2026-08-11)

The later locked-shelf visual refresh supersedes this ticket's original "no new raster artwork"
constraint for that component only:

- `scenes/ui/shelf_lock_overlay.tscn` / `scripts/shelf_lock_overlay.gd` now own the extracted standard
  and compact lock overlay instead of duplicating nodes in both shelf scenes or keeping animation
  internals in `scripts/level.gd`.
- The follow-up selected three-link candidate A, stored as `assets/ui/shelf_lock_chain_arm_a.png`,
  replaces the heavier C2 strip. Four independent arms cross over the existing orange `AD` lock,
  with remaining clears shown in the shared gameplay count badge.
- Decrements pop the count, tension each arm toward the lock, and swing the hanging lock. Reaching
  zero retracts the arms into their wall anchors and drops the lock while shelf eligibility still
  changes immediately.
- Hammer-cleared triples retain the existing `_record_triples_cleared()` path and therefore continue
  to decrement the overlay.
- `tests/ui/test_shelf_lock_overlay.gd` is the focused regression; the locked-shelf phase in
  `tests/ui/test_level_ui_consistency.gd` also covers the extracted hierarchy.

### Wall-Attachment Follow-up (2026-08-12)

- Each chain arm is now fitted between an endpoint embedded beneath a shelf side wall and an
  endpoint over the lock shackle. Small per-arm endpoint variations avoid a mechanically mirrored X.
- Overlay-owned wood covers mask the outer links, while the lock draws behind the chains and the
  count draws above them.
- Decrement tension keeps wall endpoints fixed and moves only shackle endpoints; unlock collapses
  each arm back into its wall without delaying shelf eligibility.
- `RemainingLabel` now reuses `style_box_gameplay_count_badge.tres` and the same shared font-fitting
  constants as `AbilityBar/UsesLabel`.

## Out of Scope

- Puzzle rules, shelf layout algorithms, item art, drag/drop, matching, ability effects, or level
  configuration changes.
- Retry/run-start design. Failure exits to Main Menu in this ticket; adding Retry requires a separate
  life/run-lifecycle decision and tests.
- Life, star, coin, inventory, reward-chest, progression, save-sync, leaderboard, purchase, catalog,
  or backend protocol changes.
- Rewarded-ad SDK, reward grant, analytics, audio, haptics, or new generated artwork.
- Changing the current immediate paid-ability transaction into an inventory purchase.
