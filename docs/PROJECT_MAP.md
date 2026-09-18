# Project Map

Use this file as the first stop when you need to identify where a feature lives. Keep entries short and update this map in the same commit as meaningful scene, script, or config changes.

## Entry Points

Main scene:
- `scenes/main_menu.tscn`
- Configured in `project.godot` as `run/main_scene`.
- `project.godot` keeps the 720x1280 design viewport and uses `canvas_items` stretch with `keep_width` so portrait devices share a stable logical width while gaining or losing vertical play space. The Mobile renderer uses 2x 2D MSAA to smooth runtime `Polygon2D` edges, including the dispenser shelf's short bevels, without the larger bandwidth cost of 4x sampling.
- Owns the production campaign entry point over the selected chapter's `selection_preview`,
  launches that chapter's next level, and opens the chapter picker from the action beneath the level
  button. Chapter selection updates the menu background immediately.
- Shows a separate left-side reward chest progress widget under the profile icon.

Testing menu:
- `scenes/main_menu_testing.tscn`
- Preserves the previous main menu with campaign play and developer/test level selection.
- `scenes/testing/reward_chest_fill_preview.tscn` can be run directly with F6 to replay a full
  reward-star flight into the production chest widget without changing saved progress.

Playable level scene:
- `level.tscn`
- Instantiated through the persistent `LevelTransition` autoload for production/testing menu starts
  and failed-level retries; the current completion action returns to the Main Menu.
- Owns shelf layout, timer, drag and tap movement, triple matching, abilities, pause-menu wiring, failure, and completion flow.
- Uses the original procedural gameplay background for Chapter 1 and chapter artwork for chapters
  whose catalog entry selects `artwork` mode.
- Uses one shared gameplay UI system for its HUD, ability bar, Pause/Leave Confirmation/Ability/
  Out-of-Lives/Failure modals, and the Completion terminal result (UI-003, implemented and validated --
  see `docs/UI_003_LEVEL_UI_CONSISTENCY_TICKET.md` and "Shared Gameplay UI" below).

Level loading transition:
- `scenes/ui/level_loading_screen.tscn`
- `scripts/level_loading_screen.gd`
- `scripts/level_transition.gd`
- `assets/shaders/loading_iris.gdshader`
- `assets/ui/loading/loading_cat.png`
- Registered in `project.godot` as the `LevelTransition` autoload.
- Covers production/testing menu launches and retries, blocks duplicate input, and keeps the fresh
  level frozen until its circular reveal has completed. See [LEVEL_LOADING_SCREEN.md](LEVEL_LOADING_SCREEN.md).

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

Sound effects:
- `scripts/audio/sfx_manager.gd`
- Registered in `project.godot` as the `SfxManager` autoload, after `PlayerProgress`.
- The only playback owner for shared sound effects; every screen reaches it through
  `SfxManager.play(event_id, context)`.

Reusable item scene:
- `scenes/item.tscn`
- Instantiated by `scripts/level.gd` for every shelf item.
- Displays the item sprite and exposes item identity through `ShelfItem`.
- Sticky instance state and marker live here; see `scripts/sticky_item_rules.gd`,
  `scenes/ui/sticky_item_indicator.tscn`, and [STICKY_ITEMS.md](STICKY_ITEMS.md).
