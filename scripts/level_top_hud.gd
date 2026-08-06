extends Control
class_name LevelTopHud

## Extracted top HUD (UI-003): owns the top strip background, combo slot, timer, level label, star
## pill, and Pause button as one safe-area-aware component instead of level.tscn embedding them
## piecemeal across the Background control and the UI canvas layer. scripts/level.gd only supplies
## data (set_level_text/set_timer_text/set_star_count/set_combo/set_pause_enabled), calls
## apply_safe_layout() on resize, and listens for pause_pressed.
##
## The background strip height and the combo slot both now grow/shift with the safe-top inset --
## previously only the timer/level/star/pause row did, so a top inset could push those below the
## strip's background. The timer is also kept clear of the level label and star/pause cluster so
## long values (LEVEL 99, 59:59, large star totals) can't overlap either side.

signal pause_pressed

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")

const STRIP_BASE_HEIGHT := 112.0
const HUD_TOP_MARGIN := 28.0
const HUD_SIDE_MARGIN := 24.0
const LEVEL_LABEL_MARGIN_LEFT := 32.0
const LEVEL_LABEL_TOP := 42.0
const LEVEL_LABEL_SIZE := Vector2(194.0, 40.0)
const TIMER_LABEL_HEIGHT := 64.0
const STAR_COUNTER_SIZE := Vector2(112.0, 52.0)
const STAR_COUNTER_GAP := 40.0
const COMBO_SLOT_SIZE := Vector2(170.0, 29.0)
const COMBO_SLOT_TOP := 92.0
const COMBO_FILL_INSET := 3.0
const PAUSE_BAR_WIDTH_RATIO := 0.12
const PAUSE_BAR_HEIGHT_RATIO := 0.42
const PAUSE_BAR_GAP_RATIO := 0.10
const STAR_PULSE_SCALE := Vector2(1.12, 1.12)
const STAR_PULSE_IN_SECONDS := 0.08
const STAR_PULSE_OUT_SECONDS := 0.12
const TIMER_FROZEN_FONT_COLOR := Color(0.68, 0.96, 1.0, 1.0)
const TIMER_FROZEN_OUTLINE_COLOR := Color(0.08, 0.34, 0.52, 0.95)
const TIMER_FROZEN_OUTLINE_SIZE := 5

@onready var _strip := %Strip as Control
@onready var _hud_center_slot := %HudCenterSlot as Control
@onready var _combo_fill := %ComboFill as Control
@onready var _combo_label := %ComboLabel as Label
@onready var _timer_label := %TimerLabel as Label
@onready var _level_label := %LevelLabel as Label
@onready var _star_counter := %StarCounter as Control
@onready var _star_count_label := %StarCountLabel as Label
@onready var _pause_button := %PauseButton as Button
@onready var _pause_bar_1 := %PauseBar1 as Control
@onready var _pause_bar_2 := %PauseBar2 as Control

var _star_pulse_tween: Tween


func _ready() -> void:
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())


func set_level_text(text: String) -> void:
	_level_label.text = text


func set_timer_text(text: String) -> void:
	_timer_label.text = text


func set_star_count(stars: int) -> void:
	var star_text := "%d" % stars
	var font_size := 26
	if star_text.length() >= 7:
		font_size = 18
	elif star_text.length() >= 6:
		font_size = 20
	elif star_text.length() >= 5:
		font_size = 22

	_star_count_label.add_theme_font_size_override("font_size", font_size)
	_star_count_label.text = star_text


## The reward-star flight's landing point (scripts/level.gd flies earned stars from a clear
## location to here).
func get_star_counter_global_center() -> Vector2:
	return _star_counter.get_global_rect().get_center()


