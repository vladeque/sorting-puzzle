extends Control
class_name CoinBalanceWidget

## Regular is the Shop header's existing size; compact is sized to fit the Main Menu top-status
## row through scenes/ui/main_menu_coin_shortcut.tscn. Both variants reuse the exact same %Pill
## StyleBoxFlat resource, %CoinIcon texture, and GameNumberLabel styling -- only geometry changes,
## so the two screens show the same palette/border/shape/icon by construction.
const REGULAR_SIZE := Vector2(158.0, 68.0)
const COMPACT_SIZE := Vector2(142.0, 60.0)
const REGULAR_PILL_RECT := Rect2(30.0, 10.0, 128.0, 52.0)
const COMPACT_PILL_RECT := Rect2(24.0, 8.0, 118.0, 44.0)
const REGULAR_ICON_RECT := Rect2(-2.0, -2.0, 72.0, 72.0)
const COMPACT_ICON_RECT := Rect2(-2.0, -2.0, 60.0, 60.0)
const REGULAR_LABEL_RECT := Rect2(65.0, 14.0, 86.0, 44.0)
const COMPACT_LABEL_RECT := Rect2(52.0, 10.0, 84.0, 40.0)
const REGULAR_FONT_SIZES := [25, 21, 18]
const COMPACT_FONT_SIZES := [22, 18, 15]

@onready var _pill := %Pill as Control
@onready var _coin_icon := %CoinIcon as Control
@onready var _amount_label := %AmountLabel as Label

var _amount := 0
var _is_compact := false


func _ready() -> void:
	_apply_size_variant()
	_update_label()


func set_amount(amount: int) -> void:
	_amount = maxi(amount, 0)
	if is_node_ready():
		_update_label()


func get_coin_icon_global_center() -> Vector2:
	return _coin_icon.get_global_rect().get_center()


func set_compact(is_compact: bool) -> void:
	if _is_compact == is_compact:
		return
	_is_compact = is_compact
	if is_node_ready():
		_apply_size_variant()
		_update_label()


func _apply_size_variant() -> void:
	custom_minimum_size = COMPACT_SIZE if _is_compact else REGULAR_SIZE
	_apply_rect(_pill, COMPACT_PILL_RECT if _is_compact else REGULAR_PILL_RECT)
	_apply_rect(_coin_icon, COMPACT_ICON_RECT if _is_compact else REGULAR_ICON_RECT)
	_apply_rect(_amount_label, COMPACT_LABEL_RECT if _is_compact else REGULAR_LABEL_RECT)


func _apply_rect(control: Control, rect: Rect2) -> void:
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


func _update_label() -> void:
	var amount_text := _format_amount(_amount)
	_amount_label.text = amount_text
	_amount_label.add_theme_font_size_override("font_size", _get_font_size(amount_text.length()))


func _get_font_size(character_count: int) -> int:
	var tiers := COMPACT_FONT_SIZES if _is_compact else REGULAR_FONT_SIZES
	if character_count <= 5:
		return tiers[0]
	if character_count <= 7:
		return tiers[1]
	return tiers[2]


func _format_amount(amount: int) -> String:
	var amount_text := str(maxi(amount, 0))
	var formatted := ""
	while amount_text.length() > 3:
		formatted = ",%s%s" % [amount_text.right(3), formatted]
		amount_text = amount_text.substr(0, amount_text.length() - 3)
	return amount_text + formatted
