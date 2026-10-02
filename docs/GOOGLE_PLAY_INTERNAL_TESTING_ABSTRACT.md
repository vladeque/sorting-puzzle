# Google Play internal testing: release abstract

Reviewed: **2026-10-02**. Owner-confirmed scope: **gameplay and deployed save sync first; Google Play sign-in, purchases, and ads later**.

Full audit, owners, dependencies, and acceptance criteria: [Detailed deployment and publication plan](GOOGLE_PLAY_INTERNAL_TESTING_PLAN.md).

Execution backlog: [28 first-release tickets and 5 deferred milestones](GOOGLE_PLAY_INTERNAL_TESTING_TICKETS.md), with owners, dependencies, and acceptance/verification criteria.

## Current position

The game has substantial gameplay, menus, rewards, and local-save infrastructure. The backend implements most core services, including guest identity, sessions, save sync, economy/progression records, platform verification, and privacy APIs. Terraform and a container deployment pipeline exist.

**The intended connected internal release is not ready.** One billed Google Cloud project exists, but no Terraform has been applied and no cloud service is running. Play account/app setup and public policy/support surfaces still need preparation.

## Missing work

1. **Repair the release baseline.** Backend type checking, build, and 1,449 unit tests passed, but lint and six repeatable database tests fail. Client tooling reports nine layout assertion failures.
2. **Reconcile and publish content.** Eight runtime levels differ from their templates; the launch candidate and provenance manifests are stale against scripts/level.gd.
3. **Deploy the backend.** Provision development resources, database roles and secrets; add managed migration/publication and scheduled worker execution; repair first-start readiness and connection-limit enforcement.
4. **Build a real release.** Replace the local debug APK path with a signed API-36 AAB configured for development HTTPS, save sync, Internet permission, and release secure storage.
5. **Finish tester data/support paths.** Publish an accurate policy and real contact, complete planned client deletion, and verify worker processing.
6. **Qualify and publish.** Test the installed release on physical devices, then configure Play signing, internal testers, release notes, rollout, and feedback.

Keep money purchases, ads, and public rankings unavailable initially. Unknown store-provider settings currently fall back to mock purchases, so a genuine disabled path is needed. Guest sync does not establish reinstall or cross-device recovery.

## Execution order

**Account/release decisions → regression and content repairs → cloud foundation → secrets/migration/publication → API and worker → Android AAB → privacy/device qualification → Play internal rollout.**

Account verification and legal preparation can overlap engineering. Use the development runtime. The accepted cloud design separates control-plane, development, and production projects; assign the existing project a role and create missing identities. Production services can wait.

Google permits internal tests with up to 100 testers and incomplete app setup. Internal-only Data safety is exempt; the 12-testers/14-days closed-test rule concerns later production access for qualifying personal accounts. These allowances do not establish connected-game readiness. [Testing](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en), [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en), [Production access](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).

New mobile submissions currently require API 36. Validate 16 KB native compatibility now; current guidance names February 1, 2027 for blocking incompatible updates. [Target API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en), [16 KB guidance](https://developer.android.com/guide/practices/page-sizes).

Success means a tester installs through Play, plays offline, reconnects and syncs exactly once, restarts and updates without progress loss, and reaches working privacy/support/deletion controls. Record source commits, artifact/content identities, device results, and recovery procedures.

This review produced planning documents; no cloud or store deployment was performed.
