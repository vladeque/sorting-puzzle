# Deployed Development Backend Code Tickets

Status: Planning backlog

These tickets cover source-controlled changes. Manual account, console, billing, credential, tester,
and approval work is tracked separately in
[`DEV_BACKEND_OWNER_TICKETS.md`](DEV_BACKEND_OWNER_TICKETS.md).

Cross-repository tickets do not authorize editing the sibling backend by themselves. When
implemented, follow both repositories' `AGENTS.md` files and create separate game and backend
commits.

## DEV-CODE-001 - Publish complete campaign provenance for levels 1-10

**Owner:** Game and backend

**Repositories:** `sorting-puzzle`, then `sorting-puzzle-backend`

**Depends on:** Existing `GAME-002` and backend `BE-201`

**Description:** Correct the duplicated or mismatched declarations in levels 9-10, regenerate the
immutable launch/development publication, and update the bundled client provenance manifest.

**Acceptance criteria:**

- Levels 1-10 have one unambiguous campaign number and pass solvability/content validation.
- Backend publication creates new immutable level/configuration versions; no published artifact is
  edited in place.
- The generated client manifest matches the active development publication digest.
- Pre-export and exported-runtime checks reject stale or incomplete provenance.
- Existing local saves remain readable and unsupported historic operations are not rewritten.
- Game and backend changes are committed separately and reference each other's commit plus the new
  configuration/digest identifiers.

## DEV-CODE-002 - Add a managed development migration and bootstrap job

**Owner:** Backend

**Repository:** `sorting-puzzle-backend`

**Depends on:** Backend `BE-005`, `BE-009`, `BE-010`, Terraform development foundation

**Description:** Provide a single-owner, keyless, auditable way to migrate private Cloud SQL and
idempotently publish/activate development configuration without reusing the API runtime credential
as schema owner.

**Acceptance criteria:**

- Terraform creates a development-only migration/bootstrap execution identity and managed job with
  private database connectivity.
- Its database credential is separate from `api-runtime`, least-privileged for migrations/
  publication, stored in its own Secret Manager container, and pinned by numeric version.
- The job verifies migration checksums, runs pending migrations once, then idempotently activates
  development configuration, catalog, minimum-client policy, and protocol-v2 flags.
- Concurrent executions are rejected or serialized; a failed migration cannot start application
  bootstrap.
- CI dispatch uses Workload Identity Federation and requires an explicit development environment
  approval. It never accepts a database password as workflow input.
- Output reports only migration numbers, publication/digest IDs, job execution ID, and safe status.
- Rollback is forward-fix for schema and prior-pointer activation for configuration; it never edits
  applied migrations or deletes player/purchase data.
- Integration tests cover repeat execution, partial failure, checksum mismatch, and an API revision
  starting only after a successful job.

## DEV-CODE-003 - Make the deployed development backend integration-ready

**Owner:** Backend

**Repository:** `sorting-puzzle-backend`

**Depends on:** `DEV-CODE-001`, `DEV-CODE-002`, `OWNER-003`

**Description:** Wire the development runtime configuration and preflight checks needed by mobile
clients and platform sandbox providers.

**Acceptance criteria:**

- Startup validates the complete development secret/config set for enabled features and fails with
  structural, non-secret errors when a required pair is missing.
- `/health/ready` covers database connectivity, required migrations, active configuration/catalog,
  supported-client policy, protocol-v2 recovery/ingestion flags, and enabled provider configuration
  without performing a provider transaction.
- Development accepts only development configuration and Google license-test/Apple Sandbox
  purchases; production evidence is rejected.
- Google Play Games, Game Center, Google Play purchase, and App Store purchase dependencies can be
  enabled independently, so unfinished provider setup does not disable guest/save integration.
- Cloud Run configuration declares only non-secret package/bundle IDs, environment, notification
  audiences, and service-account emails; credentials remain in pinned secret files or workload
  identity.
