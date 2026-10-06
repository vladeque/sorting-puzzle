extends VBoxContainer
class_name SupportFaqItem

signal expansion_changed(item: SupportFaqItem, expanded: bool)
signal action_requested(action_id: StringName)

@export var question := "Question"
@export_multiline var answer := "Answer"
@export var action_text := ""
@export var action_id := &""
@export var question_font_size := 22
@export var minimum_question_font_size := 16

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
	_question_button.resized.connect(_fit_question)
	_action_button.pressed.connect(func() -> void: action_requested.emit(action_id))
	set_expanded(false, false)
	_apply_reading_alignment()
	_fit_question.call_deferred()


func _fit_question() -> void:
	var style := _question_button.get_theme_stylebox("normal")
	var available_width := _question_button.size.x \
		- style.get_content_margin(SIDE_LEFT) - style.get_content_margin(SIDE_RIGHT)
	if available_width <= 0.0:
		return
	var font := _question_button.get_theme_font("font")
	var caption := _question_button.atr(_question_button.text)
	var fitted_size := question_font_size
	while fitted_size > minimum_question_font_size and font.get_string_size(
		caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size
	).x > available_width:
		fitted_size -= 1
	_question_button.add_theme_font_size_override("font_size", fitted_size)


func _apply_reading_alignment() -> void:
	var rtl := is_layout_rtl()
	_answer_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT
	)
	for state in [&"normal", &"pressed"]:
		var style := _question_button.get_theme_stylebox(state) as StyleBoxFlat
		var leading_margin := minf(style.content_margin_left, style.content_margin_right)
		var trailing_margin := maxf(style.content_margin_left, style.content_margin_right)
		style.content_margin_left = trailing_margin if rtl else leading_margin
		style.content_margin_right = leading_margin if rtl else trailing_margin


func _notification(what: int) -> void:
	if what in [NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_LAYOUT_DIRECTION_CHANGED] and is_node_ready():
		_apply_reading_alignment.call_deferred()
		_fit_question.call_deferred()


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
