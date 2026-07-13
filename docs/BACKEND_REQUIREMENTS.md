# Backend Server Requirements

Status: approved implementation plan

Last updated: 2026-07-13

## Purpose

This document defines the backend requirements for the production Android and iOS game. It is the implementation reference for player identity, authoritative progression and economy, offline synchronization, the Shop, leaderboards, profile data, security, privacy, administration, and operations.

The backend must be authoritative. Local and platform cloud saves are client caches, not sources of truth.

## Confirmed Product Decisions

- The game launches on Android and iOS.
- The game targets a general audience with a 3+ content rating; it is not specifically child-directed.
- Players are not forced through a login screen.
- The client silently attempts Google Play Games or Game Center authentication.
- When platform authentication is unavailable, the game creates or resumes a guest session.
- A verified platform identity is required for cloud recovery, leaderboard submission, and durable purchase ownership.
- The server is authoritative for progression and economy.
- The campaign remains playable offline.
- Offline level results and campaign advancement are provisional until synchronization.
- Offline play grants no durable coins, abilities, reward-chest progress, leaderboard score, or other rewards before validation.
- The Shop supports a once-per-player starter bundle, timed bundles, always-available basic bundles, and repeatable consumable coin packs.

## Existing Game Features

The current client stores the following state in `scripts/player_progress.gd`:

- Save schema version.
- Current campaign level.
- Highest completed campaign level.
- Lives and next life restoration timestamp.
- Coin balance.
- Hammer, shuffle, and highlight inventory.
- Processed Shop transaction IDs.
- Selected avatar and player name.
- Music, sound-effects, and vibration toggle state.
- Reward-chest stars and active goal index.
- Lifetime earned stars.
- Current weekly leaderboard period and weekly earned stars.

Current rules relevant to the backend:

- New players receive 300 coins.
- Players have a maximum of 5 lives.
- One missing life is restored every hour.
- Failure or confirmed level leave spends one life.
- Successful level completion does not spend a life.
- New players receive 3 hammer, 3 shuffle, and 3 highlight uses.
- A zero-inventory ability may be used immediately for a configurable coin price; the current price is 100 coins.
- Campaign completion stars feed lifetime score, weekly score, and reward-chest progress.
- Weekly ranking periods begin Monday at 00:00 UTC.
- Developer/test levels do not change campaign progression or leaderboard score.
- The public profile contains an editable player name of at most 24 characters and one of 18 allowlisted avatars.
- The current leaderboard exposes Weekly, Country, and World scopes, returns up to 50 rows, and pins the local player when outside that range.
- The current `Watch ad` ability option is only a placeholder and grants nothing.

Current reward-chest goals from `configs/reward_chest_goals.json`:

| Required stars | Coin reward |
| ---: | ---: |
| 500 | 100 |
| 1,000 | 225 |
| 1,500 | 375 |
| 2,000 | 550 |
| 3,000 | 900 |

The final goal repeats after it is reached. Goal thresholds and rewards must become versioned server configuration.

## Recommended Architecture

Start with a modular monolith rather than independent microservices.

Required components:

- Stateless HTTPS API application.
- Background worker for platform notifications, purchase reconciliation, leaderboard processing, deletion jobs, and other asynchronous work.
- PostgreSQL as the authoritative transactional database.
- Redis only where needed for short-lived caching, rate limits, locks, or leaderboard acceleration.
- Object storage or compressed database records for gameplay replay payloads if they become too large for normal relational storage.
- Internal administration API and dashboard.
- Transactional outbox for reliable asynchronous events.
- Separate development, staging/store-sandbox, and production environments.

Logical backend modules:

- Authentication and identity.
- Player profile.
- Gameplay run validation.
- Campaign progression and lives.
- Economy and inventory.
- Offline synchronization.
- Catalog and offers.
- Google Play and App Store purchases.
- Leaderboards.
- Profile moderation.
- Administration and support.
- Analytics and operations.

## Authentication and Identity

### Internal Player Identity

- Every player has an immutable internal `player_id`.
- Google Play Games and Game Center subjects are linked identities and must not be database primary keys.
- The identity model must allow future providers for cross-platform account linking.
- One player may have multiple linked identities.
- One provider identity may belong to only one active player.

