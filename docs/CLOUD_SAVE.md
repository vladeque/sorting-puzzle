# Local-first saves and cloud recovery

`GAME-001` makes local persistence always active. Campaign play, ordinary rewards, resource
spending, lives, profiles, and installed content never wait for connectivity. The BE-307 v2 backend
is an asynchronous recovery/merge destination, not an alternative runtime save provider.

## Ownership

- `scripts/player_progress.gd`: gameplay-facing facade and checkpoint-to-gameplay mapping.
- `scripts/save/local_save_store.gd`: schema validation, atomic generations, journal append,
  checkpoint transactions, compaction, recovery, and schema-4 migration.
- `scripts/save/local_save_codec.gd`: canonical JSON, SHA-256, UUIDs, timestamps, and namespace keys.
- `scripts/save/secure_session_store.gd`: focused bridge adapter for installation signing keys and
  player sessions.
- `scripts/save/guest_session_bootstrap_service.gd`: persisted protocol-1.1 guest challenge,
  installation proof, idempotent bootstrap, and coordinator handoff.
- `scripts/save/save_sync_service.gd`: v2 batching, identical-request idempotency, connectivity
  failure handling, refresh hooks, persisted full-jitter retry, cursors, and reconciliation.
- `scripts/save/account_save_coordinator.gd`: installation guest bootstrap, one-time guest rebind,
  player namespace switching, sign-out, and clean-install restore selection.
- `platform/android/secure-store-plugin/`: Godot Android plugin v2 source using Android Keystore.
- `platform/ios/secure-store-plugin/`: Godot iOS `.gdip` plugin source using Keychain.
- `addons/sorting_puzzle_secure_store_bridge/`: GAME-003 `EditorExportPlugin` that packages the
  built Android secure-store AAR into Gradle-build exports.
- `scripts/save/local_backend_debug_bootstrap.gd`: GAME-003 local-only, debug-build-only backend
  URL/sync override loader (`local/backend_debug.cfg`; see `docs/CONFIGS.md`) and, for GAME-004, a
  periodic non-secret identity/save-sync diagnostics log line for emulator verification.

The old scripts under `scripts/save_providers/` remain only as legacy migration/test adapters.
Release gameplay no longer reads `application/config/save_provider` and must not switch to a
cloud-only runtime save.

## Local schema and files

Every account has a separate directory:

```text
user://save_v2/guest_<installation_id>/
user://save_v2/player_<player_id>/
```

Each `sorting-puzzle-local-save/1` generation contains four explicit partitions:

1. `snapshot`: the current gameplay-facing state;
2. `journal`: ordered BE-307 `save-operation/2` operations;
3. `sync`: device cursor, hash-chain head, retry request, checkpoint, adjustments, and migration
   metadata;
4. `preferences`: device-only music, sound-effect, and vibration state.

The snapshot stores `completion_stars_by_level` as the explicit source of truth for completed
global level IDs and `selected_chapter_id` as a device preference. `current_level` and
`highest_completed_level` remain compatibility summaries. Checkpoint recovery rebuilds the
explicit completion map from `campaign.selected_completions`, so chapter-shaped progress does not
depend on one contiguous campaign cursor.

`current.json`, `previous.json`, and `pending.tmp` implement temporary-write, flush, validate,
previous-generation rotation, and atomic promotion. Startup validates every checksum and journal
hash, then selects the highest fully valid generation. A partial write or corrupt newest generation
therefore recovers a valid generation instead of silently resetting progress.

Journal operations use a UUID, strictly increasing per-device sequence, closed versioned payload,
configuration/level/rules provenance where applicable, previous hash, canonical SHA-256 hash, and
P-256 signature. These fields detect corruption and casual editing; they are not represented as
proof that gameplay occurred.

## Legacy migration

On the first local-first launch, `PlayerProgress` sanitizes schema-4
`user://player_progress.json`, splits settings into `preferences`, and creates generation 1 in the
stable installation guest namespace. The original JSON is copied to
`legacy_v4.previous.json` inside that namespace and retained read-only.

Migration metadata becomes complete only after the local-first generation is loaded and validated
on a later restart. Repeating migration or restarting during any atomic-save stage is idempotent.
The legacy blob is never uploaded as a balance replacement.

## Immediate gameplay transaction path

The following mutations update the snapshot and append their operation(s) in one recoverable local
generation:

- campaign completion, reward-chest rollover/coins, lifetime stars, weekly stars, and reward
  animation metadata;
- campaign failure/leave plus the resulting life state;
- coin and ability spending;
- automatic life restoration observations;
- avatar and display-name edits.

Level completion is not shown until `PlayerProgress.complete_level()` confirms the atomic commit.
That method accepts only the first incomplete level in an unlocked chapter and rejects an already
completed level, so production campaign levels are not replayable. Chapter unlock state is derived
from distinct completions in the immediately previous chapter; the default threshold is 25.
Ability and coin spending are committed after a successful preflight and before starting the
gameplay effect. Connectivity does not choose a different mutation path.

