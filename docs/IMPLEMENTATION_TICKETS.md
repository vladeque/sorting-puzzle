# Game Implementation Tickets

Status: Planning backlog

This backlog tracks implementation work owned by the Godot client. Cross-repository protocol,
identity, purchase, progression, and synchronization work must remain aligned with the canonical
backend requirements and contracts in `../../sorting-puzzle-backend`.

The next deployed development-environment integration batch is tracked separately so code changes
and project-owner console/setup work remain unambiguous:

- [`DEV_BACKEND_INTEGRATION_PLAN.md`](DEV_BACKEND_INTEGRATION_PLAN.md)
- [`DEV_BACKEND_CODE_TICKETS.md`](DEV_BACKEND_CODE_TICKETS.md)
- [`DEV_BACKEND_OWNER_TICKETS.md`](DEV_BACKEND_OWNER_TICKETS.md)

The gameplay + deployed guest-sync release to Google Play internal testing is split into
28 first-release work packages and 5 later milestones in
[`GOOGLE_PLAY_INTERNAL_TESTING_TICKETS.md`](GOOGLE_PLAY_INTERNAL_TESTING_TICKETS.md).
These packages reference the existing feature/setup tickets rather than replacing their specifications.

Focused client UX implementation tickets:

- [`AUDIO-001 — Implement Godot-Authored Core Sound Effects`](AUDIO_001_GODOT_ONLY_SFX_TICKET.md)
- [`GAME-012 — Add in-game account deletion through Support`](ACCOUNT_DELETION_PLAN.md)

Gameplay feature plans:

- [`Sticky items — rules, generation, runtime, and release plan`](STICKY_ITEMS_PLAN.md)
- [`Collapsing shelf columns — configuration, runtime, solver, and release task`](COLLAPSING_SHELF_COLUMNS_IMPLEMENTATION_TASK.md)
  — client implemented 2026-09-19; current behavior in [`COLLAPSING_SHELF_COLUMNS.md`](COLLAPSING_SHELF_COLUMNS.md).
  Backend publication compatibility implemented in sibling commit `9b8921d`. Open: first campaign
  slot, supporting mobile build numbers, publication/activation, and touch-device testing.

## Shared definition of done

Unless a ticket explicitly narrows its scope, it is complete when:

- Godot 4.6.2-compatible code, scenes, configuration, and versioned migrations are implemented.
- Automated tests cover normal, failure, retry, crash-recovery, and supported-platform behavior.
- Android and iOS integration requirements are documented and verified on representative builds.
- Relevant ownership documentation in `docs/` is updated.
- UI changes remain usable at 540x960, 720x1280, 1080x1920, 1080x2400, and a tablet-like portrait
  viewport.
- The corresponding backend contract fixtures pass in both TypeScript and Godot where applicable.

## GAME-001 — Implement unrestricted offline-first saves and background cloud sync

**Type:** Product/Foundation
**Status:** Implemented on 2026-07-23 — Godot/local automation passes; Android and iOS native
device/export verification remains a release gate
**Description:** Replace the mutually exclusive local/cloud snapshot provider and monolithic
`PlayerProgress` state with a crash-safe local snapshot, append-only operation journal, silent
background synchronization, deterministic account-scoped merge, and backend recovery. Players can
use all installed campaign content, receive and spend ordinary rewards immediately, and continue
indefinitely without connectivity or player-visible pending-reward state.

