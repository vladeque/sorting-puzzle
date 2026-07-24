# Game Implementation Tickets

Status: Planning backlog

This backlog tracks implementation work owned by the Godot client. Cross-repository protocol,
identity, purchase, progression, and synchronization work must remain aligned with the canonical
backend requirements and contracts in `../../sorting-puzzle-backend`.

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
- The first integration slice covers levels 1-8; levels 9-10 are not marked integration-ready
  until their duplicate campaign-level declarations are corrected and republished.

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
**Status:** Planned
**Description:** Exercise the existing guest challenge/bootstrap and rotating-session code against
the real local API using Android Keystore signatures.

**Plan phase:** L2 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-003`, backend `BE-102` and `BE-103`, and the backend local-secret bootstrap.

**Acceptance criteria:**

- A new emulator installation completes the signed challenge/bootstrap flow and receives a real
  guest player, device, and session.
- The installation guest namespace is rebound exactly once to the returned `player_id`.
- Session ciphertext and the installation private key remain inside the Android secure boundary.
- Killing and restarting the app resumes the same player session without creating a second guest.
- Access-token expiry performs one successful rotating refresh and stores the replacement session.
- Malformed, expired, replayed, and binding-mismatched bootstrap/session responses are covered.

## GAME-005 — Prove protocol-v2 save synchronization against PostgreSQL

**Type:** Save integration
**Status:** Planned
**Description:** Run the existing local-first operation journal and checkpoint reconciliation
against the real protocol-v2 API and database.

**Plan phase:** L2 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-002`, `GAME-004`, and backend `BE-307`

**Acceptance criteria:**

- Empty sync and signed completion, attempt, spend, life, and profile operations are accepted.
- The acknowledged cursor advances to the submitted sequence and the returned checkpoint is applied
  atomically.
- Operations beyond the acknowledged cursor remain local and replay over the checkpoint.
- Multi-batch continuation reaches the journal head without blocking scene changes.
- PostgreSQL contains the expected player/device stream, deduplicated operations, cursor snapshots,
  checkpoint, and outbox relationship.
- Existing Godot save tests and shared protocol-v2 fixtures continue to pass.

## GAME-006 — Harden local save synchronization recovery

**Type:** Reliability
**Status:** Planned
**Description:** Verify that authentication, network, server, and cursor failures preserve local
play and converge without duplicate effects.

**Plan phase:** L2 in [`LOCAL_BACKEND_INTEGRATION.md`](LOCAL_BACKEND_INTEGRATION.md)

**Depends on:** `GAME-005`

**Acceptance criteria:**

- Request timeout, response loss, app kill, API restart, database outage, `429`, and retryable
  `5xx` cases persist retry state and replay the identical payload/idempotency tuple.
- A `401` performs at most one refresh/replay and unknown refresh outcomes do not reuse a rotating
  credential.
- Cursor conflict fetches remote state and reconciles before retry.
- Disabling v2 ingestion never blocks local play; re-enabling it later drains the journal.
- Overspend adjustments clamp the affected asset without rolling back completed campaign levels.
- Diagnostics expose stable error and correlation identifiers but no tokens, signatures, request
  bodies, or secret paths.

## GAME-007 — Add a shared authenticated backend transport

**Type:** Networking/Foundation
**Status:** Planned
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

## GAME-008 — Integrate the backend Shop catalog locally

**Type:** Commerce read integration
**Status:** Planned
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

## GAME-009 — Integrate backend leaderboards locally

**Type:** Ranking read integration
**Status:** Planned
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

## GAME-010 — Automate the Android local-backend integration gate

**Type:** Tooling/Verification
**Status:** Planned
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