### Guest Sessions

- Generate an installation key pair on first launch.
- Create a server guest player when connectivity is available.
- Issue a short-lived access token and a rotating refresh token.
- Store guest credentials using Android secure storage or iOS Keychain.
- Bind credentials to a device/installation record.
- Permit provisional local play before the first successful connection.
- Rate-limit guest creation by device attestation, installation, and network risk signals.

A guest cannot be guaranteed recoverable after uninstall or device loss without an external identity. The client must explain this before purchase and after meaningful progress has accumulated.

### Google Play Games Authentication

- Attempt platform authentication silently at startup and resume.
- Obtain a single-use server authorization code from the client.
- Exchange and verify it on the backend.
- Resolve the verified Google Play Games subject.
- Link the verified subject to the internal player.
- Never accept a client-supplied player ID without verifiable credentials.

Reference: https://developer.android.com/games/pgs/android/server-access

### Game Center Authentication

- Initialize the local Game Center player silently.
- Obtain Apple's server identity-verification payload.
- Verify its signature, certificate URL, bundle identity, timestamp, salt, and player identity server-side.
- Link the verified subject to the internal player.
- Handle authentication decline, restriction, account switching, and expired credentials.

Reference: https://developer.apple.com/documentation/gamekit/authenticating-a-player

### Guest Promotion and Account Merging

- If a platform identity is new, promote/link the current guest.
- If the platform identity already belongs to a player, execute an explicit merge.
- Preserve all verified store transactions and entitlements.
- Merge accepted completion histories instead of adding snapshot balances.
- Recalculate coins, inventory, chest progress, and leaderboard totals from authoritative events and ledger entries.
- Never sum two mutable balance snapshots.
- Resolve profile fields using the most recent explicit selection.
- Enforce starter-bundle lifetime eligibility after merging.
- Revoke old guest sessions and retain a non-login tombstone for transaction traceability.
- Record the merge and its decisions in an audit table.

## Authoritative Gameplay and Progression

The server must not accept a bare completion claim such as `{level, completed, stars}`. True authority requires deterministic validation of the run.

### Versioned Game Configuration

The server owns immutable, versioned copies of:

- Level definitions.
- Item catalog.
- Puzzle-rule version.
- Timer limits.
- Shelf locking and layer promotion rules.
- Combo and star scoring rules.
- Hammer, shuffle, and highlight behavior.
- Ability prices.
- Reward-chest configuration.

Every run references an immutable `level_version` and `rules_version`. Published versions must never be edited in place.

### Run Records

Each run stores:

- Run ID.
- Player and device IDs.
- Level and configuration version.
- Rules version.
- Online ticket or offline lease ID.
- Starting authoritative player-state version.
- Server-issued deterministic random seed.
- Creation, first-action, completion, and validation timestamps.
- Ordered gameplay events or a compressed replay.
- Reserved and consumed life/ability resources.
- Claimed and calculated result.
- Validation status and rejection reason.

### Gameplay Events

The replay protocol must represent:

- First meaningful action.
- Item moves with source and destination.
- Triple resolution and layer promotion.
- Hammer use and targets.
- Shuffle use and deterministic outcome.
- Highlight use.
- Pauses and resumes where timing affects validation.
- Failure, confirmed leave, abandonment, or completion.

### Deterministic Replay Validation

The backend validator must verify:

- Every move is legal.
- Locked shelves are inaccessible.
- Triple clearing and back-layer promotion are correct.
- Ability use is legal and reserved inventory exists.
- Shuffle output matches the server-issued random seed.
- The board is empty for a completion.
- Timer rules are satisfied.
- Combo timing and earned stars are recalculated server-side.
- The completion belongs to the accepted campaign sequence.
- Duplicate run IDs have no additional effect.
- The run uses a supported configuration and rules version.

The Godot runtime and backend validator must share conformance fixtures. A gameplay-rule change requires a new rules version and updated fixtures for both implementations.

### Life Handling

Recommended policy:

