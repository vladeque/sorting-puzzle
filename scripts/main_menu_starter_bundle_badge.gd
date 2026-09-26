extends Control
class_name MainMenuStarterBundleBadge

signal pressed

@onready var _button := %BadgeButton as Button


func _ready() -> void:
	_button.pressed.connect(pressed.emit)
