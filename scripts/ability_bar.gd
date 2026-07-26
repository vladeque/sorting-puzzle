extends Control
class_name AbilityBar

signal ability_pressed(ability_id: StringName)

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
const COMPACT_VIEWPORT_WIDTH := 620.0
const COMPACT_BUTTON_SIZE := Vector2(82.0, 82.0)
const REGULAR_BUTTON_SIZE := Vector2(96.0, 96.0)

@onready var _button_row := %ButtonRow as HBoxContainer
@onready var _buttons := {
	ABILITY_HAMMER: %HammerButton as Button,
	ABILITY_SHUFFLE: %ShuffleButton as Button,
	ABILITY_HIGHLIGHT: %HighlightButton as Button,
	ABILITY_FREEZER: %FreezerButton as Button,
}


func _ready() -> void:
	for ability_id in ABILITY_IDS:
		var button := _buttons.get(ability_id) as Button
		if button != null:
			button.pressed.connect(ability_pressed.emit.bind(ability_id))


func set_uses(ability_uses: Dictionary) -> void:
	for ability_id in ABILITY_IDS:
		var button := _buttons.get(ability_id) as Button
		if button == null:
			continue
		var uses_label := button.get_node_or_null("UsesLabel") as Label
		if uses_label != null:
			uses_label.text = str(maxi(int(ability_uses.get(ability_id, 0)), 0))


func set_interaction_blocked(is_blocked: bool, freezer_active: bool) -> void:
	for ability_id in ABILITY_IDS:
		var button := _buttons.get(ability_id) as Button
		if button != null:
			button.disabled = is_blocked or (ability_id == ABILITY_FREEZER and freezer_active)


func set_active_seconds(ability_id: StringName, seconds_remaining: float) -> void:
	var button := _buttons.get(ability_id) as Button
	if button == null:
		return
	var timer_label := button.get_node_or_null("TimerLabel") as Label
	if timer_label == null:
		return
	timer_label.visible = seconds_remaining > 0.0
	if timer_label.visible:
		timer_label.text = "%ds" % ceili(seconds_remaining)


func get_icon_texture(ability_id: StringName) -> Texture2D:
	var button := _buttons.get(ability_id) as Button
	if button == null:
		return null
	var icon := button.get_node_or_null("Icon") as TextureRect
	return icon.texture if icon != null else null


func get_ability_button(ability_id: StringName) -> Button:
	return _buttons.get(ability_id) as Button


func apply_responsive_layout(viewport_width: float) -> void:
	var is_compact := viewport_width <= COMPACT_VIEWPORT_WIDTH
	var button_size := COMPACT_BUTTON_SIZE if is_compact else REGULAR_BUTTON_SIZE
	_button_row.add_theme_constant_override("separation", 18 if is_compact else 34)
	for ability_id in ABILITY_IDS:
		var button := _buttons.get(ability_id) as Button
		if button != null:
			button.custom_minimum_size = button_size
