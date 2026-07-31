extends Control
class_name ShopPurchaseDialog

@onready var _title_label := %TitleLabel as Label
@onready var _message_label := %MessageLabel as Label
@onready var _close_button := %CloseButton as Button


func _ready() -> void:
	_close_button.pressed.connect(hide)


func show_result(title: String, message: String) -> void:
	_title_label.text = title.to_upper()
	_message_label.text = message
	show()