- Reserve a life when the first meaningful action occurs, not when the scene opens.
- Release the reservation after a valid completion.
- Consume the reservation on failure or confirmed leave.
- Consume an unfinished run's reservation after a configurable expiration period.
- Calculate restoration with server time only.
- Return lives and the next restoration timestamp in every authoritative state response.

This preserves the current successful-run behavior while preventing force-close and concurrent-run abuse.

## Offline Play and Synchronization

Offline completions are provisional. The client may display completion and provisionally unlock subsequent campaign levels, but it must not commit:

- Coins.
- Ability inventory grants.
- Reward-chest stars or chest rewards.
- Lifetime or weekly leaderboard score.
- Durable campaign advancement.
- Store or offer eligibility changes.

### Signed Offline Lease

After a successful sync, issue a signed, device-bound lease containing:

- Lease ID.
- Player and device IDs.
- Authoritative player-state version.
- Issue and expiration timestamps.
- Supported level and rules versions.
- Permitted provisional level range.
- Reserved lives and ability inventory.
- Maximum queued runs.
- Signing-key version and signature.

Initial implementation policy:

- Allow offline use of inventory explicitly reserved by the lease.
- Disable coin-paid immediate abilities while offline.
- Disable real-money purchases while offline.
- If the lease expires, allow practice-only play unless a future policy explicitly allows potentially valid provisional runs.

### Offline Event Queue

Each queued event includes:

- Globally unique event ID.
- Run ID.
- Strict per-device sequence number.
- Monotonic elapsed time.
- Configuration and rules versions.
- Payload hash.
- Previous-event hash or equivalent ordering protection.

Synchronization must:

1. Authenticate the player, device, and session.
2. Upload queued runs in order.
3. Deduplicate event and run IDs.
4. Validate the lease and each replay.
5. Commit valid chained completions transactionally.
6. Return accepted and rejected results with explicit reasons.
7. Return rewards only for newly accepted completions.
8. Replace provisional client state with a new authoritative snapshot.

If an invalid run is required by later provisional progress, dependent runs cannot be committed until the chain is resolved. The client must show a clear synchronization error rather than silently discarding progress.

### Multiple Devices

- Only one device may hold an economic offline lease at a time.
- A newly synchronized device may take over the lease.
- Other devices may play without reserved consumables, but results remain provisional/practice-only until valid synchronization.
- Inventory and lives must not be spendable concurrently from multiple offline devices.

## Economy and Inventory

All balance changes must be append-only ledger entries, not direct counter edits.

Assets:

- Coins.
- Hammer uses.
- Shuffle uses.
- Highlight uses.
- Lives or life reservations if lives use the same ledger abstraction.

Ledger source types:

- New-player bootstrap.
- Verified store purchase.
- Reward-chest grant.
- Ability inventory spend.
- Coin-paid immediate ability.
- Life restoration or consumption.
- Administrative compensation.
- Refund or revocation reversal.
- Legacy migration.

Every entry stores:

- Unique operation/idempotency key.
- Player.
- Asset and signed amount.
- Source type and source ID.
- Balance before and after.
- Timestamp.
- Configuration version and metadata.
- Reversal relationship where applicable.

Accepting a completion must atomically update the run, progression, leaderboard totals, chest state, resulting coin grants, ability use, life settlement, and outbox records.

## Reward Chest

- Count stars only from accepted campaign completions.
- Support crossing multiple goals in one completion.
- Carry excess stars into the next goal.
- Grant every crossed coin reward through the economy ledger.
- Return a detailed reward breakdown for client animation.
- Version goal configurations and attach the version to each grant.
- Never accept client-reported chest balances or reward amounts.

## Shop Catalog and Offers

The server catalog is authoritative for rewards and eligibility. The client queries the platform store for localized display prices.

### Offer Types

- `starter`: once per internal player.
- `timed_bundle`: available during server-controlled UTC windows.
- `evergreen_bundle`: always available, subject to configured limits.
- `coin_pack`: repeatable consumable.
- Future `rewarded_ad` or promotional offers.

Each offer contains:

