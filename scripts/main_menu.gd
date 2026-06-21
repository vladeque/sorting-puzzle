extends Control

const LEVEL_SCENE := preload("res://level.tscn")
const MIN_LEVEL := 1
const MAX_LEVEL := 10

@onready var _level_grid := %LevelGrid as GridContainer


func _ready() -> void:
	_populate_level_selector()


func _populate_level_selector() -> void:
	for child in _level_grid.get_children():
		child.queue_free()

	for level_number in range(MIN_LEVEL, MAX_LEVEL + 1):
		var button := Button.new()
		button.text = str(level_number)
		button.custom_minimum_size = Vector2(96, 88)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_launch_level.bind(level_number))
		_level_grid.add_child(button)


func _launch_level(level_number: int) -> void:
	var level_scene := LEVEL_SCENE.instantiate()
	level_scene.selected_level = level_number

	var tree := get_tree()
	var current_scene := tree.current_scene
	tree.root.add_child(level_scene)
	tree.current_scene = level_scene

	if current_scene != null:
		current_scene.queue_free()
