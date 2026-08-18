# AUDIO-001 — Implement Godot-Authored Core Sound Effects

**Status:** Proposed

**Type:** Audio/UX

**Primary scope:** Core puzzle feedback, timer feedback, visible currency changes, Shop purchase
confirmation, reward-chest star arrivals, and shared UI buttons

**Depends on:** Existing `PlayerProgress` sound-effects preference and the current item-placement,
triple-clear, Shop, timer, and reward animation flows

## Objective

Add the approved sound effects that can be authored entirely with Godot-compatible project tooling.
Create deterministic, version-controlled WAV assets for simple transient and tonal sounds, retain the
two suitable gameplay recordings already in the project, and route all playback through one focused
SFX owner that respects the saved sound-effects setting everywhere in the game.

This ticket must not use AI-generated audio, third-party recordings, online sound libraries, or new
externally produced source clips.

## Approved Event Scope

Implement exactly these events:

| Event ID | Player-visible trigger | Asset approach |
| --- | --- | --- |
| `item_select` | A tap finishes by selecting an eligible shelf item. | Synthesize 2–3 short tactile pop variants. |
| `item_place_valid` | An item completes an accepted landing. | Retain `assets/audio/item_place.wav`; add safe pitch/volume variation and polyphonic playback. |
| `match_clear` | A matched triple finishes gathering and begins disappearing. | Retain `assets/audio/triple_clear.wav`; replace the current stop/restart playback with polyphonic playback. |
| `star_hud_arrival` | Match-earned stars finish flying into the in-level HUD star counter. | Synthesize a bright, short arrival chime. |
| `timer_critical_tick` | The active, unfrozen countdown advances by one displayed second at or below the HUD's critical threshold. | Synthesize 2–3 dry clock-tick variants, with a restrained final-five-seconds accent. |
| `time_up` | The timer reaches zero and the time-extension modal or terminal failure flow begins. | Synthesize a final tick plus short low clock-stop/alarm cue. |
| `coin_gain` | A visible, accepted reward increases the displayed coin balance. | Synthesize an ascending metallic 2–3 note sequence. |
| `coin_spend` | A successful player action visibly spends coins. | Synthesize a shorter descending metallic sequence. |
| `shop_purchase_success` | Shop purchase verification and local reward application both succeed. | Synthesize a warm confirmation chord; layer `coin_gain` separately only when the grant includes coins. |
| `reward_chest_star_arrival` | A completed-level reward star reaches and pulses the main-menu chest. | Synthesize a softer companion to `star_hud_arrival`; play once per animated arrival with rate limiting. |
| `ui_click` | An enabled visible `BaseButton` emits an accepted `pressed` action without a more specific replacement policy. | Synthesize 2–3 very short tactile click variants. |

## Current Problems

- The project contains only three source WAV files.
- `scripts/level.gd` creates one item-place player and one triple-clear player at runtime. Each helper
  stops its player before replaying it, so a rapid action cuts off the prior sound.
- Item landing and triple clearing are the only general game events with audio.
- Menu, Shop, reward, currency, and timer feedback has no shared playback owner.
- The saved sound-effects preference is read by the level and Hammer, but there is no global SFX
  path for UI or destination screens.
- Invalid item returns currently pass through the same landing helper as accepted moves and therefore
  play the placement sound. `item_place_valid` must not reinforce an invalid drop as successful.

## Required Work

### 1. Add a Deterministic SFX Asset Generator

Add a focused Godot tool script, recommended path:

```text
scripts/tools/generate_core_sfx.gd
```

The tool must generate project-owned WAV files under:

```text
assets/audio/generated/
```

Requirements:

- Run through the project's Godot 4.6.2 executable and produce identical PCM output from the same
  committed seed and parameters.
- Generate mono, 16-bit PCM WAV files at either 44.1 kHz or 48 kHz. Use one sample rate consistently.
- Use additive synthesis, simple frequency/pitch envelopes, deterministic filtered noise, amplitude
  envelopes, and short layered transients as appropriate.