- Internal offer ID and type.
- Localization keys.
- Android and iOS product IDs.
- Reward contents.
- Start and end timestamps.
- Per-player purchase limit.
- Limit period: lifetime, campaign, day, week, or offer window.
- Region eligibility.
- Minimum/maximum supported app version.
- Segment/experiment eligibility.
- Display priority and enabled state.
- Catalog version.

### Starter Bundle

- Available once per internal player.
- Eligibility survives reinstall, device changes, and account merges.
- Purchase history is checked before creating a purchase intent.
- Platform product configuration should discourage or prevent repeat purchase where supported.
- Duplicate transaction submission returns the original grant result.

### Timed Bundles

- Eligibility uses server time.
- Creating a purchase intent freezes player, offer, rewards, and catalog version.
- Purchase intents have configurable short expirations.
- A transaction completing after an offer closes is accepted only if it matches a valid intent created while the offer was active.
- Limits reset only according to the configured offer window/version.

### Pricing

- Production prices are not hardcoded in the server catalog or client.
- The backend returns platform product IDs.
- StoreKit or Play Billing returns formatted localized prices.
- Unknown product IDs are rejected even when a transaction is otherwise valid.
- Rewards are resolved from the server catalog version, never from client input.

## Purchase Verification

A verified platform identity and online session are required before purchase initiation.

### Google Play

- Receive purchase token and product ID from the client.
- Query Google Play Developer API.
- Verify package, product, token, and purchase state.
- Grant only when the purchase state is `PURCHASED`, never `PENDING`.
- Record transaction and rewards atomically.
- Acknowledge or consume according to product behavior.
- Attach an obfuscated internal account identifier to the billing flow.
- Process Real-time Developer Notifications.
- Deduplicate notification message IDs.
- Query Google for authoritative status after every notification.
- Reconcile missed, pending, voided, and refunded purchases.

References:

- https://developer.android.com/google/play/billing/backend
- https://developer.android.com/google/play/billing/integrate

### App Store

- Use current StoreKit signed transactions where the minimum iOS version supports them.
- Verify transaction JWS and certificate chain.
- Verify bundle ID, product ID, environment, and transaction state.
- Supply the internal player UUID as `appAccountToken`.
- Deduplicate original and transaction identifiers.
- Grant atomically.
- Configure App Store Server Notifications V2.
- Handle refunds, revocations, and consumption requests.
- Reconcile transaction history periodically.

References:

- https://developer.apple.com/documentation/storekit/choosing-a-storekit-api-for-in-app-purchases
- https://developer.apple.com/documentation/appstoreserverapi
- https://developer.apple.com/documentation/storekit/enabling-app-store-server-notifications

### Refunds

The ledger must support reversals without deleting history. Before implementation, select a policy for spent consumables:

- Deduct available currency and create debt for the remainder.
- Restrict future purchases until resolved.
- Absorb low-value refunds while flagging repeated abuse.
- Apply different rules by offer type.

## Leaderboards

Supported scopes:

- Weekly worldwide accepted stars.
- Country lifetime accepted stars.
- World lifetime accepted stars.

Requirements:

- Weekly periods begin Monday at 00:00 UTC.
- Preserve historical periods instead of destructively resetting one counter.
- Add score only from accepted campaign completion events.
- Exclude developer/test runs and unverified guest submissions.
- Deduplicate completion events.
- Return top 50, authenticated player entry, rank, period end, and pagination cursor.
- Use stable competition ranking for ties.
- Cache common pages while returning an accurate current-player row.
- Support quarantine of suspicious players without deleting their data.
- Propagate moderated profile changes.
- Never trust client country or score values.

Recommended country policy: derive a coarse country at first verified authentication without GPS, allow limited correction, and retain no precise location. Final correction and country-change rules must be selected before implementation.

## Player Profile and Moderation

Server profile fields:

- Display name.
- Avatar ID.
- Country code.
- Creation and update timestamps.
- Moderation state.

Display-name requirements:

- Maximum 24 Unicode characters.
- Trim and Unicode-normalize input.
- Reject control characters, deceptive bidirectional text, and empty names.
- Apply profanity and reserved-name filtering suitable for a 3+ content rating.
- Generate a safe fallback name.
- Rate-limit changes.
- Retain moderation history.
- Support reporting a leaderboard profile.
- Allow administrators to replace an abusive name without changing identity.

