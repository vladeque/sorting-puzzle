extends Control

signal chapter_selected(chapter_id: String)
signal closed

const CHAPTER_COVER_CARD_SCENE := preload("res://scenes/ui/chapter_cover_card.tscn")
const DestinationScreenLayoutScript := preload("res://scripts/destination_screen_layout.gd")
## Authored pixel height of %HeaderMargins before any additional top safe-area inset is applied.
const HEADER_HEIGHT := 112.0

@onready var _back_button := %BackButton as Button
@onready var _pager := %Pager as HorizontalPager
@onready var _header_margins := %HeaderMargins as MarginContainer
@onready var _title_label := %ChaptersTitleLabel as Label

var _cards: Array[ChapterCoverCard] = []


func _ready() -> void:
	_back_button.pressed.connect(_close)
	_populate()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


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
		_cards.append(card)
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


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_title_label.add_theme_font_size_override(
		"font_size", DestinationScreenLayoutScript.get_title_font_size(viewport_size)
	)
	_apply_safe_margins(DestinationScreenLayoutScript.get_safe_area_margins(viewport_size))


## Split from _apply_responsive_layout() so tests can exercise a simulated inset directly: the
## real safe-area lookup always yields Vector4.ZERO outside Android/iOS (see
## DestinationScreenLayout.get_safe_area_margins()), so this is the only way to verify the back
## button, title, page arrows/indicators, and each card's information panel actually respect a
## non-zero inset while the full-bleed art underneath does not move.
func _apply_safe_margins(margins: Vector4) -> void:
	_header_margins.offset_left = margins.x
	_header_margins.offset_top = margins.y
	_header_margins.offset_right = -margins.z
	_header_margins.offset_bottom = margins.y + HEADER_HEIGHT
	_pager.call("set_safe_margins", margins)
	for card in _cards:
		if is_instance_valid(card):
			card.call("set_safe_margins", margins)
