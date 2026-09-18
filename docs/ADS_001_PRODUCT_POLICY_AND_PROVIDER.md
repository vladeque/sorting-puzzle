# ADS-001 — Product Policy and Provider Decision

## Status

**Owner-approved on 2026-09-18 — provider acceptance and compliance gates remain pending.**

The owner approved the policy baseline in this record on 2026-09-18. This fixes the product
defaults; it does not enable production ads or complete ADS-001. Rewarded placements still depend
on their client and backend tickets, interstitials remain disabled for the initial public release,
and the provider remains conditional until the native platform and compliance gates pass.

## Existing product constraints

- The game targets Android and iOS.
- The current product requirement is a general audience with a 3+ content rating, not a product
  specifically directed to children.
- The project currently has no advertising or analytics integration. Adding one requires a data
  inventory and purpose, an applicable consent/lawful-basis decision, age and store-disclosure
  review, vendor retention/deletion review, and approval of any backend protocol or storage change.
- Release builds currently have no completed iOS export setup and no validated Android/iOS ads
  runtime, so SDK compatibility is not yet proven by a native-device build.

These constraints come from the current client-facing backend requirements and the canonical
backend privacy/retention policy. A future audience change reopens this decision before ads may
continue to ship.

## Approved product policy

### Audience, geography, and privacy

| Decision | Approved launch baseline |
| --- | --- |
| Audience treatment | Retain the current general-audience, 3+ classification. Do not claim that the app is child-directed without a separate product, legal, store, and SDK configuration review. |
| Geography | Make rewarded placements available in countries where the game, AdMob, and the applicable app store support them, subject to the consent and policy gates below. A country can be disabled remotely without a client update. |
| Ad personalization | Request non-personalized/contextual ads at launch. Do not use interest-based personalization for the first release. |
| Consent | Integrate Google User Messaging Platform (UMP), request/update consent information at each app launch as required by the SDK, and provide a privacy-options entry point whenever UMP says one is required. Fail closed when a required decision cannot be obtained. |
| iOS tracking | Do not request App Tracking Transparency (ATT) permission solely for this launch configuration. Keep Identifier for Advertisers access and cross-app tracking disabled. Reconsider ATT only through a separately approved personalized-ad or attribution proposal. |
| Data minimization | Do not send names, email addresses, raw account IDs, gameplay payloads, or other personally identifiable information to the provider. Server-side verification custom data must be an opaque, short-lived reward-intent nonce. |
| Under-age handling | Do not infer or collect a player's birth date for ads. If policy or store configuration later requires an age gate or child treatment, keep ads off until that design is approved and implemented. |

The owner remains responsible for confirming the selected country distribution, store age-rating
answers, privacy policy, Play Data safety answers, and App Store privacy labels against the exact
SDK and app configuration submitted to each store.

### Rewarded placement policy

All four placements are optional and may ship at launch only after their individual client,
backend, compliance, and release gates pass. Every completed ad authorizes only the reward stated
on its button. A dismissed, failed, unverified, duplicate, or expired transaction grants nothing.

| Placement | Exact reward | Launch cap and eligibility |
| --- | --- | --- |
| Time extension | Add **60 seconds** to the current attempt. | At most one ad-funded extension per attempt. Only while the time-up modal owns a still-valid, unsettled attempt. The existing coin path remains independent. |
| Life | Add **1 life**, without exceeding the configured life maximum. | One life per verified transaction; unavailable while already at the cap. No player-visible daily cap at launch. Backend eligibility and bounded velocity controls still apply. |
| Immediate ability | Apply **one use of the selected ability immediately**; do not add it to inventory. | At most one ad-funded immediate ability use per attempt. Bind authorization to that attempt and ability. The coin path remains independent. |
| Locked shelf | Unlock **only the selected locked shelf** for the current attempt. | Each configured locked shelf may be ad-unlocked once per attempt. There is no attempt-wide shelf-unlock cap; already unlocked shelves are ineligible. Do not change cleared triples, another shelf's countdown, combo, or stars. |

Placement limits are authoritative server policy, not client-only counters. Operational abuse limits
may reject implausible request velocity, but must not silently change the player-facing reward.

### Interstitial policy after launch

