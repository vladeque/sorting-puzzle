extends Node2D

const SLOT_COUNT := 3
const SLOT_ITEM_POSITION := Vector2(0, -32)
const SHELF_CELL_VISUAL_SCALE := 1.06
const SHELF_BASE_CELL_SIZE := Vector2(224, 135)
const SHELF_CELL_SIZE := SHELF_BASE_CELL_SIZE * SHELF_CELL_VISUAL_SCALE
const SHELF_BASE_SHARED_EDGE_THICKNESS := 8.0
const SHELF_SHARED_EDGE_THICKNESS := SHELF_BASE_SHARED_EDGE_THICKNESS * SHELF_CELL_VISUAL_SCALE
const SHELF_GRID_STEP := SHELF_CELL_SIZE - Vector2(SHELF_SHARED_EDGE_THICKNESS, SHELF_SHARED_EDGE_THICKNESS)
const BASE_SLOT_SNAP_DISTANCE := 98.0
const BASE_ITEM_PICK_SIZE := Vector2(74, 112)
const ABILITY_HAMMER := &"hammer"
const ABILITY_SHUFFLE := &"shuffle"
const ABILITY_HIGHLIGHT := &"highlight"
const ABILITY_FREEZER := &"freezer"
const HIGHLIGHT_DURATION_SECONDS := 15.0
const FREEZER_DURATION_SECONDS := 30.0
const SHELF_SCENE := preload("res://scenes/shelf.tscn")
const MOVING_SHELF_ROW_SCENE := preload("res://scenes/moving_shelf_row.tscn")
const ITEM_SCENE := preload("res://scenes/item.tscn")
const HAMMER_IMPACT_EFFECT_SCENE := preload("res://scenes/abilities/hammer_impact_effect.tscn")
const UIMotionScript := preload("res://scripts/ui_motion.gd")
const ITEM_SPRITES_CONFIG := "res://configs/item_sprites.json"
const ABILITY_PURCHASE_PRICES_CONFIG := "res://configs/ability_purchase_prices.json"
const LEVEL_CONFIG_TEMPLATE := "res://configs/levels/level_%03d.json"
const DEFAULT_LEVEL_CONFIG := "res://configs/levels/level_001.json"
const LAYOUT_SCENE_TEMPLATE := "res://scenes/layouts/layout_%s.tscn"
const DEFAULT_LAYOUT_PRESET := "grid_3x3"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const ITEM_PLACE_SOUND := preload("res://assets/audio/item_place.wav")
const TRIPLE_CLEAR_SOUND := preload("res://assets/audio/triple_clear.wav")
const REWARD_STAR_TEXTURE := preload("res://assets/ui/reward_star_34_glossy_b.png")
const SHUFFLE_BOX_TEXTURE := preload("res://assets/abilities/ability_shuffle_box.png")
const PAUSE_SETTING_SOUND_EFFECTS := &"sound_effects"
const SHELF_UNLOCK_REQUIREMENT_META := &"unlock_after_triples"
const SHELF_LOCKED_META := &"is_locked"
const LOCKED_OVERLAY_NAME := "LockedOverlay"
const LOCK_REMAINING_LABEL_NAME := "RemainingLabel"
const LOCK_OVERLAY_TWEEN_META := &"lock_overlay_unlock_tween"
const LOCK_LABEL_PULSE_TWEEN_META := &"lock_label_pulse_tween"
const LOCK_LABEL_PREVIOUS_REMAINING_META := &"lock_label_previous_remaining"
const LOCK_UNLOCK_FADE_SECONDS := 0.22
const LOCK_UNLOCK_SCALE := 1.18
const LOCK_LABEL_PULSE_SCALE := Vector2(1.35, 1.35)
const LOCK_LABEL_PULSE_IN_SECONDS := 0.1
const LOCK_LABEL_PULSE_OUT_SECONDS := 0.14
const SHELF_VISUAL_VARIANT_META := &"visual_variant"
const SHELF_TOP_CEILING_CAP_NAME := "TopCeilingCap"
const SHELF_BOTTOM_SHADOW_NAME := "Shadow"
const SHELF_RIGHT_COLUMN_SHADOW_NAME := "RightColumnShadow"
const ROW_LAYOUTS_KEY := "row_layouts"
const ROW_MOTION_HORIZONTAL_WRAP := "horizontal_wrap"
const ROW_MOTION_VERTICAL_WRAP := "vertical_wrap"
const SHELF_VISUAL_VARIANT_FULL := "full"
const SHELF_VISUAL_VARIANT_FLOOR_ONLY := "floor_only"
const LAYOUT_ROW_VERTICAL_EPSILON := 8.0
const SHELF_TOP_STACK_VERTICAL_EPSILON := 4.0
const SHELF_TOP_STACK_MIN_HORIZONTAL_OVERLAP := 0.35
const ABILITY_BAR_HEIGHT := 126.0
const ABILITY_BAR_DESIGN_BOTTOM_MARGIN := 96.0
const ABILITY_BAR_SAFE_BOTTOM_PADDING := 24.0
const SHELVES_TOP_CLEARANCE := 128.0
const SHELVES_BOTTOM_CLEARANCE := 52.0
const SHELVES_SIDE_MARGIN := 16.0
const SHELVES_MIN_LAYOUT_SCALE := 0.45
const SHELVES_MAX_LAYOUT_SCALE := 1.5
const STAR_REWARD_SIZE := Vector2(28, 28)
const STAR_REWARD_DROP_DURATION_SECONDS := 0.2
const STAR_REWARD_FLY_DURATION_SECONDS := 0.62
const STAR_REWARD_STAGGER_SECONDS := 0.035
const COMBO_PRAISE_WORDS := [
	"",
	"",
	"Cool",
	"Great",
	"Awesome",
	"Amazing",
	"Fantastic",
	"Incredible",
	"Spectacular",
	"Unstoppable",
	"Legendary",
	"Epic",
	"Brilliant",
	"Masterful",
	"Supreme",
	"Phenomenal",
	"Mythic",
	"Majestic",
	"Radiant",
	"Divine",
	"Transcendent",
]
const COMBO_PRAISE_LABEL_SIZE := Vector2(360, 82)
const COMBO_PRAISE_OFFSET := Vector2(0, -88)
const COMBO_PRAISE_EDGE_PADDING := 16.0
const COMBO_PRAISE_DURATION_SECONDS := 2.0
const COMBO_PRAISE_FADE_SECONDS := 0.32
const COMBO_PRAISE_POP_SCALE := Vector2(1.14, 1.14)
const SHUFFLE_BOX_DISPLAY_WIDTH := 272.0
const SHUFFLE_BOX_OPENING_OFFSET := Vector2(0.0, -52.0)
const SHUFFLE_BOX_POP_DURATION_SECONDS := 0.16
const SHUFFLE_BOX_OUT_DURATION_SECONDS := 0.12
const SHUFFLE_ITEM_GATHER_DURATION_SECONDS := 0.34
const SHUFFLE_ITEM_RETURN_DURATION_SECONDS := 0.38
const SHUFFLE_ITEM_STAGGER_SECONDS := 0.008
const SHUFFLE_ITEM_MAX_STAGGER_SECONDS := 0.18
const SHUFFLE_ITEM_FLY_IN_Z_INDEX := 28
const SHUFFLE_ITEM_FLY_OUT_Z_INDEX := 32
const SHUFFLE_BOX_Z_INDEX := 30
const SHUFFLE_ITEM_INSIDE_SCALE := Vector2(0.25, 0.25)
const DEFAULT_ABILITY_PURCHASE_PRICES := {
	ABILITY_HAMMER: 100,
	ABILITY_SHUFFLE: 100,
	ABILITY_HIGHLIGHT: 100,
	ABILITY_FREEZER: 100,
}
@export var slot_snap_distance := BASE_SLOT_SNAP_DISTANCE * SHELF_CELL_VISUAL_SCALE
@export var item_pick_size := BASE_ITEM_PICK_SIZE * SHELF_CELL_VISUAL_SCALE
@export var drag_start_distance := 12.0
@export var layer_promotion_duration_seconds := 0.22
@export var item_move_duration_seconds := 0.16
@export var highlight_outline_color := Color(1.0, 0.86, 0.18, 1.0)
@export var selected_highlight_outline_color := Color(1.0, 0.96, 0.36, 1.0)
@export_range(0.0, 8.0, 0.25) var highlight_outline_width := 6.0
@export_range(1.0, 1.5, 0.01) var highlight_item_scale := 1.15
@export var match_gather_duration_seconds := 0.18
@export var match_shrink_duration_seconds := 0.16
@export_range(0.25, 30.0, 0.25) var combo_window_seconds := 8.0
@export var level_duration_seconds := 300.0
@export_range(-40.0, 6.0, 0.5) var item_place_volume_db := -5.0
@export_range(-40.0, 6.0, 0.5) var triple_clear_volume_db := -5.0
@export var selected_level := 1
@export var launched_from_dev_mode := false
@export_file("*.tscn") var return_menu_scene_path := MAIN_MENU_SCENE

var _slots: Array[Node2D] = []
var _item_textures: Dictionary = {}
var _max_layer_count := 1
var _dragged_item: ShelfItem
var _origin_slot: Node2D
var _drag_offset := Vector2.ZERO
var _drag_layer: Node2D
var _background: Control
var _chapter_artwork: TextureRect
var _shelves_root: Node2D
var _top_hud: LevelTopHud
var _star_reward_effect_layer: Control
var _failure_screen: LevelFailureScreen
var _completion_screen: LevelCompletionScreen
var _pause_menu_overlay: PauseMenu
var _leave_confirmation_overlay: LeaveConfirmationMenu
var _ability_purchase_overlay: AbilityPurchaseMenu
var _ability_bar: AbilityBar
var _ability_uses: Dictionary = {
	ABILITY_HAMMER: 3,
	ABILITY_SHUFFLE: 3,
	ABILITY_HIGHLIGHT: 3,
	ABILITY_FREEZER: 3,
}
var _ability_purchase_prices: Dictionary = DEFAULT_ABILITY_PURCHASE_PRICES.duplicate()
var _ability_purchase_pending_id := StringName()
var _ability_purchase_was_paused := false
var _time_remaining := 0.0
var _has_player_started_timer := false
var _level_failed := false
var _level_completed := false
var _level_paused := false
var _returning_to_menu := false
var _life_spent_for_run := false
var _highlight_timer := 0.0
var _freezer_time_remaining := 0.0
var _app_interrupted := false
var _combo_count := 0
var _combo_time_remaining := 0.0
var _stars := 0
var _highlighted_items: Array[ShelfItem] = []
var _layout_preset := DEFAULT_LAYOUT_PRESET
var _rng := RandomNumberGenerator.new()
var _pressed_item: ShelfItem
var _pressed_origin_slot: Node2D
var _press_position := Vector2.ZERO
var _selected_item: ShelfItem
var _selected_slot: Node2D
var _is_resolving_shelves := false
var _shelves_pending_resolve: Array[Node] = []
var _shelves_resolving_ids: Array[int] = []
var _clearing_item_ids: Array[int] = []
var _transitioning_item_ids: Array[int] = []
var _item_place_audio_player: AudioStreamPlayer
var _triple_clear_audio_player: AudioStreamPlayer
var _sound_effects_enabled := true
var _triples_cleared := 0
var _shelves_layout_scale := 1.0
var _hammer_effect_active := false
var _shuffle_effect_active := false


func _ready() -> void:
	_background = get_node("Background") as Control
	_chapter_artwork = get_node("Background/ChapterArtwork") as TextureRect
	_shelves_root = get_node("Shelves") as Node2D
	_drag_layer = get_node("DragLayer") as Node2D
	_top_hud = get_node("UI/TopHud") as LevelTopHud
	_failure_screen = get_node("UI/FailureScreen") as LevelFailureScreen
	_completion_screen = get_node("UI/CompletionScreen") as LevelCompletionScreen
	_pause_menu_overlay = get_node("UI/PauseMenuOverlay") as PauseMenu
	_leave_confirmation_overlay = get_node("UI/LeaveConfirmationOverlay") as LeaveConfirmationMenu
	_ability_purchase_overlay = get_node("UI/AbilityPurchaseOverlay") as AbilityPurchaseMenu
	_ability_bar = get_node("UI/AbilityBar") as AbilityBar
	_failure_screen.visible = false
	_completion_screen.visible = false
	_pause_menu_overlay.visible = false
	_leave_confirmation_overlay.visible = false
	_ability_purchase_overlay.visible = false
	_setup_star_reward_effect_layer()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_rng.randomize()
	_setup_audio_players()
	_setup_pause_menu_buttons()
	_setup_completion_buttons()
	_setup_failure_screen()
	_setup_ability_purchase_menu()
	_setup_ability_buttons()
	_load_ability_purchase_prices()
	_load_item_textures()
	_apply_chapter_background()
	_apply_level_config(_load_level_config(selected_level))
	_collect_slots()
	_update_level_label()
	_update_timer_label()
	_update_star_counter_label()
	_update_ability_buttons()
	_update_pause_menu_button()


func _apply_chapter_background() -> void:
	var chapter_id := ChapterCatalog.get_chapter_id_for_level(selected_level)
	if chapter_id.is_empty():
		push_warning("Level %d is not assigned to a chapter." % selected_level)
		return
	var uses_artwork := ChapterCatalog.get_gameplay_background_mode(chapter_id) == "artwork"
	_chapter_artwork.visible = uses_artwork
	for legacy_node_path in ["Wall", "PlayWall", "Baseboard", "Floor"]:
		var legacy_node := _background.get_node(legacy_node_path) as CanvasItem
		legacy_node.visible = not uses_artwork
	if uses_artwork and _chapter_artwork.has_method("show_chapter"):
		_chapter_artwork.call("show_chapter", chapter_id)
	else:
		_chapter_artwork.texture = null


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_margins := _get_safe_area_margins(viewport_size)
	if _background != null:
		_background.position = Vector2.ZERO
		_background.size = viewport_size

	_top_hud.apply_safe_layout(safe_margins, viewport_size)
	_layout_ability_bar(safe_margins)
	_failure_screen.apply_safe_layout(safe_margins, viewport_size)
	_completion_screen.apply_safe_layout(safe_margins, viewport_size)
	_pause_menu_overlay.apply_safe_layout(safe_margins, viewport_size)
	_leave_confirmation_overlay.apply_safe_layout(safe_margins, viewport_size)
	if _ability_purchase_overlay != null:
		_ability_purchase_overlay.apply_safe_layout(safe_margins, viewport_size)
	_layout_star_reward_effect_layer(viewport_size)
	_layout_shelves(viewport_size, safe_margins)


func _setup_star_reward_effect_layer() -> void:
	var ui_layer := get_node("UI") as CanvasLayer
	if ui_layer == null:
		return

	_star_reward_effect_layer = Control.new()
	_star_reward_effect_layer.name = "StarRewardEffectLayer"
	_star_reward_effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_star_reward_effect_layer)
	if _failure_screen != null:
		ui_layer.move_child(_star_reward_effect_layer, _failure_screen.get_index())


func _layout_star_reward_effect_layer(viewport_size: Vector2) -> void:
	if _star_reward_effect_layer == null:
		return

	_star_reward_effect_layer.anchor_left = 0.0
	_star_reward_effect_layer.anchor_top = 0.0
	_star_reward_effect_layer.anchor_right = 0.0
	_star_reward_effect_layer.anchor_bottom = 0.0
	_star_reward_effect_layer.offset_left = 0.0
	_star_reward_effect_layer.offset_top = 0.0
	_star_reward_effect_layer.offset_right = viewport_size.x
	_star_reward_effect_layer.offset_bottom = viewport_size.y


func _get_safe_area_margins(viewport_size: Vector2) -> Vector4:
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe_area := DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return Vector4.ZERO

	var scale := Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	var safe_end := safe_area.position + safe_area.size
	return Vector4(
		maxf(float(safe_area.position.x) * scale.x, 0.0),
		maxf(float(safe_area.position.y) * scale.y, 0.0),
		maxf(float(window_size.x - safe_end.x) * scale.x, 0.0),
		maxf(float(window_size.y - safe_end.y) * scale.y, 0.0)
	)


