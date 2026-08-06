# UI-001 — Unify Menu-Screen Visuals and Responsive Layout

**Status:** Implemented and validated

**Type:** UI/Refactor

**Primary scope:** `main_menu.tscn`, `leaderboard_screen.tscn`, `shop_screen.tscn`, `chapter_selection_screen.tscn`

**Follow-up:** `UI-002 — Standardize UI Interaction, Navigation, and Motion`

## Objective

Give the Main Menu, Shop, Leaderboard, and Chapter Selection one intentional visual system without removing useful screen-specific hierarchy. Shared concepts such as destination backgrounds, screen titles, coin balances, status panels, buttons, borders, radii, shadows, and safe-area spacing must use shared components or theme resources instead of slightly different scene-local values.

## Current Problems

- Main Menu follows the selected chapter background, while Shop and Leaderboard always load `assets/backgrounds/main_menu.jpeg`.
- Shop and Leaderboard use nearly identical but different background shades, title sizes, header heights, orange controls, burgundy surfaces, and gold borders.
- Chapter Selection does not apply device safe-area or display-cutout margins to its back button, information card, or page indicators.
- The same coin balance appears as a pink radius-8 counter on Main Menu and a cream radius-20 pill in the Shop.
- Main Menu Play and Shop Purchase use glossy green primary-button art, while Chapter Selection uses a flat orange `PLAY`/`CONTINUE` button for the same positive action role.
- Loading, empty, and error states are laid out and styled differently in Shop and Leaderboard.
- Default gray Godot scrollbars remain visible against the illustrated UI.
- The Main Menu chapter button currently uses yellow-orange art while `docs/SCENES.md` and `tests/ui/test_chapter_ui.gd` still require light-blue art. The scene also uses `-20` action separation while the verification expects `-12`.
- Chapter CTA casing conflicts with `docs/TYPOGRAPHY.md`, which reserves uppercase for titles, headings, and special level-launch labels rather than ordinary actions.

## Required Work

### 1. Establish Shared Visual Tokens

Extend the project-wide UI theme or add focused `.tres` style resources for the four-screen scope. At minimum, define and reuse:

- Secondary-screen background shade.
- Cream text and surface colors.
- Burgundy panel and row colors.
- Gold border and highlight colors.
- Green primary-action styling.
- Orange secondary/utility-action styling.
- Standard shadows and pressed depth.
- Corner-radius roles: 16 px for buttons, 20 px for rows/cells, and 24 px for large panels.
- Screen-title typography: 48 px regular and 40 px compact, using `GameTitleLabel`.

Do not replace the existing DynaPuff/Nunito typography roles or attach fonts directly to scenes.

### 2. Create a Shared Destination-Screen Shell

Extract a reusable scene/component that owns the common Shop and Leaderboard structure:

- Fullscreen selected-chapter or explicitly neutral background.
- Standard secondary-screen shade.
- Safe-area-aware content margins.
- Standard title header.
- Maximum content width.
- Bottom gap above `main_menu_bottom_navigation.tscn`.
- Shared bottom-navigation placement and safe-bottom padding.

Shop and Leaderboard content remains screen-owned. The shell must not own catalog, purchase, leaderboard, ranking, or progression logic.

### 3. Preserve an Immersive Chapter-Selection Variant

Chapter Selection may keep full-bleed chapter artwork and its bottom information panel, but it must reuse the shared safe-area/header rules. Add a top-center `CHAPTERS` title unless the immersive-title exception is explicitly documented in `docs/SCENES.md` and `docs/TYPOGRAPHY.md`.

The back button, information panel, arrows, and page indicators must remain inside safe bounds on notched and non-notched displays.

### 4. Standardize Component Roles

