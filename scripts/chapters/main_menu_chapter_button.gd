extends Button

@onready var _preview := %Preview as TextureRect
@onready var _chapter_label := %ChapterLabel as Label
@onready var _progress_label := %ProgressLabel as Label


func set_chapter(chapter: Dictionary, progress: Dictionary) -> void:
	var chapter_id := str(chapter.get("id", ""))
	var order := int(chapter.get("order", 0))
	var title := str(chapter.get("title", "Chapter"))
	_chapter_label.text = "CHAPTER %d  ·  %s" % [order, title.to_upper()]
	var preview_path := ChapterCatalog.get_selection_preview_path(chapter_id)
	_preview.texture = load(preview_path) as Texture2D if not preview_path.is_empty() else null

	if not bool(progress.get("unlocked", false)):
		_progress_label.text = "LOCKED  ·  %d/%d TO UNLOCK" % [
			int(progress.get("previous_completed_levels", 0)),
			int(progress.get("required_completed_levels", 0)),
		]
		return
	if not bool(progress.get("has_levels", false)):
		_progress_label.text = "COMING SOON"
		return
	_progress_label.text = "%d/%d LEVELS COMPLETE" % [
		int(progress.get("completed_levels", 0)),
		int(progress.get("total_levels", 0)),
	]

