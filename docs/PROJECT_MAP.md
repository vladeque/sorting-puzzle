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
- Instantiated by `scripts/main_menu.gd` and by `scripts/level.gd` when the completion reward overlay's `Next` button loads the next normal campaign level.
- Owns shelf layout, timer, drag and tap movement, triple matching, abilities, pause-menu wiring, failure, and completion flow.
- Uses the original procedural gameplay background for Chapter 1 and chapter artwork for chapters
  whose catalog entry selects `artwork` mode.

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
- `scripts/press_scale_button.gd`
- `scripts/horizontal_pager.gd`
- `scripts/progress_ring.gd`
- `scripts/destination_screen_layout.gd`
- `scripts/production_main_menu.gd`
- `scripts/main_menu_coin_shortcut.gd`
- `scripts/coin_balance_widget.gd`
- `scripts/chapters/*.gd`
- `scripts/main_menu_reward_chest.gd`
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
- Opens `scenes/ui/profile_menu.tscn` from the profile widget, shows an editable player-name field above all 18 avatars in a centered pause-style window with a 3-column grid, and saves the name plus selected avatar through `PlayerProgress`.
- Opens `scenes/ui/settings_menu.tscn` from the settings widget, with pause-menu-style music, sound-effects, and vibration toggle visuals plus no-op `Support` and `Language` buttons.
- Disables campaign launch when saved lives are zero; the lives widget shows current lives and the `MM:SS` countdown until the next hourly restore.
- Uses `scenes/ui/level_button.tscn` and `assets/ui/level_button_blank_new.png` for the reusable glossy green level button visuals while keeping the label dynamic (also the shared `assets/themes/style_box_green_primary_button.tres` "regular" tier used by Shop purchase buttons and the Chapter cover CTA); red, light-blue, and yellow-orange variants remain available beside the source texture for alternate states or future UI variants -- yellow-orange is the intentional Main Menu Chapter-button and in-level `Watch ad` secondary/alternative-action role (see `docs/SCENES.md` "Shared UI Style Tokens"), while light-blue is currently unused by any scene.
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
- `scripts/chapters/menu_background_resolver.gd`
- `assets/themes/style_box_status_panel.tres`
- `assets/themes/style_box_orange_utility_normal.tres`, `style_box_orange_utility_pressed.tres`

Responsibility:
- Owns the visual structure Shop and Leaderboard share: a fullscreen selected-chapter background
  with a secondary-screen shade (`%DestinationShell`), safe-area-aware content margins capped to a
  720px maximum logical width with 48/40 regular/compact title sizing and bottom-navigation
  placement (`scripts/destination_screen_layout.gd`), and a bordered loading/empty/error/Retry
  presentation (`%StatusPanel`).
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
  buttons and the Chapter cover CTA share one "regular" (58px) green-button style and height.

Change here when:
- Adding offers, changing bundle presentation, integrating a real platform store, or moving purchase grants to a verified backend.
- Changing the backend development catalog join (GAME-008): update `configs/backend/shop_catalog_prices.json` to match the sibling backend's `contracts/configuration/v1/local-development-shop-catalog.json` seed content.

### Level Runtime

Files:
- `level.tscn`
- `scenes/shelf.tscn`
- `scenes/moving_shelf_row.tscn`
- `scenes/layouts/layout_*.tscn`
- `scenes/pause_menu.tscn`
- `scenes/leave_confirmation_menu.tscn`
- `assets/ui/*.png`
- Settings icon assets use square textures with warm rectangular tile art, and the main-menu and pause-menu settings buttons are square to avoid clipping or stretching.
- `scripts/level.gd`
- `scripts/moving_shelf_row.gd`
- `scripts/shelf_layout_row.gd`
- `assets/audio/*.wav`
- `configs/levels/level_*.json`
- `configs/item_sprites.json`
- `scenes/abilities/hammer_impact_effect.tscn`
- `scripts/hammer_impact_effect.gd`
- `assets/abilities/ability_hammer_swing_*.png`
- `assets/abilities/ability_shuffle_box.png`

