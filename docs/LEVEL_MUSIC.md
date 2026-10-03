# Level soundtrack

`MusicManager` is a scene autoload registered after `PlayerProgress` in `project.godot`.
`scenes/audio/music_manager.tscn` instances one `scenes/audio/level_soundtrack.tscn` player, which
owns the stream, background mix trim, and `Music` bus routing. `scripts/audio/music_manager.gd`
owns the playback lifecycle. The listening preview reuses that same player scene.

## Listen to the loop

Open `scenes/testing/music_loop_preview.tscn` in Godot and run the current scene with **F6**.
Or launch it from PowerShell at the repository root, with disposable user data:

```powershell
& .\scripts\tools\preview_level_music.ps1
```

Press **Play loop seam** to begin five seconds before the end. Listen through the crossfade and
the native wrap to 00:22.32. The countdown changes to **Loop passed — music continues**, and the
loop counter increments. Press **Play loop seam** again to repeat that listening window.
**From beginning** includes the intro; **Pause/Resume** preserves position; **Stop** ends playback.
The preview waits for a Play press and uses the game's actual player resource and mix gain.

`scripts/testing/music_loop_preview.gd` owns only the developer preview's transport and display.
Its independent player lets it play with the saved Music setting Off and leaves the paused game
autoload's position unchanged. Preview buttons suppress generic clicks so the soundtrack can be
heard alone. No preferences or progress are written by preview controls. Closing the window ends
the isolated launcher and cleans up its disposable project/save.

`tests/audio/test_music_loop_preview.gd` verifies native loop confirmation, shared stream/gain,
pause/resume/stop, silent controls, and unchanged saved settings/progression. Capture the ready
screen with `capture_ui.ps1 -Scene scenes/testing/music_loop_preview.tscn -Name music_loop_preview`.
For the post-wrap state and an expanded tablet viewport, also pass
`-Setup scripts/tools/captures/music_loop_preview_setup.gd`. The setup mutes the bus, listens through
one actual native wrap, and freezes its display for screenshots.

## Playback behavior

Music starts only when the current scene permits it through
`scripts/level.gd::is_background_music_allowed()`. The gate is open on a valid, active level,
including the time before the player's first move. It closes during loading, gameplay pause,
in-level modal pauses, failure, completion, leaving, and application suspension. A SceneTree pause
or a disabled outgoing scene also closes playback. Freezer's countdown freeze does not close the
gate: gameplay remains interactive while that ability is active.

The autoload starts its decoder once per application session. Every subsequent suspension uses
`stream_paused`; no level owns, recreates, stops, or seeks the player. Restart, next level, and
returning from the silent main menu resume the same position after loading. The saved Music toggle
also pauses/resumes that decoder. Sound Effects and Music remain independent preferences and buses.
`scripts/pause_menu.gd` refreshes playback immediately after the Music button changes the existing
saved setting; the manager's frame check also observes preferences restored by existing save flows.

Headless runs start muted. `set_muted()` provides an independent capture/test gate, and
`scripts/tools/capture_scene.gd` mutes music explicitly in its windowed captures.

## Supplied recording and loop preparation

- Source: the supplied `Corner Shop Sorting Loop.wav`, artist metadata `borealsail`; stereo,
  48 kHz, 16-bit PCM, 167.893 seconds, 33,088,542 bytes.
- Runtime derivative: `assets/audio/music/corner_shop_sorting_loop.ogg`, stereo 48 kHz Vorbis,
  quality 5, 149.08 seconds, 2,691,575 bytes. The original file in the supplied Downloads location
  is unchanged; the shipping project contains the prepared compressed derivative.
- The original has a quiet intro and a fade-out rather than a continuous full-file loop.
  Matching phrase windows at 20.32-22.32 seconds and 147.08-149.08 seconds were selected by their
  harmonic and onset correspondence. The last two seconds blend into the earlier phrase using
  complementary raised-cosine gains. The faded outro is omitted. No tempo or pitch change is applied.
- The first play starts at zero and retains the intro. Godot's imported native loop is enabled
  with `loop_offset=22.32`, giving a 126.76-second repeat. The incoming phrase is already heard in
  the crossfade, so playback resumes at its end rather than repeating the crossfade or intro.
- A 20 Hz high-pass removes the source's DC/very-low-frequency offset, and a -4 dB source trim
  provides headroom before Vorbis encoding. Normalization and dynamic compression are not applied.
- `assets/audio/music/corner_shop_sorting_loop.json` records the original and derivative hashes,
  preparation parameters, and decoded loudness measurements. The derivative is also included in
  the existing complete audio inventory at `assets/audio/sfx_loudness_measurements.json`.

Rebuild from the original lossless source with standard Python and FFmpeg (with `libvorbis`):

```powershell
python scripts/tools/prepare_level_music.py `
  --source 'C:\Users\vlad\Downloads\stock_assets\music\Corner Shop Sorting Loop.wav' `
  --ffmpeg 'C:\path\to\ffmpeg.exe'
```

The tool rejects a different source hash because these boundaries are specific to this recording.
After rebuilding, reimport in Godot and refresh the complete audio measurement snapshot using
`scripts/tools/audit_sfx_loudness.ps1 -UpdateSnapshot`. The committed `.ogg.import` owns native
looping and its offset; re-exporting an Ogg alone does not replace those settings.

## Music mix policy

This policy is separate from the semantic SFX classes in `docs/AUDIO_LOUDNESS_STANDARD.md`:

- Decoded music sources must remain at or below -3 dBTP.
- Runtime background music targets -27 LUFS-I, with -29 to -25 LUFS-I allowed.
- Preserve the source's musical dynamics. Use scene-authored `AudioStreamPlayer.volume_db` for
  mix placement; do not boost the track into the SFX reward/ability hierarchy.
- Route Music through Master and its existing -1 dB ceiling limiter. The limiter remains final
  protection rather than normal loudness control. Check the combined music/SFX sum after a gain
  or recording change, including the existing required SFX overlap cases.

The current decoded Ogg measures -19.78 LUFS-I, -15.70 maximum LUFS-M, and -4.17 dBTP.
The scene's -7 dB trim yields -26.78 LUFS-I, -22.70 maximum LUFS-M, and -11.17 dBTP before Master.

## Verification

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/audio/test_music_manager.gd
```

The integration test uses actual level/menu/pause scenes and the native decoder. It verifies the
saved Music control, independence from Sound Effects, all pause gates, frozen playback position,
actual loading transitions on restart and next level, silent menu visits, and the prepared native
loop offset, with an actual Master-bus capture across the native wrap. Run the existing audio tests
after changing the shared bus layout or inventory.

The decoded join's sample step is -56.23 dBFS, within ordinary nearby waveform steps, and its
adjacent 200 ms windows contain sounding audio. Ten active-play music/SFX overlap cases remained
at or below -15.7 maximum LUFS-M and -3.44 dBTP before Master. A conservative timeout+failure
sum with continuous music reaches -13.5 LUFS-M; music is suspended in those terminal/pause states,
and the existing sum without music measures -14.0 LUFS-M. Keep that suspension when changing
result or time-extension behavior.

The older core-SFX asset audit currently fails on baseline data: `triple_clear3.wav` is absent
from its inactive-cue inventory and measurement snapshot, and `triple_clear.wav`'s committed hash
differs from its saved measurement hash. These mismatches also exist in Git HEAD before the music
change. The music-specific integration test and existing SFX playback/event-wiring tests pass.
Phone-speaker and headphone listening remain a device check when tuning the final subjective mix.
