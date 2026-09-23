class_name ThrowingDispenserRules
extends RefCounted

## Runtime reading of the `gameplay_mode: "throwing_dispensers"` level contract. The authoritative
## validator is `scripts/tools/validate_level_solvable.py`; this mirrors its shape rules so the
## runtime fails closed on a malformed level instead of guessing. Like
## `scripts/collapsing_column_rules.gd` it must never fall back to a classic board: a level in this
## mode authors *empty* shelves, so a fallback would open a board with nothing on it and no way to
## fill it.
##
## The mode inverts where items start. A classic level authors every item into a shelf slot; here
## every item starts inside a dispenser mounted above the board, and the player decides when to
## throw the next batch onto the shelves. See `docs/THROWING_DISPENSERS.md`.

const DISPENSERS_KEY := "dispensers"
const CONTENTS_KEY := "contents"
const THROW_COUNT_KEY := "throw_count"
const THROW_SEED_KEY := "throw_seed"
const SLOTS_PER_SHELF := 3
const THROW_SEED_HEX_DIGITS := 16
const HEX_DIGITS := "0123456789abcdef"

## A throw always leaves this many slots open board-wide.
##
## It is a hard rule rather than a config field because it is what keeps the board playable at all:
## `_resolve_move_target_slot()` in `scripts/level.gd` has no swap path, so a move needs a free slot
## to land in. A board with zero free slots has no legal move, and with every item already thrown it
## could never regain one. The player would be left watching the countdown.
const RESERVED_FREE_SLOTS := 1

## Keys that belong to other modes, rejected here rather than silently ignored. Each needs its own
## compatibility task with solver fixtures before content may combine it with this mode.
const EXCLUSIVE_KEYS := ["row_layouts", "column_layout"]


static func is_throwing_dispensers(config: Dictionary) -> bool:
	return GameplayModes.get_mode(config) == GameplayModes.THROWING_DISPENSERS


## Left to right, in authored order. Only meaningful once `validate_config()` has returned no errors.
static func get_dispenser_configs(config: Dictionary) -> Array:
	var dispensers = config.get(DISPENSERS_KEY, [])
	return dispensers if dispensers is Array else []


static func get_contents(dispenser_config: Dictionary) -> PackedStringArray:
	var contents := PackedStringArray()
	var raw = dispenser_config.get(CONTENTS_KEY, [])
	if not raw is Array:
		return contents

	for item_value in raw:
		contents.append(str(item_value))

	return contents


static func get_throw_count(dispenser_config: Dictionary) -> int:
	return int(dispenser_config.get(THROW_COUNT_KEY, 0))


## The authored scatter seed. The whole point of authoring it is that a retry reproduces the run
## exactly, so an unreadable seed is a config error rather than something to replace with a random
## one. `validate_config()` has already rejected that case; this only has to be total.
##
## A 16-hex seed covers the full unsigned 64-bit range, so the top half of it does not fit a signed
## int. `String.hex_to_int()` refuses those values with an engine error rather than wrapping, so the
## digits are accumulated by hand: the final shift wraps in two's complement to a negative int, which
## `RandomNumberGenerator.seed` accepts across its whole signed range. The wrap is deterministic, and
## reproducing the same scatter is all the contract asks for.
##
## Unknown characters contribute nothing rather than raising, because this only has to be total --
## `validate_config()` is what rejects a malformed seed.
static func get_throw_seed(config: Dictionary) -> int:
	var seed_text := str(config.get(THROW_SEED_KEY, ""))
	var value := 0
	for digit in seed_text:
		value = (value << 4) | maxi(HEX_DIGITS.find(digit.to_lower()), 0)

	return value