Responsibility:
- Loads level JSON and item sprite config.
- Applies responsive layout for the top HUD, ability bar over the floor/baseboard transition strip, overlays, pause menu panel, and scaled shelf root when the viewport size changes.
- Instantiates `scenes/shelf.tscn` for each configured shelf and places shelf cells from `scenes/layouts/layout_*.tscn` preset templates.
- Builds optional `row_layouts` or template-authored moving rows, including moving rows that clip and wrap more shelves than are visible at once.
- Spawns `ShelfItem` instances from config layers.
- Handles mouse and touch interaction.
- Resolves matches of three identical visible items on the same shelf, including the gather-and-shrink clear animation.
- Shows and expires the active combo count and shrinking green time strip in `Background/HudCenterSlot` when triple clears happen within the configured combo window.
- Shows the current run's star total in `UI/StarCounterLabel` with a small `assets/ui/reward_star.png` icon; triple clears add stars equal to the combo value reached by each clear and play small `assets/ui/reward_star_34_glossy_b.png` stars that drop from the cleared triple, fly into the counter, and pulse it.
- Shows short praise words near the clear location for 2x+ combos, with unique wording through 20x and stronger colored outlines as the combo rises.
- Shows the completed-level reward overlay through the `UI/CompletionScreen` instance of `scenes/ui/level_completion_screen.tscn`, using `assets/ui/reward_star.png`, `assets/ui/level_button_blank_new.png`, and the final run star count for the earned amount label.
- Sends completed campaign stars to `PlayerProgress`; completion `Next` returns to the main menu, where one clover coin per earned star flies from the house to the reward chest and advances its visible count.
- Uses `scripts/press_scale_button.gd` on the completion `Next` button so the green blank-image button shrinks while held.
- Tracks cleared triples and unlocks shelves whose configs require progress before becoming accessible.
- Plays item placement and triple-clear sound effects.
- Keeps non-clearing items interactive while match animations run, resolves different shelves concurrently, and queues only repeated work for a shelf that is already resolving.
- Promotes back layers as soon as their own visible shelf layer clears, without waiting for match or reward animations on other shelves.
- Tracks the countdown timer, starting it only after the first meaningful player action, and win/loss overlays.
- Plays the hammer ability by gathering the targeted items into one center-screen item, striking it with the fullscreen hammer, then dropping combo reward stars from the impact point.
- Plays the shuffle ability by showing a center-screen delivery box, flying visible unlocked items into it, swapping item identities while hidden, flying them back to their slots, then resolving shelf matches.
- Wires the in-level pause menu, including the top-right circular menu button, modal overlay, Leave action, Continue action, leave confirmation overlay, and campaign life spend for confirmed Leave.
- Displays a responsive Godot-authored level backdrop with a top HUD strip, monotone shop wall, baseboard, and bottom floor band behind generated shelves.

Change here when:
- Editing puzzle rules, input behavior, runtime shelf construction, procedural level background styling, level timing, completion conditions, or ability behavior.

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
- Contains the hidden lock overlay used by triple-gated shelves; `scripts/level.gd` toggles it and fits the remaining count onto the lock center panel.
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
- Applies texture and visual scale to its `Sprite2D` and shared opaque up-right cast shadow, which is disabled for generated back-layer item previews.
- Draws reusable alpha-based sprite outlines for item highlight states.
- Defines the canonical texture size, visible bounds, shelf baseline, alpha, naming, import, and
  validation requirements for item art.

Change here when:
- Adjusting item hitboxes, sprite scale behavior, item identity storage, outline rendering, or common item visuals.

### Ability Bar

Files:
- `level.tscn`
- `scripts/level.gd`
- `scripts/player_progress.gd`
- `scenes/ability_purchase_menu.tscn`
- `scripts/ability_purchase_menu.gd`
- `configs/ability_purchase_prices.json`
- `scenes/abilities/hammer_impact_effect.tscn`
- `scripts/hammer_impact_effect.gd`
- `assets/abilities/*.png`

Responsibility:
- Provides hammer, shuffle, and highlight buttons.
- Reads campaign ability uses from `PlayerProgress`, spends campaign uses immediately, and uses temporary three-use counts for isolated dev/test levels.
- Lets hammer clear matching visible/front items first, or supplement visible/front items with first-back-layer copies of the same type if no visible item type can make a triple.
- Gathers hammer targets to the center of the screen, spawns a fullscreen hammer strike effect there, swaps through four pseudo-3D hammer angle textures in the scene-authored `AnimationPlayer`, and waits for the `impact` callback before destroying the merged item and dropping combo reward stars.
- Shows the shuffle delivery box sprite from `assets/abilities/ability_shuffle_box.png` and pauses moving shelf rows while shuffle items fly through the center-screen box.
- Disables abilities after failure, completion, pause, or active ability animations. A zero-use ability button stays pressable during gameplay so `scenes/ability_purchase_menu.tscn` can offer a paid immediate use.
- Loads per-ability paid-use prices from `configs/ability_purchase_prices.json`, spends coins through `PlayerProgress.spend_coins()`, and applies the selected paid ability immediately without adding saved inventory.
- Starts the highlight timer even when no current shelf state can be highlighted.
- Uses `ShelfItem` outline state for border-only highlight ability visuals.
- Shows the active highlight countdown in a bottom-right badge on the highlight button.