- Compare the two selected art candidates in `scenes/testing/sticky_items_preview.tscn` (F6 or the
  testing menu's **Sticky items preview** button). Campaign content is unchanged.

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
- `scenes/ui/profile_avatar_view.tscn`
- `scenes/ui/profile_choice_tile.tscn`
- `scenes/ui/settings_menu.tscn`
- `scenes/ui/level_button.tscn`
- `scenes/ui/main_menu_chapter_button.tscn`
- `scenes/ui/chapter_selection_screen.tscn`
- `scenes/ui/chapter_cover_card.tscn`
- `scenes/ui/horizontal_pager.tscn`
- `scenes/ui/coin_balance_widget.tscn`
- `scenes/ui/main_menu_coin_shortcut.tscn`
- `assets/ui/pencil_icon.png`
- `assets/ui/clover_coin_transparent_96x96.png`
- `assets/ui/reward_star_84x84.png`
- `assets/ui/main_menu_lives.png`
- `assets/ui/main_menu_reward_chest.png`
- `assets/ui/reward_chest_menu_illustration.png`
- `assets/abilities/ability_hammer.png`
- `assets/abilities/ability_lantern.png`
- `assets/abilities/ability_shuffle.png`
- `assets/abilities/ice_clock_icon_256x256.png`
- `assets/ui/avatar_circle_clip.gdshader`
- `assets/ui/avatars/*.png`
- `assets/ui/avatar_frames/*.png`
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
- `scenes/ui/out_of_lives_menu.tscn`
- `scripts/out_of_lives_menu.gd`
- `scripts/main_menu_coin_shortcut.gd`
- `scripts/coin_balance_widget.gd`
- `scripts/chapters/*.gd`
- `scripts/main_menu_reward_chest.gd`
- `scripts/main_menu_reward_star_flyer.gd`
- `scripts/reward_chest_menu.gd`
- `scripts/profile_menu.gd`
- `scripts/profile_avatar_view.gd`
- `scripts/profile_choice_tile.gd`
- `scripts/profile_frame_catalog.gd`
- `scripts/main_menu.gd`
- `scripts/level_transition.gd`
- `scenes/ui/level_loading_screen.tscn`
- `scripts/player_progress.gd`

Responsibility:
- Routes all accepted level starts through the persistent loading transition before gameplay begins.
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
- Opens `scenes/ui/profile_menu.tscn` from the profile widget; its summary card previews the pending
  avatar/frame combination, its edit button reveals the player-name field, and its Avatar/Frame
  tabs share a scrollable 3-column choice grid. Save commits the name, avatar, and avatar frame as
  one authoritative public `profile_edit` through `PlayerProgress`; a frame-only change produces a
  frame-only edit.
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
- Keeps the campaign level action enabled at zero lives, shows the responsive lives modal from
  either that launch request or the top-status lives widget, and buys one offline-capable life for
  the configured 500-coin default; only the launch request resumes into the level afterwards.
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

### UI Visual Capture

Files:
- `scripts/tools/capture_ui.ps1`
- `scripts/tools/capture_scene.gd`
- `scripts/tools/captures/*_setup.gd` (per-scene runtime state, such as
  `shelf_lock_overlay_setup.gd` and the `lives_menu_full_setup.gd`/`lives_menu_offer_setup.gd` pair
  that opens each lives-modal state over the real Main Menu)
- `tmp/.gdignore`

Responsibility:
- Renders any scene at the responsive resolutions from AGENTS.md and writes one PNG per resolution to
  `tmp/ui_capture/`, plus an ImageMagick contact sheet for a single review pass.
- Keeps all generated assets, review captures, and scratch output under `tmp/` local-only. The root
  `.gdignore` prevents Godot from importing or exporting this directory, while `.gitignore` excludes
  its contents except for the marker itself.
- Runs through the isolated test project with `run_isolated_godot_test.ps1 -Windowed`, because a
  headless display server resolves the viewport texture to null and produces no image.
- Reports results through `<name>_manifest.json` rather than stdout, since the windowed Godot binary
  on Windows is a GUI executable whose prints never reach the calling shell. The runner redirects
  engine output to the console for windowed runs so script parse errors stay visible.
- Measures each capture from the saved image, so a window clamped by the desktop or a render target
  letterboxed by the project's stretch aspect is reported instead of being passed off as the
  requested resolution.
- Prepares scenes that render nothing on their own through a setup script in `scripts/tools/captures/`
  exposing `setup(scene_root: Node, tree: SceneTree) -> void`.

Change here when:
- Adding a capture setup script for a scene that needs runtime state, changing the reviewed
  resolution set, or changing how capture artifacts are named or stored.

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
  Confirmation, Ability Purchase, Out of Lives, and Failure -- each composes it and keeps only its
  own content and signals. Standard owners use a 520x500 authored shell with compact cream-panel
  heights; Failure uses the same shell resources in a taller 520x620 composition for its heart art.
- `gameplay_result_shell.tscn` owns Completion's terminal shade, hero title role, action placement,
  and safe-area layout. Failure now uses the centered gameplay modal shell.
- `level_top_hud.tscn` owns the top strip background, combo slot, timer, level label, star pill,
  and Pause button as one safe-area-aware component (the strip background and combo slot now
  grow/shift with the safe-top inset; the timer stays clear of the level label and star/pause
  cluster at any value length). It also owns the final-30-seconds timer warning: a responsive red
  badge stays behind the digits while the label pulses once per displayed decrement; the visual
  resets at run boundaries and suppresses pulse motion while Freezer holds the countdown.
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
- `assets/audio/<event>/*.{wav,mp3}`
- `configs/levels/level_*.json`
- `configs/item_sprites.json`
- `scenes/abilities/hammer_impact_effect.tscn`
- `scripts/hammer_impact_effect.gd`
- `scenes/abilities/lantern_screen_effect.tscn`
- `scripts/lantern_screen_effect.gd`
- `scenes/abilities/freezer_screen_effect.tscn`
- `scripts/freezer_screen_effect.gd`
- `scenes/abilities/freezer_snowflake_field.tscn`
- `scripts/freezer_snowflake_field.gd`
- `scenes/effects/level_completion_confetti.tscn`
- `scripts/level_completion_confetti.gd`
- `assets/abilities/ability_hammer_swing_1.png` through `ability_hammer_swing_7.png`, including
  fractional transition frames `1.3`, `1.7`, `5.3`, and `5.7` (playback order)
- `assets/abilities/ability_shuffle_box.png`
- `assets/abilities/lantern_searchlight.gdshader`
- `assets/abilities/freezer_edge_glow.gdshader`

Responsibility:
- Loads level JSON and item sprite config.
- Applies responsive layout by delegating to each component's own
  `apply_safe_layout(safe_margins, viewport_size)` (UI-003): the top HUD
  (`scenes/ui/level_top_hud.tscn`), the ability bar over the floor/baseboard transition strip,
  Pause/Leave Confirmation/Ability Purchase/Out of Lives/Failure (each composing
  `scenes/ui/gameplay_modal_shell.tscn`), Completion (composing
  `scenes/ui/gameplay_result_shell.tscn`), and the scaled/
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
- Shows `UI/FailureScreen` as a centered modal with `LEVEL N`, broken-heart art, `LEVEL FAILED`,
  Retry, and X. Retry recreates the same level when a life remains; at zero lives it opens the
  reusable `UI/OutOfLivesOverlay`. A successful life purchase restarts, while decline or purchase
  failure returns to the originating main menu.
- Sends completed campaign stars to `PlayerProgress`; Completion's `Continue` and Failure's X both
  return to the main menu, where one reward star per earned star flies from the house to the reward
  chest and advances its visible count.
- Uses `scripts/press_scale_button.gd` on every gameplay action (Pause, all four ability buttons, every modal close button, and both result screens' actions -- UI-003 extended this to controls that previously had no press feedback at all).
- Tracks cleared triples and unlocks shelves whose configs require progress before becoming
  accessible. It passes remaining counts/state to `ShelfLockOverlay`; that component pops the badge,
  tensions the chain arms, swings the hanging lock, and releases the arms without delaying actual input
  availability. Hammer-cleared triples continue through the same `_record_triples_cleared()` path.
- Plays item placement and triple-clear sound effects.
- Keeps non-clearing items interactive while match animations run, resolves different shelves concurrently, and queues only repeated work for a shelf that is already resolving.
- Promotes back layers as soon as their own visible shelf layer clears, without waiting for match or reward animations on other shelves.
- Tracks the countdown timer, starting it only after the first meaningful player action, and win/loss overlays.
- On the first eligible `00:00`, freezes the board and plays `UI/TimeUpTransition`: a short HUD
  timer snap/shake, expanding red alarm ring, and dark-red shade synchronized to
  `assets/audio/time_up/times_up2.mp3`. It then hands the shade to the popped-in
  `UI/TimeUpExtensionOverlay`; later ineligible expiries still fail immediately.
- Plays the hammer ability by gathering the targeted items into one center-screen item, starting the
  Hammer cue on the fullscreen strike's impact signal, then dropping combo reward stars from the
  impact point.
- Plays the shuffle ability by showing a center-screen delivery box, starting the Shuffle cue as
  visible unlocked items begin flying into it, swapping item identities while hidden, flying them
  back to their slots, then resolving shelf matches.
- Shows Lantern as Focus Mode on canvas layer 4: a 30% warm shade over non-target gameplay, bright
  pulsing pools tracked to every highlighted item, and a stronger button-origin activation wave for
  the same 15-second window as the item outlines. With no current targets, a diagonal beam visibly
  keeps searching the shelves.
- Shows Freezer as a large blue perimeter glow with a concentrated bright near-edge rim and dense
  procedural snowflakes drifting inward from all four edges at 28-52 design pixels per second and
  disappearing within 1.6-2.4 seconds. The main pass sits between gameplay and
  UI, while a clipped glow and synchronized flake copy render over `TopHud`, all without recoloring
  the configured level background. The effect stops emission and fades when the 30-second active-
  gameplay window ends. While gameplay modals pause the level, the upper copy mirrors the shared
  modal-shade fade so its brightness continues matching the shaded main pass.
- Wires the in-level pause and retry recovery modals. Implements the `ui_cancel` back stack (retry
  Out of Lives -> main menu; Leave Confirmation -> Pause -> resume; Ability Purchase restores its
  prior state; Completion/Failure invoke their routes; otherwise opens Pause).
- Displays a responsive level backdrop with a top HUD strip (now owned by `scenes/ui/level_top_hud.tscn`), monotone shop wall, baseboard, and a generated diagonal-terracotta floor texture behind generated shelves for Chapter 1.

Change here when:
- Editing puzzle rules, input behavior, runtime shelf construction, procedural level background styling, level timing, completion conditions, or ability behavior.
- Changing the shared gameplay HUD/modal/result shell system: see "Shared Gameplay UI" below.

### Sound Effects (AUDIO-001)

Global path:
- `SfxManager` autoload (`scripts/audio/sfx_manager.gd`) -> pooled `AudioStreamPlayer`s -> the `SFX`
  audio bus -> `Master`.
- `scripts/audio/sfx_catalog.gd` maps each semantic event id to its streams, mix trim,
  volume/pitch variation, cooldown, and polyphony budget. Gameplay and UI scripts never preload an
  `AudioStream`.
- `scripts/audio/ui_click_binder.gd` (a child of the manager) binds every enabled, visible
  `BaseButton` in every scene to `ui_click` exactly once.

Bus layout:
- `assets/audio/default_bus_layout.tres`, referenced by `project.godot`'s
  `audio/buses/default_bus_layout`. `Master` plus a dedicated `SFX` bus that sends to it, so short
  gameplay/UI transients can be trimmed, muted, or metered as one group without touching `Master`
  (which future music work will share).

Assets:
- Every runtime cue lives under `assets/audio/<event>/`, using the matching semantic catalog event
  as its directory name. Variant pools share that one directory.
- `assets/audio/item_place_valid/item_place.wav` and
  `assets/audio/match_clear/triple_clear.wav` remain the project's retained source recordings.
- `assets/audio/time_up/times_up2.mp3` is the supplied authored timeout cue used by the recoverable
  Time's Up transition; the older generated `time_up.wav` remains generator-owned but is no longer
  the runtime catalog stream.
- `assets/audio/coin_gain/coin_gain.wav` is the selected authored Epidemic Sound reward cue. It is
  a stereo 96 kHz/24-bit PCM source and is not generator-owned.
- The deterministic synthesized files are mono 16-bit PCM at 44.1 kHz and imported uncompressed.
  `scripts/tools/generate_core_sfx.gd` writes them from `scripts/tools/core_sfx_synthesis.gd`, while
  `assets/audio/generated_sfx_manifest.json` records each event-relative path, encoding, duration,
  peak, and generator version.

Event owners:
- `scripts/level.gd`: `item_select`, `item_place_valid`, `match_clear`, `star_hud_arrival`,
  `timer_critical_tick` (driven by `LevelTopHud.critical_second_pulsed`), `time_up`, `coin_spend`.
- `scripts/shop_screen.gd`: `shop_purchase_success` and the layered `coin_gain` for granted coins.
- `scripts/production_main_menu.gd`: `reward_chest_star_arrival`, the goal-rollover and weekly
  leaderboard `coin_gain`, and the life-purchase `coin_spend`.
- `scripts/pause_menu.gd`: the sound-effects toggle acknowledgement.
- `scripts/audio/ui_click_binder.gd`: `ui_click` everywhere else.

Settings and muting:
- Every request re-reads `PlayerProgress.is_setting_disabled(&"sound_effects")`; disabling also stops
  what is already sounding.
- `SfxManager.set_muted()` is a separate capture/test mute. Headless runs start muted and
  `scripts/tools/capture_scene.gd` mutes explicitly, so no automated run needs an audio device.

Verification:
- `tests/audio/test_core_sfx_assets.gd`, `tests/audio/test_sfx_manager.gd`,
  `tests/audio/test_sfx_event_wiring.gd`.

### Haptics

Global path:
- `HapticsManager` autoload (`scripts/haptics/haptics_manager.gd`) -> saved vibration preference,
  priority/cooldown arbitration, cancellable pattern timing -> injected native/test provider or
  `Input.vibrate_handheld()` fallback.
- `scripts/haptics/haptics_catalog.gd` maps semantic event ids to short pulse patterns, priorities,
  cooldowns, and optional bounded count scaling.
- `export_presets.cfg` enables the Android `VIBRATE` permission.

Policy:
- Core sorting feedback covers successful selection/pickup, accepted moves, sticky resistance,
  triple clears, and shelf unlocks. Same-slot landings and ordinary rejected returns do not vibrate.
- Hammer, Shuffle, Lantern, Freezer, recoverable time-up, time extension, level results, applied
  purchases, life purchases, chest-goal rollover, and weekly rewards have distinct patterns.
- Critical timer ticks, individual stars, moving shelves, promotion, passive restoration, generic
  UI clicks, and modal/navigation changes intentionally remain silent.
- `PlayerProgress.is_setting_disabled(&"vibration")` gates every ordinary request. The vibration
  toggle owns one forced final preview when disabling; headless runs and captures can use the
  manager's independent mute.

Verification and detailed tuning:
- `tests/haptics/test_haptics_manager.gd`, `tests/audio/test_sfx_event_wiring.gd`, and
  `docs/HAPTICS.md`.

### Moving Shelf Rows

Files:
- `scenes/moving_shelf.tscn` (one shelf's independently editable art and slots)
- `scripts/moving_shelf.gd` (single-shelf presentation defaults, extending `Shelf`)
- `scenes/moving_shelf_row.tscn`
- `scenes/layouts/layout_*.tscn`
- `scripts/moving_shelf_row.gd`
- `scripts/shelf_layout_row.gd`
- `scripts/level.gd`
- `configs/levels/level_*.json`
- `tests/gameplay/test_moving_shelf_row.gd`

Responsibility:
- Instantiates each moving shelf from `scenes/moving_shelf.tscn`; static shelves continue to use
  `scenes/shelf.tscn`. Edit the single moving scene's `FloorSurface`, shade, and `FloorFrontLip` for
  unique moving-shelf artwork. Its default appearance and three-slot gameplay remain unchanged.
- Clips each belt to the full playable background along its motion axis. `scripts/level.gd` supplies
  the safe background width or playable wall height after fitting the authored board; the lane's
  cross-axis position, shelf size, and spacing stay unchanged.
- Keeps authored bounds separate from runtime clipping bounds so viewport resizing cannot shrink
  or shift the static board. Extends short wrap loops with empty travel space so shelves leave the
  background completely before reappearing on the opposite edge.
- Moves shelves horizontally or vertically on fixed ticks, interpolates them on render frames for
  smooth frame pacing, and wraps them back through the opposite side.
- Standardizes campaign moving rows at `60` design pixels per second for an even cadence on common
  60 Hz mobile displays.
- Keeps moving shelf bodies visually independent by reducing their rendered width by `15` design
  pixels and aligning the floor lip to the floor surface without compressing item art, slot
  positions, or hit areas.
- Antialiases moving shelf polygons so subpixel positions do not shimmer at scaled resolutions or
  refresh rates above 60 Hz.
- Keeps each level to one moving-shelf axis: horizontal or vertical.
- Lets layout templates author moving-row center positions and metadata.
- Lets `scripts/level.gd` pick the visible part of an item even after its moving shelf's center
  crosses the window edge. The row exposes cell overlap and its global clip rectangle; the level
  clips item hit areas and requires visible slot markers for drops and occupied-slot fallback.
- Supports the floor-only shelf visual variant by runtime node hiding in `scripts/level.gd`.

Change here when:
- Adding row motion types, changing wrap timing, changing moving-row drag/drop targeting, or changing moving-row visual variants.

### Shelf Cell

Files:
- `scenes/shelf.tscn`
- `scripts/shelf.gd`
- `assets/shelves/standard_shelf_light_oak.png`
- `scripts/tools/captures/standard_shelf_setup.gd`
- `tests/gameplay/test_standard_shelf_wood_texture.gd`
- `scenes/ui/shelf_lock_overlay.tscn`

Responsibility:
- Defines the reusable *standard* shelf cell visuals, front slots, and item snap markers. The narrow
  source-only variant lives in `scenes/dispenser_shelf.tscn` -- see "Dispenser Shelf" below.
- `scripts/shelf.gd` owns the shelf-type capability surface every shelf type answers.
- Owns generated back-layer slot layout and preview styling defaults.
- Contains the visible back wall, opaque non-compounding interior/cast shadows, image-textured
  light-oak floor/frame/lip, and hidden top edge details shown by `scripts/level.gd` for shelves with
  no stacked neighbor above. One shared material image is sampled horizontally for broad faces and
  with rotated UVs for vertical supports; the former line-only grain nodes remain hidden. Shelf cast
  shadows draw below generated back-layer item previews and remain enabled for full shelves so
  neighboring shelf bodies and items cover them. Shelf/shelf intersections keep one consistent
  tone, while later item contact shadows alpha-blend over shelf shadows and darken that overlap.
- Instances the reusable hidden lock overlay used by triple-gated shelves; the shelf owns only its
  placement, while `ShelfLockOverlay` owns chains, lock, badge, labels, and motion.
- Keeps the shelf width and slot positions aligned with the level grid constants so a three-shelf
  row fills most of the gameplay viewport. The standard frame's floor-anchored interior is 10%
  taller than its original 97 px opening; the cell footprint remains unchanged, while runtime row
  packing adds the scaled 10.282 px extension between rows so every opening stays visible.

Change here when:
- Editing shelf visual details, back-layer preview presentation, lock-overlay placement, front slot
  positions, item snap marker positions, or cell art node names. Edit the extracted component below
  for the lock overlay's internal visuals or motion.

### Locked Shelf Overlay

Files:
- `scenes/ui/shelf_lock_overlay.tscn`
- `scripts/shelf_lock_overlay.gd`
- `assets/ui/shelf_lock_chain_arm_a.png` (legacy path, selected C2-7A art)
- `assets/ui/lock_shelf_cutout.png`
- `tests/ui/test_shelf_lock_overlay.gd`

Responsibility:
- Reusable standard/compact visual component for every triple-gated shelf.
- Fits four instances of the selected seven-link C2-7A chain between slightly varied wall anchors
  and lock-shackle anchors. Its links alternate crosswise/front-facing and its baked shallow sag
  keeps each arm from reading as a rigid line. Overlay-owned wall covers hide the terminal links;
  the bottom arms draw behind the orange `AD` lock, the top arms draw in front, and every arm stays
  behind the shared gameplay count badge.
- On a recorded triple clear, pops the count, keeps every wall endpoint fixed while pulling the
  shackle endpoints inward, and swings the lock. On zero, collapses/fades each arm into its wall and
  drops/fades the lock while the level enables the shelf immediately.
- Replaces interrupted feedback tweens and restores authored transforms after both normal and rapid
  state changes.
- Uses a compact layout when instanced by `scenes/dispenser_shelf.tscn`.

Change here when:
- Editing wall/shackle endpoints, wall-cover depth/color, chain/lock/badge art, `AD` styling, shared
  count fitting, decrement tension/swing timing, final chain release motion, or compact proportions.

### Dispenser Shelf

Files:
- `scenes/dispenser_shelf.tscn`, `scripts/dispenser_shelf.gd`
- `assets/shelves/standard_shelf_light_oak.png`
- `scenes/shelf_layer_indicator.tscn`, `scripts/shelf_layer_indicator.gd`
- `scripts/shelf.gd`
- `scripts/level.gd`
- `scripts/tools/validate_level_solvable.py`, `scripts/tools/generate_level_shelves.py`
- `tests/gameplay/test_dispenser_shelf.gd`, `tests/tools/test_validate_level_solvable.py`

Responsibility:
- A second shelf type: a narrow one-slot open wooden cradle holding 2-4 stacked layers that the
  player can take from but never place onto. Its circular badge reuses the ability count style, and
  its thin-outlined segmented stock rail shows both remaining items and total capacity at a glance.
- Shares the standard shelf's light-oak image across its back, floor, lip, guard faces, bevels, and
  inner returns. Each `Polygon2D` owns UVs suited to its face direction; translucent face-local
  shade overlays retain the recessed-cradle depth, while its cast and back-wall shadows use opaque
  pre-blended colors so adjacent shelves do not compound. The former line-only floor grain stays
  hidden.
- The queue is not a separate stacking system. `Shelf`'s back-layer machinery already models "one
  hidden item per layer, promoted when the front layer empties", and with a single front slot that
  is exactly a dispenser.
- `scripts/shelf.gd` exposes the shelf-type capability surface (`get_base_cell_size()`,
  `get_visual_bounds()`, `get_slot_count()`, `accepts_dropped_items()`, `forms_triples()`,
  `allows_ability_modification()`, `shows_back_layer_preview()`), so `scripts/level.gd` branches on
  what a shelf can do rather than on its class. Shelf identity is `node is Shelf`, not a slot count.
- Taking and placing are separate permissions in `scripts/level.gd`
  (`_is_slot_move_source_eligible()` vs `_is_slot_drop_target_eligible()`): a dispenser passes the
  first and fails the second.
- The remaining count is authoritative state decremented once per committed move onto another shelf,
  never derived from live nodes -- a carried item is reparented out of its slot for the length of a
  drag. See `_record_dispenser_item_taken()`.
- Hammer and shuffle skip dispensers so the authored queue survives; highlight still reads them.
- Static `row_layouts` rows pack by each cell's own width. A dispenser with another row below moves
  upward by `DISPENSER_LOWER_CLEARANCE` so its indicator clears that row; standard neighbours retain
  their authored grid positions and stay interlocked with standard shelves below. Authored
  `layout_preset` markers use the same per-dispenser offset. A shelf top cap is suppressed only by a
  horizontally overlapping shelf exactly one grid step above, so a separated dispenser does not
  hide the exposed ceiling below it. Dispensers are not supported inside moving rows, which step and
  wrap on one uniform cell width.
- The mechanic is opt-in through a level-config shelf with `"type": "dispenser"`.

Change here when:
- Adding shelf types, changing dispenser capacity/indicator presentation, changing which abilities
  may touch which shelf types, or changing mixed-width row packing.

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
- `scenes/abilities/lantern_screen_effect.tscn`
- `scripts/lantern_screen_effect.gd`
- `scenes/abilities/freezer_screen_effect.tscn`
- `scripts/freezer_screen_effect.gd`
- `scenes/abilities/freezer_snowflake_field.tscn`
- `scripts/freezer_snowflake_field.gd`
- `assets/abilities/*.png`

Responsibility:
- Provides hammer, shuffle, highlight, and Freezer buttons using the circular ability icon-button
  role (compact 98.4px/regular 115.2px, with an explicit disabled style); all four are icon-only with a
  tooltip, use `press_scale_button.gd` (0.97), and rescale
  their icon/badge children proportionally to the actual button size instead of overflowing a
  compact button.
- Uses a shared cozy, low-detail 2D illustration style for the four transparent 128px ability
  textures while giving each ability a distinct palette; the Freezer clock has a complete
  12-mark dial and four external snowflakes.
- Reads campaign ability uses from `PlayerProgress`, spends campaign uses immediately, and uses temporary three-use counts for isolated dev/test levels.
- Lets hammer clear matching visible/front items first, or supplement visible/front items with first-back-layer copies of the same type if no visible item type can make a triple.
- Gathers hammer targets to the exact viewport center, merges them into one item with a short settle
  pop, then flies the hammer from the live bottom-left Hammer ability button through the supplied
  eleven-pose strike sequence. Poses 1–3 switch quickly, pose 3 holds while the 320 ms flight reaches
  center, and the later poses lead into the hit before combo reward stars drop from the impact point.
- Shows the shuffle delivery box sprite from `assets/abilities/ability_shuffle_box.png` and pauses moving shelf rows while shuffle items fly through the center-screen box.
- Disables abilities after failure, completion, pause, or active ability animations. A zero-use ability button stays pressable during gameplay so `scenes/ability_purchase_menu.tscn` can offer a paid immediate use, presented as "USE ABILITY" (UI-003, not an inventory acquisition) with the canonical clover coin art and a genuine unavailable style (not alpha dimming) when unaffordable.
- Loads per-ability paid-use prices from `configs/ability_purchase_prices.json`, spends coins through `PlayerProgress.spend_coins()`, and applies the selected paid ability immediately without adding saved inventory.
- Starts the highlight timer even when no current shelf state can be highlighted.
- Uses `ShelfItem` outline/scale state for item-local highlight visuals and mirrors the same timer
  and live item screen positions into the responsive Lantern Focus Mode treatment below the HUD.
- Shows the active highlight countdown in a bottom-right badge on the highlight button.
- Mutually disables Lantern and Freezer while either timed effect is active, preventing refreshes
  and overlapping timed effects until the current countdown finishes.
- Pauses only the level countdown for Freezer, shows its active badge and frozen timer treatment,
  and mirrors that state into the wide four-sided blue glow with inward-flying snowflakes,
  including the clipped top-HUD pass and its synchronized pause/modal shading.

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
- Stores independently configured per-chapter item unlock milestones; chapter pools may overlap.
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
- Update `scenes/ui/shelf_lock_overlay.tscn` and `scripts/shelf_lock_overlay.gd` when changing locked
  shelf art, count presentation, or feedback motion; update the shelf scenes only for instance-level
  standard/compact placement.
- Keep `ShelfLockOverlay.play_unlock()` fire-and-forget and independent from
  `_update_shelf_input_pickable()`'s immediate effect.
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

Change a sound effect's mix, variants, cooldown, or polyphony:
- Update only that event's entry in `scripts/audio/sfx_catalog.gd`. Do not add preloads or
  `AudioStreamPlayer` nodes to gameplay or UI scripts.

Change a generated sound effect's character:
- Update the cue's row and recipe in `scripts/tools/core_sfx_synthesis.gd` and bump
  `GENERATOR_VERSION`.
- Regenerate and re-import:

```powershell
& 'D:\Godot\godot.exe' --headless --path . --script res://scripts/tools/generate_core_sfx.gd -- --regenerate
& 'D:\Godot\godot.exe' --headless --path . --import
```

- Re-run `tests/audio/test_core_sfx_assets.gd`; it compares the committed WAVs against a fresh
  render byte-for-byte and enforces the encoding, duration, peak, DC, and fade constraints.
- `assets/audio/item_place_valid/item_place.wav` and
  `assets/audio/match_clear/triple_clear.wav` are source recordings, not generator outputs; replace
  those files directly if their roles ever change.

Add a new sound event:
- Add its cue to `scripts/tools/core_sfx_synthesis.gd` (if it needs a new asset), regenerate, and
  add the event to `scripts/audio/sfx_catalog.gd`.
- Play it from the owner that already knows the semantic moment succeeded, through
  `SfxManager.play()`.
- Extend `tests/audio/*.gd` for the new event and its silence cases.

Change pause-menu sound-effect controls:
- Keep the `SoundEffectsButton` setting path in `scripts/pause_menu.gd` and `scripts/level.gd`
  aligned, along with the button's `sfx_click_suppressed` mark and
  `SfxManager.acknowledge_sound_effects_toggle()`.

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
