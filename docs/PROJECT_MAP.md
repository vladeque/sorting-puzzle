# Project Map

Use this file as the first stop when you need to identify where a feature lives. Keep entries short and update this map in the same commit as meaningful scene, script, or config changes.

## Entry Points

Main scene:
- `scenes/main_menu.tscn`
- Configured in `project.godot` as `run/main_scene`.
- `project.godot` keeps the 720x1280 design viewport and uses `canvas_items` stretch with `keep_width` so portrait devices share a stable logical width while gaining or losing vertical play space.
- Owns the production campaign entry point over the selected chapter's `selection_preview`,
  launches that chapter's next level, and opens the chapter picker from the action beneath the level
  button. Chapter selection updates the menu background immediately.
- Shows a separate left-side reward chest progress widget under the profile icon.

Testing menu:
- `scenes/main_menu_testing.tscn`
- Preserves the previous main menu with campaign play and developer/test level selection.

Playable level scene:
- `level.tscn`
- Instantiated by `scripts/main_menu.gd`; the current completion action returns to the Main Menu.
- Owns shelf layout, timer, drag and tap movement, triple matching, abilities, pause-menu wiring, failure, and completion flow.
- Uses the original procedural gameplay background for Chapter 1 and chapter artwork for chapters
  whose catalog entry selects `artwork` mode.
- Uses one shared gameplay UI system for its HUD, ability bar, Pause/Leave Confirmation/Ability
  Purchase modals, and Completion/Failure terminal results (UI-003, implemented and validated --
  see `docs/UI_003_LEVEL_UI_CONSISTENCY_TICKET.md` and "Shared Gameplay UI" below).

Player progression:
- `scripts/player_progress.gd`
- `scripts/save/*.gd`
- `configs/backend/content_provenance.json`
- `configs/chapters.json`
- Registered in `project.godot` as the `PlayerProgress` autoload.
- Always saves account-scoped gameplay locally with atomic generations and a signed operation
  journal; backend synchronization is a silent recovery/merge destination.
- Campaign levels 1-10 journal the exact configuration/level/rules identities generated from the
  active local backend publication. Future unpublished levels remain local and never receive fabricated
  protocol provenance.

Reusable item scene:
- `scenes/item.tscn`
- Instantiated by `scripts/level.gd` for every shelf item.
- Displays the item sprite and exposes item identity through `ShelfItem`.

## Core Systems

### Backend Planning

Files:
- `docs/BACKEND_REQUIREMENTS.md`
- `docs/LOCAL_BACKEND_INTEGRATION.md`
- `docs/DEV_BACKEND_INTEGRATION_PLAN.md`
- `docs/DEV_BACKEND_CODE_TICKETS.md`
- `docs/DEV_BACKEND_OWNER_TICKETS.md`

Responsibility:
- Defines the approved production backend requirements for identity, authoritative progression and economy, offline synchronization, Shop offers and purchases, leaderboards, profile moderation, privacy, administration, operations, testing, and phased implementation.
- Records confirmed product decisions and the remaining policies that must be finalized during the protocol-design phase.
- Separates the completed/in-progress local Android integration from the planned deployed
  development environment for Android and iOS.
- Tracks source-controlled integration work independently from project-owner actions in Google
  Cloud, Google Play Console, Apple Developer, and App Store Connect.

Change here when:
- Backend authority boundaries, platform integrations, offline behavior, offer types, leaderboard rules, or implementation phases change.
- Deployed development-environment dependencies, ownership, ticket status, or qualification gates
  change.

### Level Selection

Files:
- `scenes/main_menu.tscn`
- `scenes/main_menu_testing.tscn`
- `scenes/ui/main_menu_top_status.tscn`
- `scenes/ui/main_menu_reward_chest.tscn`
- `scenes/ui/reward_chest_menu.tscn`
- `scenes/ui/profile_menu.tscn`
- `scenes/ui/settings_menu.tscn`
- `scenes/ui/level_button.tscn`
- `scenes/ui/main_menu_chapter_button.tscn`
- `scenes/ui/chapter_selection_screen.tscn`
- `scenes/ui/chapter_cover_card.tscn`
- `scenes/ui/horizontal_pager.tscn`
- `scenes/ui/coin_balance_widget.tscn`
- `scenes/ui/main_menu_coin_shortcut.tscn`
- `assets/ui/clover_coin_transparent_96x96.png`
- `assets/ui/reward_star_84x84.png`
- `assets/ui/main_menu_lives.png`
- `assets/ui/main_menu_reward_chest.png`
- `assets/ui/reward_chest_menu_illustration.png`
- `assets/abilities/ability_hammer.png`
- `assets/abilities/ability_lantern.png`
- `assets/abilities/ability_shuffle.png`
- `assets/ui/avatar_circle_clip.gdshader`
- `assets/ui/avatars/*.png`
- `assets/ui/level_button_blank*.png`
- `assets/themes/style_box_green_primary_button.tres`
- `assets/themes/style_box_disabled_action_button.tres`
- `assets/themes/style_box_pager_dot_inactive.tres`, `style_box_pager_dot_active.tres`
- `assets/themes/style_box_warm_icon_normal.tres`, `style_box_warm_icon_pressed.tres`
- `scripts/press_scale_button.gd`
- `scripts/ui_motion.gd`
- `scripts/horizontal_pager.gd`
- `scripts/progress_ring.gd`
- `scripts/destination_screen_layout.gd`
- `scripts/production_main_menu.gd`
- `scripts/main_menu_coin_shortcut.gd`
- `scripts/coin_balance_widget.gd`
- `scripts/chapters/*.gd`
- `scripts/main_menu_reward_chest.gd`
- `scripts/main_menu_reward_star_flyer.gd`
- `scripts/reward_chest_menu.gd`
- `scripts/profile_menu.gd`
- `scripts/main_menu.gd`
- `scripts/player_progress.gd`

Responsibility:
- Shows the selected chapter's next chapter-local level and a chapter summary button directly below.
- Uses each catalog entry's `selection_preview` for both its full-screen chapter cover and the
  production main-menu background after that chapter is selected, through the shared
  `scripts/chapters/menu_background_resolver.gd` policy (also used by Shop/Leaderboard).
