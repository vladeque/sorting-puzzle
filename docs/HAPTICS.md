# Haptics

## Runtime ownership

`HapticsManager` is the global handheld-vibration owner. Gameplay and UI code request semantic
events from `scripts/haptics/haptics_catalog.gd`; no scene calls `Input.vibrate_handheld()`
directly. The manager owns:

- the saved device-local `vibration` preference;
- a separate capture/test mute;
- one active pattern at a time, with priority replacement;
- per-event cooldowns that prevent concurrent shelf resolution from stacking pulses;
- multi-pulse timing and bounded count-based match strength;
- a replaceable provider for tests or a future native Android/iOS haptics bridge;
- Godot's `Input.vibrate_handheld(duration_ms, amplitude)` as the mobile/Web fallback.

Headless runs start muted. `tests/haptics/test_haptics_manager.gd` injects a recording provider, so
tests verify exact durations and amplitudes without accessing real hardware. The Android debug
export enables `permissions/vibrate=true`.

## Event policy

The game vibrates only for semantic state changes. It does not mirror the global UI click policy,
critical timer ticks, moving shelves, passive life restoration, back-layer promotion, or individual
reward-star arrivals.

| Event | Fallback pattern |
| --- | --- |
| Item selection / drag pickup | 16 ms at 0.18 |
| Accepted move landing | 22 ms at 0.27 |
| Sticky resistance | 32 ms at 0.34, 280 ms cooldown |
| Triple clear | 40 ms at 0.44; folded count may add at most 0.10 |
| Shelf unlock | 18 ms at 0.28, then 34 ms at 0.43 after 42 ms |
| Hammer | 65 ms at 0.70 |
| Shuffle | 22 ms at 0.34, then 22 ms at 0.28 after 35 ms |
| Lantern | 28 ms at 0.30 |
| Freezer | 42 ms at 0.40 |
| Recoverable time-up | 32 ms at 0.38, then 65 ms at 0.55 after 65 ms |
| Time extension / life purchase | 34 ms at 0.40 |
| Level complete | 22 ms at 0.32, then 50 ms at 0.52 after 45 ms |
| Level failed | 45 ms at 0.42, then 70 ms at 0.58 after 55 ms |
| Shop purchase | 22 ms at 0.34, then 48 ms at 0.50 after 45 ms |
| Chest goal / weekly reward | 20 ms at 0.30, then 42 ms at 0.46 after 40 ms |
| Vibration setting preview | 20 ms at 0.25 |

Every pulse is at most 70 ms and 0.75 amplitude. Terminal results, settings, Hammer, time-up, and
purchase outcomes outrank routine selection/placement feedback. A higher-priority request cancels
the queued remainder of a lower-priority pattern; a lower-priority request is dropped while the
important pattern is active.

## Wiring

- `scripts/level.gd`: selection, pickup, accepted landing, sticky refusal, triple clear, shelf
  unlock, all four abilities, time-up, successful time extension/life purchase, completion, and
  failure.
- `scripts/shop_screen.gd`: one success pattern only after a transaction grant is applied.
- `scripts/production_main_menu.gd`: life purchase, reward-chest goal rollover, and weekly reward.
- `scripts/pause_menu.gd`: setting preview after enabling, or one forced final preview after
  disabling.

Paid immediate abilities intentionally do not add a coin-spend haptic: the ability effect is the
physical confirmation. Shop coin gain similarly layers audio but not a second vibration. Same-slot
tap landings keep their current landing animation/audio but do not vibrate because no logical move
occurred; rejected ordinary drops also stay vibration-free.

## Physical-device verification

Automated tests establish event policy and fallback timing, not physical feel. Before release, tune
on at least one current iPhone, a Pixel-class phone, a Samsung phone, and a lower-cost Android phone
with a basic ERM motor. Confirm that system vibration settings are respected and that short pulses
remain distinguishable; devices without amplitude control may map every non-zero amplitude to a
similar strength. A future native bridge should retain the semantic event ids and map them to
platform-tuned selection, impact, success, and warning effects.