## Briefly pulses the star pill when a reward star arrives, matching
## scripts/main_menu_reward_chest.gd's play_receive_pulse() convention. Kills any prior pulse first
## so rapid repeated arrivals never accumulate competing tweens.
func play_star_receive_pulse() -> void:
	if _star_pulse_tween != null and _star_pulse_tween.is_valid():
		_star_pulse_tween.kill()

	_star_counter.pivot_offset = _star_counter.size * 0.5
	_star_counter.scale = Vector2.ONE
	_star_pulse_tween = _star_counter.create_tween()
	_star_pulse_tween.tween_property(_star_counter, "scale", STAR_PULSE_SCALE, STAR_PULSE_IN_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_star_pulse_tween.tween_property(_star_counter, "scale", Vector2.ONE, STAR_PULSE_OUT_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Kills any in-flight pulse and resets the star pill's scale -- used when a level (re)starts so a
## pulse from the previous run is never retained.
func reset_star_pulse() -> void:
	if _star_pulse_tween != null and _star_pulse_tween.is_valid():
		_star_pulse_tween.kill()
	_star_pulse_tween = null
	_star_counter.scale = Vector2.ONE


## Recolors the countdown timer to the frozen cyan treatment while Freezer is active.
func set_timer_frozen_visual(is_frozen: bool) -> void:
	if is_frozen:
		_timer_label.add_theme_color_override("font_color", TIMER_FROZEN_FONT_COLOR)
		_timer_label.add_theme_color_override("font_outline_color", TIMER_FROZEN_OUTLINE_COLOR)
		_timer_label.add_theme_constant_override("outline_size", TIMER_FROZEN_OUTLINE_SIZE)
	else:
		_timer_label.remove_theme_color_override("font_color")
		_timer_label.remove_theme_color_override("font_outline_color")
		_timer_label.remove_theme_constant_override("outline_size")


func set_combo(is_combo_active: bool, combo_count: int, time_ratio: float) -> void:
	_combo_fill.visible = is_combo_active
	_combo_label.visible = is_combo_active
	_combo_fill.anchor_right = time_ratio if is_combo_active else 0.0
	_combo_fill.offset_left = COMBO_FILL_INSET
	_combo_fill.offset_top = COMBO_FILL_INSET
	_combo_fill.offset_right = -COMBO_FILL_INSET
	_combo_fill.offset_bottom = -COMBO_FILL_INSET
	if is_combo_active:
		_combo_label.text = "COMBO ×%d" % combo_count


func set_pause_enabled(is_enabled: bool) -> void:
	_pause_button.disabled = not is_enabled


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = safe_margins.y + STRIP_BASE_HEIGHT

	var usable_width := maxf(viewport_size.x - safe_margins.x - safe_margins.z, 1.0)
	var icon_size := GameplayUIThemeScript.get_hud_icon_size(usable_width)

	var pause_right_x := viewport_size.x - (safe_margins.z + HUD_SIDE_MARGIN)
	var pause_left_x := pause_right_x - icon_size.x
	var pause_top_y := safe_margins.y + HUD_TOP_MARGIN
	_layout_absolute(_pause_button, pause_left_x, pause_top_y, pause_right_x, pause_top_y + icon_size.y)
	_layout_pause_bars(icon_size)

	var star_right_x := pause_left_x - STAR_COUNTER_GAP
	var star_left_x := star_right_x - STAR_COUNTER_SIZE.x
	var star_top_y := pause_top_y + (icon_size.y - STAR_COUNTER_SIZE.y) * 0.5
	_layout_absolute(_star_counter, star_left_x, star_top_y, star_right_x, star_top_y + STAR_COUNTER_SIZE.y)

	var level_left_x := safe_margins.x + LEVEL_LABEL_MARGIN_LEFT
	var level_top_y := safe_margins.y + LEVEL_LABEL_TOP
	_layout_absolute(_level_label, level_left_x, level_top_y, level_left_x + LEVEL_LABEL_SIZE.x, level_top_y + LEVEL_LABEL_SIZE.y)

	# Keep the timer centered on the viewport, but only as wide as the tighter of the two side
	# exclusion zones allows, so it can never overlap the level label or the star/pause cluster.
	var timer_top_y := safe_margins.y + HUD_TOP_MARGIN
	var timer_center_x := viewport_size.x * 0.5
	var half_width := maxf(minf(timer_center_x - (level_left_x + LEVEL_LABEL_SIZE.x + HUD_SIDE_MARGIN), (star_left_x - HUD_SIDE_MARGIN) - timer_center_x), 1.0)
	_layout_absolute(_timer_label, timer_center_x - half_width, timer_top_y, timer_center_x + half_width, timer_top_y + TIMER_LABEL_HEIGHT)

	_hud_center_slot.anchor_left = 0.5
	_hud_center_slot.anchor_right = 0.5
	_hud_center_slot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud_center_slot.offset_left = -COMBO_SLOT_SIZE.x * 0.5
	_hud_center_slot.offset_right = COMBO_SLOT_SIZE.x * 0.5
	_hud_center_slot.offset_top = safe_margins.y + COMBO_SLOT_TOP
	_hud_center_slot.offset_bottom = safe_margins.y + COMBO_SLOT_TOP + COMBO_SLOT_SIZE.y


func _layout_pause_bars(icon_size: Vector2) -> void:
	var bar_width := icon_size.x * PAUSE_BAR_WIDTH_RATIO
	var bar_height := icon_size.y * PAUSE_BAR_HEIGHT_RATIO
	var gap := icon_size.x * PAUSE_BAR_GAP_RATIO
	var total_width := bar_width * 2.0 + gap
	var left_x := (icon_size.x - total_width) * 0.5
	var top_y := (icon_size.y - bar_height) * 0.5

	_layout_absolute(_pause_bar_1, left_x, top_y, left_x + bar_width, top_y + bar_height)
	_layout_absolute(_pause_bar_2, left_x + bar_width + gap, top_y, left_x + total_width, top_y + bar_height)


func _layout_absolute(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom
