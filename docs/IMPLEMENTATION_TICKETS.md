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
