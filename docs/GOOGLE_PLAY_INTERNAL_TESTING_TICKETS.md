# Google Play internal testing: execution tickets

Created: **2026-10-03**, from the [2026-10-02 release audit and detailed plan](GOOGLE_PLAY_INTERNAL_TESTING_PLAN.md). Read the [abstract](GOOGLE_PLAY_INTERNAL_TESTING_ABSTRACT.md) for the overall goal.

**Scope:** Android gameplay and deployed guest save sync in the development environment. Google Play Games sign-in, real-money purchases, advertising, and public rankings remain later work.

**Status:** GPI-001 through GPI-028 are **Planned**; GPI-101 through GPI-105 are **Deferred**. Creating this backlog does not complete implementation, provision cloud resources, or publish an app. Owners are roles to assign in GPI-001. The only confirmed external resource is one billed Google Cloud project; Terraform has not been applied.

There are **28 first-release tickets** and **5 deferred tickets**. GPI-001 through GPI-027 are required to achieve the intended connected internal release. GPI-028 covers operating that release and subsequent updates. Deferred tickets do not block this release.

## How to use this backlog

- Each GPI ticket is an execution work package for this release. Existing GAME, DEV-CODE, OWNER, and BE tickets retain their feature specifications and canonical ownership; update their status/evidence when a GPI package completes. Do not implement the same work twice.
- Dependencies below are hard completion prerequisites. Independent preparation can start earlier; for example, export code can be implemented before its final HTTPS origin is available.
- Follow the owning repository's `AGENTS.md`. Backend execution requires its canonical requirements, protocol, validator boundary, and implementation tickets. Keep cross-repository commits separate and record their relationship.
- Close code tickets with a committed change, required checks, updated owning docs, and a non-secret evidence link. Close setup/QA tickets with the resource or artifact identity, actual execution results, and an assigned operating owner. Record test date and source commits; the audit's past results are not new execution evidence.
- UI changes require rendered verification at the specified responsive sizes. Installed Android behavior requires device evidence. Android-only tickets do not acquire an iOS verification prerequisite from the broader cross-platform backlog.
- Keep private keys, secret payloads, player data, tester addresses, and tokens out of these tickets and Git. Record restricted evidence locations and non-secret identifiers instead.
- After any late edit to a provenance-pinned source, reopen GPI-019 and repeat affected publication, packaging, and QA gates. A fix after qualification invalidates the evidence for the replaced artifact.

## Ticket index

### Decisions, regressions, and game work