- Remove DC offset, apply short attack/release fades, and keep final peaks at or below -1 dBFS.
- Do not normalize every cue to the same perceived loudness. Author relative loudness intentionally,
  then finish balancing in the SFX catalog/playback configuration.
- Refuse to overwrite outputs produced with a different committed generator version unless an
  explicit regeneration argument is supplied.
- Print every output path, duration, sample rate, peak level, and generator version.
- Document the exact regeneration command in this ticket and `docs/SCRIPTS.md` when implemented.

Recommended generated palette:

- `ui_click_01..03.wav`: 25–50 ms, soft transient with minimal tonal tail.
- `item_select_01..03.wav`: 40–75 ms, slightly rounder and brighter than `ui_click`.
- `star_hud_arrival.wav`: 140–240 ms, clean high chime without a long reverb tail.
- `timer_tick_01..03.wav`: 30–65 ms, dry clock-like ticks that remain readable under gameplay audio.
- `time_up.wav`: 300–600 ms, decisive but not harsh or horror-coded.
- `coin_gain.wav`: 300–650 ms ascending metallic sequence.
- `coin_spend.wav`: 180–350 ms descending metallic sequence.
- `shop_purchase_success.wav`: 400–750 ms confirmation chord with enough space for an optional
  simultaneous `coin_gain` layer.
- `reward_chest_star_arrival_01..03.wav`: 90–180 ms, warmer and softer than the HUD-star arrival.

Do not synthesize replacements for `item_place.wav` or `triple_clear.wav` in this ticket.

### 2. Add a Shared SFX Playback Owner

Create a focused audio owner, recommended path:

```text
scripts/audio/sfx_manager.gd
```

Register it as an autoload or provide an equivalently persistent scene-owned service that is
available to gameplay, Main Menu, Shop, Leaderboard, and modal scenes without duplicating players.

The owner must:

- Expose a small event-based API such as `play(event_id, context = {})`.
- Keep event-to-stream, volume, pitch range, cooldown, and maximum-polyphony configuration in one
  focused catalog rather than scattering preload constants across broad scripts.
- Use a reusable `AudioStreamPlayer` pool so rapid item placements, matches, ticks, and reward
  arrivals do not cut each other off or create an unbounded number of nodes.
- Select variants without immediate repetition and apply only subtle pitch variation.
- Apply per-event concurrency limits and cooldowns. High-frequency reward arrivals must remain
  intelligible rather than becoming a loud stack.
- Route playback through a dedicated `SFX` audio bus. Add and document the bus layout if the project
  does not yet have one.
- Respect `PlayerProgress.is_setting_disabled(&"sound_effects")` for every play request.
- Stop active SFX immediately when sound effects are disabled. Enabling SFX may play one quiet
  `ui_click` preview after the saved state changes.
- Preserve the level's ability to disable audio during automated captures and tests.
- Fail safely when an event or stream is missing: report a development warning and never block the
  owning gameplay/UI action.

### 3. Wire Puzzle Events

Update `scripts/level.gd` so:

- `item_select` plays only after an eligible item actually becomes selected. A press that becomes a
  drag, is cancelled, targets a locked/unavailable shelf, or is consumed by UI must not play it.
- `item_place_valid` plays for an accepted landing, including a deliberate same-slot landing if it
  runs the visible landing impact. Invalid/no-target returns to the origin must remain silent.
- `match_clear` stays synchronized with the existing post-gather disappearance beat.
- `star_hud_arrival` plays when the HUD receive pulse begins. A multi-star reward should produce one
  coherent count-scaled arrival cue, not one full-volume sound for every overlapping star.
- Existing landing, match, item transition, combo, shelf resolution, and completion timing remain
  unchanged apart from audio calls.

