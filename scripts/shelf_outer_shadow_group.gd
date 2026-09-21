class_name ShelfOuterShadowGroup
extends CanvasGroup

## Level-owned composite for the two exterior casts authored by standard shelves.
##
## Every shelf keeps its real Shadow and RightColumnShadow nodes so standalone previews and shelf
## effects still have stable targets. During gameplay this group mirrors those polygons, normalizes
## their opacity into one mask, and applies the final translucency once to the complete group. The
## mask can overlap freely without stacking the final shadow color at shelf seams.

const BOTTOM_SHADOW_NODE := "Shadow"
const RIGHT_SHADOW_NODE := "RightColumnShadow"
const COMPOSITE_OPACITY := 0.16
const BOTTOM_MASK_MATERIAL := preload(
	"res://assets/shelves/materials/shelf_composite_cast_shadow.tres"
)
const RIGHT_MASK_MATERIAL := preload(
	"res://assets/shelves/materials/shelf_composite_cast_shadow_right.tres"
)

var _entries: Array[Dictionary] = []


func _ready() -> void:
	self_modulate = Color(1.0, 1.0, 1.0, COMPOSITE_OPACITY)
	set_process(false)


func rebuild(shelves: Array[Node]) -> void:
	clear()

	for shelf_node in shelves:
		var shelf := shelf_node as Shelf
		if shelf == null or not shelf.should_show_exterior_shadows():
			continue

		_add_shadow(shelf, BOTTOM_SHADOW_NODE, BOTTOM_MASK_MATERIAL)
		_add_shadow(shelf, RIGHT_SHADOW_NODE, RIGHT_MASK_MATERIAL)
		shelf.set_exterior_shadows_composited(true)

	_sync_entries()
	set_process(not _entries.is_empty())


func clear() -> void:
	for entry in _entries:
		var shelf_ref := entry.get("shelf") as WeakRef
		var shelf := shelf_ref.get_ref() as Shelf if shelf_ref != null else null
		if shelf != null and is_instance_valid(shelf):
			shelf.set_exterior_shadows_composited(false)

		var proxy := entry.get("proxy") as Polygon2D
		if proxy != null and is_instance_valid(proxy):
			proxy.free()

	_entries.clear()
	set_process(false)


func _process(_delta: float) -> void:
	_sync_entries()


func _add_shadow(shelf: Shelf, node_name: String, mask_material: Material) -> void:
	var source := shelf.get_node_or_null(node_name) as Polygon2D
	if source == null or source.polygon.is_empty():
		return

	var proxy := Polygon2D.new()
	proxy.name = "%s_%s" % [shelf.name, node_name]
	proxy.material = mask_material
	proxy.antialiased = source.antialiased
	proxy.polygon = source.polygon
	proxy.uv = source.uv
	proxy.color = source.color
	proxy.z_index = source.z_index
	proxy.z_as_relative = source.z_as_relative
	add_child(proxy)

	_entries.append({
		"shelf": weakref(shelf),
		"source": weakref(source),
		"proxy": proxy,
	})


func _sync_entries() -> void:
	for entry_index in range(_entries.size() - 1, -1, -1):
		var entry := _entries[entry_index]
		var shelf_ref := entry.get("shelf") as WeakRef
		var source_ref := entry.get("source") as WeakRef
		var shelf := shelf_ref.get_ref() as Shelf if shelf_ref != null else null
		var source := source_ref.get_ref() as Polygon2D if source_ref != null else null
		var proxy := entry.get("proxy") as Polygon2D
		if (
			shelf == null
			or source == null
			or proxy == null
			or not is_instance_valid(shelf)
			or not is_instance_valid(source)
			or not is_instance_valid(proxy)
		):
			if proxy != null and is_instance_valid(proxy):
				proxy.queue_free()
			_entries.remove_at(entry_index)
			continue

		proxy.transform = global_transform.affine_inverse() * source.global_transform
		proxy.modulate = source.modulate
		proxy.self_modulate = source.self_modulate
		proxy.visible = shelf.is_visible_in_tree() and shelf.should_show_exterior_shadows()

	set_process(not _entries.is_empty())
