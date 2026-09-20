# ADS-002 Client Ad Infrastructure

Status: **implemented; every rewarded placement enabled behind runtime release gates**.

## Ownership

- `AdService` is the only ad API gameplay/UI code may call. It owns initialization, consent/privacy
  plumbing, preload and presentation, a one-active-request guard, normalized terminal results,
  focus state, audio snapshot/restore, diagnostics, and pacing persistence.
- `AdPolicy` validates the bounded schema and makes pure rewarded/interstitial eligibility
  decisions. Invalid or missing configuration fails closed.
- `AdProvider` defines the disabled base contract. `MockAdProvider` provides deterministic headless
  outcomes. `AdMobProvider` translates Poing v5.1.0/Google callbacks, isolates loaded rewarded ads
  by placement, and never grants gameplay state.
- `AdPacingState` sanitizes the non-economic local counter/timestamps. `PlayerProgress` stores it in
  the local preference partition, excludes it from authoritative snapshots, and creates no backend
  journal operation.
- `configs/ads.json` is the bundled release policy. ADS-003 through ADS-006 enable provider policy
  plus all four rewarded placement gates; every interstitial remains disabled.
  It contains pacing limits but no reward amounts, production IDs, or secrets.

## Release switches

Three independent gates prevent an accidental live request:

1. `configs/ads.json` must enable the provider and the requested format/placement.
2. `application/config/ad_provider` must select `admob` (the committed default is `disabled`).
3. `application/config/ad_native_integration_enabled` and the matching `admob/general/<platform>/enabled`
   setting must be enabled only in a controlled platform build with an injected application ID.

The mock provider additionally requires a debug build and
`application/config/ad_allow_mock_provider=true`. Debug native builds use Google's published test ad
unit IDs. Release unit IDs come only from environment-specific project settings and are committed as
empty strings.

ADS-007 now activates pacing from the then-current baseline after a newly committed campaign
completion and makes its only presentation request at the completion-to-menu transition. Disabled
policy records no completions, so the initial release cannot accumulate a backlog. A failed/no-fill
presentation does not reset the counter; only an impression does. See
[ADS_007_INTERSTITIAL_PACING.md](ADS_007_INTERSTITIAL_PACING.md).

## Reward boundary

A `REWARDED` provider callback is evidence for an authoritative claim, not a reward. The service
returns no coin, life, time, ability, or shelf payload and requires callers to confirm that the
server can accept a claim before presentation. ADS-003 owns time-extension reconciliation and
ADS-004 owns life reconciliation; ADS-005 owns immediate-ability reconciliation; and ADS-006 owns
selected-shelf-unlock reconciliation. The project/native provider switches
remain disabled by default pending device/store/privacy activation checks; interstitial policy
stays disabled for release.

## Native dependency

`addons/admob/` vendors the reviewed core bridge. See its `VENDORING.md` and `LICENSE`. The editor
entry point cannot download dependencies. With native integration disabled, export hooks contribute
no AdMob package or application metadata.

## Verification

Run:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ads/test_ad_infrastructure.gd
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/save/test_player_progress_facade.gd
```

The infrastructure test covers invalid-policy fail-closed behavior, rewarded gates, activation
baseline, first/subsequent thresholds, cooldown, cap, rewarded suppression, rollout, normalized
provider outcomes, the one-active-request guard, audio restoration, non-authoritative reward
results, placement-isolated time/life/ability/shelf-unlock inventory, and persistence without a
backend journal operation.

On 2026-09-19, the project exported its Android debug preset with all committed native switches off;
APK inspection found no Google Mobile Ads/UMP or Poing classes and no AdMob application metadata or
`AD_ID` permission. A separate minimal Android export using this exact vendored bridge and Google's
test application ID succeeded with the native switch on and contained the expected SDK classes,
manifest metadata, UMP, and ad permission. These are packaging checks only. Physical-device consent,
lifecycle, audio, impression, SSV, and iOS archive checks remain release gates in
`ADS_001_PRODUCT_POLICY_AND_PROVIDER.md` and the fail-closed ADS-008 checklist in
[ADS_008_COMPLIANCE_RELEASE_VALIDATION.md](ADS_008_COMPLIANCE_RELEASE_VALIDATION.md).
