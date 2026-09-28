extends Control

## Disposable design study around the production Pause scene. No gameplay scene imports this file.
## Set concept to 0, 1, or 2 (or press 1/2/3 while running) to compare the three header silhouettes.

@export_range(0, 2, 1) var concept := 0

const CONCEPT_NAMES := ["01  •  FOLDED RIBBON", "02  •  PRODUCT TAG", "03  •  SHELF MARQUEE"]
const HEADER_ART_SCRIPT := preload("res://scripts/testing/modal_header_study_art.gd")
const TABLET_BASE_SIZE := Vector2i(900, 1200)
const TABLET_ASPECT_THRESHOLD := 0.65

@onready var _pause_menu := $PauseMenu as PauseMenu
@onready var _caption := %StudyCaption as Label
@onready var _shell := $PauseMenu/Shell as GameplayModalShell
@onready var _panel := $PauseMenu/Shell/OuterPanel as Panel
@onready var _title := $PauseMenu/Shell/OuterPanel/TitleLabel as Label
@onready var _close := $PauseMenu/Shell/OuterPanel/CloseButton as Button

var _header_art: Control
var _tablet_preview_enabled := false


func _ready() -> void:
	# The actual Pause scene supplies the panel, content, actions, typography, and safe-area fit.
	_header_art = HEADER_ART_SCRIPT.new() as Control
	_header_art.name = "HeaderArtPrototype"
	_header_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_art.position = Vector2(-30, -54)
	_header_art.size = Vector2(580, 178)
	_panel.add_child(_header_art)
	_panel.move_child(_header_art, 0)
	resized.connect(_fit_and_label)
	_set_concept(concept)
	_fit_and_label()


func _process(_delta: float) -> void:
	# For this study only, give squarer portrait windows a matching logical aspect. The project's
	# keep-width stretch otherwise renders a 1200x1600 request as a 900x1600 letterboxed image.
	var window := get_window()
	var tablet_needed := float(window.size.x) / maxf(float(window.size.y), 1.0) > TABLET_ASPECT_THRESHOLD
	if tablet_needed == _tablet_preview_enabled:
		return
	_tablet_preview_enabled = tablet_needed
	window.content_scale_size = TABLET_BASE_SIZE if tablet_needed else Vector2i(720, 1280)
	window.content_scale_aspect = (
		Window.CONTENT_SCALE_ASPECT_IGNORE if tablet_needed
		else Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	)
	call_deferred("_fit_and_label")


func set_concept(value: int) -> void:
	concept = clampi(value, 0, 2)
	if is_node_ready():
		_set_concept(concept)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				set_concept(0)
			KEY_2:
				set_concept(1)
			KEY_3:
				set_concept(2)


func _set_concept(value: int) -> void:
	_header_art.set("concept", value)
	_header_art.queue_redraw()
	_caption.text = CONCEPT_NAMES[value]
	_title.add_theme_color_override(
		"font_color",
		Color("5c250c") if value == 1 else Color("fff5da")
	)
	_title.add_theme_color_override(
		"font_shadow_color",
		Color(1.0, 0.81, 0.43, 0.7) if value == 1 else Color(0.08, 0.14, 0.21, 0.9)
	)
	# Keep the real 72px close target; move it just above the protruding header surface.
	_close.offset_top = -41.0 if value == 1 else -35.0
	_close.offset_bottom = _close.offset_top + 72.0
	_title.offset_top = -2.0 if value == 1 else 4.0
	_title.offset_bottom = _title.offset_top + 62.0


func _fit_and_label() -> void:
	if _pause_menu == null:
		return
	_pause_menu.apply_safe_layout(Vector4.ZERO, size)
	# Place the study caption above the modal even on shorter portrait devices.
	var modal_top := (size.y - 500.0 * _panel.scale.y) * 0.5
	%StudyCaption.offset_top = maxf(16.0, modal_top - 120.0)
	%StudyCaption.offset_bottom = %StudyCaption.offset_top + 40.0
	%StudyHint.offset_top = %StudyCaption.offset_bottom + 2.0
	%StudyHint.offset_bottom = %StudyHint.offset_top + 30.0
