# In-Game Ads Implementation Plan

## Purpose

Add two clearly separated ad experiences:

1. **Rewarded ads** are explicitly chosen by the player in exchange for a stated benefit.
2. **Interstitial ads** are shown automatically only at a natural break after a configured number
   of newly completed campaign levels.

Rewarded ads are launch features. Automatic interstitials alone must ship disabled for the initial
release and be enabled later without a client update. A remote configuration mistake must not be
able to expose an unimplemented placement or grant a client-invented reward.

This is a cross-repository feature. The client work belongs here; authoritative ad-reward claims,
economy grants, and gameplay authorization require separately approved work in
`../sorting-puzzle-backend`.

## Terminology and provider direction

Google Play and the App Store distribute the game; they do not provide a shared in-game ad API.
Apple Ads promotes apps inside Apple properties rather than serving ads inside this game. The
recommended first provider evaluation is therefore Google AdMob/Google Mobile Ads on both Android
and iOS, behind a game-owned provider interface so the provider can be replaced or mediated later.

Godot does not provide the required native AdMob bridge in this repository. Time-box a technical
spike against the current Poing Studios Godot AdMob plugin and one alternative before selecting a
dependency. The spike must prove Godot 4.6.2 Android and iOS exports, rewarded and interstitial
callbacks, consent, test ads, pause/resume behavior, and clean dependency removal. Pin the chosen
plugin version and checksums; do not consume an unpinned Asset Library update in production.

## Current-state audit

### Actual rewarded-ad candidates

| Placement | Current state | Intended rewarded result | Required work |
| --- | --- | --- | --- |
| Ability purchase | `scenes/ability_purchase_menu.tscn` authors `%WatchAdButton` as disabled with `Coming Soon`; `scripts/ability_purchase_menu.gd` hides it in production and exposes it disabled in debug. `scripts/level.gd::_on_ability_purchase_ad_pressed()` is empty. | Apply the one selected ability immediately, matching the coin action rather than adding inventory. | Provider flow, enabled/loading states, one-request guard, backend-approved ad payment source, and gameplay authorization. |
| Time-up extension | `scenes/ui/time_up_extension_modal.tscn` shows a disabled `Watch Ad / Coming Soon` action in production. `configs/time_extension.json` reserves one rewarded use per attempt but keeps it disabled. `scripts/level.gd` has both a hard integration guard and a no-grant handler. | Add the configured 60 seconds once per attempt while the board remains paused. | Provider flow, attempt-scoped claim, verified reward, idempotent slot consumption, and validator/protocol coverage. This is the best first rewarded placement because the product/UI state is already designed. |
| Out of lives | `scenes/ui/out_of_lives_menu.tscn` contains an always-disabled generic `%ComingSoonButton`. It has no signal or handler in `scripts/out_of_lives_menu.gd`. The same modal is owned by the main menu and the failed-level retry flow. | Restore exactly one life below the cap; resume the interrupted launch/retry only after the grant succeeds. | Replace the generic placeholder with a rewarded action, add intent routing to both owners, and add an authoritative life ledger grant. |
| Locked shelf | `scenes/ui/shelf_lock_overlay.tscn` already displays `AD`, but the overlay is presentational and has no input. `scripts/level.gd` currently unlocks shelves only when the global cleared-triple count reaches `unlock_after_triples`. | Unlock the one shelf the player selected without adding fake cleared triples or changing any other shelf's countdown. | Add an explicit tap/confirmation flow, stable shelf identity, per-attempt rewarded-unlock state, provider/claim routing, and gameplay-proof authorization. |

### “Coming Soon” UI that is not an ad placement

| UI | Finding | Decision |
| --- | --- | --- |
| Chapter cover CTA | `scripts/chapters/chapter_cover_card.gd` uses `Coming Soon` when an unlocked chapter contains no levels. | Content availability only. Do not turn it into an ad. |
| Main-menu level button | `scripts/production_main_menu.gd` uses `COMING SOON` when the selected chapter has no next level. | Content availability only. Do not turn it into an ad. |
| Other placeholders | The remaining `PlaceholderTexture2D` entries are scrollbar theme resources, not player-facing offers. Backend “not available” strings are diagnostics, not reward alternatives. | Out of scope. |

