# SFX Loudness Audit

## Baseline

Date: 2026-09-18

This baseline covers all 30 committed audio files and all 19 semantic runtime events (23 runtime
streams including variants). The authoritative per-file measurements and SHA-256 hashes are in
`assets/audio/sfx_loudness_measurements.json`; a normal loudness-audit run fails if an asset changes
without a reviewed snapshot update.

Measurements use FFmpeg's ITU-R BS.1770 `ebur128`/`loudnorm` meters. Clips shorter than 400 ms are
silence-padded to one momentary window. Runtime values below include catalog `volume_db` and
per-stream offsets but exclude random variation unless shown as a burst.

## Runtime results

| Event / variant | Class | Nominal max-M | Burst max-M | Runtime dBTP |
| --- | --- | ---: | ---: | ---: |
| `item_select_01` | interaction | -31.8 | -31.3 | -13.0 |
| `item_select_02` | interaction | -31.6 | -31.1 | -13.5 |
| `item_select_03` | interaction | -31.9 | -31.4 | -12.4 |
| `item_place_valid` | interaction | -27.3 | -26.3 | -12.2 |
| `match_clear` | reward | -22.0 | -21.5 | -4.5 |
| `star_hud_arrival` | gameplay | -24.9 | -21.9 | -13.6 |
| `timer_critical_tick` | gameplay | -28.6 | -28.6 | -6.9 |
| `time_up` | terminal | -17.0 | -17.0 | -9.0 |
| `coin_gain` | reward | -20.4 | -20.4 | -15.6 |
| `coin_spend` | reward | -20.5 | -20.5 | -9.0 |
| `shop_purchase_success` | reward | -19.0 | -19.0 | -8.1 |
| `reward_chest_star_arrival` | gameplay | -25.2 | -24.6 | -13.6 |
| `ui_click_01` | UI | -32.3 | -31.9 | -11.2 |
| `ui_click_02` | UI | -33.0 | -32.6 | -10.2 |
| `ui_click_03` | UI | -33.0 | -32.6 | -11.3 |
| `sticky_move_blocked` | gameplay | -24.2 | -24.2 | -9.4 |
| `shelf_unlock` | reward | -20.8 | -20.8 | -13.3 |
| `ability_hammer` | ability | -16.6 | -16.6 | -4.9 |
| `ability_shuffle` | ability | -18.8 | -18.8 | -7.8 |
| `ability_lantern` | ability | -18.8 | -18.8 | -9.8 |
| `ability_freezer` | ability | -18.5 | -18.5 | -4.4 |
| `level_complete` | terminal | -15.7 | -15.7 | -9.1 |
| `level_failed` | terminal | -16.3 | -16.3 | -10.7 |

Every nominal and burst result is inside its class range from `docs/AUDIO_LOUDNESS_STANDARD.md`.
The click variants now span 0.7 LU, below the one-LU limit.

The selected 2.0-second stereo Epidemic Sound cue replaces the synthesized `coin_gain` source.
Its original 96 kHz/24-bit PCM encoding is retained; the existing -2 dB catalog trim places it at
-20.4 LUFS-M with -15.6 dBTP runtime headroom, inside the reward-confirmation range.

The selected 300 ms mono cartoon gum-pop source replaces the earlier invalid-action recording for
`sticky_move_blocked`. Its catalog trim is -7.9 dB, retaining the event's -24.2 LUFS-M runtime
level while presenting a simpler, non-realistic blocked-item cue. The selected 1.2-second stereo
shelf-unlock cue replaces the earlier unlock recording. Its source was attenuated by 3.09 dB to
the -3 dBTP working ceiling, and its -10.3 dB catalog trim retains the event's -20.8 LUFS-M
runtime level.

## Source processing

The player selected transparent timer candidate A. Its timing, stereo layout, and tonal content are
unchanged. The processing uses gentle peak-linked compression (threshold 0.035, ratio 2.5:1,
10 ms attack, 150 ms release, knee 2), transparent gain, and a look-ahead limiter. The resulting
source is -31.6 LUFS-M and -9.9 dBTP; the catalog's +3 dB trim produces -28.6 LUFS-M and -6.9 dBTP.

Four authored WAVs previously had 0 dBFS sample peaks and positive decoded true peaks. They were
attenuated without EQ, saturation, time changes, or creative dynamics changes, then received equal
and opposite catalog compensation where needed:

| Source | Applied source gain | New source dBTP | Runtime max-M |
| --- | ---: | ---: | ---: |
| `ability_freezer/freeze.wav` | -3.56 dB | -3.00 | -18.5 |
| `ability_hammer/hammer.wav` | -3.07 dB | -3.00 | -16.6 |
| `level_failed/level_failed.wav` | -3.38 dB | -3.00 | -16.3 |
| `shelf_unlock/shelve_unlock.wav` | -3.09 dB | -3.00 | -20.8 |

No committed source now exceeds the -1 dBTP hard ceiling. The four repaired sources meet the
preferred -3 dBTP working ceiling.

## Required overlap results

These are offline pre-Master-limiter renders using the catalog gains, upper random variation,
maximum count scaling, cooldown spacing, and declared polyphony where applicable.

| Scenario | Max-M | Pre-limiter dBTP |
| --- | ---: | ---: |
| placement + match + maximum star arrival | -18.0 | -4.0 |
| timer + Hammer | -16.3 | -4.8 |
| timer + Shuffle | -18.3 | -6.5 |
| timer + Lantern | -18.3 | -6.1 |
| timer + Freezer | -18.2 | -4.1 |
| purchase + coin gain | -16.5 | -7.4 |
| time-up + failure transition | -14.0 | -6.6 |
| four placement voices | -21.7 | -11.2 |
| three match voices | -16.6 | -3.2 |
| three reward-arrival voices | -23.0 | -13.0 |
| three UI-click variants | -27.6 | -9.8 |

All scenarios stay at or below the -14 LUFS-M overlap ceiling and below 0 dBTP before the limiter.
The Master hard limiter remains enabled at -1 dB as emergency protection.

`match_clear` has one accepted advisory: its isolated runtime peak is -4.5 dBTP, above the routine
-6 dBTP preference but below the -3 dBTP major-transient ceiling. Its three-voice overlap remains
safe at -3.2 dBTP, so further peak reduction would sacrifice the intended match transient without
providing necessary headroom.

## Verification

Run:

```powershell
& .\scripts\tools\audit_sfx_loudness.ps1
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/audio/test_core_sfx_assets.gd
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/audio/test_sfx_manager.gd
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/audio/test_sfx_event_wiring.gd
```

The first command requires `ffmpeg` and `ffprobe` on `PATH`, or explicit `-FfmpegPath` and
`-FfprobePath` arguments. Physical-device listening remains required whenever a cue's sound or mix
position changes; the automated measurements do not replace that check.
