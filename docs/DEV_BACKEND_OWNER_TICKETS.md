# Deployed Development Backend Owner/Setup Tickets

Status: Owner backlog

These tickets require project-owner, billing-owner, platform-console, credential-custodian, signing,
tester, or physical-device action. They are intentionally separate from
[`DEV_BACKEND_CODE_TICKETS.md`](DEV_BACKEND_CODE_TICKETS.md).

Do not paste secret payloads, OAuth secrets, private keys, purchase tokens, signed transactions,
service-account keys, or tester credentials into Git, tickets, chat, screenshots, or CI variables.
Tickets may record non-secret resource names, roles, numeric Secret Manager versions, timestamps,
and links to restricted change records.

## OWNER-001 - Lock application, account, and environment identifiers

**Who:** Project owner

**Blocks:** All other development-environment tickets

**Actions:**

- Permanent Android package name: decided as `com.vbrus.sortingpuzzle` (2026-10-14) and set in the export
  preset.
- Choose the permanent Apple bundle ID and whether it intentionally matches the Android reverse-DNS
  identifier.
- Record the public app display name, development Google Cloud/control-plane project IDs, region,
  billing account owner, GitHub repository owner/name and immutable numeric IDs, Apple team ID,
  Play Console developer account, App Store Connect organization, and support contact.
- Choose Game Center player scope (`team` for a normal non-Arcade game unless product requirements
  say otherwise) before any identity is linked.
- Name the development infrastructure administrator, secret custodian, Play Console administrator,
  App Store Connect administrator, and production approver. Apply MFA and least privilege.
- Approve that development uses Google license-test purchases and Apple Sandbox only.

**Done when:**

- A restricted decision record contains every non-secret identifier and accountable owner.
- Package/bundle/scope changes are treated as migrations after the first platform link or purchase.

## OWNER-002 - Create and bootstrap the Google Cloud foundation

**Who:** Google Cloud billing/project administrator

**Depends on:** `OWNER-001`

**Actions:**

- Create three projects: control plane, development runtime, and production runtime. Attach billing
  without placing project creation under Terraform.
- Enable the APIs required by the checked Terraform plan, including Cloud Run, Cloud SQL,
  Secret Manager, Artifact Registry, IAM Credentials/STS, Cloud Build as applicable, monitoring,
  logging, Service Networking, and Pub/Sub when its ticket is activated.
- Install the pinned Terraform and Google Cloud CLI versions and authenticate the human bootstrap
  operator using Application Default Credentials. Do not create service-account keys.
- Apply `infra/terraform/state`, migrate state to its protected GCS backend, then apply the
  control-plane and development roots according to the backend Terraform README.
- Configure the development and production GitHub Environments with the non-secret
  `ARTIFACT_IMAGE_URI`, `GCP_PROJECT_ID`, `GCP_REGION`, `WIF_PROVIDER`, and
  `DEPLOY_SERVICE_ACCOUNT` variables.
- Restrict deployment federation to the expected repository, workflow, `main` branch, and matching
  GitHub Environment. Require review and prevent self-review for production.
- Verify budgets, audit logging, dashboard, development alert routing, private Cloud SQL, deletion
  settings, and environment isolation.

**Done when:**

- Terraform plans cleanly and outputs the development Cloud Run service, Secret Manager containers,
  identities, Artifact Registry, Cloud SQL, and monitoring resources.
- GitHub can deploy development by WIF and has no secret-access permissions or long-lived Google
  credential.
- No production runtime is enabled merely to complete this ticket.

## OWNER-003 - Materialize development secrets and deploy the first usable backend

**Who:** Development secret custodian and backend release owner

**Depends on:** `OWNER-002`, `DEV-CODE-002`

**Actions:**

- On a hardened workstation, create independent development token-signing, offline-lease-signing,
  and data-encryption keyrings plus the API runtime document exactly as described in
  `SECRET_AND_KEY_MANAGEMENT.md`.
- Create separate least-privilege API and migration/bootstrap PostgreSQL logins.
- Add each secret document as a Secret Manager version using `--data-file`; record only numeric
  versions in the restricted change record and Terraform variables.