### Integration gaps

- No ad SDK, ad provider, consent manager, ad configuration, or ad analytics exist.
- The only native Android plugin is the secure-store bridge. The committed Android export is a
  local-backend debug preset; the release currently does not request Internet access.
- No iOS export preset or iOS native plugin setup is committed in this repository.
- The canonical backend requirements explicitly say current watch-ad actions grant nothing.
  Backend protocol v2 has no ad-reward operation, and authoritative ability spending has no
  rewarded-ad payment source.
- Time-extension policy reserves an ad slot, but neither the client nor server authorizes its use.

## Product rules

### Rules shared by all ads

- Keep independent provider, rewarded-format, interstitial-format, and placement kill switches. The
  production launch policy enables implemented rewarded placements and disables interstitials.
- Fail closed: no config, consent, network, provider readiness, or verification means no ad and no
  reward. Keep the existing coin/wait alternatives usable.
- Never show an ad during active puzzle interaction, the completion celebration, a purchase flow,
  another modal transition, or while the app is backgrounded.
- Never chain an interstitial immediately after a rewarded ad. Apply a configurable suppression
  window and allow at most one full-screen ad per transition.
- An unavailable or failed ad must not silently replace the player's requested action.
- Use provider test ad units in editor/debug/QA builds. Production IDs must be environment- and
  platform-specific and must never be used by automated tests.
- Do not initialize the ad SDK while the provider switch is off. Inclusion of an SDK still requires
  an explicit privacy and store-disclosure review.

### Rewarded ads

- The player must tap a button whose copy states both the ad and exact reward, for example
  `Watch Ad · +1 Life` or `Watch Ad · +60s`.
- A button is enabled only when the placement is remotely enabled, the SDK may request ads, an ad
  is loaded, and the server can accept a claim. Use a short `Loading…` state rather than leaving an
  enabled button that will fail.
- Grant only from the provider's earned-reward callback plus the authoritative server claim. A
  click, impression, close, or full-screen dismissal is not a reward.
- A close before the earned-reward callback grants nothing and returns to the unchanged modal.
- Duplicate, delayed, and out-of-order callbacks must be idempotent. The provider transaction ID
  may produce one grant at most.
- Rewarded placements require connectivity. Do not invent an offline rewarded-ad journal entry.
- A verified reward that arrives after a scene change must still be applied exactly once and be
  visible after state reconciliation.

#### Rewarded locked-shelf interaction

- Make the `AD` lock plate tappable only while that shelf is still locked and the placement is
  eligible. Tapping it opens a dedicated confirmation modal stating that one ad unlocks this shelf;
  it must not launch an ad on the first incidental shelf tap.
- Bind the request to a stable shelf ID from the immutable level definition, not a transient node
  instance or screen position.
- Pause gameplay while the confirmation, ad, and verification flow is active. Only one shelf claim
  may be pending at a time.
- On verified success, mark only that shelf as ad-unlocked for the current attempt, make its items
  immediately interactable, run the existing `ShelfLockOverlay.play_unlock()` animation, and call
  the existing shelf-resolution path in case its visible items already form a triple.
- Do not increment `_triples_cleared`, grant stars/combo, or reduce another shelf's countdown. Other
  shelves continue to evaluate their configured `unlock_after_triples` requirement normally.
- If the ad is dismissed, fails, or cannot be verified, the selected shelf remains locked with the
  same visible clear count.
- Each configured locked shelf may be unlocked once per attempt. Do not add an attempt-wide cap at
  launch; every locked shelf must retain its own rewarded path while it remains locked.

### Automatic interstitials

Interpret “after each X levels” as **after X newly committed production campaign completions**.
Level starts, retries, failures, leaves, developer levels, re-opened completion screens, and reward
chest animation do not increment the counter.

