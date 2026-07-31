extends ColorRect
class_name LevelCompletionScreen

signal next_pressed

const TITLE_SIZE := Vector2(720, 96)
const TITLE_TOP := 108.0
const STAR_SIZE := Vector2(340, 340)
const STAR_CENTER_Y := 466.0
const STARS_LABEL_SIZE := Vector2(320, 84)
const STARS_LABEL_OFFSET_Y := 150.0
const BUTTON_SIZE := Vector2(340, 124)
const BUTTON_CENTER_Y := 850.0
const MIN_BUTTON_BOTTOM_MARGIN := 118.0

@onready var _title_label := $TitleLabel as Label
@onready var _star_image := $StarImage as TextureRect
@onready var _earned_stars_label := $EarnedStarsLabel as Label
@onready var _next_button := $NextButton as Button


func _ready() -> void:
	_next_button.pressed.connect(_on_next_button_pressed)


func apply_responsive_layout(safe_margins: Vector4) -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var viewport_size := get_viewport_rect().size
	var layout_scale := clampf(minf(viewport_size.x / 720.0, viewport_size.y / 1280.0), 0.75, 1.35)
	var center_x := viewport_size.x * 0.5
	var title_top := safe_margins.y + TITLE_TOP * layout_scale
	var star_center_y := safe_margins.y + STAR_CENTER_Y * layout_scale
	var button_center_y := minf(
		safe_margins.y + BUTTON_CENTER_Y * layout_scale,
		viewport_size.y - safe_margins.w - MIN_BUTTON_BOTTOM_MARGIN * layout_scale - BUTTON_SIZE.y * layout_scale * 0.5
	)

	_layout_centered_control(
		_title_label,
		Vector2(center_x, title_top + TITLE_SIZE.y * layout_scale * 0.5),
		Vector2(viewport_size.x - safe_margins.x - safe_margins.z, TITLE_SIZE.y * layout_scale)
	)
	_layout_centered_control(_star_image, Vector2(center_x, star_center_y), STAR_SIZE * layout_scale)
	_layout_centered_control(
		_earned_stars_label,
		Vector2(center_x, star_center_y + STARS_LABEL_OFFSET_Y * layout_scale),
		STARS_LABEL_SIZE * layout_scale
	)
	_layout_centered_control(_next_button, Vector2(center_x, button_center_y), BUTTON_SIZE * layout_scale)


func set_earned_stars(stars: int) -> void:
	var earned_text := "×%d" % stars
	var font_size := 58
	if earned_text.length() >= 8:
		font_size = 42
	elif earned_text.length() >= 7:
		font_size = 48
	elif earned_text.length() >= 6:
		font_size = 52

	_earned_stars_label.add_theme_font_size_override("font_size", font_size)
	_earned_stars_label.text = earned_text


func _layout_centered_control(control: Control, center: Vector2, size: Vector2) -> void:
	if control == null:
		return

	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = center.x - size.x * 0.5
	control.offset_top = center.y - size.y * 0.5
	control.offset_right = center.x + size.x * 0.5
	control.offset_bottom = center.y + size.y * 0.5


func _on_next_button_pressed() -> void:
	next_pressed.emit()