static func validate_config(config: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var mode = config.get(GameplayModes.GAMEPLAY_MODE_KEY, GameplayModes.CLASSIC)
	if not GameplayModes.is_known(mode):
		errors.append(GameplayModes.describe_unknown_mode())
		return errors

	# Every level runs this guard, so a level in another mode still has to be told that these fields
	# mean nothing there rather than having them quietly ignored.
	if mode != GameplayModes.THROWING_DISPENSERS:
		for owned_key in [DISPENSERS_KEY, THROW_SEED_KEY]:
			if config.has(owned_key):
				errors.append("%s is only valid when %s is '%s'" % [
					owned_key, GameplayModes.GAMEPLAY_MODE_KEY, GameplayModes.THROWING_DISPENSERS
				])
		return errors

	for exclusive_key in EXCLUSIVE_KEYS:
		if config.has(exclusive_key):
			errors.append("%s cannot be combined with %s '%s'" % [
				exclusive_key, GameplayModes.GAMEPLAY_MODE_KEY, GameplayModes.THROWING_DISPENSERS
			])

	errors.append_array(_validate_throw_seed(config))

	var shelves = config.get("shelves", [])
	if not shelves is Array or shelves.is_empty():
		errors.append("shelves must be a non-empty array")
	else:
		for shelf_index in range(shelves.size()):
			errors.append_array(_validate_shelf(shelves[shelf_index], shelf_index + 1))

	var dispensers = config.get(DISPENSERS_KEY)
	if not dispensers is Array or dispensers.is_empty():
		errors.append("%s must be a non-empty array" % DISPENSERS_KEY)
		return errors

	var item_counts := {}
	for dispenser_index in range(dispensers.size()):
		errors.append_array(
			_validate_dispenser(dispensers[dispenser_index], dispenser_index + 1, item_counts)
		)

	errors.append_array(_validate_item_totals(item_counts))

	return errors


## A hand-authored seed is easy to get subtly wrong -- wrong length, uppercase, an `0x` prefix -- and
## every one of those silently changes the scatter the level was tuned against, so the shape is
## checked rather than coerced.
static func _validate_throw_seed(config: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var throw_seed = config.get(THROW_SEED_KEY)
	if not throw_seed is String:
		errors.append("%s must be a %d-digit lowercase hex string" % [
			THROW_SEED_KEY, THROW_SEED_HEX_DIGITS
		])
		return errors

	var seed_text := str(throw_seed)
	if seed_text.length() != THROW_SEED_HEX_DIGITS or seed_text != seed_text.to_lower():
		errors.append("%s must be a %d-digit lowercase hex string" % [
			THROW_SEED_KEY, THROW_SEED_HEX_DIGITS
		])
		return errors

	for digit in seed_text:
		if not digit.is_valid_hex_number():
			errors.append("%s must be a %d-digit lowercase hex string" % [
				THROW_SEED_KEY, THROW_SEED_HEX_DIGITS
			])
			return errors

	return errors


## The board opens empty: every item in the level is inside a dispenser. An authored item on a shelf
## would be an item the solver's playability estimate never accounted for.
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

	for item_value in layer:
		if item_value != null and not str(item_value).is_empty():
			errors.append("Shelf %d must start empty; every item begins in a dispenser" % shelf_number)
			break

	return errors


static func _validate_dispenser(
	dispenser, dispenser_number: int, item_counts: Dictionary
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not dispenser is Dictionary:
		errors.append("Dispenser %d must be an object" % dispenser_number)
		return errors

	var throw_count = dispenser.get(THROW_COUNT_KEY)
	if not _is_positive_integer(throw_count):
		errors.append("Dispenser %d %s must be a positive integer" % [dispenser_number, THROW_COUNT_KEY])

	var contents = dispenser.get(CONTENTS_KEY)
	if not contents is Array or contents.is_empty():
		errors.append("Dispenser %d %s must be a non-empty array" % [dispenser_number, CONTENTS_KEY])
		return errors

	for content_index in range(contents.size()):
		var item_value = contents[content_index]
		# A hole in a dispenser's contents has no meaning: there is nothing for it to throw, and
		# unlike a shelf slot nothing can ever move into it.
		if not item_value is String or str(item_value).is_empty():
			errors.append("Dispenser %d %s entry %d must be an item ID string" % [
				dispenser_number, CONTENTS_KEY, content_index + 1
			])
			continue

		var item_id := str(item_value)
		item_counts[item_id] = int(item_counts.get(item_id, 0)) + 1

	return errors


## The existing whole-level rule, counted from dispensers because that is where every item now
## starts. An item with a count that is not a multiple of three can never be fully cleared.
static func _validate_item_totals(item_counts: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var item_ids := item_counts.keys()
	item_ids.sort()
	for item_id in item_ids:
		var count := int(item_counts[item_id])
		if count % SLOTS_PER_SHELF != 0:
			errors.append("Item '%s' appears %d times, expected a multiple of %d" % [
				item_id, count, SLOTS_PER_SHELF
			])

	return errors


## JSON numbers arrive as floats, so an integer is any whole number rather than only `TYPE_INT`.
static func _is_positive_integer(value) -> bool:
	if not (value is int or value is float):
		return false

	return float(value) == floorf(float(value)) and float(value) >= 1.0
