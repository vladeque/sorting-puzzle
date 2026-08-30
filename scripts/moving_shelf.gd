class_name MovingShelf
extends Shelf

## Owns the single moving shelf's presentation. Slots, layers, and gameplay capabilities stay in
## Shelf; movement, wrapping, and clipping stay in MovingShelfRow.


func _init() -> void:
	_visual_variant = VISUAL_VARIANT_FLOOR_ONLY


func _apply_visual_variant() -> void:
	# The independent scene opens as a floor-only shelf in the editor. Restore its optional frame
	# when an existing row config explicitly requests the full variant.
	var show_frame := _visual_variant == VISUAL_VARIANT_FULL
	for node_name in ["Shadow", "RightColumnShadow", "BackWall", "BackWallTopShade", "Ceiling"]:
		_set_node_visible(node_name, show_frame)
	super._apply_visual_variant()