| Ticket | Work package | Owner | Depends on |
| --- | --- | --- | --- |
| [GPI-001](#gpi-001) | Lock release identities, scope, owners, and cost envelope | Publisher + infrastructure owner | None |
| [GPI-002](#gpi-002) | Create and verify the Play account/app | Play owner | 001 |
| [GPI-003](#gpi-003) | Fix backend formatting and generator drift | Backend engineer | 001 |
| [GPI-004](#gpi-004) | Repair database integration tests and establish the backend baseline | Backend engineer | 003 |
| [GPI-005](#gpi-005) | Repair client tooling and isolated test harnesses | Game engineer | 001 |
| [GPI-006](#gpi-006) | Reconcile campaign content and end-of-content behavior | Game/content engineer | 005 |
| [GPI-007](#gpi-007) | Disable mock money/ranking and ad flows | Game engineer | 001 |
| [GPI-008](#gpi-008) | Publish policy/support pages and define data-request handling | Publisher + privacy/support owner | 001 |
| [GPI-009](#gpi-009) | Execute GAME-012 and persistent privacy access for Android | Game engineer | 007, 008 |
| [GPI-010](#gpi-010) | Make the Android API-36 toolchain reproducible | Android build engineer | 001 |
| [GPI-011](#gpi-011) | Add a safe internal-release export and secure-store gate | Game/build engineer | 007, 009, 010 |

### Backend engineering and cloud setup

| Ticket | Work package | Owner | Depends on |
| --- | --- | --- | --- |
| [GPI-012](#gpi-012) | Package managed migration and publication execution | Backend engineer | 001 |
| [GPI-013](#gpi-013) | Repair first-start sequencing and integration readiness | Backend + infrastructure engineer | 012 |
| [GPI-014](#gpi-014) | Enforce API/worker database connection limits | Backend engineer | 001 |
| [GPI-015](#gpi-015) | Package and schedule the worker with secret loading | Backend + infrastructure engineer | 012, 014 |
| [GPI-016](#gpi-016) | Add deployment automation and remote guest/save smoke | Backend/release engineer | 004, 012, 013, 014, 015 |
| [GPI-017](#gpi-017) | Provision state, control plane, and development foundation | Infrastructure/billing owner | 001, 013, 014, 015 |
| [GPI-018](#gpi-018) | Create database roles and pin development secrets | Secret custodian + database owner | 017 |
| [GPI-019](#gpi-019) | Freeze source and regenerate candidate/provenance artifacts | Game + backend release engineer | 002, 004, 006, 009, 011, 016 |
| [GPI-020](#gpi-020) | Run managed migrations and activate development content | Backend release owner | 012, 018, 019 |
| [GPI-021](#gpi-021) | Deploy API/worker and pass remote smoke | Backend release owner | 016, 020 |
| [GPI-022](#gpi-022) | Qualify abuse limits, alerts, backup restore, and rollback | Backend/infrastructure operator | 021 |
| [GPI-023](#gpi-023) | Verify remote deletion/export and support operations | Privacy/support + backend owner | 008, 009, 021 |

### Packaging, qualification, and release

| Ticket | Work package | Owner | Depends on |
| --- | --- | --- | --- |
| [GPI-024](#gpi-024) | Sign and validate the candidate AAB | Build engineer + upload-key custodian | 002, 011, 019, 021 |
| [GPI-025](#gpi-025) | Qualify gameplay, responsive UI, and native performance | Android QA + game engineer | 024 |
| [GPI-026](#gpi-026) | Qualify guest sync, recovery, deletion, and app updates on devices | Android QA + backend engineer | 022, 023, 024 |
| [GPI-027](#gpi-027) | Publish and verify the Play internal release | Play/release owner + QA | 025, 026 |
| [GPI-028](#gpi-028) | Operate tester feedback and release updates | Release/support owner | 027 |

The starting batch is GPI-001. After its decisions, Play verification, policy preparation, regression repairs, feature gating, Android tooling, and backend deployment engineering can proceed in parallel. Cloud provisioning waits for the corrected bootstrap/job definitions. Final content generation waits for changes to pinned game sources.

## GPI-001

**Lock release identities, scope, owners, and cost envelope**

**Owner:** Publisher and infrastructure owner. **Scope:** Decision/setup records. **Depends on:** None.

**Work**

- Permanent package decided as `com.vbrus.sortingpuzzle` (2026-10-14). Confirm the public title, publisher, first language, age audience, tester/device scope, feedback contact, region, and first version/build numbering policy.
- Assign the existing billed GCP project to control-plane, development, or production. Record three distinct project identities under the accepted topology; production runtime deployment can wait.
- Assign named owners for Play, signing, infrastructure, secrets, database changes, QA, privacy requests, and operations. Record repository numeric IDs, a current regional cost estimate, instance ceilings, and alert recipients.

**Acceptance and verification**

- [ ] A decision record contains all non-secret identifiers and assigned owners, with no unresolved package/environment choice.
- [ ] The first build is explicitly guest gameplay + development save sync; platform integrations are deferred.
- [ ] Cost assumptions and limits are recorded; a budget alert is not described as a spending cap.

**Existing work:** OWNER-001/002 in [owner tickets](DEV_BACKEND_OWNER_TICKETS.md). **Plan:** Step 0.

## GPI-002

**Create and verify the Google Play account and app**

**Owner:** Play/publisher owner. **Scope:** Play Console. **Depends on:** GPI-001.

**Work**

- Choose the applicable personal/organization account type, complete registration and required identity/contact/device/business verification, enable MFA, and grant scoped release access.
- Create the app record with confirmed title, default language, free-distribution decision, and package linkage when Console requests it. Record the intended Play URL for publication configuration.
- Prepare a restricted internal tester list and real feedback channel; identify the upload-key custodian and Play App Signing procedure. Keep tester addresses in the restricted Console record.

**Acceptance and verification**

- [ ] Verified account and app access exist and the owner can prepare an internal release.
- [ ] Tester configuration and feedback channel are ready; first-upload package identity agrees with GPI-001.
- [ ] No Games OAuth, merchant products, or AdMob setup is treated as a prerequisite for this scope.

**Existing work:** OWNER-004 in [owner tickets](DEV_BACKEND_OWNER_TICKETS.md). Signing artifact execution is GPI-024; rollout is GPI-027. **Plan:** Step 1.

## GPI-003

**Fix backend formatting and provenance-generator drift**

**Owner:** Backend engineer. **Scope:** Backend repository. **Depends on:** GPI-001.

**Work**

- Repair the observed formatting failures in `apps/api/src/ads/admob-ssv-verifier.ts` and `contracts/configuration/v1/development-client-provenance.json`.
- Align provenance generation with the repository's formatter so regeneration does not recreate the JSON failure.
- Coordinate with the owner of existing uncommitted rewarded-ad changes; commit only the reviewed, intended batch.

**Acceptance and verification**

- [ ] `pnpm lint` passes on the selected backend source.
- [ ] Regenerating provenance produces formatter-compliant output and no unexplained diff on a second generation.
- [ ] Relevant generator tests and required backend checks pass; unrelated work is preserved.

**Existing work:** Release-audit regression repair; provenance relates to DEV-CODE-001 in [code tickets](DEV_BACKEND_CODE_TICKETS.md). **Plan:** Step 2.

## GPI-004

**Repair database integration tests and establish a coherent backend baseline**

**Owner:** Backend engineer. **Scope:** Backend repository/CI. **Depends on:** GPI-003.

**Work**

- Repair the six repeatable failures recorded in the audit: account-merge fixture/database clock mismatch; obsolete final-migration expectation; invalid rewarded-ad intent/authorization setup; and save-sync balance seeding through a forbidden direct update.
- Preserve idempotency expiry, foreign keys, and ledger materialization. Use valid fixture relationships and supported ledger writes rather than removing database safeguards.
- Resolve resource contention/cleanup instability and establish a reproducible local/CI concurrency setting. Decide and commit the release schema/code, including the disposition of existing rewarded-ad changes even though ads are disabled.

**Acceptance and verification**

- [ ] Backend lint, typecheck, unit, integration, and build checks all pass on a recorded committed baseline.
- [ ] Integration runs have no unexplained timeout/deadlock failures; bounded execution, if needed, is documented in CI.
- [ ] The chosen migration set and source commit are explicit; the release is not built from an arbitrary dirty checkout.

**Existing work:** Relevant BE-005/007/207/307 specifications in [backend tickets](../../sorting-puzzle-backend/docs/IMPLEMENTATION_TICKETS.md). **Plan:** Step 2 and audit section 2.3.

## GPI-005

**Repair client tooling and isolated save/contract test harnesses**

**Owner:** Game engineer. **Scope:** Game repository. **Depends on:** GPI-001.

**Work**

- Reconcile the moving-belt count and keyhole row assertions with their intended layouts; repair the responsible tests or implementation after confirming the intended behavior.
- Make isolated projects resolve sibling backend fixtures reproducibly. Remove the simulated GAME-006 refresh's invalid relative URL and establish clean save/recovery test output.
- Triage clean-import resource UID warnings and document the old Android POST-with-body stall as unresolved until GPI-026 supplies real-network evidence.

**Acceptance and verification**

- [ ] The Python tooling suite passes, including all previously failing subcases.
- [ ] GAME-001 saves, PlayerProgress facade, GAME-006 recovery, and GAME-010 contract checks run reproducibly without the fixture-layout or invalid-URL errors.
- [ ] Remaining warnings have a specific disposition; local tests are not described as remote Android proof.

**Existing work:** GAME-001/006/010 in [game tickets](IMPLEMENTATION_TICKETS.md). **Plan:** Step 2.

## GPI-006

**Reconcile campaign sources and define a safe finite internal campaign**

**Owner:** Game/content engineer. **Scope:** Game repository; publication inputs. **Depends on:** GPI-005.

**Work**

- Review runtime/template differences for levels 001-007 and 009. Preserve intentional authored layouts in the authoritative inputs before regenerating runtime files.
- Select the finite test slice and explicitly decide whether placeholder levels 13-20 belong in it. Validate structure, solvability, progression, lives, abilities, chests, locks, and dispensers for included content.
- Implement/verify the terminal completion/menu behavior and keep empty or unreachable chapters unavailable. Update stale campaign/Freezer ownership descriptions against current source.

**Acceptance and verification**

- [ ] `python scripts/tools/materialize_level_templates.py --check` and relevant content validation pass.
- [ ] The chosen slice and placeholder status are documented; completing its final level never requests missing content.
- [ ] Any changed UI is rendered at representative sizes and gameplay/terminal behavior is exercised.

**Existing work:** DEV-CODE-001, GAME-002/011 and [project map](PROJECT_MAP.md). Final digests/publication are GPI-019/020. **Plan:** Step 3.

## GPI-007

**Disable mock money purchases, fabricated rankings, and ad entry points**

**Owner:** Game engineer. **Scope:** Game repository/export capabilities. **Depends on:** GPI-001.

**Work**

- Add an actual unavailable/disabled money-purchase provider path. Unknown or disabled release settings must not fall back to `MockStoreProvider`; gate Shop money offers and starter purchase actions.
- Keep ordinary earned coins, coin spending, abilities, lives, and chests usable. Hide public ranking or show an accurate unavailable state instead of mock players.
- Disable rewarded/interstitial entry points and native ad export flags for this profile. Ensure depleted-life/time/ability flows remain usable without dead ad or purchase buttons.

**Acceptance and verification**

- [ ] Every reachable money action cannot simulate a purchase or grant; ordinary gameplay economy still works.
- [ ] No fabricated public ranking or enabled ad flow appears in the release profile.
- [ ] Focused provider/gating tests and rendered UI review cover these states; packaged SDK inspection is repeated in GPI-024.

**Existing work:** GAME-008/009 and ADS-008 ownership; [detailed plan](GOOGLE_PLAY_INTERNAL_TESTING_PLAN.md) section 4. **Plan:** Step 8.

## GPI-008

**Publish privacy/support pages and define data-request handling**

**Owner:** Publisher and privacy/support owner. **Scope:** Public pages and restricted operating procedures. **Depends on:** GPI-001.

**Work**

- Choose page hosting and publish an accessible HTTPS policy with a real support contact. Replace `.example` details and empty policy configuration with approved values.
- Inventory actual guest identifiers, installation public keys, save/profile data, logs, purposes, hosting, retention, and deletion. Match the no-purchases/no-ads/no-platform-login build and define honest test-language/audience disclosures.
- Prepare an external deletion request resource with secure ownership verification, retained-record explanation, and completion expectations. Define authenticated support handling for data access/export; a player ID alone is insufficient proof.
- Prepare an asset/font/engine/plugin license inventory and the app-content answers needed for this build. Recheck account-deletion applicability for the guest design rather than assuming exemption.

**Acceptance and verification**

- [ ] Policy/support/deletion URLs work in a public browser and contain approved publisher/contact information.
- [ ] A named operator can handle a verified rights request without exposing another player's data; export processing is qualified in GPI-023.
- [ ] Data, audience, language, and license records match the planned artifact; wider-track Data safety preparation is distinguished from the internal-only exemption.

**Existing work:** BE-614 in [backend tickets](../../sorting-puzzle-backend/docs/IMPLEMENTATION_TICKETS.md); OWNER-004. **Plan:** Step 10.

## GPI-009

**Execute GAME-012 account deletion and persistent privacy access for Android**

**Owner:** Game engineer. **Scope:** Game and Android secure-store bridge; existing deletion specification. **Depends on:** GPI-007, GPI-008.

**Work**

- Implement the Android execution slice of [GAME-012's approved account-deletion plan](ACCOUNT_DELETION_PLAN.md), including its focused Support/modal scenes, durable service, protocol-1.3 DELETE adapter, and launch recovery.
- Implement installation-key destruction and repeatable account-scoped local/session/cache cleanup. Preserve the exact-request retry and uncertain-outcome rules; suspend ordinary sync/bootstrap during possible deletion.
- Keep explicit new-game consent after accepted deletion; distinguish local-only reset from server deletion. Provide a persistent policy action independent of ad consent availability.

**Acceptance and verification**

- [ ] GAME-012's confirmation, accepted, rejected, uncertain, restart, remaining-token retry, cleanup-retry, and explicit-new-game cases pass for Android.
- [ ] Ordinary saves remain protocol 2.1; accepted/possibly accepted deletion cannot silently restore the old guest or refresh its revoked session.
- [ ] Android key cleanup and responsive rendered Support/modal states are verified; actual cloud completion is required in GPI-023/026.

**Existing work:** GAME-012 remains the feature ticket; BE-607 remains the server contract. This package does not replace their specifications or claim iOS completion. **Plan:** Step 10.

## GPI-010

**Make the Android API-36 build toolchain reproducible**

**Owner:** Android build engineer. **Scope:** Game build tooling/export templates. **Depends on:** GPI-001.

**Work**

- Keep Godot 4.6.2 and matching export templates. Reproduce compile/target SDK 36 with a compatible AGP/Gradle/JDK/plugin set; the reviewed AGP 8.6.1 template needs upgrading for the API-36 baseline.
- Source-control the setup/patch process; changes only inside ignored `android/build` are insufficient. Review all native dependencies and intended arm64/optional x86_64 support.
- Record prerequisites and a clean-machine build command, with minimum SDK 24 retained only if supported by the actual dependency/device matrix.

**Acceptance and verification**

- [ ] A clean checkout can prepare templates and build the release variant using pinned, documented tools.
- [ ] The app itself compiles/targets the required API baseline; the plugin's SDK or emulator version is not used as proof.
- [ ] Secure-store and other included native components build compatibly; artifact-level 16 KB checks remain GPI-024/025.

**Existing work:** Android scope of DEV-CODE-004 in [code tickets](DEV_BACKEND_CODE_TICKETS.md). **Plan:** Step 9; policy must be rechecked in GPI-027.

## GPI-011

**Add a safe internal-release export and fail-closed secure-storage validation**

**Owner:** Game/build engineer. **Scope:** Game configuration, export preset, Android plugin packaging. **Depends on:** GPI-007, GPI-009, GPI-010.

**Work**

- Add a reproducible Android internal-development release/AAB profile selecting the HTTPS development backend, sync, release secure bridge, approved capability flags, policy/support URLs, package, and consistent build metadata.
- Build/include the release secure-store AAR and make release validation reject a missing bridge. Reject empty/non-HTTPS/local URLs, mixed environments, stale provenance, wrong package/build, and packaged `local/backend_debug.cfg`.
- Explicitly include Internet permission and prohibit cleartext in the merged release manifest. Exclude tests/local overrides/unneeded previews without breaking dynamic resource loading.

**Acceptance and verification**

- [ ] Export validation has focused negative cases for the listed unsafe/missing settings and succeeds for a valid release profile.
- [ ] A valid test export uses the release bridge, Internet permission, HTTPS-only settings, and no debug overrides.
- [ ] The final origin/publication is injected and checked after GPI-021; GPI-024 records the actual packaged values and artifact identity.

**Existing work:** DEV-CODE-004 Android slice; GAME-003 is a debug export, not completion evidence for this ticket. **Plan:** Step 8.

**Progress:** the "Android (Release)" preset, `configs/backend/environments.json`, and
`scripts/tools/check_release_export.gd` exist (see `docs/CONFIGS.md`). The preset targets
production, not development. The check rejects non-HTTPS, local, and development origins, mixed
environment tags, a wrong package, mismatched versions, an unexcluded `local/`, a missing
release bridge or Internet permission, a placeholder support email, unguarded mock purchases,
and a missing or non-production manifest. Still open: the production manifest and support
email, a merged-manifest cleartext check and a packaged build manifest, which need a real
export, and the signed test export itself.

## GPI-012

**Package managed migration and content-publication execution**

**Owner:** Backend engineer. **Scope:** Backend container, job command, database execution roles, Terraform/runbook. **Depends on:** GPI-001.

**Work**

- Execute DEV-CODE-002 with a managed Cloud Run Job/container target containing immutable migrations, required scripts/contracts, and frozen configuration/catalog inputs.
- Remove runtime dependence on a developer workstation or sibling game checkout. Consume a versioned publication artifact and confirmed app URL instead of local placeholder URLs.
- Separate migration/publication execution from the API identity and database role. Serialize migration execution, preserve checksums, make retries safe, and record non-secret migration/publication results.

**Acceptance and verification**

- [ ] The packaged target initializes a clean PostgreSQL database and publishes a validated fixture artifact without sibling checkout access.
- [ ] Repeat execution does not duplicate/overwrite immutable publications or bypass migration checksums.
- [ ] Least-privilege role/secret contracts, job commands, failure handling, and private-network requirements are documented and tested.

**Existing work:** DEV-CODE-002; BE-004/005. Cloud execution is GPI-020. **Plan:** Step 4.

## GPI-013

**Repair first-start provisioning and integration readiness**

**Owner:** Backend and infrastructure engineer. **Scope:** Backend readiness, Terraform sequencing, runbooks. **Depends on:** GPI-012.

**Work**

- Replace the contradictory initial API-without-secrets sequence with explicit foundation, secrets, migration/publication, then ready API stages or a documented equivalent.
- Add readiness or a mandatory deployment preflight for schema version, active configuration/catalog, supported client build policy, and v2 recovery/ingestion flags.
- Keep database/readiness failures meaningful. Disabled Games, Billing, and ad providers must not prevent guest-only readiness.

**Acceptance and verification**

- [ ] A staged fresh-environment walkthrough has no circular secret/job/API readiness dependency.
- [ ] Checks reject missing schema/publication/build support/required flags and accept a complete guest-only configuration.
- [ ] Terraform/runbooks and deployment gates reflect the same sequence; normal readiness is not weakened for bootstrap.

**Existing work:** DEV-CODE-003 and OWNER-002/003. **Plan:** Step 4.

## GPI-014

**Enforce API and worker database connection budgets**

**Owner:** Backend engineer. **Scope:** Backend PostgreSQL pool owners and infrastructure limits. **Depends on:** GPI-001.

**Work**

- Make API pools consume validated `DATABASE_POOL_MAX`; audit all worker stores and bound/reuse their pools instead of assuming one pool per job.
- Calculate maximum connections from API instance ceilings, job task counts/overlap/retries, migration execution, and operational reserve against the selected Cloud SQL limit.
- Align configuration validation, Terraform settings, and runtime behavior. Include pool disposal on one-shot worker exit.

**Acceptance and verification**

- [ ] Focused checks show the configured maximum reaches each actual pool and invalid values fail startup/config validation.
- [ ] Documented arithmetic fits the development database limit under the maximum configured concurrency.
- [ ] Worker execution and repeated invocation do not leak connections; observed cloud behavior is checked in GPI-022.

**Existing work:** Deployment gap identified by the audit; BE-009/613 ownership. **Plan:** Step 4.

## GPI-015

**Package and schedule the worker with explicit secret loading**

**Owner:** Backend and infrastructure engineer. **Scope:** Backend worker, Cloud Run Job/Scheduler definitions. **Depends on:** GPI-012, GPI-014.

**Work**

- Package the existing one-shot application-context worker and define its runtime document/secret loader so mounted secrets initialize database access correctly.
- Add private database connectivity, a distinct identity/role, Scheduler invocation permissions, bounded retry/task settings, and overlap protection. No HTTP worker service is required for the existing entry point.
- Operate configuration activation, expiry, retention/deletion/export, and required checkpoint/outbox processing. Set privacy processing at least hourly under current commitments; choose/document projection latency independently.

**Acceptance and verification**

- [ ] Packaged worker processing is tested with purpose-scoped secrets and failures produce a failing execution/visible diagnostics.
- [ ] Infrastructure defines an authenticated schedule and finite retry/overlap behavior within GPI-014's budget.
- [ ] Enabled tasks, cadence, retries, alerts, and any deliberate projection postponement are documented; scheduled cloud evidence is GPI-021/023.

**Existing work:** BE-008/506/606/607/608 in [backend tickets](../../sorting-puzzle-backend/docs/IMPLEMENTATION_TICKETS.md). **Plan:** Step 4.

## GPI-016

**Add deployment automation and remote guest/save smoke checks**

**Owner:** Backend/release engineer. **Scope:** Backend CI, deployment scripts, remote smoke tooling. **Depends on:** GPI-004, GPI-012, GPI-013, GPI-014, GPI-015.

**Work**

- Extend deployment tooling to build immutable API/job artifacts, execute guarded migration/publication, deploy compatible API/worker revisions, and check integration readiness.
- Automate HTTPS health, guest challenge/P-256 bootstrap, resume/refresh, v2 checkpoint read, signed journal sync, duplicate retry, and persistence verification for an isolated test account.
- Gate rollout on schema/content/build/environment compatibility and redact credentials/proofs/player payloads. Document forward schema repair, compatible API rollback, and prior configuration-pointer activation.

**Acceptance and verification**

- [ ] The sequence and failure gates are reproducible; unavailable platform providers do not affect guest smoke.
- [ ] Smoke tooling validates exact retry and convergence and has an intentional cleanup policy for its test account.
- [ ] Artifacts/digests and safe results can be recorded by CI; a successful remote run is still required in GPI-021.

**Existing work:** DEV-CODE-003/012 Android/backend scope; existing deployment workflow. **Plan:** Step 4.

## GPI-017

**Provision state, control plane, and the development foundation**

**Owner:** Infrastructure/billing owner. **Scope:** GCP and Terraform. **Depends on:** GPI-001, GPI-013, GPI-014, GPI-015.

**Work**

- Create missing project identities/billing links; use the pinned Terraform toolchain and reviewed real non-secret variables. Apply protected remote state, then control-plane Artifact Registry/WIF/budgets, then the staged development foundation.
- Provision private PostgreSQL 17, VPC/private service networking, database, runtime/job identities, secret containers, Scheduler prerequisites, monitoring, finite scaling, and backups.
- Configure development GitHub Environment variables and federation restricted to the intended numeric repository/owner IDs, workflow, main branch, and environment. Keep production runtime unapplied.

**Acceptance and verification**

- [ ] Applied inventory and remote Terraform state agree; private database/job paths and required APIs exist.
- [ ] GitHub can authenticate with WIF and push/deploy to the intended environment without a service-account key.
- [ ] Budgets/alerts/backups have owners and the resource sequence does not attempt a ready API before GPI-018/020.

**Existing work:** OWNER-002; BE-009/011; [Terraform runbook](../../sorting-puzzle-backend/infra/terraform/README.md). **Plan:** Step 5.

## GPI-018

**Create purpose-scoped database roles and pin development secrets**

**Owner:** Secret custodian and database owner. **Scope:** Private Cloud SQL/Secret Manager/runtime configuration. **Depends on:** GPI-017.

**Work**

- Create distinct API, worker, and migration/publication database roles with the required grants. Verify encrypted/private access through the managed runtime path.
- Generate the prescribed development signing/encryption keyrings and purpose-specific runtime documents. Materialize secret payloads out of band and pin numeric versions in deployment configuration.
- Audit access and document rotation/recovery ownership; do not put secret payloads in Terraform state, build arguments, app resources, Git, or CI output.

**Acceptance and verification**

- [ ] Each workload reads only its intended secret versions and performs its intended database operations; prohibited cross-role access is checked.
- [ ] Private connectivity works without exposing the database publicly.
- [ ] Non-secret role/resource/version references and restricted custody/rotation records are available to the release owner.

**Existing work:** OWNER-003; BE-010. **Plan:** Step 6.

## GPI-019

**Freeze release sources and regenerate candidate/provenance artifacts**

**Owner:** Game and backend release engineer. **Scope:** Separate commits in both repositories and immutable publication inputs. **Depends on:** GPI-002, GPI-004, GPI-006, GPI-009, GPI-011, GPI-016.

**Work**

- Select clean committed game/backend sources after pinned-source changes. Generate a new launch candidate and matching development manifests in both repositories, resolving the stale `scripts/level.gd` digest.
- Include the confirmed content slice, rules/economy/catalog, supported client build, and real package/app URL. Preserve immutable existing publications.
- Produce the frozen artifact consumed by GPI-012/020 and record source commits, configuration/catalog identities, protocol, and content digests. Rerun required backend checks after final backend artifact changes.

**Acceptance and verification**

- [ ] Materializer check, `pnpm check:launch-configuration`, `pnpm check:development-client-manifest`, and the isolated Godot `check_content_provenance.gd` all pass.
- [ ] Repositories and packaged publication inputs agree; source/artifact generation is reproducible.
- [ ] All required baseline checks remain green after generation; any later pinned-source change reopens this ticket.

**Existing work:** DEV-CODE-001, GAME-002, BE-201. Database activation is GPI-020. **Plan:** Step 3.

## GPI-020

**Run managed migrations and activate development configuration**

**Owner:** Backend release owner. **Scope:** Development managed jobs/database. **Depends on:** GPI-012, GPI-018, GPI-019.

**Work**

- Build/push the chosen managed artifact and execute serialized migrations with the pinned role/secret. Verify the committed migration set, including deletion/export prerequisites and the explicit disposition of rewarded-ad schema changes.
- Publish/activate the new immutable configuration/catalog and supported build policy from the frozen artifact.
- Enable v2 recovery before ingestion, preserve supported legacy compatibility, and record safe job results, checksums, digests, and active pointers.

**Acceptance and verification**

- [ ] Managed execution succeeds without a developer workstation; migration checksums and expected schema are verified.
- [ ] Active content/catalog/build policy matches GPI-019 and the intended guest-only capability profile.
- [ ] Recovery/ingestion flag ordering and repeat execution are checked; a database ping alone is not the acceptance test.

**Existing work:** OWNER-003; BE-005/201/307. **Plan:** Step 6.

## GPI-021

**Deploy the HTTPS API and scheduled worker, then pass remote smoke**

**Owner:** Backend release owner. **Scope:** Development Cloud Run/API/jobs. **Depends on:** GPI-016, GPI-020.

**Work**

- Deploy pinned API/worker digests with usable secrets and private database access. Expose the API's managed HTTPS origin for mobile application-authenticated routes; configure platform invocation accordingly.
- Run GPI-016's guest/save smoke off the developer network and inspect integration readiness, content/environment/build identity, exact retries, and persistence.
- Execute the worker manually and verify scheduled executions, task coverage, retry/failure reporting, and bounded concurrency. Keep administration disabled unless its required IAP boundary is configured.

**Acceptance and verification**

- [ ] Guest bootstrap/resume/refresh and protocol-2.1 save operations succeed remotely; identical retries cannot duplicate state changes.
- [ ] The scheduled worker actually executes with its intended identity/secrets; failures reach the designated operator.
- [ ] The HTTPS origin, resource names, image digests, active publication, and sanitized smoke evidence are recorded for app packaging.

**Existing work:** OWNER-003; DEV-CODE-003/012. **Plan:** Step 7.

## GPI-022

**Qualify public API limits, alerts, backup restore, and rollback**

**Owner:** Backend/infrastructure operator. **Scope:** Development operational qualification. **Depends on:** GPI-021.

**Work**

- Apply basic guest-registration/request abuse controls, finite instance/job limits, useful error/sync/job/connection alerts, and budget routing. Internal app distribution does not restrict the public API to testers.
- Observe actual API/worker pool usage against GPI-014's budget and verify operator notification with controlled failures.
- Restore a development backup into an isolated target and verify usable recovered data. Establish a healthy baseline, then rehearse a compatible API revision rollback and prior configuration-pointer activation without destructive schema downgrade.

**Acceptance and verification**

- [ ] Limits and alert delivery work under controlled tests; logs expose neither proofs/tokens nor player data.
- [ ] Restore and rollback records identify tested artifacts, compatibility limits, commands, results, and operating owners.
- [ ] Operators can recover the development test service using the runbook; wider production SLO/DR qualification remains deferred.

**Existing work:** BE-011/610/612/613 operational scope. **Plan:** Step 7.

## GPI-023

**Verify remote account deletion, export, retention, and support handling**

**Owner:** Privacy/support owner and backend engineer. **Scope:** Deployed APIs/worker and support procedures. **Depends on:** GPI-008, GPI-009, GPI-021.

**Work**

- Use isolated guest accounts to verify deletion acceptance immediately revokes access and public visibility, and scheduled processing reaches anonymized completion within the documented commitment.
- Verify export request authentication/recent-auth rules, device/account binding, scheduled generation, access, and expiry through the supported authenticated operating path.
- Exercise a verified external request, unconfirmed deletion escalation, retained-record explanation, and retention processing. User-facing export UI can remain later work if the documented support path is operational.

**Acceptance and verification**

- [ ] Deletion/export records reach expected worker states and deadline/expiry failure handling is observed, not merely inferred from API acceptance.
- [ ] Another account/device or unverified requester cannot retrieve/delete the test player's data.
- [ ] The privacy owner can resolve uncertain requests without asking for private keys or restoring a possibly deleted account; policy statements match actual behavior.

**Existing work:** GAME-012; BE-606/607/608/614. Installed client lifecycle checks remain GPI-026. **Plan:** Steps 7 and 10.

## GPI-024

**Sign and validate the internal-release AAB**

**Owner:** Android build engineer and upload-key custodian. **Scope:** Protected signing and release artifact. **Depends on:** GPI-002, GPI-011, GPI-019, GPI-021.

**Work**

- Create/securely custody the upload key outside Git, configure protected export signing, and prepare Play App Signing. Record the distinction between upload and Play delivery certificates; confirm Console fingerprints when available.
- Export the AAB with the actual development HTTPS origin, consistent app/build/versionCode, and exact GPI-019 content. Record checksums and the build evidence manifest.
- Validate package, target/minimum SDK, signing, Internet/cleartext permissions, native architectures, secure-store release AAR, absent/inactive ad dependencies, excluded debug resources, and bundletool splits. Inspect all native ELF/packaging 16 KB alignment and measure release download size.

**Acceptance and verification**

- [ ] The signed AAB and generated release splits validate/install; metadata and embedded content/environment match backend policy.
- [ ] All shipped native libraries satisfy the compatibility checks; no debug key, missing bridge, local host, mock money flow, or active ad integration is present.
- [ ] Source commits, tool versions, checksum, versionCode, certificate references, and safe artifact-inspection results are recorded; later artifact changes require requalification.

**Existing work:** OWNER-004; Android DEV-CODE-004. **Plan:** Steps 8-9.

## GPI-025

**Qualify gameplay, responsive UI, and native performance**

**Owner:** Android QA and game engineer. **Scope:** Candidate release splits on intended devices/environments. **Depends on:** GPI-024.

**Work**

- Exercise first launch, level completion/failure/leave, lives, coin/ability spending, chest rewards, campaign boundary, and unavailable money/ranking/ad states.
- Render and touch-test main menu/gameplay/modals/Shop/profile/Support at 540x960, 720x1280, 1080x1920, 1080x2400, and an exact squarer portrait size. Inspect safe areas, drag/drop, Back, keyboard, and touch targets.
- Investigate the reviewed tall-screen footer spacing on Android. Fix capture setup labels/sizing; the prior 900x1600 output is not evidence for requested 1200x1600. Verify startup/frame pacing/memory/crash/ANR behavior and a 16 KB runtime.

**Acceptance and verification**

- [ ] A device/report matrix identifies OS, viewport, architecture, artifact checksum, scenarios, and rendered results.
- [ ] No blocking layout/gameplay/native compatibility failure remains; performance observations use explicit test conditions.
- [ ] Any fixes update owning docs and trigger affected provenance/build/QA gates before this ticket closes.

**Existing work:** Android DEV-CODE-012 and OWNER-010 slices; project responsive/visual verification rules. **Plan:** Step 11.

## GPI-026

**Qualify guest sync, recovery, deletion, and app updates on Android**

**Owner:** Android QA and backend engineer. **Scope:** Installed release variant against development HTTPS. **Depends on:** GPI-022, GPI-023, GPI-024.

**Work**

- Test fresh online and fresh offline installation, reconnect, airplane mode, Wi-Fi/mobile switching, app background/force-stop/process death, expired access/refresh, and stable native key/session recovery.
- Exercise duplicate/lost-response sync, API downtime/5xx, local-generation corruption/checkpoint recovery, and server convergence after ordinary rewards/spends. Resolve or conclusively replace the old Android POST-with-body stall evidence.
- Test accepted/interrupted/unconfirmed deletion, restart and key cleanup, explicit new game, and no old-progress resurrection. Test N-to-N+1 updates with a consistent signing identity and old/new backend compatibility; never use uninstall as the save-preservation test.

**Acceptance and verification**

- [ ] Device evidence proves exactly-once effects/eventual convergence without losing local progress across offline/retry/restart cases.
- [ ] A higher-version candidate retains saves/keys and syncs; package/protocol/build policy stays compatible with supported testers.
- [ ] Deletion/uncertainty follows GAME-012, and guest reinstall/cross-device recovery is not promised. Play-delivered signing/install proof follows in GPI-027.

**Existing work:** GAME-001/004/005/006/010/012; DEV-CODE-012/OWNER-010 Android slices. **Plan:** Step 11.

## GPI-027

**Publish and verify the Google Play internal release**

**Owner:** Play/release owner and Android QA. **Scope:** Play Console internal track and Play-delivered installation. **Depends on:** GPI-025, GPI-026.

**Work**

- Recheck official Play target/API/native/signing/testing requirements at upload time. Complete the Console-requested app-content/listing inputs with truthful audience/content/no-ads/no-purchases answers; distinguish internal allowances from later distribution obligations.
- Configure Play App Signing, select the restricted tester list, upload the exact qualified AAB, resolve validation errors, add release notes/known guest-recovery limits and feedback instructions, then publish to internal testing.
- Record the opt-in link in restricted release records. Using an eligible tester account, install through Play on a dedicated device/profile, verify delivery signing and remote gameplay/sync/privacy access, and check server artifact/content/build compatibility.

**Acceptance and verification**

- [ ] The internal release is available to intended testers; a Play installation runs and syncs against the correct development environment.
- [ ] The uploaded artifact matches the qualified checksum/versionCode; Console processing and per-device size/signing findings are recorded.
- [ ] No valued debug installation is erased as routine troubleshooting; tester communication/sharing is performed only within separately authorized release actions.

**Existing work:** OWNER-004 and OWNER-010 Android release scope. **Plan:** Step 12. The later qualifying-personal-account closed-test production-access gate is not substituted with internal testing.

## GPI-028

**Operate tester feedback and release updates**

**Owner:** Release/support owner. **Scope:** Live internal test and continuing maintenance. **Depends on:** GPI-027.

**Work**

- Maintain the feedback/triage record, daily initial review cadence or another explicit owner-approved cadence, and visibility into crashes/ANRs when available, sync failures, worker/privacy backlog, and cost/connection alerts.
- Convert reproduced failures into linked fix tickets; release fixes using new versionCodes, renewed content identities when needed, and compatible backend changes for older tester builds.
- Record each release's commits, digests, content/catalog IDs, AAB checksum, policy revision, device evidence, known limits, and recovery owner. Feed wider-release requirements into the deferred backlog.

**Acceptance and verification**

- [ ] A named owner and usable feedback/incident procedure exist, with the first post-release review recorded.
- [ ] The update/rollback checklist is ready; a subsequent update repeats affected GPI-019 through GPI-027 gates rather than reusing stale evidence.
- [ ] Ticket can close once the operating process is handed over and evidenced; ongoing reviews remain an operational responsibility.

**Existing work:** Release operations under OWNER-010 and backend observability/support tickets. **Plan:** Step 13. This is post-publication work, not an extra upload prerequisite.

## Deferred ticket index

These are **later milestones**, not conditions for the guest gameplay/save-sync release. Their canonical feature tickets remain authoritative. Split each into smaller engineering/setup/QA subtickets when that milestone is scheduled.

| Ticket | Later milestone | Hard prerequisite |
| --- | --- | --- |
| [GPI-101](#gpi-101) | Google Play Games identity and account recovery | 027 |
| [GPI-102](#gpi-102) | Public rankings/profiles with moderation | 101 |
| [GPI-103](#gpi-103) | Real Google Play Billing and reconciliation | 101 |
| [GPI-104](#gpi-104) | Rewarded ads and consent qualification | 027 |
| [GPI-105](#gpi-105) | Closed/open/production distribution readiness | 028 + separately approved feature scope |

## GPI-101

**Integrate Google Play Games identity and account recovery**

**Owner:** Game/backend engineers and Play owner. **Scope:** Android/native identity, account UX, Console/OAuth. **Depends on:** GPI-027. **Status:** Deferred.

**Work:** Execute DEV-CODE-006/008 and OWNER-005: configure Games services and delivery-certificate identities; exchange a fresh server authorization code with the backend; implement promotion, switching, merge decisions, account isolation, and recovery UX while retaining guest fallback.

**Acceptance and verification**

- [ ] Silent/manual identity flows, cancel/unavailable/expired-code behavior, merge/account choices, restart, and genuine linked recovery pass on Play-installed builds.
- [ ] Native/OAuth secrets remain server-side; app-signing identities match Console; gameplay remains available as guest.

**Canonical work:** [Code tickets](DEV_BACKEND_CODE_TICKETS.md), [owner tickets](DEV_BACKEND_OWNER_TICKETS.md), BE-104/106/107.

## GPI-102

**Enable public rankings/profiles with moderation and reporting**

**Owner:** Game/backend engineers and moderation/support owner. **Scope:** Ranking/profile UX and operated projection/moderation. **Depends on:** GPI-101. **Status:** Deferred.

**Work:** Replace unavailable/mock ranking with verified-session reads; qualify checkpoint projection, periods/country/profile state and cache behavior; complete applicable moderation, reporting/quarantine, support and abuse controls before exposing public content.

**Acceptance and verification**

- [ ] Real eligible players appear with correct score/period/country; deleted/quarantined users disappear and caches refresh correctly.
- [ ] Report/moderation workflows are usable and operated; no mock users are presented as public players.

**Canonical work:** GAME-009, BE-504/505/506 and applicable BE-610 in the existing [game](IMPLEMENTATION_TICKETS.md) and [backend](../../sorting-puzzle-backend/docs/IMPLEMENTATION_TICKETS.md) backlogs.

## GPI-103

**Enable real Google Play Billing and reconciliation**

**Owner:** Game/backend engineers, Play merchant/API owner, support operator. **Scope:** Native billing, server-owned grants, Console products/notifications. **Depends on:** GPI-101. **Status:** Deferred.

**Work:** Execute DEV-CODE-009/011 and OWNER-006 with a currently accepted Billing library, real product prices, account-bound intent/verification/status flows, minimal Publisher permissions, RTDN/reconciliation, and refund handling. Configure license testers separately from track membership.

**Acceptance and verification**

- [ ] Pending/cancel/duplicate/lost-response/restart/refund/account-binding scenarios pass; only verified server outcomes grant purchases.
- [ ] Notification/reconciliation and support procedures work; no mock or client catalog grant remains in enabled money flows.

**Canonical work:** [Code tickets](DEV_BACKEND_CODE_TICKETS.md), [owner tickets](DEV_BACKEND_OWNER_TICKETS.md), BE-401 through BE-409 and applicable BE-605.

## GPI-104

**Enable rewarded ads and qualify consent and server rewards**

**Owner:** Game/backend engineers and ads/privacy owner. **Scope:** Android AdMob/UMP, authorization/SSV, policy/evidence. **Depends on:** GPI-027. **Status:** Deferred.

**Work:** Configure environment-specific units/test devices and consent; qualify each of the four rewarded placements against server authorization, callback verification/key rotation, lost-response/status recovery, and lifecycle rules. Produce genuine Android release evidence; do not mark unrelated iOS approvals complete to bypass a gate.

**Acceptance and verification**

- [ ] All enabled placements/consent outcomes are tested on the actual Android release with server-correlated exact rewards and safe failure/retry behavior.
- [ ] Policy/store data and ad declarations match the enabled SDKs; interstitials stay disabled unless separately approved and qualified.

**Canonical work:** ADS-002 through ADS-008 in [ad infrastructure ownership](PROJECT_MAP.md), BE-ADS-001 and associated canonical rewarded-ad documents.

## GPI-105

**Prepare closed/open/production distribution and an isolated production backend**

**Owner:** Publisher, release, infrastructure, privacy, security, and QA owners. **Scope:** Wider-release milestone. **Depends on:** GPI-028 and the separately approved feature scope. **Status:** Deferred.

**Work:** Decide which optional milestones GPI-101 through GPI-104 ship. Complete applicable listing/localization/audience/Data safety and public rights surfaces; provision isolated production; qualify SLOs, capacity, restore/DR, abuse/security, restricted support/admin operations, and required closed-test production access for the account type.

**Acceptance and verification**

- [ ] A wider-release checklist records each applicable BE-605/609-616 requirement as completed or with a justified release-specific disposition.
- [ ] Production API/jobs/secrets/content and the promoted app are compatible and qualified; current Console/policy gates are satisfied for the chosen track.
- [ ] Optional integrations have their own completion evidence; iOS has its own release plan if added to scope.

**Canonical work:** Remaining [backend tickets](../../sorting-puzzle-backend/docs/IMPLEMENTATION_TICKETS.md), [owner tickets](DEV_BACKEND_OWNER_TICKETS.md), and detailed plan section 7.

## Plan coverage and completion records

| Detailed-plan step | Execution tickets |
| --- | --- |
| 0: Release decisions | GPI-001 |
| 1: Play account | GPI-002 |
| 2: Regression baseline | GPI-003, 004, 005 |
| 3: Campaign/provenance/publication | GPI-006, 019, 020 |
| 4: Backend deployment code | GPI-012, 013, 014, 015, 016 |
| 5: Cloud foundation | GPI-017 |
| 6: Secrets, migrations, activation | GPI-018, 020 |
| 7: API/worker qualification | GPI-021, 022, 023 |
| 8: Android release profile | GPI-007, 011 |
| 9: Toolchain/signing/bundle | GPI-010, 024 |
| 10: Privacy/support/declarations | GPI-008, 009, 023, 027 |
| 11: Real Android qualification | GPI-025, 026 |
| 12: Internal publication | GPI-027 |
| 13: Operating the test | GPI-028 |
| Later phases | GPI-101 through GPI-105 |

When executing a ticket, append a completion record under it with: **status/date, assigned owner, owning-repository commit(s), related existing ticket status, artifact/resource/publication identities, checks and device results, restricted evidence link, and remaining limitations**. Preserve the original dated audit; update the ticket record and current operating docs as work progresses.
