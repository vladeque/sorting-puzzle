class_name CollapsingColumnRules
extends RefCounted

## Runtime reading of the `gameplay_mode` / `column_layout` level contract. The authoritative
## validator is `scripts/tools/validate_level_solvable.py`; this mirrors its shape rules so the
## runtime fails closed on a malformed level instead of guessing. It must never fall back to a
## classic board: the same `shelves` array means something different under each mode.

const GAMEPLAY_MODE_KEY := "gameplay_mode"
const GAMEPLAY_MODE_CLASSIC := "classic"
const GAMEPLAY_MODE_COLLAPSING_COLUMNS := "collapsing_columns"
const COLUMN_LAYOUT_KEY := "column_layout"
const SHELF_COUNTS_KEY := "shelf_counts"
const VISIBLE_SHELVES_KEY := "visible_shelves_per_column"
const SLOTS_PER_SHELF := 3


static func get_gameplay_mode(config: Dictionary) -> String:
	return str(config.get(GAMEPLAY_MODE_KEY, GAMEPLAY_MODE_CLASSIC))


static func is_collapsing(config: Dictionary) -> bool:
	return get_gameplay_mode(config) == GAMEPLAY_MODE_COLLAPSING_COLUMNS


## Left to right. Only meaningful once `validate_config()` has returned no errors.
static func get_column_heights(config: Dictionary) -> Array[int]:
	var heights: Array[int] = []
	var column_layout = config.get(COLUMN_LAYOUT_KEY, {})
	if not column_layout is Dictionary:
		return heights

	var shelf_counts = column_layout.get(SHELF_COUNTS_KEY, [])
	if not shelf_counts is Array:
		return heights

	for shelf_count in shelf_counts:
		heights.append(int(shelf_count))

	return heights


## The authored guaranteed minimum window.
static func get_visible_count(config: Dictionary) -> int:
	var column_layout = config.get(COLUMN_LAYOUT_KEY, {})
	if not column_layout is Dictionary:
		return 1

	return int(column_layout.get(VISIBLE_SHELVES_KEY, 1))


static func validate_config(config: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var mode = config.get(GAMEPLAY_MODE_KEY, GAMEPLAY_MODE_CLASSIC)
	if mode != GAMEPLAY_MODE_CLASSIC and mode != GAMEPLAY_MODE_COLLAPSING_COLUMNS:
		errors.append("%s must be '%s' or '%s'" % [
			GAMEPLAY_MODE_KEY, GAMEPLAY_MODE_CLASSIC, GAMEPLAY_MODE_COLLAPSING_COLUMNS
		])
		return errors

	if mode == GAMEPLAY_MODE_CLASSIC:
		if config.has(COLUMN_LAYOUT_KEY):
			errors.append("%s is only valid when %s is '%s'" % [
				COLUMN_LAYOUT_KEY, GAMEPLAY_MODE_KEY, GAMEPLAY_MODE_COLLAPSING_COLUMNS
			])
		return errors

	for exclusive_key in ["layout_preset", "row_layouts"]:
		if config.has(exclusive_key):
			errors.append("%s cannot be combined with %s '%s'" % [
				exclusive_key, GAMEPLAY_MODE_KEY, GAMEPLAY_MODE_COLLAPSING_COLUMNS
			])

	var shelves = config.get("shelves", [])
	if not shelves is Array:
		errors.append("shelves must be an array")
		return errors

	var column_layout = config.get(COLUMN_LAYOUT_KEY)
	if not column_layout is Dictionary:
		errors.append("%s must be an object" % COLUMN_LAYOUT_KEY)
		return errors

	var shelf_counts = column_layout.get(SHELF_COUNTS_KEY)
	if not shelf_counts is Array or shelf_counts.is_empty():
		errors.append("%s.%s must be a non-empty array of positive integers" % [
			COLUMN_LAYOUT_KEY, SHELF_COUNTS_KEY
		])
	else:
		var total := 0
		var counts_valid := true
		for shelf_count in shelf_counts:
			if not _is_positive_integer(shelf_count):
				counts_valid = false
				errors.append("%s.%s entries must be positive integers" % [COLUMN_LAYOUT_KEY, SHELF_COUNTS_KEY])
				break
			total += int(shelf_count)
		if counts_valid and total != shelves.size():
			errors.append("%s.%s total is %d, expected %d shelves" % [
				COLUMN_LAYOUT_KEY, SHELF_COUNTS_KEY, total, shelves.size()
			])

	var visible_count = column_layout.get(VISIBLE_SHELVES_KEY)
	if (
		not _is_positive_integer(visible_count)
		or int(visible_count) > CollapsingShelfBoard.MAX_VISIBLE_SHELVES_PER_COLUMN
	):
		errors.append("%s.%s must be an integer from 1 to %d" % [
			COLUMN_LAYOUT_KEY, VISIBLE_SHELVES_KEY, CollapsingShelfBoard.MAX_VISIBLE_SHELVES_PER_COLUMN
		])

	for shelf_index in range(shelves.size()):
		errors.append_array(_validate_shelf(shelves[shelf_index], shelf_index + 1))

	return errors


## First-version content restrictions, matching `validate_collapsing_shelf_contract()` in the
## Python validator.
static func _validate_shelf(shelf, shelf_number: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if not shelf is Dictionary:
		errors.append("Shelf %d must be an object" % shelf_number)
		return errors

	if str(shelf.get("type", "standard")) != "standard":
		errors.append("Shelf %d must be a standard shelf" % shelf_number)

	var unlock_after_triples = shelf.get("unlock_after_triples", 0)
	if (unlock_after_triples is int or unlock_after_triples is float) and unlock_after_triples > 0:
		errors.append("Shelf %d is locked; locked shelves are not supported" % shelf_number)

	var sticky_items = shelf.get("sticky_items", [])
	if sticky_items is Array and not sticky_items.is_empty():
		errors.append("Shelf %d has sticky items; sticky items are not supported" % shelf_number)

	var layers = shelf.get("layers", [])
	if not layers is Array or layers.size() != 1:
		errors.append("Shelf %d must have exactly one layer" % shelf_number)
		return errors

	var layer = layers[0]
	if not layer is Array or layer.size() != SLOTS_PER_SHELF:
		errors.append("Shelf %d layer must contain %d slots" % [shelf_number, SLOTS_PER_SHELF])
		return errors

	var has_item := false
	for item_value in layer:
		if item_value != null and not str(item_value).is_empty():
			has_item = true
	if not has_item:
		errors.append("Shelf %d is empty; an authored collapsing shelf needs at least one item" % shelf_number)

	return errors


## JSON numbers arrive as floats, so an integer is any whole number rather than only `TYPE_INT`.
static func _is_positive_integer(value) -> bool:
	if not (value is int or value is float):
		return false

	return float(value) == floorf(float(value)) and float(value) >= 1.0