- Reuse `coin_balance_widget.tscn` for Main Menu and Shop, with explicit compact and regular variants if needed.
- Make the Main Menu coin `+` open Shop, or remove it if the balance remains non-interactive.
- Use the green primary-action role for Main Menu Play, Chapter `Play`/`Continue`, and Shop Purchase.
- Use orange for retry, dismiss, secondary, and utility actions.
- Standardize green purchase-button height and label treatment; allow only documented regular and hero sizes.
- Extract one reusable loading/empty/error component for Shop and Leaderboard.
- Add a game-styled vertical scrollbar or hide the scrollbar on touch devices while keeping scrolling discoverable and functional.
- Replace square pager dots with circular inactive indicators and a rounded active capsule.

### 5. Resolve the Main Menu Chapter-Button Drift

Choose one authoritative chapter-button treatment before implementation proceeds:

- Recommended: restore the documented light-blue secondary CTA so it remains visually distinct from the green Play button and orange utility controls.
- Alternative: retain yellow-orange, then update the visual role, text treatment, documentation, and test expectation together.

Whichever option is selected, set one intentional overlap/separation value and update `main_menu.tscn`, `docs/SCENES.md`, and `tests/ui/test_chapter_ui.gd` in the same change.

### 6. Normalize Typography and Copy

- Use `Play`, `Continue`, `Locked`, and `Coming Soon` for Chapter actions.
- Keep screen titles and section headings uppercase.
- Use the real ellipsis character (`…`) consistently in loading copy.
- Preserve localized store price strings exactly as supplied by the store provider.

## Acceptance Criteria

- Shop and Leaderboard obtain their background through one shared policy and do not silently revert to Chapter 1 art after another chapter is selected.
- Shop and Leaderboard use the same shade, header height, title sizes, safe-area layout, maximum width, and bottom-navigation gap.
- Chapter Selection keeps its back button, title/exception, page arrows, indicators, and information panel clear of safe areas and display cutouts.
- The same coin balance has the same palette, border, shape, icon, and number styling on Main Menu and Shop; size differences are exposed as named variants.
- Green, orange, burgundy, cream, and gold values come from shared resources rather than approximate scene-local copies.
- Positive actions are green; retry/dismiss/utility actions are orange unless a documented semantic exception exists.
- Buttons, rows, cells, and large panels use the 16/20/24 px geometry roles.
- Shop and Leaderboard use the same loading, empty, error, and Retry presentation.
- No default gray scrollbar is visible in the four-screen scope.
- The Main Menu chapter-button art, overlap, documentation, and automated expectation agree.
- Chapter action casing follows `docs/TYPOGRAPHY.md`.
- No new raster artwork is required. Existing button, coin, star, background, and navigation assets should be reused.

## Verification

Run the existing isolated checks:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Scene scenes/shop_verification.tscn
& .\scripts\tools\run_isolated_godot_test.ps1 -Scene scenes/leaderboard_verification.tscn
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ui/test_chapter_ui.gd
```

Add or extend structural UI tests to verify:

- Selected Chapter 1 and Chapter 2 background continuity through Main Menu, Shop, and Leaderboard.
- Shared title, shade, status-state, coin-widget, and geometry resources.
- Chapter safe-area offsets with simulated top, side, and bottom insets.
- Bounds at 540×960, 720×1280, 1080×1920, 1080×2400, and 1200×1600.

Perform visual review at the five required portrait sizes for normal, loading, empty, error, and scrolled states. Confirm long leaderboard names, regional prices, `LEADERBOARD`, and Chapter lock copy remain readable without overlap or truncation.

## Documentation Updates

Update `docs/SCENES.md`, `docs/SCRIPTS.md`, `docs/PROJECT_MAP.md`, and `docs/TYPOGRAPHY.md` for the final shell, shared components, style roles, and any documented Chapter Selection exception.

## Out of Scope

- Store provider, purchase, catalog, leaderboard provider, save, economy, or progression changes.
- New generated images or replacement background artwork.
- Gameplay HUD, pause menu, result screens, profile modal, settings modal, or reward dialogs except where a reused shared style requires a non-behavioral update.
- Interaction timing, active-tab behavior, system-back behavior, and reward animation semantics; those belong to UI-002.