The natural break is after the completion result has been committed and shown, while routing away
from the completion screen. The level is already frozen at this point. Do not show at the beginning
of the next level or over active play.

Recommended policy inputs:

```json
{
  "schema_version": 1,
  "provider_enabled": true,
  "rewarded": {
    "enabled": true,
    "time_extension_enabled": true,
    "life_enabled": true,
    "ability_enabled": true,
    "shelf_unlock_enabled": true
  },
  "interstitial": {
    "enabled": false,
    "rollout_percent": 0,
    "completed_levels_per_ad": 3,
    "minimum_completed_levels_before_first_ad": 0,
    "minimum_seconds_between_ads": 300,
    "maximum_ads_per_session": 3,
    "suppress_after_rewarded_seconds": 180
  }
}
```

`3` is an example interval, not an approved post-release value. The remote service must validate
that intervals and caps are positive and bounded. The rewarded section represents the intended
production launch policy; interstitials remain off regardless of their configured pacing values.

Pacing behavior:

1. Persist `eligible_completions_since_interstitial`, last impression time, session impression
   count, last rewarded-ad time, and the config version used. This state is local and is not an
   economy balance.
2. When ads are enabled for an existing install for the first time, store the current completion
   count as the baseline. Do not immediately monetize old completions.
3. Increment only after `PlayerProgress.complete_level()` commits a new completion.
4. At the post-result transition, ask the policy object whether an interstitial is due and safe.
5. Reset the completion counter only after an actual impression callback. A load/no-fill failure
   keeps the ad due, but the next attempt occurs only at a later eligible completion break—never
   unexpectedly on the main menu or mid-level.
6. If the player is not eligible because of consent, cooldown, session cap, rewarded suppression,
   or rollout assignment, continue immediately without an ad.
7. Always continue navigation after dismissal or presentation failure. An ad outage must never
   block progression.

## Client architecture

Add an `AdService` autoload as the only API gameplay and menus can call:

```text
Level / Main Menu placement
        |
        v
AdService ----> AdPolicy + pacing state
        |
        v
AdProvider interface ----> AdMob adapter ----> native Android/iOS SDK
        |                         |
        +----> Mock adapter       +----> load/show/full-screen callbacks
        |
        v
RewardClaimClient ----> authoritative backend / SSV verification
```

Suggested ownership:

- `scripts/ads/ad_service.gd`: lifecycle, placement requests, one-active-ad guard, preload, callback
  normalization, audio restoration, and public signals/results.
- `scripts/ads/ad_policy.gd`: pure eligibility and interstitial pacing decisions. It must have no
  native SDK dependency.
- `scripts/ads/ad_provider.gd`: provider contract for initialize, consent state, load, show, and
  normalized callbacks.
- `scripts/ads/admob_provider.gd`: selected plugin adapter. No gameplay reward logic belongs here.
- `scripts/ads/mock_ad_provider.gd`: deterministic earned, dismissed, no-fill, load-failure,
  presentation-failure, and delayed/out-of-order scenarios for editor/headless tests.
- `scripts/ads/ad_reward_claim_client.gd`: create and reconcile backend reward intents without
  exposing SDK-specific data to gameplay scenes.
- `configs/ads.json`: bundled fail-closed defaults and bounded schema, but no authoritative reward
  amounts and no production secrets.
- `PlayerProgress`: persist only non-economic pacing state through the existing crash-safe save
  path. Authoritative reward balances still come from the backend.

Expose request methods that return a single terminal result, such as `REWARDED`, `DISMISSED`,
`UNAVAILABLE`, or `FAILED`. A placement awaits that result and then chooses its existing UI path.
Do not let scenes subscribe directly to raw provider signals; doing so makes stale callbacks and
freed-scene races difficult to contain.

During full-screen presentation, record that the background/focus transition belongs to an ad so
the normal interruption handling does not open or resume unrelated overlays. Snapshot and restore
audio state without overriding the player's sound settings. Gameplay remains paused for all four
rewarded placements and is already terminal for an interstitial.

