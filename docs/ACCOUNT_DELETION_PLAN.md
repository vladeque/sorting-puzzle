# In-game account deletion implementation plan

Status: **Implemented; Android emulator and local-backend validation done.** Batches 1-4 are
complete. Open release gates: compile and device-test the iOS Keychain bridge, test on a physical
Android device, schedule the backend deletion worker, configure a real support e-mail, and commit a
regenerated backend launch candidate (see batch 4).

Date: 2026-10-02

Client ticket: GAME-012. Backend dependency: BE-607, implemented in sibling commit `24e18d6`.

## Scope and confirmed product decisions

Add account deletion to the existing Main Menu > Settings > Support route. Support currently uses
the full-screen `scenes/ui/support_screen.tscn` overlay. The destructive confirmation and result
will use a dedicated modal scene above it, with its own focused script.

The owner confirmed these decisions during planning:

- After acceptance and successful local cleanup, show confirmation and offer **Start a new game**.
  Do not automatically create another account or resume gameplay.
- If a sent request cannot be confirmed before its retry credential expires, keep the old account
  locked and show **Deletion status unconfirmed**, with a support option. Do not offer an ordinary
  local reset as a substitute for confirmed server deletion.
- For a proven never-registered installation, offer a separately labeled **Delete local game
  data** flow. Delete its local progress without creating a backend account, then offer
  **Start a new game**.

After the 2026-10-03 plan review, the owner also confirmed:

