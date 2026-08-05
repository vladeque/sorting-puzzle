extends Control
class_name ShopPurchaseDialog

const UIMotionScript := preload("res://scripts/ui_motion.gd")

@onready var _title_label := %TitleLabel as Label
@onready var _message_label := %MessageLabel as Label
@onready var _close_button := %CloseButton as Button


func _ready() -> void:
	_close_button.pressed.connect(close)


func show_result(title: String, message: String, button_text: String = "Continue") -> void:
	_title_label.text = title.to_upper()
	_message_label.text = message
	_close_button.text = button_text
	UIMotionScript.fade_in(self)


## Fades out and hides this dialog (never freed -- shop_screen.gd reuses the same instance for
## every purchase result). Safe to call more than once (Close pressed, or `ui_cancel` arriving)
## while already closing -- a repeat call is ignored.
func close() -> void:
	UIMotionScript.close_with_fade(self, hide)
