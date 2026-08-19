extends SceneTree

## AUDIO-001 asset generator: writes the project-owned, deterministic core SFX palette to
## res://assets/audio/generated/.
##
## Regenerate with (see docs/SCRIPTS.md):
##
##     & 'D:\Godot\godot.exe' --headless --path . --script res://scripts/tools/generate_core_sfx.gd -- --regenerate
##     & 'D:\Godot\godot.exe' --headless --path . --import
##
## The second command re-imports the new WAVs; scripts/audio/sfx_catalog.gd loads the imported
## samples, so a generation without an import leaves the catalog pointing at stale audio.
##
## All synthesis lives in scripts/tools/core_sfx_synthesis.gd. This script only owns the CLI: the
## overwrite guard, the manifest, and the report. It deliberately does not synthesize replacements
## for item_place.wav / triple_clear.wav -- those stay the project's source recordings.
##
## Options (after the `--` separator):
##   --regenerate            Allow overwriting outputs recorded under a different generator version.
##   --output-dir=<res path> Write elsewhere (tests use this to compare a fresh run byte-for-byte).

const SynthesisScript := preload("res://scripts/tools/core_sfx_synthesis.gd")

const DEFAULT_OUTPUT_DIRECTORY := "res://assets/audio/generated"
const MANIFEST_FILE_NAME := "generated_sfx_manifest.json"

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var allow_regeneration := arguments.has("--regenerate")
	var output_directory := DEFAULT_OUTPUT_DIRECTORY
	for argument in arguments:
		if argument.begins_with("--output-dir="):
			output_directory = argument.trim_prefix("--output-dir=")

	print("Core SFX generator version %s" % SynthesisScript.GENERATOR_VERSION)
	print("Output directory: %s" % output_directory)

	if not _prepare_output_directory(output_directory, allow_regeneration):
		quit(1)
		return

	var rendered := SynthesisScript.render_all()
	var manifest_entries := []
	for cue in rendered:
		var file_path := output_directory.path_join(str(cue["file_name"]))
		if not _write_file(file_path, cue["pcm"] as PackedByteArray):
			quit(1)
			return

		var peak_db := float(cue["peak_db"])
		if peak_db > SynthesisScript.PEAK_CEILING_DB:
			push_error("%s exceeds the %.1f dBFS ceiling at %.2f dBFS." % [
				file_path, SynthesisScript.PEAK_CEILING_DB, peak_db
			])
			_failed = true

		print("  %s  %6.1f ms  %d Hz  peak %6.2f dBFS  dc %+.5f" % [
			file_path,
			float(cue["duration_seconds"]) * 1000.0,
			SynthesisScript.SAMPLE_RATE,
			peak_db,
			float(cue["dc_offset"]),
		])
		manifest_entries.append({
			"file_name": str(cue["file_name"]),
			"duration_seconds": snappedf(float(cue["duration_seconds"]), 0.000001),
			"sample_rate": SynthesisScript.SAMPLE_RATE,
			"bit_depth": SynthesisScript.BIT_DEPTH,
			"channels": SynthesisScript.CHANNEL_COUNT,
			"authored_peak_db": float(cue["authored_peak_db"]),
			"peak_db": snappedf(peak_db, 0.001),
		})

	if not _write_manifest(output_directory, manifest_entries):
		quit(1)
		return

	print("Wrote %d cues (mono %d-bit PCM @ %d Hz)." % [
		rendered.size(), SynthesisScript.BIT_DEPTH, SynthesisScript.SAMPLE_RATE
	])
	quit(1 if _failed else 0)


## Creates the output directory and enforces the version guard: outputs recorded under a different
## generator version are never silently replaced, because the committed WAVs and the manifest are
## what the determinism test compares against.
func _prepare_output_directory(output_directory: String, allow_regeneration: bool) -> bool:
	if not DirAccess.dir_exists_absolute(output_directory):
		var make_result := DirAccess.make_dir_recursive_absolute(output_directory)
		if make_result != OK:
			push_error("Could not create the SFX output directory: %s" % output_directory)
			return false

		return true

	var manifest_path := output_directory.path_join(MANIFEST_FILE_NAME)
	if not FileAccess.file_exists(manifest_path):
		if _directory_has_wav_files(output_directory) and not allow_regeneration:
			push_error(
				"%s already holds WAV files with no generator manifest. Pass --regenerate to replace them."
				% output_directory
			)
			return false

		return true

	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	if manifest_file == null:
		push_error("Could not read the existing manifest: %s" % manifest_path)
		return false

	var parsed = JSON.parse_string(manifest_file.get_as_text())
	var recorded_version := ""
	if parsed is Dictionary:
		recorded_version = str((parsed as Dictionary).get("generator_version", ""))

	if recorded_version == SynthesisScript.GENERATOR_VERSION or allow_regeneration:
		return true

	push_error(
		"%s was produced by generator version '%s' but this generator is '%s'. Pass --regenerate to replace it."
		% [output_directory, recorded_version, SynthesisScript.GENERATOR_VERSION]
	)
	return false


func _directory_has_wav_files(output_directory: String) -> bool:
	var directory := DirAccess.open(output_directory)
	if directory == null:
		return false

	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() == "wav":
			return true

	return false


func _write_file(file_path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s (error %d)." % [file_path, FileAccess.get_open_error()])
		return false

	file.store_buffer(bytes)
	file.close()
	return true


func _write_manifest(output_directory: String, entries: Array) -> bool:
	var manifest := {
		"generator_version": SynthesisScript.GENERATOR_VERSION,
		"generator_script": "res://scripts/tools/generate_core_sfx.gd",
		"sample_rate": SynthesisScript.SAMPLE_RATE,
		"bit_depth": SynthesisScript.BIT_DEPTH,
		"channels": SynthesisScript.CHANNEL_COUNT,
		"peak_ceiling_db": SynthesisScript.PEAK_CEILING_DB,
		"files": entries,
	}
	var manifest_path := output_directory.path_join(MANIFEST_FILE_NAME)
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		push_error("Could not write the generator manifest: %s" % manifest_path)
		return false

	manifest_file.store_string("%s\n" % JSON.stringify(manifest, "\t"))
	manifest_file.close()
	print("  %s" % manifest_path)
	return true