Avatar IDs must come from a server allowlist. Uploaded images and free-form chat are not required.

Music, sound effects, vibration, and device language remain local unless cross-device preference sync is added later.

## Representative API

```text
POST   /v1/sessions/guest
POST   /v1/sessions/refresh
POST   /v1/auth/google-play-games/exchange
POST   /v1/auth/game-center/exchange
POST   /v1/auth/link
POST   /v1/auth/merge

GET    /v1/player/state
PATCH  /v1/player/profile
GET    /v1/player/devices
DELETE /v1/player/account
POST   /v1/player/data-export

POST   /v1/runs/start
POST   /v1/runs/{run_id}/complete
POST   /v1/runs/{run_id}/fail
POST   /v1/runs/{run_id}/abandon
POST   /v1/sync

GET    /v1/catalog
POST   /v1/purchases/intents
POST   /v1/purchases/google/verify
POST   /v1/purchases/apple/verify
GET    /v1/purchases/{transaction_id}

GET    /v1/leaderboards/{scope}
POST   /v1/profiles/{player_id}/report

POST   /webhooks/google-play
POST   /webhooks/app-store
```

Every mutation requires:

- Authentication.
- Client-generated idempotency key.
- Device/session ID.
- Expected player-state version.
- App and protocol version.
- Correlation ID.
- Optional platform-integrity proof for sensitive operations.

Every state response includes authoritative server time and current state version.

## Core Data Model

Minimum tables or equivalent aggregates:

- `players`
- `player_identities`
- `devices`
- `sessions`
- `player_profiles`
- `player_state_snapshots`
- `level_definitions`
- `level_runs`
- `run_events`
- `offline_leases`
- `economy_ledger`
- `asset_balances`
- `life_state`
- `reward_chest_state`
- `catalog_versions`
- `offers`
- `offer_windows`
- `purchase_intents`
- `purchase_transactions`
- `offer_claims`
- `leaderboard_periods`
- `leaderboard_scores`
- `idempotency_records`
- `moderation_actions`
- `account_merge_records`
- `deletion_requests`
- `admin_audit_log`
- `outbox_events`

Balances and snapshots are materialized read models. Ledger entries and accepted run events are the audit source of truth.

## Security and Anti-Abuse

- TLS for every connection.
- Short-lived access tokens and rotating refresh tokens.
- Device-bound guest credentials.
- Encryption at rest for transaction payloads and platform identifiers.
- Secrets manager for store credentials and signing keys.
- Signing-key rotation and key-version tracking.
- Rate limits by player, device, network, and endpoint.
- Replay protection and idempotency.
- Strict schema validation and payload size limits.
- Administrative role-based access control.
- Immutable administrative audit logs.
- Compensating ledger entries instead of direct balance edits.
- Detection for impossible completion time, excessive stars, repeated rejected runs, reused purchase tokens, and abnormal account merging.

Use Play Integrity for high-value Android operations with a request hash bound to the protected request:

https://developer.android.com/google/play/integrity/standard

Use App Attest assertions for high-value iOS operations and verify server-issued challenges:

https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server

Integrity verdicts are tiered risk signals, not a universal hard dependency, because legitimate devices and platform services can fail.

## Privacy and Account Lifecycle

Minimize collected data:

- Internal IDs and platform pseudonymous identifiers.
- No precise location.
- No date of birth without a future legal requirement.
- No contacts, microphone, camera, or free-form messaging.
- Short IP retention for security; only coarse country derivation where required.
- Separate disclosure of analytics and advertising SDK data.

Required flows:

- Public privacy policy and accurate store disclosures.
- In-app account deletion.
- Web-based deletion request for Google Play.
- Data export/access request.
- Deletion status tracking.
- Session and identity-link revocation.
- Defined retention exceptions for purchase, accounting, security, and fraud records.
- Anonymization of retained operational records.

References:

- https://support.google.com/googleplay/android-developer/answer/13327111
- https://developer.apple.com/support/offering-account-deletion-in-your-app

## Administration and Live Operations

