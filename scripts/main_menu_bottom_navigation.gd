extends MarginContainer

signal shop_pressed
signal home_pressed
signal leaderboard_pressed

@onready var _shop_button := %ShopButton as Button
@onready var _home_button := %HomeButton as Button
@onready var _leaderboard_button := %LeaderboardButton as Button


func _ready() -> void:
	_shop_button.pressed.connect(shop_pressed.emit)
	_home_button.pressed.connect(home_pressed.emit)
	_leaderboard_button.pressed.connect(leaderboard_pressed.emit)


func set_safe_bottom_margin(margin: float) -> void:
	add_theme_constant_override("margin_bottom", roundi(maxf(margin, 0.0)))
