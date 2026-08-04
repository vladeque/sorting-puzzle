extends PressScaleButton


func set_chapter(chapter: Dictionary, _progress: Dictionary) -> void:
	var order := int(chapter.get("order", 0))
	var title := str(chapter.get("title", "Chapter"))
	text = "CHAPTER %d" % order
	tooltip_text = "Choose Chapter %d: %s" % [order, title]
