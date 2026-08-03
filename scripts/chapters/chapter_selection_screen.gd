extends Control

signal chapter_selected(chapter_id: String)
signal closed

const CHAPTER_CARD_SCENE := preload("res://scenes/ui/chapter_card.tscn")

@onready var _back_button := %BackButton as Button
@onready var _card_list := %CardList as VBoxContainer


func _ready() -> void:
	_back_button.pressed.connect(_close)
	_populate()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _populate() -> void:
	var selected_id := PlayerProgress.get_selected_chapter_id()
	for chapter in ChapterCatalog.get_chapters():
		var chapter_id := str(chapter.get("id", ""))
		var card := CHAPTER_CARD_SCENE.instantiate()
		_card_list.add_child(card)
		card.call("configure", chapter, PlayerProgress.get_chapter_progress(chapter_id), chapter_id == selected_id)
		card.connect("selected", Callable(self, "_select_chapter"))


func _select_chapter(chapter_id: String) -> void:
	if not PlayerProgress.select_chapter(chapter_id):
		return
	chapter_selected.emit(chapter_id)
	_close()


func _close() -> void:
	closed.emit()
	queue_free()