Interstitials are **disabled in the initial public release**. Their SDK format switch, remote
policy switch, and rollout percentage must all prevent requests and impressions. A later activation
is a separate release decision and starts each eligible install from its then-current completion
baseline, so old completions never trigger an immediate ad.

The approved candidate settings for that later, staged activation are:

| Setting | Value |
| --- | --- |
| Eligible event | A newly committed production campaign level completion |
| First-ad threshold | No earlier than the fifth eligible completion after activation baseline |
| Recurrence | After every 3 additional eligible completions |
| Minimum time between impressions | 10 minutes |
| Maximum impressions | 2 per foreground app session |
| Suppression after any rewarded impression | 5 minutes |
| Initial rollout | 5% of otherwise eligible players, with a stable assignment and a holdout cohort |
| Presentation point | Only while leaving the already-shown completion result; never during play or at next-level startup |
| Counter reset | Only after a confirmed impression callback |

Activation should require a reviewed experiment plan and live health thresholds. No-fill, lack of
consent, cooldown, cap, suppression, backgrounding, load failure, or presentation failure always
continues navigation without an ad.

### Future ad-free entitlement

An ad-free purchase is not part of the first ads release. If introduced later, the recommended
contract is:

- disable automatic interstitials for the entitlement holder;
- leave voluntary rewarded offers available, because they exchange attention for an explicit
  benefit;
- disclose this distinction before purchase; and
- treat the entitlement as authoritative cross-device purchase state rather than a local flag.

This behavior must be approved again when an ad-free product is actually scoped.

## Provider decision

### Recommendation

The owner conditionally approved **Poing Studios Godot AdMob Plugin v5.1.0** as the first provider
bridge, using Google Mobile Ads/AdMob on Android and iOS. The selection is conditional because
repository inspection and artifact verification do not replace Android and iOS export/device
tests.

Reasons for the recommendation:

- MIT-licensed source and a provider-specific adapter boundary fit the project's replaceable
  `AdProvider` design.
- The v5.1.0 release publishes explicit Godot 4.6.2 Android and iOS template artifacts.
- The plugin surface covers rewarded ads, interstitials, UMP, ATT support when needed, editor mock
  behavior, and server-side verification fields.
- It is a closer version match than the evaluated unified alternative, whose latest inspected
  release did not publish Godot 4.6.2-specific native templates.

Use only AdMob core at first. Do not add mediation adapters or additional advertising networks
until each network receives the same privacy, licensing, retention, disclosure, and native-build
review.

### Pinned inputs

Vendor the exact approved source/runtime artifacts or fetch them in a controlled dependency step.
Record and verify these upstream v5.1.0 release checksums before extraction:

| Artifact | SHA-256 |
| --- | --- |
| `poing-godot-admob-v5.1.0.zip` | `8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f` |
| `android-template-v4.6.2.zip` | `f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee` |
| `ios-template-v4.6.2.zip` | `3ec209252ee75b43df81e651e2ca8b51df0967465c82e12bfdd3b16a57bce6c1` |

The inspected Android plugin declares Google Mobile Ads SDK `1.4.0` and AndroidX ConstraintLayout
`2.2.0`. The inspected iOS package pins Google Mobile Ads `13.9.0`, UMP `3.1.0`, and iOS 15 as its
minimum deployment target. Re-run the dependency, license, vulnerability, and platform review if
any of these versions or artifact hashes change.

### Supply-chain controls

The inspected editor helper can download missing native archives from GitHub using host tools, but
does not verify the release SHA-256 before extraction. Production and CI must therefore:

1. Disable or bypass the automatic native-binary downloader.
2. Acquire the pinned archives in a controlled dependency step.
3. Verify the SHA-256 values above before extraction or packaging.
4. Check in an attribution/license notice and generate Android/iOS dependency manifests for the
   release archive.
5. Keep production AdMob app/ad-unit IDs outside scenes and source code; inject platform- and
   environment-specific IDs during signed builds.
6. Block production IDs and live requests from editor, automated, and internal test runs. Use
   Google's test ad units and registered test devices.

## Provider acceptance gates

The provider remains conditional until both platform spikes pass against the pinned inputs.

### Local Android build evidence — 2026-09-18

The locally testable build portion passed on Windows:

- Godot `4.6.2.stable.official.71f334935` loaded plugin v5.1.0 and exported a core-only,
  Gradle-built Android debug APK with exit code `0`.