Remove or retire the level-local item-place and triple-clear players after the shared owner is fully
connected. Do not leave two playback paths that can double-trigger the same cue.

### 4. Wire Timer Events

Use the existing critical-timer state owned by `scripts/level_top_hud.gd` rather than calculating a
second critical threshold.

- Play `timer_critical_tick` once when a new critical displayed second causes the HUD pulse.
- Do not tick before the player's first action, while paused, while Freezer is active, after time has
  expired, or after the level reaches a terminal state.
- Use a restrained accent or pitch change for the final five seconds without increasing overall
  loudness on every second.
- Play `time_up` exactly once when `_handle_level_time_expired()` accepts the expiry. It must not
  replay when the modal refreshes, when the player lacks an extension, or when failure opens.

### 5. Wire Currency and Shop Events

Use semantic success points, not button presses:

- Play `coin_spend` only after `PlayerProgress.spend_coins()` or `purchase_life()` succeeds.
  Approved current contexts are an immediate ability purchase/use, a time extension, and a life
  purchase.
- Play `coin_gain` only for a visible accepted reward presentation: successful Shop coin grants,
  reward-chest coin payout at goal rollover, and a displayed weekly leaderboard reward.
- Do not play balance sounds for initial screen population, save loading, backend reconciliation,
  rejected/duplicate transactions, or merely opening a coin-bearing offer.
- Play `shop_purchase_success` only after both the store result and
  `PlayerProgress.apply_shop_purchase()` succeed, immediately before or with the success dialog.
- If the Shop reward contains coins, layer one `coin_gain` cue with the success cue. Ability-only
  bundles receive only the success cue in this ticket.
- Do not add a purchase-failure sound; it is outside the approved event scope.

### 6. Wire Reward-Chest Arrivals

Update the main-menu reward animation so `reward_chest_star_arrival` plays from the same accepted
arrival callback that advances the visible chest count and starts its receive pulse.

- Use a small variant pool or bounded pitch sequence for consecutive stars.
- Apply a cooldown/concurrency policy that preserves the authored stagger without clipping or
  excessive stacking.
- When an arrival crosses a chest goal and grants coins, layer `coin_gain` once for the completed
  goal. Do not add a separate chest-complete sound in this ticket.
- Do not play arrival audio when the menu simply reconciles its displayed count to saved progress.

### 7. Wire Shared UI Clicks

Provide one reusable policy for enabled `BaseButton` actions across authored scenes and runtime
buttons.

- Play on accepted `pressed`, not raw pointer-down, so a cancelled release does not click.
- Disabled buttons and controls that never emit `pressed` remain silent.
- Avoid double playback when a button is rebound, reparented, pooled, or observed by more than one
  scene owner.
- Allow a node metadata flag or focused component property to suppress the generic click where a
  future feature owns a complete replacement cue.
- The generic click may layer with delayed semantic feedback such as Shop success, but it must not
  layer twice with another generic button owner.
- Retapping a documented no-op active destination tab should remain silent. If a global button
  binder cannot know whether an action is a no-op, mark those active buttons silent explicitly.
- Handle the sound-effects toggle deliberately: switching Off may acknowledge the accepted press
  before muting; switching On may acknowledge it immediately after enabling. Other settings toggles
  use the normal click.

## Asset and Mix Guidelines

- Keep the palette friendly, tactile, warm, and toy-like; avoid casino-heavy reward sounds, harsh
  alarms, realistic gun-like impacts, or long cinematic tails.
- UI clicks and timer ticks must remain quieter than gameplay matches and currency confirmations.
- No cue in this ticket should exceed approximately 750 ms.
- Use mono assets unless a strong technical reason for stereo is documented. Let the game mix place
  short UI/gameplay transients centrally.
- Keep random pitch changes subtle enough that event identity and musical relationships remain
  stable.
- Test worst-case layering: a placement causing a match, match stars reaching the HUD, critical timer
  ticking, and a button opening an overlay within a short interval.