- Securely remove local plaintext after rollback material and access are confirmed.
- Push the one-time bootstrap image, apply the development environment with pinned secret versions,
  run the managed migration/bootstrap job, and deploy the API by digest.
- Verify `/health/live`, `/health/ready`, active content/catalog digests, protocol-v2 flags,
  minimum-client policy, logs, alerts, and rollback to the previous revision.
- Perform and record a Secret Manager access audit. Unexpected human, CI, or cross-environment reads
  are incidents.

**Done when:**

- The public development HTTPS origin is known and ready.
- Guest bootstrap and protocol-v2 save sync work without platform-provider credentials.
- No secret payload appears in Terraform state, GitHub, build artifacts, logs, tickets, or chat.

## OWNER-004 - Create the Google Play app, signing, test track, and testers

**Who:** Play Console account owner/administrator

**Depends on:** `OWNER-001`

**Actions:**

- Complete current Play developer identity/account verification and create the app as a game with
  the locked package name.
- Enable Play App Signing and securely retain the upload-key recovery information.
- Record the Play app-signing SHA-1 and each approved development/debug signing SHA-1 needed by Play
  Games Services.
- Create an internal test track, add tester groups/accounts, upload the first correctly signed
  development AAB, and have each tester opt in/install from Play.
- Configure license testers separately for Billing. Confirm testers understand that test-track
  users who are not license testers can incur real charges.
- Keep release keystores, upload keys, account cookies, and tester credentials outside the repo.

**Done when:**

- A tester can install the package from the internal track.
- Package name and certificate fingerprints are available as non-secret inputs to `OWNER-005`.
- One physical Play-certified Android device has the current Play Store and an allowlisted account.

## OWNER-005 - Configure Google Play Games Services and server OAuth

**Who:** Play Console and Google Cloud OAuth administrator

**Depends on:** `OWNER-002`, `OWNER-004`

**Actions:**

- Link the Play Games Services project to the intended Google Cloud project and enable the Games
  Services API.
- Configure the OAuth consent/branding screen and approved scopes/test audience.
- Create and link Android credentials for the exact package plus Play app-signing certificate; add a
  separate debug-signing credential only if sideloaded debug testing is required.
- Create and link the Game Server credential backed by a **Web application** OAuth client.
- Add the project owner and test accounts/groups as Play Games Services testers or enable the
  applicable release track for testing.
- Place the web client ID/secret and an independently generated subject-HMAC key into the
  development `api-runtime.store_credentials` document through the secret-custodian process.
  Record only the new numeric Secret Manager version.
- Publish Play Games Services configuration only to the testing audience until qualification is
  complete.

**Done when:**

- An allowlisted Android build signs in silently and can request one fresh server authorization
  code for the web client.
- The deployed backend reports Google Play Games configured without exposing the credential.
- A tester not on the allowlist fails as expected and continues as guest.

## OWNER-006 - Configure Google Play products, API access, license testing, and RTDN

**Who:** Play Console monetization administrator and Google Cloud administrator

**Depends on:** `OWNER-002`, `OWNER-004`

**Actions:**

- Complete the payments profile and required merchant/tax agreements for testing.
- Create the one-time products referenced by the development backend catalog. Use product types that
  match backend policy: repeatable coin packs are consumable; starter/timed/evergreen bundles are
  acknowledged non-consumables.
- Confirm every Play product ID exactly matches the immutable development catalog.
- Grant the backend workload identity only the minimum Android Publisher permissions needed to read,
  acknowledge/consume, and reconcile purchases for this app. Do not create or upload a service-
  account key file.
- Add license testers and verify approved, declined, slow-approved, slow-declined, and chargeback
  test instruments.
- In Terraform, enable the development `google_play_rtdn` resource only after `DEV-CODE-011` is
  ready. Bind its topic in Play Console and send a Play test notification.
- Verify the exact OIDC push audience/service account and dead-letter visibility.

**Done when:**

- Product queries return localized test prices on the allowlisted device.
- The backend can authoritatively read and fulfill a license-test purchase.
- The RTDN test notification reaches the development webhook and is recorded as a safe test outcome.

## OWNER-007 - Create the Apple app identity, signing, capabilities, and TestFlight access

