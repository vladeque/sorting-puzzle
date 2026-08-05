# UI-002 — Standardize UI Interaction, Navigation, and Motion

**Status:** Proposed

**Type:** UI/Behavior

**Primary scope:** `main_menu.tscn`, `leaderboard_screen.tscn`, `shop_screen.tscn`, `chapter_selection_screen.tscn`

**Depends on:** UI-001 shared visual roles and component boundaries

## Objective

Make every actionable control in the four-screen scope respond predictably to touch, mouse, keyboard/gamepad focus, active-tab reselection, system back, loading, and navigation. Establish one small motion language so buttons, tabs, navigation icons, overlays, and reward progress no longer mix scaling, color-only feedback, persistent toggles, and no feedback.

## Current Problems

- `PressScaleButton` is used by Main Menu Play/Chapter, Chapter CTA/back/arrows, Main Menu Settings, and Shop Purchase, but not by Profile, Reward Chest, bottom navigation, Leaderboard tabs/Retry, Shop Retry, purchase-dialog Close, or clickable Shop ability cells.
- Some controls darken when pressed, some reverse border depth, some scale instantly, and some have no visible pressed state.
- Leaderboard tabs have a distinct hover state while most other controls reuse their normal state.
- Retapping active Shop reloads the catalog, retapping active Leaderboard refreshes rankings, and retapping active Home does nothing.
- Only Chapter Selection handles `ui_cancel`; Shop and Leaderboard do not return Home through the same action.
- Focus policy is mixed: some controls use `FOCUS_NONE`, while others accept focus but have no deliberate focus style.
- Several clickable controls do not use the pointing-hand cursor on desktop.
- The chapter pager uses a 0.32-second eased slide, but screen changes, overlay opening/closing, and bottom-navigation active-icon movement snap instantly.
- Main Menu flies clover coins into a chest whose progress is advanced by earned stars, while clover coins elsewhere represent spendable currency.

## Required Work

### 1. Define Interaction Roles

Apply a shared interaction owner to every visible action:

- Primary and secondary CTA buttons.
- Icon buttons.
- Segmented/toggle tabs.
- Bottom-navigation tabs.
- Art-only hit targets such as Profile and Reward Chest.
- Shop ability information cells.
- Retry and dialog-dismiss buttons.

Enhance or wrap `PressScaleButton` so an invisible hit target can animate a designated visual child without shrinking or moving the touch rectangle.

Recommended held scales:

- `0.94` for primary and secondary CTA buttons.
- `0.97` for compact tabs, bottom navigation, icon buttons, and clickable cells.

The control must always restore its released state after release outside the button, visibility changes, disabling, scene exit, or an interrupted transition.

### 2. Standardize Button States

Each interactive role must define normal, hover, pressed, disabled, and focus presentation, even when two states intentionally share a visual resource.

- Pressed feedback must use the same combination of scale, color, and depth for each role.
- Disabled controls must not scale, animate as successful, emit purchase/select actions, or retain a hover cursor.
- Persistent selection, such as a Leaderboard scope tab, must remain visually distinct from the momentary held state.
- Art-only controls must visibly acknowledge a tap without changing the underlying icon asset.

### 3. Standardize Bottom-Navigation Behavior

Use one active-tab reselection rule on all three destinations.

Recommended rule: retapping the already-active tab is a no-op. Catalog and leaderboard refresh must remain available through explicit Retry/error behavior or a separately designed refresh interaction, not a hidden tab-retap convention.

Cross-destination navigation must ignore duplicate presses while a scene transition is active.

### 4. Standardize Back and Focus Behavior

- `ui_cancel` closes Chapter Selection and any open scoped overlay first.
- With no overlay open, `ui_cancel` on Shop or Leaderboard returns to Main Menu.
- Main Menu must not quit or navigate unexpectedly from `ui_cancel` without a separately approved exit flow.
- All clickable desktop controls use the pointing-hand cursor while enabled.
- Adopt and document one focus policy. Recommended: `FOCUS_ALL` for enabled actions with a visible shared focus style, allowing keyboard/gamepad navigation during desktop testing. If the product is deliberately touch-only, use `FOCUS_NONE` consistently and document that decision instead.

Focus order must follow visible reading order and must not enter hidden, disabled, or off-page Chapter controls.

### 5. Establish Motion Tokens

Use shared constants or a focused animation helper rather than local durations:

