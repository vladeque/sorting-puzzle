extends Button

signal selected(chapter_id: String)

var _chapter_id := ""

@onready var _preview := %Preview as TextureRect
@onready var _number_label := %NumberLabel as Label
@onready var _title_label := %TitleLabel as Label
@onready var _progress_label := %ProgressLabel as Label
@onready var _lock_label := %LockLabel as Label


func _ready() -> void:
	pressed.connect(_emit_selected)


func configure(chapter: Dictionary, progress: Dictionary, is_selected: bool) -> void:
	_chapter_id = str(chapter.get("id", ""))
	_number_label.text = "CHAPTER %d" % int(chapter.get("order", 0))
	_title_label.text = str(chapter.get("title", "Chapter"))
	var preview_path := ChapterCatalog.get_selection_preview_path(_chapter_id)
	_preview.texture = load(preview_path) as Texture2D if not preview_path.is_empty() else null

	var unlocked := bool(progress.get("unlocked", false))
	disabled = not unlocked
	if not unlocked:
		_progress_label.text = "Complete %d levels in the previous chapter" % int(
			progress.get("required_completed_levels", 0)
		)
		_lock_label.text = "LOCKED  ·  %d/%d" % [
			int(progress.get("previous_completed_levels", 0)),
			int(progress.get("required_completed_levels", 0)),
		]
		return

	if not bool(progress.get("has_levels", false)):
		_progress_label.text = "New levels are coming soon"
		_lock_label.text = "SELECTED" if is_selected else "COMING SOON"
		return

	_progress_label.text = "%d of %d levels complete" % [
		int(progress.get("completed_levels", 0)),
		int(progress.get("total_levels", 0)),
	]
	_lock_label.text = "SELECTED" if is_selected else "PLAY"


func _emit_selected() -> void:
	selected.emit(_chapter_id)

