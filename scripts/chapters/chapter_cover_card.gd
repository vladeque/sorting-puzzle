class_name ChapterCoverCard
extends Control

signal selected(chapter_id: String)

const LOCKED_ART_TINT := Color(0.82, 0.78, 0.72, 1.0)
const DEFAULT_PANEL_HEIGHT := 244.0
const LOCKED_PANEL_HEIGHT := 290.0
## Authored left/right/bottom inset of %InfoMargins from the card's own edges, before any
## additional device safe-area inset is applied.
const INFO_MARGIN_BASE := 30.0

@onready var _art: TextureRect = %Art
@onready var _info_margins: MarginContainer = %InfoMargins
@onready var _eyebrow_label: Label = %EyebrowLabel
@onready var _title_label: Label = %TitleLabel
@onready var _status_row: HBoxContainer = %StatusRow
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _status_label: Label = %StatusLabel
@onready var _progress_header: HBoxContainer = %ProgressHeader
@onready var _progress_label: Label = %ProgressLabel
@onready var _progress_value_label: Label = %ProgressValueLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _cta_button: Button = %CtaButton

var _chapter_id := ""
var _panel_height := DEFAULT_PANEL_HEIGHT
var _safe_margins := Vector4.ZERO


func _ready() -> void:
	_cta_button.pressed.connect(_emit_selected)


func configure(chapter: Dictionary, progress: Dictionary, is_selected: bool) -> void:
	_chapter_id = str(chapter.get("id", ""))
	_eyebrow_label.text = "CHAPTER %d" % int(chapter.get("order", 0))
	_title_label.text = str(chapter.get("title", "Chapter"))
	var preview_path := ChapterCatalog.get_selection_preview_path(_chapter_id)
	_art.texture = load(preview_path) as Texture2D if not preview_path.is_empty() else null

	var unlocked := bool(progress.get("unlocked", false))
	_art.self_modulate = Color.WHITE if unlocked else LOCKED_ART_TINT
	_set_panel_height(LOCKED_PANEL_HEIGHT if not unlocked else DEFAULT_PANEL_HEIGHT)
	_status_row.visible = not unlocked
	_lock_icon.visible = not unlocked
	_progress_header.visible = true
	_progress_bar.visible = true
	_cta_button.disabled = not unlocked

	if not unlocked:
		var completed_required_levels := int(progress.get("previous_completed_levels", 0))
		var required_levels := int(progress.get("required_completed_levels", 0))
		var remaining_levels := maxi(required_levels - completed_required_levels, 0)
		var previous_chapter_id := ChapterCatalog.get_previous_chapter_id(_chapter_id)
		var previous_chapter := ChapterCatalog.get_chapter(previous_chapter_id)
		var previous_title := str(previous_chapter.get("title", "the previous chapter"))
		_status_label.text = "Complete %d more %s levels to unlock" % [remaining_levels, previous_title]
		_progress_label.text = "Unlock progress"
		_set_progress(completed_required_levels, required_levels)
		_cta_button.text = "LOCKED"
		return

	if not bool(progress.get("has_levels", false)):
		_status_row.visible = true
		_lock_icon.visible = false
		_status_label.text = "New levels are coming soon"
		_progress_header.visible = false
		_progress_bar.visible = false
		_cta_button.disabled = true
		_cta_button.text = "COMING SOON"
		return

	var completed_levels := int(progress.get("completed_levels", 0))
	var total_levels := int(progress.get("total_levels", 0))
	_progress_label.text = "Current progress"
	_set_progress(completed_levels, total_levels)
	if is_selected:
		_cta_button.text = "CONTINUE" if completed_levels > 0 else "PLAY"
	else:
		_cta_button.text = "PLAY"


func _set_progress(current: int, total: int) -> void:
	_progress_bar.max_value = maxf(float(total), 1.0)
	_progress_bar.value = clampf(float(current), 0.0, _progress_bar.max_value)
	_progress_value_label.text = "%d / %d" % [current, total]


## Insets %InfoMargins by the given device safe-area margin (left/top/right/bottom) on top of its
## authored padding, leaving %Art/%Atmosphere untouched so the cover art stays full-bleed under
## notches and display cutouts. Only left/right/bottom are relevant -- the info panel is bottom
## anchored and never approaches the top safe area.
func set_safe_margins(margins: Vector4) -> void:
	_safe_margins = margins
	_apply_info_margins()


func _set_panel_height(height: float) -> void:
	_panel_height = height
	_apply_info_margins()


func _apply_info_margins() -> void:
	_info_margins.offset_left = INFO_MARGIN_BASE + _safe_margins.x
	_info_margins.offset_right = -(INFO_MARGIN_BASE + _safe_margins.z)
	_info_margins.offset_bottom = -(INFO_MARGIN_BASE + _safe_margins.w)
	_info_margins.offset_top = _info_margins.offset_bottom - _panel_height


func _emit_selected() -> void:
	selected.emit(_chapter_id)
