extends VBoxContainer
class_name SupportFaqItem

signal expansion_changed(item: SupportFaqItem, expanded: bool)
signal action_requested(action_id: StringName)

@export var question := "Question"
@export_multiline var answer := "Answer"
@export var action_text := ""
@export var action_id := &""

@onready var _question_button := %QuestionButton as Button
@onready var _chevron_label := %ChevronLabel as Label
@onready var _answer_panel := %AnswerPanel as PanelContainer
@onready var _answer_label := %AnswerLabel as RichTextLabel
@onready var _action_button := %ActionButton as Button

var _expanded := false


func _ready() -> void:
	_question_button.text = question
	_answer_label.text = answer
	_action_button.text = action_text
	_action_button.visible = not action_text.is_empty() and action_id != StringName()
	_question_button.pressed.connect(_toggle_expanded)
	_action_button.pressed.connect(func() -> void: action_requested.emit(action_id))
	set_expanded(false, false)


func set_answer(value: String) -> void:
	answer = value
	if is_node_ready():
		_answer_label.text = value


func set_expanded(value: bool, emit_change: bool = true) -> void:
	_expanded = value
	if not is_node_ready():
		return
	_answer_panel.visible = value
	_chevron_label.text = "−" if value else "+"
	_question_button.set_pressed_no_signal(value)
	if emit_change:
		expansion_changed.emit(self, value)


func is_expanded() -> bool:
	return _expanded


func _toggle_expanded() -> void:
	set_expanded(not _expanded)