- Implement the batches in the order documented below. The server deletion path comes first,
  not a local-only slice, even though the local-only flow is the only one a committed release
  build reaches today (see [Current reachability](#current-reachability)).
- Implement iOS Keychain key destruction in this work, alongside Android, rather than deferring
  it to an iOS release. Both packaged native builds remain release gates.

This work is client-owned. Read the backend contracts and fixtures, but do not modify the sibling
repository, its canonical requirements, or the game repository's requirements snapshot. Data
export, a public deletion website, and unrelated account-management UI are separate work.

## Authoritative backend contract

References:

- [BE-607 account deletion](../../sorting-puzzle-backend/docs/ACCOUNT_DELETION.md)
- [ADR 0022](../../sorting-puzzle-backend/docs/adr/0022-immediate-account-deletion-with-lineage-anonymization.md)
- [Protocol boundary](../../sorting-puzzle-backend/docs/PROTOCOL_BOUNDARY.md)
- [Canonical v1 schema](../../sorting-puzzle-backend/packages/protocol/schemas/v1/protocol.schema.json)
- [v1.3 request fixture](../../sorting-puzzle-backend/contracts/fixtures/v1.3/account-deletion.request.json)
- [v1.3 response fixture](../../sorting-puzzle-backend/contracts/fixtures/v1.3/account-deletion.response.json)

Send authenticated `DELETE /v1/player/account` using protocol `1.3`, the standard mutation
envelope, `data: { "confirmed": true }`, and a UUID `Idempotency-Key`. Metadata includes a stable
request UUID, device/session binding, app/locale/time, and the authoritative
`expected_state_version`. The client's ordinary save synchronization remains protocol v2.1;
account deletion does not downgrade that save journal.

Success is HTTP **202 Accepted**, with `AccountDeletionResponseEnvelope`. Validate the response
metadata and the deletion request UUID, `kind: "deletion"`, status, creation/update timestamps,
and required `complete_by`. Ignore additive response fields and map unknown status values to
`unknown` as the protocol requires. An accepted response with an unknown status still revokes
access; do not resume the account.

Guest and platform-verified players are both eligible. Acceptance immediately revokes all server
sessions/devices, unlinks platform identities, and removes public leaderboard visibility.
Anonymization is asynchronous, with a 30-day completion deadline. There is no cooling-off period
or cancellation. Signing in with the same platform identity later creates an unrelated account.
Purchase history retained for accounting/refunds does not restore deleted rewards or ownership.

The acceptance also revokes the caller's session. The server permits an exact retry using the
original, still-unexpired access token for that session; the access-token lifetime is five minutes.
The usable retry window is the token's **remaining** lifetime, not five minutes from the click.
Normal refresh, bootstrap, and identity recovery must not run after a possibly accepted request.
After a validated 202, discard the deleted save, its secure session, installation signing key,
and device identity. Reusing the old installation key before worker cleanup causes an
`installation_binding_conflict`.

The backend's mutation fingerprint covers the operation, authenticated player, protocol version,
`expected_state_version`, and canonical `data`. Request ID, client time, correlation ID,
credentials, and retry count are excluded
([idempotent mutations](../../sorting-puzzle-backend/docs/IDEMPOTENT_PLAYER_MUTATIONS.md)). An
exact replay therefore needs the same idempotency key, expected state version, and session/device
binding; the envelope does not have to be byte-identical. The `409 state.version_conflict`
response carries `recovery.current_state_version`
([controller](../../sorting-puzzle-backend/apps/api/src/identity/account-deletion.controller.ts)).

## Current client gaps and ownership

| Owner | Planned responsibility |
| --- | --- |
| `scenes/ui/support_screen.tscn`, `scripts/support_screen.gd` | Add a clearly labeled account action, open the modal, and retain existing FAQ/contact behavior. |
| New `scenes/ui/account_deletion_modal.tscn`, `scripts/account_deletion_modal.gd` | Own confirmation, progress, failure, unconfirmed, cleanup-retry, and accepted result views, buttons, and signals. Reuse existing UI resources. |
| New `scripts/save/account_deletion_service.gd` | Own the durable deletion state machine, preflight, exact request retries, outcome classification, and cleanup orchestration. It must outlive the Support screen. |
| New `scripts/backend/account_deletion_operations.gd` | Own protocol-1.3 request construction and closed validation of the deletion response data. |
| `scripts/backend/backend_transport.gd` | Add an explicit DELETE path that accepts only 202, never refreshes, takes a caller-supplied request ID and idempotency key, refuses to send when the stored session is not the one bound to the operation, and reports whether any attempt may have reached the server. GET/POST behavior stays unchanged. |
| `scripts/save/secure_session_store.gd`, Android/iOS native secure-store bridges | Destroy the old installation key/binding and deleted player's credentials, then create fresh identifiers only when the player starts again. |
| `scripts/save/local_save_store.gd`, `scripts/save/account_save_coordinator.gd` | Perform scoped, repeatable removal of deleted-account generations and guest/legacy fallback data; create a clean namespace without migration from deleted progress. |
| `scripts/save/save_sync_service.gd`, `scripts/save/guest_session_bootstrap_service.gd` | Suspend network activity and invalidate stale callbacks while deletion is pending or cleanup is running. |
| `scripts/player_progress.gd` | Expose the focused service, enforce gameplay/write/account-switch gates, and initialize recovery before ordinary save/bootstrap/sync behavior. |
| `scripts/app_launch_router.gd`, `scripts/production_main_menu.gd` | Restore unresolved/accepted deletion UI on launch before the first-level auto-start; rebuild the menu only after an explicit new-game action. |
| Shop/leaderboard cache and provider owners | Erase old account-dependent cached data and reject late responses from the deleted identity. |

The current transport only exposes GET/POST and treats 200 as its POST success. Its automatic
401 refresh is unsuitable for a deletion with an uncertain outcome. The native bridges can clear
a player session, but have no installation-key destruction API. `sign_out()` retains player saves
and activates the old guest namespace, so it cannot implement deletion.

### Current reachability

The committed `project.godot` defaults leave `application/config/backend_base_url` empty and
`application/config/save_sync_v2_enabled` false. Guest registration requires both, plus the
secure-store bridge (`GuestSessionBootstrapService._can_register()`). A committed release build
therefore never registers, and every player there takes the **Delete local game data** flow.
Server deletion is reachable only through the local-backend debug target and the planned Google
Play internal-test configuration. Its tests must not depend on the release defaults.

No platform sign-in is wired yet: `switch_to_player()` and `sign_out()` have no callers outside
`PlayerProgress`/`AccountSaveCoordinator`, and `CloudSaveProvider` is unused. In practice the only
namespaces are the installation guest and the player namespace it is rebound to. Protection of
unrelated account namespaces is still required, as a guard with a test, for when sign-in lands.

## Player flow and proposed copy

1. Add a visible **Delete account** action after the Support FAQs. It should be easy to find and
   require an explicit tap; opening Support or expanding an FAQ must never submit deletion.
2. Open the dedicated confirmation modal. Explain that deletion is permanent, progress, coins,
   items, profile, and game entitlements become unavailable, and the same platform sign-in will
   start a new account. Explain that some records remain for accounting/security and that
   anonymization finishes by the deadline after acceptance.
3. Offer **Cancel** and **Delete my account**. Before submission, Back/cancel closes the modal
   without changing anything. A final deliberate confirmation is sufficient; no typed phrase or
   artificial delay is needed.
4. While submitting, show **Deleting account...**, disable duplicate actions, and block gameplay
   and account switching. Closing the app does not cancel a sent deletion request. Back must not
   return the player to an account whose deletion outcome is unresolved.
5. On validated acceptance, finish local cleanup before offering **Start a new game**. Suggested
   result: **Your account is no longer accessible. Your deletion request was accepted. Data
   removal is due by {complete_by}.** Do not describe pending anonymization as already complete.
6. **Start a new game** creates fresh installation/device UUIDs and a fresh key, activates the
   normal initial snapshot, and follows the existing first-time launch route. It may start local
   play while offline; ordinary guest registration resumes when available. Never import the
   deleted journal or automatically restore its platform identity/purchase history.

Keep only device language and music/sound/vibration preferences across a confirmed reset. Reset
account-bound chapter selection, tutorial state, reward notifications, and ad pacing/session
state. Existing English UI can use translation-aware strings in preparation for future catalogs.

For an existing server account, lack of connectivity must show **Connect to the internet to
delete your account** and leave its save intact. The action should remain visible. Missing backend
configuration, credentials, or native cleanup support must explain the unavailable capability
before sending a destructive request.

For a proven never-registered installation, label the Support action and confirmation **Delete
local game data**, explain the local scope, and use the same durable cleanup and explicit restart
flow without HTTP. Report **Your local game data was deleted**, with no server receipt or
anonymization deadline. Persist the operation kind so restart recovery cannot confuse local
cleanup with an account deletion request. An empty player ID alone does not prove no server
account exists: if guest bootstrap was already sent and its response is unknown, resolve the
persisted registration operation before deciding which deletion flow applies. Registered guests
and temporarily signed-out/recoverable server accounts always use account deletion.

## Request safety and recovery

Persist an atomic, versioned deletion-operation record outside the account namespace before the
first send. It contains only public binding IDs (player, device, session), the request ID,
idempotency key, and expected state version, plus the phase, whether any attempt may have reached
the server, safe diagnostics, and the accepted receipt when available. Credentials remain in secure
storage. Use recoverable generations/checksums so a torn write cannot unlock a deleting account.

| Phase | Behavior |
| --- | --- |
| Confirmation / preflight | No deletion sent; cancellation or definite preparation failure can return to normal play. |
| Submitting / retrying | Persisted request may have reached the server; freeze old-account writes, refresh, sync, bootstrap, purchases, and switching. |
| Definitely rejected | Show a mapped error and resume only when the response establishes non-acceptance of this operation. |
| Outcome unconfirmed | Preserve the old save in quarantine; show status unconfirmed and support. No normal play, reauthentication, or new guest. |
| Accepted / cleaning | Persist the server receipt before destroying local files/credentials; retry incomplete cleanup on restart. Never reopen the old save. |
| Accepted / ready to start | Show the accepted result; no new identity or gameplay until **Start a new game**. |
| New-game activation | Persist restart intent and complete identity/namespace creation idempotently; a crash cannot create duplicate resets or reuse old identity files. |

Preflight must coordinate with in-flight sync, refresh, purchase, and ad operations, suppress new
work, and prevent old callbacks from committing. Local cancellation alone does not prove a server
mutation stopped. Obtain `expected_state_version` from a fresh authenticated player-state read
(`GET /v1/player/state`, as `scripts/ads/rewarded_life_client.gd` already does); do not use a
local generation/journal number or replace the local snapshot with this read.
Prepare a sufficiently fresh access credential before submission under the same exclusive flow.
The pending journal need not be uploaded before an irreversible deletion.

Transient retries reuse the persisted request ID, idempotency key, expected state version, and
original credential, with the protocol's bounded jitter/Retry-After policy. Never generate a new operation after a
timeout or rotate the credential in an attempt to discover whether deletion succeeded. A
malformed 202 also requires outcome resolution rather than silently resuming play.

A definitive first-request `409 state.version_conflict` permits a rebuilt request with a **new**
idempotency key and the response's `recovery.current_state_version` (a fresh state read only when
that value is missing): expected state version is part of the fingerprint and conflict outcomes
are retained. Bound this recovery; repeated conflicts return a visible retry
state. `idempotency.key_reused` is an implementation error, not a reason to bypass idempotency.
Map offline, 429, temporary dependency, authentication, unsupported-client, and validation errors
to useful UI without exposing raw tokens, payloads, or server internals.

After an ambiguous send, a later 401/refresh failure cannot establish whether deletion happened.
Attempt exact replay while the original token remains valid. When that window expires, use the
owner-selected locked fallback. The current backend has no durable post-revocation status API for
the client; do not invent one. Show the support route with a safe operation/correlation reference
and public player identifier where needed, never a token or save file. A future durable status
capability would require a separately scoped backend contract.

## Cleanup and native integration

Record acceptance durably before destructive cleanup. Cleanup must be idempotent and resumable;
an OS storage failure shows **Account deletion accepted; finishing cleanup** with retry. Do not
offer a fresh game while old data or key removal is incomplete.

Remove the deleted player's `current.json`, `previous.json`, `pending.tmp`, migrated legacy copy,
journal/checkpoint/retry state, and in-memory snapshot. Remove the old installation guest fallback
and its one-time rebind references, plus legacy `user://player_progress.json` if it could restore
this account. Clear active-namespace current/temp files and all current/temp/previous public
installation identity files. Ensure startup fallback/migration cannot resurrect deleted data.
Removal must stay within validated application-owned paths and target only the deleted account
and its known installation/legacy aliases; protect unrelated saved account namespaces.

Extend Android Keystore and iOS Keychain adapters with an explicit, idempotent installation-key
and binding destruction API. Wire it through the iOS header/Objective-C++ bindings and GDScript
adapter, return real failures, and clear the revoked player's access/refresh session. Preserve
unrelated account credentials; shared-key or device-binding consequences must be covered by
account-switch tests. Check native capability before submission, rebuild the Android AAR, and
verify the packaged iOS library exports the new bridge method.

Invalidate `user://shop_catalog_backend_cache.json`, `user://leaderboard_backend_cache.json`,
their in-memory providers, and account-dependent reward/offer/ad callbacks. Use an identity or
operation generation guard so a response started before cleanup cannot write deleted profile,
balance, eligibility, or session state back into the fresh account.

Startup must check the operation record before `PlayerProgress.load_progress()` can migrate
legacy state, restore lives, initialize old keys, register guests, or start sync. The launch router
must route unresolved/accepted phases to their dedicated result flow before its level-1 auto-start.

## Implementation batches and acceptance checks

1. **Transport and contract adapter.** Add DELETE/202 and exact replay with explicit refresh
   control. Add focused tests using the canonical v1.3 deletion goldens; regress existing shared
   GET/POST consumers. The isolated test runner copies the project into `%TEMP%`, where
   `res://../sorting-puzzle-backend` does not resolve, so keep client copies of the two goldens
   under `tests/fixtures/` and compare them with the sibling repository whenever it is reachable.
   *Implemented 2026-10-03:* `BackendTransport.delete_json()`,
   `scripts/backend/account_deletion_operations.gd`, and
   `tests/backend/test_account_deletion_transport.gd` (pass the backend root as the single user
   argument to compare the copies in `tests/fixtures/account_deletion_v1_3/`). The GAME-007,
   GAME-008, GAME-009, and rewarded-ad suites still pass, apart from GAME-007's pre-existing
   sibling-fixture lookups in the isolated runner.
2. **Durable service and cleanup.** Implement preflight exclusion, phase persistence, startup
   recovery, scoped save/cache deletion, native key removal, and explicit fresh-game activation.
   Cover acceptance, definite rejection, conflict/new-key behavior, transient failures, response
   loss, expired retry credentials, corrupt/partial records, cleanup failure, and process death
   before/after every destructive boundary. Verify late sync/refresh responses and migration
   cannot resurrect data, and unrelated namespaces remain untouched.
   *Implemented 2026-10-03:* `AccountDeletionService`, `AccountDeletionRecordStore`, the
   `PlayerProgress` startup gates, write/switch refusals, and release/activation hooks;
   suspend/drain support in the transport, sync, and registration services;
   `SecureSessionStore.destroy_installation_identity()`, `LocalSaveStore.erase_namespace()`, and
   `destroy_installation_key` in both native bridges (Android AAR built and checked; iOS not
   compiled); AdService pacing reload; and a launch-router guard. See
   [Account deletion](CLOUD_SAVE.md#account-deletion). `tests/save/test_account_deletion_service.gd`
   covers local deletion and restart before the new game; registration-pending and signed-out
   availability; acceptance and scoped cleanup with an unrelated namespace kept; lost-response
   replay after restart with the original key; 401 after ambiguity staying `unconfirmed` across a
   restart; definite rejection; offline preflight; conflict rebuild; first-attempt 401 refresh;
   process death during a send; cleanup failure resumed after restart; an unreadable record; an
   interrupted activation; an unsupported bridge; and torn record generations.
   Late responses are prevented rather than raced: preflight drains in-flight requests before
   sending, and cleanup detaches the services from the deleted store. There is no separate identity
   generation guard and no test that injects a late callback. Each cleanup step is idempotent and
   all of them re-run after a restart, so death between individual steps is covered by the
   resumed-cleanup test rather than one test per step. The save, backend, ads, UI, gameplay,
   audio, and haptics suites show only failures that also occur without these changes.
3. **Support and modal UI.** Add the Support action and focused scene, wire service signals,
   cancellation, back handling, disabled duplicate taps, offline/error states, receipt/deadline,
   support fallback, and new-game action. Extend `tests/ui/test_support_screen.gd`; add modal and
   launch-router coverage, including restart directly after acceptance.
   *Implemented 2026-10-03:* Support's Account section and `scenes/ui/account_deletion_modal.tscn`
   (`scripts/account_deletion_modal.gd`), hosted by `scripts/production_main_menu.gd` from Support
   and at launch. **Start New Game** changes to the main scene, so the fresh progress follows the
   first-launch route into level 1. `scripts/support_contact.gd` now holds the shared support
   e-mail route. Button labels are title case and fit the two-button row: **Delete Account**,
   **Delete Data**, **Start New Game**, and **Get Help** stand in for this plan's longer suggestions.
   `tests/ui/test_account_deletion_modal.gd` covers every view and action; the Support and
   launch-router suites cover the entry point, a launch right after deletion, and the new game
   reaching level 1. Captures of Support and ten modal views were reviewed at 540x960, 720x1280,
   1080x1920, and 1080x2400, plus 1200x1600, which the window manager rendered as 900x1600. The
   first account confirmation clipped its last line; the panel grew to 520x760 and the copy was
   shortened. Because every Main Menu open calls `PlayerProgress.load_progress()`, the service now
   reads its record and auto-resumes only once per process.
4. **Disposable local-backend and mobile validation.** Delete dedicated test accounts; verify
   immediate revocation, replay of a lost 202, worker anonymization, and fresh-key guest bootstrap
   before worker execution. Verify Android/iOS key destruction, process death/background/resume,
   local cleanup, fresh registration, and platform re-sign-in where those adapters are available.
   Cover proven local-only deletion without HTTP and guest-registration response loss that must
   not be misclassified as local-only data.
   *Validated 2026-10-03* with `scripts/tools/run_local_backend_account_deletion_check.ps1` against
   backend `0677a03` and game `e9b278f`, plus the `sorting-puzzle-api36` Android emulator:
   - Server (`local_backend_account_deletion_check.mjs`, real P-256 guests): 202 receipt with a
     30-day `complete_by` and a state version advanced by one; the deleted session's access and
     refresh tokens rejected at once; an exact replay returning the stored 202; a different body
     under the same key returning `idempotency.key_reused`; a new key reading the existing request;
     the deleted installation's key refused (`401 auth.guest_proof_invalid`) under its own and a new
     device id; a fresh key bootstrapping a new guest before the worker; and after one worker run a
     completed request, an anonymized tombstone with the **Deleted Player** profile, anonymized
     devices, an untouched unrelated guest, and an old key that never resumes the deleted player.
   - Android account flow through the real Support UI: acceptance with the deadline shown, the
     server player `deletion_pending` with no active sessions, `files/save_v2/` emptied, identity
     and namespace files and the secure-store `installation_id` and session entries removed, the
     locked result restored after force-stop and after background/resume, and **Start New Game**
     creating a new device id, installation key, and guest that registered as a different player.
     The worker then anonymized the deleted player and destroyed its device's key and binding.
   - Android local flow with the API stopped: **Delete Game Data** offered for an installation
     still at the challenge phase, deleted without any request, then a fresh identity.
   - Registration response loss: the emulator lost a bootstrap response the server had applied.
     Support still offered account deletion (never local data), and a relaunch replayed the same
     bootstrap and bound the player.
   - Device validation found that Android's `JNISingleton` hides plugin methods from
     `has_method()`, which made every Android build report deletion as unavailable. Fixed in
     `e9b278f` (`SecureSessionStore._bridge_has_method()` falls back to `has_java_method()`).
   - Godot exits on Android Back by default (`application/config/quit_on_go_back`), so Back from
     the locked modal closes the app rather than staying on the modal; the next launch restores it.
   - The emulator's `HTTPRequest` POST-response loss (GAME-004/GAME-010) also happens over
     `http://10.0.2.2:8080`, not only `adb reverse`, but less often; the deletion request itself
     completed on the first try.
   - The backend's pinned launch candidate is stale for committed game sources (`scripts/level.gd`,
     `configs/levels/level_020.json`, `scripts/tools/generate_level_shelves.py`), so
     `pnpm bootstrap:local` refuses to run. Validation regenerated it only inside a disposable
     backend worktree; the backend repository needs its own regenerated, committed candidate.
   Not covered: a physical device, iOS (the Keychain bridge is uncompiled), and platform re-sign-in
   (no client adapter exists yet).
5. **Documentation and commits.** Update `CLOUD_SAVE.md`, `SCENES.md`, `SCRIPTS.md`, `PROJECT_MAP.md`,
   this plan/ticket, and both native bridge READMEs. Commit each meaningful implementation batch.

Use `scripts/tools/run_isolated_godot_test.ps1` for Godot tests so deletion fixtures never operate
on the developer's real `user://` save. Add a focused capture setup for modal states. Run
`scripts/tools/capture_ui.ps1` for Support plus confirmation, submitting, offline/error,
unconfirmed, cleanup-failure, and accepted-result states; inspect contact-sheet pixels at 540x960,
720x1280, 1080x1920, 1080x2400, and a tablet-like portrait viewport. Verify long warning/deadline
text, safe areas, touch targets, scrolling, and button separation. Requested/rendered size
mismatches remain verification warnings requiring correction.

Release requires both native builds to include key destruction and the backend deletion worker
to execute on schedule, at least hourly as BE-607 documents. The locked support fallback also
requires a real `application/config/support_email`; the current default
`support@sortingpuzzle.example` cannot serve that release flow. Document how support verifies
the referenced request through existing backend lookup tools; the client must not unlock or
declare success based solely on a player's description of a support reply. Durable automated
resolution after credential expiry remains a separately scoped backend capability.

Keep those device/deployment checks explicit if the implementation environment cannot complete
them. No Godot scenes or runtime code are changed by this planning document, so rendered UI
verification belongs to implementation.