Verified purchase/refund facts are server-originated and idempotent. The development-only mock
store retains its schema-4 processed-transaction ledger, but production store code must never call
`apply_shop_purchase()` with client-invented rewards.

## Secure identity bridge

The gameplay save contains public installation/device/player identifiers only. It never contains
installation private keys, access/refresh tokens, platform credentials, or raw store evidence.

The `SortingPuzzleSecureStoreBridge` contract is:

- `ensure_installation_key(installation_id) -> bool`
- `set_installation_id(installation_id) -> bool`
- `get_installation_public_key_der(installation_id) -> String`
- `sign_save_operation_hash(operation_hash) -> String`
- `sign_installation_payload(payload) -> String`
- `store_player_session(player_id, session_json) -> bool`
- `load_player_session(player_id) -> String`
- `clear_player_session(player_id) -> bool`

Android keeps P-256/AES keys in Android Keystore and only AES-GCM ciphertext in private
SharedPreferences. iOS keeps the P-256 key and session JSON in Keychain using
`AfterFirstUnlockThisDeviceOnly`. Desktop builds create schema-shaped development signatures for
crash tests, but `can_synchronize()` remains false and those signatures are never sent to the
backend.

## Background synchronization

Synchronization is enabled only when all of these are true:

- `application/config/save_sync_v2_enabled` is `true`;
- `application/config/backend_base_url` is non-empty;
- a player namespace and secure session are active;
- the mobile secure bridge can sign operations.

While the installation guest namespace is active, the same gate starts
`POST /v1/sessions/guest/challenge` followed by `POST /v1/sessions/guest`. The challenge request and
the final bootstrap payload/idempotency key are persisted before transport. The bridge signs the
exact `guest-registration-proof/1` JSON array with the installation key; only its DER public key is
sent. A validated bootstrap response stores its session securely and asks
`AccountSaveCoordinator` to rebind the guest journal to the returned immutable `player_id`.

`POST /v2/saves/sync` sends at most 500 operations and 1 MiB. The exact JSON payload, request UUID,
and `Idempotency-Key` are stored before transport; timeout, response loss, force-close, or reboot
replays those identical values. Eligible failures use persisted full-jitter exponential backoff,
`Retry-After` takes precedence, and no retry blocks scene changes.

An access-token `401` permits one rotating-refresh attempt and then replays the still-identical
save request. Because refresh tokens are single-use, an unknown refresh transport outcome is
recorded as a non-secret terminal authentication diagnostic rather than risking credential reuse
and session-family revocation.

Successful responses validate the protocol/request/device/player binding, apply the merged
checkpoint and cursor atomically, replay only local operations beyond the acknowledged cursor, and
retain the latest 100 acknowledged operations for recovery/support. Cursor conflicts fetch
`GET /v2/saves/state` and reconcile before retry. Merge adjustments are retained in diagnostics;
ordinary UI simply shows the reconciled zero-floor amount.

The feature flag may be turned off without changing local play. The client never downgrades its v2
journal into the legacy provisional lease protocol.

## Account switching and recovery

The active namespace is persisted separately from all account payloads. Switching:

1. leaves the current valid generation and unsynchronized journal intact;
2. activates only the selected player directory, or a fresh player bootstrap;
3. applies a remote checkpoint only for the matching immutable `player_id`;
4. replays that player's later local journal entries.

An installation guest namespace can be rebound exactly once after guest registration. Repeating
the same binding reopens the existing player generation and cannot replace newer player progress.
Sign-out activates the installation guest namespace without deleting any player namespace. No routine sync
path opens modal UI; a future destructive/ambiguous platform-identity merge must use a dedicated
dialog scene.

## Support and release verification

`PlayerProgress.get_local_save_diagnostics()` exposes non-secret namespace, device id, generation,
journal head/cursor, retry count, terminal error code, last server correlation id, guest
registration phase/retry/terminal error, adjustment count, migration state, and content-manifest
validity/digest/environment/diagnostic. Never request gameplay-save files, tokens, private keys, or
screenshots of platform credentials from players.

`GuestSessionBootstrapService` and `SaveSyncService` record the server's `meta.correlation_id` from
every parsed response alongside their own stable error codes (`sync.guest_registration.terminal_error`,
`sync.terminal_error`, `sync.last_correlation_id`, `sync.identity_diagnostics`). This is the
non-secret identity/session diagnostic surface GAME-004 requires; it never stores tokens,
signatures, or request bodies.

