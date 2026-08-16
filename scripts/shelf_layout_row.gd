class_name ShelfLayoutRow
extends Node2D

const DEFAULT_SMOOTH_SPEED := 60.0

@export_range(1, 12, 1) var shelf_count := 3
@export_range(1, 12, 1) var visible_count := 3
@export_enum("horizontal_wrap", "vertical_wrap") var motion_type := "horizontal_wrap"
@export var speed_pixels_per_second := DEFAULT_SMOOTH_SPEED
@export_enum("right", "left", "down", "up") var direction := "right"
@export_enum("full", "floor_only") var visual_variant := "floor_only"


func to_row_config() -> Dictionary:
	var resolved_direction := direction
	if motion_type == "vertical_wrap" and resolved_direction not in ["down", "up"]:
		resolved_direction = "down"
	elif motion_type == "horizontal_wrap" and resolved_direction not in ["right", "left"]:
		resolved_direction = "right"

	return {
		"shelf_count": shelf_count,
		"visible_count": visible_count,
		"motion": {
			"type": motion_type,
			"speed": speed_pixels_per_second,
			"direction": resolved_direction,
		},
		"visual_variant": visual_variant,
	}