- A deployed smoke command verifies health, guest bootstrap, v2 save, catalog, and leaderboard
  against a pinned revision.
- Logs and metrics contain no OAuth codes, platform subjects, purchase tokens, signed transactions,
  notification payloads, or secret paths.

## DEV-CODE-004 - Add environment-safe Android and iOS development exports

**Owner:** Game

**Repository:** `sorting-puzzle`

**Depends on:** `OWNER-001`, deployed HTTPS URL from `OWNER-003`

**Description:** Add reproducible Android and iOS development export configuration that selects the
remote backend and real backend providers without weakening local or production defaults.

**Acceptance criteria:**

- A closed environment configuration selects public API origin, sync enablement, catalog source,
  leaderboard provider, and store provider. It contains no secrets.
- Local, development, and production values cannot be combined accidentally.
- Development uses the Cloud Run HTTPS origin; cleartext HTTP remains local-debug-only.
- Android development exports include Internet access and the release-safe secure-store bridge.
- iOS development exports include HTTPS networking and the iOS plugin packaging inputs.
- Production defaults do not point to development and cannot package `local/backend_debug.cfg`.
- Export validation rejects an empty/non-HTTPS remote development URL, mock purchasing labeled as
  real, stale content provenance, unexpected package/bundle ID, or incompatible build number.
- A build manifest records environment, app version/build, content digest, protocol family, and
  source commit without credentials.
- Documentation covers local workstation and CI export paths.

## DEV-CODE-005 - Package and verify the iOS secure-store baseline

**Owner:** Game

**Repository:** `sorting-puzzle`

**Depends on:** `DEV-CODE-004`, `OWNER-007`

**Description:** Turn the existing Keychain bridge source into a reproducible Godot 4.6.2 iOS
plugin/export and prove guest plus protocol-v2 synchronization against development.

**Acceptance criteria:**

- A documented build produces device and simulator slices, one xcframework, and a valid `.gdip`
  package from the checked-in source.
- CI or a checked verification script validates exported symbols and required architectures.
- The bridge creates a non-exportable P-256 private key, signs guest and journal payloads, and
  stores each player session under the expected Keychain accessibility policy.
- Process death, reboot/first unlock, background/resume, account A/B isolation, sign-out, and the
  chosen uninstall/reinstall behavior are device-tested.
- A clean iOS development install creates/resumes a guest and synchronizes one offline completion
  against the deployed backend.
- Diagnostics reveal only bridge availability and stable non-secret identifiers.

## DEV-CODE-006 - Integrate Google Play Games platform identity

**Owner:** Game

**Repository:** `sorting-puzzle`

**Depends on:** `DEV-CODE-004`, `OWNER-004`, `OWNER-005`, backend `BE-104`

**Description:** Add a focused Android Godot plugin/service for silent Play Games Services v2
authentication and server-side identity exchange.

**Acceptance criteria:**

- The native bridge uses the supported Play Games Services v2 authentication API and requests a
  fresh single-use server authorization code for the configured game-server web OAuth client.
- The code is passed directly to `POST /v1/auth/google-play-games/exchange`; it is never persisted,
  logged, retried, or reused.
- Decline, unavailable services, tester misconfiguration, and restriction preserve guest play.
- Invalid/used code and dependency outage restart the flow with a fresh code.
- A successful exchange atomically stores the replacement `platform_verified` session and promotes
  the active guest namespace without copying another player's snapshot.
- `auth.google_play_games_account_switch` is handed to the shared account-choice flow in
  `DEV-CODE-008`.
- Debug and Play-signed certificate/package variants are tested with allowlisted accounts.
- Contract tests use synthetic codes only; no real code or scoped player ID enters fixtures.

## DEV-CODE-007 - Integrate Game Center platform identity

**Owner:** Game

**Repository:** `sorting-puzzle`

**Depends on:** `DEV-CODE-005`, `OWNER-007`, `OWNER-008`, backend `BE-105`