`ContentProvenanceManifest` validates
`configs/backend/content_provenance.json` before `PlayerProgress` configures guest bootstrap or save
synchronization. Runtime validation covers the packaged manifest's schema, digest, immutable
publication identity, and complete level mapping; raw authored source hashes are checked by the
mandatory pre-export command because Godot compiles/remaps `.gd`/`.tscn` files in exported builds.
A missing, incomplete, digest-mismatched, or provenance-invalid packaged manifest fails closed for
networking but does not block snapshot commits or campaign play. Campaign levels outside the
manifest remain local and do not append an uploadable completion/attempt operation.

Support sequence:

1. Confirm the active namespace and that migration completed.
2. Compare journal head with acknowledged cursor.
3. If retry count grows, check feature capability, session refresh, HTTP status, and platform
   connectivity without deleting local data.
4. If checksum recovery occurred, preserve `current.json`, `previous.json`, and `pending.tmp` for
   engineering; do not reset progress.
5. For account mismatch, switch to the intended identity; never copy another namespace's snapshot.

Automated verification:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/save/test_game_001.gd -GodotArguments '--verbose'
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/save/test_game_002.gd -GodotArguments '--verbose'
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/save/test_player_progress_facade.gd -GodotArguments '--verbose'
& .\scripts\tools\run_isolated_godot_test.ps1 -Script scripts/tools/check_content_provenance.gd
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/save/test_local_backend_debug_bootstrap.gd -GodotArguments '--verbose'
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/save/test_game_004.gd -GodotArguments '--verbose'
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/save/test_game_005.gd -GodotArguments '--verbose'
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/save/test_game_006.gd -GodotArguments '--verbose'
pnpm --dir ..\sorting-puzzle-backend check:development-client-manifest
```

`tests/save/test_game_004.gd` drives `GuestSessionBootstrapService._on_request_completed` and
`SaveSyncService._on_request_completed` directly with malformed, expired-challenge, replayed
(`auth.refresh_reuse_detected`), and device-binding-mismatched response bodies, and proves the
one-time guest rebind and the single-refresh-attempt guard survive a simulated app restart
(`AccountSaveCoordinator` reopened against the same installation).

`tests/save/test_game_006.gd` (GAME-006) feeds `SaveSyncService._on_request_completed` every
non-success `HTTPRequest.Result` (timeout, response loss, connection refused) plus `429`/`500`/`503`
and confirms the identical pending payload/idempotency tuple persists and replays, including across
a simulated app kill/restart; drives a full `401` -> refresh -> replay round trip plus the
transport-failure-during-refresh (`auth.refresh_result_unknown`) path GAME-004 did not exercise;
drives a `409 save_sync.cursor_mismatch` through the real `GET /v2/saves/state` fetch-and-reconcile
flow; proves the v2 feature flag never blocks a local commit and that re-enabling it drains the
accumulated journal in one request; calls `PlayerProgress._map_checkpoint_to_snapshot` directly (the
real mapper, not the no-op one other suites use) to prove an overspend clamp never rolls back
completed campaign levels; and confirms `get_local_save_diagnostics()` never serializes an injected
access token, refresh token, signature, or raw request body.

Android release verification requires JDK 17, Android SDK 36, the Gradle export path, and physical
device tests for Keystore, airplane-mode transitions, process death/reboot, account switching, and
uninstall/reinstall. iOS verification requires macOS/Xcode, a device/simulator xcframework, and the
corresponding Keychain/background/account tests. These device matrices are release gates; Windows
headless tests do not claim to replace them.

GAME-003 packages that same Android bridge into a debug-only local-backend export. See
`platform/android/secure-store-plugin/README.md` for the build/export/`adb reverse` workflow and
`scripts/tools/android_local_backend_smoke_check.ps1` for the emulator smoke check. On 2026-07-24,
the debug AAR/APK were built and the smoke check passed against a live local backend; release
security/persistence behavior still belongs to the broader device matrix above.

GAME-004 exercised that same debug build against the real guest challenge/bootstrap and
rotating-refresh endpoints and found two real defects, both fixed on 2026-07-24: `SecureSessionStore`
gated every Android bridge call behind `_bridge.has_method(...)`, which returned `false` on-device
for a bridge that genuinely worked, silently disabling synchronization; and
`application/config/version` was never declared in `project.godot`, so every protocol request's
`meta.app.version` was empty and failed backend schema validation. `scripts/tools/
android_local_backend_identity_smoke_check.ps1` automates the intended end-to-end proof (real
bootstrap, then kill/restart resumption), but a device/emulator `HTTPRequest` POST-with-body
reliability issue on this workstation (GET requests always completed; POST requests intermittently
never signaled completion, even past their own timeout) prevented a full live observation as of
that date -- see the GAME-004 entry in `docs/IMPLEMENTATION_TICKETS.md` for details. The malformed,
expired-challenge, replayed, and device-binding-mismatched response handling this ticket also
requires is proven by `tests/save/test_game_004.gd` independently of that device flakiness.
