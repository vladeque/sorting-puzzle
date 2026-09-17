extends RefCounted

## Machine-readable counterpart to docs/AUDIO_LOUDNESS_STANDARD.md.
##
## These are mix targets, not instructions to peak-normalize source files. Tests require every
## catalog event to choose one class and compare its measured 400 ms maximum-momentary loudness
## after catalog gain against that class.

const MASTER_TARGET_LUFS_I := -18.0
const MASTER_ACCEPTABLE_LUFS_I := Vector2(-20.0, -16.0)
const MASTER_TRUE_PEAK_CEILING_DBTP := -1.0

const ASSET_WORKING_TRUE_PEAK_DBTP := -3.0
const ASSET_HARD_TRUE_PEAK_DBTP := -1.0
const ROUTINE_EVENT_TRUE_PEAK_DBTP := -6.0
const MAJOR_EVENT_TRUE_PEAK_DBTP := -3.0
const MAX_VARIANT_SPREAD_LU := 1.0

## `nominal_max_m_lufs` is the accepted range for one ordinary play. `burst_ceiling_lufs` includes
## bounded random variation and declared count scaling; it is a ceiling, not a normalization goal.
const CLASSES := {
	&"ui_micro": {
		"nominal_max_m_lufs": Vector2(-34.0, -30.0),
		"burst_ceiling_lufs": -29.0,
	},
	&"interaction_micro": {
		"nominal_max_m_lufs": Vector2(-32.0, -27.0),
		"burst_ceiling_lufs": -26.0,
	},
	&"gameplay_feedback": {
		"nominal_max_m_lufs": Vector2(-29.0, -24.0),
		"burst_ceiling_lufs": -21.0,
	},
	&"reward_confirmation": {
		"nominal_max_m_lufs": Vector2(-22.0, -17.0),
		"burst_ceiling_lufs": -16.0,
	},
	&"ability_warning": {
		"nominal_max_m_lufs": Vector2(-19.0, -16.0),
		"burst_ceiling_lufs": -15.0,
	},
	&"terminal_stinger": {
		"nominal_max_m_lufs": Vector2(-17.0, -15.0),
		"burst_ceiling_lufs": -14.0,
	},
}


static func has_class(class_id: StringName) -> bool:
	return CLASSES.has(class_id)


static func get_class_config(class_id: StringName) -> Dictionary:
	return (CLASSES.get(class_id, {}) as Dictionary).duplicate(true)
