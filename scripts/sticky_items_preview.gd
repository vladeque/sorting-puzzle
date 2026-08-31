extends "res://scripts/level.gd"

const PREVIEW_CONFIG := "res://configs/test_levels/sticky_items_preview.json"
const PREVIEW_SCENE := "res://scenes/testing/sticky_items_preview.tscn"

var preview_variant := "both"


func _ready() -> void:
	launched_from_dev_mode = true
	return_menu_scene_path = "res://scenes/main_menu_testing.tscn"
	super._ready()
	$PreviewUI/Controls.variant_changed.connect(_set_preview_variant)
	$PreviewUI/Controls.reset_requested.connect(_reset_preview_if_idle)
	_set_preview_variant(preview_variant)
	_top_hud.set_level_text("STICKY PREVIEW")


func _load_level_config(_level_number: int) -> Dictionary:
	return _load_json_file(PREVIEW_CONFIG)


func _apply_responsive_layout() -> void:
	super._apply_responsive_layout()
	$PreviewUI/Controls.apply_safe_layout(_get_safe_area_margins(get_viewport_rect().size))


func _get_ability_bar_bottom_margin(safe_margins: Vector4) -> float:
	return safe_margins.w + ABILITY_BAR_DESIGN_BOTTOM_MARGIN


func _set_preview_variant(variant: String) -> void:
	preview_variant = variant
	$PreviewUI/Controls.set_variant(variant)
	if variant != "both":
		set_sticky_marker_variant(variant)
		return
	var shelves := _get_all_shelves()
	for shelf_index in range(shelves.size()):
		var items: Array[ShelfItem] = []
		_collect_items_recursive(shelves[shelf_index], items)
		for item in items:
			item.sticky_variant = "pink" if shelf_index < shelves.size() / 2 else "amber"


func _reset_preview_if_idle() -> void:
	if not _is_ability_effect_active() and not _is_resolving_shelves and not _completion_celebration_active:
		_restart_level()


func _restart_level() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	var next := (load(PREVIEW_SCENE) as PackedScene).instantiate()
	next.set("preview_variant", preview_variant)
	get_tree().root.add_child(next)
	get_tree().current_scene = next
	queue_free()