## Authoritative reward design

Create a separately approved backend contract before enabling a rewarded button:

1. The client requests an ad-reward intent with placement, player, device/session, campaign level
   or attempt ID where applicable, and an idempotency key.
2. The server validates eligibility and returns an opaque intent/nonce to place in AdMob
   server-side verification custom data. Reward type and amount come from immutable server
   configuration, never from the client or AdMob UI alone.
3. AdMob sends an SSV callback. The backend validates the signature/key, timestamp, ad unit,
   placement binding, player/intent binding, and unique provider transaction ID.
4. The backend atomically settles the intent and its one authorized effect, or records a terminal
   rejection. Repeated callbacks return the original result.
5. The client waits/polls for a bounded verification result while showing `Verifying reward…`, then
   reconciles the authoritative player state. If verification is delayed, keep the claim pending
   and reconcile after restart rather than granting locally a second time.

Placement settlement:

- **Life:** append a rewarded-ad ledger grant of one life, capped by the configured maximum, then
  return authoritative lives and next-restoration state.
- **Ability:** issue an attempt/ability-bound authorization consumed by the immediate ability use.
  Extend the existing authoritative ability-spending contract so the run is backed by this source.
- **Time extension:** issue an attempt-bound authorization for the configured seconds and consume
  the attempt's rewarded slot exactly once. Extend gameplay proof/settlement so the resulting timer
  is valid and cannot be replayed on another attempt.
- **Locked shelf:** issue an attempt-and-shelf-bound authorization. Record an explicit rewarded
  shelf-unlock event in the gameplay proof so the validator permits subsequent interaction with
  that shelf without treating it as a cleared-triple unlock. Reusing the authorization for another
  shelf or attempt must fail.

The server must not accept a new client-authored generic `ad_reward` journal operation. SSV-backed
grants and gameplay authorizations are online authoritative facts.

## Configuration and safe rollout

Use two gates for each rewarded placement and three for interstitials:

- A compiled integration-capability constant/build feature confirms that provider code exists.
- A remotely served, versioned policy controls the provider, format, and placement switches.
- Interstitials additionally require rollout and pacing eligibility.

The applicable gates must all be true. Missing, expired, malformed, or unsupported remote policy
resolves to disabled. Cache only a previously verified policy with a bounded expiry; an emergency
kill switch should take effect on the next foreground/config refresh.

Keep ad unit IDs outside economy configuration. Store separate test/staging/production IDs per
platform in export/native configuration. The backend may identify an allowed placement/ad-unit
mapping for SSV validation, but the client cannot change the reward by changing an ID.

Recommended rollout:

1. Validate the SDK with test IDs and all rewarded placements on internal accounts before release.
2. Verify crash rate, consent flow, app size, startup time, SSV settlement, and each rewarded
   fallback path.
3. Launch production with the approved rewarded placements enabled, interstitial
   `enabled = false`, and interstitial rollout `0`.
4. Keep independent kill switches for time extension, life, ability, shelf unlock, all rewarded
   ads, and the provider so a defective placement can be removed without disabling the others.
5. Enable interstitials later and separately with a holdout cohort. Start with conservative caps,
   evaluate retention and session depth, then tune the interval remotely.
6. Retain an independent interstitial kill switch throughout rollout.

## Privacy, store, and audience requirements

Before SDK initialization:

- Decide whether the game targets children or a mixed audience. Configure content rating,
  child-directed treatment, under-age-of-consent handling, and ad personalization accordingly.
- Refresh consent information at app launch and provide the required privacy-options entry point in
  Settings. Only request ads when the consent SDK reports that requests are allowed.
- On iOS, decide whether tracking is necessary. If it is, supply a clear ATT purpose string and ask
  before accessing IDFA; denial must leave a functional non-tracking experience. Do not make an ad
  reward conditional on accepting tracking.
- Add/verify iOS privacy manifests, SDK signatures, `Info.plist` entries, SKAdNetwork identifiers,
  and App Store privacy labels.
