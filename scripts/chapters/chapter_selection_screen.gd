extends Control

signal chapter_selected(chapter_id: String)
signal closed

const CHAPTER_COVER_CARD_SCENE := preload("res://scenes/ui/chapter_cover_card.tscn")

@onready var _back_button := %BackButton as Button
@onready var _pager := %Pager as HorizontalPager


func _ready() -> void:
	_back_button.pressed.connect(_close)
	_populate()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _populate() -> void:
	var selected_id := PlayerProgress.get_selected_chapter_id()
	var chapters := ChapterCatalog.get_chapters()
	var initial_index := 0
	for chapter_index in chapters.size():
		var chapter := chapters[chapter_index]
		var chapter_id := str(chapter.get("id", ""))
		var card := CHAPTER_COVER_CARD_SCENE.instantiate() as ChapterCoverCard
		_pager.add_page(card)
		card.configure(chapter, PlayerProgress.get_chapter_progress(chapter_id), chapter_id == selected_id)
		card.selected.connect(_select_chapter)
		if chapter_id == selected_id:
			initial_index = chapter_index
	_pager.go_to_page(initial_index, false)


func _select_chapter(chapter_id: String) -> void:
	if not PlayerProgress.select_chapter(chapter_id):
		return
	chapter_selected.emit(chapter_id)
	_close()


func _close() -> void:
	closed.emit()
	queue_free()
