extends SceneTree

## Tool-side bridge for scripts/tools/audit_sfx_loudness.ps1. It serializes the typed GDScript
## catalog and machine-readable loudness standard without making either PowerShell or FFmpeg parse
## GDScript source text.

const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")
const SfxLoudnessStandardScript := preload("res://scripts/audio/sfx_loudness_standard.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")

	if output_path.is_empty():
		push_error("Expected --output=<absolute json path>.")
		quit(2)
		return

	var events: Array[Dictionary] = []
	var event_ids := SfxCatalogScript.get_event_ids()
	event_ids.sort()
	for event_id in event_ids:
		var config := SfxCatalogScript.get_event(event_id)
		var offsets := {}
		for stream_path in (config.get("stream_volume_offsets_db", {}) as Dictionary):
			offsets[str(stream_path)] = float(
				(config["stream_volume_offsets_db"] as Dictionary)[stream_path]
			)

		var scaling := config.get("count_scaling", {}) as Dictionary
		events.append({
			"event_id": str(event_id),
			"loudness_class": str(config.get("loudness_class", &"")),
			"streams": config.get("streams", []),
			"volume_db": float(config.get("volume_db", 0.0)),
			"stream_volume_offsets_db": offsets,
			"volume_variation_db": float(config.get("volume_variation_db", 0.0)),
			"max_count_gain_db": float(scaling.get("max_volume_db", 0.0)),
			"cooldown_seconds": float(config.get("cooldown_seconds", 0.0)),
			"max_polyphony": int(config.get("max_polyphony", 1)),
		})

	var classes := {}
	for class_id in SfxLoudnessStandardScript.CLASSES:
		var class_config := SfxLoudnessStandardScript.CLASSES[class_id] as Dictionary
		var nominal_range := class_config["nominal_max_m_lufs"] as Vector2
		classes[str(class_id)] = {
			"nominal_min_lufs": nominal_range.x,
			"nominal_max_lufs": nominal_range.y,
			"burst_ceiling_lufs": float(class_config["burst_ceiling_lufs"]),
		}

	var manifest := {
		"events": events,
		"standard": {
			"master_target_lufs_i": SfxLoudnessStandardScript.MASTER_TARGET_LUFS_I,
			"master_acceptable_min_lufs_i": (
				SfxLoudnessStandardScript.MASTER_ACCEPTABLE_LUFS_I.x
			),
			"master_acceptable_max_lufs_i": (
				SfxLoudnessStandardScript.MASTER_ACCEPTABLE_LUFS_I.y
			),
			"master_true_peak_ceiling_dbtp": (
				SfxLoudnessStandardScript.MASTER_TRUE_PEAK_CEILING_DBTP
			),
			"asset_working_true_peak_dbtp": (
				SfxLoudnessStandardScript.ASSET_WORKING_TRUE_PEAK_DBTP
			),
			"asset_hard_true_peak_dbtp": SfxLoudnessStandardScript.ASSET_HARD_TRUE_PEAK_DBTP,
			"routine_event_true_peak_dbtp": (
				SfxLoudnessStandardScript.ROUTINE_EVENT_TRUE_PEAK_DBTP
			),
			"major_event_true_peak_dbtp": SfxLoudnessStandardScript.MAJOR_EVENT_TRUE_PEAK_DBTP,
			"max_variant_spread_lu": SfxLoudnessStandardScript.MAX_VARIANT_SPREAD_LU,
			"classes": classes,
		},
	}

	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write loudness manifest: %s" % output_path)
		quit(3)
		return

	file.store_string(JSON.stringify(manifest, "\t", false, true))
	file.close()
	quit(0)
