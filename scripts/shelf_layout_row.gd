class_name ShelfLayoutRow
extends Node2D

@export_range(1, 12, 1) var shelf_count := 3
@export_range(1, 12, 1) var visible_count := 3
@export var motion_type := "horizontal_wrap"
@export var speed_pixels_per_second := 70.0
@export_enum("right", "left") var direction := "right"
@export_enum("full", "floor_only") var visual_variant := "floor_only"


func to_row_config() -> Dictionary:
	return {
		"shelf_count": shelf_count,
		"visible_count": visible_count,
		"motion": {
			"type": motion_type,
			"speed": speed_pixels_per_second,
			"direction": direction,
		},
		"visual_variant": visual_variant,
	}