- Press-in: 80–100 ms.
- Release: 100–140 ms.
- Bottom-navigation active icon/label change: 150–180 ms.
- Overlay and destination fade/slide: 180–220 ms.
- Chapter pager snap: retain approximately 320 ms with quadratic ease-out.

Motion must respect rapid repeated input: kill or replace prior tweens without accumulating scale, offsets, opacity, or callbacks.

Scene transitions must prevent double navigation and must not leave the old screen accepting input while the new screen becomes visible.

### 6. Correct Reward-Progress Semantics

Use the existing reward-star artwork when earned stars travel into the reward chest and advance chest progress. Clover-coin art must appear only when spendable coins are actually granted or displayed.

This is a presentation correction only. Do not change chest thresholds, rewards, economy, save data, leaderboard score, or progression calculations.

Rename `main_menu_reward_coin_flyer` only if necessary to make ownership accurate; preserve backward-compatible scene references within the same change.

### 7. Standardize Loading Feedback

Use the shared UI-001 status component and give Shop and Leaderboard the same loading feedback. If a spinner or pulse is added, it must:

- Use the shared motion tokens.
- Stop when the status becomes hidden or leaves the tree.
- Not block `ui_cancel` or bottom navigation.
- Avoid indefinite accumulated tweens across reloads.

## Acceptance Criteria

- Every visible action in the four-screen scope has deliberate held feedback and uses one of the documented held-scale roles.
- Profile, Reward Chest, bottom navigation, Leaderboard tabs/Retry, Shop Retry, purchase-dialog Close, and ability information cells no longer behave as feedback-less exceptions.
- Hit rectangles and responsive layout do not shrink when only the visual content scales.
- Normal, hover, pressed, disabled, persistent-selected, and focus states are deterministic and role-consistent.
- Retapping Home, Shop, or Leaderboard follows one documented behavior on every screen.
- `ui_cancel` closes Chapter Selection and overlays before returning Shop/Leaderboard to Main Menu.
- Enabled desktop controls use a consistent pointer cursor and focus policy.
- Bottom-navigation active icon/label changes animate instead of jumping.
- Screen and overlay transitions prevent duplicate navigation and input-through.
- Rapid press/release, tab switching, scene changes, and visibility changes never leave a control scaled, offset, transparent, disabled, or selected incorrectly.
- Chapter paging retains its current drag threshold, bounded overscroll, and approximately 0.32-second snap behavior.
- Earned-star chest progress uses star imagery; clover coins continue to mean spendable currency.
- No economy, progression, catalog, leaderboard, purchase, save, or backend protocol behavior changes.

## Verification

Run the existing isolated checks:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Scene scenes/shop_verification.tscn
& .\scripts\tools\run_isolated_godot_test.ps1 -Scene scenes/leaderboard_verification.tscn
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ui/test_chapter_ui.gd
```

Add interaction-focused automated coverage for:

- Press/release restoration, release outside, disable while held, visibility changes, and scene exit.
- Art-only controls animating their visual target without changing the hit rectangle.
- Active-tab reselection on Main Menu, Shop, and Leaderboard.
- Duplicate navigation presses while a transition is active.
- `ui_cancel` behavior with and without an overlay.
- Focus order and hidden/disabled control exclusion under the selected focus policy.
- Rapid Leaderboard scope switching without stale selected, loading, or tween state.
- Shop reload and purchase-dialog dismissal without lingering animation state.
- Reward-chest progress using star art without changing saved reward values.

Perform device/manual verification with touch and mouse at 540×960, 720×1280, 1080×1920, 1080×2400, and 1200×1600. Include rapid taps, drag-versus-tap on Chapter pages, release outside a button, backgrounding/resuming during a held press, and navigation during loading.

## Documentation Updates

Update `docs/SCENES.md`, `docs/SCRIPTS.md`, and `docs/PROJECT_MAP.md` with the interaction owner, motion tokens, active-tab rule, back behavior, focus policy, and corrected reward-progress animation semantics.

## Out of Scope

- Visual palette, shared screen shell, title sizing, panel geometry, coin-widget design, or scrollbar styling except as required to consume UI-001 components.
- New generated artwork or audio.
- Haptics, sound effects, analytics, monetization, backend calls, provider refresh policy, save behavior, economy, or progression changes.
- Gameplay controls and menus outside the four-screen scope unless they directly reuse an updated shared interaction script and require a compatibility adjustment.
