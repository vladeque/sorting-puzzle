extends CenterContainer

## Shared loading/empty/error/Retry presentation for Shop/Leaderboard-style destination screens.
## Purely presentational: the owning screen decides when to call each state and what the retry
## action actually does.

signal retry_pressed

@onready var _message_label := %StatusMessageLabel as Label
@onready var _retry_button := %StatusRetryButton as Button


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry_pressed)


## No Retry action -- an in-progress load, not a failure.
func show_loading(message: String) -> void:
	visible = true
	_message_label.text = message
	_retry_button.visible = false


## No Retry action -- a legitimately empty result, not a failure.
func show_empty(message: String) -> void:
	visible = true
	_message_label.text = message
	_retry_button.visible = false


## Shows Retry so the player can ask the owning screen to reload.
func show_error(message: String) -> void:
	visible = true
	_message_label.text = message
	_retry_button.visible = true


func hide_status() -> void:
	visible = false


func _on_retry_pressed() -> void:
	retry_pressed.emit()
