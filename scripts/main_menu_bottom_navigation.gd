extends MarginContainer

signal shop_pressed
signal home_pressed
signal leaderboard_pressed

const TAB_SHOP := "shop"
const TAB_HOME := "home"
const TAB_LEADERBOARD := "leaderboard"
const INACTIVE_ICON_TOP := -50.0
const INACTIVE_ICON_BOTTOM := 50.0
const ACTIVE_ICON_TOP := -76.0
const ACTIVE_ICON_BOTTOM := 24.0

@export_enum("shop", "home", "leaderboard") var active_tab := "home"

@onready var _shop_button := %ShopButton as Button
@onready var _home_button := %HomeButton as Button
@onready var _leaderboard_button := %LeaderboardButton as Button
@onready var _shop_icon := %ShopButton.get_node("Icon") as TextureRect
@onready var _home_icon := %HomeButton.get_node("Icon") as TextureRect
@onready var _leaderboard_icon := %LeaderboardButton.get_node("Icon") as TextureRect
@onready var _shop_label := %ShopButton.get_node("ActiveLabel") as Label
@onready var _home_label := %HomeButton.get_node("ActiveLabel") as Label
@onready var _leaderboard_label := %LeaderboardButton.get_node("ActiveLabel") as Label


func _ready() -> void:
	_shop_button.pressed.connect(shop_pressed.emit)
	_home_button.pressed.connect(home_pressed.emit)
	_leaderboard_button.pressed.connect(leaderboard_pressed.emit)
	_apply_active_tab()


func set_active_tab(tab_name: StringName) -> void:
	var normalized_name := String(tab_name).to_lower()
	if normalized_name not in [TAB_SHOP, TAB_HOME, TAB_LEADERBOARD]:
		push_warning("Unknown bottom navigation tab: %s" % tab_name)
		return

	active_tab = normalized_name
	if is_node_ready():
		_apply_active_tab()


func set_safe_bottom_margin(margin: float) -> void:
	add_theme_constant_override("margin_bottom", roundi(maxf(margin, 0.0)))


func _apply_active_tab() -> void:
	_set_tab_active(_shop_icon, _shop_label, active_tab == TAB_SHOP)
	_set_tab_active(_home_icon, _home_label, active_tab == TAB_HOME)
	_set_tab_active(_leaderboard_icon, _leaderboard_label, active_tab == TAB_LEADERBOARD)


func _set_tab_active(icon: TextureRect, label: Label, is_active: bool) -> void:
	icon.offset_top = ACTIVE_ICON_TOP if is_active else INACTIVE_ICON_TOP
	icon.offset_bottom = ACTIVE_ICON_BOTTOM if is_active else INACTIVE_ICON_BOTTOM
	label.visible = is_active