The administration system must support:

- Player lookup by internal ID, platform ID, transaction ID, or generated name.
- Authoritative state, ledger, purchase, run, sync-failure, and moderation history.
- Compensating grants or revocations with reason and audit trail.
- Purchase re-verification and notification replay.
- Account merging.
- Leaderboard quarantine and ban.
- Name moderation.
- Catalog and timed-offer scheduling.
- Offer eligibility preview.
- Versioned publication of chest, ability-price, level, and gameplay configuration.
- Feature flags and minimum supported client versions.
- Account deletion processing.
- Store integration and service health dashboards.

Economy-affecting configuration should require validation and preferably two-person approval.

## Observability and Reliability

Suggested initial service targets:

- 99.9% monthly API availability, excluding platform-store outages.
- Common authenticated reads under 250 ms p95.
- Cached leaderboard reads under 500 ms p95.
- Purchase verification within a few seconds under normal platform conditions.
- PostgreSQL point-in-time recovery.
- Daily restore verification and a documented disaster-recovery procedure.
- Load testing at a minimum of 10 times the expected launch peak.

Monitor:

- Authentication success by provider.
- Guest-to-platform conversion.
- Sync acceptance and rejection rates.
- Replay validation failures by rule.
- Purchase verification and notification lag.
- Duplicate transactions.
- Economy ledger invariant violations.
- Leaderboard update lag.
- Database latency, worker queues, errors, and saturation.

Use structured logs, traces, correlation IDs, and alerts. Never log tokens, full purchase payloads, or unredacted platform identifiers.

## Test Requirements

- Gameplay replay conformance against Godot-generated fixtures.
- Every level version accepted by both client tooling and server simulator.
- Duplicate and out-of-order event synchronization.
- Offline chained completion acceptance and rejection.
- Multiple-device lease conflicts.
- Life restoration across UTC and daylight-saving changes.
- Monday 00:00 UTC leaderboard rollover.
- Concurrent coin and inventory spending.
- Duplicate purchase callbacks.
- Pending, canceled, refunded, and revoked purchases.
- Google and Apple sandbox notification processing.
- Starter-bundle lifetime limit.
- Timed-offer boundary conditions.
- Account merging with purchases on both accounts.
- Account deletion and retained-ledger anonymization.
- Backup restoration and disaster recovery.
- API compatibility with the oldest supported client version.

## Implementation Phases

### Phase 1: Protocol and Rules Foundation

- Freeze schemas for player state, runs, replays, catalog, and ledger.
- Create deterministic gameplay conformance fixtures.
- Version all economy and level configuration.

### Phase 2: Identity and Canonical State

- Implement guest sessions, platform linking, tokens, and profiles.
- Create the PostgreSQL schema and authoritative state API.
- Define and implement the one-time legacy-save migration policy.

### Phase 3: Authoritative Progression and Economy

- Implement run lifecycle and deterministic simulator.
- Add life reservations, economy ledger, and chest processing.
- Deliver online completion before offline synchronization.

### Phase 4: Offline Synchronization

- Implement signed leases and provisional event queues.
- Validate queued replays and resolve conflicts.
- Add the pending-reward client contract.

### Phase 5: Shop and Purchases

- Implement the catalog and starter, timed, evergreen, and coin-pack offers.
- Add purchase intents, Google and Apple verification, notifications, reconciliation, and refunds.

### Phase 6: Leaderboards and Moderation

- Implement weekly, country, and world ranking.
- Add pagination, current-player rows, name filtering, reporting, and quarantine.

### Phase 7: Operations and Compliance

- Add administration, deletion/export, audit, observability, backups, integrity signals, and load testing.

## Policies to Finalize During Phase 1

- Offline lease duration.
- Maximum queued and chained offline levels.
- Behavior after an offline lease expires.
- Refund handling after purchased currency has been spent.
- Country assignment, correction, and country-change rules.
- Legacy local-save import limits.
- Run expiration before a reserved life is consumed.

The deterministic run validator is the critical dependency. Purchases, reward chests, leaderboards, and durable progression are only authoritative when the server can independently verify completion and calculate earned stars.
