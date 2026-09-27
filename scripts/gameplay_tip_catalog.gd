extends RefCounted

## Loads `configs/gameplay_tips.json`: which campaign level shows which first-time tip.
##
## The file is presentation only. Tips deliberately do not live in `configs/levels/level_*.json`,
## because those files are hashed into `configs/backend/content_provenance.json` and editing them
## would change the published content identity. See docs/GAMEPLAY_TIPS.md.
##
## An invalid file fails closed: every error is reported and no tip is served, so a typo can never
## show a half-configured tip.

const CONFIG_PATH := "res://configs/gameplay_tips.json"
const TYPE_MOVE_TO_TRIPLE := "move_to_triple"
const TYPE_TAP_DISPENSER := "tap_dispenser"
const KNOWN_TYPES := [TYPE_MOVE_TO_TRIPLE, TYPE_TAP_DISPENSER]
const DEFAULT_START_DELAY_SECONDS := 0.6
const DEFAULT_RESHOW_DELAY_SECONDS := 1.5
const MAX_DELAY_SECONDS := 10.0
## Matches `PlayerProgress.MAX_GAMEPLAY_TIP_ID_LENGTH`, so every served id can be marked seen.
const MAX_ID_LENGTH := 64

var _tips_by_level: Dictionary = {}
var _errors := PackedStringArray()


func load_catalog(path: String = CONFIG_PATH) -> bool:
	if not FileAccess.file_exists(path):
		_reset()
		_errors.append("Gameplay tips config is missing: %s" % path)
		return false

	return load_document(JSON.parse_string(FileAccess.get_file_as_string(path)))


func load_document(document) -> bool:
	_reset()
	if not (document is Dictionary):
		_errors.append("Gameplay tips config must be a JSON object.")
		return false

	var raw_tips = (document as Dictionary).get("tips", null)
	if not (raw_tips is Array):
		_errors.append("Gameplay tips config needs a `tips` array.")
		return false

	var tips_by_level := {}
	var seen_ids := {}
	for tip_index in range((raw_tips as Array).size()):
		var tip := _normalize_tip((raw_tips as Array)[tip_index], tip_index)
		if tip.is_empty():
			continue

		if seen_ids.has(tip.id):
			_errors.append("Tip %d reuses the id `%s`." % [tip_index + 1, tip.id])
			continue
		if tips_by_level.has(tip.level):
			_errors.append("Tip %d is a second tip for level %d." % [tip_index + 1, tip.level])
			continue

		seen_ids[tip.id] = true
		tips_by_level[tip.level] = tip

	if not _errors.is_empty():
		return false

	_tips_by_level = tips_by_level
	return true


func get_tip_for_level(level_number: int) -> Dictionary:
	return (_tips_by_level.get(level_number, {}) as Dictionary).duplicate(true)


func get_tips() -> Array[Dictionary]:
	var tips: Array[Dictionary] = []
	for tip in _tips_by_level.values():
		tips.append((tip as Dictionary).duplicate(true))

	return tips


func get_errors() -> PackedStringArray:
	return _errors


func _reset() -> void:
	_tips_by_level.clear()
	_errors = PackedStringArray()


func _normalize_tip(raw_tip, tip_index: int) -> Dictionary:
	var label := "Tip %d" % (tip_index + 1)
	if not (raw_tip is Dictionary):
		_errors.append("%s must be an object." % label)
		return {}

	var source := raw_tip as Dictionary
	var tip_id = source.get("id", null)
	if not (tip_id is String) or (tip_id as String).is_empty() or (tip_id as String).length() > MAX_ID_LENGTH:
		_errors.append("%s needs a non-empty `id` of at most %d characters." % [label, MAX_ID_LENGTH])
		return {}

	var level_number := _read_whole_number(source.get("level", null))
	if level_number < 1:
		_errors.append("%s needs a positive whole-number `level`." % label)
		return {}

	var tip_type = source.get("type", null)
	if not KNOWN_TYPES.has(tip_type):
		_errors.append("%s has an unknown `type`; expected one of %s." % [label, ", ".join(PackedStringArray(KNOWN_TYPES))])
		return {}

	var message = source.get("message", "")
	if not (message is String):
		_errors.append("%s has a `message` that is not a string." % label)
		return {}

	var start_delay := _read_delay(source, "start_delay_seconds", DEFAULT_START_DELAY_SECONDS, label)
	var reshow_delay := _read_delay(source, "reshow_delay_seconds", DEFAULT_RESHOW_DELAY_SECONDS, label)
	if start_delay < 0.0 or reshow_delay < 0.0:
		return {}

	return {
		"id": tip_id,
		"level": level_number,
		"type": tip_type,
		"message": (message as String).strip_edges(),
		"start_delay_seconds": start_delay,
		"reshow_delay_seconds": reshow_delay,
	}


## JSON numbers arrive as floats, so `10` and `10.0` are the same level; `10.5` is not a level.
func _read_whole_number(value) -> int:
	if not (value is int or value is float):
		return 0
	if not is_equal_approx(float(value), floorf(float(value))):
		return 0

	return int(value)


## Returns -1 after recording an error, so the caller can drop the tip.
func _read_delay(source: Dictionary, key: String, default_value: float, label: String) -> float:
	var value = source.get(key, default_value)
	if not (value is int or value is float) or float(value) < 0.0 or float(value) > MAX_DELAY_SECONDS:
		_errors.append("%s needs `%s` between 0 and %s seconds." % [label, key, MAX_DELAY_SECONDS])
		return -1.0

	return float(value)
