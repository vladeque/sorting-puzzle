# Local Backend Integration Plan

Status: Proposed

Target: Godot Android debug build running in an Android emulator and connecting to the sibling
backend repository on the development machine.

The successor plan for a deployed shared development environment, Android and iOS platform
identity, and store sandbox integration is
[`DEV_BACKEND_INTEGRATION_PLAN.md`](DEV_BACKEND_INTEGRATION_PLAN.md).

## Goal

Prove the launch client/backend path locally before adding production deployment, platform
identity, or real-money store integrations. The completed slice must use the real PostgreSQL-backed
API, real bearer/refresh sessions, the Android Keystore-backed installation key, and protocol v2
save synchronization.

The local backend remains a recovery and merge destination. It must not become a requirement for
installed campaign play, local rewards, lives, or local spending.

## Daily one-click Android workflow

For routine development on the configured Windows workstation, double-click:

```text
run_android_local_development.cmd
```

The equivalent terminal command is:

```powershell
.\scripts\tools\run_android_local_development.ps1
```

The launcher uses the confirmed `sorting-puzzle-api36` AVD, Godot at `D:\Godot\godot.exe`, and the
sibling `../sorting-puzzle-backend` checkout by default. It starts or reuses the emulator, starts
the backend PostgreSQL Compose service with its persistent named volume, reuses or creates the
ignored persistent backend secrets, applies migrations and the idempotent development bootstrap,
starts or reuses the API, exports the debug APK, installs it, and opens the game. It verifies the
debug override, `/health/live`, and Android secure-store bridge through logcat before reporting
success.

The emulator, PostgreSQL container, and API remain running after the command finishes. Re-running
the command preserves the emulator's app data, backend database, and signing/encryption secrets.
It does not run the destructive/disposable GAME-010 integration scenario and never clears app data.
Use `-SkipInstall` or `-SkipPluginBuild` only when the corresponding dependencies/artifacts are
known to be current. Other AVDs, tool paths, sibling paths, and host API ports can be passed through
the script parameters.

Prerequisites:

- Godot 4.6.2 with the Android build template already installed for this project.
- Android SDK with platform-tools, emulator, and the named AVD.
- JDK 17 and Android SDK Platform 36 for the secure-store plugin.
- Node.js 24, pnpm 11, and a running Docker Engine with Compose v2.

If launch fails, the error identifies its phase. Backend process logs created by the launcher are
under ignored `build/local-development/`. The double-click wrapper pauses on failure so the error
remains visible. If port 8080 is already owned by another service, stop it or pass an unused
`-ApiPort`; emulator tcp:8080 is still mapped to that host port with `adb reverse`.

## Confirmed baseline

### Game repository

- `GAME-001` already implements crash-safe local saves, guest registration orchestration, rotating
  session handling, signed protocol v2 operations, cursor reconciliation, and background retry.
- Synchronization is disabled by default because `application/config/backend_base_url` is empty and
  `application/config/save_sync_v2_enabled` is `false`.
- Desktop Godot deliberately cannot synchronize. The real signing and secure-session contract is
  implemented by the Android and iOS native bridge sources.
- The Android bridge source exists. As of `GAME-003` (2026-07-24), the checked-in Android export
  preset and Godot Android plugin (`addons/sorting_puzzle_secure_store_bridge/`) have been built
  and verified against a live local backend in an Android emulator.
- Leaderboards and the Shop still select mock providers. `GAME-007` added a shared authenticated
  read transport and closed protocol adapters (`scripts/backend/backend_transport.gd`,
  `scripts/backend/backend_read_operations.gd`) for these features, but no provider yet uses it;
  that is `GAME-008` (catalog) and `GAME-009` (leaderboards).

### Backend repository

- Guest challenge/bootstrap, rotating sessions, authenticated player reads, protocol v2 save
  state/sync, catalog reads, purchase intents, and leaderboard reads are implemented.
- PostgreSQL migrations create schema only. A fresh local database has no active development game
  configuration or Shop catalog.
