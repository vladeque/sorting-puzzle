extends SceneTree

## AUDIO-001 asset verification: the committed generated palette is still exactly what
## scripts/tools/generate_core_sfx.gd produces, it satisfies the ticket's PCM/peak/fade/duration
## constraints, and scripts/audio/sfx_catalog.gd resolves every approved event to real streams.
##
## Run through scripts/tools/run_isolated_godot_test.ps1:
##
##     & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/audio/test_core_sfx_assets.gd
##
## A failure on the byte-comparison check means the committed WAVs and the generator have drifted
## apart. Regenerate with the documented command rather than relaxing the check.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const SynthesisScript := preload("res://scripts/tools/core_sfx_synthesis.gd")
const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")

const GENERATED_DIRECTORY := "res://assets/audio/generated"
const MANIFEST_PATH := "res://assets/audio/generated/generated_sfx_manifest.json"
const RETAINED_RECORDINGS := {
	"res://assets/audio/item_place.wav": SfxCatalogScript.EVENT_ITEM_PLACE_VALID,
	"res://assets/audio/triple_clear.wav": SfxCatalogScript.EVENT_MATCH_CLEAR,
}
## The ticket's per-cue duration windows, in milliseconds.
const DURATION_WINDOWS_MS := {
	"ui_click": Vector2(25.0, 50.0),
	"item_select": Vector2(40.0, 75.0),
	"star_hud_arrival": Vector2(140.0, 240.0),
	"timer_tick": Vector2(30.0, 65.0),
	"time_up": Vector2(300.0, 600.0),
	"coin_gain": Vector2(300.0, 650.0),
	"coin_spend": Vector2(180.0, 350.0),
	"shop_purchase_success": Vector2(400.0, 750.0),
	"reward_chest_star_arrival": Vector2(90.0, 180.0),
}
const MAX_DC_OFFSET := 0.002
## The ticket caps every cue in scope at roughly 750 ms.
const MAX_CUE_DURATION_MS := 750.0
## The edge fades must land the first and last samples on (quantized) silence.
const EDGE_SILENCE_THRESHOLD := 4

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Core SFX asset verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_generator_determinism()
	_test_committed_files_match_the_generator()
	_test_manifest()
	_test_committed_wav_constraints()
	_test_catalog_completeness()

	if _failures.is_empty():
		print("Core SFX asset verification passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


## The same committed seeds and parameters must produce the same PCM every time -- no engine RNG,
## no wall-clock, no frame state anywhere in the synthesis path.
func _test_generator_determinism() -> void:
	var first := SynthesisScript.render_all()
	var second := SynthesisScript.render_all()
	_check(first.size() == SynthesisScript.CUES.size(), "The generator renders one file per catalogued cue.")
	_check(first.size() == second.size(), "Repeated generator runs render the same number of cues.")
	if first.size() != second.size():
		return

	for index in range(first.size()):
		var name := str(first[index]["name"])
		_check(name == str(second[index]["name"]), "Cue order is stable across runs (%s)." % name)
		_check(
			(first[index]["pcm"] as PackedByteArray) == (second[index]["pcm"] as PackedByteArray),
			"Regenerating %s produces byte-identical PCM." % name
		)


func _test_committed_files_match_the_generator() -> void:
	for cue in SynthesisScript.render_all():
		var file_path := GENERATED_DIRECTORY.path_join(str(cue["file_name"]))
		var committed := _read_file(file_path)
		if committed.is_empty():
			_failures.append("Missing committed generated asset: %s" % file_path)
			continue

		_check(
			committed == (cue["pcm"] as PackedByteArray),
			"%s is reproducible from the committed generator." % file_path
		)


func _test_manifest() -> void:
	var manifest_bytes := _read_file(MANIFEST_PATH)
	if manifest_bytes.is_empty():
		_failures.append("Missing generator manifest: %s" % MANIFEST_PATH)
		return

	var parsed = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not (parsed is Dictionary):
		_failures.append("The generator manifest is not a JSON object.")
		return

	var manifest := parsed as Dictionary
	_check(
		str(manifest.get("generator_version", "")) == SynthesisScript.GENERATOR_VERSION,
		"The manifest records the current generator version."
	)
	_check(
		int(manifest.get("sample_rate", 0)) == SynthesisScript.SAMPLE_RATE
			and int(manifest.get("bit_depth", 0)) == SynthesisScript.BIT_DEPTH
			and int(manifest.get("channels", 0)) == SynthesisScript.CHANNEL_COUNT,
		"The manifest records the one committed encoding (mono 16-bit PCM at 44.1 kHz)."
	)

	var manifest_names := []
	for raw_entry in manifest.get("files", []) as Array:
		manifest_names.append(str((raw_entry as Dictionary).get("file_name", "")))

	var expected_names := []
	for cue in SynthesisScript.CUES:
		expected_names.append("%s.wav" % cue["name"])

	_check(
		manifest_names == expected_names,
		"The manifest lists exactly the expected output files, in order."
	)


func _test_committed_wav_constraints() -> void:
	for cue in SynthesisScript.CUES:
		var cue_name := str(cue["name"])
		var file_path := GENERATED_DIRECTORY.path_join("%s.wav" % cue_name)
		var bytes := _read_file(file_path)
		if bytes.is_empty():
			continue

		var wav := _parse_wav(bytes)
		if not bool(wav.get("ok", false)):
			_failures.append("%s is not a readable 16-bit PCM WAV: %s" % [file_path, wav.get("error", "")])
			continue

		var samples := wav["samples"] as PackedInt32Array
		_check(int(wav["channels"]) == 1, "%s is mono." % cue_name)
		_check(int(wav["bits_per_sample"]) == 16, "%s is 16-bit." % cue_name)
		_check(
			int(wav["sample_rate"]) == SynthesisScript.SAMPLE_RATE,
			"%s uses the project's single sample rate." % cue_name
		)
		_check(not samples.is_empty(), "%s carries non-empty PCM data." % cue_name)
		if samples.is_empty():
			continue

		var duration_ms := float(samples.size()) / float(wav["sample_rate"]) * 1000.0
		var window := _get_duration_window(cue_name)
		_check(
			duration_ms >= window.x and duration_ms <= window.y,
			"%s lasts %.1f ms, inside its %.0f-%.0f ms window." % [cue_name, duration_ms, window.x, window.y]
		)
		_check(
			duration_ms <= MAX_CUE_DURATION_MS,
			"%s stays under the %.0f ms ceiling for this ticket." % [cue_name, MAX_CUE_DURATION_MS]
		)

		var peak := 0
		var total := 0.0
		for sample in samples:
			peak = maxi(peak, absi(sample))
			total += float(sample) / 32768.0

		var peak_db := linear_to_db(float(peak) / 32768.0) if peak > 0 else -INF
		_check(
			peak_db <= SynthesisScript.PEAK_CEILING_DB,
			"%s peaks at %.2f dBFS, at or under the %.1f dBFS ceiling." % [
				cue_name, peak_db, SynthesisScript.PEAK_CEILING_DB
			]
		)
		_check(
			is_equal_approx(peak_db, float(cue["peak_db"])) or absf(peak_db - float(cue["peak_db"])) < 0.05,
			"%s keeps its authored relative loudness (%.2f dBFS)." % [cue_name, float(cue["peak_db"])]
		)

		var dc_offset := total / float(samples.size())
		_check(
			absf(dc_offset) < MAX_DC_OFFSET,
			"%s has a bounded DC offset (%.5f)." % [cue_name, dc_offset]
		)
		_check(
			absi(samples[0]) <= EDGE_SILENCE_THRESHOLD and absi(samples[-1]) <= EDGE_SILENCE_THRESHOLD,
			"%s starts and ends on the attack/release fades." % cue_name
		)

	_check(
		_get_generated_wav_names().size() == SynthesisScript.CUES.size(),
		"The generated directory holds no orphan WAV files."
	)


func _test_catalog_completeness() -> void:
	var expected_events := [
		SfxCatalogScript.EVENT_ITEM_SELECT,
		SfxCatalogScript.EVENT_ITEM_PLACE_VALID,
		SfxCatalogScript.EVENT_MATCH_CLEAR,
		SfxCatalogScript.EVENT_STAR_HUD_ARRIVAL,
		SfxCatalogScript.EVENT_TIMER_CRITICAL_TICK,
		SfxCatalogScript.EVENT_TIME_UP,
		SfxCatalogScript.EVENT_COIN_GAIN,
		SfxCatalogScript.EVENT_COIN_SPEND,
		SfxCatalogScript.EVENT_SHOP_PURCHASE_SUCCESS,
		SfxCatalogScript.EVENT_REWARD_CHEST_STAR_ARRIVAL,
		SfxCatalogScript.EVENT_UI_CLICK,
	]
	_check(
		SfxCatalogScript.EVENTS.size() == expected_events.size(),
		"The catalog holds exactly the eleven approved events."
	)
	for event_id in expected_events:
		if not SfxCatalogScript.has_event(event_id):
			_failures.append("The catalog is missing approved event %s." % event_id)
			continue

		var config := SfxCatalogScript.get_event(event_id)
		var streams := config.get("streams", []) as Array
		_check(not streams.is_empty(), "%s resolves to at least one stream." % event_id)
		for stream_path in streams:
			_check(
				ResourceLoader.exists(str(stream_path)),
				"%s references an importable stream (%s)." % [event_id, stream_path]
			)
		_check(
			int(config.get("max_polyphony", 0)) >= 1,
			"%s declares a polyphony budget." % event_id
		)

	for recording_path in RETAINED_RECORDINGS:
		var owning_event := RETAINED_RECORDINGS[recording_path] as StringName
		var streams := SfxCatalogScript.get_event(owning_event).get("streams", []) as Array
		_check(
			streams.has(recording_path),
			"%s keeps the project's source recording %s." % [owning_event, recording_path]
		)

	# Every generated file must be reachable from the catalog: an asset nothing plays is either a
	# wiring mistake or dead weight in the build.
	var catalog_paths := SfxCatalogScript.get_all_stream_paths()
	for file_name in _get_generated_wav_names():
		var generated_path := GENERATED_DIRECTORY.path_join(file_name)
		_check(
			catalog_paths.has(generated_path),
			"The catalog references generated asset %s." % file_name
		)


func _get_duration_window(cue_name: String) -> Vector2:
	for prefix in DURATION_WINDOWS_MS:
		if cue_name.begins_with(str(prefix)):
			return DURATION_WINDOWS_MS[prefix] as Vector2

	_failures.append("No documented duration window for cue %s." % cue_name)
	return Vector2(0.0, MAX_CUE_DURATION_MS)


func _get_generated_wav_names() -> Array[String]:
	var names: Array[String] = []
	var directory := DirAccess.open(GENERATED_DIRECTORY)
	if directory == null:
		_failures.append("Could not open %s." % GENERATED_DIRECTORY)
		return names

	for file_name in directory.get_files():
		# A run against the imported project also sees the generated `.import` sidecars.
		if file_name.get_extension().to_lower() == "wav":
			names.append(file_name)

	return names


func _read_file(file_path: String) -> PackedByteArray:
	if not FileAccess.file_exists(file_path):
		return PackedByteArray()

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return PackedByteArray()

	return file.get_buffer(file.get_length())


## Minimal RIFF/WAVE reader, deliberately independent of Godot's importer so the check describes
## the committed source bytes rather than whatever the import pipeline produced.
func _parse_wav(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 44:
		return {"ok": false, "error": "shorter than a WAV header"}

	var stream := StreamPeerBuffer.new()
	stream.big_endian = false
	stream.data_array = bytes
	if stream.get_string(4) != "RIFF":
		return {"ok": false, "error": "missing RIFF marker"}

	stream.get_u32()
	if stream.get_string(4) != "WAVE":
		return {"ok": false, "error": "missing WAVE marker"}

	var channels := 0
	var sample_rate := 0
	var bits_per_sample := 0
	var samples := PackedInt32Array()
	var found_data := false
	while stream.get_position() + 8 <= bytes.size():
		var chunk_id := stream.get_string(4)
		var chunk_size := stream.get_u32()
		var chunk_end := stream.get_position() + chunk_size
		if chunk_id == "fmt ":
			var format_tag := stream.get_u16()
			if format_tag != 1:
				return {"ok": false, "error": "format tag %d is not PCM" % format_tag}
			channels = stream.get_u16()
			sample_rate = stream.get_u32()
			stream.get_u32()
			stream.get_u16()
			bits_per_sample = stream.get_u16()
		elif chunk_id == "data":
			found_data = true
			var sample_count := chunk_size / 2
			samples.resize(sample_count)
			for index in range(sample_count):
				samples[index] = stream.get_16()

		stream.seek(chunk_end)

	if not found_data:
		return {"ok": false, "error": "missing data chunk"}

	return {
		"ok": true,
		"channels": channels,
		"sample_rate": sample_rate,
		"bits_per_sample": bits_per_sample,
		"samples": samples,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