- Update the Google Play Data safety form, Ads declaration, content rating, privacy policy, and any
  Families declarations.
- Provide an in-app route for reporting inappropriate or age-inappropriate ads where required.

## Telemetry

Record placement and policy outcomes without gameplay proofs, raw SSV query strings, advertising
identifiers, or sensitive device data:

- `ad_offer_rendered`
- `ad_load_requested`, `ad_load_succeeded`, `ad_load_failed`
- `ad_show_requested`, `ad_impression`, `ad_clicked`
- `ad_reward_callback`, `ad_dismissed`, `ad_show_failed`
- `ad_reward_verified`, `ad_reward_rejected`, `ad_reward_pending`
- `interstitial_due`, `interstitial_skipped` with a bounded reason enum

Include provider, format, placement, config version, app version, session-relative timing, and a
provider response/error category. Revenue telemetry must use the provider's paid-event callback and
must remain separate from reward settlement.

## Delivery sequence

### ADS-001 — Approve product policy and provider

- Confirm the audience/age policy, target countries, whether personalized ads are needed, and the
  exact reward/cap for each placement.
- Choose and security/license-review the Godot 4.6.2 Android/iOS plugin through the platform spike.
- Approve the interstitial interval, cooldown, session cap, suppression window, and any future
  ad-free entitlement behavior.

### ADS-002 — Build client ad infrastructure

- Add `AdService`, policy, provider interface, mock provider, fail-closed config, and pacing save.
- Add consent/privacy entry-point plumbing and test-mode diagnostics.
- Integrate and pin native Android/iOS dependencies, export settings, and required network/native
  metadata.
- Keep production IDs and production requests unavailable until the rewarded flows and their
  backend contracts pass release verification.

### BE-ADS-001 — Approve and implement reward contracts

- Add versioned placement definitions, reward-intent endpoints, AdMob SSV verification, transaction
  deduplication, immutable audit records, and eligibility/rate limits.
- Add life ledger grants plus ability, time-extension, and selected-shelf gameplay authorizations.
- Add reconciliation/status responses and conformance fixtures for duplicates, mismatches, delays,
  and replay attempts.
- Update the canonical backend requirements and protocol/validator documents before client
  production activation.

### ADS-003 — Enable rewarded time extension behind flags

- Replace the hardcoded integration constant with the compiled capability plus policy/readiness
  gates.
- Implement the paused claim flow and consume the per-attempt slot only after verification.
- Keep the coin extension independent and usable when ads are unavailable.

### ADS-004 — Enable rewarded life

- Give `OutOfLivesMenu` a dedicated `rewarded_ad_requested` signal and explicit loading/error states.
- Route successful grants through both `production_main_menu.gd` and `level.gd` without duplicating
  purchase/retry behavior.
- Refresh authoritative life state, then resume a pending launch/retry exactly once.

### ADS-005 — Enable rewarded immediate ability

- Make the existing button production-visible only when the placement is configured and ready.
- Bind the claim to the selected ability and current attempt, then invoke the same ability execution
  path as an authorized coin-backed immediate use.
- Prevent selection changes, duplicate taps, overlay close, or scene teardown from applying the
  reward to a different ability.

### ADS-006 — Enable rewarded locked-shelf unlock

- Give `ShelfLockOverlay` an intentional input owner and add a dedicated confirmation modal rather
  than starting an ad directly from a shelf tap.
- Add stable configured shelf IDs and per-attempt ad-unlocked shelf state in `level.gd`; do not
  mutate `_triples_cleared` or the configured requirement.
- Bind the verified authorization to the selected shelf and attempt, then reuse the existing input
  activation, unlock animation, feedback, and shelf-resolution paths.
- Add proof/validator coverage for legal rewarded unlocks and forged, duplicate, wrong-shelf, and
  wrong-attempt claims.

### ADS-007 — Add automatic interstitial pacing

- Increment pacing only after a committed new campaign completion.
- Schedule presentation at the post-completion result transition and continue navigation on every
  terminal outcome.
