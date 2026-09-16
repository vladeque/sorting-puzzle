# AUDIO-001 — Implement Godot-Authored Core Sound Effects

**Status:** Implemented (see "Implementation Record" at the end; the audible manual pass and the
Android device check are still outstanding)

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
| `item_place_valid` | An item completes an accepted landing. | Retain `assets/audio/item_place_valid/item_place.wav`; add safe pitch/volume variation and polyphonic playback. |
| `match_clear` | A matched triple finishes gathering and begins disappearing. | Retain `assets/audio/match_clear/triple_clear.wav`; replace the current stop/restart playback with polyphonic playback. |
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

The tool must generate project-owned WAV files in event-named directories under:

```text
assets/audio/<event>/
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
  (Done — see "Regeneration command" under "Implementation Record".)

Current generated palette:

- `item_select_01..03.wav`: 40–75 ms, slightly rounder and brighter than `ui_click`.
- `time_up.wav`: 300–600 ms, decisive but not harsh or horror-coded.
- `coin_gain.wav`: 300–650 ms ascending metallic sequence.
- `coin_spend.wav`: 180–350 ms descending metallic sequence.

The runtime now uses an authored 30-second `timer_tick.wav` bed and authored
`purchase_successful.wav` confirmation. The UI-click and star-arrival pools are also authored
recordings. None are generator outputs. Do not synthesize replacements for `item_place.wav` or
`triple_clear.wav` in this ticket.

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

- All approved event IDs have a documented catalog entry and an audible implementation.
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


## Implementation Record

**Completion status:** Implemented. Every required section is in place and the automated coverage
below passes. The audible manual pass and the Android device check listed under "Verification"
remain outstanding and must be done by a human before this ticket is closed.

### Regeneration command

```powershell
& 'D:\Godot\godot.exe' --headless --path . --script res://scripts/tools/generate_core_sfx.gd -- --regenerate
& 'D:\Godot\godot.exe' --headless --path . --import
```

The second command re-imports the regenerated WAVs. A generation without an import leaves the
catalog pointing at stale audio. Omit `--regenerate` for a normal run: the generator refuses to
overwrite outputs whose `generated_sfx_manifest.json` records a different generator version, or WAV
files with no manifest at all.

Options after the `--` separator:

- `--regenerate`: allow replacing outputs recorded under a different generator version.
- `--output-dir=<res path>`: write the event-directory tree and manifest under another root instead
  of `res://assets/audio`.

### Implemented files

Owners:

- `scripts/audio/sfx_manager.gd` — the `SfxManager` autoload: pooled players, per-event cooldown and
  polyphony, variant selection, mute paths, `SFX` bus routing.
- `scripts/audio/sfx_catalog.gd` — the one event catalog for every approved event.
- `scripts/audio/ui_click_binder.gd` — the single generic `ui_click` policy for every `BaseButton`.
- `scripts/tools/generate_core_sfx.gd` — the generator CLI (overwrite guard, manifest, report).
- `scripts/tools/core_sfx_synthesis.gd` — deterministic synthesis, the cue table, and the WAV encoder.
- `assets/audio/default_bus_layout.tres` — `Master` plus a dedicated `SFX` bus, referenced from
  `project.godot`'s `audio/buses/default_bus_layout`.

Wiring:

- `scripts/level.gd`, `scripts/level_top_hud.gd` (new `critical_second_pulsed` signal),
  `scripts/pause_menu.gd`, `scripts/shop_screen.gd`, `scripts/production_main_menu.gd`,
  `scripts/main_menu_bottom_navigation.gd`, `scripts/player_progress.gd` (new read-only
  `get_reward_chest_goal_coin_reward_at_index()`), `scripts/tools/capture_scene.gd` (capture mute).

Tests:

- `tests/audio/test_core_sfx_assets.gd`, `tests/audio/test_sfx_manager.gd`,
  `tests/audio/test_sfx_event_wiring.gd`.

### Generated asset list

Generator version `1.1.0`. Generated files are mono 16-bit PCM at 44 100 Hz in their matching
`assets/audio/<event>/` directories, imported with `compress/mode=0` (uncompressed PCM). Measured
peaks are the authored relative loudness, not a loudness match; every one is at or under the -1 dBFS
ceiling. `assets/audio/generated_sfx_manifest.json` owns only the generated paths.

| File | Duration | Peak | DC offset |
| --- | --- | --- | --- |
| `item_select_01.wav` | 55.0 ms | -14.00 dBFS | +0.00007 |
| `item_select_02.wav` | 62.0 ms | -14.50 dBFS | +0.00003 |
| `item_select_03.wav` | 48.0 ms | -13.50 dBFS | +0.00011 |
| `time_up.wav` | 520.0 ms | -4.00 dBFS | -0.00005 |
| `coin_gain.wav` | 520.0 ms | -5.00 dBFS | -0.00000 |
| `coin_spend.wav` | 285.0 ms | -7.00 dBFS | +0.00000 |

`assets/audio/item_place_valid/item_place.wav` and
`assets/audio/match_clear/triple_clear.wav` are unchanged and remain the source recordings for
`item_place_valid` and `match_clear`. No replacements were synthesized for them.
All other catalog streams not listed in the generated table are authored source cues and are not
overwritten by the generator.