Change here when:
- Adding, removing, rebalancing, or restyling player abilities.

### Pause Menu

Files:
- `level.tscn`
- `scenes/pause_menu.tscn`
- `scenes/leave_confirmation_menu.tscn`
- `scenes/ability_purchase_menu.tscn`
- `assets/ui/*.png`
- Settings icon assets use square textures with warm rectangular tile art, and the pause/settings buttons are square to avoid clipping or stretching.
- `scripts/pause_menu.gd`
- `scripts/press_scale_button.gd`
- `scripts/level.gd`

Responsibility:
- `level.tscn` provides the top-right circular pause button and instances the pause menu scene.
- `scenes/pause_menu.tscn` owns the popup layout, warm outer area, cream inner settings area, `Pause` title, protruding top-right red close button, music / sound-effects / vibration square icon buttons with shadow-only button styling, and Leave/Continue image buttons.
- `scenes/leave_confirmation_menu.tscn` owns the second-step confirmation popup shown after Leave, including warm outer area, cream inner loss area, protruding top-right red close button, crossed-out rectangular lost life/star slots, and red Leave / green Continue image buttons.
- `scenes/ability_purchase_menu.tscn` owns the zero-ability purchase popup, including warm outer area, cream inner item slot, selected ability icon, `x1` badge, coin-price button, and inactive `Watch ad` button.
- `scripts/press_scale_button.gd` provides the default held-press shrink behavior for visible game UI buttons, including the pause/settings icon buttons and red/green bottom image buttons.
- `scripts/pause_menu.gd` toggles crossed-out visuals on the three settings icon buttons, keeps their saved disabled states synchronized between the main-menu settings popup and in-level pause menu, and emits setting state changes.
- `scripts/level.gd` opens and closes the menu, pauses the timer and gameplay input, treats red close buttons like Continue, opens the leave confirmation before routing confirmed Leave back to the main menu, writes the current run star count into that confirmation, initializes gameplay sound effects from the shared setting, and mutes them when the sound-effects button is crossed out.

Change here when:
- Restyling the in-level pause popup, adding pause menu actions, or changing pause/resume behavior.

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
- Update `scenes/pause_menu.tscn`.
- Update `scenes/leave_confirmation_menu.tscn` when changing the leave-confirmation popup.
- Update `assets/ui/*.png` when changing pause menu icon art.
- `assets/ui/pause_menu_option_a_sheet.png` and `assets/ui/pause_menu_option_b_sheet.png` are kept as alternate generated style sheets.
- Keep node paths used by `scripts/level.gd` stable unless the script is updated in the same change.

Change fonts or text hierarchy:
- Update `assets/themes/game_typography.tres` for shared font families, weights, and semantic type variations.
- Apply an existing theme type variation in the owning scene instead of attaching font files directly.
- Keep uppercase title rules and the `×` multiplier convention synchronized with dynamic strings in the owning scripts.
- Follow `docs/TYPOGRAPHY.md` and recheck the representative mobile and tablet resolutions.

Change shared button/panel/scrollbar styling:
- Edit the relevant `assets/themes/style_box_*.tres` resource (see `docs/SCENES.md` "Shared UI
  Style Tokens") rather than a scene-local `StyleBoxFlat`/`StyleBoxTexture` copy, so every consuming
  scene updates together.
- Edit `assets/themes/game_typography.tres`'s `VScrollBar`/`HScrollBar` entries for scrollbar
  changes; it is the project's global `theme/custom`, so this affects every `ScrollContainer`.
- Keep the 16/20/24 px corner-radius roles (buttons/rows/large panels) and the green-positive
  vs. orange-utility vs. neutral-disabled action-color roles consistent with `docs/SCENES.md`.

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