**Description:** Add a focused iOS Godot plugin/service for silent Game Center authentication and
server identity-verification exchange.

**Acceptance criteria:**

- The bridge initializes `GKLocalPlayer`, presents Apple's controller only when required, and calls
  `fetchItems(forIdentityVerificationSignature:)` only for an authenticated local player.
- It sends only public-key URL, signature, salt, unchanged millisecond timestamp represented as
  canonical RFC 3339, and the configured scoped player ID.
- Identity evidence exists only in memory, is never logged/persisted, and is discarded after the
  attempt or freshness window.
- Decline, restriction, unavailable Game Center, stale evidence, certificate dependency outage, and
  account switch follow the backend recovery contract.
- A successful exchange stores the replacement `platform_verified` session and promotes the active
  guest namespace safely.
- Team/game player ID scope is fixed before the first link and matches backend configuration.
- Device tests cover signed-in, signed-out, restricted, account-changed, and clean-install cases.

## DEV-CODE-008 - Implement account promotion, switching, merge, and recovery UX

**Owner:** Game

**Repository:** `sorting-puzzle`

**Depends on:** `DEV-CODE-006`, `DEV-CODE-007`, backend `BE-106` and `BE-107`

**Description:** Complete the shared cross-platform account coordinator and dedicated reusable
dialogs for the non-routine identity decisions.

**Acceptance criteria:**

- Routine guest promotion and same-account reauthentication remain silent.
- Account A is atomically closed before account B is activated; snapshots, balances, profiles,
  sessions, and journals never appear under the wrong identity.
- Unsynchronized namespaces remain intact and retry when their identity becomes active again.
- A recoverable clean installation downloads the selected platform account checkpoint before
  applying that account's pending local journal.
- A merge-required response shows a dedicated scene summarizing the choice without exposing raw
  provider identifiers; no merge occurs without explicit confirmation.
- Merge requests retain one idempotency key/payload across ambiguous retries and apply only the
  server's surviving player, revoked-session, profile-choice, and recomputed-state result.
- Sign-out never deletes guest or platform namespaces and warns before leaving the only recoverable
  identity when required by backend policy.
- Android and iOS tests cover guest promotion, A/B switch online/offline, merge with conflicts,
  cancellation, response loss, restart, and purchases on both source accounts.

## DEV-CODE-009 - Replace Android mock purchases with Google Play Billing

**Owner:** Game

**Repository:** `sorting-puzzle`

**Depends on:** `DEV-CODE-006`, `DEV-CODE-008`, `OWNER-006`, backend `BE-403` through `BE-405`,
`BE-408`, and `BE-409`

**Description:** Add a Google Play Billing provider and the complete backend intent, verification,
status, and recovery lifecycle.

**Acceptance criteria:**

- Product details/localized prices come from Play Billing and join by the backend catalog's exact
  `platform_product_id`; missing/mismatched products are not purchasable.
- Purchasing requires connectivity and a verified Google Play Games session.
- The client creates a backend intent before launching Billing and supplies the returned
  obfuscated account binding to the purchase flow.
- `PENDING` never grants rewards. `PURCHASED` submits intent ID, product ID, and opaque purchase
  token to the backend with one mutation idempotency key.
- Rewards and balances are applied only from the backend response/checkpoint. The client does not
  call `PlayerProgress.apply_shop_purchase()` with provider or catalog reward data.
- Consumption/acknowledgement follows the backend durable result; ambiguous outcomes recover through
  `GET /v1/purchases/{transaction_id}` and fresh provider query without duplicate grants.
- App restart discovers unfinished purchases and resumes verification.
- License-test cases cover approved, declined, slow-approved, slow-declined, duplicate callback,
  response loss, refund/chargeback, reinstatement, wrong account, and account merge.
- Mock provider remains available only in explicit local development mode and is visibly labeled.

## DEV-CODE-010 - Replace iOS mock purchases with StoreKit

**Owner:** Game

**Repository:** `sorting-puzzle`