### Event catalog

| Event ID | Streams | Trim | Pitch window | Cooldown | Max polyphony |
| --- | --- | --- | --- | --- | --- |
| `item_select` | `item_select_01..03` | -1.0 dB ±0.5 | 0.97–1.03 | 35 ms | 3 |
| `item_place_valid` | `item_place.wav` | -5.0 dB ±1.0 | 0.95–1.05 | 20 ms | 4 |
| `match_clear` | `triple_clear.wav` | -5.0 dB ±0.5 | 0.97–1.03 | 20 ms | 3 |
| `star_hud_arrival` | `star_hud_arrival.wav` | -2.0 dB | 0.99–1.01 | 90 ms | 2 |
| `timer_critical_tick` | `timer_tick.wav` | -3.0 dB | none | none | 1 |
| `time_up` | `times_up2.mp3` | -1.0 dB | none | 750 ms | 1 |
| `coin_gain` | `coin_gain.wav` | -1.0 dB | 0.995–1.005 | 200 ms | 2 |
| `coin_spend` | `coin_spend.wav` | -2.0 dB | 0.995–1.005 | 150 ms | 2 |
| `shop_purchase_success` | `purchase_successful.wav` | +2.0 dB | none | 600 ms | 1 |
| `reward_chest_star_arrival` | `star_hud_arrival.wav` | -3.0 dB ±0.6 | 0.98–1.04 | 50 ms | 3 |
| `ui_click` | `ui_click_01..03` | -2.0 dB ±0.4 | 0.97–1.03 | 40 ms | 3 |

`star_hud_arrival` additionally carries count scaling (+0.9 dB and +0.012 pitch per extra star,
capped at +3.0 dB and 1.05), so a multi-star combo is one bigger arrival rather than one cue per
star.

The reward-chest event currently trials that same authored recording with its own per-star cooldown
and polyphony policy. The three prior chest variants remain committed as inactive comparison assets.

The later Time Up transition replaced the runtime stream with the supplied authored
`assets/audio/time_up/times_up2.mp3`. The original `time_up.wav` remains listed in the generated
asset table above because the deterministic generator still owns and verifies that artifact; the
catalog intentionally no longer references it.

### Validation results

Automated, all through `scripts/tools/run_isolated_godot_test.ps1`:

- `tests/audio/test_core_sfx_assets.gd` — **passed.** Generator determinism (two in-process renders
  byte-identical), committed WAVs byte-identical to a fresh render, manifest contents, and per-file
  mono/16-bit/44.1 kHz encoding, non-empty PCM, ticket duration windows, the -1 dBFS ceiling, the
  authored per-cue peak, bounded DC offset, and edge fades landing on silence. Also catalog
  completeness (all catalog events, every stream importable), the two retained source recordings,
  and no orphan audio assets.
- `tests/audio/test_sfx_manager.gd` — **passed.** `SFX` bus present and sending to `Master`, all
  pooled players routed to it, pool reuse across 40 rapid plays, per-event polyphony with the newest
  cue surviving a burst, cooldown rejection, no immediate variant repeat, unknown-event and
  missing-stream safety, bounded count scaling, global mute stopping active cues, the saved setting
  gating every request and stopping active cues on disable, owner identity and setting behavior
  across a scene change, and the button-click policy (single binding across reparenting, exactly one
  click per accepted press, silence for disabled/hidden/suppressed buttons).
- `tests/audio/test_sfx_event_wiring.gd` — **passed.** Accepted landings versus silent invalid
  returns and silent forced restores; `item_select` only on a finished selecting tap; critical-timer
  entry, per-second ticking, no repeat inside one displayed second, no tick above the threshold, no
  tick while not counting down, no tick while frozen, the final-five pitch accent, and no ticking
  after a terminal state; one `time_up` per accepted expiry with no replay on re-entry or modal
  refresh; `coin_spend` on a successful time extension and silence when it cannot be afforded; Shop
  routing for granted coins, ability-only bundles, and duplicate transactions; and reward-chest
  arrivals with goal-rollover `coin_gain` versus silent state reconciliation.

Existing suites re-run after the refactor (all `tests/**/test_*.gd`, plus
`scenes/shop_verification.tscn` and `scenes/leaderboard_verification.tscn`): gameplay, UI, Shop,
save, Hammer, Freezer, and Lantern coverage all pass. Four pre-existing failures are unrelated to
audio and were failing before this work: `tests/backend/test_game_007.gd` and
`tests/backend/test_game_010.gd` need `../sorting-puzzle-backend/contracts/fixtures/`, which the
isolated scratch project cannot reach; `tests/save/test_game_001.gd` and `tests/save/test_game_002.gd`
fail on a stale `configs/backend/content_provenance.json` (21 of its 29 tracked config files have
drifted since it was published).

Visual check: `scripts/tools/capture_ui.ps1 -Scene scenes/main_menu.tscn` renders unchanged, as
expected — this ticket changed no layout.

### Still outstanding

- The audible manual pass through all six listed flows, at normal device volume.
- The Android build check for short-transient balance and device-volume behavior.
