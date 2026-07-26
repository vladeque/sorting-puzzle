# Deployed Development Backend Integration Plan

Status: Proposed

Target: Android and iOS development builds connecting over HTTPS to the shared deployed
development backend, using real platform identity and store sandbox integrations.

Detailed backlogs:

- [Code tickets](DEV_BACKEND_CODE_TICKETS.md)
- [Owner/setup tickets](DEV_BACKEND_OWNER_TICKETS.md)
- [Existing local integration](LOCAL_BACKEND_INTEGRATION.md)

## Outcome

The integration is complete when Android and iOS development builds can:

1. create and resume a guest account against the deployed development API;
2. synchronize the protocol-v2 local journal and recover it on a clean installation;
3. authenticate with Google Play Games or Game Center and safely promote, switch, or merge accounts;
4. read the deployed Shop catalog and backend leaderboards;
5. complete Google Play and App Store sandbox purchases through server-created intents and
   server-verified grants;
6. converge after pending purchases, response loss, provider notifications, refunds, revocations,
   and app restarts; and
7. pass a repeatable, secret-free cross-platform development-environment gate.

The backend remains a recovery and merge destination. Loss of connectivity must not block installed
campaign play, ordinary local rewards, lives, or local spending. Real-money purchasing and initial
retrieval of uninstalled content remain online-only.

## Confirmed baseline

- `GAME-001` through `GAME-010` implement and test local-first persistence, guest bootstrap,
  rotating sessions, protocol-v2 synchronization, Android secure storage, shared authenticated
  reads, backend catalog/leaderboard providers, and the local Android integration gate.
- The committed client defaults intentionally disable backend connectivity, use mock catalog/store/
  leaderboard providers, and have no environment-aware Android or iOS development export pipeline.
- The Android secure-store bridge is packaged and emulator-tested. The iOS Keychain bridge exists
  as source but is not yet packaged and verified in an exported iOS development build.
- Google Play Games, Game Center, Google Play Billing, and StoreKit client bridges do not exist.
- Shop purchasing still trusts the development-only mock provider and applies mock rewards locally.
- The backend implements the required platform-authentication, purchase-verification,
  notification/reconciliation, catalog, leaderboard, and protocol-v2 endpoints.
- Backend Terraform exists for a control-plane project and isolated development and production
  projects, but applying infrastructure, materializing secrets, configuring GitHub environments,
  running managed migrations/bootstrap, and connecting store consoles are still outstanding.
- Backend launch publication remains incomplete for campaign levels 9-10.

## Environment boundary

Use three distinct boundaries:

| Boundary | Purpose | Store traffic | Data |
| --- | --- | --- | --- |
| Local | Fast deterministic development and contract tests | Mock only | Disposable PostgreSQL |
| Development | Shared device integration and operational rehearsal | Google license tests and Apple Sandbox | Non-production |
| Production | Player-facing release | Production providers only | Isolated authoritative data |

Development and production must not share projects, databases, service identities, signing keys,
encryption keys, provider HMAC keys, OAuth secrets, App Store Connect keys, notification routes, or
test/player data.

## Delivery phases

### D0 - Lock identifiers and ownership

Owner tickets: `OWNER-001`

Code tickets: none

Exit gate:

- Stable Android package name and Apple bundle ID are recorded.
- Development/control-plane Google Cloud project IDs, region, billing owner, repository owner/name,
  Apple team, Play Console account, and custodians are known.
- Changing an identifier after platform links or purchases exist requires an explicit migration.

### D1 - Deploy a usable development backend

Owner tickets: `OWNER-002`, `OWNER-003`

Code tickets: `DEV-CODE-001`, `DEV-CODE-002`, `DEV-CODE-003`

Exit gate:

- Terraform state, control plane, development Cloud Run, private Cloud SQL, Secret Manager
  containers, budgets, observability, and keyless deployment identity exist.
- A dedicated managed migration/bootstrap path applies migrations and activates development
  configuration without giving the API schema-owner credentials.
- `/health/live` and `/health/ready` succeed over the Cloud Run HTTPS URL.
- Protocol-v2 recovery and ingestion flags, development catalog, minimum-client policy, and complete
  level provenance are active.
- No production secret or credential is present in development.

### D2 - Connect Android and iOS development builds

Owner tickets: `OWNER-004`, `OWNER-007`

Code tickets: `DEV-CODE-004`, `DEV-CODE-005`

Exit gate:

- Environment-selected development builds embed only the public HTTPS API origin and non-secret
  feature/provider selections.
- Release/production builds cannot accidentally consume a local or development override.
- Android and iOS both prove guest creation, secure session persistence, restart, offline play,
  synchronization, and clean-install platform-backed recovery prerequisites.
- Exported diagnostics contain no tokens, signatures, Keychain/Keystore material, or request bodies.

### D3 - Add platform identity and account recovery

Owner tickets: `OWNER-005`, `OWNER-008`

Code tickets: `DEV-CODE-006`, `DEV-CODE-007`, `DEV-CODE-008`

Exit gate:

- Android exchanges a fresh single-use Play Games server authorization code.
- iOS exchanges fresh Game Center identity-verification fields.
- Guest decline/restriction continues silently; successful authentication promotes the guest.
- Account switching never renders one player's cached state under another identity.
- Merge is explicit, idempotent, and based only on the backend merge result.
- Clean-install recovery restores the correct player on both platforms.