## Acceptance Criteria

- All eleven approved event IDs have a documented catalog entry and an audible implementation.
- Every new source WAV is reproducible from the committed Godot generator and passes the documented
  PCM, peak, fade, and duration constraints.
- `item_place.wav` and `triple_clear.wav` remain the source recordings for their existing roles.
- Rapid valid placements and matches can overlap within their limits without cutting off the most
  recent cue.
- Invalid item returns do not play `item_place_valid`.
- Critical ticks follow the HUD's existing threshold/pulse, stop while frozen or paused, and do not
  continue after time-up.
- Time-up plays once per accepted expiry.
- Coin gain/spend cues occur only after successful semantic mutations and never on initial balance
  display or failed operations.
- Shop success plays only after rewards are actually granted.
- Reward-chest arrivals remain clear during a multi-star flight and play no audio during silent state
  reconciliation.
- Enabled accepted buttons play exactly one generic click unless explicitly suppressed; disabled,
  cancelled, and documented no-op actions remain silent.
- Turning SFX off silences every event in this ticket across gameplay and menus and stops active
  cues; the saved setting continues to work after scene changes and restart.
- No gameplay timing, rewards, prices, progression, save schema, Shop provider, backend protocol, or
  responsive layout changes.

## Verification

Add automated coverage for:

- Generator determinism, expected output list, sample rate, encoding, duration, non-empty PCM data,
  peak ceiling, and bounded DC offset.
- Catalog completeness and missing-stream behavior.
- Player-pool reuse, event polyphony, cooldowns, variation selection, and no immediate-repeat policy.
- Global mute, immediate stop on disable, persistence across scenes, and re-enable behavior.
- Valid placement versus invalid-return routing.
- Match and HUD-star synchronization.
- Critical threshold entry, per-second ticking, final-five accent, pause, Freezer, time-up, and
  terminal-state suppression.
- Successful and rejected coin mutations, Shop grants, duplicate transactions, weekly rewards, and
  chest-goal rollover.
- Runtime/authored button discovery without duplicate connections; disabled, cancelled, suppressed,
  and active-tab no-op cases.

Run the relevant existing gameplay, UI, Shop, save, Hammer, Freezer, and Lantern tests after the
audio refactor. Tests that do not evaluate audio should run with SFX muted and must not depend on an
audio device.

Perform an audible manual pass at normal device volume through:

1. item selection, valid movement, invalid return, triple clear, and star arrival;
2. the complete critical countdown with pause/resume, Freezer activation/expiry, time extension,
   and terminal time-up;
3. ability, time-extension, and life coin spending;
4. successful coin-pack and bundle purchases;
5. multi-star main-menu chest flights including a goal rollover; and
6. Main Menu, Chapter Selection, Shop, Leaderboard, profile, settings, pause, result, and modal
   buttons.

Verify on desktop plus at least one Android build because short transient balance and device-volume
behavior can differ from desktop output.

## Documentation Updates

When implemented, update:

- `docs/SCRIPTS.md` with the generator, SFX manager, catalog, and event owners.
- `docs/SCENES.md` with scene-owned audio hooks where they affect component ownership.
- `docs/PROJECT_MAP.md` with the global SFX path, bus, assets, and common change guide.
- This ticket with the final regeneration command, implemented asset list, validation results, and
  completion status.

## Out of Scope

- Generated or externally recorded audio.
- Shelf-lock progress and unlock sounds.
- Level-complete, level-failed, and out-of-lives stingers.
- Dedicated Hammer recordings or any Shuffle, Lantern, or Freezer sound set.
- Purchase-failure, invalid-action, navigation, modal, pager, profile, chapter-unlock, life-restored,
  moving-shelf, dispenser, layer-promotion, combo, or background ambience sounds.
- Music, music transitions, vibration/haptics, voice, spatial audio, analytics, monetization changes,
  economy changes, save-schema changes, or backend work.

