"""Prepare the supplied Corner Shop WAV as a looping Vorbis stream (standard library + FFmpeg).

The first play retains the intro. A phase-aligned crossfade replaces the outro with the matching
earlier phrase, then Godot's native decoder loops to the end of that earlier phrase.
See docs/LEVEL_MUSIC.md for the selected boundaries and the separate runtime gain policy.
"""

import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import wave

SOURCE_SHA256 = "64baea9e2f3211a161264d0505fd6ccd42f292632065eab95a183c4e1e01be59"
RATE = 48000
CHANNELS = 2
LOOP_OFFSET = 22.32
END_SECONDS = 149.08
CROSSFADE_SECONDS = 2.0
SOURCE_GAIN_DB = -4.0


def run(ffmpeg, *args):
    result = subprocess.run([ffmpeg, "-hide_banner", "-nostats", "-nostdin", *args],
                            capture_output=True, check=True)
    return result.stderr.decode("utf-8", errors="replace")


def measure(ffmpeg, path):
    filters = ("[0:a]asplit=3[a][b][c];"
               "[a]loudnorm=I=-24:LRA=7:TP=-3:print_format=json[ao];"
               "[b]volumedetect[bo];"
               "[c]ebur128=peak=true:framelog=verbose[co]")
    log = run(ffmpeg, "-loglevel", "verbose", "-i", str(path), "-filter_complex", filters,
              "-map", "[ao]", "-map", "[bo]", "-map", "[co]", "-f", "null", "-")
    def value(pattern):
        match = re.search(pattern, log)
        if not match:
            raise ValueError(f"Missing FFmpeg meter value: {pattern}")
        return round(float(match.group(1)), 2)
    return {
        "integrated_lufs": value(r'"input_i"\s*:\s*"([^\"]+)"'),
        "true_peak_dbtp": value(r'"input_tp"\s*:\s*"([^\"]+)"'),
        "rms_dbfs": value(r'mean_volume:\s*([-\d\.]+) dB'),
        "sample_peak_dbfs": value(r'max_volume:\s*([-\d\.]+) dB'),
        "max_m_lufs": round(max(float(m.group(1)) for m in
                                   re.finditer(r'\bM:\s*(-?\d+(?:\.\d+)?)', log)), 2),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--output-dir", type=Path,
                        default=Path(__file__).resolve().parents[2] / "assets/audio/music")
    args = parser.parse_args()
    source_hash = hashlib.sha256(args.source.read_bytes()).hexdigest()
    if source_hash != SOURCE_SHA256:
        parser.error("These loop boundaries are specific to the reviewed Corner Shop WAV.")
    with wave.open(str(args.source)) as original:
        if (original.getframerate(), original.getnchannels(), original.getsampwidth()) != (RATE, CHANNELS, 2):
            parser.error("Expected the supplied stereo 48 kHz / 16-bit PCM WAV.")
        original_duration = original.getnframes() / RATE
    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / "corner_shop_sorting_loop.ogg"
    with tempfile.TemporaryDirectory(prefix="sorting-puzzle-music-") as scratch:
        raw_path = Path(scratch) / "filtered.f32"
        run(args.ffmpeg, "-loglevel", "error", "-i", str(args.source), "-map", "0:a:0",
            "-af", f"highpass=f=20,volume={SOURCE_GAIN_DB}dB", "-ar", str(RATE),
            "-ac", str(CHANNELS), "-t", str(END_SECONDS), "-f", "f32le", str(raw_path))
        samples = array.array("f", raw_path.read_bytes())
        if sys.byteorder != "little":
            samples.byteswap()
        total_frames = round(END_SECONDS * RATE)
        overlap_frames = round(CROSSFADE_SECONDS * RATE)
        early_start = round((LOOP_OFFSET - CROSSFADE_SECONDS) * RATE)
        late_start = total_frames - overlap_frames
        if len(samples) != total_frames * CHANNELS:
            raise ValueError("FFmpeg did not produce the requested sample count.")
        for frame in range(overlap_frames):
            incoming = 0.5 - 0.5 * math.cos(math.pi * frame / (overlap_frames - 1))
            for channel in range(CHANNELS):
                late = (late_start + frame) * CHANNELS + channel
                early = (early_start + frame) * CHANNELS + channel
                samples[late] = samples[late] * (1 - incoming) + samples[early] * incoming
        if sys.byteorder != "little":
            samples.byteswap()
        raw_path.write_bytes(samples.tobytes())
        run(args.ffmpeg, "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(RATE),
            "-ac", str(CHANNELS), "-i", str(raw_path), "-c:a", "libvorbis", "-q:a", "5",
            "-metadata", "title=Corner Shop Sorting Loop", "-metadata", "artist=borealsail",
            str(output))
    measurement = measure(args.ffmpeg, output)
    if measurement["true_peak_dbtp"] > -3.0:
        raise ValueError("Decoded Vorbis exceeds the music source's -3 dBTP ceiling.")
    manifest = {
        "schema_version": 1,
        "source_file": args.source.name,
        "source_sha256": source_hash,
        "source_duration_seconds": original_duration,
        "path": "res://assets/audio/music/corner_shop_sorting_loop.ogg",
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "file_size_bytes": output.stat().st_size,
        "sample_rate": RATE,
        "channels": CHANNELS,
        "vorbis_quality": 5,
        "duration_seconds": END_SECONDS,
        "loop_offset_seconds": LOOP_OFFSET,
        "loop_period_seconds": round(END_SECONDS - LOOP_OFFSET, 3),
        "crossfade_seconds": CROSSFADE_SECONDS,
        "crossfade_curve": "raised cosine, complementary gains",
        "highpass_hz": 20,
        "source_gain_db": SOURCE_GAIN_DB,
        "decoded_measurements": measurement,
    }
    (args.output_dir / "corner_shop_sorting_loop.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