### D4 - Add sandbox purchases and reconciliation

Owner tickets: `OWNER-006`, `OWNER-009`

Code tickets: `DEV-CODE-009`, `DEV-CODE-010`, `DEV-CODE-011`

Exit gate:

- Store prices come from Google Play Billing or StoreKit, while offer eligibility and rewards come
  from the immutable backend catalog.
- Both clients create a backend purchase intent before launching the platform purchase sheet.
- Google sends the exact product ID, purchase token, intent ID, and server-issued account binding;
  Apple sends only the intent ID and signed transaction JWS.
- The client never grants provider-reported rewards. It applies only the durable backend state/grant
  result and finishes/consumes/acknowledges in the approved order.
- Pending, canceled, duplicate, lost-response, restart, refund, revocation, reinstatement, and
  account-merge cases converge without duplicate rewards.
- Google RTDN and App Store Server Notifications V2 are exercised in development.

### D5 - Automate the shared-environment release gate

Owner tickets: `OWNER-010`

Code tickets: `DEV-CODE-012`

Exit gate:

- One Android run and one iOS run cover identity, sync, catalog, leaderboard, purchase, restart, and
  recovery against a pinned backend revision and content manifest.
- Automated assertions inspect only dedicated test players and safe aggregate state.
- Failures report platform, phase, stable error code, build/revision identifiers, content digest,
  and correlation ID without exposing secrets or provider evidence.
- The gate includes documented manual checks for provider sheets and console-only notification/
  refund actions that cannot be automated safely.

## Critical path

```text
OWNER-001
  -> OWNER-002 -> DEV-CODE-002 -> OWNER-003 -> DEV-CODE-003
  -> DEV-CODE-004
      -> Android: OWNER-004 -> OWNER-005 -> DEV-CODE-006
      -> iOS:     OWNER-007 -> DEV-CODE-005 -> OWNER-008 -> DEV-CODE-007
  -> DEV-CODE-008
      -> Google: OWNER-006 -> DEV-CODE-009
      -> Apple:  OWNER-009 -> DEV-CODE-010
  -> DEV-CODE-011
  -> DEV-CODE-012 -> OWNER-010
```

`DEV-CODE-001` can run in parallel with the infrastructure path but must finish before the
development content publication is treated as complete.

## Shared definition of done

Every code ticket must:

- remain compatible with Godot 4.6.2 and the supported backend protocol versions;
- add unit/contract tests plus device or deployed-environment evidence proportional to risk;
- keep retries idempotent and preserve the identical payload after an ambiguous mutation result;
- map unknown response enums to `unknown` and ignore additive response fields;
- keep secrets and pseudonymous provider evidence out of logs, screenshots, analytics, fixtures,
  local gameplay saves, and committed configuration;
- update the owning documentation;
- keep game and backend changes in separate commits; and
- document rollback without deleting durable identity, journal, purchase, or ledger records.

Every owner/setup ticket must:

- record only non-secret identifiers, roles, numeric Secret Manager versions, and verification
  evidence;
- keep secret payloads out of Git, Terraform state, CI variables, tickets, and chat;
- use least privilege, MFA, and keyless Google authentication where supported;
- configure development/sandbox resources only; and
- identify the person who can approve or reverse the change.

## Explicitly deferred

- Production infrastructure application or production store rollout.
- Play Integrity and App Attest enforcement; they require separate risk-policy and client tickets.
- Re-enabling deterministic gameplay replay/proof generation.
- Custom production DNS, load balancer, WAF, and trusted country header.
- Administration, moderation/reporting, privacy export/deletion UI, and public compliance surfaces.
- Rewarded ads or any client-invented promotional grant.

## References

Repository contracts and runbooks:

- `../sorting-puzzle-backend/BACKEND_REQUIREMENTS.md`
- `../sorting-puzzle-backend/docs/PROTOCOL_BOUNDARY.md`
- `../sorting-puzzle-backend/docs/DEPLOYMENT.md`
- `../sorting-puzzle-backend/docs/SECRET_AND_KEY_MANAGEMENT.md`
- `../sorting-puzzle-backend/infra/terraform/README.md`
- `../sorting-puzzle-backend/docs/GOOGLE_PLAY_GAMES_AUTHENTICATION.md`
- `../sorting-puzzle-backend/docs/GAME_CENTER_AUTHENTICATION.md`
- `../sorting-puzzle-backend/docs/GOOGLE_PLAY_PURCHASE_VERIFICATION.md`
- `../sorting-puzzle-backend/docs/GOOGLE_PLAY_RTDN_RECONCILIATION.md`
- `../sorting-puzzle-backend/docs/APP_STORE_PURCHASE_VERIFICATION.md`
- `../sorting-puzzle-backend/docs/APP_STORE_NOTIFICATIONS_RECONCILIATION.md`

Platform setup references checked on 2026-07-26:

- [Google Play Games Services setup](https://developer.android.com/games/pgs/console/setup)
- [Play Games server-side access](https://developer.android.com/games/pgs/android/server-access)
- [Google Play Billing testing](https://developer.android.com/google/play/billing/test)
- [Game Center player authentication](https://developer.apple.com/documentation/gamekit/authenticating-a-player)
- [Apple capabilities](https://developer.apple.com/help/account/capabilities/capabilities-overview/)
- [Apple in-app purchase setup](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases)
- [App Store Server Notifications URLs](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/enter-server-urls-for-app-store-server-notifications/)