- Product authentication is unavailable unless an ignored local secret root contains valid token,
  offline-lease, and data-encryption keyrings.
- Protocol v2 validates campaign operation provenance against published immutable configuration,
  level, and rules IDs.
- The current launch candidate contains levels 1-8 only. Client levels 9 and 10 both declare
  campaign level `1`, so they cannot be published as unique campaign levels.
- The deterministic replay validator is dormant under ADR 0019 and must not be added to this
  integration.

## Material gaps to close

1. **Reproducible local backend bootstrap**
   - Generate ignored development-only signing/encryption secrets without printing them.
   - Start PostgreSQL, apply migrations, publish and activate a development game configuration,
     publish and activate a development Shop catalog, and enable both v2 save feature flags.
   - Make the process idempotent so restarting development does not create conflicting content,
     keys, or active pointers.

2. **Shared immutable content provenance**
   - Replace `client-bundled-2026-07-23`, `triple-sort-rules-1`, and
     `level-%03d-client-1` as protocol provenance.
   - Generate a client manifest from the same canonical publication operation used to seed the
     backend. It must map each bundled campaign level to the exact opaque
     `configuration_version`, `level_version`, and `rules_version`.
   - Load the generated manifest in `PlayerProgress` when creating campaign operations. Missing or
     mismatched provenance must fail locally with a diagnostic instead of uploading an invalid
     operation forever.
   - Verify authored source hashes before export. Exported runtime validation must use the
     manifest's schema/self-digest/publication mapping and must not depend on raw `.gd`/`.tscn`
     files that Godot compiles or remaps.
   - For the first slice, publish levels 1-8 and constrain integration tests to those levels.
     Correct and validate levels 9-10 before claiming full bundled-campaign coverage.

3. **Android debug packaging and host networking**
   - Build the existing secure-store AAR with JDK 17 and Android SDK 36.
   - Package and enable it as a Godot Android v2 plugin with Gradle Build.
   - Add an Android debug export preset with Internet permission and debug-only cleartext HTTP.
   - Standardize local routing through `adb reverse tcp:8080 tcp:8080`, using
     `http://127.0.0.1:8080` inside the emulator. Document `10.0.2.2:8080` as the fallback.
   - Keep committed release defaults safe: empty backend URL, synchronization off, and no
     development secret or host address embedded in release exports.

4. **Authenticated Godot transport boundary**
   - Add one focused client transport/service layer for request metadata, bearer headers,
     correlation IDs, response-envelope checks, structured errors, timeouts, retry classification,
     `Retry-After`, and one refresh/replay attempt.
   - Keep operation-specific adapters responsible for closed request writers and tolerant response
     readers. Unknown response enum values map to `unknown`; unknown additive response fields are
     ignored.
   - Reuse `SecureSessionStore` for tokens. Never copy credentials into local gameplay saves,
     ordinary logs, screenshots, test artifacts, or UI error strings.
   - Introduce the shared transport without changing the already-correct rule that mutation retries
     retain the identical body and idempotency key.

5. **Protocol v2 save end-to-end validation**
   - Exercise the existing guest challenge, guest bootstrap, one-time namespace rebind,
     `GET /v2/saves/state`, `POST /v2/saves/sync`, cursor acknowledgement, checkpoint application,
     refresh, and persisted retry paths against the real API and PostgreSQL.
   - Verify real P-256 signatures generated by Android Keystore, including operation-domain
     separation and the guest-registration proof payload.
   - Treat any behavior found missing in the existing `GAME-001` implementation as a focused
     correction, not a second save system.

6. **Read-only backend features**
   - Add a backend leaderboard provider under `scripts/leaderboards/` for
     `GET /v1/leaderboards/{weekly|country|world}` with limit/cursor normalization, current-player
     pinning, cached last-successful data, offline fallback, and silent refresh after save sync.
   - Add a server-catalog source for `GET /v1/catalog`. For local development, join eligible
     backend offers with the existing mock store's formatted regional prices.
   - Keep local mock purchasing explicitly development-only. Do not call purchase-intent or
     verification endpoints and do not represent mock grants as verified server purchases.
   - Do not add a separate profile mutation path for ordinary v2 profile edits; those already flow
     through the local journal. The server checkpoint remains the reconciliation source.

