# Google Play internal testing and backend deployment plan

Reviewed: **2026-10-02**.

Status: **Review and execution plan; connected internal release is not ready.**

Owner-confirmed first release: **gameplay plus deployed save sync**. Real Google Play Games sign-in, Billing, and advertising are later phases.

Read the [abstract](GOOGLE_PLAY_INTERNAL_TESTING_ABSTRACT.md) for the short version.

Execute the plan through the [release ticket backlog](GOOGLE_PLAY_INTERNAL_TESTING_TICKETS.md): 28 first-release work packages and 5 deferred milestones, mapped to the steps and existing feature/setup tickets below.

## 1. Scope, evidence, and boundaries

The owner confirmed that only one billed Google Cloud project exists. Terraform has never been applied and nothing is running in Google Cloud. No existing Play account/app or public policy/domain was reported.

The audit examined both repositories, their canonical requirements and boundaries, export/native-plugin configuration, cloud Terraform and workflows, client save/store/ad code, and current tests. Game HEAD at the end of inspection was 80048ab; the review started at 3b9676c and a documentation-only account-deletion planning commit appeared during the review. Backend HEAD was df51117, with existing uncommitted rewarded-ad and related changes. Backend checks therefore assess the **working tree**, including those changes, rather than proving that HEAD alone builds.

This plan does not authorize deployment, billable provisioning, signing-key creation, store publication, or destructive migrations. Those are future execution tasks. Existing unrelated work was preserved. Backend requirements remain canonical in the sibling repository.

Important product boundaries:

- Installed campaign play is local-first under save protocol 2.1; the backend holds the merged recovery record and server-originated identity, purchase, moderation, and deletion facts.
- Legacy v1.3 remains a compatibility path. Do not switch ordinary v2 save journals to legacy run/lease APIs to make deployment easier.
- The deterministic gameplay replay validator is dormant under ADR 0019. Reactivating replay validation is not a prerequisite for this release.
- Android is the current release target. Apple credentials, iOS secure-store packaging, StoreKit, and TestFlight do not block this Android test.
- Guest registration and signed save sync can operate without Google Play Games credentials. Guest sync must not be advertised as reinstall or cross-device recovery.

Canonical references: [Backend requirements](../../sorting-puzzle-backend/BACKEND_REQUIREMENTS.md), [Protocol boundary](../../sorting-puzzle-backend/docs/PROTOCOL_BOUNDARY.md), [Validator boundary](../../sorting-puzzle-backend/docs/GAMEPLAY_VALIDATOR_BOUNDARY.md), [Local-first synchronization](../../sorting-puzzle-backend/docs/LOCAL_FIRST_SAVE_SYNCHRONIZATION.md).

## 2. Current readiness

### 2.1 Game

| Area | Current evidence | Release implication |
| --- | --- | --- |
| Engine and entry | Godot 4.6.2; launch router opens level 1 for a new player, then the production menu | A gameplay foundation exists; verify the exported path on devices. |
| Campaign | Twenty runtime level files and twenty-level development provenance; launch documentation identifies levels 13-20 as level-1-shaped placeholders | A finite internal campaign is viable; do not claim twenty distinct finished levels. Verify terminal campaign behavior. |
| Chapters | Chapter 1 contains levels 1-20; Chapter 2 has no levels and requires 25 previous-chapter completions; chapter selection defaults off | Keep empty/unreachable chapter content out of the first tester flow. |
| Saves | Atomic local generations, signed journal, guest bootstrap, secure-session handling, protocol 2.1 background sync | Core save architecture exists. Remote Android behavior still requires proof. |
| Networking defaults | Empty backend URL and save sync disabled in project.godot | Normal release builds will not connect until environment configuration is added. |
| Android export | One local debug APK preset; package com.sortingpuzzle.game; version 0.1.0/code 1; target API 35 | No reproducible internal release AAB preset was found. Confirm package identity before first upload. |
| Android build tools | Installed ignored Android template uses compile SDK 35 and AGP 8.6.1; secure-store plugin separately compiles against SDK 36 | An API-36 emulator or plugin compile setting does not make the game artifact API-36 compliant. |
| Secure storage | Android debug/release AAR bridge and export hook exist | The export hook warns and continues if its AAR is missing. The connected release must fail validation in that case. |
| Internet permission | Secure-store debug AAR adds INTERNET and cleartext; release AAR adds neither; preset has no explicit Internet permission | Add INTERNET to the remote release manifest while retaining HTTPS-only networking. Verify the merged artifact. |
| Shop | Local/backend catalog selection exists; only MockStoreProvider is implemented; unknown providers fall back to mock | Hiding or disabling real-money purchasing needs implementation. A provider setting alone is insufficient. |
| Leaderboards | Local backend reader and mock provider exist; default is mock | Keep public ranking unavailable until verified platform identity is integrated. Do not ship mock players as real rankings. |
| Ads | Vendored AdMob/UMP integration, four rewarded placements, consent and fail-closed checks exist; runtime/native defaults are off; all release approvals are false | Ads can remain outside first scope. Verify native libraries and permissions are actually excluded or inactive in the AAB. |
| Privacy/support | Policy URL is empty; support address uses .example; policy access currently shares the ad-privacy route | Add usable privacy and support access for the guest-only release. |
| Deletion/export | Backend supports both; client GAME-012 is planned and unimplemented; no client export surface found | Complete deletion and operate its worker. Export access/support handling remains a separate deliverable. |
| Localization/legal | Language selection exists, but legal research records untranslated UI and no Ukrainian locale | Define the test language honestly; translated worldwide release is later work. Confirm publisher/market obligations before wider distribution. |

