class_name DevLevelPicker
extends VBoxContainer

## Developer level browser for the testing menu. It lists every level of one chapter in a scrolling
## grid and also accepts a typed level number, so selection stays usable as Chapter 1 grows from its
## current twenty levels toward the planned few hundred.

signal level_selected(level_number: int)

const BUTTON_MIN_SIZE := Vector2(96, 84)
const GRID_SEPARATION := 12
const MIN_COLUMNS := 3
const MAX_COLUMNS := 8
const SCROLL_INTO_VIEW_ATTEMPTS := 3
const EMPTY_STATUS := "No levels found."
const JUMP_HINT := "Tap a level, or type a number."

@onready var _scroll := %LevelScroll as ScrollContainer
@onready var _grid := %LevelGrid as GridContainer
@onready var _level_input := %LevelInput as LineEdit
@onready var _jump_button := %JumpButton as Button
@onready var _status_label := %StatusLabel as Label

var _level_numbers := PackedInt32Array()
var _buttons_by_level := {}
var _focus_level := 0
var _pending_focus_level := 0


func _ready() -> void:
	_jump_button.pressed.connect(_submit_typed_level)
	_level_input.text_submitted.connect(_on_level_input_submitted)
	_level_input.text_changed.connect(_on_level_input_changed)
	_scroll.resized.connect(_apply_grid_columns)
	_grid.sort_children.connect(_apply_pending_focus)
	_apply_grid_columns()
	_rebuild()


## Lists `level_numbers` as selectable buttons. `focus_level` is scrolled into view once the grid
## has been laid out, so the saved campaign level stays reachable in a long chapter.
func set_levels(level_numbers: PackedInt32Array, focus_level: int = 0) -> void:
	_level_numbers = level_numbers.duplicate()
	_focus_level = focus_level
	if is_node_ready():
		_rebuild()


func get_level_numbers() -> PackedInt32Array:
	return _level_numbers.duplicate()


## Returns the generated button for `level_number`, or null when the level is not listed.
func get_level_button(level_number: int) -> Button:
	return _buttons_by_level.get(level_number, null) as Button


func _rebuild() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_buttons_by_level.clear()

	for level_number in _level_numbers:
		var button := Button.new()
		button.text = str(level_number)
		button.custom_minimum_size = BUTTON_MIN_SIZE
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_select_level.bind(level_number))
		_grid.add_child(button)
		_buttons_by_level[level_number] = button

	var has_levels := not _level_numbers.is_empty()
	_level_input.editable = has_levels
	_jump_button.disabled = not has_levels
	_status_label.text = JUMP_HINT if has_levels else EMPTY_STATUS
	_pending_focus_level = _focus_level if _buttons_by_level.has(_focus_level) else 0


func _select_level(level_number: int) -> void:
	level_selected.emit(level_number)


func _on_level_input_submitted(_text: String) -> void:
	_submit_typed_level()


## The on-screen keyboard and a pasted value can still deliver non-digits, so the field is filtered
## rather than trusted.
func _on_level_input_changed(text: String) -> void:
	var digits := ""
	for character in text:
		if character >= "0" and character <= "9":
			digits += character
	if digits == text:
		return
	_level_input.text = digits
	_level_input.caret_column = digits.length()


func _submit_typed_level() -> void:
	var typed := _level_input.text.strip_edges()
	if typed.is_empty() or not typed.is_valid_int():
		_status_label.text = "Type a level number first."
		return

	var level_number := typed.to_int()
	if not _buttons_by_level.has(level_number):
		_status_label.text = "Level %d is not in this chapter." % level_number
		return

	_status_label.text = JUMP_HINT
	_select_level(level_number)


## Fits as many level buttons per row as the visible scroll width allows, because the grid has to
## stay readable on short and tall viewports alike.
func _apply_grid_columns() -> void:
	var available := _scroll.size.x
	var scroll_bar := _scroll.get_v_scroll_bar()
	if scroll_bar != null and scroll_bar.visible:
		available -= scroll_bar.size.x
	var columns := int(floor((available + GRID_SEPARATION) / (BUTTON_MIN_SIZE.x + GRID_SEPARATION)))
	columns = clampi(columns, MIN_COLUMNS, MAX_COLUMNS)
	if columns == _grid.columns:
		return

	_grid.columns = columns
	# A reflow moves every button, so a focus request made before the final column count still has
	# to be honored against the new rows.
	if _buttons_by_level.has(_focus_level):
		_pending_focus_level = _focus_level


## Runs once per rebuild, after the grid has positioned its buttons, so the requested level can be
## scrolled into view even when it sits hundreds of rows down.
func _apply_pending_focus() -> void:
	if _pending_focus_level <= 0:
		return
	var button := _buttons_by_level.get(_pending_focus_level, null) as Button
	_pending_focus_level = 0
	if button == null or not is_instance_valid(button):
		return
	_scroll_into_view(button)


## The scroll range only grows once the container has taken the sorted grid's new height, so the
## first request is clamped to the previous, much shorter content and has to be repeated.
func _scroll_into_view(button: Button) -> void:
	for attempt in range(SCROLL_INTO_VIEW_ATTEMPTS):
		if not _can_scroll_to(button):
			return
		_scroll.ensure_control_visible(button)
		if attempt < SCROLL_INTO_VIEW_ATTEMPTS - 1:
			await get_tree().process_frame


## A rebuild or a closing menu can free the button between two attempts, and the scroll container
## rejects a control it no longer owns.
func _can_scroll_to(button: Button) -> bool:
	return (
		is_instance_valid(button)
		and button.is_inside_tree()
		and _scroll.is_ancestor_of(button)
	)