7. **Backend v2 leaderboard materialization**
   - Confirm that a v2 selected campaign completion updates the tables queried by
     `GET /v1/leaderboards/*`.
   - The current save-sync path creates a `save.checkpoint_merged.v1` outbox event, while the
     existing leaderboard store is centered on accepted run completions. Add the missing
     idempotent projection or equivalent query path before declaring leaderboard integration
     complete.
   - Derive score only from selected unique checkpoint completions. Never trust an uploaded
     lifetime, weekly, reward-chest, or ranking balance.

## Delivery sequence

### Phase L0 - Make the backend locally bootable

Owner: backend repository

Tracking: create a focused backend-local bootstrap ticket in the backend backlog. This work is not
owned by a `GAME-*` ticket.

Deliverables:

- An ignored local-secret generator and a documented `SORTING_PUZZLE_SECRET_ROOT`.
- An idempotent local bootstrap command that applies migrations and publishes/activates:
  - development gameplay/economy/reward configuration;
  - protocol v2 ingestion and recovery flags;
  - client support for Android debug build 1; and
  - a development Shop catalog.
- A generated client provenance manifest plus a digest/check command.
- Updated backend `docs/LOCAL_DEVELOPMENT.md`.

Exit gate:

- From a clean database and no existing local secrets, documented commands result in
  `GET /health/ready` returning ready and guest bootstrap being able to issue a real session.
- Running the bootstrap command twice makes no semantic changes.

### Phase L1 - Produce a backend-enabled Android debug build

Owner: game repository

Tracking: `GAME-002` and `GAME-003`.

Status: `GAME-002` complete on 2026-07-24. `GAME-003` complete and emulator-verified on
2026-07-24.

Deliverables:

- Packaged Android secure-store plugin and debug export preset.
- Local-only configuration mechanism for backend URL and sync enablement.
- `adb reverse` setup and an emulator smoke command/checklist.
- Client provenance manifest loader and removal of synthetic operation IDs.

Exit gate:

- The emulator reports `SortingPuzzleSecureStoreBridge` available. Verified by the GAME-003 smoke
  check.
- The bridge exposes signing operations but no private-key export API; smoke diagnostics contain no
  token, signature, or key material. Persistence/security behavior remains part of the later
  identity device-test gate.
- A debug build reaches `/health/live` through `adb reverse` and receives HTTP 200. Verified by the
  GAME-003 smoke check.
- A release/default run still has network integration disabled. Committed `project.godot` keeps
  `backend_base_url` empty and `save_sync_v2_enabled` false; the local override is gitignored,
  injected only into debug exports, and applied only when `OS.is_debug_build()` is true.

### Phase L2 - Prove identity and cloud-save synchronization

Owner: game repository with backend fixtures and local stack

Tracking: `GAME-004`, `GAME-005`, and `GAME-006`.

Status: `GAME-004` implemented and gap-tested on 2026-07-24 (live device end-to-end proof blocked
by an emulator `HTTPRequest` POST issue; see the ticket entry). `GAME-005` implemented and
gap-tested on 2026-07-25 -- the server/database half of protocol-v2 save synchronization is proven
directly against a real running local backend and PostgreSQL; the same emulator POST issue blocks a
live Godot-client-driven proof. `GAME-006` implemented and gap-tested on 2026-07-25 -- every
reliability behavior this phase requires (persisted-replay retry, single-refresh guard, cursor-
conflict reconciliation, feature-flag gating, overspend clamp, secret-free diagnostics) was already
correctly implemented by `GAME-001`/`GAME-004`/`GAME-005`; no production defect was found, only test
coverage was missing.

Deliverables:

- Real guest bootstrap and secure session persistence across app process restart.
- Initial local journal upload, server checkpoint receipt, cursor advancement, and local
  reconciliation.
- Test controls or a fault proxy for response loss, API outage, malformed response, `401`,
  `409`, `429`, and retryable `5xx` cases.