Ownership references: [Project map](PROJECT_MAP.md), [Local integration](LOCAL_BACKEND_INTEGRATION.md), [Development code tickets](DEV_BACKEND_CODE_TICKETS.md), [Owner tickets](DEV_BACKEND_OWNER_TICKETS.md), [Deletion plan](ACCOUNT_DELETION_PLAN.md), [Legal research](LEGAL_DOCUMENTS_RESEARCH.md).

### 2.2 Backend

| Area | Current evidence | Missing deployment or qualification |
| --- | --- | --- |
| Application | Node 24, TypeScript, NestJS/Fastify, PostgreSQL; modular API and worker | Deploy and exercise the actual release artifact. |
| Core services | Guest/session/device identity, save sync, state/economy, profiles, catalogs, run settlement, leaderboards, platform verification, privacy APIs exist | Source implementation is broader than deployment readiness. Provider credentials and external rehearsals remain separate. |
| Schema | Ordered migrations reach 0048, including deletion 0047 and export 0048; rewarded-ad migration 0042 is in existing uncommitted work | Freeze a coherent source/schema release. Migrate before enabling routes that require those tables. |
| Cloud foundation | Terraform roots for state, control plane, development, production; private Cloud SQL, API Cloud Run, secrets, WIF, monitoring, optional RTDN | Owner must provision projects/resources and supply private configuration. No cloud resources exist yet. |
| API deployment | Dockerfile and manual GitHub development build/production digest-promotion workflow exist | Pipeline does not perform migration/publication, worker rollout, or an end-to-end guest/save smoke gate. |
| Migration/bootstrap | Local scripts can migrate and activate development configuration | DEV-CODE-002 remains needed for a managed private-database execution path. The production Docker stage does not copy migrations, scripts, or contracts. |
| Worker | One-shot application context runs configuration activation, run expiration, privacy cleanup, deletion, export, and checkpoint projection | Terraform creates a dormant worker identity, but no deployed worker job or schedule. Worker startup also needs a defined secret-loading path. |
| Readiness | Registered dependency is a database ping | A ping does not verify schema, active content/catalog, build policy, or sync flags. Add integration readiness/preflight checks. |
| First-start sequence | Documentation proposes initial API apply without secret versions; startup probes /health/ready, which is false without a database | Static bootstrap inconsistency: stage infrastructure, secrets and migration before a ready API, or implement a documented equivalent sequence. Not cloud-tested. |
| Connection budget | Terraform sets DATABASE_POOL_MAX; API creates a pool without reading it; worker jobs create separate pools | Enforce the setting and account for all API/worker/migration connections before sizing Cloud SQL. |
| Privacy | Deletion revokes access immediately; worker anonymizes later. Export generation/expiry also needs worker execution | Accepting a request is insufficient unless scheduled completion, retries and alerts work. |
| Remaining product work | Moderation/reporting, broader anti-abuse, store operations, integrity signals, DR/performance qualification, public legal surfaces and admin dashboard remain in backlog | Scope public exposure carefully; broader launch requires additional work. Do not equate infrastructure ticket completion with applied resources. |

References: [Deployment](../../sorting-puzzle-backend/docs/DEPLOYMENT.md), [Terraform runbook](../../sorting-puzzle-backend/infra/terraform/README.md), [Secret management](../../sorting-puzzle-backend/docs/SECRET_AND_KEY_MANAGEMENT.md), [Launch candidate](../../sorting-puzzle-backend/docs/LAUNCH_CONFIGURATION.md), [Backend backlog](../../sorting-puzzle-backend/docs/IMPLEMENTATION_TICKETS.md).

### 2.3 Checks performed for this review

| Check | Observed result |
| --- | --- |
| Backend pnpm lint | Failed: formatting in apps/api/src/ads/admob-ssv-verifier.ts and contracts/configuration/v1/development-client-provenance.json. No automatic fixes applied. |
| Backend pnpm typecheck | Passed. |
| Backend pnpm build | Passed. |
| Backend pnpm test:unit | Passed: 286 files, 1,449 tests. |
| Backend default integration run | Failed: 99 passed, 14 failed, including timeouts and a cleanup deadlock. |
| Integration rerun, --maxWorkers=2, unchanged 10-second test timeout | 107 passed, six failed across four files. Repeatable failures are listed below. |
| Client GAME-001 save tests and PlayerProgress facade | Passed with isolated saves and the correct sibling-fixture layout. |
| Client GAME-006 recovery tests | Reported pass, but emitted an invalid /v1/sessions/refresh URL during a simulated refresh. Treat this as test-harness cleanup work, not clean real-network evidence. |
| GAME-010 contract gate | Passed: 55 fixtures across pinned v1/v1.1/v2, plus client additive checks. This is not an installed Android HTTP test. |
| ADS-008 readiness unit tests | Passed. This verifies gate behavior; it does not approve an ad-enabled release. |
| Python tooling suite | 227 tests executed; nine failing subcase/layout assertions involving moving-belt counts and keyhole row expectations. |
| Materializer --check | Failed: runtime levels 001-007 and 009 differ from template materialization. |
| Backend launch-candidate and development-manifest checks | Both failed; scripts/level.gd is stale in source provenance. |
| Godot content-provenance check | Failed: content_manifest.source_stale. |
| Rendered review | Main menu and a gameplay capture inspected; resolution/harness limits described below. |
| Cloud deployment, remote smoke, release AAB, physical Android, Terraform apply | Not performed. |