**Who:** Apple Developer Account Holder/Admin and App Store Connect Admin/App Manager

**Depends on:** `OWNER-001`

**Actions:**

- Register the explicit App ID with the locked bundle ID and create the App Store Connect app record.
- Enable Game Center and In-App Purchase capabilities on the App ID and exported Xcode target.
  Regenerate affected provisioning profiles after capability changes.
- Configure development/distribution certificates or approved managed signing without exporting
  private keys into the repo or CI logs.
- Create internal TestFlight tester groups and add the required users/roles.
- Complete the first Godot iOS export/Xcode archive prerequisites on the approved macOS build host.
- Record only non-secret team, bundle, App Store app, profile, and build identifiers.

**Done when:**

- The app installs on a physical iOS device using the intended bundle/team and entitlements.
- An internal TestFlight build can be distributed to approved testers.
- Signing private material remains in the approved Apple/macOS custody boundary.

## OWNER-008 - Configure Game Center and development testers

**Who:** App Store Connect App Manager/Admin

**Depends on:** `OWNER-007`

**Actions:**

- Enable and configure Game Center for the app/version in App Store Connect.
- Confirm the backend bundle ID and immutable player ID scope match `OWNER-001`.
- Add/configure the required Game Center test accounts and device sign-in state.
- Add `game-center-app` and a separately generated Game Center subject-HMAC key to the development
  API runtime secret through the custodian workflow. Record only the numeric secret version.
- Re-pin the development Cloud Run revision and verify readiness.

**Done when:**

- The physical device authenticates the local Game Center player and produces fresh identity-
  verification items.
- The backend reports Game Center configured and successfully promotes one test guest.
- Signed identity evidence and raw player IDs are absent from logs and tickets.

## OWNER-009 - Configure App Store products, Sandbox, server API, and notifications

**Who:** App Store Connect Account Holder/Admin/App Manager and secret custodian

**Depends on:** `OWNER-007`

**Actions:**

- Accept the active Paid Apps agreement and complete required banking/tax setup needed for Sandbox
  in-app purchase testing.
- Create consumable/non-consumable in-app purchases whose product IDs exactly match the development
  catalog; complete required metadata and availability.
- Create Sandbox tester accounts and enable internal TestFlight access.
- Download the approved Apple public root certificates and add their canonical DER values plus an
  independent App Store purchase-HMAC key to the development runtime secret.
- Create a least-privilege App Store Connect In-App Purchase API key for server transaction/history
  access. Add its issuer ID, key ID, and private key only through the secret-custodian process.
- Configure the **Sandbox** App Store Server Notifications URL as
  `https://<development-origin>/webhooks/app-store`, selecting Version 2. Do not route Sandbox
  notifications to production.
- Send a test notification and perform one Sandbox purchase/refund rehearsal.

**Done when:**

- StoreKit returns products and localized Sandbox prices for the TestFlight/device build.
- The backend verifies one Sandbox transaction, queries transaction history, and receives a V2 test
  notification.
- Only numeric secret versions and safe test outcomes are recorded outside Secret Manager.

## OWNER-010 - Execute and approve cross-platform development qualification

**Who:** Project owner with Android and iOS testers

**Depends on:** `DEV-CODE-012`

**Actions:**

- Select one Play-certified Android device/account and one physical iOS device/Game Center/Sandbox
  account dedicated to the qualification run.
- Run the documented Android and iOS matrices against the same pinned backend revision and content
  digest.
- Perform console-only actions at the runner's checkpoints: pending/declined instrument, Play test
  RTDN, Apple V2 test notification, refund/revocation, account switch, reinstall, and recovery.
- Review redacted backend assertions, Cloud Run/Cloud SQL health, provider lag/dead letters, Secret
  Manager access audit, and budget impact.
- File follow-up defects against the owning `DEV-CODE-*` ticket; do not waive failed identity,
  idempotency, isolation, grant, refund, or secret-handling checks.
- Approve the development environment only after all blocking checks pass.

**Done when:**

- One signed qualification record contains safe build/revision/digest identifiers, passed cases,
  known non-blocking limitations, defect links, date, and approver.
- No secret, platform evidence, tester credential, or raw player/provider identifier is attached.