- Non-secret integration diagnostics for player namespace, device ID, generation, cursor,
  retry state, error code, and correlation ID.

Exit gate:

- Complete a level while disconnected, spend a resource, edit the profile, reconnect, and observe
  one deterministic merged checkpoint with no duplicate grants.
- Kill the app after request send and before response handling; restart and confirm the identical
  request/idempotency tuple is replayed.
- Force access-token expiry and confirm one refresh plus one request replay.
- Disable v2 ingestion, continue playing locally, re-enable it, and synchronize later.
- All existing headless save tests and backend v2 fixtures continue to pass.

### Phase L3 - Integrate catalog and leaderboards

Owner: both repositories

Tracking: `GAME-007`, `GAME-008`, and `GAME-009`, plus a focused backend ticket for protocol-v2
checkpoint-to-leaderboard materialization.

Status: `GAME-007` implemented on 2026-07-25 -- the shared authenticated read transport
(`scripts/backend/backend_transport.gd`) and its closed protocol adapters
(`scripts/backend/backend_read_operations.gd`) exist and are proven against the real backend
contract fixtures plus synthetic transport-fault coverage (`tests/backend/test_game_007.gd`).
`GAME-008` implemented on 2026-07-25 -- `application/config/shop_catalog_source=backend` sources
Shop offers from `GET /v1/catalog` (`scripts/store/backend_catalog_source.gd`), joins them against
`configs/backend/shop_catalog_prices.json` for local/mock pricing, and caches the last successful
join for offline display (`scripts/store/backend_catalog_cache.gd`); mock remains the default and
purchase execution stays local/mock regardless of catalog source (`tests/backend/test_game_008.gd`).
`GAME-009` implemented on 2026-07-25 -- `application/config/leaderboard_provider=backend` sources
Weekly/Country/World pages from `GET /v1/leaderboards/{scope}`
(`scripts/leaderboards/backend_leaderboard_provider.gd`) through the same shared transport, passing
entries/current-player placement/period end/pagination cursor through unchanged, and caches the last
successful page per scope for offline display
(`scripts/leaderboards/backend_leaderboard_cache.gd`); mock remains the default and the existing
leaderboard screen is unchanged (`tests/backend/test_game_009.gd`). The backend-owned v2
checkpoint-to-leaderboard materialization gap (item 7 below) is not closed by this ticket, so
deterministic cross-player score ordering cannot yet be proven against a real running backend.

Deliverables:

- Shared authenticated Godot transport used by server catalog and leaderboard adapters.
- Backend-backed provider selections for local debug builds; mock remains the safe default.
- Cached/offline leaderboard behavior and normalized backend error states.
- Idempotent v2 checkpoint-to-leaderboard projection.

Exit gate:

- The Shop renders the active backend development catalog with mock regional price strings and
  does not expose ineligible offers.
- Two locally created players synchronize distinct scores and appear in the expected weekly/world
  ordering after projection.
- Country scope handles the guest/no-country case using the backend's documented response rather
  than client inference.
- Cursor pagination, current-player pinning, empty rankings, offline cache, and retryable failures
  are covered.

### Phase L4 - Automate the local integration gate

Owner: both repositories

Tracking: `GAME-010`, with any backend-owned orchestration support committed separately.

Status: implemented and backend-gate verified on 2026-07-26. The full Android exit remains blocked
on the current emulator by the GAME-004/005 `HTTPRequest` POST-with-body issue. From the game
repository on Windows, run:

```powershell
.\scripts\tools\run_local_backend_integration_gate.ps1
```

The default command is intentionally destructive only to the fixed local database
`sorting_puzzle_game010`, the generated ignored secret directory `local-secrets/game010`, and the
Sorting Puzzle package's emulator app data. It restores any existing ignored
`local/backend_debug.cfg` after the run. Use `-SkipInstall` only after the backend pnpm workspace is
installed. `-SkipAndroid` is a contract/backend diagnostic subset and does not satisfy the full L4
exit gate. `-KeepIntegrationDatabase` is an explicit troubleshooting choice. Port 8080 is the
default; if another local API already owns it, pass an unused `-ApiPort` (the runner maps emulator
tcp:8080 to that host port with `adb reverse` and refuses to reuse an occupied listener).

