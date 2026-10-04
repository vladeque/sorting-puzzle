extends PressScaleButton

var _chapter: Dictionary = {}


func set_chapter(chapter: Dictionary, _progress: Dictionary) -> void:
	_chapter = chapter.duplicate(true)
	var order := int(chapter.get("order", 0))
	var title := tr(str(chapter.get("title", "Chapter")))
	text = tr("chapter.button") % order
	tooltip_text = tr("chapter.button_tooltip") % [order, title]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and not _chapter.is_empty():
		set_chapter(_chapter, {})