The initial isolated GAME-001 run failed only because its temporary project could not resolve sibling backend fixtures. It passed after placing the sibling fixture reference beside the scratch project. Do not classify that initial harness failure as a save implementation defect.

Repeatable backend integration failures:

| File | Failure | Repair direction |
| --- | --- | --- |
| account-merge-store.integration.test.ts | Two idempotency expiry check failures | Test inputs use July 2026 while inserted created_at defaults to database current time. Reconcile fixture and database clock semantics; preserve the expiry invariant. |
| replay-payload-store.integration.test.ts | Expects final migration 0041, receives 0048 | Update the migration expectation to the supported migration set. |
| run-settlement-store.integration.test.ts | Two ad_reward_intents_authorization_fk violations in authorization setup | Construct a valid intent/authorization relationship and verify actual settlement behavior. These tests include existing uncommitted ad work. |
| save-sync-store.integration.test.ts | Direct asset_balances update rejected because balances materialize only from economy_ledger | Seed through the ledger-supported path, then test the life purchase. Do not remove the integrity trigger. |

These are release-baseline failures, not evidence that every corresponding feature is broken. Resolve setup defects and rerun assertions before making that conclusion.

### 2.4 Rendered evidence and its limits

Main-menu contact sheet: [Local review image](../tmp/ui_capture/release_review_main_menu_contact_sheet.png).

The 540x960 and 720x1280 renders have a footer at the bottom. At 1080x1920 and 1080x2400 the level action/footer sit substantially above the bottom, leaving unused background below. Reproduce and assess this on Android; desktop capture/layout behavior may contribute.

The corrected gameplay [contact sheet](../tmp/ui_capture/release_review_level_5_contact_sheet.png), captured with -Position '0,0', shows the shelves and four ability controls inside the viewport at all four exact phone resolutions. At 1080x2400 the board is smaller relative to the screen. The setup loads level 5 without updating the HUD's Level 1 label, so this is layout evidence rather than proof of the full level-selection flow. Verify touch targets and gameplay on devices.

An initial helper-centered Node2D capture displaced the board and was discarded. Neither image establishes a successful full campaign run.

Both capture runs requested 1200x1600, but Windows rendered 900x1600. Those images are **not tablet-resolution evidence**. Obtain an exact squarer portrait render or a real tablet. Gameplay capture also emitted resource-UID/path-fallback and layout warnings; triage clean-import behavior before release.

Review images are ignored scratch artifacts and may not exist in another checkout.

## 3. What blocks which milestone?

| Requirement | Valid first Play upload | Intended connected internal test | Before wider release |
| --- | --- | --- | --- |
| Verified Play developer account and app | Required | Required | Required |
| Permanent package, release signing, valid AAB/version | Required | Required | Required |
| Current target API and compatible Android tooling | Required | Required | Required |
| Working cloud API/database, migrations and publication | Play does not supply or require your backend | Required for this scope | Required |
| Guest sync, secure storage, HTTPS, Internet permission | Depends on app functionality | Required | Required |
| Regression/content repair and device QA | Project quality gate | Required | Required |
| No active mock money purchases/rankings | Honest build behavior | Required | Required |
| Policy/support and deletion/retention operations | General policy and data obligations still apply | Treat as project data-readiness gates | Complete reviewed surfaces required |
| Complete public store listing and all app-content setup | Can be incomplete on internal track | Prepare what Console requests; finish before expansion | Required as applicable |
| Data safety form | Internal-only track is exempt | Inventory actual data now | Required for closed/open/production |
| Play Games, Billing, ads | Conditional on enabled features | Deferred by owner | Required before enabling each feature |
| 12 testers for 14 days | Not an internal-track prerequisite | Not required here | Closed-test production-access rule for qualifying new personal accounts |
| Production GCP runtime and HA/DR qualification | Not required | Development runtime is sufficient | Required before routing public production traffic |

Internal testing supports up to 100 testers and may start before full app setup. Internal-only Data safety exemption is specific to that declaration, not a blanket policy exemption. [Internal testing](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en), [Data safety scope](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).

The new-personal-account closed-test requirement is at least 12 continuously opted-in testers for 14 days before applying for production access. Internal testing does not satisfy that requirement. [Production-access testing](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).

## 4. First-build product configuration

| Capability | First-build behavior |
| --- | --- |
| Campaign, lives, coins, abilities, chests | Functional local-first gameplay; ordinary earned/spent game currency remains usable. |
| Identity | Installation-bound guest; no forced login. |
| Remote persistence | Signed guest bootstrap/resume and save protocol 2.1 to development HTTPS. |
| Platform recovery | Unavailable; explain this limitation to testers. Avoid uninstall/data-clear as a routine troubleshooting instruction. |
| Real-money Shop and starter offer | Hide or provide an explicit unavailable state; no mock grant or fake completed purchase. |
| Public leaderboard | Hide or show an accurate unavailable state; no fabricated rankings. |
| Ads | Provider/native integration disabled; no ad calls or reward buttons that lead to a dead end. |
| Privacy/support | Persistent public policy access, real contact, deletion route and status recovery. |
| Content | Approved finite campaign slice with correct end state; empty chapters unavailable. |

This is a test-build capability profile, not a change to the product's final platform-identity and monetization requirements. Record it in a build manifest and make selection reproducible.

## 5. Detailed execution sequence