- Enforce activation baseline, cooldown, session cap, rewarded suppression, one-ad guard, rollout,
  consent, foreground, and readiness rules.

### ADS-008 — Compliance, QA, and release validation

- Complete store disclosures, privacy policy, consent/ATT, age treatment, and ad-reporting flow.
- Run the full automated, visual, native-device, and backend conformance matrix.
- Ship rewarded placements enabled after verification; ship interstitials disabled and activate
  them later through remote policy.

## Verification plan

### Automated client tests

- Pure policy matrix for every provider/format/placement/rollout/cooldown/session/counter
  combination.
- Pacing persistence across restart and configuration changes; old completions never create an
  immediate ad on first activation.
- Reward callback orders: earned then dismissed, dismissed without earned, failure, duplicate
  earned, delayed earned, and callback after scene destruction.
- One-active-ad and rapid-tap protection.
- No-fill and offline behavior preserves coin/wait alternatives.
- Locked-shelf success unlocks only the bound shelf, does not change `_triples_cleared`, and runs
  resolution once; dismiss/failure/invalid claim leaves the shelf and countdown unchanged.
- Shelf claims remain bound across node layout changes and reject duplicate, stale, wrong-shelf,
  wrong-level, and wrong-attempt callbacks.
- No interstitial on failure, retry, leave, developer level, startup, next-level start, or a
  completion already counted.
- Navigation always continues after interstitial dismissal or show failure.
- App background/foreground, audio, haptics, and pause state restore to their pre-ad values.
- Pending verified rewards reconcile once after process death.

### Backend tests

- Valid SSV signatures and rotated-key caching; invalid signature/key/unit/placement/player rejected.
- Unique provider transaction and intent idempotency under concurrent duplicate callbacks.
- Expired intents, replayed custom data, wrong attempts, over-cap lives, reused time slots, and
  mismatched abilities grant nothing.
- Atomic ledger/authorization settlement and authoritative state responses.
- Gameplay validator accepts exactly the authorized ability/time extension and rejects fabricated
  client claims.

### Visual and device tests

- Capture the ability, time-up, out-of-lives, tappable shelf lock, and shelf-unlock confirmation
  states at 540x960, 720x1280, 1080x1920, 1080x2400, and a tablet-like portrait viewport after
  their scene changes.
- Verify `Loading`, ready, verifying, unavailable, failure, and used states with large text and safe
  areas.
- Test real Android and iOS devices with provider test IDs, consent granted/denied, ATT
  granted/denied, slow network, no fill, rotation/backgrounding, and fresh/returning installs.
- Inspect Android and iOS release artifacts for the pinned SDK versions, permissions, privacy
  manifests, and absence of test IDs in production configuration.

## Definition of done

- Initial public release enables the approved rewarded placements and produces no automatic
  interstitial requests or impressions.
- The three audited placeholders and the locked-shelf `AD` action are working, policy-gated
  rewarded placements; unavailable/no-fill states remain honest and preserve the non-ad path.
- No ad callback can directly modify authoritative economy or gameplay state.
- Interstitials occur only after the configured number of new committed campaign completions and
  only at the completion-to-menu break after they are explicitly enabled post-release.
- All failure/no-fill/consent-denied paths continue the game without reward or navigation deadlock.
- Each reward and automatic impression is deduplicated, observable, remotely killable, and covered
  by client/backend tests.
- Android and iOS store disclosures and privacy behavior match the exact shipped SDK configuration.

## External implementation references

- [Google Mobile Ads SDK for iOS](https://developers.google.com/admob/ios/quick-start)
- [Google interstitial guidance for Android](https://developers.google.com/admob/android/interstitial)
- [Google rewarded-ad server-side verification](https://developers.google.com/admob/android/ssv)
- [Google User Messaging Platform setup](https://developers.google.com/admob/android/privacy)
- [Google Play ads policy](https://support.google.com/googleplay/android-developer/answer/9857753)
- [Apple user privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Current community Godot AdMob plugin candidate](https://github.com/poingstudios/godot-admob-plugin)