**Backend dependency:**
[`BE-307`](../../sorting-puzzle-backend/docs/IMPLEMENTATION_TICKETS.md#be-307--implement-unrestricted-local-first-save-synchronization)

**Policy:**
[`ADR 0020`](../../sorting-puzzle-backend/docs/adr/0020-unrestricted-local-first-offline-saves.md)

### State ownership and local schema

- Introduce a versioned local-save schema with four explicit partitions:
  1. the current player-facing gameplay snapshot;
  2. an append-only journal of unsynchronized and recently acknowledged operations;
  3. synchronization metadata/checkpoints; and
  4. device-only preferences.
- Namespace every save by immutable backend `player_id`. Before first registration, use a stable
  installation guest namespace that can be rebound exactly once to the created guest player.
- Keep installation private keys, access/refresh tokens, and platform credentials in Android secure
  storage or iOS Keychain through focused native bridge code. Never serialize them into the gameplay
  save, platform cloud blob, logs, screenshots, or diagnostics.
- Give every journal entry a UUID operation ID, strictly increasing device sequence, operation type,
  closed versioned payload, level/configuration provenance where relevant, preceding hash, and
  canonical hash/signature. Integrity metadata detects corruption or casual editing but must not be
  described as proof that gameplay occurred.
- Persist by atomic temporary-write/flush/replace with a previous-good generation. Recovery chooses
  the newest fully valid generation and never silently resets progress after a partial write.

### Client module structure

- Add a focused local persistence layer owning schema validation, atomic generations, journal append,
  checkpoint application, compaction, and migration.
- Add a secure identity/session store owning installation keys and tokens through platform bridges.
- Add a sync service owning connectivity detection, authentication refresh, request batching,
  idempotency keys, retry/backoff, cursors, response validation, and checkpoint reconciliation.
- Add an account/save coordinator owning guest bootstrap, player namespaces, Google Play Games/Game
  Center switching, guest promotion, account merge, sign-out, and recovery selection.
- Refactor `PlayerProgress` into the gameplay-facing facade over the active local snapshot. Existing
  scenes continue to request balances/progress through that facade, while persistence and network
  behavior move into the focused owners above.
- Remove `local` versus `cloud` provider exclusivity. Local persistence is always active; the backend
  and optional platform cloud storage are asynchronous recovery destinations, never replacements for
  the local runtime save.
- Use the same journal-backed mutation path while online and offline. Connectivity only determines
  how soon background synchronization runs, so gameplay does not maintain two reward/progression
  implementations.

### Immediate offline gameplay

- `complete_level()` must atomically update the local campaign snapshot, derived star/chest state,
  immediate coin rewards, lifetime/weekly local totals, reward animation metadata, and the matching
  journal operation before navigating away from the result flow.
- Coin spending, ability spending, life loss/restoration, profile changes, and every reward grant
  must update the snapshot and append their operation in one recoverable transaction.
- Do not require connectivity, a lease, a fresh server timestamp, a queue slot, or a prior online
  session to play installed campaign content. Do not enforce the legacy 72-hour, 20-attempt, or
  10-completion limits.
- Do not label rewards or campaign progress as pending/provisional and do not block their immediate
  local use. Network errors remain silent during normal gameplay.
- Purchases and initial retrieval of content not already installed remain online operations.
  Leaderboards may show a cached offline view and refresh after sync, but campaign play cannot depend
  on leaderboard availability.

### Background synchronization

- Implement the BE-307 v2 contract and generated/hand-maintained adapters using its golden fixtures.
  Upload at most 500 operations and 1 MiB per request, continuing in background batches until the
  acknowledged cursor reaches the local journal head.
- Reuse the identical idempotency key and canonical payload after timeouts or response loss. Persist
  retry state across force-close/reboot and use the approved retry/backoff policy without holding up
  scene transitions.
- Apply a successful merged checkpoint atomically, retain locally created operations beyond the
  acknowledged cursor, and compact only data no longer required for retry, crash recovery, support,
  or migration.
- Accept automatic merge adjustments without rolling back completed campaign levels. If divergent
  devices overspent a balance, apply the returned zero-floor balance/inventory and keep an internal
  diagnostic record; ordinary UI should simply show the reconciled amount.
- Never create or infer a purchase grant locally. Apply verified server-originated purchase/refund
  facts idempotently and preserve processed transaction provenance across compaction and account
  merge.

### Account switching and recovery

- On Google Play Games/Game Center account change, close the active namespace at a valid atomic
  generation, preserve its unsynchronized journal, authenticate the selected identity, and activate
  only that identity's local namespace or downloaded checkpoint. Never render one player's cached
  balance/profile under another identity.
- Keep unsynchronized namespaces available for later silent retry. Do not delete guest or signed-out
  progress merely because another account becomes active.
- For an identity with backend data, restore the latest checkpoint before applying that identity's
  unacknowledged local journal. For a new identity, start from the correct new-player bootstrap and
  never copy another player's mutable snapshot.
- Use the backend's explicit guest-promotion/account-merge result when a platform identity already
  owns a player. Any genuinely destructive or ambiguous identity conflict must use a dedicated
  reusable dialog scene; routine synchronization must not show modal UI.

### Migration and compatibility

- Add a one-time migration from the current `player_progress.json` schema version 4. Preserve
  campaign level/completions, coins, lives/timer, ability inventory, processed mock transaction IDs,
  profile, settings, chest progress, lifetime stars, and weekly stars in the initial local
  checkpoint/journal baseline.
- Make migration idempotent and retain a read-only previous-good copy until the new schema has loaded,
  saved, restarted, and passed validation once. Never upload the legacy JSON blob as an arbitrary
  backend balance replacement.
- Keep the existing provider adapters only as temporary migration/test inputs where necessary.
  Remove release dependence on Google Play Games Saved Games/GameKit blobs after backend recovery is
  verified; platform blobs may remain optional encrypted caches if separately justified.
- Gate v2 synchronization by server capability/feature configuration. A new client talking to a
  server without BE-307 continues local play and retries later; it must not downgrade its journal
  into the legacy provisional lease protocol.

### Verification

- Add automated save tests for every operation type, schema rejection, checksum/hash failure,
  interrupted writes at each atomic-save stage, previous-generation recovery, migration replay,
  compaction, and repeated migration/restart.
- Add offline scenarios for first launch without connectivity, more than 72 hours offline, more than
  20 attempts, more than 10 and 100 consecutive completions, immediate reward spending, life
  restoration, force-close during completion, reboot, and later multi-batch synchronization.
- Add mocked-contract tests for duplicate delivery, out-of-order operations, stale cursors, response
  loss, token refresh, server outage, malformed responses, merge adjustments, verified purchase and
  refund arrival, and journals larger than one request.
- Add account tests for guest bootstrap, silent platform sign-in, account A/B switching, switching
  while offline, guest promotion, remote restore on a clean installation, stale-device return, and
  assurance that namespaces, tokens, balances, profiles, and journals never leak across players.
- Run device integration tests on Android and iOS for secure storage, background/resume behavior,
  airplane-mode transitions, process death, platform account switching, uninstall/reinstall recovery,
  and platform backup interactions.
- Update `docs/CLOUD_SAVE.md`, `docs/SCRIPTS.md`, `docs/PROJECT_MAP.md`, relevant scene documentation,
  and release/support troubleshooting instructions to identify each new owner and recovery path.

## GAME-002 — Consume canonical backend content provenance

**Type:** Foundation
**Status:** Complete - implemented on 2026-07-24; exported-runtime verification corrected on
2026-07-24.
**Description:** Replace synthetic configuration, level, and rules identifiers with a generated
client manifest produced from the same immutable backend publication used by local development.

**Plan phase:** L1 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-001` and the backend development-configuration bootstrap.

**Acceptance criteria:**

- The bundled manifest maps every supported campaign level to one exact opaque
  `configuration_version`, `level_version`, and `rules_version`.
- `PlayerProgress` uses the mapping for campaign completion and attempt journal operations.
- A check command rejects a stale, incomplete, or digest-mismatched manifest before export.
- Runtime code never invents fallback protocol provenance. An invalid manifest disables
  synchronization with a non-secret diagnostic while local campaign play remains available.
- Runtime validation checks the packaged manifest's schema, digest, publication identity, and
  mappings without requiring raw authored `.gd`/`.tscn` files that Godot compiles/remaps during
  export. Raw source hashes remain mandatory in the pre-export check.
- Android regression coverage exports/installs the real debug APK and makes the local-backend smoke
  check fail if runtime rejects the packaged manifest.
- The integration slice covers all current Chapter 1 levels 1-20; future levels are not marked
  integration-ready until added to a regenerated immutable publication.

## GAME-003 — Package the Android local-backend debug target

**Type:** Platform/Foundation
**Status:** Complete and emulator-verified on 2026-07-24.
**Description:** Package the existing Android secure-store bridge and create a safe debug export
that can reach the developer-hosted API from an Android emulator.

**Plan phase:** L1 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-001`

**Acceptance criteria:**

- The secure-store AAR is built and loaded as `SortingPuzzleSecureStoreBridge`.
- The debug export enables Gradle Build, Internet access, and debug-only cleartext HTTP.
- The documented default uses `adb reverse tcp:8080 tcp:8080`; `10.0.2.2` is documented as a
  fallback.
- Backend URL and synchronization enablement are supplied through a local-only configuration path.
- Committed release defaults keep the backend URL empty and synchronization disabled.
- An emulator smoke check reaches the local `/health/live` endpoint and confirms bridge
  availability without exporting private key material.

**Implementation notes:**

- `addons/sorting_puzzle_secure_store_bridge/` is a Godot Android v2 `EditorExportPlugin` (the
  current packaging mechanism; the older `.gdap` format is deprecated) that loads
  `SortingPuzzleSecureStoreBridge-debug.aar` for debug exports and `-release.aar` otherwise.
- `plugin/src/debug/AndroidManifest.xml` is the only source of the INTERNET permission and
  `usesCleartextTraffic="true"` to the debug AAR specifically (via Gradle's own debug/release
  source-set manifest merge). The export preset does not request Internet itself, so a release
  export using the same preset receives neither permission nor cleartext opt-in.
- The AAR builds with JDK 17 and Android SDK Platform 36. The Godot 4.6.2 Gradle export targets
  Android SDK 35, matching that engine release's installed build template.
- `local/backend_debug.cfg` (gitignored; template at `local/backend_debug.example.cfg`) is the
  local-only configuration path. The export plugin injects it only into debug exports, and the
  `LocalBackendDebugBootstrap` autoload also refuses to apply it outside debug builds.
- `scripts/tools/android_local_backend_smoke_check.ps1` automates the emulator smoke check via adb
  + logcat and resolves adb from an explicit path, PATH, or the standard Android SDK locations.
- The emulator smoke check passed against a live local backend: the override activated,
  `/health/live` returned HTTP 200, and `SortingPuzzleSecureStoreBridge` was available. Diagnostics
  contain no token, signature, or private-key material.
- An unsigned release verification build contains the release bridge but does not contain the
  local override, INTERNET permission, or cleartext opt-in. A signed release still requires the
  project's release keystore and remains part of the release pipeline.

## GAME-004 — Prove local guest registration and session persistence

**Type:** Identity integration
**Status:** Implemented and gap-tested on 2026-07-24. Two real on-device defects were found and
fixed. A live device receipt of a real `player_id`/session remains unverified — see "Device
verification notes" below.
**Description:** Exercise the existing guest challenge/bootstrap and rotating-session code against
the real local API using Android Keystore signatures.

**Plan phase:** L2 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-003`, backend `BE-102` and `BE-103`, and the backend local-secret bootstrap.

**Acceptance criteria:**

- A new emulator installation completes the signed challenge/bootstrap flow and receives a real
  guest player, device, and session. **Not yet observed end to end on-device; see notes.**
- The installation guest namespace is rebound exactly once to the returned `player_id`. Proven by
  `AccountSaveCoordinator.bind_registered_guest()`/`rebind_guest_to_player()` coverage in
  `tests/save/test_game_001.gd` and the new restart-resumption test in `tests/save/test_game_004.gd`.
- Session ciphertext and the installation private key remain inside the Android secure boundary
  (unchanged Android Keystore/`SharedPreferences` design; see `docs/CLOUD_SAVE.md`).
- Killing and restarting the app resumes the same player session without creating a second guest.
  Proven at the `AccountSaveCoordinator` layer by `tests/save/test_game_004.gd`; not yet observed
  through a live device kill/restart because it depends on a completed bootstrap (see notes).
- Access-token expiry performs one successful rotating refresh and stores the replacement session.
  The single-refresh-attempt guard and a valid-refresh round trip are proven by
  `tests/save/test_game_001.gd` and `tests/save/test_game_004.gd`; forcing a live 401 requires
  either the real ~5 minute access-token TTL or a backend dev-only short-TTL hook, neither of which
  exists yet.
- Malformed, expired, replayed, and binding-mismatched bootstrap/session responses are covered.
  Proven by `tests/save/test_game_004.gd`, which drives `GuestSessionBootstrapService` and
  `SaveSyncService`'s real `_on_request_completed` handlers with malformed envelopes, an
  `auth.guest_challenge_expired` response, an `auth.refresh_reuse_detected` (replay) response, and
  device-binding-mismatched bootstrap/refresh responses.

**Real defects found and fixed while gap-testing:**

1. `SecureSessionStore` gated every Android bridge call (`ensure_installation_key`,
   `get_installation_public_key_der`, `sign_save_operation_hash`, `sign_installation_payload`,
   `store_player_session`, `load_player_session`, `clear_player_session`) behind
   `_bridge.has_method(...)`. On a real device this returned `false` for a bridge that was
   genuinely present and fully functional, silently disabling `can_synchronize()` and the
   installation key/public-key lookup with no error surfaced anywhere. Fixed by calling the bridge
   directly and treating a `null`/failed result as an error, matching the tolerant-result pattern
   already used elsewhere in the file.
2. `application/config/version` was never declared in `project.godot`. Every protocol request's
   `meta.app.version` was therefore an empty string, which the backend's schema rejects
   (`request.invalid` / `request.schema.minlength` on `/meta/app/version`), so the guest challenge
   request failed on every real device before this fix. Fixed by declaring
   `config/version="0.1.0"` (matching the export preset's `version/name`).

Both were only discoverable by actually dispatching signed requests from a real Android Keystore
against the real backend — exactly what this ticket exists to do.

**Device verification notes (2026-07-24):**

- `GET /health/live` from the app (via `LocalBackendDebugBootstrap`'s health probe) succeeded
  reliably on every run.
- Two clean runs (fresh install, fresh `device_id`) sent the real signed `POST
  /v1/sessions/guest/challenge` request and received a real backend response within ~200ms. Before
  the version fix, the backend correctly returned `400 request.invalid` with the exact
  `/meta/app/version` violation, which is what led to defect #2 above; the client correctly
  recorded the server's error code and `correlation_id` as a non-secret terminal diagnostic.
- On roughly a dozen subsequent clean-install attempts (including an `adb kill-server` restart and
  `pm clear` data wipes to rule out stale state), the same POST request was accepted by
  `HTTPRequest.request()` (`request_error == OK`) but its `request_completed` signal never fired —
  not even Godot's own 30-second request timeout — while `GET` requests continued to succeed
  reliably throughout. This was reproduced identically with and without extra diagnostic
  `print()` calls near the request (ruling out a print-timing theory considered mid-investigation).
  This looks like emulator/Godot-Android `HTTPRequest` POST-with-body flakiness specific to this
  workstation's `adb reverse` setup, not an application defect; it blocks a live end-to-end
  bootstrap/kill-restart/refresh-rotation proof for now. `GAME-005`/`GAME-006` also depend on POST
  (`/v2/saves/sync`), so this is worth a focused retest (different emulator image, physical device,
  or a native `nc`-based reproduction) before those tickets attempt device verification.
- `scripts/tools/android_local_backend_identity_smoke_check.ps1` automates the intended proof
  (bootstrap + kill/restart) once the above is resolved.

## GAME-005 — Prove protocol-v2 save synchronization against PostgreSQL

**Type:** Save integration
**Status:** Implemented and gap-tested on 2026-07-25. Two real defects were found and fixed. A live
on-device (Android emulator) proof of the same POST path remains blocked by the `HTTPRequest`
issue already documented under GAME-004; see "Device verification notes" below.
**Description:** Run the existing local-first operation journal and checkpoint reconciliation
against the real protocol-v2 API and database.

**Plan phase:** L2 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-002`, `GAME-004`, and backend `BE-307`

**Acceptance criteria:**

- Empty sync and signed completion, attempt, spend, life, and profile operations are accepted.
  Proven directly against the real API/database by
  `scripts/tools/local_backend_save_sync_integration_check.mjs` using a genuine generated P-256
  installation key (real guest challenge/bootstrap, then a real signed operation of each of the
  five v2 types in one batch).
- The acknowledged cursor advances to the submitted sequence and the returned checkpoint is applied
  atomically. Proven live (cursor reaches the submitted sequence; checkpoint reflects the merged
  campaign completion, coin spend, and profile edit) and replayed through the real
  `SaveSyncService._apply_response()`/`LocalSaveStore.apply_reconciliation()` code paths against the
  exact captured response bodies by `tests/save/test_game_005.gd`.
- Operations beyond the acknowledged cursor remain local and replay over the checkpoint. This
  journal-retention behavior is unchanged GAME-001 `LocalSaveStore` logic (cursor advancement never
  deletes unacknowledged entries; `compact_journal()` only trims already-acknowledged history) and
  remains covered by `tests/save/test_game_001.gd`; GAME-005 additionally confirms the real
  acknowledged-cursor values this logic reconciles against.
- Multi-batch continuation reaches the journal head without blocking scene changes. Proven live
  with a 520-operation continuation (two real `POST /v2/saves/sync` requests: 500 operations then
  the remaining 20), confirming `continuation.has_more`/`next_device_sequence` match
  `SaveSyncService`'s cursor-driven re-invocation (via `call_deferred("request_background_sync")`)
  exactly.
- PostgreSQL contains the expected player/device stream, deduplicated operations, cursor snapshots,
  checkpoint, and outbox relationship. Confirmed directly via `docker exec ... psql`: one row each
  in `players`/`devices`/`sessions`, 525 deduplicated rows in `save_operations`
  (`count(*) = count(DISTINCT operation_id)`), `save_device_streams.acknowledged_sequence = 525`
  matching the journal head, five incrementing `save_checkpoints` generations (0 initial + 4 real
  synchronize calls; the idempotent replay call correctly produced no new generation), and a
  `save_checkpoint_outbox_events` -> `outbox_events` `save.checkpoint_merged.v1` row for each of the
  four mutating generations.
- Existing Godot save tests and shared protocol-v2 fixtures continue to pass. Reran
  `test_game_001.gd`, `test_game_002.gd`, `test_game_004.gd`,
  `test_local_backend_debug_bootstrap.gd`, and `test_player_progress_facade.gd` headless; all pass
  alongside the new `test_game_005.gd`.

**Real defects found and fixed while gap-testing:**

1. `LocalSaveCodec.iso_timestamp()` (`scripts/save/local_save_codec.gd`) called
   `Time.get_datetime_string_from_unix_time(timestamp, true)`. That second argument is
   `use_space`, not a UTC flag (Godot's unix-time-based `Time` functions are already UTC) --
   passing `true` renders a space (`"2026-07-24 21:54:02"`) instead of the ISO-8601 `T` separator
   the backend's `Timestamp` schema requires everywhere this client sends a timestamp
   (`meta.client_time` on every request envelope, plus every operation's `occurred_at` and
   `life_state`'s `observed_at`). A direct request to the live backend with the exact malformed
   value confirmed the real-world impact: `400 request.invalid` /
   `request.schema.pattern` on the violating field, every time. This means every real backend
   request this client has ever attempted to send -- including the guest challenge/bootstrap calls
   GAME-004 drove from a real Android Keystore -- would have been rejected before today's fix.
   Fixed by passing `false` (ISO-8601 `T` separator).
2. `LocalSaveCodec.is_timestamp()` only checked the string length and a literal `.000Z` suffix, so
   it neither caught defect #1 (a space-separated string is also 24 characters ending in `.000Z`)
   nor accepted any genuine non-`.000` millisecond value a real backend timestamp or another
   platform's clock could produce. Fixed by matching the backend's exact `Timestamp` regex
   (`^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$`).

Both were only discoverable by validating this client's own timestamp-producing code against a
real backend's schema enforcement -- exactly what this ticket exists to do, and the same pattern
GAME-004 already found real defects with.

**Device verification notes (2026-07-25):**

- The server/database half of protocol-v2 save synchronization is proven directly and repeatably
  against a real, currently-running local backend + PostgreSQL by
  `scripts/tools/local_backend_save_sync_integration_check.mjs` (38/38 checks passing), independent
  of the Godot/Android runtime.
- A live, Godot-client-driven, real-Android-Keystore-signed `POST /v2/saves/sync` end-to-end proof
  was not attempted in this environment (no attached Android emulator/device) and remains subject
  to the same emulator/Godot-Android `HTTPRequest` POST reliability issue GAME-004 documented and
  explicitly flagged as relevant to `GAME-005`/`GAME-006`. `tests/save/test_game_005.gd` closes as
  much of that gap as is possible without a device: it replays the exact response bodies the live
  backend returned (`tests/fixtures/save_sync_v2/*.json`) through the real on-device reconciliation
  code, rather than hand-authored/synthetic envelopes.
- `scripts/tools/local_backend_save_sync_integration_check.mjs --dump-fixtures <dir>` regenerates
  the committed fixtures from a fresh live run if the backend's response shape ever changes.

## GAME-006 — Harden local save synchronization recovery

**Type:** Reliability
**Status:** Implemented and gap-tested on 2026-07-25. No production defect was found: GAME-001,
GAME-004, and GAME-005 had already implemented every behavior this ticket requires
(`SaveSyncService`'s persisted pending-request replay, single-refresh guard, `auth.refresh_result_unknown`
transport-failure branch, cursor-mismatch state fetch, and the feature-flag gate; `PlayerProgress`'s
checkpoint mapper). None of it was exercised end-to-end by an existing test until now.
**Description:** Verify that authentication, network, server, and cursor failures preserve local
play and converge without duplicate effects.

**Plan phase:** L2 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-005`

**Acceptance criteria:**

- Request timeout, response loss, app kill, API restart, database outage, `429`, and retryable
  `5xx` cases persist retry state and replay the identical payload/idempotency tuple. Proven by
  `tests/save/test_game_006.gd` feeding `SaveSyncService._on_request_completed()` every non-success
  `HTTPRequest.Result` plus `429`/`500`/`503`, and by reopening a `LocalSaveStore`/`SaveSyncService`
  pair against the same on-disk namespace to simulate an app kill/restart.
- A `401` performs at most one refresh/replay and unknown refresh outcomes do not reuse a rotating
  credential. GAME-004 already proved the single-refresh-attempt guard and malformed/replayed
  refresh handling; GAME-006 adds the previously untested paths: a full 401 -> refresh -> replay
  round trip that reuses the identical pending payload/idempotency tuple with the rotated access
  token, and a transport-level failure *during* the refresh call itself
  (`auth.refresh_result_unknown`), which never retries and never overwrites the stored session.
- Cursor conflict fetches remote state and reconciles before retry. Proven end-to-end: a `409
  save_sync.cursor_mismatch` triggers `GET /v2/saves/state`, and only after that response
  reconciles (cursor adopted, pending request cleared, `reconciliation_applied` emitted) does any
  further sync attempt become possible.
- Disabling v2 ingestion never blocks local play; re-enabling it later drains the journal. Proven
  by committing local mutations with the feature flag off (commits succeed, no request is built),
  then flipping the flag and confirming the next `request_background_sync()` drains the full
  accumulated journal in one request. Draining is event-driven (the next local mutation or the next
  app start calls `request_background_sync()` again), not a mid-session flag-change listener; there
  is no requirement for one and none was added.
- Overspend adjustments clamp the affected asset without rolling back completed campaign levels.
  Every existing test had configured `SaveSyncService` with a no-op checkpoint mapper
  (`func(checkpoint, current, remaining): return current`), so `PlayerProgress._map_checkpoint_to_snapshot()`
  /`_apply_unacknowledged_operation()` — where the actual clamp-without-rollback behavior lives —
  was untested end-to-end. GAME-006 calls the real mapper directly and confirms a checkpoint with a
  floored `balances.coins` leaves `campaign.highest_completed_level`/`current_level` untouched, and
  that replaying a further local overspend on top floors at zero instead of going negative.
- Diagnostics expose stable error and correlation identifiers but no tokens, signatures, request
  bodies, or secret paths. Proven by seeding a terminal error, correlation id, adjustment, pending
  request, and a real access/refresh token, then asserting `PlayerProgress.get_local_save_diagnostics()`'s
  serialized output exposes the stable identifiers but contains none of the injected secret values.

Automated verification:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/save/test_game_006.gd -GodotArguments '--verbose'
```

## GAME-007 — Add a shared authenticated backend transport

**Type:** Networking/Foundation
**Status:** Implemented on 2026-07-25.
**Description:** Provide reusable authenticated read transport and closed protocol adapters for
backend features outside the focused save services.

**Plan phase:** L3 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-004`

**Acceptance criteria:**

- The transport owns bearer headers, request metadata where applicable, correlation IDs, timeouts,
  response-envelope validation, structured errors, retry classification, and one refresh/replay.
- Bodyless v1 GET requests send no invented request body or protocol headers.
- Operation adapters validate required Godot `Variant` types, ignore additive response fields, and
  map unknown response enums to `unknown`.
- Reads retry only on the approved network, rate-limit, and retryable dependency outcomes.
- Shared v1 and v1.1 success/error fixtures pass in Godot.

**Implementation notes:**

- `scripts/backend/backend_transport.gd` (`BackendTransport`) is a new `Node`, wired once by
  `PlayerProgress` (`get_backend_transport()`) alongside the existing `SecureSessionStore`. It
  issues bodyless authenticated v1 `GET` reads with an `Authorization: Bearer` header and a
  client-generated `X-Correlation-ID`, validates the success/error envelope shape (including the
  bodyless-GET rule that `request_id` equals the final `correlation_id`), and classifies retries
  per the backend's documented client read policy: network failures, `429` (honoring
  `Retry-After`), and `502`/`503`/`504` retry up to one initial try plus four retries within 30
  seconds; every other outcome, including `500` (mutation-retry-only per the backend's status
  table), is terminal. Exactly one refresh-and-replay is attempted on `401` via
  `POST /v1/sessions/refresh`, self-contained to this file so `scripts/save/save_sync_service.gd`'s
  existing mutation idempotency/retry behavior is untouched, as `LOCAL_BACKEND_INTEGRATION.md`
  requires.
- `scripts/backend/backend_read_operations.gd` (`BackendReadOperations`) adapts the five bodyless
  v1 reads named in the backend's `PROTOCOL_BOUNDARY.md` (player state, player devices, catalog,
  one purchase, one leaderboard scope) against the exact required-field/enum definitions in the
  backend's `packages/protocol/schemas/v1/protocol.schema.json`. Every adapter type-checks its
  required fields (reusing `LocalSaveCodec.is_uuid`/`is_opaque_id`/`is_timestamp`, and the
  established `value is int or (value is float and integral)` check for JSON-decoded integers),
  reads only the keys it exposes so additive response fields are ignored by construction, and maps
  unrecognized enum values to `"unknown"`.
- `tests/backend/test_game_007.gd` feeds the real backend contract fixtures from the sibling
  `../sorting-puzzle-backend/contracts/fixtures/v1/{success,error}/*.json` straight into the
  adapters (proving the shared fixtures parse in Godot, per the acceptance criterion) and a
  duplicated player-state fixture with unrecognized `account_kind`/`moderation_state` values into
  `parse_player_state()` (proving the `unknown` mapping). A `BackendTransport` subclass overriding
  only the `_send_get`/`_send_post`/`_wait_before_retry` network/timing seams (the same test-double
  pattern `tests/save/test_game_006.gd` uses for `SaveSyncService`) drives network-failure retry,
  `429` `Retry-After` handling, `502`/`503`/`504` retry, terminal `400`/`403`/`404`/`426`/`500`
  handling, retry-budget exhaustion, a full `401` -> refresh -> replay round trip, a second `401`
  after refresh, an unknown refresh transport outcome, and a malformed refresh response, all
  without opening a real socket or a real delay.
- No new project settings were added; the transport reuses `application/config/backend_base_url`
  and requires a valid stored session for the active player, which is already gated by
  `application/config/save_sync_v2_enabled` at guest-registration time (`GAME-004`).
- Catalog (`GAME-008`) and leaderboard (`GAME-009`) provider integration, offline caching, and
  UI wiring are explicitly out of scope for this ticket.

Automated verification:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/backend/test_game_007.gd -GodotArguments '--verbose'
```

## GAME-008 — Integrate the backend Shop catalog locally

**Type:** Commerce read integration
**Status:** Implemented on 2026-07-25.
**Description:** Populate the existing Shop from the authenticated backend development catalog
while keeping price lookup and purchasing explicitly local/mock.

**Plan phase:** L3 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-007`, backend `BE-401`, and an active development catalog.

**Acceptance criteria:**

- The Shop displays only eligible offers returned by `GET /v1/catalog`.
- Backend rewards and product IDs are joined with mock provider-formatted regional prices without
  trusting local catalog eligibility.
- No purchase-intent or verification endpoint is called in this ticket.
- Mock grants remain visibly development-only and cannot be represented as verified purchases.
- Loading, empty, unavailable, unauthorized, cached, and malformed catalog responses are covered.

**Implementation notes:**

- `application/config/shop_catalog_source` (new, default `local`) independently selects the Shop's
  *offer* source; `application/config/store_provider` (unchanged, still `mock`-only) continues to
  own regional price formatting and purchase execution regardless of catalog source, so this ticket
  never widens the mock-purchase surface.
- `scripts/store/backend_catalog_source.gd` (`BackendCatalogSource`) is the `backend` catalog
  source. It reads `GET /v1/catalog` through the existing GAME-007 `BackendTransport`/
  `BackendReadOperations.parse_catalog()`, keeps only offers with `eligible: true` (defense in
  depth -- the backend's `SHOP_CATALOGS.md` already guarantees every returned offer is eligible,
  but this class never trusts a local file for that decision either), maps the backend `starter`/
  `timed_bundle`/`evergreen_bundle`/`coin_pack` enum to the UI's `bundle`/`coins` grouping (an
  offer with an unrecognized/`unknown` type is excluded, not rendered blindly), and joins each
  offer to `configs/backend/shop_catalog_prices.json` by `platform_product_id` for its display
  title and mock regional price -- reusing the exact same `MockStoreProvider.load_products()` the
  local catalog already uses, so pricing/currency formatting code is not duplicated. An offer with
  no matching local presentation entry is excluded rather than shown without a price.
- `scripts/store/backend_catalog_cache.gd` (`BackendCatalogCache`) persists the last successful
  join to `user://shop_catalog_backend_cache.json` (offers/prices only, never a token or
  signature). Any failed read -- an empty/unset `backend_base_url`, a network/dependency failure
  (including "no active catalog", which the backend's `catalog.controller.ts` returns as a
  retryable `503 dependency.catalog_unavailable`), an exhausted `401` refresh, or a catalog
  response that fails `parse_catalog()` validation -- falls back to this cache; only surfaces an
  error to the Shop when no prior cache exists either.
- `StoreService.load_catalog()`/`purchase_offer()` are otherwise unchanged: `purchase_offer()`
  always calls the mock provider's `purchase()` regardless of catalog source, so a backend-sourced
  offer is bought exactly the same mock-transaction-id way a local-catalog offer already was, and
  no purchase-intent or verification endpoint is ever called.
- `configs/backend/shop_catalog_prices.json` presents the two offers the sibling backend's
  `pnpm bootstrap:local` seed actually publishes (`../sorting-puzzle-backend/contracts/configuration/v1/local-development-shop-catalog.json`):
  `sorting_puzzle.local.starter_bundle` and `sorting_puzzle.local.coin_pack_small`. It must be kept
  in sync with that seed file if the backend's local development catalog content changes.
- `tests/backend/test_game_008.gd` drives `BackendCatalogSource` with the same synthetic-transport
  test-double pattern `tests/backend/test_game_007.gd` established (a `BackendTransport` subclass
  overriding only `_send_get`/`_send_post`/`_wait_before_retry`), covering: eligible-offer join and
  pricing, ineligible-offer exclusion, unrecognized-offer-type exclusion, missing-local-price
  exclusion, an empty catalog, an unavailable catalog with and without a prior cache, an exhausted
  `401`, a malformed response falling back to cache, and a disabled/unset backend short-circuiting.
  It also proves `StoreService._create_catalog_source()`'s `local`/`backend`/unknown-value
  selection. A live, Godot-client-driven proof against a real running local backend was not
  attempted in this environment (no attached local backend/Android device), consistent with the
  same environment limitation GAME-004/005/006/007 already documented.

Automated verification:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/backend/test_game_008.gd
```

## GAME-009 — Integrate backend leaderboards locally

**Type:** Ranking read integration
**Status:** Implemented on 2026-07-25.
**Description:** Replace mock ranking data in backend-enabled debug builds with authenticated
weekly, country, and world leaderboard reads.

**Plan phase:** L3 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-007`, backend `BE-502`, and backend protocol-v2 completion materialization.

**Acceptance criteria:**

- The provider normalizes entries, current-player row, period end, limit, and opaque cursor fields
  for the existing leaderboard screen.
- Pagination, ties, current player outside the page, empty rankings, and cursor expiry are covered.
- The most recent successful page is available offline and refreshes silently after synchronization.
- Country scope follows the backend's no-country behavior and never infers country locally.
- Two local players with different selected v2 completions appear in deterministic score order.

**Implementation notes:**

- `application/config/leaderboard_provider` (unchanged setting, new `backend` value; default stays
  `mock`) selects `scripts/leaderboards/backend_leaderboard_provider.gd`
  (`BackendLeaderboardProvider`) in `LeaderboardService._create_provider()`, mirroring
  `StoreService`'s GAME-008 `_find_backend_transport()` lookup so the provider never takes a hard
  compile-time dependency on `PlayerProgress` autoload resolution order.
- `BackendLeaderboardProvider` implements the existing `LeaderboardProvider.fetch_leaderboard(scope,
  current_player, limit)` contract unchanged, so `leaderboard_screen.gd` needed no changes. It reads
  `GET /v1/leaderboards/{scope}` through the shared GAME-007 `BackendTransport`/
  `BackendReadOperations.parse_leaderboard()` (already contract-tested against the real backend
  fixture by `tests/backend/test_game_007.gd`) and passes entries through unchanged -- rank, score,
  and tie ordering are authoritative from the backend, never re-derived locally. `current_player` is
  read from the response's `current_player` field when the backend omits the player from `entries`
  (outside-page placement) and otherwise recovered from the matching `is_current_player` row inside
  `entries`, matching the backend's `playerIsInPage` behavior in `leaderboard-query-store.ts`.
  `period_end` is converted through the existing `LocalSaveCodecScript.unix_from_timestamp()` helper
  into the screen's expected `period_end_unix`. `has_more` reflects whether the response's
  `next_cursor` is non-empty; a `fetch_page(scope, limit, cursor)` method exposes cursor forwarding
  and cursor-expiry (`request.invalid_cursor`) error handling for a later "load more" page even
  though the screen only requests the backend's single 50-row max page today. The country scope's
  documented no-country response (`entries: []`, no `period_id`/`period_end`/`current_player`) is
  never special-cased or defaulted locally -- it renders as an ordinary empty board.
- `scripts/leaderboards/backend_leaderboard_cache.gd` (`BackendLeaderboardCache`) persists the last
  successful page per scope to `user://leaderboard_backend_cache.json` (entries, current-player row,
  and period end only -- never a token, signature, or pagination cursor). Any failed read -- an
  empty/unset `backend_base_url`, a network/dependency failure (including `503
  dependency.leaderboard_unavailable`), an exhausted `401` refresh, an invalid/expired cursor
  (`400 request.invalid_cursor`), or a response that fails `parse_leaderboard()` validation -- falls
  back to this cache; only surfaces an error to the screen when no prior cache exists either. An
  empty cached page (no prior successful fetch with entries) is treated as no usable cache, matching
  `BackendCatalogCache`'s GAME-008 behavior.
- `tests/backend/test_game_009.gd` drives `BackendLeaderboardProvider` with the same synthetic-
  transport test-double pattern `tests/backend/test_game_007.gd`/`test_game_008.gd` established,
  covering: current player outside and inside the page, tie rank/order passthrough, empty rankings,
  the country no-country response, `next_cursor`/`has_more`, an unavailable leaderboard with and
  without a prior cache, an exhausted `401`, a malformed response falling back to cache, an
  invalid/expired cursor, an unrecognized scope, and a disabled/unset backend short-circuiting. It
  also proves `LeaderboardService._create_provider()`'s `mock`/`backend`/unknown-value selection.
- Backend v2 checkpoint-to-leaderboard materialization (`LOCAL_BACKEND_INTEGRATION.md` gap 7) is a
  backend-owned gap this ticket does not close: the backend's current score model is populated from
  accepted run completions, while this game repository's save-sync path produces a
  `save.checkpoint_merged.v1` outbox event. Per this repository's `AGENTS.md`, the sibling backend
  repository is not modified as part of this ticket. Until that backend materialization ships, two
  local players with different selected v2 completions cannot be proven to appear in deterministic
  score order against a real running backend; this is the same kind of environment/cross-repository
  gap GAME-004/005/006 already documented, not a defect in this ticket's client-side provider,
  cache, or selection logic, all of which are proven by `tests/backend/test_game_009.gd`. A live,
  Godot-client-driven proof against a real running local backend was not attempted in this
  environment (no attached local backend/Android device), consistent with GAME-004/005/006/007/008.

Automated verification:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/backend/test_game_009.gd
```

## GAME-010 — Automate the Android local-backend integration gate

**Type:** Tooling/Verification
**Status:** Implemented and backend-gate verified on 2026-07-26; full Android exit remains blocked
by the previously documented emulator `HTTPRequest` POST-with-body issue from GAME-004/005.
**Description:** Turn the clean-start Android emulator flow into a repeatable local verification
command and troubleshooting runbook.

**Plan phase:** L4 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-006`, `GAME-008`, and `GAME-009`

**Acceptance criteria:**

- One documented flow starts PostgreSQL, migrates and bootstraps development data, starts and waits
  for the API, configures `adb reverse`, installs the debug APK, and runs the smoke scenario.
- The flow verifies persisted identity/session, save cursor/checkpoint, outbox, catalog, and
  leaderboard results.
- Cleanup targets only a dedicated disposable integration database or explicitly named test data.
- Failures identify the phase, stable error code, and correlation ID without exposing secrets.
- Client and backend changes remain separate commits and identify the shared content/fixture
  versions used by the run.

**Implementation:** `scripts/tools/run_local_backend_integration_gate.ps1` is the single Windows
developer command. It uses the fixed disposable `sorting_puzzle_game010` database, runs the
Godot fixture runner at `tests/backend/test_game_010.gd`, exports and installs the local-backend
debug APK, clears only this package's emulator data, proves Android guest/session restart
resumption, executes two signed protocol-v2 save scenarios, and delegates database promotion and
assertions to the sibling backend's `game010:*` commands. The two repository changes are committed
separately.

The gate reports the pinned v1 `1.0.0`, v1.1 `1.1.6`, and v2 `save-sync-fixtures/1` fixture
versions plus the generated content manifest digest/configuration version. Its default cleanup
stops only the API process it started, drops only `sorting_puzzle_game010`, removes only
`local-secrets/game010`, and restores a pre-existing `local/backend_debug.cfg` byte-for-byte.
`-KeepIntegrationDatabase` is an explicit troubleshooting opt-out. Failure output contains the
phase, a stable `game010.<phase>.failed` code, and a per-run correlation ID; tokens, signatures,
request bodies, credential values, and secret paths are not emitted by the gate.

Automated verification:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/backend/test_game_010.gd
.\scripts\tools\run_local_backend_integration_gate.ps1
```

Verification on 2026-07-26:

- `tests/backend/test_game_010.gd` passed all 48 fixture documents.
- `run_local_backend_integration_gate.ps1 -SkipInstall -SkipAndroid -ApiPort 18080` completed from
  disposable database creation through 16/16 persistence/catalog/outbox/leaderboard assertions and
  bounded cleanup.
- The full command on the attached `emulator-5554` successfully exported/installed the APK,
  cleared app data, configured `adb reverse tcp:8080 tcp:18080`, launched the debug app, and entered
  `guest_phase=challenge`. It then failed at the stable `android_identity` phase because
  the same Godot Android POST request never emitted `request_completed`. This is the existing
  workstation/emulator transport limitation documented under GAME-004, not a failure of the new
  orchestration, disposable cleanup, contract runner, or backend assertions.

## GAME-011 — Add the Freezer countdown ability

**Type:** Product/Gameplay
**Status:** Client implementation in progress on 2026-07-26; generated art selection and the
backend v2.1/catalog publication remain open dependencies.
**Description:** Add `freezer` as the fourth first-class ability. A successful use freezes only
the level countdown for 30 seconds of active gameplay while normal puzzle interaction and all
other gameplay timers continue.

**Backend dependencies:**
- [`BE-208`](../../sorting-puzzle-backend/docs/IMPLEMENTATION_TICKETS.md#be-208--implement-authoritative-ability-spending)
  for canonical ability inventory/economy handling.
- [`BE-307`](../../sorting-puzzle-backend/docs/IMPLEMENTATION_TICKETS.md#be-307--implement-unrestricted-local-first-save-synchronization)
  for journal/checkpoint merge semantics.
- The product-requested backend Freezer/v2.1 catalog ticket is not yet present in the checked-out
  sibling repository. Its eventual identifier/publication must be linked here before release.

**Timing contract:**
- Activation sets a 30-second active-gameplay window and starts the level timer if it was idle.
- While active, only `_time_remaining` is suppressed. Item input/moves, moving shelf rows,
  matches, animations, combo expiration, and Lantern expiration continue normally.
- Pause, leave/purchase modals, and application interruption suspend the Freezer window.
- Freezer cannot stack or refresh. Preflight rejects an active use before inventory or coins are
  spent.
- A delta that crosses expiry freezes only the exact remaining portion; its remainder advances the
  level countdown.
- Completion, failure, leave, load/reset, and scene teardown clear runtime state and visuals.

**Ownership:**
- `scenes/ui/ability_bar.tscn` and `scripts/ability_bar.gd`: four-button visual hierarchy,
  responsive touch targets, uses badges, and active countdown badges.
- `scripts/level.gd`: activation preflight, exact timing, countdown gating, pause/interruption, and
  terminal cleanup.
- `scripts/player_progress.gd` and `scripts/save/*`: schema-5 migration, immediate persistence,
  `resource_spend`, crash recovery, and v2.1/v2.0-compatible reconciliation.
- `configs/ability_purchase_prices.json`: 100-coin paid immediate use.
- Shop/catalog adapters: additive three-Freezer starter rewards for new catalog versions while
  historic versions without the field remain valid.

**Automated verification:**

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/gameplay/test_game_011.gd
```

The accelerated-delta suite covers activation before the first move, exact countdown suppression,
other timers and moving rows continuing, pause/purchase/app-interruption suspension, non-stacking
and no accidental spend, terminal cleanup, zero-inventory coin purchase, insufficient coins,
offline persistence/restart and promoted-generation crash recovery, v2.1
request/reconciliation plus v2.0 checkpoint compatibility, starter-grant idempotency, and layout
assertions at the required portrait sizes. `tests/backend/test_game_010.gd` separately loads the
client v2.1 goldens while retaining the sibling backend's v2.0 compatibility manifest gate.

## GAME-012 — Add in-game account deletion through Support

**Type:** Product/Privacy
**Status:** Planned on 2026-10-02 — no runtime implementation yet
**Plan:** [`ACCOUNT_DELETION_PLAN.md`](ACCOUNT_DELETION_PLAN.md)
**Backend dependency:** [`BE-607`](../../sorting-puzzle-backend/docs/ACCOUNT_DELETION.md),
implemented in sibling commit `24e18d6`.

**Description:** Add a Support action and dedicated confirmation/result modal for permanent
account deletion. Submit the canonical protocol-1.3 DELETE mutation, erase the old save and secure
installation identity after acceptance, then offer an explicit **Start a new game** action.

**Owner-confirmed behavior:**

- Confirm the accepted request and complete local cleanup before offering a fresh game.
- Keep an ambiguously deleted account locked with **Deletion status unconfirmed** and a support
  option after the original retry credential expires.
- Offer separately labeled **Delete local game data** for proven never-registered installations,
  without creating a backend account solely to delete it.

**Acceptance criteria:**

- Guests and platform accounts use `DELETE /v1/player/account`, `confirmed: true`, authoritative
  state version, stable request/idempotency identities, and a validated 202 response.
- Restart-safe request tracking, scoped cleanup, Android/iOS key destruction, and startup gates
  prevent stale sync, refresh, legacy migration, or guest fallback from resurrecting deleted data.
- Exact retries preserve the original credential while valid; unconfirmed outcomes never become
  success merely because authentication fails.
- A new game starts only after explicit input, with fresh installation/device/key identities and
  normal initial progress. Unrelated account namespaces remain protected.
- Local-only deletion, registration response loss, failures, conflicts, cleanup interruption,
  restart, and responsive modal states have focused automated/device/screenshot verification.
- Backend worker scheduling and packaged native cleanup capability remain explicit release gates.