func _layout_ability_bar(safe_margins: Vector4) -> void:
	if _ability_bar == null:
		return

	var bottom_margin := _get_ability_bar_bottom_margin(safe_margins)
	_ability_bar.anchor_left = 0.0
	_ability_bar.anchor_top = 1.0
	_ability_bar.anchor_right = 1.0
	_ability_bar.anchor_bottom = 1.0
	_ability_bar.offset_left = safe_margins.x
	_ability_bar.offset_top = -(bottom_margin + ABILITY_BAR_HEIGHT)
	_ability_bar.offset_right = -safe_margins.z
	_ability_bar.offset_bottom = -bottom_margin
	# Usable width after safe-area side insets, not raw viewport width, so the compact/regular
	# breakpoint is based on the space actually available to the bar.
	_ability_bar.apply_responsive_layout(get_viewport_rect().size.x - safe_margins.x - safe_margins.z)


func _get_ability_bar_bottom_margin(safe_margins: Vector4) -> float:
	return maxf(ABILITY_BAR_DESIGN_BOTTOM_MARGIN, safe_margins.w + ABILITY_BAR_SAFE_BOTTOM_PADDING)


func _layout_shelves(viewport_size: Vector2, safe_margins: Vector4) -> void:
	if _shelves_root == null:
		return

	var play_top := safe_margins.y + SHELVES_TOP_CLEARANCE
	var ability_top := viewport_size.y - _get_ability_bar_bottom_margin(safe_margins) - ABILITY_BAR_HEIGHT
	var play_bottom := maxf(play_top, ability_top - SHELVES_BOTTOM_CLEARANCE)
	var play_left := safe_margins.x + SHELVES_SIDE_MARGIN
	var play_right := viewport_size.x - safe_margins.z - SHELVES_SIDE_MARGIN
	var shelf_bounds := _get_shelves_local_bounds()
	_shelves_layout_scale = _get_shelves_layout_scale(shelf_bounds, play_left, play_right, play_top, play_bottom)
	_shelves_root.scale = Vector2.ONE * _shelves_layout_scale

	var scaled_bounds := _get_scaled_rect(shelf_bounds, _shelves_layout_scale)
	var root_position := Vector2((play_left + play_right) * 0.5, (play_top + play_bottom) * 0.5)
	if shelf_bounds.size.y > 0.0:
		var bounds_center_x := scaled_bounds.position.x + scaled_bounds.size.x * 0.5
		root_position.x = (play_left + play_right) * 0.5 - bounds_center_x

		var min_root_x := play_left - scaled_bounds.position.x
		var max_root_x := play_right - (scaled_bounds.position.x + scaled_bounds.size.x)
		if min_root_x <= max_root_x:
			root_position.x = clampf(root_position.x, min_root_x, max_root_x)

		var bounds_center_y := scaled_bounds.position.y + scaled_bounds.size.y * 0.5
		root_position.y = (play_top + play_bottom) * 0.5 - bounds_center_y

		var min_root_y := play_top - scaled_bounds.position.y
		var max_root_y := play_bottom - (scaled_bounds.position.y + scaled_bounds.size.y)
		if min_root_y <= max_root_y:
			root_position.y = clampf(root_position.y, min_root_y, max_root_y)
		else:
			root_position.y = min_root_y

	_shelves_root.position = root_position


func _get_shelves_layout_scale(
	shelf_bounds: Rect2,
	play_left: float,
	play_right: float,
	play_top: float,
	play_bottom: float
) -> float:
	if shelf_bounds.size.x <= 0.0 or shelf_bounds.size.y <= 0.0:
		return 1.0

	var play_width := maxf(play_right - play_left, 1.0)
	var play_height := maxf(play_bottom - play_top, 1.0)
	var fit_scale := minf(play_width / shelf_bounds.size.x, play_height / shelf_bounds.size.y)
	return clampf(fit_scale, SHELVES_MIN_LAYOUT_SCALE, SHELVES_MAX_LAYOUT_SCALE)


func _get_scaled_rect(rect: Rect2, scale_value: float) -> Rect2:
	return Rect2(rect.position * scale_value, rect.size * scale_value)


func _get_shelves_local_bounds() -> Rect2:
	if _shelves_root == null:
		return Rect2()

	var bounds := Rect2()
	var has_bounds := false
	for child in _shelves_root.get_children():
		var child_rect := _get_shelves_root_child_bounds(child)
		if child_rect.size.x <= 0.0 or child_rect.size.y <= 0.0:
			continue

		if has_bounds:
			bounds = bounds.merge(child_rect)
		else:
			bounds = child_rect
			has_bounds = true

	return bounds if has_bounds else Rect2()


func _get_shelves_root_child_bounds(child: Node) -> Rect2:
	var moving_row := child as MovingShelfRow
	if moving_row != null:
		return Rect2(moving_row.position, moving_row.size)

	var shelf_node := child as Node2D
	if shelf_node != null and _is_shelf_node(shelf_node):
		return Rect2(shelf_node.position - SHELF_CELL_SIZE * 0.5, SHELF_CELL_SIZE)

	return Rect2()


func _setup_audio_players() -> void:
	_item_place_audio_player = _create_audio_player("ItemPlaceAudio", ITEM_PLACE_SOUND, item_place_volume_db)
	_triple_clear_audio_player = _create_audio_player("TripleClearAudio", TRIPLE_CLEAR_SOUND, triple_clear_volume_db)


