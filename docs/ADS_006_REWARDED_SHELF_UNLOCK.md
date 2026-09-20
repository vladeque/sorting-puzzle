# ADS-006 Rewarded Locked-Shelf Unlock

Status: **implemented behind release/provider gates**.

## Player flow

A triple-gated shelf keeps its configured `unlock_after_triples` countdown and its existing lock
art. When the rewarded `shelf_unlock` placement is configured, the backend can accept a claim, and
that placement has loaded inventory, the shelf's `AD` lock plate becomes tappable and plays a gentle
idle pulse so it reads as an action rather than decoration. When the placement is unavailable the
plate keeps exactly its previous decorative appearance and accepts no input at all.

Tapping the plate never starts an ad. It opens `scenes/ui/shelf_unlock_menu.tscn`, which states the
exact offer -- one ad unlocks this one shelf -- alongside the clear count the shelf still requires
without it. Gameplay pauses for the confirmation, the ad, and verification, and every other plate is
withdrawn while a claim is bound, so only one shelf claim can be pending at a time.

The CTA has explicit ready, loading, verifying, pending (`Verify Reward`), and retryable-error
states. Closing before an earned reward grants nothing and leaves the shelf locked with the same
visible clear count; an unsettled intent holds the modal so the player reconciles it instead of
watching a second ad.

## Authorization and gameplay boundary

`scripts/ads/rewarded_time_extension_client.gd` owns one authoritative online run shared by the
time-extension, ability, and shelf-unlock placements. The shelf-unlock flow:

1. starts or reuses the current level's run and reserved life;
2. creates a protocol-1.4 `shelf_unlock` intent bound to that run and exact configured shelf id;
3. forwards only the backend nonce as AdMob `ssv_custom_data`;
4. accepts only a settled `{kind: shelf_unlock, shelf_id}` authorization naming the bound shelf; and
5. marks that one shelf ad-unlocked for the current attempt.

Shelf identity is `SHELF_CONFIG_ID_META`: the shelf's 1-based index in the immutable level
definition's `shelves` array, which every layout path already uses as its shelf number. It is not a
node instance or a screen position, so it survives responsive relayouts, board rebuilds, and
collapsing-column motion. Authorizations are kept per shelf id rather than as one attempt-wide slot,
so every locked shelf retains its own rewarded route while it remains locked, and a shelf already
unlocked this attempt cannot be claimed again.

Run completion uses claim format 2 whenever any rewarded placement settled, and reports each issued
shelf authorization in ascending shelf order alongside the time and ability authorizations.

## Gameplay application

A verified authorization sets one entry in `level.gd`'s per-attempt `_ad_unlocked_shelf_ids` and
then reuses the paths that already own unlocking: `_update_locked_shelves()` for lock meta, item
input activation, `ShelfLockOverlay.play_unlock()`, and the shared unlock SFX/haptic, followed by one
`_resolve_shelves()` pass in case the released shelf's visible items already form a triple.

`_triples_cleared`, stars, and the combo are untouched, and no shelf's configured
`unlock_after_triples` changes, so every other locked shelf keeps evaluating its own requirement with
an unchanged visible countdown. The state is attempt-scoped: a retry rebuilds the board with every
configured lock intact.

## Gates

`configs/ads.json` enables the rewarded shelf-unlock policy, but live requests still require the
AdMob provider, native integration, consent, authentication, loaded inventory, and a matching
backend runtime mapping. Android and iOS use distinct empty-by-default
`admob_*_rewarded_shelf_unlock_ad_unit_id` project settings. Interstitials remain disabled for
release.

Proof/validator coverage for forged, duplicate, wrong-shelf, and wrong-attempt claims is server-side
work and belongs to BE-ADS-001 in `../sorting-puzzle-backend`; this ticket does not change that
repository. The client rejects a settled authorization that names any other shelf rather than
redirecting it to the shelf the player is looking at.

## Verification

- `tests/ads/test_rewarded_shelf_unlock.gd` covers exact run/shelf intent binding, two shelves
  settling on one shared run, the exact reported authorization set, wrong-shelf intent rejection,
  one-unsettled-claim-at-a-time, pending reconciliation without a second presentation, and duplicate
  rejection.
- `tests/gameplay/test_rewarded_shelf_unlock.gd` covers the plate offering an action only while the
  shelf is locked and the placement is ready, a tap opening the confirmation without starting an ad,
  duplicate-tap protection, the bound shelf unlocking while the other shelf's requirement and
  countdown stay put, `_triples_cleared`/stars staying put, immediate item interactability, and
  dismissed/wrong-shelf claims leaving the shelf locked.
- `tests/ads/test_ad_infrastructure.gd` verifies placement-isolated ad inventory.
- `tests/ui/test_level_ui_consistency.gd` verifies the fail-closed default and explicit CTA states.
- Responsive captures `ads006_shelf_unlock_modal` (540x960 through a tablet-like portrait viewport),
  `ads006_shelf_unlock_error`/`_pending`/`_unavailable`, and
  `ads006_shelf_lock_ad_ready` versus `ads006_shelf_lock_decorative` for the two plate states.