Deliverables:

- One documented command or orchestration script to start PostgreSQL, migrate/bootstrap data,
  start the API, wait for readiness, configure `adb reverse`, install the debug APK, and run the
  smoke scenario.
- Godot fixture runners for the v1, v1.1, and v2 contract manifests.
- Backend assertions for persisted player/device/session, save stream/cursor/checkpoint, outbox,
  and leaderboard projection state.
- Cleanup that removes only explicitly named local test players/data or recreates a dedicated
  disposable integration database.

Exit gate:

- The clean-start scenario is repeatable on a developer workstation.
- Failures report the phase, stable error code, and correlation ID without leaking tokens,
  signatures, request bodies, or secret paths.
- Client and backend commits remain separate and reference the corresponding content manifest and
  fixture versions.

The fixture versions currently pinned by the gate are protocol v1 `1.0.0`, v1.1 `1.1.6`, and v2
`save-sync-fixtures/1`. Successful output also records the active content configuration version
and bundled manifest SHA-256. Troubleshooting artifacts are under ignored `build/game010/`; the
top-level failure line identifies the phase, stable `game010.<phase>.failed` code, and run
correlation ID without echoing credentials, bearer/refresh tokens, signatures, request bodies, or
the secret root.

Development publications are intentionally ranking-ineligible. The backend preparation phase
therefore adds one production-eligible publication and one bounded projection checkpoint for each
of the same two explicitly named fixture players, only inside `sorting_puzzle_game010`. This proves
the real worker/outbox/leaderboard path without weakening environment isolation or changing the
real development save checkpoints, cursor assertions, or bundled manifest.

## Local test matrix

| Area | Required local cases |
| --- | --- |
| Bootstrap | New guest, repeated challenge, expired challenge, duplicate identical bootstrap |
| Session | Process restart, access expiry, successful rotation, invalid/reused refresh token |
| Save | Empty sync, single operation, multi-operation batch, multi-batch continuation |
| Reliability | Offline start, request timeout, response loss, API restart, database outage |
| Conflict | Cursor mismatch, duplicate operation, changed idempotency fingerprint, overspend clamp |
| Recovery | Fetch remote state, apply checkpoint, retain operations after acknowledged cursor |
| Profile | Name edit, avatar edit, moderation value from checkpoint, invalid local value rejection |
| Catalog | Eligible/ineligible offers, no active catalog, mock price join, offline cached display |
| Ranking | Weekly/world/country, ties, current player outside page, empty page, cursor expiry |
| Security | Real signature verification, session binding mismatch, redacted diagnostics |

## Explicitly deferred

- Cloud Run, Cloud SQL, Secret Manager, Pub/Sub deployment, production DNS/TLS, and production
  observability.
- Google Play Games and Game Center authentication, account linking, guest promotion to a platform
  account, account merging, account switching, and clean-install cloud recovery.
- Google Play Billing, StoreKit, purchase intents, purchase verification, provider notifications,
  refunds, reconciliation, and durable entitlements.
- Play Integrity, App Attest, production rate-limit tuning, moderation/reporting UI, account
  deletion/export UI, and administration surfaces.
- Re-enabling deterministic gameplay replay/proof generation or the legacy v1.3 lease path.
- iOS export and Keychain verification.

These are deferred, not designed around. The shared transport, session, content-provenance, and
provider boundaries created locally must remain suitable for their later implementations.

## Recommended first implementation batch

Implement the backend Phase L0 ticket first, followed by `GAME-002` and `GAME-003`. They are the
critical path: until the backend has active development content, the game has matching provenance,
and the emulator can sign and reach the API, higher-level client adapters cannot be tested against
reality.

Do not begin Shop purchase integration during this batch. Complete `GAME-004` through `GAME-006`
for real guest-and-save synchronization and recovery, then add the read-only transport, catalog,
and leaderboard tickets.
