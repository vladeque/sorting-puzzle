extends SceneTree

## Audio asset verification: the manifest-owned AUDIO-001 palette is still exactly what
## scripts/tools/generate_core_sfx.gd produces, it satisfies the ticket's PCM/peak/fade/duration
## constraints, and scripts/audio/sfx_catalog.gd resolves every shared event to real streams.
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
const SfxLoudnessStandardScript := preload("res://scripts/audio/sfx_loudness_standard.gd")

const AUDIO_DIRECTORY := "res://assets/audio"
const MANIFEST_PATH := "res://assets/audio/generated_sfx_manifest.json"
const LOUDNESS_MEASUREMENTS_PATH := "res://assets/audio/sfx_loudness_measurements.json"
const REWARD_CHEST_SHORT_CUE := (
	"res://assets/audio/reward_chest_star_arrival/reward_chest_star_arrival_short.wav"
)
const RETAINED_RECORDINGS := {
	"res://assets/audio/item_place_valid/item_place.wav": SfxCatalogScript.EVENT_ITEM_PLACE_VALID,
	"res://assets/audio/match_clear/triple_clear.wav": SfxCatalogScript.EVENT_MATCH_CLEAR,
}
const AUTHORED_SOURCE_CUES := [
	"res://assets/audio/ability_freezer/freeze.wav",
	"res://assets/audio/ability_hammer/hammer.wav",
	"res://assets/audio/sticky_move_blocked/cartoon_gum_pop.wav",
	"res://assets/audio/ability_lantern/lantern.wav",
	"res://assets/audio/level_complete/level_complete.mp3",
	"res://assets/audio/level_failed/level_failed.wav",
	"res://assets/audio/shop_purchase_success/purchase_successful.wav",
	"res://assets/audio/shelf_unlock/shelve_unlock.wav",
	"res://assets/audio/ability_shuffle/shuffle.wav",
	"res://assets/audio/timer_critical_tick/timer_tick.wav",
	"res://assets/audio/time_up/times_up2.mp3",
	"res://assets/audio/star_hud_arrival/star_hud_arrival.wav",
	"res://assets/audio/ui_click/ui_click_01.wav",
	"res://assets/audio/ui_click/ui_click_02.wav",
	"res://assets/audio/ui_click/ui_click_03.wav",
]
## Kept as easy-to-restore comparison material. This includes the prior chest variants while that
## event trials star_hud_arrival.wav. Unlike AUTHORED_SOURCE_CUES, none are runtime-catalogued.
const INACTIVE_AUTHORED_CUES := [
	"res://assets/audio/ability_lantern/lantern1.wav",
	"res://assets/audio/match_clear/triple_clear1.wav",
	"res://assets/audio/match_clear/triple_clear2.wav",
	"res://assets/audio/reward_chest_star_arrival/reward_chest_star_arrival_01.wav",
	"res://assets/audio/reward_chest_star_arrival/reward_chest_star_arrival_02.wav",
	"res://assets/audio/reward_chest_star_arrival/reward_chest_star_arrival_03.wav",
]
const DERIVED_RUNTIME_CUES := [REWARD_CHEST_SHORT_CUE]
## The ticket's per-cue duration windows, in milliseconds.
const DURATION_WINDOWS_MS := {
	"item_select": Vector2(40.0, 75.0),
	"time_up": Vector2(300.0, 600.0),
	"coin_gain": Vector2(300.0, 650.0),
	"coin_spend": Vector2(180.0, 350.0),
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
	_test_loudness_measurements()

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
		var file_path := AUDIO_DIRECTORY.path_join(str(cue["relative_path"]))
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
		expected_names.append("%s/%s.wav" % [cue["event"], cue["name"]])

	_check(
		manifest_names == expected_names,
		"The manifest lists exactly the expected output files, in order."
	)


func _test_committed_wav_constraints() -> void:
	for cue in SynthesisScript.CUES:
		var cue_name := str(cue["name"])
		var file_path := AUDIO_DIRECTORY.path_join("%s/%s.wav" % [cue["event"], cue_name])
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

	var authored_wav_count := 0
	for source_path in AUTHORED_SOURCE_CUES + INACTIVE_AUTHORED_CUES + DERIVED_RUNTIME_CUES:
		if str(source_path).get_extension().to_lower() == "wav":
			authored_wav_count += 1
	_check(
		_get_audio_wav_paths().size()
			== SynthesisScript.CUES.size() + authored_wav_count + RETAINED_RECORDINGS.size(),
		"Every committed WAV is owned by the generator, authored batch, or retained recordings."
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
		SfxCatalogScript.EVENT_STICKY_MOVE_BLOCKED,
		SfxCatalogScript.EVENT_SHELF_UNLOCK,
		SfxCatalogScript.EVENT_ABILITY_HAMMER,
		SfxCatalogScript.EVENT_ABILITY_SHUFFLE,
		SfxCatalogScript.EVENT_ABILITY_LANTERN,
		SfxCatalogScript.EVENT_ABILITY_FREEZER,
		SfxCatalogScript.EVENT_LEVEL_COMPLETE,
		SfxCatalogScript.EVENT_LEVEL_FAILED,
	]
	_check(
		SfxCatalogScript.EVENTS.size() == expected_events.size(),
		"The catalog holds exactly the expected shared events."
	)
	for event_id in expected_events:
		if not SfxCatalogScript.has_event(event_id):
			_failures.append("The catalog is missing approved event %s." % event_id)
			continue

		var config := SfxCatalogScript.get_event(event_id)
		var loudness_class := config.get("loudness_class", &"") as StringName
		_check(
			SfxLoudnessStandardScript.has_class(loudness_class),
			"%s declares a recognized loudness class." % event_id
		)
		var streams := config.get("streams", []) as Array
		_check(not streams.is_empty(), "%s resolves to at least one stream." % event_id)
		for stream_path in streams:
			_check(
				ResourceLoader.exists(str(stream_path)),
				"%s references an importable stream (%s)." % [event_id, stream_path]
			)
		var stream_offsets := config.get("stream_volume_offsets_db", {}) as Dictionary
		for stream_path in stream_offsets:
			_check(
				streams.has(stream_path),
				"%s only declares per-stream gain for a stream in its own pool (%s)." % [
					event_id, stream_path
				]
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

	# Every supplied source cue remains reachable from its one semantic event folder.
	var catalog_paths := SfxCatalogScript.get_all_stream_paths()
	for generated_path in AUTHORED_SOURCE_CUES:
		_check(
			ResourceLoader.exists(generated_path),
			"The authored source cue is importable (%s)." % generated_path
		)
		_check(
			catalog_paths.has(generated_path),
			"The catalog references authored source cue %s." % generated_path
		)

	for inactive_path in INACTIVE_AUTHORED_CUES:
		_check(
			ResourceLoader.exists(inactive_path),
			"The inactive authored comparison cue is importable (%s)." % inactive_path
		)
		_check(
			not catalog_paths.has(inactive_path),
			"The inactive authored comparison cue stays out of the runtime catalog (%s)." % inactive_path
		)

	for derived_path in DERIVED_RUNTIME_CUES:
		_check(
			ResourceLoader.exists(derived_path) and catalog_paths.has(derived_path),
			"The derived runtime cue is importable and catalogued (%s)." % derived_path
		)

	_check(
		SfxCatalogScript.get_event(SfxCatalogScript.EVENT_REWARD_CHEST_STAR_ARRIVAL).get(
			"streams", []
		) == [REWARD_CHEST_SHORT_CUE],
		"Reward chest arrivals use the short, chest-specific HUD arrival derivative."
	)
	var short_cue := load(REWARD_CHEST_SHORT_CUE) as AudioStreamWAV
	_check(short_cue != null, "The short reward-chest cue imports as AudioStreamWAV.")
	if short_cue != null:
		_check(
			absf(short_cue.get_length() - 0.2) <= 0.005,
			"The short reward-chest cue lasts 200 ms."
		)


func _test_loudness_measurements() -> void:
	var bytes := _read_file(LOUDNESS_MEASUREMENTS_PATH)
	if bytes.is_empty():
		_failures.append("Missing loudness measurement snapshot: %s" % LOUDNESS_MEASUREMENTS_PATH)
		return

	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not (parsed is Dictionary):
		_failures.append("The loudness measurement snapshot is not a JSON object.")
		return

	var snapshot := parsed as Dictionary
	_check(int(snapshot.get("schema_version", 0)) == 1, "The loudness snapshot uses schema 1.")
	var measurements_by_path := {}
	for raw_measurement in snapshot.get("measurements", []) as Array:
		var measurement := raw_measurement as Dictionary
		var path := str(measurement.get("path", ""))
		_check(not path.is_empty(), "Every loudness measurement names its source path.")
		_check(not measurements_by_path.has(path), "The loudness snapshot lists %s once." % path)
		measurements_by_path[path] = measurement
		_check(FileAccess.file_exists(path), "The measured audio file still exists (%s)." % path)
		if FileAccess.file_exists(path):
			_check(
				FileAccess.get_sha256(path) == str(measurement.get("sha256", "")),
				"%s has fresh loudness measurements for its current bytes." % path
			)
		_check(
			float(measurement.get("true_peak_dbtp", INF))
				<= SfxLoudnessStandardScript.ASSET_HARD_TRUE_PEAK_DBTP + 0.05,
			"%s stays at or below the %.1f dBTP source ceiling." % [
				path, SfxLoudnessStandardScript.ASSET_HARD_TRUE_PEAK_DBTP
			]
		)

	var audio_paths := _get_audio_source_paths()
	audio_paths.sort()
	var measured_paths := measurements_by_path.keys()
	measured_paths.sort()
	_check(
		measured_paths == audio_paths,
		"The loudness snapshot covers every committed audio source exactly once."
	)

	for event_id in SfxCatalogScript.get_event_ids():
		var config := SfxCatalogScript.get_event(event_id)
		var class_id := config.get("loudness_class", &"") as StringName
		var class_config := SfxLoudnessStandardScript.get_class_config(class_id)
		if class_config.is_empty():
			continue

		var nominal_range := class_config["nominal_max_m_lufs"] as Vector2
		var variant_levels: Array[float] = []
		var stream_offsets := config.get("stream_volume_offsets_db", {}) as Dictionary
		for raw_stream_path in config.get("streams", []) as Array:
			var stream_path := str(raw_stream_path)
			if not measurements_by_path.has(stream_path):
				_failures.append("%s has no loudness measurement (%s)." % [event_id, stream_path])
				continue

			var measurement := measurements_by_path[stream_path] as Dictionary
			var nominal := (
				float(measurement.get("max_m_lufs", -INF))
				+ float(config.get("volume_db", 0.0))
				+ float(stream_offsets.get(stream_path, 0.0))
			)
			variant_levels.append(nominal)
			_check(
				nominal >= nominal_range.x - 0.25 and nominal <= nominal_range.y + 0.25,
				"%s/%s is %.2f LUFS-M inside %s's %.1f to %.1f range." % [
					event_id,
					stream_path.get_file(),
					nominal,
					class_id,
					nominal_range.x,
					nominal_range.y,
				]
			)

			var scaling := config.get("count_scaling", {}) as Dictionary
			var burst := (
				nominal
				+ float(config.get("volume_variation_db", 0.0))
				+ float(scaling.get("max_volume_db", 0.0))
			)
			_check(
				burst <= float(class_config["burst_ceiling_lufs"]) + 0.25,
				"%s remains under its %.1f LUFS-M burst ceiling." % [
					event_id, float(class_config["burst_ceiling_lufs"])
				]
			)

		if variant_levels.size() > 1:
			var spread: float = variant_levels.max() - variant_levels.min()
			_check(
				spread <= SfxLoudnessStandardScript.MAX_VARIANT_SPREAD_LU + 0.05,
				"%s variants stay within %.1f LU." % [
					event_id, SfxLoudnessStandardScript.MAX_VARIANT_SPREAD_LU
				]
			)


func _get_duration_window(cue_name: String) -> Vector2:
	for prefix in DURATION_WINDOWS_MS:
		if cue_name.begins_with(str(prefix)):
			return DURATION_WINDOWS_MS[prefix] as Vector2

	_failures.append("No documented duration window for cue %s." % cue_name)
	return Vector2(0.0, MAX_CUE_DURATION_MS)


func _get_audio_wav_paths() -> Array[String]:
	var paths: Array[String] = []
	_collect_wav_paths(AUDIO_DIRECTORY, paths)
	return paths


func _get_audio_source_paths() -> Array:
	var paths := []
	_collect_audio_source_paths(AUDIO_DIRECTORY, paths)
	return paths


func _collect_audio_source_paths(directory_path: String, paths: Array) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_failures.append("Could not open %s." % directory_path)
		return

	var extensions := ["wav", "mp3", "ogg", "flac", "m4a", "aac", "opus"]
	for file_name in directory.get_files():
		if extensions.has(file_name.get_extension().to_lower()):
			paths.append(directory_path.path_join(file_name))

	for child_directory in directory.get_directories():
		_collect_audio_source_paths(directory_path.path_join(child_directory), paths)


func _collect_wav_paths(directory_path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_failures.append("Could not open %s." % directory_path)
		return

	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() == "wav":
			paths.append(directory_path.path_join(file_name))

	for child_directory in directory.get_directories():
		_collect_wav_paths(directory_path.path_join(child_directory), paths)


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
