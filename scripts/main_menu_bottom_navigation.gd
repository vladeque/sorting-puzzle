extends MarginContainer

## Retapping the already-active tab is intentionally a no-op here too: `pressed` is a native Button
## signal that fires on every press regardless of prior state, so it always forwards. The owning
## screen (production_main_menu.gd/shop_screen.gd/leaderboard_screen.gd) is the one that decides
## whether its own matching signal actually does anything -- see docs/SCENES.md's "Active-Tab
## Reselection Rule".
signal shop_pressed
signal home_pressed
signal leaderboard_pressed

const UIMotionScript := preload("res://scripts/ui_motion.gd")

const TAB_SHOP := "shop"
const TAB_HOME := "home"
const TAB_LEADERBOARD := "leaderboard"
const INACTIVE_ICON_TOP := -50.0
const INACTIVE_ICON_BOTTOM := 50.0
const ACTIVE_ICON_TOP := -76.0
const ACTIVE_ICON_BOTTOM := 24.0
const ICON_TWEEN_META := &"_nav_icon_tween"
const LABEL_TWEEN_META := &"_nav_label_tween"

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


## Animates the active-tab icon raise/lower and label fade over
## UIMotion.NAV_ACTIVE_CHANGE_DURATION instead of jumping, including the very first call each time
## a destination scene loads (screens never live-switch their own bottom nav's active tab -- Home,
## Shop, and Leaderboard are separate scenes -- so scene entry is the only moment this is visible).
## Kills any tween already in flight per icon/label so rapid re-entry never accumulates offsets or
## opacity.
func _set_tab_active(icon: TextureRect, label: Label, is_active: bool) -> void:
	var target_top := ACTIVE_ICON_TOP if is_active else INACTIVE_ICON_TOP
	var target_bottom := ACTIVE_ICON_BOTTOM if is_active else INACTIVE_ICON_BOTTOM
	var icon_tween := UIMotionScript.retween(icon, ICON_TWEEN_META)
	icon_tween.set_parallel(true)
	icon_tween.tween_property(icon, "offset_top", target_top, UIMotionScript.NAV_ACTIVE_CHANGE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	icon_tween.tween_property(icon, "offset_bottom", target_bottom, UIMotionScript.NAV_ACTIVE_CHANGE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var label_tween := UIMotionScript.retween(label, LABEL_TWEEN_META)
	if is_active:
		label.modulate.a = 0.0
		label.visible = true
		label_tween.tween_property(label, "modulate:a", 1.0, UIMotionScript.NAV_ACTIVE_CHANGE_DURATION)
	else:
		label_tween.tween_property(label, "modulate:a", 0.0, UIMotionScript.NAV_ACTIVE_CHANGE_DURATION)
		label_tween.tween_callback(label.hide)
