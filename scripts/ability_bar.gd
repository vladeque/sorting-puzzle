extends Control
class_name AbilityBar

signal ability_pressed(ability_id: StringName)

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")

const ABILITY_HAMMER := &"hammer"
const ABILITY_SHUFFLE := &"shuffle"
const ABILITY_HIGHLIGHT := &"highlight"
const ABILITY_FREEZER := &"freezer"
const ABILITY_IDS := [
	ABILITY_HAMMER,
	ABILITY_SHUFFLE,
	ABILITY_HIGHLIGHT,
	ABILITY_FREEZER,
]
@onready var _button_row := %ButtonRow as HBoxContainer
@onready var _buttons := {
	ABILITY_HAMMER: %HammerButton as Button,
	ABILITY_SHUFFLE: %ShuffleButton as Button,
	ABILITY_HIGHLIGHT: %HighlightButton as Button,
	ABILITY_FREEZER: %FreezerButton as Button,
}

## Each button's Icon/UsesLabel/TimerLabel rects as authored in the scene (calibrated for
## GameplayUITheme.HUD_ICON_REGULAR_SIZE). apply_responsive_layout() scales these proportionally
## for the compact size instead of only resizing the parent button -- previously the icon and both
## badge types stayed at their 115.2px-authored offsets and overflowed a 98.4px compact button.
var _reference_child_rects: Dictionary = {}
var _active_seconds: Dictionary = {}


func _ready() -> void:
	for ability_id in ABILITY_IDS:
		var button := _buttons.get(ability_id) as Button
		if button != null:
			button.pressed.connect(ability_pressed.emit.bind(ability_id))
			_reference_child_rects[ability_id] = _capture_reference_rects(button)


func set_uses(ability_uses: Dictionary) -> void:
	for ability_id in ABILITY_IDS:
		var button := _buttons.get(ability_id) as Button
		if button == null:
			continue
		var uses_label := button.get_node_or_null("UsesLabel") as Label
		if uses_label != null:
			uses_label.text = str(maxi(int(ability_uses.get(ability_id, 0)), 0))
			_fit_uses_label(uses_label)


func set_interaction_blocked(
	is_blocked: bool,
	lantern_active: bool,
	freezer_active: bool
) -> void:
	var timed_ability_active := lantern_active or freezer_active
	for ability_id in ABILITY_IDS:
		var button := _buttons.get(ability_id) as Button
		if button != null:
			button.disabled = (
				is_blocked
				or (timed_ability_active and ability_id in [ABILITY_HIGHLIGHT, ABILITY_FREEZER])
			)
			button.mouse_default_cursor_shape = (
				Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
			)


func set_active_seconds(ability_id: StringName, seconds_remaining: float) -> void:
	_active_seconds[ability_id] = seconds_remaining
	var button := _buttons.get(ability_id) as Button
	if button == null:
		return
	var timer_label := button.get_node_or_null("TimerLabel") as Label
	if timer_label == null:
		return
	timer_label.visible = seconds_remaining > 0.0
	if timer_label.visible:
		timer_label.text = tr("hud.seconds_short") % ceili(seconds_remaining)


func get_icon_texture(ability_id: StringName) -> Texture2D:
	var button := _buttons.get(ability_id) as Button
	if button == null:
		return null
	var icon := button.get_node_or_null("Icon") as TextureRect
	return icon.texture if icon != null else null


func get_ability_button(ability_id: StringName) -> Button:
	return _buttons.get(ability_id) as Button


func apply_responsive_layout(usable_width: float) -> void:
	var is_compact := usable_width <= GameplayUIThemeScript.HUD_ICON_COMPACT_VIEWPORT_WIDTH
	var button_size := GameplayUIThemeScript.get_hud_icon_size(usable_width)
	var reference_size := GameplayUIThemeScript.HUD_ICON_REGULAR_SIZE
	var scale := button_size.x / reference_size.x if reference_size.x > 0.0 else 1.0
	var compact_scale := (
		button_size.x / GameplayUIThemeScript.HUD_ICON_COMPACT_SIZE.x if is_compact else 1.0
	)

	_button_row.add_theme_constant_override(
		"separation",
		maxi(roundi(18.0 * compact_scale), 1) if is_compact else 34
	)
	for ability_id in ABILITY_IDS:
		var button := _buttons.get(ability_id) as Button
		if button == null:
			continue

		button.custom_minimum_size = button_size
		var rects: Dictionary = _reference_child_rects.get(ability_id, {})
		_apply_scaled_rect(button.get_node_or_null("Icon") as Control, rects.get("icon"), scale)
		var uses_label := button.get_node_or_null("UsesLabel") as Label
		_apply_scaled_rect(uses_label, rects.get("uses_label"), scale)
		_apply_scaled_rect(button.get_node_or_null("TimerLabel") as Control, rects.get("timer_label"), scale)
		_fit_uses_label(uses_label)


func _capture_reference_rects(button: Button) -> Dictionary:
	var child_names_by_key := {
		"icon": "Icon",
		"uses_label": "UsesLabel",
		"timer_label": "TimerLabel",
	}
	var rects := {}
	for key in child_names_by_key.keys():
		var child := button.get_node_or_null(child_names_by_key[key]) as Control
		if child == null:
			continue
		rects[key] = Rect2(
			child.offset_left,
			child.offset_top,
			child.offset_right - child.offset_left,
			child.offset_bottom - child.offset_top
		)
	return rects


func _apply_scaled_rect(control: Control, reference: Variant, scale: float) -> void:
	if control == null or reference == null:
		return

	var rect := reference as Rect2
	control.offset_left = rect.position.x * scale
	control.offset_top = rect.position.y * scale
	control.offset_right = (rect.position.x + rect.size.x) * scale
	control.offset_bottom = (rect.position.y + rect.size.y) * scale


func _fit_uses_label(uses_label: Label) -> void:
	if uses_label == null:
		return
	var available_width := (
		uses_label.offset_right
		- uses_label.offset_left
		- GameplayUIThemeScript.COUNT_BADGE_HORIZONTAL_PADDING
	)
	uses_label.add_theme_font_size_override(
		"font_size",
		GameplayUIThemeScript.fit_label_font_size(
			uses_label,
			available_width,
			GameplayUIThemeScript.COUNT_BADGE_MAX_FONT_SIZE,
			GameplayUIThemeScript.COUNT_BADGE_MIN_FONT_SIZE
		)
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		for ability_id in _active_seconds:
			set_active_seconds(ability_id, float(_active_seconds[ability_id]))
