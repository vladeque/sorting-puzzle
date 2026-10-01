class_name ComboScoringRules
extends RefCounted

## Tiered combo scoring read from `configs/combo_scoring.json`.
##
## Each tier starts at its `min_combo` and lasts until the next tier's `min_combo`; the last tier is
## open-ended. A triple that brings the combo to ×N earns ×N's `stars_per_triple`, and ×N's
## `window_seconds` is how long the player then has to land ×(N+1). So higher combos pay more per
## triple but give less time to keep the chain going.

const CONFIG_PATH := "res://configs/combo_scoring.json"
const TIERS_KEY := "tiers"
const MIN_COMBO_KEY := "min_combo"
const WINDOW_SECONDS_KEY := "window_seconds"
const STARS_PER_TRIPLE_KEY := "stars_per_triple"

## Mirrors `configs/combo_scoring.json` so a missing or malformed file cannot zero out scoring.
const DEFAULT_TIERS := [
	{MIN_COMBO_KEY: 1, WINDOW_SECONDS_KEY: 15.0, STARS_PER_TRIPLE_KEY: 1},
	{MIN_COMBO_KEY: 4, WINDOW_SECONDS_KEY: 10.0, STARS_PER_TRIPLE_KEY: 2},
	{MIN_COMBO_KEY: 7, WINDOW_SECONDS_KEY: 7.0, STARS_PER_TRIPLE_KEY: 3},
	{MIN_COMBO_KEY: 10, WINDOW_SECONDS_KEY: 5.0, STARS_PER_TRIPLE_KEY: 4},
	{MIN_COMBO_KEY: 15, WINDOW_SECONDS_KEY: 4.0, STARS_PER_TRIPLE_KEY: 5},
	{MIN_COMBO_KEY: 20, WINDOW_SECONDS_KEY: 3.0, STARS_PER_TRIPLE_KEY: 7},
]

var _tiers: Array[Dictionary] = []


static func load_from_config(path: String = CONFIG_PATH) -> ComboScoringRules:
	var rules := ComboScoringRules.new()
	var raw_tiers = null
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			raw_tiers = (parsed as Dictionary).get(TIERS_KEY)

	var errors := rules.set_tiers(raw_tiers)
	if not errors.is_empty():
		push_error("Invalid combo scoring config %s: %s" % [path, "; ".join(errors)])
		rules.set_tiers(DEFAULT_TIERS)
	return rules


## Replaces the tiers when `raw_tiers` is valid and returns the problems found otherwise, leaving the
## current tiers untouched. Tiers must start at ×1 and list strictly increasing `min_combo` values.
func set_tiers(raw_tiers) -> PackedStringArray:
	var errors := PackedStringArray()
	if not raw_tiers is Array or (raw_tiers as Array).is_empty():
		errors.append("`%s` must be a non-empty array" % TIERS_KEY)
		return errors

	var tiers: Array[Dictionary] = []
	var previous_min_combo := 0
	for index in range((raw_tiers as Array).size()):
		var raw_tier = raw_tiers[index]
		if not raw_tier is Dictionary:
			errors.append("tier %d must be an object" % index)
			continue

		var min_combo := int(raw_tier.get(MIN_COMBO_KEY, 0))
		var window_seconds := float(raw_tier.get(WINDOW_SECONDS_KEY, 0.0))
		var stars_per_triple := int(raw_tier.get(STARS_PER_TRIPLE_KEY, -1))
		if index == 0 and min_combo != 1:
			errors.append("the first tier must start at %s 1" % MIN_COMBO_KEY)
		elif min_combo <= previous_min_combo:
			errors.append("tier %d %s must be greater than %d" % [index, MIN_COMBO_KEY, previous_min_combo])
		if window_seconds <= 0.0:
			errors.append("tier %d %s must be positive" % [index, WINDOW_SECONDS_KEY])
		if stars_per_triple < 0:
			errors.append("tier %d %s must not be negative" % [index, STARS_PER_TRIPLE_KEY])

		previous_min_combo = maxi(min_combo, previous_min_combo)
		tiers.append({
			MIN_COMBO_KEY: min_combo,
			WINDOW_SECONDS_KEY: window_seconds,
			STARS_PER_TRIPLE_KEY: stars_per_triple,
		})

	if errors.is_empty():
		_tiers = tiers
	return errors


func get_window_seconds(combo_count: int) -> float:
	return float(_get_tier(combo_count).get(WINDOW_SECONDS_KEY, 0.0))


func get_stars_per_triple(combo_count: int) -> int:
	return int(_get_tier(combo_count).get(STARS_PER_TRIPLE_KEY, 0))


## Combos below ×1 fall into the first tier; only ×1 and above are ever scored.
func _get_tier(combo_count: int) -> Dictionary:
	if _tiers.is_empty():
		return {}

	for index in range(_tiers.size() - 1, -1, -1):
		if combo_count >= int(_tiers[index][MIN_COMBO_KEY]):
			return _tiers[index]
	return _tiers[0]
