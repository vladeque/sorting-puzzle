# ADS-005 Rewarded Immediate Ability

Status: **implemented behind release/provider gates**.

## Player flow

When Hammer, Shuffle, or Lantern has zero saved uses, Ability Purchase keeps its existing coin
action and exposes `Watch Ad` only when the rewarded `ability` placement is configured, the backend
can accept a claim, and that placement has loaded inventory. Freezer remains coin-only because it
is outside the approved backend rewarded-ability enum.

The ad action has explicit loading, verifying, pending (`Verify Reward`), and retryable-error
states. While a request or unsettled intent exists, the coin action, close action, ability
selection, and duplicate taps are locked. A pending retry polls the same intent and never presents
a second ad.

## Authorization and gameplay boundary

`scripts/ads/rewarded_time_extension_client.gd` owns one authoritative online run shared by the
time-extension and ability placements. The ability flow:

1. starts or reuses the current level's run and reserved life;
2. creates a protocol-1.4 `ability` intent bound to that run and exact selected ability;
3. forwards only the backend nonce as AdMob `ssv_custom_data`;
4. accepts only a settled `{kind: ability, ability_id, uses: 1}` authorization; and
5. invokes the existing immediate-use execution path without adding saved inventory or spending
   coins.

Run completion uses claim format 2 when either rewarded placement settled. It reports one use for
the authorized ability and includes the exact issued authorization set. Coin- and inventory-funded
uses remain in the local-first journal and are not reported again by this compatibility run.

## Gates

`configs/ads.json` enables the rewarded ability policy, but live requests still require the AdMob
provider, native integration, consent, authentication, loaded inventory, and matching backend
runtime mapping. Android and iOS use distinct empty-by-default
`admob_*_rewarded_ability_ad_unit_id` project settings. Interstitials remain disabled for release.

## Verification

- `tests/ads/test_rewarded_ability.gd` covers exact run/ability intent binding, shared-run
  completion, exact authorization reporting, pending reconciliation, and Freezer rejection.
- `tests/gameplay/test_rewarded_ability.gd` covers the ready CTA, duplicate/selection/close locks,
  immediate application, and no coin or persistent-inventory mutation.
- `tests/ads/test_ad_infrastructure.gd` verifies placement-isolated ad inventory.
- `tests/ui/test_level_ui_consistency.gd` verifies fail-closed default and explicit CTA states.
- Responsive capture `ads005_rewarded_ability` covers the ready offer.
