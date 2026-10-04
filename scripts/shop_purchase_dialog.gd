extends Control
class_name ShopPurchaseDialog

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const ModalAwningHeaderScript := preload("res://scripts/modal_awning_header.gd")

@onready var _header := %AwningHeader as ModalAwningHeaderScript
@onready var _message_label := %MessageLabel as Label
@onready var _close_button := %CloseButton as Button


func _ready() -> void:
	_close_button.pressed.connect(close)


var _result_title := ""


func show_result(title: String, message: String, button_text: String = "Continue") -> void:
	_result_title = title
	_header.set_title(tr(title).to_upper())
	_message_label.text = message
	_close_button.text = button_text
	UIMotionScript.fade_in(self)


## Fades out and hides this dialog (never freed -- shop_screen.gd reuses the same instance for
## every purchase result). Safe to call more than once (Close pressed, or `ui_cancel` arriving)
## while already closing -- a repeat call is ignored.
func close() -> void:
	UIMotionScript.close_with_fade(self, hide)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_header.set_title(tr(_result_title).to_upper())
