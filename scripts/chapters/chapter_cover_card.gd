class_name ChapterCoverCard
extends Control

signal selected(chapter_id: String)

const LOCKED_ART_TINT := Color(0.75, 0.7, 0.62, 1.0)

@onready var _art: TextureRect = %Art
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _ring: ProgressRing = %Ring
@onready var _eyebrow_label: Label = %EyebrowLabel
@onready var _title_label: Label = %TitleLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _cta_button: Button = %CtaButton

var _chapter_id := ""


func _ready() -> void:
	_cta_button.pressed.connect(_emit_selected)


func configure(chapter: Dictionary, progress: Dictionary, is_selected: bool) -> void:
	_chapter_id = str(chapter.get("id", ""))
	_eyebrow_label.text = "CHAPTER %d" % int(chapter.get("order", 0))
	_title_label.text = str(chapter.get("title", "Chapter"))
	var preview_path := ChapterCatalog.get_selection_preview_path(_chapter_id)
	_art.texture = load(preview_path) as Texture2D if not preview_path.is_empty() else null

	var unlocked := bool(progress.get("unlocked", false))
	_cta_button.disabled = not unlocked
	_art.self_modulate = Color.WHITE if unlocked else LOCKED_ART_TINT
	_lock_icon.visible = not unlocked
	_ring.visible = unlocked

	if not unlocked:
		_ring.set_progress(
			int(progress.get("previous_completed_levels", 0)),
			int(progress.get("required_completed_levels", 0))
		)
		_caption_label.text = "Complete %d levels in the previous chapter" % int(
			progress.get("required_completed_levels", 0)
		)
		_cta_button.text = "LOCKED"
		return

	if not bool(progress.get("has_levels", false)):
		_ring.visible = false
		_caption_label.text = "New levels are coming soon"
		_cta_button.text = "SELECTED" if is_selected else "COMING SOON"
		return

	_ring.set_progress(int(progress.get("completed_levels", 0)), int(progress.get("total_levels", 0)))
	_caption_label.text = "%d of %d levels complete" % [
		int(progress.get("completed_levels", 0)),
		int(progress.get("total_levels", 0)),
	]
	if is_selected:
		_cta_button.text = "CONTINUE" if int(progress.get("completed_levels", 0)) > 0 else "PLAY"
	else:
		_cta_button.text = "PLAY"


func _emit_selected() -> void:
	selected.emit(_chapter_id)
