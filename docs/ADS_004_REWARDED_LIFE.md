# ADS-004 Rewarded Life

Status: **implemented behind release/provider gates**.

## Player flow

`OutOfLivesMenu` now exposes a dedicated `rewarded_ad_requested` intent beside the independent
coin purchase. The action renders explicit unavailable, loading, verifying, pending-verification,
and retryable-error states. At the life cap, both acquisition actions remain hidden and the
existing `Got it` state is unchanged.

`scripts/ads/rewarded_life_client.gd` owns the authoritative flow:

1. read `/v1/player/state`, capture its state version, and stop before showing an ad when lives are
   already full;
2. create a protocol-1.4 `life` reward intent with no client-authored effect or run binding;
3. pass only the returned opaque nonce to AdMob as `ssv_custom_data`;
4. after the SDK reports reward earned, poll the intent status; and
5. return the backend `life_state` only after the status is `settled` with the exact one-life
   effect.

Dismissal, provider failure, malformed data, or pending/rejected/expired settlement grants no
life. A delayed callback changes the action to `Verify Reward`; another tap polls the same intent
without showing a second ad.

## Routing and economy boundary

Both modal owners mirror the settled `life_state` through
`PlayerProgress.apply_authoritative_life_state()`, which persists the authoritative balance but
does not append a local purchase/grant operation.

- `production_main_menu.gd` closes the modal and resumes only the campaign launch that originally
  opened it. A life acquired from the top-status lives widget closes the modal and stays on the
  Main Menu.
- `level.gd` routes both coin and rewarded recovery through the same restart helper. The failed
  level is restarted once after a verified life exists.

Coin purchase remains available whenever its existing economy rules allow it and is locked only
while rewarded verification is active. Natural restoration while a launch is pending uses the
same single completion path, preventing a stale or duplicate launch.

## Gates

`configs/ads.json` enables the `life` placement in bundled rewarded policy. Actual requests still
require the configured provider, native integration, consent, loaded inventory, authenticated
backend session, and backend runtime ad-unit mapping. Default project/native provider switches
remain off and interstitial policy remains disabled for release.

AdMob inventory is cached per rewarded placement so preloading a life ad cannot overwrite or
consume a time-extension ad. Production uses the existing platform rewarded-unit settings for
time extension and the distinct `admob_android_rewarded_life_ad_unit_id` /
`admob_ios_rewarded_life_ad_unit_id` settings for life; those IDs must match the backend's unique
platform/placement runtime mapping.

## Verification

- `tests/ads/test_rewarded_life.gd` covers the closed intent binding, nonce forwarding, exact
  effect validation, settled authoritative state, delayed reconciliation without a second ad,
  dismissal no-grant behavior, and full-cap rejection before intent creation.
- `tests/ui/test_out_of_lives_menu.gd` covers the dedicated signal and visible loading/error states,
  plus one-time pending-launch resume without coin spend or a local life-purchase operation.
- `tests/ui/test_level_failure_screen.gd` covers one-time rewarded retry through the existing
  failed-level restart route.
- Responsive captures cover the unavailable and retryable-error states at 540x960, 720x1280,
  1080x1920, and 1080x2400. The requested 1200x1600 tablet capture was rendered by the window
  manager at 900x1600 and is retained only as a warning-marked supplementary check.
