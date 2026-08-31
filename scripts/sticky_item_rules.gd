class_name StickyItemRules
extends RefCounted

## Authoring validation is separate from presentation. Coordinates always refer to initial items;
## runtime state lives on ShelfItem and survives promotion, never on a permanently sticky slot.
static func validate_config(config: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var shelves = config.get("shelves", [])
	if not shelves is Array:
		return PackedStringArray(["shelves must be an array"])
	for shelf_index in range(shelves.size()):
		var shelf = shelves[shelf_index]
		if not shelf is Dictionary:
			errors.append("Shelf %d must be an object" % (shelf_index + 1))
			continue
		var entries = shelf.get("sticky_items", [])
		if not entries is Array:
			errors.append("Shelf %d sticky_items must be an array" % (shelf_index + 1))
			continue
		if not entries.is_empty() and shelf.get("type", "standard") == "dispenser":
			errors.append("Dispenser shelves cannot contain sticky items")
		var seen := {}
		var layers = shelf.get("layers", [])
		for entry in entries:
			if not entry is Dictionary or entry.size() != 2 or not entry.has_all(["layer", "slot"]):
				errors.append("sticky_items entries need exactly layer and slot")
				continue
			if not _is_index(entry.layer) or not _is_index(entry.slot):
				errors.append("Sticky layer and slot must be non-negative integers")
				continue
			var layer := int(entry.layer)
			var slot := int(entry.slot)
			if seen.has(layer):
				errors.append("Only one sticky item is allowed per shelf layer")
			seen[layer] = true
			if not layers is Array or layer >= layers.size() or not layers[layer] is Array or slot >= layers[layer].size():
				errors.append("Sticky item coordinates are out of range")
			elif not layers[layer][slot] is String or str(layers[layer][slot]).is_empty():
				errors.append("Sticky item must reference an occupied slot")
	return errors


static func _is_index(value: Variant) -> bool:
	# Godot's JSON parser represents JSON numbers as floats, including integer-valued numbers.
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) >= 0.0 and float(value) == floorf(float(value))


static func is_sticky_slot(entries: Array, layer: int, slot: int) -> bool:
	for entry in entries:
		if int(entry.layer) == layer and int(entry.slot) == slot:
			return true
	return false


static func hammer_reserves(items: Array[ShelfItem]) -> Dictionary:
	var counts := {}
	var sticky_counts := {}
	for item in items:
		if not is_instance_valid(item) or item.is_queued_for_deletion():
			continue
		counts[item.item_id] = int(counts.get(item.item_id, 0)) + 1
		if item.is_sticky:
			sticky_counts[item.item_id] = int(sticky_counts.get(item.item_id, 0)) + 1
	var blocked := {}
	for item_id in sticky_counts:
		if int(counts[item_id]) - 3 < 3 * int(sticky_counts[item_id]):
			blocked[item_id] = true
	return blocked