### Step 0 — Record release identities and owners

**Owner:** Project/publisher owner. **Dependency:** None.

Confirm the permanent Android package, public title, publisher identity, first test language, intended age groups, tester count, feedback contact, region, and initial supported devices. The current package com.sortingpuzzle.game is a proposal until confirmed; the first uploaded artifact fixes package identity.

Assign the existing billed GCP project to a role. The accepted topology needs distinct control-plane, development, and production project identities. Create missing projects and attach billing; do not silently collapse the architecture. Production services can remain undeployed.

Record GitHub repository/owner numeric IDs, release custodian, infrastructure administrator, secret custodian, and Play owner. Approve a current regional cost estimate, instance limits, and alert recipients. Template budget values are example thresholds, not cost forecasts or spending caps.

**Done when:** A restricted decision record contains non-secret identities/owners and the first-build profile. No unresolved package/environment decision is carried into signing or publication.

Maps to OWNER-001 and OWNER-002.

### Step 1 — Start Google Play account setup immediately

**Owner:** Publisher/Play owner. **Dependency:** Publisher decisions from Step 0.

Create a Play Console developer account using the appropriate personal or organization type, complete required identity/contact/payment verification, enable MFA, and grant scoped access. The current registration fee is a one-time USD 25. New personal accounts also have device-verification requirements; organizations require their applicable business verification. Follow the actual Console account flow. [Play Console registration](https://support.google.com/googleplay/android-developer/answer/6112435?hl=en), [Identity verification](https://support.google.com/googleplay/android-developer/answer/10841920?hl=en).

Create the game app with its title/default language and initial free distribution decision. Configure a private internal tester email list and a real feedback channel. Account verification can proceed while engineering is underway.

**Done when:** Verified account access and an app record exist; the owner can create an internal release. No merchant products, Games OAuth, or AdMob setup is needed for the selected first-build scope.

Maps to OWNER-004.

### Step 2 — Repair regressions and freeze a coherent code baseline

**Owner:** Backend and game engineers. **Dependency:** Step 0 scope.

Resolve the two lint failures and six repeatable database failures listed in section 2.3. Reconcile generator formatting with Biome so regenerating provenance does not recreate the lint failure. Fix moving-belt/keyhole test assumptions or the owned layouts after confirming intended designs.

Triage the GAME-006 mock refresh error, resource UID warnings, and the local integration gate's recorded Android POST-with-body stall. That gate is documented as blocked since July; this review did not prove it fixed. A real remote HTTPS device test is the required evidence for the new release path.

Review existing uncommitted rewarded-ad work and explicitly decide which backend commit contains the release schema/code. Keep disabled ad paths coherent if included; do not silently deploy an arbitrary dirty checkout. Reconcile stale ticket descriptions, particularly campaign count and Freezer status, against current source.

Run the required backend lint/typecheck/unit/integration/build checks and relevant client save/gameplay/tooling checks. Use a bounded local integration configuration if needed, and establish reproducible CI behavior with no unexplained failures.

**Done when:** Selected commits pass checks, remaining warnings have documented disposition, and the release baseline is reproducible. Tests preserve ledger, foreign-key and idempotency invariants.

### Step 3 — Reconcile, regenerate, and publish the campaign

**Owner:** Game/content engineer and backend engineer. **Dependency:** Step 2; repeat after content-affecting edits.

Determine whether each runtime/template mismatch represents intentional authored content or stale output. Preserve intended layouts by updating their authoritative templates/materializer inputs before generation. Do not blindly overwrite live level files to make --check pass.

Run materialization and validate the chosen campaign slice for structure, solvability, progression, ability/chest rules, locked shelves, dispensers, and end-of-content behavior. Confirm whether placeholders 13-20 remain in this internal slice and communicate that to testers. More levels are not inherently required for internal testing.

Regenerate the backend launch candidate from a clean game content commit, then generate the development client manifest into both repositories. This resolves the stale scripts/level.gd source digest. Use the approved publication pipeline to create/activate a **new immutable development configuration**; do not edit existing published artifacts.

Required checks, from the appropriate repository:

    python scripts/tools/materialize_level_templates.py --check
    pnpm check:launch-configuration
    pnpm check:development-client-manifest
    ./scripts/tools/run_isolated_godot_test.ps1 -Script scripts/tools/check_content_provenance.gd

Also check the exported runtime, active database configuration, and packaged manifest. Keep separate cross-repository commits and record their relationship. Late changes to pinned sources require another publication/manifest pass.

**Done when:** Template/runtime checks pass; candidate/manifests match current source; active development publication and AAB content identities agree.

Extends DEV-CODE-001, GAME-002, BE-201.

### Step 4 — Complete the missing backend deployment code

**Owner:** Backend engineer. **Dependency:** Release baseline; run alongside Step 3.

Add a managed development migration/publication job with a separate database role, execution identity and pinned secret. Include migrations and the validated content/catalog artifacts in its container target. Local bootstrap scripts currently depend on sibling game files and local placeholder store URLs; a cloud job must consume frozen packaged artifacts and the real app URL instead.

Stage first provisioning so the API is created with usable secrets and a migrated database before readiness must succeed. The current no-secret initial-API instructions conflict with the /health/ready startup probe. Resolve this in source/runbooks without weakening normal readiness.

Extend readiness or a mandatory deployment preflight to verify schema version, active development configuration/catalog, supported build policy, and both v2 recovery/ingestion flags. A database ping alone cannot establish a usable game backend. Disabled platform providers must not block guest-only readiness.

Deploy the one-shot worker as a Cloud Run Job with a private database path and Cloud Scheduler invocation. Define worker-runtime loading; mounting the reserved secret container alone does not initialize DATABASE_URL. Use least privilege, job failure/retry visibility, and overlap protection. Keep privacy work at least hourly as current commitments require; choose a faster schedule if checkpoint-projection latency needs it. [Scheduled Cloud Run jobs](https://docs.cloud.google.com/run/docs/execute/jobs-on-schedule).

Make API pooling consume DATABASE_POOL_MAX and bound/reuse worker pools. Recalculate total connections across maximum API instances, concurrent worker execution and migration jobs, leaving operational reserve. The Terraform pool arithmetic currently does not match API code.

Add remote smoke automation and deployment gates for migrations, API/worker compatibility and safe logs. Keep schema rollback as forward fixes and configuration rollback as prior-pointer activation.

**Done when:** A clean private database can be initialized and the packaged API/worker can operate without a developer workstation or sibling checkout.

Maps to DEV-CODE-002/003/012 plus the worker and connection-budget gaps found here.

### Step 5 — Provision cloud state, control plane, and development foundation

**Owner:** Infrastructure/billing owner. **Dependency:** Step 0 decisions; Step 4 provisioning sequence.

Install the repository-pinned Terraform toolchain and current Google Cloud CLI; authenticate the human bootstrap operator. Enable required APIs and provision in this order:

1. State root: protected GCS state bucket; migrate bootstrap state to its remote backend.
2. Control-plane root: immutable Artifact Registry, budgets, and environment-scoped GitHub WIF.
3. Development foundation: VPC/subnet/private service networking, private PostgreSQL 17 Cloud SQL, database, runtime/job identities, secret containers, logs, dashboards and alert routing.

Use reviewed ignored variable files with real non-secret project IDs and repo IDs. Resolve the API/secret/job bootstrap ordering from Step 4. Include the Cloud Scheduler API when worker scheduling is added.

Configure the development GitHub Environment variables expected by deploy.yml: ARTIFACT_IMAGE_URI, GCP_PROJECT_ID, GCP_REGION, WIF_PROVIDER, DEPLOY_SERVICE_ACCOUNT. Restrict federation to the intended repository, workflow, main branch and environment. No long-lived service-account key is needed.

Keep production runtime unapplied. Control-plane configuration may still need the reserved production project identity. Validate baseline monitoring, finite API scaling, and database backups.

**Done when:** Applied development resource inventory and Terraform state match; secret containers exist; GitHub deploy identity works; no production player service was started.

Follow [Terraform runbook](../../sorting-puzzle-backend/infra/terraform/README.md). Maps to OWNER-002 and BE-009/011.

### Step 6 — Materialize secrets, migrate, and activate development data

**Owner:** Secret custodian and backend release owner. **Dependency:** Steps 3-5.

Create distinct API, worker and migration database roles. Generate development token-signing, offline-lease-signing and encryption keyrings with the prescribed schemas; provide API runtime credentials and the minimum worker/migration documents. Keep private values out of Git, Terraform state, build arguments, chat, CI output and app resources.

Add Secret Manager versions out of band and pin numeric versions in runtime/job configuration. Audit access. Verify private database routing and required encrypted connectivity for each role; do not add a public database address to avoid the managed job.

Build/push the first backend image through the documented bootstrap identity and record its digest. Execute migrations and development publication through the managed job, then verify migration checksums, immutable configuration/catalog, build support and real store URL.

The reviewed full schema reaches 0048; 0047 and 0048 are prerequisites for deletion/export routes. Resolve inclusion of existing uncommitted 0042 before freezing the release. Enable v2 recovery before ingestion and keep unsupported legacy behavior compatible.

**Done when:** Managed execution reports safe migration/publication IDs; the development database is ready for the chosen API digest; no required secret or schema is missing.

Maps to OWNER-003, BE-005/010/201/307.

### Step 7 — Deploy and qualify the API and worker

**Owner:** Backend release owner. **Dependency:** Step 6.

Deploy the API by immutable digest to Cloud Run. Use its managed public HTTPS origin for the app; a custom API domain is optional. Public platform invocation is expected for mobile clients, while application routes authenticate guest/player sessions.

Execute a remote smoke flow: liveness/readiness, guest challenge/signature/bootstrap, resume/refresh, v2 checkpoint read, signed journal sync, exact duplicate retry, and persistence inspection. Confirm the content identity, environment and client build. Do not log request proofs/tokens or exported player data.

Run the worker manually, then verify scheduled executions and each enabled processing path. Confirm a test deletion reaches anonymized completion and an export can be generated/expired where offered. Exercise outbox checkpoint projection even if ranking UI is hidden, or document deliberate postponement while privacy/retention still run.

Apply basic public guest-registration abuse controls, finite scaling, request limits and useful alerts. The internal app track does not make the public API private. Keep administration disabled unless its IAP boundary is configured.

Rehearse rollback to a previous compatible API revision and prior configuration pointer. For a first deployment, establish a known healthy baseline before treating rollback as tested. Take/restore a development backup to verify data recovery, not only that backup scheduling is enabled.

**Done when:** HTTPS guest/save operations succeed off the developer network; jobs run on schedule; operators receive failures; rollback and a development restore have usable records.

### Step 8 — Add a closed Android build configuration

**Owner:** Game engineer. **Dependency:** Step 0 identifiers; Step 7 HTTPS URL.

Add an Android internal-development **release** preset and a reproducible environment-selection/export step. Choose values together: development HTTPS origin, save sync enabled, correct secure-storage singleton/bridge, approved content, app version/build, first-build capabilities and privacy/support URLs.

Implement a genuine disabled money-purchase path and gate Shop/starter flows. StoreService currently falls back to MockStoreProvider for any unknown value; setting store_provider=disabled alone would still simulate purchases. Preserve ordinary earned coin spending and abilities.

Gate public/mock leaderboard UI and ad entry points. Keep AdMob native-export flags off and verify the packaged dependencies/permissions. Do not treat the existing Android+iOS ad-release audit as a general Android release gate; retain its incomplete evidence for the later ad phase.

Build and include the secure-store **release** AAR. Make export validation reject a missing bridge, non-HTTPS/empty remote URL, packaged local/backend_debug.cfg, mixed environments, stale provenance, wrong package or incompatible build. Explicitly enable INTERNET and reject cleartext in the merged manifest.

Restrict resources to the intended shipped product without breaking dynamic loading. Exclude local development overrides, tests and unnecessary preview assets. Current debug APK is about 170.1 MiB; this is not the Play per-device compressed size. Measure the release AAB in Play and keep the download reasonable. [Play size measurement](https://support.google.com/googleplay/android-developer/answer/9859372?hl=en).

**Done when:** The build manifest identifies environment, source commit, version/build, protocol and content digests; packaged settings are correct; no enabled mock money flow or local host remains.

Maps to Android scope of DEV-CODE-004.

### Step 9 — Update Android toolchain, signing, and bundle packaging

**Owner:** Game/build engineer and upload-key custodian. **Dependency:** Step 8; Play app identity.

New mobile submissions currently require Android 16/API 36 or higher, effective August 31, 2026. The committed target 35 must change. Keep Godot 4.6.2 and matching export templates; prepare a reproducible compatible Gradle template with compile/target 36. The installed ignored Android directory must not be the only record of required patches. Android documents AGP 8.9.1 as the minimum for API 36, above the current installed 8.6.1. Validate its compatible Gradle/JDK/plugin set. [Target policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en), [Android tool compatibility](https://developer.android.com/build/releases/about-agp), [Godot 4.6 export](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html).

Keep minimum SDK 24 if supported by actual dependencies and device tests; target SDK and minimum SDK are separate. Include arm64. Add x86_64 only where useful and verify all shipped native libraries.

Create/store the upload key outside the repository, supply signing credentials through the supported protected export path, and enroll in Play App Signing. Record Console-provided app-signing fingerprints for future platform integration; Play-distributed APKs use Play's signing identity. Do not reuse a local debug key. [App signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en).

Export a signed **AAB**, with a unique versionCode and consistent application build metadata. Validate bundle contents, permissions, signing, package, native architectures, and bundletool-generated split APKs. Test the release variant; a debug APK is insufficient.

Verify 16 KB ELF and packaging alignment and test a 16 KB Android environment. Current guidance states that incompatible updates become blocked from February 1, 2027; still make compatibility a quality gate now. Inspect every native dependency, not just Godot's version. [16 KB compatibility](https://developer.android.com/guide/practices/page-sizes).

**Done when:** The signed AAB validates, targets API 36, has a recorded checksum, and installs/runs as split APKs on intended architectures.

### Step 10 — Finish privacy/support and content declarations

**Owner:** Publisher/legal owner plus game/backend engineers. **Dependency:** Actual first-build data inventory and Step 7 services.

Publish an accessible HTTPS privacy policy and real support contact. An API custom domain is not required, and legal pages may use an appropriate hosted URL. Decide hosting/publisher identity before publishing text.

Describe actual guest identifiers, installation public keys, save/profile data, network/security logs, purposes, hosting, retention and deletion. Explain that this build has no active purchases/ads/platform sign-in. Do not copy disclosures for SDKs that are absent, or claim no collection when guest sync stores data.

Provide persistent in-app policy access independent of consent forms. Implement GAME-012 using its already confirmed confirmation, uncertain-outcome, native-key cleanup and explicit-new-game decisions. Verify it against the deployed DELETE endpoint and scheduled worker. A local reset is not server account deletion.

Prepare the external deletion request resource and secure ownership-verification/support procedure. Google provides in-app and web deletion requirements for apps offering account creation; review applicability to the installation-bound guest design rather than assuming silent signup is exempt. The repository already treats guests as deletable accounts, and this plan treats deletion operation as a tester-data gate. Public policy must explain retained records and completion expectations. [Account deletion guidance](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).

Backend export exists, but client request/download UX and a public rights-request surface are separate. Supply an authenticated, operational support path for this test; complete the planned user-facing export flow before it is promised or required for the selected markets. Never identify ownership using only an arbitrary player ID from an email.

Prepare app access instructions, honest no-ads/no-money declarations, and target-audience/content-rating answers for the actual build. A 3+ content rating does not decide target age groups. Child-inclusive targeting requires the applicable Families policy. Publisher/market legal review owns that decision. [Audience settings](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en).

The internal-only Data safety form is exempt, but create the inventory now. Complete applicable app-content forms when Console requests them and before expansion. Public listing assets can follow: reviewed title/description, 512x512 icon, 1024x500 feature graphic and authentic screenshots. Existing icon.svg is not evidence of a completed Play asset package. [Review preparation](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en), [Listing assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

Audit font/engine/plugin/art/audio distribution rights and provide required notices. If new art is generated, follow the repository's direction and candidate-selection requirements.

**Done when:** Real URLs/contact work, tester data can be deleted through an operated process, declarations match the artifact, and release notices/rights are recorded.

Maps to GAME-012, BE-606/607/608/614, legal research and OWNER-004.

### Step 11 — Qualify the release on real Android devices

**Owner:** Game/backend QA and named testers. **Dependency:** Steps 7-10.

Use at least a low/mid-range physical Android phone and a recent phone, plus exact tablet-like evidence. Test the chosen minimum OS range and API-36 behavior. Use the release AAB/splits and then the Play-delivered build.

| Scenario | Required evidence |
| --- | --- |
| Fresh online install | Automatic guest registration, secure bridge/key binding, playable level 1, expected initial resources. |
| Fresh offline launch | Play proceeds locally; reconnect binds/syncs without discarding local progress. |
| Complete/fail/leave levels; spend coins/abilities; earn/open chest | Correct local outcomes and accepted remote checkpoint; no duplicate grant/spend on retry. |
| Airplane mode and reconnect; Wi-Fi/mobile switch | No network requirement for campaign; queued operations eventually accepted once. |
| App background, force-stop/process death, restart, expired access | Stable identity/session and journal; fresh refresh/retry semantics; no stuck sync. |
| Lost response, duplicate sync, API downtime or server 5xx | Exact retry/idempotency and eventual convergence; no progress loss. |
| Update N to N+1 | Save and native key remain usable; unique versionCode; compatible old/new backend behavior. |
| Corrupt local generation and checkpoint recovery | Recovery respects account namespace and valid journal state. |
| Deletion and interrupted deletion | Server access revoked, public/cache state removed, worker completes, local key/save cleanup succeeds, uncertainty is handled safely. |
| Campaign boundary and depleted lives | No missing next level, unreachable chapter or fake ad/money rescue flow. |
| Main menu/gameplay/modals/Shop/profile/support | Rendered and touch-tested at 540x960, 720x1280, 1080x1920, 1080x2400 and an exact squarer portrait size; safe areas, system Back, keyboard and drag/drop work. |
| Native compatibility/performance | 16 KB run, acceptable frame pacing/memory/startup, renderer behavior, and no crash/ANR; release log review. |

Do not promise cross-device or uninstall recovery for this guest build. Reinstall/data-clear testing is a deliberate destructive QA case with explicit expectations, not an update test.

**Done when:** A release report lists device/OS/build, scenarios, screenshots, checkpoint evidence and resolved blockers. Corrected gameplay capture is supporting evidence only.

Maps to Android portion of DEV-CODE-012 and OWNER-010.

### Step 12 — Publish to Google Play internal testing

**Owner:** Play release owner. **Dependency:** Account/app, validated AAB and connected-release gates.

1. Open the app's Test and release > Testing > Internal testing page.
2. Add/select the internal tester list, set a real feedback channel, and save.
3. Create a release; upload the signed AAB; select/configure Play App Signing as prompted.
4. Check package/version, device support and Console validation. Resolve errors and explain any warning; do not rely on internal-track exemptions to bypass artifact problems.
5. Add release notes identifying test scope, guest-recovery limits and known non-blocking issues. Save/review and start the internal rollout.
6. Wait for publication availability; first app/test links may take time and an unfinished listing may have a temporary name.
7. Record the opt-in link and Play listing link. Provide them to the selected testers through the agreed feedback process; users need to opt in with an eligible Google account.
8. Have at least one physical tester install from Play and repeat guest/save/update smoke checks against development.

A debug-signed sideloaded app with the same package may not upgrade to the Play-signed version. Use a clean dedicated tester installation or a deliberately planned migration; do not accidentally erase valued local saves. Internal App Sharing is a different distribution mechanism and is not the requested track.

If purchases are later enabled, license testers are a separate configuration; internal-track membership alone does not prevent real charges. [Track setup and tester rules](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en), [Release preparation and rollout](https://support.google.com/googleplay/android-developer/answer/9859348).

**Done when:** An allowed tester installs through the internal track and synchronizes to the expected cloud environment; publication and build evidence are recorded.

### Step 13 — Operate the test and release updates

**Owner:** Release owner, backend operator, QA. **Dependency:** Step 12.

Monitor API errors/latency, guest bootstrap, sync rejection/retry rates, worker failure/lag, database connections, privacy deadlines and costs. Check Android vitals/reports when available and collect direct tester feedback. Do not claim automated pre-launch coverage for a track where no report was generated.

Triage data loss, key-binding failure, privacy/deletion failure, crashes and incorrect grants ahead of polish. Keep a release issue list with reproduction/device/build and redacted evidence.

Build fixes with an increased versionCode and run the relevant gates; verify upgrade from the previous Play version. Keep the backend compatible with both installed builds. For backend failure, restore compatible traffic/configuration; for a defective app, publish a fixed higher version because installed users cannot be downgraded by uploading an older code.

Freeze the successful test release with both repository commits, container digest/revision, migrations, configuration/catalog IDs, client manifest, AAB checksum/version, signing certificate references, URLs, device results and operating owner. Keep secret material and player payloads out of that record.

**Done when:** Testers have a stable connected build and operators have feedback, alerts, recovery instructions and a reproducible next release.

## 6. Dependency order and work that can overlap

| Milestone | Dependencies | Completion evidence |
| --- | --- | --- |
| M0: Release identity/account | Steps 0-1 | Decisions and verified Console access. |
| M1: Code/content baseline | Steps 2-3 | Green checks and coherent content identities. |
| M2: Deployable backend tooling | Step 4 | Packaged migration/publication and worker jobs; readiness and pooling repaired. |
| M3: Connected development backend | Steps 5-7; M1/M2 | Private database, pinned secrets, healthy API, scheduled worker, remote smoke/restore. |
| M4: Candidate release app | Steps 8-10; M0/M3 | API-36 signed AAB with exact environment and privacy controls. |
| M5: Qualified installed release | Step 11; M4 | Physical-device and responsive test report. |
| M6: Internal testing live | Steps 12-13; M5 | Play install, cloud sync and operated feedback loop. |

Start account verification and legal preparation while repairing code/content and deployment tooling. Provision reviewed foundation once Step 4's staging sequence is defined. Environment export structure can be developed before the API exists, but final URL/content injection and device sync qualification depend on M3.

No reliable calendar date can be derived from this review: console verification, release-key custody, intended content repairs and physical-device access are external dependencies. Estimate engineering batches after owners are assigned; avoid promising a launch date from ticket counts.

## 7. Later integration phases

These are required before enabling their capabilities, not blockers for the owner-selected guest-sync test.

| Phase | Game work | Backend/console work | Acceptance |
| --- | --- | --- | --- |
| Google Play Games identity | DEV-CODE-006 and shared account promotion/switch/merge UX from 008 | OWNER-005: PGS v2, exact package plus Console app-signing certificates, game-server Web OAuth client, tester audience, pinned server credentials | Silent sign-in, fresh server-code exchange, guest fallback, account isolation and genuine linked recovery. |
| Public leaderboards/profiles | Verified-session reader, reporting/moderation UI and honest eligibility | BE-504/505 and necessary anti-abuse; operated checkpoint projection, moderation and support | No fabricated users; correct score/period/country/profile behavior and abuse response. |
| Google Play Billing | DEV-CODE-009: native provider, product prices, intent/verification/status/restart flow; server-owned grants | OWNER-006/DEV-CODE-011: products, merchant setup, minimal Publisher access, license testers, RTDN and reconciliation | Pending/cancel/duplicate/response-loss/refund/account-binding tests; no client catalog/provider grant. |
| Rewarded ads | Native AdMob/UMP configuration, test ads/devices, exact effect authorization and consent | Environment ad-unit mappings, SSV callback/key rotation/status recovery, privacy/store evidence | Four placements verified end to end; no client-only reward; interstitials remain disabled under initial policy. |
| Wider distribution | Honest complete listing/localizations, full privacy/export/legal surfaces, all user-visible integrations | Applied isolated production, monitored SLOs, restore/DR/performance, stronger anti-abuse/operations, closed-test requirements if applicable | Formal wider-release checklist and evidence; build/content/backend promotion reviewed together. |

For PGS, the server access flow uses a server authorization code exchanged by the backend; no OAuth secret belongs in the AAB. [Google server access](https://developer.android.com/games/pgs/android/server-access).

When implementing Billing, choose a supported library version. The current schedule retires version 7 for submissions after August 31, 2026, and version 8 after August 31, 2027; use version 8 or newer as appropriate and recheck at implementation. [Billing support timeline](https://developer.android.com/google/play/billing/deprecation-faq).

The existing ad audit includes both Android and iOS evidence and identifiers. Introduce a reviewed platform/scope-aware gate when that phase starts; do not mark unperformed iOS verification complete to release Android. Retain incomplete external approvals honestly.

Before public production, complete the relevant remaining BE-605/609-616 operational/security/compliance work or record a justified release-specific disposition. A full graphical admin dashboard is not necessary to install the first internal AAB, but usable restricted support/operating procedures are necessary.

## 8. Final connected internal-release checklist

- [ ] Permanent package/publisher/environment/test scope recorded.
- [ ] Verified Play account/app and internal testers configured.
- [ ] Both repositories have a coherent committed release baseline.
- [ ] Backend required checks and relevant client/content checks pass.
- [ ] Runtime/templates reconciled; candidate/provenance/publication agree.
- [ ] Development cloud state/resources provisioned with cost/alert owners.
- [ ] Separate DB roles and pinned secret versions are usable and audited.
- [ ] Managed migrations/publication complete before dependent API routes.
- [ ] Readiness verifies integration inputs; actual pools obey connection ceilings.
- [ ] HTTPS API and scheduled worker pass remote smoke and privacy checks.
- [ ] Build selects development sync and release secure storage, with no local override.
- [ ] Fake Shop/ranking and ad flows are unavailable in the tester build.
- [ ] API-36 signed AAB, unique versionCode and consistent build metadata validated.
- [ ] Native/16 KB compatibility and Play-generated split installation verified.
- [ ] Policy/support/deletion process and accurate declarations are ready.
- [ ] Physical-device save/retry/restart/update and exact responsive QA pass.
- [ ] Internal-track Play install succeeds and syncs to development.
- [ ] Release evidence, feedback channel, monitoring and recovery owners recorded.

## 9. Maintaining this plan

This is a dated audit, not a replacement for canonical requirements or ticket ownership. Recheck official Google requirements immediately before uploading and update observed status when an execution batch completes.

Document each code/scene/config/infrastructure batch in its owning docs and commit it in the correct repository. Record sibling commit and publication references for cross-repository work. Source tests alone do not establish deployed readiness, and rendered desktop captures do not establish physical Android behavior.