**Depends on:** `DEV-CODE-007`, `DEV-CODE-008`, `OWNER-009`, backend `BE-403`, `BE-406` through
`BE-409`

**Description:** Add a StoreKit provider and the complete backend intent, signed-transaction
verification, status, and recovery lifecycle.

**Acceptance criteria:**

- Product/localized price data comes from StoreKit and joins by exact backend product ID.
- Purchasing requires connectivity and a verified Game Center session.
- The client creates a backend intent first and supplies its account binding as the StoreKit
  `appAccountToken` where supported.
- The verification request contains only the intent ID and StoreKit signed transaction JWS.
- Signed transactions remain memory-only and secret; no reward is applied until the backend returns
  a durable grant/state result.
- StoreKit transactions are finished only after durable server success; ambiguous results recover
  through backend status plus current StoreKit entitlements/unfinished transactions.
- Sandbox tests cover consumable and non-consumable offers, Ask to Buy/pending where available,
  cancellation, duplicate delivery, response loss, restart, refund, family revocation,
  reinstatement, account mismatch, and merge.
- Mock provider remains local-only and cannot be selected by a remote development/production build.

## DEV-CODE-011 - Activate development store notifications and reconciliation

**Owner:** Backend

**Repository:** `sorting-puzzle-backend`

**Depends on:** `DEV-CODE-003`, `OWNER-006`, `OWNER-009`, backend `BE-405` and `BE-407`

**Description:** Instantiate and verify the development-only Google RTDN resources and the Apple
notification/history runtime path.

**Acceptance criteria:**

- Terraform enables only the approved `google_play_rtdn` development resources with exact webhook
  URL/audience, dedicated OIDC push identity, retry policy, and dead-letter subscription.
- Only Google's documented publisher may publish to the topic; the API validates exact audience
  and service-account email.
- App Store Server Notifications V2 accept only valid signed Sandbox payloads for the configured
  bundle.
- App Store history uses the separately pinned App Store Connect API credential and database leases.
- Provider test notifications, a completed purchase, pending-to-purchased transition, refund/
  revocation, duplicate, out-of-order delivery, dead-letter visibility, and recovery scan are
  exercised.
- Notification state is treated only as a hint; both platforms perform the authoritative provider
  read before changing grants or reversals.
- Dashboards and alerts expose lag, retry, duplicate, reconciliation, and dead-letter outcomes
  without provider identifiers or payloads.
- Replaying a delivery preserves its provider identity and cannot duplicate a grant or reversal.

## DEV-CODE-012 - Build the remote cross-platform integration gate

**Owner:** Game and backend

**Repositories:** `sorting-puzzle`, then `sorting-puzzle-backend`

**Depends on:** `DEV-CODE-001` through `DEV-CODE-011`, `OWNER-010`

**Description:** Add a repeatable development-environment qualification flow for Android and iOS.

**Acceptance criteria:**

- The runner pins and reports client commit/build, backend image digest/revision, protocol fixture
  versions, and active content/catalog digests.
- Android and iOS each cover guest bootstrap, secure restart, offline completion and later sync,
  platform promotion, clean-install recovery, catalog, leaderboard, and one store sandbox purchase.
- Dedicated test identities/data are tagged and isolated; cleanup never deletes shared
  development players, financial records, or environment resources.
- Automated backend assertions verify player/device/session, cursor/checkpoint, selected completion,
  leaderboard projection, intent, purchase transaction, ledger grant, notification/reconciliation,
  and idempotent duplicate behavior.
- Manual checkpoints cover provider-owned UI and console actions that automation cannot safely
  drive.
- Failure output contains only platform, phase, stable error code, safe IDs/digests, correlation ID,
  and links to redacted runbooks.
- The matrix includes network loss, API restart, token refresh, response loss, account switch,
  pending purchase, refund/revocation, and provider outage.
- Game and backend gate changes are separate commits and cross-reference one qualification run.