- Keeps the chapter picker on a dedicated overlay z-index above all production menu actions.
- Shows all configured chapters on a dedicated screen with a centered `CHAPTERS` title; locked
  cards expose exact previous-chapter progress toward the default 25-level requirement, and every
  overlay (back button, title, pager arrows/indicators, each card's information panel) respects
  device safe-area insets through the shared `scripts/destination_screen_layout.gd` helper while
  the full-bleed cover art itself stays uninset.
- Shows production top-row icons for the saved circular-clipped profile avatar, a tappable
  compact/regular-shared gold coin balance (`scenes/ui/coin_balance_widget.tscn` through
  `scenes/ui/main_menu_coin_shortcut.tscn`, which also opens the Shop when pressed), saved lives,
  and a warm rounded settings button styled like the chapter selection back button.
- Shows a separate side reward chest widget under the profile icon with saved stars versus the active configured goal; tapping it opens `scenes/ui/reward_chest_menu.tscn`, a read-only centered modal showing the same progress at a larger size, the dedicated `assets/ui/reward_chest_menu_illustration.png` artwork, and the coin payout waiting at the next goal.
- Uses one shared interaction/motion system across Main Menu, Shop, Leaderboard, and Chapter
  Selection (UI-002): `scripts/press_scale_button.gd` (now tween-based, with an optional
  `visual_target_path` so art-only/full-cell hit targets can animate without shrinking their touch
  rect) and `scripts/ui_motion.gd` (shared durations plus fade/retween/close-with-fade helpers) for
  press feedback and overlay/destination fades; retapping an already-active bottom-navigation tab is
  a no-op; `ui_cancel` closes the topmost overlay or returns to Main Menu; every control is
  `FOCUS_NONE` (documented touch-only policy). See `docs/SCENES.md`'s "Shared Interaction Roles".
- Opens `scenes/ui/profile_menu.tscn` from the profile widget, shows an editable player-name field above all 18 avatars in a centered pause-style window with a 3-column grid, and saves the name plus selected avatar through `PlayerProgress`.
- Opens `scenes/ui/settings_menu.tscn` from the settings widget, with pause-menu-style music, sound-effects, and vibration toggle visuals plus no-op `Support` and `Language` buttons.
- Disables campaign launch when saved lives are zero; the lives widget shows current lives and the `MM:SS` countdown until the next hourly restore.
- Uses `scenes/ui/level_button.tscn` and `assets/ui/level_button_blank_new.png` for the reusable glossy green level button visuals while keeping the label dynamic (also the shared `assets/themes/style_box_green_primary_button.tres` "regular" tier used by Shop purchase buttons); red, light-blue, and yellow-orange variants remain available beside the source texture for alternate states or future UI variants -- yellow-orange is the intentional Main Menu Chapter-button and in-level `Watch ad` secondary/alternative-action role (see `docs/SCENES.md` "Shared UI Style Tokens"), while light-blue is currently unused by any scene. The Chapter cover CTA instead uses a scene-local flat treatment sampled from the glossy green palette and matching the neutral disabled style's geometry.
- Uses `scripts/press_scale_button.gd` as the default held-press behavior for visible game UI buttons so they shrink slightly while a click or touch is held.
- Keeps free level selection out of the production menu.
- Preserves the old testing menu in `scenes/main_menu_testing.tscn`.
- Keeps Shop, Home, and Leaderboard entry points in the reusable full-width `scenes/ui/main_menu_bottom_navigation.tscn`; all three route between dedicated screens.
- Builds testing level buttons for levels 1 through 10 only when dev/test level selection is enabled.
- Instantiates `level.tscn`, assigns `selected_level`, `launched_from_dev_mode`, and `return_menu_scene_path`, swaps it into `SceneTree.current_scene`, and removes the menu.

Change here when:
- Adding production campaign entry UI, dev/test level selection UI, lock states, stars, level paging, or menu-to-game navigation behavior.

### Player Progression

Files:
- `scripts/player_progress.gd`
- `scripts/save/local_save_codec.gd`
- `scripts/save/local_save_store.gd`
- `scripts/save/secure_session_store.gd`
- `scripts/save/account_save_coordinator.gd`
- `scripts/save/guest_session_bootstrap_service.gd`
- `scripts/save/save_sync_service.gd`
- `platform/android/secure-store-plugin/`
- `platform/ios/secure-store-plugin/`
- `project.godot`
- `configs/reward_chest_goals.json`
- `docs/CLOUD_SAVE.md`

Responsibility:
- Keeps local persistence active in every build and namespaces progress by installation guest or
  immutable backend player id.
- Commits snapshot and journal operations through crash-safe current/previous/temporary generations.
- Stores device preferences separately and keeps keys/tokens behind Android Keystore or iOS
  Keychain bridge code.
- Registers installation guests with the backend challenge/proof flow and rebinds their local
  journal exactly once to the immutable backend player id.
- Uploads BE-307 v2 batches silently, persists exact retries, reconciles checkpoints/cursors, and
  retains inactive account journals.
- Tracks explicit per-level completions, selected chapter, compatibility campaign cursors, lives,
  economy, abilities, reward chest, leaderboard totals, and profile state.
- Defaults fresh and legacy profile saves to `avatar_cat` and a generated `player_` name with a five-character random suffix.
- Restores one missing life per elapsed real-time hour until the five-life cap is reached.
- Spends one campaign life when a campaign level fails or the player leaves from the pause menu.
- Commits ability/coin spends after effect preflight and before starting the gameplay effect.
- Accepts only the selected chapter's first incomplete level, prevents replay after completion, and
  derives later-chapter access from distinct previous-chapter completions.
- Adds earned campaign completion stars to the reward chest and grants configured gold coin rewards when goals are reached.
- Adds the same earned campaign completion stars to a non-spending lifetime total and a Monday-UTC weekly total for leaderboard scoring.

Change here when:
- Adding life tuning, operations, account flows, recovery, secure native storage, retries,
  checkpoint mapping, migrations, rewards, purchases, reset flows, or new persisted state.

### Headless Test Isolation

Files:
- `scripts/tools/run_isolated_godot_test.ps1`
- `scripts/tools/verify_shop.gd`
- `scripts/tools/verify_leaderboard.gd`
- `tests/save/test_player_progress_facade.gd`

Responsibility:
- Runs save-aware headless verification under a unique `SortingPuzzleTest_<id>` project identity so
  Godot resolves `user://` outside the live development player's `SortingPuzzle` data.
- Excludes the local backend override, reuses the import cache in a temporary project, and removes
  isolated project/user-data artifacts after each run.
- Refuses direct production-identity execution for the Shop, leaderboard, and PlayerProgress facade
  checks that intentionally purchase or reset progress.

Change here when:
- Adding a headless test that writes `user://`, changing the project name, or changing which project
  resource directories tests require.

### Android Local Backend Debug Export (GAME-003)

Files:
- `addons/sorting_puzzle_secure_store_bridge/plugin.cfg`
- `addons/sorting_puzzle_secure_store_bridge/export_plugin.gd`
- `platform/android/secure-store-plugin/.gdignore`
- `platform/android/secure-store-plugin/gradle.properties`
- `platform/android/secure-store-plugin/gradlew`, `gradlew.bat`, `gradle/wrapper/`
- `platform/android/secure-store-plugin/plugin/src/debug/AndroidManifest.xml`
- `export_presets.cfg`
- `local/backend_debug.example.cfg`
- `scripts/save/local_backend_debug_bootstrap.gd`
- `scripts/tools/android_local_backend_smoke_check.ps1`
- `scripts/tools/run_android_local_development.ps1`
- `scripts/tools/redeploy_android_game.ps1`
- `run_android_local_development.cmd`
- `redeploy_android_game.cmd`
- `platform/android/secure-store-plugin/README.md`

Responsibility:
- Packages the built `SortingPuzzleSecureStoreBridge` AAR as a Godot Android v2
  `EditorExportPlugin`, selecting the debug AAR (INTERNET permission +
  `usesCleartextTraffic="true"`) for debug exports and the release AAR (neither) otherwise.
- Excludes the native plugin's Gradle source/output tree from Godot resources via `.gdignore`; the
  selected AAR is still passed directly to the Android Gradle export.
- Defines a committed "Android (Local Backend Debug)" export preset with Gradle Build enabled.
- Supplies backend URL/sync-enabled overrides only through the gitignored, debug-build-only
  `local/backend_debug.cfg`. The export plugin injects the file only for debug builds; committed
  `project.godot` release defaults are never touched by this system.
- Documents and automates the `adb reverse tcp:8080 tcp:8080` local routing (with `10.0.2.2` as the
  fallback) and an emulator smoke check for `/health/live` reachability and secure-bridge
  availability.
- Provides a double-click daily-development launcher that starts or reuses the configured AVD,
  persistent backend database/secrets, and API before exporting, installing, and launching the
  debug game. Unlike the disposable GAME-010 gate, it preserves developer and app state and leaves
  its services running.
- Provides a fast redeploy launcher for game-only changes that requires those services to already
  be ready, validates content provenance, preserves emulator app data, and only exports, installs,
  and restarts the game.

Change here when:
- Changing how the secure-store AAR is built/packaged, the debug export preset, the local override
  mechanism, or the emulator smoke-check flow. This is Phase L1 of
  `docs/LOCAL_BACKEND_INTEGRATION.md`; identity/session and save-sync end-to-end verification are
  `GAME-004`-`GAME-006` (Phase L2), not this system.

### Local Backend Identity/Session Verification (GAME-004)

Files:
- `scripts/save/guest_session_bootstrap_service.gd`
- `scripts/save/save_sync_service.gd`
- `scripts/save/secure_session_store.gd`
- `scripts/save/local_backend_debug_bootstrap.gd`
- `scripts/tools/android_local_backend_identity_smoke_check.ps1`
- `tests/save/test_game_004.gd`

Responsibility:
- Exercises the GAME-001 guest challenge/bootstrap and rotating-refresh code against the real local
  backend and a real Android Keystore-backed installation key, closing gaps found only by driving
  the real HTTP entry points: malformed/expired-challenge/replayed/binding-mismatched bootstrap and
  session-refresh responses (`tests/save/test_game_004.gd`), non-secret identity/session
  diagnostics (server `correlation_id`, error codes, retry state -- see `PlayerProgress
  .get_local_save_diagnostics()` and `LocalBackendDebugBootstrap`'s periodic `identity
  diagnostics:` logcat line), and a one-time-rebind/restart-resumption proof at the
  `AccountSaveCoordinator` layer.
- `scripts/tools/android_local_backend_identity_smoke_check.ps1` extends the GAME-003 smoke check
  with a real guest-bootstrap wait and a force-stop/relaunch check that the same `player_id` and
  `device_id` are resumed (no second guest).
- Found and fixed two real on-device defects: `SecureSessionStore` gating bridge calls behind
  `_bridge.has_method(...)` (returned `false` on-device for a working bridge) and a missing
  `application/config/version` project setting (every protocol request's `meta.app.version` was
  empty and failed backend schema validation). See `docs/CLOUD_SAVE.md` and the GAME-004 entry in
  `docs/IMPLEMENTATION_TICKETS.md` for the full verification notes, including an unresolved
  emulator/`HTTPRequest` POST reliability issue that blocked a full live bootstrap observation.

Change here when:
- Changing the guest bootstrap/refresh identity flow, its non-secret diagnostics, or the identity
  smoke-check script. Save-sync end-to-end verification against PostgreSQL is `GAME-005`, not this
  system.

### Shared Backend Transport (GAME-007)

Files:
- `scripts/backend/backend_transport.gd`
- `scripts/backend/backend_read_operations.gd`
- `scripts/player_progress.gd`
- `tests/backend/test_game_007.gd`

Responsibility:
- Provides one reusable authenticated read transport for bodyless authenticated v1 `GET` reads
  (`/v1/player/state`, `/v1/player/devices`, `/v1/catalog`, `/v1/purchases/{transaction_id}`,
  `/v1/leaderboards/{scope}`), for backend features outside the focused save services owned by
  `GAME-001`/`GAME-004`-`GAME-006`.
- Owns bearer headers, a client-generated `X-Correlation-ID`, timeouts, response-envelope
  validation, structured errors, retry classification, and exactly one refresh-and-replay on `401`.
  Never invents a request body or protocol/app headers for these bodyless reads.
- Retries only network failures, `429` (honoring `Retry-After`), and `502`/`503`/`504`, bounded to
  one initial try plus four retries within 30 seconds, per the backend's documented read retry
  policy; every other outcome (including `500`, which is mutation-retry-only) is terminal.
- `scripts/backend/backend_read_operations.gd` holds closed protocol adapters that validate every
  field they expose and map unrecognized response enum values to `"unknown"`.
- `PlayerProgress.get_backend_transport()` exposes one configured instance wired to the existing
  `SecureSessionStore` and active player id; it does not read or write save state itself.
- Does not touch `scripts/save/save_sync_service.gd`'s mutation idempotency/retry behavior.

Change here when:
- Adding a new authenticated backend read, changing read retry/refresh policy, or building the
  catalog (`GAME-008`) or leaderboard (`GAME-009`) providers that consume this transport.

### Shared Destination-Screen UI

Files:
- `scenes/ui/destination_screen_shell.tscn`
- `scenes/ui/destination_status_panel.tscn`
- `scripts/destination_screen_shell.gd`
- `scripts/destination_status_panel.gd`
- `scripts/destination_screen_layout.gd`
- `scripts/ui_motion.gd`
- `scripts/press_scale_button.gd`
- `scripts/chapters/menu_background_resolver.gd`
- `assets/themes/style_box_status_panel.tres`
- `assets/themes/style_box_orange_utility_normal.tres`, `style_box_orange_utility_pressed.tres`

Responsibility:
- Owns the visual structure Shop and Leaderboard share: a fullscreen selected-chapter background
  with a secondary-screen shade (`%DestinationShell`), safe-area-aware content margins capped to a
  720px maximum logical width with 48/40 regular/compact title sizing and bottom-navigation
  placement (`scripts/destination_screen_layout.gd`), and a bordered loading/empty/error/Retry
  presentation (`%StatusPanel`) that pulses its message while loading (UI-002,
  `scripts/ui_motion.gd`) and whose Retry button uses `scripts/press_scale_button.gd`.
- `scenes/ui/in_level_shop_screen.tscn` inherits the Shop presentation in overlay mode: the same
  catalog/purchase UI without Bottom Navigation, with a safe-area X that returns to Ability
  Purchase.
- `%ContentMargin`, `%TitleLabel`, and `%BottomNavigation` stay directly authored in each owning
  screen's own scene rather than inside the shell, because Godot's `%unique_name` lookup cannot
  cross into a child instanced scene and the headless verifiers (`scripts/tools/verify_shop.gd`/
  `verify_leaderboard.gd`) reach those nodes directly.
- Does not own catalog, purchase, leaderboard, ranking, or progression logic; that stays in
  `shop_screen.gd`/`leaderboard_screen.gd`.
- Chapter Selection reuses only `DestinationScreenLayout.get_safe_area_margins()`/
  `get_title_font_size()` -- its full-bleed per-chapter layout is not a fixed-content-rect screen,
  so it does not use the shell or status panel.

Change here when:
- Changing the shared background policy, secondary-screen shade, content-rect/title-size/
  bottom-navigation math, or loading/empty/error presentation used by Shop and Leaderboard.

### Shared Gameplay UI

Files:
- `scenes/ui/gameplay_modal_shell.tscn`, `scripts/gameplay_modal_shell.gd`
- `scenes/ui/gameplay_result_shell.tscn`, `scripts/gameplay_result_shell.gd`
- `scenes/ui/level_top_hud.tscn`, `scripts/level_top_hud.gd`
- `scripts/gameplay_ui_theme.gd`
- `scripts/ui_motion.gd`, `scripts/press_scale_button.gd`
- `assets/themes/style_box_gameplay_*.tres`

Responsibility:
- UI-003's gameplay-scope equivalent of "Shared Destination-Screen UI" above. Most level controls
  keep the denser gameplay palette; Pause deliberately reuses the warm Main Menu settings-button
  role because both controls open settings/navigation UI.
- `gameplay_modal_shell.tscn` owns the shared shade, safe-area-fitted outer panel, regular/long
  title role, true-circular close action, cream content region, and action row for Pause, Leave
  Confirmation, and Ability Purchase -- each composes it and keeps only its own content and signals.
  All three use a 520x500 authored shell; owners set compact cream-panel heights (224px Pause/
  Purchase, 240px Leave Confirmation) before safe-area scaling.
- `gameplay_result_shell.tscn` owns the shared terminal shade, hero title role, action placement,
  and safe-area layout for Completion and Failure -- each keeps its own state-specific content
  (star/earned-count, body copy) without merging it into the shell.
- `level_top_hud.tscn` owns the top strip background, combo slot, timer, level label, star pill,
  and Pause button as one safe-area-aware component (the strip background and combo slot now
  grow/shift with the safe-top inset; the timer stays clear of the level label and star/pause
  cluster at any value length).
- `gameplay_ui_theme.gd` holds the ability-icon compact/regular sizes and breakpoint, modal
  safe-fit geometry, modal-title regular/long sizes, and the result-hero title role + responsive
  scale -- the gameplay-scope equivalent of `destination_screen_layout.gd`.
- Every shell exposes `apply_safe_layout(safe_margins, viewport_size)`, `open()`/`close()` (fading
  via `scripts/ui_motion.gd` instead of snapping `visible`), and `is_transitioning()` so
  `scripts/level.gd`'s button handlers and `ui_cancel` chain never double-navigate mid-fade.
- Does not own puzzle rules, ability effects, economy, or progression logic; that stays in
  `scripts/level.gd` and `PlayerProgress`.

Change here when:
- Changing the shared gameplay shade, modal/result panel geometry, HUD icon-button/badge/pill
  roles, or the top HUD's safe-area/responsive math.

### Leaderboards

Files:
- `scenes/leaderboard_verification.tscn`
- `scenes/ui/leaderboard_rank_reward.tscn`
- `scenes/ui/leaderboard_screen.tscn`
- `scenes/ui/leaderboard_row.tscn`
- `scenes/ui/main_menu_bottom_navigation.tscn`
- `scripts/leaderboard_rank_reward.gd`
- `scripts/leaderboard_screen.gd`
- `scripts/leaderboard_row.gd`
- `scripts/tools/verify_leaderboard.gd`
- `scripts/leaderboards/leaderboard_provider.gd`
- `scripts/leaderboards/mock_leaderboard_provider.gd`
- `scripts/leaderboards/backend_leaderboard_provider.gd`
- `scripts/leaderboards/backend_leaderboard_cache.gd`
- `scripts/leaderboards/leaderboard_service.gd`
- `scripts/backend/backend_transport.gd`
- `scripts/backend/backend_read_operations.gd`
- `scripts/player_progress.gd`
- `docs/LEADERBOARDS.md`

Responsibility:
- Opens a dedicated responsive leaderboard screen from the production menu trophy tab and returns through Home.
- Presents Weekly, Country, and World scopes above a large scrollable ranking list.
- Shows rank, saved avatar, display name, and earned-star score for each entry.
- Pins the local player's highlighted entry above the bottom navigation when it falls outside the fetched top 50.
- Uses a provider selected by `application/config/leaderboard_provider` (`mock` default, or `backend`) while preserving a provider boundary for later backend integration.
- Uses Monday 00:00 UTC through the following Monday as the mock weekly scoring period; Country and World use lifetime stars.
- GAME-009: `backend` sources Weekly/Country/World pages from the authenticated backend development leaderboard (`GET /v1/leaderboards/{scope}`, via the shared `BackendTransport`/`BackendReadOperations` from GAME-007) through `scripts/leaderboards/backend_leaderboard_provider.gd`, passing entries/rank/score/tie order through unchanged and never inferring country locally for the no-country response. `scripts/leaderboards/backend_leaderboard_cache.gd` persists the last successful page per scope to `user://leaderboard_backend_cache.json` so an unavailable, unauthorized, expired-cursor, or malformed later read falls back to an offline cached view instead of failing outright.
- Uses the "Shared Destination-Screen UI" system above for its background, content-rect/title
  sizing, bottom-navigation placement, and loading/empty/error presentation; the title now reads
  the same 48/40 regular/compact size as Shop instead of its own previous 44/36.
- Retapping the already-active Leaderboard bottom-navigation tab is a no-op; `ui_cancel` always
  returns to Main Menu; the screen fades in on `_ready()` (UI-002, see `docs/SCENES.md`'s "Shared
  Interaction Roles").

Change here when:
- Replacing mock data, adding backend requests or pagination, changing leaderboard scopes, or changing ranking-row presentation.
- Changing the backend leaderboard read (GAME-009): update `scripts/leaderboards/backend_leaderboard_provider.gd`/`backend_leaderboard_cache.gd` and their tests if the backend response shape or cursor semantics change.

### Shop

Files:
- `scenes/ui/shop_screen.tscn`
- `scenes/ui/shop_bundle_card.tscn`
- `scenes/ui/shop_coin_offer_row.tscn`
- `scenes/ui/coin_balance_widget.tscn`
- `scenes/ui/shop_purchase_dialog.tscn`
- `scripts/shop_*.gd`
- `scripts/coin_balance_widget.gd`
- `scripts/store/*.gd`
- `configs/shop_catalog.json`
- `configs/backend/shop_catalog_prices.json`
- `scripts/backend/backend_transport.gd`
- `scripts/backend/backend_read_operations.gd`
- `scripts/player_progress.gd`

Responsibility:
- Opens a dedicated responsive Shop destination from every shared bottom navigation bar.
- Shows configured ability-and-coin bundles before compact coin purchase offers in one vertical scroll view.
- Uses `StoreService` and a provider boundary so UI code never owns regional pricing or transaction behavior.
- Uses the `mock` provider and configurable mock storefront country during development; real Google Play and App Store providers can replace it later.
- Applies mock purchase rewards atomically through `PlayerProgress.apply_shop_purchase()`, retains
  processed transaction ids so callbacks are idempotent, and persists offer ids so local/mock
  lifetime offers disappear after their first account purchase.
- GAME-008: `application/config/shop_catalog_source` independently selects where the *offer list* comes from. `local` (default) reads `configs/shop_catalog.json` unchanged. `backend` sources eligibility, rewards, and product IDs from the authenticated backend development catalog (`GET /v1/catalog`, via the shared `BackendTransport`/`BackendReadOperations` from GAME-007) through `scripts/store/backend_catalog_source.gd`, joins each eligible offer to `configs/backend/shop_catalog_prices.json` by `platform_product_id` for its display title and mock regional price, and still prices/purchases through the local `mock` provider. `scripts/store/backend_catalog_cache.gd` persists the last successful backend catalog to `user://shop_catalog_backend_cache.json` so an unavailable, unauthorized, or malformed later read falls back to an offline cached view instead of failing outright.
- Uses the "Shared Destination-Screen UI" system above for its background, content-rect/title
  sizing, bottom-navigation placement, and loading/error presentation; bundle/coin-offer purchase
  buttons use the shared glossy "regular" green style; the Chapter cover CTA shares their 58 px
  height but uses its own flat green active-state treatment.
- Retapping the already-active Shop bottom-navigation tab is a no-op; `ui_cancel` closes an open
  purchase-result dialog first, otherwise returns to Main Menu; the screen and dialog fade rather
  than snap (UI-002, see `docs/SCENES.md`'s "Shared Interaction Roles").

Change here when:
- Adding offers, changing bundle presentation, integrating a real platform store, or moving purchase grants to a verified backend.
- Changing the backend development catalog join (GAME-008): update `configs/backend/shop_catalog_prices.json` to match the sibling backend's `contracts/configuration/v1/local-development-shop-catalog.json` seed content.

### Level Runtime

Files:
- `level.tscn`
- `scenes/shelf.tscn`
- `scenes/moving_shelf_row.tscn`
- `scenes/layouts/layout_*.tscn`
- `scenes/ui/level_top_hud.tscn`, `scenes/ui/gameplay_modal_shell.tscn`, `scenes/ui/gameplay_result_shell.tscn`
- `scenes/pause_menu.tscn`
- `scenes/leave_confirmation_menu.tscn`
- `scenes/ui/level_failure_screen.tscn`
- `assets/ui/*.png`
- Settings icon assets use square textures with warm rectangular tile art, and the main-menu and pause-menu settings buttons are square to avoid clipping or stretching.
- `scripts/level.gd`
- `scripts/level_top_hud.gd`, `scripts/gameplay_modal_shell.gd`, `scripts/gameplay_result_shell.gd`, `scripts/gameplay_ui_theme.gd`
- `scripts/moving_shelf_row.gd`
- `scripts/shelf_layout_row.gd`
- `assets/audio/*.wav`
- `configs/levels/level_*.json`
- `configs/item_sprites.json`
- `scenes/abilities/hammer_impact_effect.tscn`
- `scripts/hammer_impact_effect.gd`
- `scenes/effects/level_completion_confetti.tscn`
- `scripts/level_completion_confetti.gd`
- `assets/abilities/ability_hammer_swing_*.png`
- `assets/abilities/ability_shuffle_box.png`

Responsibility:
- Loads level JSON and item sprite config.
- Applies responsive layout by delegating to each component's own
  `apply_safe_layout(safe_margins, viewport_size)` (UI-003): the top HUD
  (`scenes/ui/level_top_hud.tscn`), the ability bar over the floor/baseboard transition strip,
  Pause/Leave Confirmation/Ability Purchase (each composing `scenes/ui/gameplay_modal_shell.tscn`),
  Completion/Failure (each composing `scenes/ui/gameplay_result_shell.tscn`), and the scaled/
  centered shelf root. `scripts/level.gd` no longer owns fixed panel sizes or reaches into overlay
  children by path -- see "Shared Gameplay UI" below.
- Instantiates `scenes/shelf.tscn` for each configured shelf and places shelf cells from `scenes/layouts/layout_*.tscn` preset templates.
- Builds optional `row_layouts` or template-authored moving rows, including moving rows that clip and wrap more shelves than are visible at once.
- Spawns `ShelfItem` instances from config layers.
- Handles mouse and touch interaction.
- Resolves matches of three identical visible items on the same shelf, including the gather-and-shrink clear animation.
- Shows and expires the active combo count and shrinking green time strip in the top HUD's combo slot when triple clears happen within the configured combo window.
- Shows the current run's star total in the top HUD's star pill (a true pill, UI-003) with a small `assets/ui/reward_star_34_glossy_b.png` icon; triple clears add stars equal to the combo value reached by each clear and play the same compact stars as they drop from the cleared triple, fly into the counter, and pulse it.
- Shows short praise words near the clear location for 2x+ combos, with unique wording through 20x and stronger colored outlines as the combo rises.
- Starts the layered Paper A `UI/CompletionConfetti` effect immediately, keeps the cleared board
  exposed for `COMPLETION_REVEAL_SECONDS` (1.35s), then opens the reward overlay while foreground
  curls continue falling. Progress commits at clear time; Back during the lead-in skips the wait.
- Shows the completed-level reward overlay through `UI/CompletionScreen`, with a title pop, reward
  star overshoot, earned-count bounce, rising `Continue` action, and small tinted paper-star glints.
- Shows a working failure exit through the `UI/FailureScreen` instance of `scenes/ui/level_failure_screen.tscn` (new, UI-003 P0 -- Failure was previously a dead-end embedded label with no action), composing the same shared result shell as Completion.
- Sends completed campaign stars to `PlayerProgress`; Completion's `Continue` and Failure's `Main Menu` both return to the main menu, where one reward star per earned star flies from the house to the reward chest and advances its visible count.
- Uses `scripts/press_scale_button.gd` on every gameplay action (Pause, all four ability buttons, every modal close button, and both result screens' actions -- UI-003 extended this to controls that previously had no press feedback at all).
- Tracks cleared triples and unlocks shelves whose configs require progress before becoming accessible, pulsing the remaining count on decrease and playing a one-shot fade/scale on unlock (UI-003 P3) without delaying the shelf's actual input availability.
- Plays item placement and triple-clear sound effects.
- Keeps non-clearing items interactive while match animations run, resolves different shelves concurrently, and queues only repeated work for a shelf that is already resolving.
- Promotes back layers as soon as their own visible shelf layer clears, without waiting for match or reward animations on other shelves.
- Tracks the countdown timer, starting it only after the first meaningful player action, and win/loss overlays.
- Plays the hammer ability by gathering the targeted items into one center-screen item, striking it with the fullscreen hammer, then dropping combo reward stars from the impact point.
- Plays the shuffle ability by showing a center-screen delivery box, flying visible unlocked items into it, swapping item identities while hidden, flying them back to their slots, then resolving shelf matches.
- Wires the in-level pause menu, including the shared circular Pause button (`scenes/ui/level_top_hud.tscn`), modal overlay, Leave action, Continue action, leave confirmation overlay, and campaign life spend for confirmed Leave. Implements the `ui_cancel` back stack (Leave Confirmation -> Pause -> resume; Ability Purchase restores its prior state; Completion/Failure invoke their routes; otherwise opens Pause) -- there was no back-button handling at all during gameplay before UI-003.
- Displays a responsive Godot-authored level backdrop with a top HUD strip (now owned by `scenes/ui/level_top_hud.tscn`), monotone shop wall, baseboard, and bottom floor band behind generated shelves.

Change here when:
- Editing puzzle rules, input behavior, runtime shelf construction, procedural level background styling, level timing, completion conditions, or ability behavior.
- Changing the shared gameplay HUD/modal/result shell system: see "Shared Gameplay UI" below.

### Moving Shelf Rows

Files:
- `scenes/moving_shelf_row.tscn`
- `scenes/layouts/layout_*.tscn`
- `scripts/moving_shelf_row.gd`
- `scripts/shelf_layout_row.gd`
- `scripts/level.gd`
- `configs/levels/level_*.json`

Responsibility:
- Clips a shelf row to a configured visible window.
- Moves shelves horizontally or vertically at runtime and wraps them back through the opposite side.
- Keeps each level to one moving-shelf axis: horizontal or vertical.
- Lets layout templates author moving-row center positions and metadata.
- Lets `scripts/level.gd` decide drag/drop eligibility based on whether a moving shelf is currently inside the row window.
- Supports the floor-only shelf visual variant by runtime node hiding in `scripts/level.gd`.

Change here when:
- Adding row motion types, changing wrap timing, changing moving-row drag/drop targeting, or changing moving-row visual variants.

### Shelf Cell

Files:
- `scenes/shelf.tscn`
- `scripts/shelf.gd`

Responsibility:
- Defines the reusable shelf cell visuals, front slots, and item snap markers.
- Owns generated back-layer slot layout and preview styling defaults.
- Contains the visible back wall, opaque non-compounding interior/cast shadows, wood floor, frame, floor lip, floor grain nodes, and hidden top edge details shown by `scripts/level.gd` for shelves with no stacked neighbor above. Shelf cast shadows draw below generated back-layer item previews and remain enabled for full shelves so neighboring shelf bodies and items cover them.
- Contains the hidden lock overlay used by triple-gated shelves; `scripts/level.gd` toggles it, fits the remaining count onto the lock center panel, pulses that count on a decrease, and plays a one-shot fade/scale when the shelf unlocks (UI-003 P3) without delaying the shelf's actual input availability.
- Keeps the shelf width, height, and slot positions aligned with the level grid constants so a three-shelf row fills most of the gameplay viewport.

Change here when:
- Editing shelf visual details, back-layer preview presentation, locked shelf overlay visuals, front slot positions, item snap marker positions, or cell art node names.

### Item Runtime

Files:
- `scenes/item.tscn`
- `scripts/item.gd`
- `assets/items/*.png`
- `docs/ITEM_ASSET_REQUIREMENTS.md`

Responsibility:
- Represents one sortable item as an `Area2D`.
- Stores `item_id`.
- Applies texture and visual scale to its `Sprite2D` and to an equally sized translucent shadow drawn inside the item's own alpha silhouette. The shadow is disabled for generated back-layer item previews and blends from a nearby up-right resting offset to a farther down-right carried offset while preserving the item's size.
- Draws reusable alpha-based sprite outlines for item highlight states.
- Defines the canonical texture size, visible bounds, shelf baseline, alpha, naming, import, and
  validation requirements for item art.

Change here when:
- Adjusting item hitboxes, sprite scale behavior, item identity storage, outline rendering, or common item visuals.

### Ability Bar

Files:
- `level.tscn`
- `scenes/ui/ability_bar.tscn`, `scripts/ability_bar.gd`
- `scripts/level.gd`
- `scripts/gameplay_ui_theme.gd`
- `scripts/player_progress.gd`
- `scenes/ability_purchase_menu.tscn`
- `scripts/ability_purchase_menu.gd`
- `configs/ability_purchase_prices.json`
- `scenes/abilities/hammer_impact_effect.tscn`
- `scripts/hammer_impact_effect.gd`
- `assets/abilities/*.png`

Responsibility:
- Provides hammer, shuffle, highlight, and Freezer buttons using the circular ability icon-button
  role (compact 82px/regular 96px, with an explicit disabled style); all four are icon-only with a
  tooltip, use `press_scale_button.gd` (0.97), and rescale
  their icon/badge children proportionally to the actual button size instead of overflowing a
  compact button.
- Reads campaign ability uses from `PlayerProgress`, spends campaign uses immediately, and uses temporary three-use counts for isolated dev/test levels.
- Lets hammer clear matching visible/front items first, or supplement visible/front items with first-back-layer copies of the same type if no visible item type can make a triple.
- Gathers hammer targets to the center of the screen, spawns a fullscreen hammer strike effect there, swaps through four pseudo-3D hammer angle textures in the scene-authored `AnimationPlayer`, and waits for the `impact` callback before destroying the merged item and dropping combo reward stars.
- Shows the shuffle delivery box sprite from `assets/abilities/ability_shuffle_box.png` and pauses moving shelf rows while shuffle items fly through the center-screen box.
- Disables abilities after failure, completion, pause, or active ability animations. A zero-use ability button stays pressable during gameplay so `scenes/ability_purchase_menu.tscn` can offer a paid immediate use, presented as "USE ABILITY" (UI-003, not an inventory acquisition) with the canonical clover coin art and a genuine unavailable style (not alpha dimming) when unaffordable.
- Loads per-ability paid-use prices from `configs/ability_purchase_prices.json`, spends coins through `PlayerProgress.spend_coins()`, and applies the selected paid ability immediately without adding saved inventory.
- Starts the highlight timer even when no current shelf state can be highlighted.
- Uses `ShelfItem` outline state for border-only highlight ability visuals.
- Shows the active highlight countdown in a bottom-right badge on the highlight button.

Change here when:
- Adding, removing, rebalancing, or restyling player abilities.
- Changing the shared HUD icon-button/badge roles: see "Shared Gameplay UI" below.

### Pause Menu

Files:
- `level.tscn`
- `scenes/ui/gameplay_modal_shell.tscn`, `scripts/gameplay_modal_shell.gd`
- `scenes/pause_menu.tscn`, `scripts/pause_menu.gd`
- `scenes/leave_confirmation_menu.tscn`, `scripts/leave_confirmation_menu.gd`
- `scenes/ability_purchase_menu.tscn`, `scripts/ability_purchase_menu.gd`
- `assets/ui/*.png`
- Settings icon assets use square textures with warm rectangular tile art, and the pause/settings buttons are square to avoid clipping or stretching.
- `scripts/press_scale_button.gd`
- `scripts/gameplay_ui_theme.gd`
- `scripts/level.gd`

Responsibility:
- `level.tscn` provides the top HUD's 72x64 warm Pause/settings-role button (`scenes/ui/level_top_hud.tscn`) and instances the pause menu scene.
- `scenes/pause_menu.tscn`, `scenes/leave_confirmation_menu.tscn`, and `scenes/ability_purchase_menu.tscn` each compose `scenes/ui/gameplay_modal_shell.tscn` for the shared shade, warm outer panel, cream inner content region, title, protruding true-circular red close button, and bottom action row (UI-003) instead of each owning local copies of that styling. Each keeps only its own content and action buttons:
  - Pause: `Pause` title, music / sound-effects / vibration square icon buttons with shadow-only button styling and a scene-authored crossed-out marker, and Leave/Continue actions.
  - Leave Confirmation: `Leaving the Level` title (the long-title role), crossed-out rectangular lost life/star slots, and red Leave / green Continue actions. Close/system-back returns to Pause; the explicit Continue action resumes gameplay directly -- these used to collapse into the same outcome.
  - Ability Purchase: `Use Ability` title, selected ability icon without a redundant secondary badge, a coin-price button using the canonical clover coin art, and the rewarded-ad placeholder hidden in production (visible-but-disabled with `Coming Soon` copy in a debug build only).
- All three modal owners use the same 520x500 outer shell and compact content-specific cream-panel
  heights, preventing taller inner panels from returning when one modal's content changes.
- `scripts/press_scale_button.gd` provides the default held-press shrink behavior for every gameplay action, including the pause/settings icon buttons, all four ability buttons, every modal's close button, and the red/green bottom image buttons -- several of these had no press feedback at all before UI-003.
- `scripts/pause_menu.gd` toggles crossed-out visuals on the three settings icon buttons (located by name, working for both this scene's shell-composed layout and the Main Menu settings popup's own unrelated layout), keeps their saved disabled states synchronized between the main-menu settings popup and in-level pause menu, and emits setting state changes.
- `scripts/level.gd` opens and closes the menu, pauses the timer and gameplay input, and implements
  the `ui_cancel` back stack (in-level Shop returns to Ability Purchase; Leave Confirmation returns
  to Pause; Ability Purchase restores the state it opened from; Pause resumes) by listening to each
  overlay's signals instead of reaching into their buttons by child path. An unaffordable Ability
  Purchase action opens the inherited Shop overlay without spending coins or applying the ability.
  The script also writes the current run star count into the leave confirmation, initializes
  gameplay sound effects from the shared setting, and mutes them when the sound-effects button is
  crossed out.

Change here when:
- Restyling the in-level pause popup, adding pause menu actions, or changing pause/resume behavior.
- Changing the shared modal shell itself: see "Shared Gameplay UI" below.

### Level Data And Tooling

Files:
- `configs/chapters.json`
- `configs/item_progression.json`
- `configs/level_templates/level_*.json`
- `configs/levels/level_*.json`
- `scenes/layouts/layout_*.tscn`
- `scripts/tools/generate_level_shelves.py`
- `scripts/tools/level_item_progression.py`
- `scripts/tools/materialize_level_templates.py`
- `scripts/tools/validate_level_solvable.py`

Responsibility:
- Stores ordered chapter/global-level membership and chapter presentation/unlock metadata.
- Stores exclusive per-chapter item unlock milestones.
- Stores abstract level number, time limit, layout preset, and logical shelf layers.
- Materializes abstract item identities into concrete runtime item IDs using each level's available pool.
- Stores named layout preset positions in Godot scene templates.
- Supports optional row layout configs for static and moving shelf rows.
- Supports the `grid_3x3_moving_5_bottom` preset for a 3x3 static grid plus a five-shelf moving bottom row.
- Supports optional per-shelf triple-clear unlock requirements.
- Generates shelf configs from difficulty, logical-item-count, shelf, and layer settings.
- Validates shelf shape, known item IDs, row layout shape, item counts, and bounded solvability.

Change here when:
- Creating levels, adjusting level schema, adding layout presets, or improving validation/generation rules.

## Common Change Guide

Add a new item type:
- Add the item image under `assets/items/`.
- Follow `docs/ITEM_ASSET_REQUIREMENTS.md`.
- Name variants family-first, such as `item_soda_can_lime.png`.
- Add an entry to `configs/item_sprites.json`.
- Schedule the item exactly once in `configs/item_progression.json`.
- Rematerialize runtime levels if the item should affect an existing milestone.

Add a new level:
- Generate `configs/level_templates/level_011.json` or the next numbered template.
- Add its global ID to the owning chapter's `level_ids` in `configs/chapters.json`.
- Run `scripts/tools/materialize_level_templates.py` to create the runtime level.
- Validate the level with `scripts/tools/validate_level_solvable.py`.

Change shelf layout spacing:
- Update `SHELF_CELL_VISUAL_SCALE`, `SHELF_BASE_CELL_SIZE`, `SHELF_SHARED_EDGE_THICKNESS`, and `SHELF_GRID_STEP` in `scripts/level.gd`.
- Reposition shelf markers in the relevant `scenes/layouts/layout_*.tscn` templates.
- Keep `scenes/shelf.tscn` cell bounds and boundary thickness aligned with those layout constants.
- Keep `scripts/moving_shelf_row.gd` row sizing and runtime configuration aligned with `SHELF_CELL_SIZE` and `SHELF_GRID_STEP`.
- Keep `SLOT_ITEM_POSITION`, shelf slot markers, `scenes/item.tscn` default scale, shelf instance scaling, and `item_pick_size` aligned when shelf width changes affect item spacing.
- Keep `scripts/tools/generate_level_shelves.py` layout presets in sync if preset names or supported shapes change.
- Fixed staggered preset positions live in `scenes/layouts/`; keep their required shelf counts documented in `docs/CONFIGS.md`.

Change matching rules:
- Update `_clear_matching_shelves()`, `_resolve_shelves()`, and related validation logic if the data rules also change.
- Update `scripts/tools/validate_level_solvable.py` so generated or validated levels match runtime behavior.

Change shelf unlock rules:
- Update `scripts/level.gd` shelf lock helpers, ability item collection, and match/promotion filters.
- Update `scenes/shelf.tscn` when changing the locked shelf overlay art, placement, or count label.
- Keep the unlock/count-pulse feedback animation (`_update_shelf_lock_overlay()`,
  `_play_shelf_unlock_animation()`, `_pulse_lock_remaining_label()`) from delaying
  `_update_shelf_input_pickable()`'s immediate effect if you change this further.
- Update `scripts/tools/validate_level_solvable.py` when unlock timing or counting semantics change.
- Keep `docs/CONFIGS.md` and generator `--locked-shelves` behavior aligned with the level JSON field.

Change drag or tap movement:
- Update `_input()`, `_handle_press_at()`, `_handle_motion_at()`, `_handle_release_at()`, `_move_item_to_slot()`, `_resolve_move_target_slot()`, and slot lookup helpers in `scripts/level.gd`.
- Keep occupied-slot fallback behavior in sync with `_resolve_move_target_slot()` and `_find_free_slot_on_target_shelf()`, including the same-shelf return-to-origin rule.
- Keep `_is_slot_drag_drop_targetable()` aligned with moving-row visibility rules if moving rows change.

Change moving shelf rows:
- Update `scripts/moving_shelf_row.gd` for row wrapping, clipping, speed, or visible-window behavior.
- Update `scripts/level.gd` row layout helpers and floor-only visual variant node list when config semantics or shelf visuals change.
- Update `scripts/tools/validate_level_solvable.py` when row layout config validation changes.
- Keep `docs/CONFIGS.md` row-layout schema and moving-row lock restrictions aligned.

Change gameplay sound effects:
- Update `assets/audio/item_place.wav`, `assets/audio/triple_clear.wav`, and the audio player helpers in `scripts/level.gd`.
- Keep the `SoundEffectsButton` setting path in `scripts/pause_menu.gd` and `scripts/level.gd` aligned when changing pause menu sound-effect controls.

Change level win or loss flow:
- Update `_process()`, `_fail_level()`, `_complete_level()`, `_check_level_completed()`, pause-menu helpers, `level.tscn`, and `scenes/ui/level_completion_screen.tscn`.
- Keep `assets/ui/reward_star.png` aligned with both `UI/StarCounterLabel/Icon` and `scenes/ui/level_completion_screen.tscn` `StarImage`, and keep `assets/ui/level_button_blank_new.png` aligned with `NextButton` when changing completion reward art.

Change pause menu layout:
- Update `scenes/pause_menu.tscn`, `scenes/leave_confirmation_menu.tscn`, or
  `scenes/ability_purchase_menu.tscn` for their own content/action-row nodes; update
  `scenes/ui/gameplay_modal_shell.tscn` for shade/panel/title/close-button changes shared by all three.
- Update `assets/ui/*.png` when changing pause menu icon art.
- `assets/ui/pause_menu_option_a_sheet.png` and `assets/ui/pause_menu_option_b_sheet.png` are kept as alternate generated style sheets.
- `scripts/level.gd` only listens to each overlay's own signals
  (`leave_pressed`/`continue_pressed`/`close_requested`/`buy_pressed`/etc.) and calls
  `set_star_count()`/`set_offer()`/`open()`/`close()` -- it does not reach into these scenes'
  children by path, so their internal node structure can change without touching `level.gd`.

Change fonts or text hierarchy:
- Update `assets/themes/game_typography.tres` for shared font families, weights, and semantic type variations.
- Apply an existing theme type variation in the owning scene instead of attaching font files directly.
- Keep uppercase title rules and the `×` multiplier convention synchronized with dynamic strings in the owning scripts.
- Gameplay modal-title regular/long and terminal-result hero sizes live in
  `scripts/gameplay_ui_theme.gd`, not `game_typography.tres` -- see `docs/TYPOGRAPHY.md`.
- Follow `docs/TYPOGRAPHY.md` and recheck the representative mobile and tablet resolutions.

Change shared button/panel/scrollbar styling:
- Edit the relevant `assets/themes/style_box_*.tres` resource (see `docs/SCENES.md` "Shared UI
  Style Tokens") rather than a scene-local `StyleBoxFlat`/`StyleBoxTexture` copy, so every consuming
  scene updates together.
- Edit `assets/themes/game_typography.tres`'s `VScrollBar`/`HScrollBar` entries for scrollbar
  changes; it is the project's global `theme/custom`, so this affects every `ScrollContainer`.
- Keep the 16/20/24 px corner-radius roles (buttons/rows/large panels) and the green-positive
  vs. orange-utility vs. neutral-disabled action-color roles consistent with `docs/SCENES.md`.
- Gameplay-scoped roles (ability HUD icon buttons, gameplay modal shell, terminal result shell,
  badges, and the star pill) live in `assets/themes/style_box_gameplay_*.tres`; the warm Pause/
  settings role lives in `style_box_warm_icon_{normal,pressed}.tres`. See `docs/SCENES.md` "Shared
  Gameplay UI Roles" and "Shared Gameplay UI" above. Edit those instead of a scene-local copy, and
  keep the 16/20/24 geometry roles consistent there too (true-circular
  controls use a deliberately oversized `corner_radius`, which Godot clamps to a true circle at any
  size, rather than a size-specific exact value).

Change the shared destination-screen shell, status panel, or layout math:
- Update `scripts/destination_screen_shell.gd`/`scripts/destination_status_panel.gd` for the
  shared background/shade or loading/empty/error presentation, or
  `scripts/destination_screen_layout.gd` for safe-area/content-rect/title-size/bottom-navigation
  math. See "Shared Destination-Screen UI" above.
- `%ContentMargin`, `%TitleLabel`, and `%BottomNavigation` must stay directly authored in each
  owning screen's own scene, not relocated into the shell -- see that section for why.

## Related Docs

- `docs/ITEM_ASSET_REQUIREMENTS.md`: canonical item texture, alignment, import, and validation rules.
- `docs/SCENES.md`: scene and node ownership inventory.
- `docs/SCRIPTS.md`: script responsibilities, exports, and dependencies.
- `docs/CONFIGS.md`: config file schema and data contracts.
- `docs/CLOUD_SAVE.md`: platform cloud-save setup and bridge contract.
- `docs/TYPOGRAPHY.md`: global font assets, semantic theme roles, casing, numeric style, and responsive typography checks.
