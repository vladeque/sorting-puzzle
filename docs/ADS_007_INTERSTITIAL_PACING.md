# ADS-007 Automatic Interstitial Pacing

Status: **implemented and release-disabled**.

## Runtime boundary

`scripts/ads/interstitial_completion_gate.gd` is a level-scoped, one-shot owner. `scripts/level.gd`
notifies it only after `PlayerProgress.complete_level()` commits a new non-development campaign
completion. It baselines historical completions at `total_completed_levels - 1`, counts the newly
committed completion once, and preloads best-effort without delaying the completion celebration.

The completion screen's Continue action is the only presentation point. It disables repeated input,
requests an interstitial with `safe_transition = true`, and returns to the main menu after every
terminal result: dismissal, no fill, policy denial, consent denial, backgrounding, or show failure.
Failure, retry, leave, startup, development levels, and next-level startup do not enter this gate.

`AdService` and `AdPolicy` continue to own all eligibility. The request must pass the activation
baseline, first/subsequent completion threshold, cooldown, per-session cap, rewarded-impression
suppression, stable local rollout assignment, foreground, consent, provider readiness, safe
transition, and one-active-request guard. Gameplay cannot supply its own rollout bucket. Only a
confirmed impression resets the completion counter and increments the session cap.

The committed initial-release policy remains:

- `interstitial.enabled = false`
- `interstitial.rollout_percent = 0`
- first ad after 5 new committed completions following activation
- subsequent ads after 3 new committed completions
- 10-minute cooldown, 2 impressions per session, and 5-minute rewarded suppression

Because `record_campaign_completion()` fails closed while interstitial policy is disabled, the
initial release does not accumulate a hidden backlog. A later enabled policy starts from the then-
current completion baseline.

## Verification

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ads/test_interstitial_completion.gd
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ads/test_ad_infrastructure.gd
```

The tests cover one-shot committed counting, historical baseline behavior, safe-transition-only
presentation, navigation-safe provider failure, stable service eligibility, impression-only reset,
session impression counting, persistence, and provider call suppression when ineligible.
