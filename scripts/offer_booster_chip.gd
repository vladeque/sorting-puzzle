extends VBoxContainer
class_name OfferBoosterChip

## One booster reward in an offer (Starter Bundle modal): the ability icon in the same dark round
## socket the level's ability bar uses, a count badge on the socket's corner, and the booster name
## underneath. Each instance authors its own `icon` and `title`; the owner sets the count from the
## loaded offer. `set_claimed(true)` swaps the count badge for a green check and prefixes the name
## with the granted amount for the purchase-complete state.

@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			_icon_rect.texture = icon
@export var title := "Booster":
	set(value):
		title = value
		if is_node_ready():
			_refresh_labels()
@export var count_badge_style: StyleBox
@export var claimed_badge_style: StyleBox
@export var check_color := Color(1, 1, 1, 1)
@export var check_width := 3.4
@export var name_font_size := 18
## The claimed name carries the amount ("+3 Freezer"), so it steps down to stay within the chip.
@export var claimed_name_font_size := 16
## The default brown suits the Starter Bundle's light panel; the reward-chest ceremony shows chips
## over a dimmed screen and switches to light text with an outline.
@export var name_color := Color(0.42, 0.165, 0.086, 1)
@export var name_outline_color := Color(0, 0, 0, 0)
@export var name_outline_size := 0

@onready var _icon_rect := %Icon as TextureRect
@onready var _count_badge := %CountBadge as Panel
@onready var _count_label := %CountLabel as Label
@onready var _check_mark := %CheckMark as Control
@onready var _name_label := %NameLabel as Label

var _count := 0
var _is_claimed := false


func _ready() -> void:
	_icon_rect.texture = icon
	_check_mark.draw.connect(_draw_check_mark)
	_name_label.add_theme_color_override("font_color", name_color)
	_name_label.add_theme_color_override("font_outline_color", name_outline_color)
	_name_label.add_theme_constant_override("outline_size", name_outline_size)
	_refresh_labels()


## Shows the chip for a positive count and hides it otherwise, so absent rewards leave no gap.
func set_count(count: int) -> void:
	_count = maxi(count, 0)
	visible = _count > 0
	_refresh_labels()


func get_count() -> int:
	return _count


func set_claimed(is_claimed: bool) -> void:
	_is_claimed = is_claimed
	_count_badge.add_theme_stylebox_override(
		"panel", claimed_badge_style if is_claimed else count_badge_style
	)
	_count_label.visible = not is_claimed
	_check_mark.visible = is_claimed
	_name_label.add_theme_font_size_override(
		"font_size", claimed_name_font_size if is_claimed else name_font_size
	)
	_refresh_labels()


func is_claimed() -> bool:
	return _is_claimed


## Where the ability icon currently sits, so a flight can launch from exactly on top of it.
func get_icon_global_rect() -> Rect2:
	return _icon_rect.get_global_rect()


func _refresh_labels() -> void:
	_count_label.text = "×%d" % _count
	_name_label.text = "+%d %s" % [_count, title] if _is_claimed else title


func _draw_check_mark() -> void:
	var box := _check_mark.size
	_check_mark.draw_polyline(
		PackedVector2Array([
			Vector2(box.x * 0.24, box.y * 0.53),
			Vector2(box.x * 0.43, box.y * 0.72),
			Vector2(box.x * 0.78, box.y * 0.32),
		]),
		check_color,
		check_width,
		true
	)