- The spike used Google's Android test application ID, targeted Android 35 with minimum Android
  24, included only the plugin's `ads` and `core` AARs, and added no third-party mediation adapter.
- The 89,459,872-byte APK verified under Android Signature Scheme v2. Its SHA-256 was
  `9d052c982cf275719da18ff3b5d3967061826f1bfb8363ef7da1cff0c45f8e08`.
- The merged manifest contains the test AdMob application ID and SDK-contributed permissions for
  `INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID`, `com.google.android.gms.permission.AD_ID`,
  `READ_BASIC_PHONE_STATE`, `WAKE_LOCK`, and `FOREGROUND_SERVICE`. The release disclosure review
  must account for every retained permission and remove any unnecessary permission explicitly.
- The exact downloaded editor, Android, and iOS archives matched the pinned SHA-256 values in this
  record before extraction. Supplying both native packages prevented the plugin's unverified
  headless auto-downloader from running.

The isolated build and logs live under the git-ignored
`tmp/ad_provider_android_export_20260918/` directory. No Android device was attached, so ad
loading, consent UI, callbacks, lifecycle, audio restoration, and on-device network behavior are
still unverified. This evidence passes the compile/artifact-inspection portion only.

### Android

- Export a signed-like release APK/AAB with Godot 4.6.2 and inspect its dependency and permission
  manifests.
- On a physical device, complete UMP/privacy-options, rewarded earn/dismiss/failure, interstitial
  show/dismiss/failure, pause/resume, audio restoration, process restart, and test-device flows.
- Confirm the exact earned-reward and full-screen callback ordering used by the adapter.
- Confirm there are no live ad requests in editor/tests or while the provider switch is off.

### iOS

- On macOS/Xcode, export and archive with Godot 4.6.2 using the pinned iOS package.
- On a physical device, repeat consent, reward, interstitial, lifecycle, audio, restart, and
  test-device flows.
- Inspect required `Info.plist` entries, privacy manifests, linked SDKs, deployment target, and
  App Store validation output.
- Confirm the non-personalized launch path does not access tracking data or display ATT solely for
  ads.

A desktop/headless parse is not an acceptance substitute for either native platform test.

## Decision and acceptance checklist

ADS-001 is complete only when the remaining evidence links are filled in and all gates pass.

- [x] Owner approved the audience/geography/non-personalized launch policy on 2026-09-18.
- [x] Owner approved all four exact reward and cap rules on 2026-09-18.
- [x] Owner approved the disabled-at-release and conservative post-release interstitial policy on
      2026-09-18.
- [ ] License and attribution review accepts the MIT plugin and Google SDK terms.
- [ ] Security review accepts the pinned-artifact and no-auto-download controls.
- [x] Android 4.6.2 core-only Gradle export and APK inspection pass; see local evidence above.
- [ ] Android physical-device behavior spike passes. Evidence: _pending; no device attached_
- [ ] iOS 4.6.2 archive/device spike passes. Evidence: _pending_
- [ ] Store/privacy owner confirms disclosures for the exact release build. Evidence: _pending_
- [ ] AdMob app IDs, test IDs, production ad-unit ownership, and account access are assigned without
      committing secrets. Owner/evidence: _pending_

With owner approval recorded, ADS-002 may begin while the provider remains conditional. Production
activation stays blocked until every applicable native, backend, compliance, and placement gate
passes.

## References

- [Client-facing backend requirements](BACKEND_REQUIREMENTS.md)
- [Canonical backend privacy and retention policy](../../sorting-puzzle-backend/docs/PRIVACY_RETENTION.md)
- [Poing Studios plugin v5.1.0 release](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0)
- [Poing Studios plugin source and MIT license](https://github.com/poingstudios/godot-admob-plugin)
- [Google Mobile Ads SDK for Android](https://developers.google.com/admob/android/quick-start)
- [Google Mobile Ads SDK for iOS](https://developers.google.com/admob/ios/quick-start)
- [Google UMP for Android](https://developers.google.com/admob/android/privacy)
- [Google UMP for iOS](https://developers.google.com/admob/ios/privacy)
- [Google rewarded-ad server-side verification](https://developers.google.com/admob/android/ssv)
- [Google Play ads policy](https://support.google.com/googleplay/android-developer/answer/9857753)
- [Apple user privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
