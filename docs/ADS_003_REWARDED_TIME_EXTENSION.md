# ADS-003 Rewarded Time Extension

Status: **implemented behind release/provider gates**.

## Player flow

At the recoverable `00:00` timeout, the existing coin route remains independent. The ad action is
enabled only when the local placement flag, `AdService` policy/consent/readiness, and authenticated
backend transport are all available. While a request is active, both payment actions are locked.

`scripts/ads/rewarded_time_extension_client.gd` owns the authoritative flow:

1. read `/v1/player/state` and require the same current campaign level;
2. start an online run and record its first action;
3. create a protocol-1.4 `time_extension` reward intent;
4. pass only the returned opaque nonce to AdMob as `ssv_custom_data`;
5. after the SDK reports reward earned, poll the intent status; and
6. return 60 seconds only after the backend reports `settled` with a valid authorization.

Dismissal, provider failure, malformed data, or a pending/rejected/expired status grants no time and
does not consume the attempt's rewarded slot. A delayed pending callback leaves a `Verify Reward`
action that polls the same intent without showing another ad. The coin action stays available.

## Run settlement and local-first compatibility

Once the reward flow starts an online run, that run owns its terminal life transition. Failure or
leave calls the authoritative terminal endpoint and mirrors the returned life state locally without
creating another v2 life-spend operation. Completion submits the exact issued authorization through
protocol 1.4 `sorting-puzzle-completion/2` before the existing local completion is committed.

The local completion remains the immediate/offline UI journal. The backend's mixed v1.3/v2 merge
uses the online completion as its baseline, so the mirrored v2 completion cannot grant progression,
stars, or chest rewards twice. Ability uses stay in the existing v2 journal and are reported as zero
on this compatibility run, avoiding a second debit.

## Gates

- `configs/time_extension.json` enables the compiled placement capability.
- `configs/ads.json` enables provider policy plus the implemented rewarded time-extension and life
  placements; ability/shelf rewarded placements and interstitials remain disabled.
- `application/config/ad_provider`, native integration, platform AdMob enablement/application ID,
  consent, ad readiness, backend URL/session, and backend runtime ad-unit mapping must all be valid.
- Interstitials remain independently disabled.

Production IDs are not committed, and the default project/native provider switches stay off.
Release builds enable those environment-specific switches only after the physical-device consent,
SSV, lifecycle, and store/privacy checks in `ADS_001_PRODUCT_POLICY_AND_PROVIDER.md`. Interstitials
remain off on release.

## Verification

- `tests/ads/test_rewarded_time_extension.gd` proves intent/run sequencing, nonce forwarding,
  pending no-grant behavior, dismissal no-grant behavior, exact 60-second effect validation, and
  completion authorization binding.
- `tests/gameplay/test_time_extension.gd` proves the paused modal consumes the rewarded slot once,
  grants exactly 60 seconds, resumes the same board, and keeps the unavailable and coin paths safe.
- `tests/save/test_player_progress_facade.gd` proves authoritative life mirroring creates no second
  local-first spend operation.
- `tests/backend/test_game_007.gd` covers the authenticated protocol POST envelope and idempotency
  header added to the shared transport.
