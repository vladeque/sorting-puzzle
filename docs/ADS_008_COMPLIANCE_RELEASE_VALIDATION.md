# ADS-008 Compliance and Release Validation

Status: **client safeguards implemented; external approvals remain intentionally incomplete**.

## Player-facing privacy and reporting

The main-menu Settings modal retains the product-owned **Support** and **Language** actions and owns
one focused ad privacy action:

- **Privacy Choices** opens the provider's UMP privacy-options form when UMP reports that an entry
  point is required. Otherwise the action is labeled **Privacy Policy** and opens the configured
  HTTPS privacy-policy URL.
- **Support** opens a native offline FAQ. Its **How do I report a bad ad?** article tells the player
  to collect a screenshot, approximate time, placement, advertiser/app name, and reason for review,
  then opens a prefilled message to the configured support email.

The privacy action remains hidden until a valid `https://` URL is configured, but can appear
independently when UMP requires it. Support remains available offline; only its email handoff
depends on an installed device email app.

Project settings:

- `application/config/ad_privacy_policy_url`
- `application/config/support_email`

## Fail-closed release audit

`configs/ad_release_evidence.json` records the approved initial policy shape and six evidence-
backed owner gates: dependency/license review, privacy-policy review, Google Play disclosures, App
Store privacy details, Android physical-device verification, and iOS archive/device verification.
Every committed approval begins incomplete; evidence must name a durable ticket, artifact, or
review result before it can pass.

`scripts/ads/ad_release_readiness.gd` also requires:

- the general-audience 3+ and non-personalized launch baseline, with no ATT prompt solely for ads;
- all four rewarded placements enabled;
- interstitials disabled with zero rollout;
- AdMob and native integration explicitly enabled for the release environment;
- an HTTPS privacy-policy URL and a non-placeholder support email; and
- injected Android/iOS application IDs plus per-placement rewarded and future interstitial unit IDs.

Run the audit with:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 `
    -Script res://scripts/tools/check_ad_release_readiness.gd
```

The committed development configuration is expected to exit non-zero. That is deliberate: empty
production identifiers and incomplete legal/store/device evidence must never be mistaken for a
release approval.

## Verification performed in this repository

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ads/test_ad_release_readiness.gd
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ui/test_ad_compliance_settings.gd
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ui/test_support_screen.gd
& .\scripts\tools\capture_ui.ps1 -Scene scenes/main_menu.tscn -Name ad_compliance_settings `
    -Setup scripts/tools/captures/ad_compliance_settings_setup.gd
& .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/support_screen.tscn -Name support_screen_report `
    -Setup scripts/tools/captures/support_screen_report_setup.gd
```

The responsive capture covers 540x960, 720x1280, 1080x1920, 1080x2400, and the available
tablet-like portrait viewport. The window manager rendered the requested 1200x1600 capture at
900x1600, so that image is useful for visual review but is not exact 1200x1600 evidence.

Repository automation cannot complete store-console declarations, legal approval, physical-device
behavior, or an iOS archive. Those remain explicit blockers in the evidence file. A remotely
served, authenticated/expiring ad-policy transport is also not part of the current backend
protocol; interstitial activation therefore remains prohibited until that separately reviewed
transport and the owner evidence gates are complete.

Current primary guidance:

- [Google Play app content and ads declarations](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en)
- [Google UMP privacy options](https://developers.google.com/admob/android/privacy?authuser=661122158&consent=legacy)
- [Apple user privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Apple privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files?trk=public_post_comment-text)
- [Apple App privacy details](https://developer.apple.com/go/?id=info-1)