func _create_audio_player(player_name: String, stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player


func _play_item_place_sound() -> void:
	if not _sound_effects_enabled or _item_place_audio_player == null:
		return

	_item_place_audio_player.stop()
	_item_place_audio_player.play()


func _play_triple_clear_sound() -> void:
	if not _sound_effects_enabled or _triple_clear_audio_player == null:
		return

	_triple_clear_audio_player.stop()
	_triple_clear_audio_player.play()


func _stop_sound_effects() -> void:
	if _item_place_audio_player != null:
		_item_place_audio_player.stop()

	if _triple_clear_audio_player != null:
		_triple_clear_audio_player.stop()


func _process(delta: float) -> void:
	if _level_completed:
		return

	if _level_failed:
		return

	if _level_paused:
		return

	if _app_interrupted:
		return

	var countdown_delta := _update_freezer_timer(delta)

	if _is_ability_effect_active():
		return

	_update_combo_timer(delta)
	_update_highlight_timer(delta)
	_clear_drag_drop_selection_if_unavailable()

	if not _has_player_started_timer:
		return

	_time_remaining = maxf(_time_remaining - countdown_delta, 0.0)
	_update_timer_label()

	if _time_remaining <= 0.0:
		_fail_level()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_app_interrupted = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_app_interrupted = false


func _exit_tree() -> void:
	_clear_freezer()


func _input(event: InputEvent) -> void:
	if _level_failed or _level_completed:
		return

	if _level_paused:
		return

	if _is_ability_effect_active():
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		var pointer_position := get_global_mouse_position()
		if mouse_event.pressed:
			_handle_press_at(pointer_position)
		else:
			_handle_release_at(pointer_position)
	elif event is InputEventMouseMotion:
		_handle_motion_at(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		var pointer_position := _screen_position_to_global(touch_event.position)
		if touch_event.pressed:
			_handle_press_at(pointer_position)
		else:
			_handle_release_at(pointer_position)
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_handle_motion_at(_screen_position_to_global(drag_event.position))


## System back / Android back / Escape (UI-003). Unlike _input() above, this always runs regardless
## of pause/failed/completed state, implementing one topmost-state-first back stack:
##   1. Leave Confirmation returns to Pause.
##   2. Ability Purchase closes and restores the state it opened from.
##   3. Pause closes and resumes active gameplay.
##   4. Completion invokes its Continue route; Failure invokes its Main Menu route.
##   5. Otherwise (active gameplay) opens Pause.
## Every branch reuses the exact handler its equivalent button already calls, so this can never
## spend a life, coin, or star by itself, and behaves identically to tapping that button. If any
## overlay/result screen is mid open()/close() transition, the press is dropped rather than acted
## on, so a rapid double-press can never race two transitions or double-navigate.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return

	if _is_any_overlay_transitioning():
		get_viewport().set_input_as_handled()
		return

	get_viewport().set_input_as_handled()
	if _leave_confirmation_overlay.visible:
		_on_leave_confirmation_close_pressed()
	elif _ability_purchase_overlay != null and _ability_purchase_overlay.visible:
		_on_ability_purchase_close_pressed()
	elif _pause_menu_overlay.visible:
		_on_pause_menu_continue_pressed()
	elif _level_completed:
		_on_completion_next_pressed()
	elif _level_failed:
		_on_failure_main_menu_pressed()
	else:
		_on_pause_menu_button_pressed()


func _is_any_overlay_transitioning() -> bool:
	if _leave_confirmation_overlay.is_transitioning() or _pause_menu_overlay.is_transitioning():
		return true
	if _ability_purchase_overlay != null and _ability_purchase_overlay.is_transitioning():
		return true
	return _completion_screen.is_transitioning() or _failure_screen.is_transitioning()


func _load_item_textures() -> void:
	_item_textures.clear()

	var config := _load_json_file(ITEM_SPRITES_CONFIG)
	var items := config.get("items", []) as Array
	for item_data in items:
		var item_config := item_data as Dictionary
		if item_config == null:
			continue

		var item_id := str(item_config.get("id", ""))
		var texture_path := str(item_config.get("texture", ""))
		if item_id.is_empty() or texture_path.is_empty():
			continue

		var texture := load(texture_path) as Texture2D
		if texture != null:
			_item_textures[item_id] = texture


func _load_ability_purchase_prices() -> void:
	_ability_purchase_prices = DEFAULT_ABILITY_PURCHASE_PRICES.duplicate()
	if not FileAccess.file_exists(ABILITY_PURCHASE_PRICES_CONFIG):
		return

	var config := _load_json_file(ABILITY_PURCHASE_PRICES_CONFIG)
	var prices := config.get("prices", {}) as Dictionary
	if prices == null:
		push_warning("Ability purchase prices config must define a prices object.")
		return

	for ability_id in DEFAULT_ABILITY_PURCHASE_PRICES.keys():
		var ability_key := String(ability_id)
		_ability_purchase_prices[ability_id] = maxi(int(prices.get(ability_key, _ability_purchase_prices[ability_id])), 0)


func _load_level_config(level_number: int) -> Dictionary:
	var level_config_path := LEVEL_CONFIG_TEMPLATE % level_number
	if not FileAccess.file_exists(level_config_path):
		push_warning("Missing %s. Using %s." % [level_config_path, DEFAULT_LEVEL_CONFIG])
		level_config_path = DEFAULT_LEVEL_CONFIG

	return _load_json_file(level_config_path)


func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open config: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	var config := parsed as Dictionary
	if config == null:
		push_error("Config is not a JSON object: %s" % path)
		return {}

	return config


func _apply_level_config(config: Dictionary) -> void:
	level_duration_seconds = float(config.get("time_seconds", level_duration_seconds))
	_time_remaining = level_duration_seconds
	_has_player_started_timer = false
	_max_layer_count = 1
	_level_failed = false
	_level_completed = false
	_level_paused = false
	_app_interrupted = false
	_life_spent_for_run = false
	_triples_cleared = 0
	_stars = 0
	_clear_star_reward_effects()
	_reset_combo()
	_update_star_counter_label()
	_returning_to_menu = false
	_failure_screen.visible = false
	_completion_screen.visible = false
	if _pause_menu_overlay != null:
		_pause_menu_overlay.visible = false
	if _leave_confirmation_overlay != null:
		_leave_confirmation_overlay.visible = false
	if _ability_purchase_overlay != null:
		_ability_purchase_overlay.visible = false
	_ability_purchase_pending_id = StringName()
	_is_resolving_shelves = false
	_shelves_pending_resolve.clear()
	_shelves_resolving_ids.clear()

	_clear_ability_highlights()
	_clear_freezer()
	_load_ability_uses()

	var shelves_config := config.get("shelves", []) as Array
	_layout_preset = str(config.get("layout_preset", DEFAULT_LAYOUT_PRESET))
	var shelves := get_node("Shelves") as Node2D
	_clear_shelves(shelves)

	var row_layouts := config.get(ROW_LAYOUTS_KEY, []) as Array
	if row_layouts != null and not row_layouts.is_empty():
		_add_row_layout_shelves(shelves, shelves_config, row_layouts)
	else:
		_add_preset_layout_shelves(shelves, shelves_config)

	_update_shelf_perspective_edges()
	_apply_responsive_layout()
	_set_moving_shelf_rows_paused(false)
	_update_locked_shelves()
	_resolve_shelves(_get_all_shelves())
	_check_level_completed()
	_update_pause_menu_button()


func _clear_shelves(shelves: Node) -> void:
	for child in shelves.get_children():
		shelves.remove_child(child)
		child.free()


func _add_preset_layout_shelves(shelves: Node2D, shelves_config: Array) -> void:
	if _add_layout_template_shelves(shelves, shelves_config, _layout_preset):
		return

	push_warning("Layout preset '%s' has no compatible template scene. Using %s." % [_layout_preset, DEFAULT_LAYOUT_PRESET])
	var shelf_positions := _get_grid_layout_positions(3, shelves_config.size())
	for shelf_index in range(shelves_config.size()):
		var shelf_config := shelves_config[shelf_index] as Dictionary
		if shelf_config == null:
			continue

		var shelf := _add_shelf(shelves, shelf_index + 1, shelf_positions[shelf_index])
		_apply_shelf_row_placement(shelf, _get_grid_row_shelf_placement(shelf_index, shelves_config.size(), 3))
		_configure_shelf_from_config(shelf, shelf_config)


func _add_row_layout_shelves(shelves: Node2D, shelves_config: Array, row_layouts: Array) -> void:
	var configured_shelf_count := _get_row_layout_shelf_count(row_layouts)
	if configured_shelf_count != shelves_config.size():
		push_warning(
			"%s shelf_count total must match shelves size. Using %s."
			% [ROW_LAYOUTS_KEY, DEFAULT_LAYOUT_PRESET]
		)
		_add_preset_layout_shelves(shelves, shelves_config)
		return

	if _has_mixed_row_layout_motion_types(row_layouts):
		push_warning(
			"%s cannot mix horizontal and vertical moving shelves in one level. Using %s."
			% [ROW_LAYOUTS_KEY, DEFAULT_LAYOUT_PRESET]
		)
		_add_preset_layout_shelves(shelves, shelves_config)
		return

	var row_origin_y := -float(row_layouts.size() - 1) * SHELF_GRID_STEP.y * 0.5
	var shelf_config_index := 0
	for row_index in range(row_layouts.size()):
		var row_config := row_layouts[row_index] as Dictionary
		if row_config == null:
			continue

		var row_shelf_count := int(row_config.get("shelf_count", 0))
		var row_center_y := row_origin_y + float(row_index) * SHELF_GRID_STEP.y
		var is_moving := _is_row_layout_moving(row_config)
		var visible_count := _get_row_visible_count(row_config, row_shelf_count, is_moving)
		var visual_variant := _get_row_visual_variant(row_config, is_moving)

		if is_moving:
			_add_moving_shelf_row(
				shelves,
				shelves_config,
				shelf_config_index,
				row_shelf_count,
				visible_count,
				Vector2(0.0, row_center_y),
				row_config,
				visual_variant
			)
		else:
			_add_static_shelf_row(
				shelves,
				shelves_config,
				shelf_config_index,
				row_shelf_count,
				row_center_y,
				visual_variant
			)

		shelf_config_index += row_shelf_count


func _get_row_layout_shelf_count(row_layouts: Array) -> int:
	var shelf_count := 0
	for row_layout in row_layouts:
		var row_config := row_layout as Dictionary
		if row_config == null:
			return -1

		var row_shelf_count := int(row_config.get("shelf_count", 0))
		if row_shelf_count <= 0:
			return -1

		shelf_count += row_shelf_count

	return shelf_count


func _has_mixed_row_layout_motion_types(row_layouts: Array) -> bool:
	var moving_motion_type := ""
	for row_layout in row_layouts:
		var row_config := row_layout as Dictionary
		if row_config == null or not _is_row_layout_moving(row_config):
			continue

		var row_motion_type := _get_row_motion_type(row_config)
		if moving_motion_type != "" and row_motion_type != moving_motion_type:
			return true

		moving_motion_type = row_motion_type

	return false


func _add_static_shelf_row(
	shelves: Node2D,
	shelves_config: Array,
	start_shelf_index: int,
	row_shelf_count: int,
	row_center_y: float,
	visual_variant: String
) -> void:
	var row_origin_x := -float(row_shelf_count - 1) * SHELF_GRID_STEP.x * 0.5
	for row_shelf_index in range(row_shelf_count):
		var shelf_config := shelves_config[start_shelf_index + row_shelf_index] as Dictionary
		if shelf_config == null:
			continue

		var shelf_number := start_shelf_index + row_shelf_index + 1
		var shelf_position := Vector2(row_origin_x + float(row_shelf_index) * SHELF_GRID_STEP.x, row_center_y)
		var shelf := _add_shelf(shelves, shelf_number, shelf_position)
		_apply_shelf_visual_variant(shelf, visual_variant)
		_apply_shelf_row_placement(shelf, _get_row_shelf_placement(row_shelf_index, row_shelf_count))
		_configure_shelf_from_config(shelf, shelf_config)


func _add_moving_shelf_row(
	shelves: Node2D,
	shelves_config: Array,
	start_shelf_index: int,
	row_shelf_count: int,
	visible_count: int,
	row_center_position: Vector2,
	row_config: Dictionary,
	visual_variant: String
) -> void:
	var row := MOVING_SHELF_ROW_SCENE.instantiate() as MovingShelfRow
	row.name = "MovingShelfRow%02d" % (start_shelf_index + 1)
	row.configure(
		visible_count,
		SHELF_GRID_STEP,
		SHELF_CELL_SIZE,
		_get_row_motion_type(row_config),
		_get_row_motion_speed(row_config),
		_get_row_motion_direction(row_config)
	)
	var visible_size := row.get_visible_size()
	row.position = row_center_position - visible_size * 0.5
	shelves.add_child(row)

	for row_shelf_index in range(row_shelf_count):
		var shelf_config := shelves_config[start_shelf_index + row_shelf_index] as Dictionary
		if shelf_config == null:
			continue

		var shelf_number := start_shelf_index + row_shelf_index + 1
		var shelf := _add_shelf(row, shelf_number, Vector2.ZERO)
		row.add_shelf(shelf)
		_apply_shelf_visual_variant(shelf, visual_variant)
		_apply_shelf_row_placement(shelf, Shelf.ROW_PLACEMENT_MIDDLE)
		_configure_shelf_from_config(shelf, shelf_config, false)


func _configure_shelf_from_config(shelf: Shelf, shelf_config: Dictionary, allow_locked := true) -> void:
	var layers := shelf_config.get("layers", []) as Array
	_max_layer_count = maxi(_max_layer_count, layers.size())
	_add_configured_layers(shelf, layers)
	_configure_shelf_unlock(shelf, shelf_config, allow_locked)


func _is_row_layout_moving(row_config: Dictionary) -> bool:
	var motion := _get_row_motion_config(row_config)
	var motion_type := str(motion.get("type", "")).to_lower()
	if motion_type == ROW_MOTION_HORIZONTAL_WRAP or motion_type == ROW_MOTION_VERTICAL_WRAP:
		return true

	if row_config.has("moving"):
		return bool(row_config.get("moving", false))

	return _get_row_motion_speed(row_config) > 0.0


func _get_row_motion_config(row_config: Dictionary) -> Dictionary:
	var motion := row_config.get("motion", {}) as Dictionary
	return {} if motion == null else motion


func _get_row_motion_speed(row_config: Dictionary) -> float:
	var motion := _get_row_motion_config(row_config)
	return maxf(float(motion.get("speed", row_config.get("speed", 0.0))), 0.0)


func _get_row_motion_type(row_config: Dictionary) -> String:
	var motion := _get_row_motion_config(row_config)
	var motion_type := str(motion.get("type", ROW_MOTION_HORIZONTAL_WRAP)).to_lower()
	if motion_type == ROW_MOTION_VERTICAL_WRAP:
		return ROW_MOTION_VERTICAL_WRAP

	return ROW_MOTION_HORIZONTAL_WRAP


func _get_row_motion_direction(row_config: Dictionary) -> int:
	var motion := _get_row_motion_config(row_config)
	var motion_type := _get_row_motion_type(row_config)
	var default_direction := "down" if motion_type == ROW_MOTION_VERTICAL_WRAP else "right"
	var direction_name := str(motion.get("direction", row_config.get("direction", default_direction))).to_lower()
	if motion_type == ROW_MOTION_VERTICAL_WRAP:
		return -1 if direction_name == "up" else 1

	return -1 if direction_name == "left" else 1


func _get_row_visible_count(row_config: Dictionary, row_shelf_count: int, is_moving: bool) -> int:
	var default_visible_count := mini(3, row_shelf_count) if is_moving else row_shelf_count
	var visible_count := int(row_config.get("visible_count", default_visible_count))
	return clampi(visible_count, 1, row_shelf_count)


func _get_row_visual_variant(row_config: Dictionary, is_moving: bool) -> String:
	var default_variant := SHELF_VISUAL_VARIANT_FLOOR_ONLY if is_moving else SHELF_VISUAL_VARIANT_FULL
	return str(row_config.get("visual_variant", default_variant)).to_lower()


func _add_layout_template_shelves(shelves: Node2D, shelves_config: Array, layout_preset: String) -> bool:
	var layout_scene_path := _get_layout_scene_path(layout_preset)
	if not ResourceLoader.exists(layout_scene_path):
		return false

	var layout_scene := load(layout_scene_path) as PackedScene
	if layout_scene == null:
		push_warning("Layout preset '%s' could not load from %s. Using %s." % [layout_preset, layout_scene_path, DEFAULT_LAYOUT_PRESET])
		return false

	var layout_template := layout_scene.instantiate() as Node2D
	if layout_template == null:
		push_warning("Layout preset '%s' is not a Node2D scene. Using %s." % [layout_preset, DEFAULT_LAYOUT_PRESET])
		return false

	var template_shelf_count := _get_layout_template_shelf_count(layout_template)
	if template_shelf_count != shelves_config.size():
		push_warning(
			"Layout preset '%s' expects %s shelves, got %s. Using %s."
			% [layout_preset, template_shelf_count, shelves_config.size(), DEFAULT_LAYOUT_PRESET]
		)
		layout_template.queue_free()
		return false

	var shelf_config_index := 0
	var marker_placements := _get_layout_template_marker_placements(layout_template)
	var moving_motion_type := ""
	for layout_node in layout_template.get_children():
		if layout_node is ShelfLayoutRow:
			var layout_row := layout_node as ShelfLayoutRow
			var row_shelf_count := layout_row.shelf_count
			var visible_count := clampi(layout_row.visible_count, 1, row_shelf_count)
			var row_config := layout_row.to_row_config()
			var row_motion_type := _get_row_motion_type(row_config)
			if moving_motion_type != "" and row_motion_type != moving_motion_type:
				push_warning(
					"Layout preset '%s' mixes horizontal and vertical moving shelves. Using %s."
					% [layout_preset, DEFAULT_LAYOUT_PRESET]
				)
				layout_template.queue_free()
				return false

			moving_motion_type = row_motion_type
			var visual_variant := _get_row_visual_variant(row_config, true)
			_add_moving_shelf_row(
				shelves,
				shelves_config,
				shelf_config_index,
				row_shelf_count,
				visible_count,
				layout_row.global_position,
				row_config,
				visual_variant
			)
			shelf_config_index += row_shelf_count
		elif _is_layout_shelf_marker(layout_node):
			var shelf_config := shelves_config[shelf_config_index] as Dictionary
			if shelf_config != null:
				var shelf_marker := layout_node as Node2D
				var shelf := _add_shelf(shelves, shelf_config_index + 1, shelf_marker.global_position)
				_apply_shelf_row_placement(
					shelf,
					str(marker_placements.get(shelf_marker.get_instance_id(), Shelf.ROW_PLACEMENT_MIDDLE))
				)
				_configure_shelf_from_config(shelf, shelf_config)

			shelf_config_index += 1

	layout_template.queue_free()
	return true


func _get_layout_scene_path(layout_preset: String) -> String:
	return LAYOUT_SCENE_TEMPLATE % layout_preset


func _get_layout_template_shelf_count(layout_template: Node2D) -> int:
	var shelf_count := 0
	for layout_node in layout_template.get_children():
		if layout_node is ShelfLayoutRow:
			var layout_row := layout_node as ShelfLayoutRow
			if layout_row.shelf_count <= 0:
				return -1

			shelf_count += layout_row.shelf_count
		elif _is_layout_shelf_marker(layout_node):
			shelf_count += 1

	return shelf_count


func _is_layout_shelf_marker(layout_node: Node) -> bool:
	return layout_node is Marker2D and str(layout_node.name).begins_with("Shelf")


func _get_layout_template_marker_placements(layout_template: Node2D) -> Dictionary:
	var rows: Array = []
	for layout_node in layout_template.get_children():
		if not _is_layout_shelf_marker(layout_node):
			continue

		var marker := layout_node as Node2D
		var row_index := _find_layout_marker_row_index(rows, marker.global_position.y)
		if row_index == -1:
			rows.append({
				"y": marker.global_position.y,
				"markers": [marker],
			})
		else:
			var existing_row := rows[row_index] as Dictionary
			var row_markers_to_append := existing_row.get("markers", []) as Array
			row_markers_to_append.append(marker)

	var placements := {}
	for row_entry in rows:
		var row_data := row_entry as Dictionary
		if row_data == null:
			continue

		var sorted_markers := row_data.get("markers", []) as Array
		sorted_markers.sort_custom(Callable(self, "_sort_layout_markers_by_x"))
		for row_shelf_index in range(sorted_markers.size()):
			var sorted_marker := sorted_markers[row_shelf_index] as Node2D
			if sorted_marker != null:
				placements[sorted_marker.get_instance_id()] = _get_row_shelf_placement(row_shelf_index, sorted_markers.size())

	return placements


func _find_layout_marker_row_index(rows: Array, marker_y: float) -> int:
	for row_index in range(rows.size()):
		var row := rows[row_index] as Dictionary
		if row == null:
			continue

		if absf(float(row.get("y", marker_y)) - marker_y) <= LAYOUT_ROW_VERTICAL_EPSILON:
			return row_index

	return -1


func _sort_layout_markers_by_x(left: Node, right: Node) -> bool:
	var left_marker := left as Node2D
	var right_marker := right as Node2D
	if left_marker == null or right_marker == null:
		return str(left.name) < str(right.name)

	if not is_equal_approx(left_marker.global_position.x, right_marker.global_position.x):
		return left_marker.global_position.x < right_marker.global_position.x

	return str(left_marker.name) < str(right_marker.name)


func _get_grid_row_shelf_placement(shelf_index: int, shelf_count: int, columns: int) -> String:
	var row_start_index := floori(float(shelf_index) / float(columns)) * columns
	var row_shelf_index := shelf_index - row_start_index
	var row_shelf_count := mini(columns, shelf_count - row_start_index)
	return _get_row_shelf_placement(row_shelf_index, row_shelf_count)


func _get_row_shelf_placement(row_shelf_index: int, row_shelf_count: int) -> String:
	if row_shelf_count <= 1:
		return Shelf.ROW_PLACEMENT_MIDDLE

	if row_shelf_index <= 0:
		return Shelf.ROW_PLACEMENT_LEFT

	if row_shelf_index >= row_shelf_count - 1:
		return Shelf.ROW_PLACEMENT_RIGHT

	return Shelf.ROW_PLACEMENT_MIDDLE


func _apply_shelf_visual_variant(shelf: Node2D, visual_variant: String) -> void:
	var shelf_cell := shelf as Shelf
	match visual_variant:
		SHELF_VISUAL_VARIANT_FULL, SHELF_VISUAL_VARIANT_FLOOR_ONLY:
			if shelf_cell != null:
				shelf_cell.set_visual_variant(visual_variant)
			else:
				shelf.set_meta(SHELF_VISUAL_VARIANT_META, visual_variant)
		_:
			if shelf_cell != null:
				shelf_cell.set_visual_variant(SHELF_VISUAL_VARIANT_FULL)
			else:
				shelf.set_meta(SHELF_VISUAL_VARIANT_META, SHELF_VISUAL_VARIANT_FULL)
			push_warning("Unknown shelf visual_variant '%s'. Using full shelf." % visual_variant)


func _apply_shelf_row_placement(shelf: Node2D, row_placement: String) -> void:
	var shelf_cell := shelf as Shelf
	if shelf_cell != null:
		shelf_cell.set_row_placement(row_placement)


func _update_shelf_perspective_edges() -> void:
	var shelves := _get_all_shelves()
	for shelf_node in shelves:
		var shelf := shelf_node as Node2D
		if shelf == null:
			continue

		_set_shelf_top_ceiling_cap_visible(shelf, not _has_stacked_shelf_above(shelf, shelves))
		_set_shelf_bottom_shadow_visible(shelf)
		_set_shelf_right_column_shadow_visible(shelf)


func _has_stacked_shelf_above(shelf: Node2D, shelves: Array[Node]) -> bool:
	var shelf_position := _get_shelf_root_local_position(shelf)
	for other_node in shelves:
		var other_shelf := other_node as Node2D
		if other_shelf == null or other_shelf == shelf:
			continue

		var other_position := _get_shelf_root_local_position(other_shelf)
		if other_position.y >= shelf_position.y - SHELF_TOP_STACK_VERTICAL_EPSILON:
			continue

		if _shelf_cells_stack_horizontally(shelf_position.x, other_position.x):
			return true

	return false


func _shelf_cells_stack_horizontally(first_x: float, second_x: float) -> bool:
	var overlap_width := maxf(SHELF_CELL_SIZE.x - absf(first_x - second_x), 0.0)
	return overlap_width / SHELF_CELL_SIZE.x >= SHELF_TOP_STACK_MIN_HORIZONTAL_OVERLAP


func _get_shelf_root_local_position(shelf: Node2D) -> Vector2:
	if _shelves_root != null and shelf.is_inside_tree():
		return _shelves_root.to_local(shelf.global_position)

	return shelf.position


func _set_shelf_top_ceiling_cap_visible(shelf: Node2D, should_show: bool) -> void:
	var shelf_cell := shelf as Shelf
	if shelf_cell != null:
		shelf_cell.set_top_ceiling_cap_visible(should_show)
		return

	var cap := shelf.get_node_or_null(SHELF_TOP_CEILING_CAP_NAME) as CanvasItem
	if cap == null:
		return

	var visual_variant := str(shelf.get_meta(SHELF_VISUAL_VARIANT_META, SHELF_VISUAL_VARIANT_FULL))
	cap.visible = should_show and visual_variant == SHELF_VISUAL_VARIANT_FULL


func _set_shelf_bottom_shadow_visible(shelf: Node2D) -> void:
	var shadow := shelf.get_node_or_null(SHELF_BOTTOM_SHADOW_NAME) as CanvasItem
	if shadow == null:
		return

	var visual_variant := str(shelf.get_meta(SHELF_VISUAL_VARIANT_META, SHELF_VISUAL_VARIANT_FULL))
	shadow.visible = visual_variant == SHELF_VISUAL_VARIANT_FULL


func _set_shelf_right_column_shadow_visible(shelf: Node2D) -> void:
	var shadow := shelf.get_node_or_null(SHELF_RIGHT_COLUMN_SHADOW_NAME) as CanvasItem
	if shadow == null:
		return

	var visual_variant := str(shelf.get_meta(SHELF_VISUAL_VARIANT_META, SHELF_VISUAL_VARIANT_FULL))
	shadow.visible = visual_variant == SHELF_VISUAL_VARIANT_FULL


func _get_grid_layout_positions(columns: int, shelf_count: int) -> Array[Vector2]:
	var spacing := SHELF_GRID_STEP

	var rows := ceili(float(shelf_count) / float(columns))
	var origin := Vector2(
		-(columns - 1) * spacing.x * 0.5,
		-(rows - 1) * spacing.y * 0.5
	)
	var positions: Array[Vector2] = []
	for shelf_index in range(shelf_count):
		var column := shelf_index % columns
		var row := floori(float(shelf_index) / float(columns))
		positions.append(origin + Vector2(column * spacing.x, row * spacing.y))

	return positions


func _add_shelf(parent: Node, shelf_number: int, shelf_position: Vector2) -> Shelf:
	var shelf := SHELF_SCENE.instantiate() as Shelf
	shelf.name = "Shelf%02d" % shelf_number
	shelf.position = shelf_position
	shelf.scale = Vector2.ONE * SHELF_CELL_VISUAL_SCALE
	shelf.set_visual_variant(SHELF_VISUAL_VARIANT_FULL)
	shelf.set_row_placement(Shelf.ROW_PLACEMENT_MIDDLE)
	parent.add_child(shelf)

	return shelf


func _add_configured_layers(shelf: Shelf, layers: Array) -> void:
	for layer_index in range(layers.size()):
		var item_ids := layers[layer_index] as Array
		if item_ids == null:
			push_warning("%s layer %s is not an array." % [shelf.name, layer_index + 1])
			continue

		if item_ids.size() != SLOT_COUNT:
			push_warning("%s layer %s expected %s slots, found %s." % [shelf.name, layer_index + 1, SLOT_COUNT, item_ids.size()])

		var layer_slots := _get_front_slots(shelf) if layer_index == 0 else shelf.add_back_layer(layer_index, _get_front_slots(shelf))
		var fill_count = mini(SLOT_COUNT, item_ids.size())
		for slot_index in range(fill_count):
			_add_configured_item(layer_slots[slot_index], item_ids[slot_index], layer_index, slot_index)


func _configure_shelf_unlock(shelf: Node2D, shelf_config: Dictionary, allow_locked := true) -> void:
	var unlock_after_triples := maxi(int(shelf_config.get("unlock_after_triples", 0)), 0)
	if unlock_after_triples > 0 and not allow_locked:
		push_warning("%s is in a moving row. Locked moving shelves are not allowed." % shelf.name)
		unlock_after_triples = 0

	shelf.set_meta(SHELF_UNLOCK_REQUIREMENT_META, unlock_after_triples)
	shelf.set_meta(SHELF_LOCKED_META, false)


func _record_triples_cleared(triple_count: int) -> int:
	if triple_count <= 0:
		return 0

	_triples_cleared += triple_count
	var earned_stars := 0
	if _has_player_started_timer and not _level_failed and not _level_completed:
		earned_stars = _extend_combo(triple_count)
		_add_stars(earned_stars)

	var newly_unlocked_shelves := _update_locked_shelves()
	_resolve_shelves(newly_unlocked_shelves)
	return earned_stars


func _update_locked_shelves() -> Array[Node]:
	var newly_unlocked_shelves: Array[Node] = []
	for shelf in _get_all_shelves():
		var shelf_node := shelf as Node2D
		if shelf_node == null:
			continue

		var was_locked := _is_shelf_locked(shelf_node)
		var should_lock := _get_shelf_unlock_requirement(shelf_node) > _triples_cleared
		shelf_node.set_meta(SHELF_LOCKED_META, should_lock)
		_update_shelf_lock_overlay(shelf_node, should_lock)
		_update_shelf_input_pickable(shelf_node, not should_lock)

		if was_locked and not should_lock:
			newly_unlocked_shelves.append(shelf_node)

	return newly_unlocked_shelves


func _get_shelf_unlock_requirement(shelf: Node) -> int:
	if shelf == null:
		return 0

	return maxi(int(shelf.get_meta(SHELF_UNLOCK_REQUIREMENT_META, 0)), 0)


func _is_shelf_locked(shelf: Node) -> bool:
	return shelf != null and bool(shelf.get_meta(SHELF_LOCKED_META, false))


func _is_slot_locked(slot: Node) -> bool:
	return _is_shelf_locked(_get_owning_shelf(slot))


func _is_slot_drag_drop_targetable(slot: Node) -> bool:
	return slot != null and _is_shelf_drag_drop_targetable(_get_owning_shelf(slot))


func _is_shelf_drag_drop_targetable(shelf: Node) -> bool:
	var shelf_node := shelf as Node2D
	if shelf_node == null:
		return false

	if _is_shelf_locked(shelf_node):
		return false

	var moving_row := _get_moving_shelf_row(shelf_node)
	return moving_row == null or moving_row.is_shelf_inside_visible_window(shelf_node)


func _get_moving_shelf_row(node: Node) -> MovingShelfRow:
	var current := node.get_parent()
	while current != null:
		var moving_row := current as MovingShelfRow
		if moving_row != null:
			return moving_row

		current = current.get_parent()

	return null


func _clear_drag_drop_selection_if_unavailable() -> void:
	if _selected_slot != null and not _is_slot_drag_drop_targetable(_selected_slot):
		_clear_selected_item()

	if _pressed_origin_slot != null and not _is_slot_drag_drop_targetable(_pressed_origin_slot):
		_pressed_item = null
		_pressed_origin_slot = null


## Locked-shelf feedback (UI-003 P3): pulses the remaining-count label when it decreases and plays a
## one-shot fade/scale when the shelf unlocks, instead of the count and overlay changing instantly.
## _update_shelf_input_pickable() (called separately by every caller of this function) is never
## gated on this animation, so the shelf becomes interactable immediately regardless of how long the
## unlock animation takes to finish.
func _update_shelf_lock_overlay(shelf: Node2D, should_lock: bool) -> void:
	var overlay := shelf.get_node_or_null(LOCKED_OVERLAY_NAME) as Node2D
	if overlay == null:
		return

	if should_lock:
		# A freshly (re)locked shelf always starts from a clean visual state -- never retains a
		# scale/modulate change from a prior unlock animation on this same overlay instance.
		UIMotionScript.stop_tween(overlay, LOCK_OVERLAY_TWEEN_META)
		overlay.visible = true
		overlay.modulate = Color.WHITE
		overlay.scale = Vector2.ONE

		var remaining := maxi(_get_shelf_unlock_requirement(shelf) - _triples_cleared, 0)
		var count_label := overlay.get_node_or_null(LOCK_REMAINING_LABEL_NAME) as Label
		if count_label != null:
			_update_lock_remaining_label(count_label, remaining)
		return

	if not overlay.visible:
		return

	_play_shelf_unlock_animation(overlay)


func _play_shelf_unlock_animation(overlay: Node2D) -> void:
	overlay.modulate = Color.WHITE
	overlay.scale = Vector2.ONE

	var tween := UIMotionScript.retween(overlay, LOCK_OVERLAY_TWEEN_META)
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 0.0, LOCK_UNLOCK_FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(overlay, "scale", Vector2.ONE * LOCK_UNLOCK_SCALE, LOCK_UNLOCK_FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		overlay.visible = false
		overlay.modulate = Color.WHITE
		overlay.scale = Vector2.ONE
	)


func _update_lock_remaining_label(count_label: Label, remaining: int) -> void:
	var remaining_text := str(remaining)
	count_label.text = remaining_text

	var font_size := 34
	if remaining_text.length() >= 3:
		font_size = 24
	elif remaining_text.length() == 2:
		font_size = 30

	count_label.add_theme_font_size_override("font_size", font_size)

	var previous_remaining := int(count_label.get_meta(LOCK_LABEL_PREVIOUS_REMAINING_META, remaining))
	count_label.set_meta(LOCK_LABEL_PREVIOUS_REMAINING_META, remaining)
	if remaining < previous_remaining:
		_pulse_lock_remaining_label(count_label)


func _pulse_lock_remaining_label(count_label: Label) -> void:
	count_label.pivot_offset = count_label.size * 0.5
	count_label.scale = Vector2.ONE

	var tween := UIMotionScript.retween(count_label, LOCK_LABEL_PULSE_TWEEN_META)
	tween.tween_property(count_label, "scale", LOCK_LABEL_PULSE_SCALE, LOCK_LABEL_PULSE_IN_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(count_label, "scale", Vector2.ONE, LOCK_LABEL_PULSE_OUT_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _update_shelf_input_pickable(shelf: Node, should_enable: bool) -> void:
	for item in _get_shelf_items(shelf):
		if item == null or not is_instance_valid(item):
			continue

		item.input_pickable = should_enable and not _is_item_busy(item)


func _add_configured_item(slot: Node2D, item_value, layer_index: int, slot_index: int) -> void:
	if item_value == null:
		return

	var item_id := str(item_value)
	if item_id.is_empty():
		return

	var item := ITEM_SCENE.instantiate() as ShelfItem
	item.name = "Item%sL%sS%s" % [item_id.to_pascal_case(), layer_index + 1, slot_index + 1]
	item.item_id = StringName(item_id)
	item.texture = _item_textures.get(item_id)
	if item.texture == null:
		push_warning("No texture configured for item '%s'." % item_id)

	item.position = SLOT_ITEM_POSITION
	slot.add_child(item)

	if layer_index > 0:
		var shelf := _get_owning_shelf(slot) as Shelf
		if shelf != null:
			shelf.configure_back_layer_item(item, layer_index == Shelf.FIRST_BACK_LAYER_INDEX)


func _collect_slots() -> void:
	_slots.clear()

	for shelf in _get_all_shelves():
		for slot in _get_front_slots(shelf):
			_slots.append(slot)


func _get_front_slots(shelf: Node) -> Array[Node2D]:
	var front_slots: Array[Node2D] = []
	for child in shelf.get_children():
		var slot := child as Node2D
		if slot != null and slot.name.begins_with("Slot"):
			front_slots.append(slot)

	return front_slots


func _update_timer_label() -> void:
	var remaining_seconds := ceili(_time_remaining)
	var minutes := floori(float(remaining_seconds) / 60.0)
	var seconds := remaining_seconds % 60
	_top_hud.set_timer_text("%02d:%02d" % [minutes, seconds])


func _update_level_label() -> void:
	var local_level := ChapterCatalog.get_local_level_number(selected_level)
	_top_hud.set_level_text("LEVEL %d" % (local_level if local_level > 0 else selected_level))


func _update_star_counter_label() -> void:
	_top_hud.set_star_count(_stars)


func _add_stars(star_count: int) -> void:
	if star_count <= 0:
		return

	_stars += star_count
	_update_star_counter_label()


func _extend_combo(triple_count: int) -> int:
	if triple_count <= 0:
		return 0

	var earned_stars := 0
	var combo_is_active := _combo_count > 0 and _combo_time_remaining > 0.0
	for _triple_index in range(triple_count):
		if not combo_is_active:
			_combo_count = 1
			combo_is_active = true
		else:
			_combo_count += 1

		earned_stars += _combo_count

	_combo_time_remaining = maxf(combo_window_seconds, 0.0)
	_update_combo_hud()
	return earned_stars


func _update_combo_timer(delta: float) -> void:
	if _combo_count <= 0:
		return

	_combo_time_remaining = maxf(_combo_time_remaining - delta, 0.0)
	if _combo_time_remaining <= 0.0:
		_reset_combo()
	else:
		_update_combo_hud()


func _reset_combo() -> void:
	_combo_count = 0
	_combo_time_remaining = 0.0
	_update_combo_hud()


func _update_combo_hud() -> void:
	var should_show := _combo_count > 0 and not _level_failed and not _level_completed
	_top_hud.set_combo(should_show, _combo_count, _get_combo_time_ratio())


func _get_combo_time_ratio() -> float:
	if combo_window_seconds <= 0.0:
		return 0.0

	return clampf(_combo_time_remaining / combo_window_seconds, 0.0, 1.0)


func _start_level_timer_from_player_action() -> void:
	if _has_player_started_timer:
		return

	_has_player_started_timer = true


func _fail_level() -> void:
	_level_failed = true
	_level_paused = false
	_clear_freezer()
	_spend_campaign_life_for_run("failed")
	_reset_combo()
	_clear_selected_item()
	_set_moving_shelf_rows_paused(true)
	_update_ability_buttons()
	_update_pause_menu_button()

	if _dragged_item != null and _origin_slot != null:
		_dragged_item.set_contact_shadow_enabled(true)
		_place_item_in_slot(_dragged_item, _origin_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	_pressed_item = null
	_pressed_origin_slot = null
	_failure_screen.open()
	_pause_menu_overlay.visible = false
	_leave_confirmation_overlay.visible = false
	if _ability_purchase_overlay != null:
		_ability_purchase_overlay.visible = false


func _complete_level() -> void:
	if not launched_from_dev_mode and not PlayerProgress.complete_level(selected_level, _stars):
		push_error("Level completion could not be committed; keeping the level active.")
		return

	_level_completed = true
	_level_paused = false
	_clear_freezer()
	_reset_combo()
	_clear_selected_item()
	_set_moving_shelf_rows_paused(true)
	if _dragged_item != null:
		_dragged_item.set_contact_shadow_enabled(true)
	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	_pressed_item = null
	_pressed_origin_slot = null
	_clear_ability_highlights()
	_update_ability_buttons()
	_update_pause_menu_button()
	_completion_screen.set_earned_stars(_stars)
	_completion_screen.open()
	_pause_menu_overlay.visible = false
	_leave_confirmation_overlay.visible = false
	if _ability_purchase_overlay != null:
		_ability_purchase_overlay.visible = false


func _check_level_completed() -> void:
	if _level_failed or _level_completed:
		return

	if _get_all_items().is_empty():
		_complete_level()


func _return_to_main_menu() -> void:
	_level_paused = false
	_returning_to_menu = true
	_clear_freezer()
	var menu_scene_path := return_menu_scene_path if return_menu_scene_path != "" else MAIN_MENU_SCENE
	var error := get_tree().change_scene_to_file(menu_scene_path)
	if error != OK:
		_returning_to_menu = false
		push_error("Could not return to main menu: %s" % menu_scene_path)


func _spend_campaign_life_for_run(outcome: String = "left") -> void:
	if launched_from_dev_mode or _life_spent_for_run:
		return

	if PlayerProgress.spend_life(selected_level, outcome):
		_life_spent_for_run = true
	else:
		push_warning("Could not spend campaign life for level %d." % selected_level)


func _setup_pause_menu_buttons() -> void:
	_top_hud.pause_pressed.connect(_on_pause_menu_button_pressed)
	_pause_menu_overlay.leave_pressed.connect(_on_pause_menu_leave_pressed)
	_pause_menu_overlay.continue_pressed.connect(_on_pause_menu_continue_pressed)
	_pause_menu_overlay.setting_toggled.connect(_on_pause_menu_setting_toggled)
	_sound_effects_enabled = not _pause_menu_overlay.is_setting_disabled(PAUSE_SETTING_SOUND_EFFECTS)
	_leave_confirmation_overlay.close_requested.connect(_on_leave_confirmation_close_pressed)
	_leave_confirmation_overlay.continue_pressed.connect(_on_leave_confirmation_continue_pressed)
	_leave_confirmation_overlay.leave_pressed.connect(_on_leave_confirmation_leave_pressed)


func _setup_completion_buttons() -> void:
	_completion_screen.next_pressed.connect(_on_completion_next_pressed)


func _setup_failure_screen() -> void:
	_failure_screen.main_menu_pressed.connect(_on_failure_main_menu_pressed)


func _setup_ability_purchase_menu() -> void:
	if _ability_purchase_overlay == null:
		return

	_ability_purchase_overlay.close_pressed.connect(_on_ability_purchase_close_pressed)
	_ability_purchase_overlay.buy_pressed.connect(_on_ability_purchase_buy_pressed)
	_ability_purchase_overlay.ad_pressed.connect(_on_ability_purchase_ad_pressed)


func _on_completion_next_pressed() -> void:
	if not _level_completed or _returning_to_menu:
		return

	_return_to_main_menu()


func _on_failure_main_menu_pressed() -> void:
	if not _level_failed or _returning_to_menu:
		return

	_return_to_main_menu()


func _on_pause_menu_setting_toggled(setting_id: StringName, is_disabled: bool) -> void:
	if setting_id != PAUSE_SETTING_SOUND_EFFECTS:
		return

	_sound_effects_enabled = not is_disabled
	if not _sound_effects_enabled:
		_stop_sound_effects()


func _on_pause_menu_button_pressed() -> void:
	if _level_failed or _level_completed:
		return

	_open_pause_menu()


func _open_pause_menu() -> void:
	_cancel_active_interaction()
	_level_paused = true
	_set_moving_shelf_rows_paused(true)
	_pause_menu_overlay.open()
	if _ability_purchase_overlay != null:
		_ability_purchase_overlay.close()
	_update_ability_buttons()
	_update_pause_menu_button()


func _on_pause_menu_leave_pressed() -> void:
	_open_leave_confirmation()


func _open_leave_confirmation() -> void:
	_cancel_active_interaction()
	_level_paused = true
	_set_moving_shelf_rows_paused(true)
	_leave_confirmation_overlay.set_star_count(_stars)
	_pause_menu_overlay.close()
	_leave_confirmation_overlay.open()
	if _ability_purchase_overlay != null:
		_ability_purchase_overlay.close()
	_update_ability_buttons()
	_update_pause_menu_button()


func _on_leave_confirmation_leave_pressed() -> void:
	if _returning_to_menu:
		return

	_spend_campaign_life_for_run()
	_return_to_main_menu()


## Close/system-back on Leave Confirmation pops back to Pause rather than resuming gameplay
## directly -- the explicit green Continue action (_on_leave_confirmation_continue_pressed) is the
## one that resumes gameplay. These used to collapse into the same outcome; UI-003 distinguishes
## "pop this confirmation" from "resume."
func _on_leave_confirmation_close_pressed() -> void:
	_leave_confirmation_overlay.close()
	_pause_menu_overlay.open()
	_update_ability_buttons()
	_update_pause_menu_button()


func _on_leave_confirmation_continue_pressed() -> void:
	_close_pause_menu()


func _on_pause_menu_continue_pressed() -> void:
	_close_pause_menu()


func _open_ability_purchase_menu(ability_id: StringName) -> void:
	if _ability_purchase_overlay == null:
		return

	_cancel_active_interaction()
	_ability_purchase_pending_id = ability_id
	_ability_purchase_was_paused = _level_paused
	_level_paused = true
	_set_moving_shelf_rows_paused(true)
	_refresh_ability_purchase_offer()
	_pause_menu_overlay.close()
	_leave_confirmation_overlay.close()
	_ability_purchase_overlay.open()
	_update_ability_buttons()
	_update_pause_menu_button()


func _refresh_ability_purchase_offer() -> void:
	if _ability_purchase_overlay == null or _ability_purchase_pending_id == StringName():
		return

	_ability_purchase_overlay.set_offer(
		_get_ability_icon_texture(_ability_purchase_pending_id),
		_get_ability_purchase_price(_ability_purchase_pending_id),
		PlayerProgress.get_coins()
	)


## should_resume=true (the close/X button and ui_cancel) restores whatever state Ability Purchase was
## opened from: Pause if it was opened from Pause, or active gameplay otherwise. should_resume=false
## (a successful paid purchase) deliberately leaves gameplay running regardless of where it was
## opened from -- the caller already resumed gameplay itself before applying the paid ability.
func _close_ability_purchase_menu(should_resume: bool = true) -> void:
	if _ability_purchase_overlay != null:
		_ability_purchase_overlay.close()

	_ability_purchase_pending_id = StringName()
	if should_resume and not _level_failed and not _level_completed:
		if _ability_purchase_was_paused:
			_pause_menu_overlay.open()
		else:
			_level_paused = false
			_set_moving_shelf_rows_paused(false)

	_update_ability_buttons()
	_update_pause_menu_button()


func _on_ability_purchase_close_pressed() -> void:
	_close_ability_purchase_menu()


func _on_ability_purchase_buy_pressed() -> void:
	if _ability_purchase_pending_id == StringName():
		return

	var ability_id := _ability_purchase_pending_id
	var price := _get_ability_purchase_price(ability_id)
	if PlayerProgress.get_coins() < price:
		_refresh_ability_purchase_offer()
		return
	if not _can_apply_ability(ability_id):
		_refresh_ability_purchase_offer()
		return

	_level_paused = false
	_set_moving_shelf_rows_paused(false)
	if not PlayerProgress.spend_coins(price, "ability_use"):
		_level_paused = true
		_set_moving_shelf_rows_paused(true)
		_refresh_ability_purchase_offer()
		return
	if not _apply_paid_ability(ability_id):
		_level_paused = true
		_set_moving_shelf_rows_paused(true)
		push_error("Paid ability passed preflight but could not start: %s" % String(ability_id))
		_refresh_ability_purchase_offer()
		return

	_close_ability_purchase_menu(false)


func _on_ability_purchase_ad_pressed() -> void:
	pass


func _close_pause_menu() -> void:
	_level_paused = false
	_set_moving_shelf_rows_paused(false)
	_pause_menu_overlay.close()
	_leave_confirmation_overlay.close()
	if _ability_purchase_overlay != null:
		_ability_purchase_overlay.close()
	_ability_purchase_pending_id = StringName()
	_update_ability_buttons()
	_update_pause_menu_button()


func _update_pause_menu_button() -> void:
	_top_hud.set_pause_enabled(not (_level_failed or _level_completed or _level_paused))


func _handle_press_at(pointer_global_position: Vector2) -> void:
	if _dragged_item != null:
		return

	var clicked_item := _find_item_at_position(pointer_global_position)
	if _selected_item != null:
		var target_slot := _find_clicked_slot(pointer_global_position, clicked_item)
		if target_slot != null:
			var moved_item := _move_item_to_slot(_selected_item, _selected_slot, target_slot)
			_clear_selected_item()
			if moved_item:
				get_viewport().set_input_as_handled()
				return
		else:
			_clear_selected_item()

	if clicked_item == null:
		return

	_start_level_timer_from_player_action()
	_pressed_item = clicked_item
	_pressed_origin_slot = clicked_item.get_parent() as Node2D
	_press_position = pointer_global_position
	get_viewport().set_input_as_handled()


func _handle_motion_at(pointer_global_position: Vector2) -> void:
	if _dragged_item != null:
		_move_active_drag(pointer_global_position)
		return

	if _pressed_item == null:
		return

	if not _is_slot_drag_drop_targetable(_pressed_origin_slot):
		_pressed_item = null
		_pressed_origin_slot = null
		return

	if pointer_global_position.distance_to(_press_position) < drag_start_distance:
		return

	_clear_selected_item()
	_begin_drag(_pressed_item, pointer_global_position)
	get_viewport().set_input_as_handled()


func _handle_release_at(pointer_global_position: Vector2) -> void:
	if _dragged_item != null:
		_finish_active_drag(pointer_global_position)
		_pressed_item = null
		_pressed_origin_slot = null
		return

	if _pressed_item == null:
		return

	if _pressed_item.get_parent() == _pressed_origin_slot and _is_slot_drag_drop_targetable(_pressed_origin_slot):
		_set_selected_item(_pressed_item, _pressed_origin_slot)

	_pressed_item = null
	_pressed_origin_slot = null
	get_viewport().set_input_as_handled()


func _begin_drag(item: ShelfItem, pointer_global_position: Vector2) -> void:
	var origin_slot := item.get_parent() as Node2D
	if not _is_slot_drag_drop_targetable(origin_slot):
		return

	_dragged_item = item
	_origin_slot = origin_slot
	_drag_offset = item.global_position - pointer_global_position
	item.reparent(_drag_layer, true)
	item.z_index = 100
	item.set_contact_shadow_enabled(false)
	item.global_position = pointer_global_position + _drag_offset


func _move_active_drag(pointer_global_position: Vector2) -> void:
	if _dragged_item == null:
		return

	_dragged_item.global_position = pointer_global_position + _drag_offset
	get_viewport().set_input_as_handled()


func _finish_active_drag(pointer_global_position: Vector2) -> void:
	if _dragged_item == null:
		return

	var item := _dragged_item
	var origin_slot := _origin_slot
	var target_slot := _find_nearest_slot(pointer_global_position)
	item.set_contact_shadow_enabled(true)
	if target_slot == null:
		_return_item_to_origin_after_animation(item, origin_slot)
	elif target_slot == origin_slot:
		_return_item_to_origin_after_animation(item, origin_slot)
	else:
		if not _move_item_to_slot(item, origin_slot, target_slot):
			_return_item_to_origin_after_animation(item, origin_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	get_viewport().set_input_as_handled()


func _move_item_to_slot(item: ShelfItem, origin_slot: Node2D, target_slot: Node2D) -> bool:
	if item == null or origin_slot == null or target_slot == null:
		return false

	if _is_slot_locked(origin_slot) or not _is_slot_drag_drop_targetable(target_slot):
		return false

	target_slot = _resolve_move_target_slot(origin_slot, target_slot)
	if target_slot == null:
		return false

	if target_slot == origin_slot:
		_place_item_in_slot(item, origin_slot, true)
		return true

	var shelves_to_check: Array[Node] = []
	_add_shelf_to_check(shelves_to_check, origin_slot)
	_add_shelf_to_check(shelves_to_check, target_slot)

	_move_item_to_slot_after_animation(item, target_slot, shelves_to_check)
	return true


func _find_item_at_position(pointer_global_position: Vector2) -> ShelfItem:
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if not _is_slot_drag_drop_targetable(slot):
			continue

		var item := _get_slot_item(slot)
		if item == null or _is_item_busy(item):
			continue

		var scaled_pick_size := item_pick_size * _shelves_layout_scale
		var item_rect := Rect2(item.global_position - scaled_pick_size * 0.5, scaled_pick_size)
		if item_rect.has_point(pointer_global_position):
			return item

	return null


func _find_clicked_slot(pointer_global_position: Vector2, clicked_item: ShelfItem) -> Node2D:
	if clicked_item != null:
		return clicked_item.get_parent() as Node2D

	return _find_nearest_empty_slot(pointer_global_position)


func _find_nearest_slot(pointer_global_position: Vector2) -> Node2D:
	var nearest_slot: Node2D
	var nearest_distance := _get_scaled_slot_snap_distance()

	for slot in _slots:
		if not _is_slot_drag_drop_targetable(slot):
			continue

		var marker := _get_slot_marker(slot)
		if marker == null:
			continue

		var distance := pointer_global_position.distance_to(marker.global_position)
		if distance <= nearest_distance:
			nearest_slot = slot
			nearest_distance = distance

	return nearest_slot


func _find_nearest_empty_slot(pointer_global_position: Vector2) -> Node2D:
	var nearest_slot: Node2D
	var nearest_distance := _get_scaled_slot_snap_distance()

	for slot in _slots:
		if not _is_slot_drag_drop_targetable(slot):
			continue

		if _get_slot_item(slot) != null:
			continue

		var marker := _get_slot_marker(slot)
		if marker == null:
			continue

		var distance := pointer_global_position.distance_to(marker.global_position)
		if distance <= nearest_distance:
			nearest_slot = slot
			nearest_distance = distance

	return nearest_slot


func _get_scaled_slot_snap_distance() -> float:
	return slot_snap_distance * _shelves_layout_scale


func _resolve_move_target_slot(origin_slot: Node2D, target_slot: Node2D) -> Node2D:
	if _is_slot_locked(origin_slot) or not _is_slot_drag_drop_targetable(target_slot):
		return null

	if target_slot == origin_slot:
		return target_slot

	if _get_slot_item(target_slot) == null:
		return target_slot

	if _get_owning_shelf(origin_slot) == _get_owning_shelf(target_slot):
		return origin_slot

	return _find_free_slot_on_target_shelf(target_slot, origin_slot)


func _find_free_slot_on_target_shelf(target_slot: Node2D, excluded_slot: Node2D) -> Node2D:
	var target_shelf := _get_owning_shelf(target_slot)
	if target_shelf == null:
		return null

	if not _is_shelf_drag_drop_targetable(target_shelf):
		return null

	var target_marker := _get_slot_marker(target_slot)
	if target_marker == null:
		return null

	var nearest_slot: Node2D
	var nearest_distance := INF
	for shelf_slot in _get_front_slots(target_shelf):
		if shelf_slot == excluded_slot or _get_slot_item(shelf_slot) != null:
			continue

		var marker := _get_slot_marker(shelf_slot)
		if marker == null:
			continue

		var distance := target_marker.global_position.distance_to(marker.global_position)
		if distance < nearest_distance:
			nearest_slot = shelf_slot
			nearest_distance = distance

	return nearest_slot


func _get_slot_marker(slot: Node2D) -> Marker2D:
	return slot.get_node_or_null("ItemSlot%s" % slot.name.trim_prefix("Slot")) as Marker2D


func _get_slot_item(slot: Node2D) -> ShelfItem:
	for child in slot.get_children():
		var item := child as ShelfItem
		if item != null and not item.is_queued_for_deletion():
			return item

	return null


func _place_item_in_slot(item: ShelfItem, slot: Node2D, should_play_sound := false) -> void:
	item.reparent(slot, true)
	item.position = SLOT_ITEM_POSITION
	item.z_index = 10
	_apply_item_visual_state(item)
	if should_play_sound:
		_play_item_place_sound()


func _move_item_to_slot_after_animation(item: ShelfItem, target_slot: Node2D, shelves_to_check: Array[Node]) -> void:
	await _play_item_move_animation(item, target_slot)
	_resolve_shelves(shelves_to_check)


func _return_item_to_origin_after_animation(item: ShelfItem, origin_slot: Node2D) -> void:
	await _play_item_move_animation(item, origin_slot)


func _play_item_move_animation(item: ShelfItem, target_slot: Node2D) -> void:
	if item == null or target_slot == null or not is_instance_valid(item):
		return

	var duration := maxf(item_move_duration_seconds, 0.0)
	item.reparent(target_slot, true)
	item.z_index = 13
	item.input_pickable = false
	_mark_item_transitioning_by_id(item.get_instance_id())

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true

	if duration > 0.0:
		var move_tween := create_tween()
		move_tween.tween_property(
			item,
			"position",
			SLOT_ITEM_POSITION,
			duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await move_tween.finished

	if item == null or not is_instance_valid(item):
		return

	item.position = SLOT_ITEM_POSITION
	item.z_index = 10
	item.input_pickable = true
	_unmark_item_transitioning_by_id(item.get_instance_id())

	collision = item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = false

	_apply_item_visual_state(item)
	_play_item_place_sound()


func _add_shelf_to_check(shelves_to_check: Array[Node], slot: Node2D) -> void:
	var shelf := _get_owning_shelf(slot)
	if shelf != null and not shelves_to_check.has(shelf):
		shelves_to_check.append(shelf)


func _resolve_shelves(shelves_to_check: Array[Node]) -> void:
	for shelf in shelves_to_check:
		if shelf == null or not is_instance_valid(shelf):
			continue

		var shelf_instance_id := shelf.get_instance_id()
		if _shelves_resolving_ids.has(shelf_instance_id):
			_queue_shelves_to_resolve([shelf])
			continue

		_shelves_resolving_ids.append(shelf_instance_id)
		_resolve_shelf(shelf, shelf_instance_id)

	_is_resolving_shelves = not _shelves_resolving_ids.is_empty()


func _resolve_shelf(shelf: Node, shelf_instance_id: int) -> void:
	while shelf != null and is_instance_valid(shelf):
		while true:
			var cleared := await _clear_matching_shelves([shelf])
			var promoted := await _promote_empty_front_layers([shelf])
			if not cleared and not promoted:
				break

		if not _shelves_pending_resolve.has(shelf):
			break

		_shelves_pending_resolve.erase(shelf)

	_shelves_resolving_ids.erase(shelf_instance_id)
	_is_resolving_shelves = not _shelves_resolving_ids.is_empty()
	if _is_resolving_shelves:
		return

	_refresh_ability_highlights()
	_check_level_completed()
	_update_ability_buttons()


func _queue_shelves_to_resolve(shelves_to_check: Array[Node]) -> void:
	for shelf in shelves_to_check:
		if shelf != null and is_instance_valid(shelf) and not _shelves_pending_resolve.has(shelf):
			_shelves_pending_resolve.append(shelf)


func _clear_matching_shelves(shelves_to_check: Array[Node]) -> bool:
	var cleared_any := false

	for shelf in shelves_to_check:
		if _is_shelf_locked(shelf):
			continue

		var shelf_items := _get_shelf_items(shelf)
		if shelf_items.size() != 3:
			continue

		var item_id := shelf_items[0].item_id
		if item_id == &"":
			continue

		if shelf_items.all(func(item: ShelfItem) -> bool: return item.item_id == item_id):
			cleared_any = true

			if shelf_items.has(_selected_item):
				_clear_selected_item()

			for item in shelf_items:
				_highlighted_items.erase(item)

			var star_reward_origin := shelf_items[1].global_position
			await _play_match_clear_animation(shelf_items)
			var earned_stars := _record_triples_cleared(1)
			_show_combo_praise(star_reward_origin, _combo_count)
			_play_combo_star_reward_animation(star_reward_origin, earned_stars)

	return cleared_any


func _play_match_clear_animation(shelf_items: Array[ShelfItem]) -> void:
	if shelf_items.size() != SLOT_COUNT:
		return

	var center_item := shelf_items[1]
	if center_item == null or not is_instance_valid(center_item):
		for item in shelf_items:
			if item != null and is_instance_valid(item):
				item.queue_free()
		return

	var clearing_item_ids: Array[int] = []
	var center_position := center_item.global_position
	for item in shelf_items:
		if item == null or not is_instance_valid(item):
			continue

		var item_instance_id := item.get_instance_id()
		clearing_item_ids.append(item_instance_id)
		_mark_item_clearing_by_id(item_instance_id)
		item.input_pickable = false
		item.z_index = 20

	center_item.z_index = 21

	var gather_tween := create_tween()
	gather_tween.set_parallel(true)
	for item in shelf_items:
		if item == center_item or item == null or not is_instance_valid(item):
			continue

		gather_tween.tween_property(
			item,
			"global_position",
			center_position,
			match_gather_duration_seconds
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		gather_tween.tween_property(
			item,
			"scale",
			Vector2.ONE * 0.82,
			match_gather_duration_seconds
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await gather_tween.finished
	_play_triple_clear_sound()

	for item in shelf_items:
		if item != center_item and item != null and is_instance_valid(item):
			item.queue_free()

	if center_item == null or not is_instance_valid(center_item):
		for item_instance_id in clearing_item_ids:
			_unmark_item_clearing_by_id(item_instance_id)
		return

	var shrink_tween := create_tween()
	shrink_tween.set_parallel(true)
	shrink_tween.tween_property(
		center_item,
		"scale",
		Vector2.ZERO,
		match_shrink_duration_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	shrink_tween.tween_property(
		center_item,
		"modulate",
		Color(1, 1, 1, 0),
		match_shrink_duration_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await shrink_tween.finished

	if center_item != null and is_instance_valid(center_item):
		center_item.queue_free()

	for item_instance_id in clearing_item_ids:
		_unmark_item_clearing_by_id(item_instance_id)


func _play_combo_star_reward_animation(origin_global_position: Vector2, star_count: int) -> void:
	if star_count <= 0 or _star_reward_effect_layer == null or _top_hud == null:
		return

	var target_global_position := _top_hud.get_star_counter_global_center()
	for star_index in range(star_count):
		_spawn_combo_reward_star(origin_global_position, target_global_position, star_index, star_count)

	var total_duration := (
		STAR_REWARD_DROP_DURATION_SECONDS
		+ STAR_REWARD_FLY_DURATION_SECONDS
		+ STAR_REWARD_STAGGER_SECONDS * maxf(float(star_count - 1), 0.0)
	)
	await get_tree().create_timer(total_duration).timeout
	_top_hud.play_star_receive_pulse()


func _show_combo_praise(origin_global_position: Vector2, combo_count: int) -> void:
	var praise_text := _get_combo_praise_text(combo_count)
	if praise_text == "" or _star_reward_effect_layer == null:
		return

	var label := Label.new()
	label.text = praise_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = COMBO_PRAISE_LABEL_SIZE
	label.pivot_offset = COMBO_PRAISE_LABEL_SIZE * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 3
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	label.scale = Vector2(0.72, 0.72)
	label.add_theme_color_override("font_color", _get_combo_praise_color(combo_count))
	label.add_theme_color_override("font_outline_color", _get_combo_praise_outline_color(combo_count))
	label.add_theme_constant_override("outline_size", _get_combo_praise_outline_size(combo_count))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.01, 0.55))
	label.add_theme_font_size_override("font_size", _get_combo_praise_font_size(praise_text))
	_star_reward_effect_layer.add_child(label)

	var praise_center := _get_star_effect_layer_position(origin_global_position + COMBO_PRAISE_OFFSET)
	praise_center = _clamp_combo_praise_center(praise_center, COMBO_PRAISE_LABEL_SIZE)
	label.position = praise_center - COMBO_PRAISE_LABEL_SIZE * 0.5

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", Color.WHITE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", COMBO_PRAISE_POP_SCALE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_delay(0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		label,
		"position",
		label.position + Vector2(0, -18),
		COMBO_PRAISE_DURATION_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		label,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		COMBO_PRAISE_FADE_SECONDS
	).set_delay(COMBO_PRAISE_DURATION_SECONDS - COMBO_PRAISE_FADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _get_combo_praise_text(combo_count: int) -> String:
	if combo_count < 2:
		return ""

	var praise_index := mini(combo_count, COMBO_PRAISE_WORDS.size() - 1)
	return str(COMBO_PRAISE_WORDS[praise_index])


func _get_combo_praise_color(combo_count: int) -> Color:
	if combo_count >= 17:
		return Color(1.0, 0.95, 0.78, 1.0)
	if combo_count >= 14:
		return Color(1.0, 0.88, 1.0, 1.0)
	if combo_count >= 10:
		return Color(1.0, 0.66, 0.2, 1.0)
	if combo_count >= 7:
		return Color(1.0, 0.78, 0.34, 1.0)
	if combo_count >= 4:
		return Color(1.0, 0.86, 0.28, 1.0)
	return Color(0.98, 0.96, 0.72, 1.0)


func _get_combo_praise_outline_color(combo_count: int) -> Color:
	if combo_count >= 17:
		return Color(0.82, 0.05, 0.04, 0.98)
	if combo_count >= 14:
		return Color(0.5, 0.12, 0.88, 0.98)
	if combo_count >= 10:
		return Color(0.95, 0.54, 0.02, 0.98)
	if combo_count >= 7:
		return Color(0.28, 0.22, 0.48, 0.94)
	if combo_count >= 4:
		return Color(0.28, 0.21, 0.1, 0.9)
	return Color(0.14, 0.3, 0.26, 0.86)


func _get_combo_praise_outline_size(combo_count: int) -> int:
	if combo_count >= 17:
		return 13
	if combo_count >= 14:
		return 11
	if combo_count >= 10:
		return 9
	if combo_count >= 7:
		return 6
	if combo_count >= 4:
		return 5
	return 4


func _get_combo_praise_font_size(praise_text: String) -> int:
	if praise_text.length() >= 12:
		return 38
	if praise_text.length() >= 11:
		return 40
	if praise_text.length() >= 9:
		return 44
	return 52


func _clamp_combo_praise_center(center: Vector2, label_size: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return center

	var half_size := label_size * 0.5
	var min_center := half_size + Vector2.ONE * COMBO_PRAISE_EDGE_PADDING
	var max_center := viewport_size - half_size - Vector2.ONE * COMBO_PRAISE_EDGE_PADDING
	var clamped_center := center
	clamped_center.x = viewport_size.x * 0.5 if max_center.x < min_center.x else clampf(center.x, min_center.x, max_center.x)
	clamped_center.y = viewport_size.y * 0.5 if max_center.y < min_center.y else clampf(center.y, min_center.y, max_center.y)
	return clamped_center


func _spawn_combo_reward_star(
	origin_global_position: Vector2,
	target_global_position: Vector2,
	star_index: int,
	star_count: int
) -> void:
	if _star_reward_effect_layer == null:
		return

	var star := TextureRect.new()
	star.texture = REWARD_STAR_TEXTURE
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.size = STAR_REWARD_SIZE
	star.pivot_offset = STAR_REWARD_SIZE * 0.5
	star.scale = Vector2(0.56, 0.56)
	star.modulate = Color(1.0, 1.0, 1.0, 0.0)
	star.rotation = _rng.randf_range(-0.28, 0.28)
	_star_reward_effect_layer.add_child(star)

	var spread_x := 0.0
	if star_count > 1:
		spread_x = lerpf(-34.0, 34.0, float(star_index) / float(star_count - 1))
	spread_x += _rng.randf_range(-8.0, 8.0)

	var spawn_center := _get_star_effect_layer_position(
		origin_global_position + Vector2(spread_x, _rng.randf_range(-8.0, 8.0))
	)
	var drop_center := spawn_center + Vector2(
		_rng.randf_range(-18.0, 18.0),
		_rng.randf_range(40.0, 66.0)
	)
	var target_center := _get_star_effect_layer_position(target_global_position)
	star.position = spawn_center - STAR_REWARD_SIZE * 0.5

	_animate_combo_reward_star(
		star,
		drop_center - STAR_REWARD_SIZE * 0.5,
		target_center - STAR_REWARD_SIZE * 0.5,
		star_index
	)


func _animate_combo_reward_star(
	star: TextureRect,
	drop_position: Vector2,
	target_position: Vector2,
	star_index: int
) -> void:
	var delay := STAR_REWARD_STAGGER_SECONDS * float(star_index)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if star == null or not is_instance_valid(star):
		return

	var drop_tween := star.create_tween()
	drop_tween.set_parallel(true)
	drop_tween.tween_property(
		star,
		"position",
		drop_position,
		STAR_REWARD_DROP_DURATION_SECONDS
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop_tween.tween_property(
		star,
		"scale",
		Vector2.ONE,
		STAR_REWARD_DROP_DURATION_SECONDS
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop_tween.tween_property(
		star,
		"modulate",
		Color(1.0, 1.0, 1.0, 1.0),
		STAR_REWARD_DROP_DURATION_SECONDS * 0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drop_tween.tween_property(
		star,
		"rotation",
		star.rotation + _rng.randf_range(-0.65, 0.65),
		STAR_REWARD_DROP_DURATION_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await drop_tween.finished
	if star == null or not is_instance_valid(star):
		return

	var fly_tween := star.create_tween()
	fly_tween.set_parallel(true)
	fly_tween.tween_property(
		star,
		"position",
		target_position,
		STAR_REWARD_FLY_DURATION_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fly_tween.tween_property(
		star,
		"scale",
		Vector2(0.42, 0.42),
		STAR_REWARD_FLY_DURATION_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(
		star,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		STAR_REWARD_FLY_DURATION_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(
		star,
		"rotation",
		star.rotation + _rng.randf_range(-1.15, 1.15),
		STAR_REWARD_FLY_DURATION_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fly_tween.finished

	if star != null and is_instance_valid(star):
		star.queue_free()


func _get_star_effect_layer_position(global_position: Vector2) -> Vector2:
	if _star_reward_effect_layer == null:
		return global_position

	return global_position - _star_reward_effect_layer.global_position


func _clear_star_reward_effects() -> void:
	if _top_hud != null:
		_top_hud.reset_star_pulse()

	if _star_reward_effect_layer == null:
		return

	for child in _star_reward_effect_layer.get_children():
		child.queue_free()


func _mark_item_clearing_by_id(instance_id: int) -> void:
	if instance_id != 0 and not _clearing_item_ids.has(instance_id):
		_clearing_item_ids.append(instance_id)


func _unmark_item_clearing_by_id(instance_id: int) -> void:
	_clearing_item_ids.erase(instance_id)


func _is_item_clearing(item: ShelfItem) -> bool:
	return item != null and _clearing_item_ids.has(item.get_instance_id())


func _mark_item_transitioning_by_id(instance_id: int) -> void:
	if instance_id != 0 and not _transitioning_item_ids.has(instance_id):
		_transitioning_item_ids.append(instance_id)


func _unmark_item_transitioning_by_id(instance_id: int) -> void:
	_transitioning_item_ids.erase(instance_id)


func _is_item_transitioning(item: ShelfItem) -> bool:
	return item != null and _transitioning_item_ids.has(item.get_instance_id())


func _is_item_busy(item: ShelfItem) -> bool:
	return _is_item_clearing(item) or _is_item_transitioning(item)


func _promote_empty_front_layers(shelves_to_check: Array[Node]) -> bool:
	var promoted_any := false

	for shelf in shelves_to_check:
		var shelf_node := shelf as Node2D
		if shelf_node == null:
			continue

		if _is_shelf_locked(shelf_node):
			continue

		if not _front_layer_is_empty(shelf_node):
			continue

		if await _promote_back_layer(shelf_node):
			promoted_any = true

	return promoted_any


func _front_layer_is_empty(shelf: Node) -> bool:
	for slot in _get_front_slots(shelf):
		if _get_slot_item(slot) != null:
			return false

	return true


func _promote_back_layer(shelf: Node2D) -> bool:
	var shelf_cell := shelf as Shelf
	if shelf_cell == null:
		return false

	var next_layer := shelf_cell.get_back_layer(Shelf.FIRST_BACK_LAYER_INDEX)
	if next_layer == null:
		return false

	var promotion_entries: Array[Dictionary] = []
	for front_slot in _get_front_slots(shelf):
		var layer_slot := next_layer.get_node_or_null("Layer%s" % front_slot.name) as Node2D
		if layer_slot == null:
			continue

		var layer_item := _get_slot_item(layer_slot)
		if layer_item == null:
			continue

		promotion_entries.append(_prepare_layer_promotion_item(layer_item, front_slot))

	shelf.remove_child(next_layer)
	next_layer.free()
	_advance_back_layers(shelf_cell)
	await _play_layer_promotion_animation(promotion_entries)
	return true


func _prepare_layer_promotion_item(item: ShelfItem, front_slot: Node2D) -> Dictionary:
	var target_visual_scale := item.visual_scale
	var shelf := _get_owning_shelf(front_slot) as Shelf
	if shelf != null and shelf.back_layer_item_scale > 0.0:
		target_visual_scale /= shelf.back_layer_item_scale

	item.reparent(front_slot, true)
	item.z_index = 12
	item.input_pickable = false
	_mark_item_transitioning_by_id(item.get_instance_id())

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = true

	return {
		"item": item,
		"target_visual_scale": target_visual_scale,
	}


func _play_layer_promotion_animation(promotion_entries: Array[Dictionary]) -> void:
	if promotion_entries.is_empty():
		return

	var duration := maxf(layer_promotion_duration_seconds, 0.0)
	if duration <= 0.0:
		for entry in promotion_entries:
			_finish_layer_promotion_item(entry)
		return

	var promotion_tween := create_tween()
	promotion_tween.set_parallel(true)
	var did_add_tween := false

	for entry in promotion_entries:
		var item := entry.get("item") as ShelfItem
		if item == null or not is_instance_valid(item):
			continue

		var target_visual_scale := float(entry.get("target_visual_scale", item.visual_scale))
		did_add_tween = true
		promotion_tween.tween_property(
			item,
			"position",
			SLOT_ITEM_POSITION,
			duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		promotion_tween.tween_property(
			item,
			"modulate",
			Color.WHITE,
			duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		promotion_tween.tween_property(
			item,
			"visual_scale",
			target_visual_scale,
			duration
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if not did_add_tween:
		for entry in promotion_entries:
			_finish_layer_promotion_item(entry)
		return

	await promotion_tween.finished

	for entry in promotion_entries:
		_finish_layer_promotion_item(entry)


func _finish_layer_promotion_item(entry: Dictionary) -> void:
	var item := entry.get("item") as ShelfItem
	if item == null or not is_instance_valid(item):
		return

	item.position = SLOT_ITEM_POSITION
	item.z_index = 10
	item.modulate = Color.WHITE
	item.visual_scale = float(entry.get("target_visual_scale", item.visual_scale))
	item.set_contact_shadow_enabled(true)
	item.input_pickable = true
	_unmark_item_transitioning_by_id(item.get_instance_id())

	var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.disabled = false

	_apply_item_visual_state(item)


func _advance_back_layers(shelf: Shelf) -> void:
	for layer_index in range(Shelf.FIRST_BACK_LAYER_INDEX + 1, _max_layer_count):
		var layer := shelf.get_back_layer(layer_index)
		if layer == null:
			continue

		layer.name = shelf.get_back_layer_name(layer_index - 1)
		shelf.configure_back_layer(layer, layer_index - 1)


func _get_shelf_items(shelf: Node) -> Array[ShelfItem]:
	var shelf_items: Array[ShelfItem] = []
	for child in shelf.get_children():
		var slot := child as Node2D
		if slot == null or not slot.name.begins_with("Slot"):
			continue

		var item := _get_slot_item(slot)
		if item != null:
			shelf_items.append(item)

	return shelf_items


func _screen_position_to_global(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _set_selected_item(item: ShelfItem, slot: Node2D) -> void:
	_clear_selected_item()
	_selected_item = item
	_selected_slot = slot
	_apply_item_visual_state(item)


func _clear_selected_item() -> void:
	var previous_item := _selected_item

	_selected_item = null
	_selected_slot = null

	if previous_item != null and is_instance_valid(previous_item):
		_apply_item_visual_state(previous_item)


func _apply_item_visual_state(item: ShelfItem) -> void:
	var sprite := item.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	var is_selected := item == _selected_item
	var is_highlighted := _highlighted_items.has(item)
	if is_selected:
		sprite.modulate = Color(1.12, 1.12, 1.12, 1.0)
	else:
		sprite.modulate = Color.WHITE

	var outline_color := selected_highlight_outline_color if is_selected else highlight_outline_color
	item.set_outline(is_highlighted, outline_color, highlight_outline_width)
	item.set_highlight_scale(highlight_item_scale if is_highlighted else 1.0)


func _setup_ability_buttons() -> void:
	if _ability_bar == null:
		push_warning("Missing reusable ability bar.")
		return
	_ability_bar.ability_pressed.connect(_on_ability_button_pressed)
	_update_highlight_timer_label()
	_update_freezer_visuals()


func _on_ability_button_pressed(ability_id: StringName) -> void:
	if _level_failed or _level_completed or _level_paused or _is_ability_effect_active():
		return
	if ability_id == ABILITY_FREEZER and _is_freezer_active():
		return

	if int(_ability_uses.get(ability_id, 0)) <= 0:
		_open_ability_purchase_menu(ability_id)
		return

	_apply_ability_from_button(ability_id)


func _apply_ability_from_button(ability_id: StringName) -> bool:
	if not _can_apply_ability(ability_id):
		return false
	if launched_from_dev_mode:
		_ability_uses[ability_id] = maxi(int(_ability_uses.get(ability_id, 0)) - 1, 0)
	elif not PlayerProgress.spend_ability(ability_id):
		return false
	_cancel_active_interaction()

	var did_apply := false
	match ability_id:
		ABILITY_HAMMER:
			did_apply = _use_hammer()
		ABILITY_SHUFFLE:
			did_apply = _use_shuffle()
		ABILITY_HIGHLIGHT:
			did_apply = _use_highlight()
		ABILITY_FREEZER:
			did_apply = _use_freezer()

	if not did_apply:
		push_error("Ability passed preflight but could not start: %s" % String(ability_id))
		return false

	_start_level_timer_from_player_action()
	if not launched_from_dev_mode:
		_load_ability_uses()
	_update_ability_buttons()
	return true


func _apply_paid_ability(ability_id: StringName) -> bool:
	if not _can_apply_ability(ability_id):
		return false
	_cancel_active_interaction()

	var did_apply := false
	match ability_id:
		ABILITY_HAMMER:
			did_apply = _use_hammer()
		ABILITY_SHUFFLE:
			did_apply = _use_shuffle()
		ABILITY_HIGHLIGHT:
			did_apply = _use_highlight()
		ABILITY_FREEZER:
			did_apply = _use_freezer()

	if not did_apply:
		return false

	_start_level_timer_from_player_action()
	_update_ability_buttons()
	return true


func _can_apply_ability(ability_id: StringName) -> bool:
	match ability_id:
		ABILITY_HAMMER:
			var front_groups := _group_hammer_items_by_type(_get_visible_items())
			var back_groups := _group_hammer_items_by_type(_get_first_back_layer_items())
			for item_id in front_groups.keys():
				var front_count := (front_groups[item_id] as Array).size()
				var back_count := (back_groups.get(item_id, []) as Array).size()
				if front_count >= SLOT_COUNT or (front_count > 0 and front_count + back_count >= SLOT_COUNT):
					return true
			return false
		ABILITY_SHUFFLE:
			return not _is_resolving_shelves and _get_shuffle_eligible_items().size() >= 2
		ABILITY_HIGHLIGHT:
			return true
		ABILITY_FREEZER:
			return not _is_freezer_active()
	return false


func _cancel_active_interaction() -> void:
	_clear_selected_item()

	if _dragged_item != null and _origin_slot != null:
		_dragged_item.set_contact_shadow_enabled(true)
		_place_item_in_slot(_dragged_item, _origin_slot)

	_dragged_item = null
	_origin_slot = null
	_drag_offset = Vector2.ZERO
	_pressed_item = null
	_pressed_origin_slot = null


func _use_hammer() -> bool:
	var visible_items := _get_visible_items()
	var items_to_destroy := _find_hammer_targets(visible_items)
	if items_to_destroy.is_empty():
		items_to_destroy = _find_hammer_supplemented_targets(visible_items, _get_first_back_layer_items())

	if items_to_destroy.is_empty():
		return false

	_play_hammer_ability(items_to_destroy)
	return true


func _play_hammer_ability(items_to_destroy: Array[ShelfItem]) -> void:
	_hammer_effect_active = true
	_update_ability_buttons()

	var shelves_to_check := _get_hammer_shelves_to_check(items_to_destroy)
	var destroyed_triples := floori(float(_get_valid_item_count(items_to_destroy)) / float(SLOT_COUNT))
	var impact_screen_position := get_viewport_rect().size * 0.5
	var impact_global_position := _screen_position_to_global(impact_screen_position)
	var merged_item := await _play_hammer_gather_animation(items_to_destroy, impact_global_position)
	var ui_layer := get_node("UI") as CanvasLayer
	var effect := HAMMER_IMPACT_EFFECT_SCENE.instantiate() as HammerImpactEffect
	ui_layer.add_child(effect)
	effect.play(impact_screen_position)

	await effect.impact
	_play_hammer_screen_shake()
	await _play_hammer_destroy_animation(merged_item, items_to_destroy)
	var earned_stars := _record_triples_cleared(destroyed_triples)
	_show_combo_praise(impact_global_position, _combo_count)
	_resolve_shelves(shelves_to_check)
	await effect.finished
	effect.queue_free()
	await _play_combo_star_reward_animation(impact_global_position, earned_stars)

	_hammer_effect_active = false
	_update_ability_buttons()


func _get_hammer_shelves_to_check(items_to_destroy: Array[ShelfItem]) -> Array[Node]:
	var shelves_to_check: Array[Node] = []
	for item in items_to_destroy:
		if item == null or not is_instance_valid(item):
			continue

		var item_slot := item.get_parent() as Node2D
		if item_slot != null:
			_add_shelf_to_check(shelves_to_check, item_slot)

	return shelves_to_check


func _play_hammer_gather_animation(items_to_destroy: Array[ShelfItem], target_global_position: Vector2) -> ShelfItem:
	var valid_items := _get_valid_items(items_to_destroy)
	if valid_items.is_empty():
		return null

	var merged_item := valid_items[0]
	for item in valid_items:
		var item_instance_id := item.get_instance_id()
		_mark_item_clearing_by_id(item_instance_id)
		_highlighted_items.erase(item)
		item.input_pickable = false
		item.set_contact_shadow_enabled(false)
		item.modulate = Color.WHITE
		item.rotation = 0.0
		item.z_index = 26 if item == merged_item else 25

	var gather_tween := create_tween()
	gather_tween.set_parallel(true)
	for item in valid_items:
		gather_tween.tween_property(
			item,
			"global_position",
			target_global_position,
			match_gather_duration_seconds
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		gather_tween.tween_property(
			item,
			"scale",
			Vector2.ONE * 0.82,
			match_gather_duration_seconds
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await gather_tween.finished

	for item in valid_items:
		if item != merged_item and item != null and is_instance_valid(item):
			_unmark_item_clearing_by_id(item.get_instance_id())
			item.queue_free()

	return merged_item if merged_item != null and is_instance_valid(merged_item) else null


func _play_hammer_destroy_animation(merged_item: ShelfItem, items_to_destroy: Array[ShelfItem]) -> void:
	_play_triple_clear_sound()
	if merged_item != null and is_instance_valid(merged_item):
		var shrink_tween := create_tween()
		shrink_tween.set_parallel(true)
		shrink_tween.tween_property(
			merged_item,
			"scale",
			Vector2.ZERO,
			match_shrink_duration_seconds
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		shrink_tween.tween_property(
			merged_item,
			"modulate",
			Color(1, 1, 1, 0),
			match_shrink_duration_seconds
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await shrink_tween.finished

	for item in items_to_destroy:
		if item == null or not is_instance_valid(item):
			continue

		if item == _selected_item:
			_clear_selected_item()

		_unmark_item_clearing_by_id(item.get_instance_id())
		item.queue_free()


func _get_valid_items(items: Array[ShelfItem]) -> Array[ShelfItem]:
	var valid_items: Array[ShelfItem] = []
	for item in items:
		if item != null and is_instance_valid(item) and not item.is_queued_for_deletion():
			valid_items.append(item)

	return valid_items


func _get_valid_item_count(items: Array[ShelfItem]) -> int:
	return _get_valid_items(items).size()


func _play_hammer_screen_shake() -> void:
	if _shelves_root == null:
		return

	var original_position := _shelves_root.position
	var shake_offset := Vector2(8.0, -5.0) * clampf(_shelves_layout_scale, 0.75, 1.35)
	var tween := create_tween()
	tween.tween_property(_shelves_root, "position", original_position + shake_offset, 0.035)
	tween.tween_property(_shelves_root, "position", original_position - shake_offset * 0.6, 0.045)
	tween.tween_property(_shelves_root, "position", original_position, 0.055)


func _find_hammer_targets(items: Array[ShelfItem]) -> Array[ShelfItem]:
	var items_by_type := _group_hammer_items_by_type(items)
	var candidate_ids: Array[StringName] = []
	for item_id in items_by_type.keys():
		var typed_items := items_by_type[item_id] as Array
		if typed_items.size() >= SLOT_COUNT:
			candidate_ids.append(item_id)

	if candidate_ids.is_empty():
		return []

	var chosen_id := candidate_ids[_rng.randi_range(0, candidate_ids.size() - 1)]
	var chosen_items := items_by_type[chosen_id] as Array
	_shuffle_array(chosen_items)

	var items_to_destroy: Array[ShelfItem] = []
	for item_index in range(SLOT_COUNT):
		var item := chosen_items[item_index] as ShelfItem
		if item != null:
			items_to_destroy.append(item)

	return items_to_destroy


func _find_hammer_supplemented_targets(
	front_items: Array[ShelfItem],
	back_layer_items: Array[ShelfItem]
) -> Array[ShelfItem]:
	var front_items_by_type := _group_hammer_items_by_type(front_items)
	var back_items_by_type := _group_hammer_items_by_type(back_layer_items)

	var candidate_ids: Array[StringName] = []
	for item_id in front_items_by_type.keys():
		var front_typed_items := front_items_by_type[item_id] as Array
		var back_typed_items := back_items_by_type.get(item_id, []) as Array
		if not front_typed_items.is_empty() and front_typed_items.size() + back_typed_items.size() >= SLOT_COUNT:
			candidate_ids.append(item_id)

	if candidate_ids.is_empty():
		return []

	var chosen_id := candidate_ids[_rng.randi_range(0, candidate_ids.size() - 1)]
	var chosen_front_items := front_items_by_type[chosen_id] as Array
	var chosen_back_items := back_items_by_type.get(chosen_id, []) as Array
	_shuffle_array(chosen_front_items)
	_shuffle_array(chosen_back_items)

	var items_to_destroy: Array[ShelfItem] = []
	var front_item_count = mini(chosen_front_items.size(), SLOT_COUNT)
	for item_index in range(front_item_count):
		var item := chosen_front_items[item_index] as ShelfItem
		if item != null:
			items_to_destroy.append(item)

	var back_items_needed := SLOT_COUNT - items_to_destroy.size()
	for item_index in range(back_items_needed):
		var item := chosen_back_items[item_index] as ShelfItem
		if item != null:
			items_to_destroy.append(item)

	return items_to_destroy


func _group_hammer_items_by_type(items: Array[ShelfItem]) -> Dictionary:
	var items_by_type := {}
	for item in items:
		if item.item_id == &"":
			continue

		if not items_by_type.has(item.item_id):
			items_by_type[item.item_id] = []

		items_by_type[item.item_id].append(item)

	return items_by_type


func _use_shuffle() -> bool:
	if _is_resolving_shelves:
		return false

	var items := _get_shuffle_eligible_items()
	if items.size() < 2:
		return false

	_play_shuffle_ability(items)
	return true


func _get_shuffle_eligible_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for item in _get_unlocked_items():
		if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
			continue

		if item.item_id == &"":
			continue

		if _is_item_busy(item):
			return []

		items.append(item)

	return items


func _play_shuffle_ability(items_to_shuffle: Array[ShelfItem]) -> void:
	_shuffle_effect_active = true
	_set_moving_shelf_rows_paused(true)
	_update_ability_buttons()
	_clear_ability_highlights()

	var animation_entries := _prepare_shuffle_animation_entries(items_to_shuffle)
	var shuffle_box := _create_shuffle_box()
	if shuffle_box != null:
		await _play_shuffle_box_intro(shuffle_box)

	if not animation_entries.is_empty():
		var box_center := _get_shuffle_box_opening_global_position(shuffle_box)
		await _play_shuffle_items_into_box(animation_entries, box_center)
		_shuffle_item_id_assignments(items_to_shuffle)
		await _play_shuffle_items_out_of_box(animation_entries, box_center)
	else:
		_shuffle_item_id_assignments(items_to_shuffle)

	_finish_shuffle_animation_entries(animation_entries)
	if shuffle_box != null:
		await _play_shuffle_box_outro(shuffle_box)
		shuffle_box.queue_free()

	_set_moving_shelf_rows_paused(false)
	_shuffle_effect_active = false
	_resolve_shelves(_get_all_shelves())
	_update_ability_buttons()


func _prepare_shuffle_animation_entries(items: Array[ShelfItem]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _drag_layer == null:
		return entries

	for item in items:
		if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
			continue

		if not item.is_visible_in_tree() or item.modulate.a <= 0.01:
			continue

		var slot := item.get_parent() as Node2D
		if slot == null:
			continue

		var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var shadow := item.get_node_or_null("Shadow") as CanvasItem
		var entry := {
			"item": item,
			"slot": slot,
			"position": item.position,
			"global_position": item.global_position,
			"scale": item.scale,
			"rotation": item.rotation,
			"z_index": item.z_index,
			"modulate": item.modulate,
			"visual_scale": item.visual_scale,
			"input_pickable": item.input_pickable,
			"collision_disabled": collision != null and collision.disabled,
			"contact_shadow_enabled": shadow != null and shadow.visible,
			"target_global_position": slot.to_global(SLOT_ITEM_POSITION),
		}

		_mark_item_transitioning_by_id(item.get_instance_id())
		_highlighted_items.erase(item)
		item.reparent(_drag_layer, true)
		item.global_position = entry["global_position"]
		item.z_index = SHUFFLE_ITEM_FLY_IN_Z_INDEX
		item.input_pickable = false
		item.set_contact_shadow_enabled(false)
		if collision != null:
			collision.disabled = true

		entries.append(entry)

	return entries


func _create_shuffle_box() -> Sprite2D:
	if _drag_layer == null:
		return null

	var box := Sprite2D.new()
	box.name = "ShuffleBoxEffect"
	box.texture = SHUFFLE_BOX_TEXTURE
	box.centered = true
	box.z_index = SHUFFLE_BOX_Z_INDEX
	box.global_position = _screen_position_to_global(get_viewport_rect().size * 0.5)
	box.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var texture_size := SHUFFLE_BOX_TEXTURE.get_size()
	var target_scale := Vector2.ONE
	if texture_size.x > 0.0:
		target_scale = Vector2.ONE * (SHUFFLE_BOX_DISPLAY_WIDTH / texture_size.x)

	box.scale = target_scale * 0.72
	box.set_meta(&"target_scale", target_scale)
	_drag_layer.add_child(box)
	return box


func _play_shuffle_box_intro(box: Sprite2D) -> void:
	if box == null or not is_instance_valid(box):
		return

	var target_scale: Vector2 = box.get_meta(&"target_scale", box.scale)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(box, "scale", target_scale, SHUFFLE_BOX_POP_DURATION_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "modulate", Color.WHITE, SHUFFLE_BOX_POP_DURATION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


func _play_shuffle_box_outro(box: Sprite2D) -> void:
	if box == null or not is_instance_valid(box):
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(box, "scale", box.scale * 0.88, SHUFFLE_BOX_OUT_DURATION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(box, "modulate", Color(1.0, 1.0, 1.0, 0.0), SHUFFLE_BOX_OUT_DURATION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


func _get_shuffle_box_opening_global_position(box: Sprite2D) -> Vector2:
	if box == null or not is_instance_valid(box):
		return _screen_position_to_global(get_viewport_rect().size * 0.5)

	return box.global_position + SHUFFLE_BOX_OPENING_OFFSET * box.scale.x


func _play_shuffle_items_into_box(entries: Array[Dictionary], target_global_position: Vector2) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var did_add_tween := false

	for entry_index in range(entries.size()):
		var item := entries[entry_index].get("item") as ShelfItem
		if item == null or not is_instance_valid(item):
			continue

		did_add_tween = true
		var delay := minf(float(entry_index) * SHUFFLE_ITEM_STAGGER_SECONDS, SHUFFLE_ITEM_MAX_STAGGER_SECONDS)
		var jitter := Vector2(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-10.0, 10.0))
		item.z_index = SHUFFLE_ITEM_FLY_IN_Z_INDEX
		tween.tween_property(
			item,
			"global_position",
			target_global_position + jitter,
			SHUFFLE_ITEM_GATHER_DURATION_SECONDS
		).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(
			item,
			"scale",
			SHUFFLE_ITEM_INSIDE_SCALE,
			SHUFFLE_ITEM_GATHER_DURATION_SECONDS
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(
			item,
			"rotation",
			item.rotation + _rng.randf_range(-0.65, 0.65),
			SHUFFLE_ITEM_GATHER_DURATION_SECONDS
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(
			item,
			"modulate",
			Color(1.0, 1.0, 1.0, 0.0),
			SHUFFLE_ITEM_GATHER_DURATION_SECONDS * 0.45
		).set_delay(delay + SHUFFLE_ITEM_GATHER_DURATION_SECONDS * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if did_add_tween:
		await tween.finished


func _play_shuffle_items_out_of_box(entries: Array[Dictionary], source_global_position: Vector2) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var did_add_tween := false

	for entry_index in range(entries.size()):
		var item := entries[entry_index].get("item") as ShelfItem
		if item == null or not is_instance_valid(item):
			continue

		did_add_tween = true
		var delay := minf(float(entry_index) * SHUFFLE_ITEM_STAGGER_SECONDS, SHUFFLE_ITEM_MAX_STAGGER_SECONDS)
		var target_global_position: Vector2 = entries[entry_index].get("target_global_position", source_global_position)
		var target_scale: Vector2 = entries[entry_index].get("scale", Vector2.ONE)
		var target_rotation := float(entries[entry_index].get("rotation", 0.0))
		var target_modulate: Color = entries[entry_index].get("modulate", Color.WHITE)

		item.z_index = SHUFFLE_ITEM_FLY_OUT_Z_INDEX
		item.global_position = source_global_position + Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-6.0, 6.0))
		item.scale = SHUFFLE_ITEM_INSIDE_SCALE
		item.modulate = Color(target_modulate.r, target_modulate.g, target_modulate.b, 0.0)
		tween.tween_property(
			item,
			"global_position",
			target_global_position,
			SHUFFLE_ITEM_RETURN_DURATION_SECONDS
		).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(
			item,
			"scale",
			target_scale,
			SHUFFLE_ITEM_RETURN_DURATION_SECONDS
		).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(
			item,
			"rotation",
			target_rotation,
			SHUFFLE_ITEM_RETURN_DURATION_SECONDS
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(
			item,
			"modulate",
			target_modulate,
			SHUFFLE_ITEM_RETURN_DURATION_SECONDS * 0.45
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if did_add_tween:
		await tween.finished


func _finish_shuffle_animation_entries(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var item := entry.get("item") as ShelfItem
		var slot := entry.get("slot") as Node2D
		if item == null or slot == null or not is_instance_valid(item):
			continue

		item.reparent(slot, true)
		item.position = entry.get("position", SLOT_ITEM_POSITION)
		item.scale = entry.get("scale", Vector2.ONE)
		item.rotation = float(entry.get("rotation", 0.0))
		item.z_index = int(entry.get("z_index", 10))
		item.modulate = entry.get("modulate", Color.WHITE)
		item.visual_scale = float(entry.get("visual_scale", item.visual_scale))
		item.set_contact_shadow_enabled(bool(entry.get("contact_shadow_enabled", true)))
		_unmark_item_transitioning_by_id(item.get_instance_id())
		item.input_pickable = bool(entry.get("input_pickable", true))

		var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			collision.disabled = bool(entry.get("collision_disabled", false))

		_apply_item_visual_state(item)


func _shuffle_item_id_assignments(items: Array[ShelfItem]) -> void:
	var item_ids: Array[StringName] = []
	for item in items:
		item_ids.append(item.item_id)

	if item_ids.size() < 2:
		return

	var original_ids := item_ids.duplicate()
	for attempt_index in range(6):
		_shuffle_array(item_ids)
		if not _item_id_arrays_match(original_ids, item_ids):
			break

	for item_index in range(items.size()):
		var item := items[item_index]
		if item == null or not is_instance_valid(item):
			continue

		var item_id := item_ids[item_index]
		item.item_id = item_id
		item.texture = _item_textures.get(String(item_id))
		_apply_item_visual_state(item)


func _item_id_arrays_match(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false

	for item_index in range(left.size()):
		if left[item_index] != right[item_index]:
			return false

	return true


func _use_highlight() -> bool:
	var items_to_highlight := _find_immediate_triple_items()
	_clear_ability_highlights()
	_highlighted_items = items_to_highlight
	_highlight_timer = HIGHLIGHT_DURATION_SECONDS
	for item in _highlighted_items:
		_apply_item_visual_state(item)

	_update_highlight_timer_label()
	return true


func _use_freezer() -> bool:
	if _is_freezer_active():
		return false
	_freezer_time_remaining = FREEZER_DURATION_SECONDS
	_update_freezer_visuals()
	return true


func _destroy_items(items_to_destroy: Array[ShelfItem]) -> void:
	var shelves_to_check: Array[Node] = []
	var destroyed_count := 0
	for item in items_to_destroy:
		if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
			continue

		var item_slot := item.get_parent() as Node2D
		if item_slot != null:
			_add_shelf_to_check(shelves_to_check, item_slot)

		_highlighted_items.erase(item)
		if item == _selected_item:
			_clear_selected_item()

		item.queue_free()
		destroyed_count += 1

	var destroyed_triples := floori(float(destroyed_count) / float(SLOT_COUNT))
	_record_triples_cleared(destroyed_triples)

	_resolve_shelves(shelves_to_check)


func _find_immediate_triple_items() -> Array[ShelfItem]:
	var items_by_id := {}
	for item in _get_visible_items():
		if item.item_id == &"":
			continue

		var group: Array = items_by_id.get(item.item_id, [])
		group.append(item)
		items_by_id[item.item_id] = group

	# Prefer a triple that can be completed in a single move: a shelf that is
	# one item away from a full match, plus a loose match elsewhere.
	for shelf in _get_all_shelves():
		if _is_shelf_locked(shelf):
			continue

		var shelf_items := _get_shelf_items(shelf)
		if shelf_items.size() != SLOT_COUNT - 1:
			continue

		var first_id := shelf_items[0].item_id
		if first_id == &"":
			continue

		if not shelf_items.all(func(item: ShelfItem) -> bool: return item.item_id == first_id):
			continue

		var group: Array = items_by_id.get(first_id, [])
		if group.size() < SLOT_COUNT:
			continue

		return _merge_highlight_items(shelf_items, group)

	# Otherwise, settle for any visible items of the same type, even if
	# gathering them takes more than one move.
	for item_id in items_by_id:
		var group: Array = items_by_id[item_id]
		if group.size() >= SLOT_COUNT:
			return _merge_highlight_items([], group)

	return []


func _merge_highlight_items(priority_items: Array, candidates: Array) -> Array[ShelfItem]:
	var merged: Array[ShelfItem] = []
	for item in priority_items:
		merged.append(item)

	for item in candidates:
		if not merged.has(item):
			merged.append(item)

	return merged


func _update_highlight_timer(delta: float) -> void:
	if _highlight_timer <= 0.0:
		return

	_highlight_timer = maxf(_highlight_timer - delta, 0.0)
	_update_highlight_timer_label()
	if _highlight_timer <= 0.0:
		_clear_ability_highlights()


func _refresh_ability_highlights() -> void:
	if _highlight_timer <= 0.0:
		return

	var previous_items := _highlighted_items.duplicate()
	# Keep highlighting the same item type across unrelated moves instead of
	# jumping to a different candidate every time shelves resolve; only pick
	# a new type once the current one can no longer complete a triple.
	var next_items := _find_current_highlight_type_items()
	if next_items.is_empty():
		next_items = _find_immediate_triple_items()

	_highlighted_items = next_items
	for item in previous_items:
		if item != null and is_instance_valid(item):
			_apply_item_visual_state(item)

	for item in _highlighted_items:
		if item != null and is_instance_valid(item):
			_apply_item_visual_state(item)


func _find_current_highlight_type_items() -> Array[ShelfItem]:
	var current_id: StringName = &""
	for item in _highlighted_items:
		if item != null and is_instance_valid(item) and not item.is_queued_for_deletion():
			current_id = item.item_id
			break

	if current_id == &"":
		return []

	var matches: Array[ShelfItem] = []
	for item in _get_visible_items():
		if item.item_id == current_id:
			matches.append(item)

	if matches.size() < SLOT_COUNT:
		return []

	return matches


func _clear_ability_highlights() -> void:
	var previous_items := _highlighted_items.duplicate()
	_highlighted_items.clear()
	_highlight_timer = 0.0
	_update_highlight_timer_label()

	for item in previous_items:
		if item != null and is_instance_valid(item):
			_apply_item_visual_state(item)


func _update_highlight_timer_label() -> void:
	if _ability_bar == null:
		return
	_ability_bar.set_active_seconds(
		ABILITY_HIGHLIGHT,
		_highlight_timer if not _level_failed and not _level_completed else 0.0
	)


func _update_freezer_timer(delta: float) -> float:
	if not _is_freezer_active():
		return delta
	var frozen_delta := minf(maxf(delta, 0.0), _freezer_time_remaining)
	_freezer_time_remaining = maxf(_freezer_time_remaining - frozen_delta, 0.0)
	_update_freezer_visuals()
	return maxf(delta - frozen_delta, 0.0)


func _is_freezer_active() -> bool:
	return _freezer_time_remaining > 0.0


func _clear_freezer() -> void:
	_freezer_time_remaining = 0.0
	_update_freezer_visuals()


func _update_freezer_visuals() -> void:
	var is_active := _is_freezer_active() and not _level_failed and not _level_completed
	if _ability_bar != null:
		_ability_bar.set_active_seconds(
			ABILITY_FREEZER,
			_freezer_time_remaining if is_active else 0.0
		)
	if _top_hud != null:
		_top_hud.set_timer_frozen_visual(is_active)


func _update_ability_buttons() -> void:
	if _ability_bar != null:
		_ability_bar.set_uses(_ability_uses)
		_ability_bar.set_interaction_blocked(
			_level_failed or _level_completed or _level_paused or _is_ability_effect_active(),
			_is_freezer_active()
		)
	_update_highlight_timer_label()
	_update_freezer_visuals()


func _reset_ability_uses() -> void:
	_ability_uses = {
		ABILITY_HAMMER: 3,
		ABILITY_SHUFFLE: 3,
		ABILITY_HIGHLIGHT: 3,
		ABILITY_FREEZER: 3,
	}


func _load_ability_uses() -> void:
	if launched_from_dev_mode:
		_reset_ability_uses()
		return

	var saved_uses := PlayerProgress.get_ability_uses()
	_ability_uses = {
		ABILITY_HAMMER: maxi(int(saved_uses.get(String(ABILITY_HAMMER), 3)), 0),
		ABILITY_SHUFFLE: maxi(int(saved_uses.get(String(ABILITY_SHUFFLE), 3)), 0),
		ABILITY_HIGHLIGHT: maxi(int(saved_uses.get(String(ABILITY_HIGHLIGHT), 3)), 0),
		ABILITY_FREEZER: maxi(int(saved_uses.get(String(ABILITY_FREEZER), 3)), 0),
	}
func _get_ability_icon_texture(ability_id: StringName) -> Texture2D:
	return _ability_bar.get_icon_texture(ability_id) if _ability_bar != null else null


func _get_ability_purchase_price(ability_id: StringName) -> int:
	return maxi(int(_ability_purchase_prices.get(ability_id, DEFAULT_ABILITY_PURCHASE_PRICES.get(ability_id, 0))), 0)


func _is_ability_effect_active() -> bool:
	return _hammer_effect_active or _shuffle_effect_active


func _set_moving_shelf_rows_paused(should_pause: bool) -> void:
	for moving_row in _get_all_moving_shelf_rows():
		moving_row.set_movement_paused(should_pause)


func _get_all_moving_shelf_rows() -> Array[MovingShelfRow]:
	var moving_rows: Array[MovingShelfRow] = []
	_collect_moving_shelf_rows_recursive(get_node("Shelves"), moving_rows)
	return moving_rows


func _collect_moving_shelf_rows_recursive(node: Node, moving_rows: Array[MovingShelfRow]) -> void:
	for child in node.get_children():
		var moving_row := child as MovingShelfRow
		if moving_row != null:
			moving_rows.append(moving_row)

		_collect_moving_shelf_rows_recursive(child, moving_rows)


func _get_all_shelves() -> Array[Node]:
	var shelves: Array[Node] = []
	_collect_shelves_recursive(get_node("Shelves"), shelves)

	return shelves


func _collect_shelves_recursive(node: Node, shelves: Array[Node]) -> void:
	for child in node.get_children():
		if _is_shelf_node(child):
			shelves.append(child)
			continue

		_collect_shelves_recursive(child, shelves)


func _is_shelf_node(node: Node) -> bool:
	return node is Node2D and _get_front_slots(node).size() == SLOT_COUNT


func _get_all_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for shelf in _get_all_shelves():
		_collect_items_recursive(shelf, items)

	return items


func _get_unlocked_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for shelf in _get_all_shelves():
		if _is_shelf_locked(shelf):
			continue

		_collect_items_recursive(shelf, items)

	return items


func _get_visible_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for shelf in _get_all_shelves():
		if _is_shelf_locked(shelf):
			continue

		for item in _get_shelf_items(shelf):
			if not _is_item_busy(item):
				items.append(item)

	return items


func _get_first_back_layer_items() -> Array[ShelfItem]:
	var items: Array[ShelfItem] = []
	for shelf in _get_all_shelves():
		if _is_shelf_locked(shelf):
			continue

		var shelf_node := shelf as Shelf
		if shelf_node == null:
			continue

		var back_layer := shelf_node.get_back_layer(Shelf.FIRST_BACK_LAYER_INDEX)
		if back_layer == null:
			continue

		for layer_slot_node in back_layer.get_children():
			var layer_slot := layer_slot_node as Node2D
			if layer_slot == null:
				continue

			var item := _get_slot_item(layer_slot)
			if item != null and not _is_item_busy(item):
				items.append(item)

	return items


func _collect_items_recursive(node: Node, items: Array[ShelfItem]) -> void:
	for child in node.get_children():
		var item := child as ShelfItem
		if item != null:
			if not item.is_queued_for_deletion() and not _is_item_busy(item):
				items.append(item)
			continue

		_collect_items_recursive(child, items)


func _get_owning_shelf(node: Node) -> Node:
	var current := node
	var shelves := get_node("Shelves")
	while current != null:
		if current != shelves and _is_shelf_node(current):
			return current

		current = current.get_parent()

	return null


func _shuffle_array(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temp = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temp
