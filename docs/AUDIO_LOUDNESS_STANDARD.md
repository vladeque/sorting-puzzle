# Sound-Effect Loudness Standard

## Scope

This is the required authoring, measurement, cataloguing, and verification standard for every
sound effect in `assets/audio/`. It applies to new cues, replacements, derivatives, and changes to
catalog gain. Music and voice require their own mix policies before they are introduced.

The machine-readable values live in `scripts/audio/sfx_loudness_standard.gd`. The human-readable
document and that script must change together.

## Measurement terms

- **LUFS-M / maximum momentary loudness:** the loudest K-weighted 400 ms window. This is the primary
  balance measurement for short game cues.
- **LUFS-I / integrated loudness:** the K-weighted average over the entire file or captured mix.
  Use it for stingers, long beds, and representative gameplay captures, not as the sole criterion
  for a click or impact.
- **dBTP / true peak:** an oversampled estimate of the continuous waveform peak. Use it to protect
  the signal path from intersample clipping; it does not describe perceived loudness.
- **LU:** a relative loudness difference. A gain change of 1 dB changes a steady measurement by
  approximately 1 LU.

Measurements must use an ITU-R BS.1770 compliant meter. The current standard is
[ITU-R BS.1770-5](https://www.itu.int/rec/R-REC-BS.1770). For a cue shorter than 400 ms, append
silence to exactly one 400 ms measurement window; never loop or stretch the cue to obtain a value.
Measure decoded audio, so lossy codec overs are included.

Do not use Loudness Range for individual SFX. EBU R128s1 explains that LRA is not meaningful for
short-form material and identifies integrated loudness, short-term loudness, and true peak as the
useful descriptors. Its -23 LUFS programme target, -18 LUFS maximum short-term value, and -1 dBTP
ceiling are distribution references, not per-SFX targets for this game:
[EBU R128s1](https://tech.ebu.ch/docs/r/r128s1.pdf).

## Project targets

The complete representative gameplay mix targets **-18 LUFS-I**, with **-20 to -16 LUFS-I** an
acceptable range across level types, and must remain at or below **-1 dBTP**. AES uses -18 LUFS as
an overall-content normalization reference when there is no reliably measurable anchor element:
[AES loudness normalization guidance](https://aes2.org/resources/audio-topics/loudness-project/loudness-normalization/).

Individual events use maximum momentary loudness after `volume_db` and any per-stream correction:

| Class | Normal play target | Typical content |
| --- | ---: | --- |
| `ui_micro` | -34 to -30 LUFS-M | navigation and ordinary button clicks |
| `interaction_micro` | -32 to -27 LUFS-M | item selection and placement |
| `gameplay_feedback` | -29 to -24 LUFS-M | timer ticks, small arrivals, blocked actions |
| `reward_confirmation` | -22 to -17 LUFS-M | matches, currency, purchases, unlocks |
| `ability_warning` | -19 to -16 LUFS-M | abilities and prominent warnings |
| `terminal_stinger` | -17 to -15 LUFS-M | completion, failure, and time-up |

The class's `burst_ceiling_lufs` in the machine-readable standard additionally limits random gain
and count scaling. It is not a target to hit.

## Peak policy

- New or re-exported source files should stay at or below **-3 dBTP**.
- **-1 dBTP is the absolute source-file ceiling.** A file above it must not be added to the catalog.
- Routine runtime one-shots should normally remain at or below **-6 dBTP** after catalog gain.
- A rare major ability or terminal stinger may approach **-3 dBTP**, but only after the overlap
  scenarios pass and the limiter is not audibly pumping.
- Master always carries an enabled hard limiter with a **-1 dB ceiling**. The limiter is emergency
  protection, not a way to make an overdriven mix compliant. Godot recommends a Master-bus limiter
  as protection against sudden summed peaks:
  [AudioEffectHardLimiter](https://docs.godotengine.org/en/stable/classes/class_audioeffecthardlimiter.html).

## Variant and catalog policy

- Variants in one event must be within **1 LU** after `stream_volume_offsets_db` and before random
  `volume_variation_db`.
- Use `volume_db` for the event's position in the hierarchy.
- Use `stream_volume_offsets_db` only to correct differences inside a variant pool.
- Random volume variation must remain subtle and must not push the event beyond its class's burst
  ceiling.
- Do not enable Godot import normalization. Peak normalization does not equalize perceived
  loudness and destroys the catalog's explicit gain model.
- Do not normalize every source to the same LUFS or peak. Transient shape, frequency, duration,
  repetition rate, and semantic importance are intentionally different.

## Required overlap scenarios

Measure both the pre-limiter mix and the Master output for these deterministic cases:

1. item placement + match clear + maximum count-scaled HUD star arrival;
2. a critical-timer tick + each ability cue, using the loudest result;
3. purchase success + coin gain;
4. time-up + level failure transition;
5. the maximum declared polyphony of any changed repeating event.

The pre-limiter mix should not exceed 0 dBTP. Master must not exceed -1 dBTP. A scenario that
drives sustained limiter reduction must be rebalanced even when its limited peak technically
passes.

## Adding or changing an SFX

1. Put the source under `assets/audio/<event>/` and keep the original lossless file when available.
2. Remove DC offset and use short edge fades where the cue permits.
3. Measure decoded maximum LUFS-M, integrated LUFS-I, sample peak, and dBTP.
4. Correct source true peak before using catalog gain. Do not solve a clipped file by turning down
   only the runtime player.
5. Add the semantic event or stream to `scripts/audio/sfx_catalog.gd`, including a required
   `loudness_class` and any variant-only `stream_volume_offsets_db`.
6. Run the loudness audit and update its committed measurement snapshot. A changed file hash with
   old measurements is invalid.
7. Run all audio tests and all required overlap scenarios.
8. Listen on a low-end phone speaker, a modern phone, earbuds, and headphones at fixed system
   volume. Meter compliance does not replace this listening check.
9. Update `docs/SCRIPTS.md` when ownership, tooling, or behavior changes.

## Current implementation boundary

`scripts/audio/sfx_manager.gd` is the sole runtime playback owner. All players route to the `SFX`
bus, which sends to Master. `assets/audio/default_bus_layout.tres` owns the Master limiter;
individual scenes must not add private limiters or bypass `SfxManager`.
