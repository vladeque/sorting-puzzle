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
const HUD_ROW_CENTER_Y := 60.0
const HUD_SIDE_MARGIN := 24.0
const LEVEL_LABEL_MARGIN_LEFT := 32.0
const LEVEL_LABEL_TOP := 42.0
const LEVEL_LABEL_SIZE := Vector2(194.0, 40.0)
const COMPACT_HUD_SIDE_MARGIN := 16.0
const COMPACT_LEVEL_LABEL_MARGIN_LEFT := 20.0
const COMPACT_LEVEL_LABEL_SIZE := Vector2(160.0, 40.0)
const COMPACT_STAR_COUNTER_SIZE := Vector2(88.0, 46.0)
const COMPACT_STAR_COUNTER_GAP := 10.0
const COMPACT_TIMER_WIDTH := 120.0
const REGULAR_TIMER_WIDTH := 140.0
const COMPACT_TIMER_FONT_SIZE := 40
const REGULAR_TIMER_FONT_SIZE := 46
const COMPACT_LEVEL_FONT_SIZE := 24
const REGULAR_LEVEL_FONT_SIZE := 28
const TIMER_LABEL_HEIGHT := 64.0
const STAR_COUNTER_SIZE := Vector2(112.0, 52.0)
const STAR_COUNTER_GAP := 12.0
const COMBO_SLOT_SIZE := Vector2(170.0, 29.0)
const COMBO_SLOT_TOP := 92.0
const COMBO_FILL_INSET := 3.0
## Matches MainMenuTopStatus/SettingsWidget at supported widths. On exceptionally narrow usable
## widths it follows the row's existing compact scale so safe-area fitting still wins.
const PAUSE_BUTTON_SIZE := Vector2(72.0, 64.0)
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
@onready var _star_icon := %StarCounter.get_node("Icon") as TextureRect
@onready var _star_count_label := %StarCountLabel as Label
@onready var _pause_button := %PauseButton as Button

var _star_pulse_tween: Tween


func _ready() -> void:
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())


func set_level_text(text: String) -> void:
	_level_label.text = text


func set_timer_text(text: String) -> void:
	_timer_label.text = text


func set_star_count(stars: int) -> void:
	_star_count_label.text = "%d" % stars
	_fit_star_count_font()


## The reward-star flight's landing point (scripts/level.gd flies earned stars from a clear
## location to here).
func get_star_counter_global_center() -> Vector2:
	return _star_counter.get_global_rect().get_center()


## Briefly pulses the star icon when a reward star arrives, matching
## scripts/main_menu_reward_chest.gd's play_receive_pulse() convention. Kills any prior pulse first
## so rapid repeated arrivals never accumulate competing tweens.
##
## The pulse scales the icon rather than the whole pill on purpose. Scaling the pill runs its
## StyleBoxFlat and its glyphs through the scaled transform: the 2px gold border and the 6px drop
## shadow visibly thicken and the rasterized count blurs, so the counter stops matching the Pause
## button beside it for the length of the pulse. That was most obvious during the completion
## celebration, where the level-clearing combo's stars land while the frozen board is on screen.
## The icon is a texture drawn straight from its source, so it stays crisp at any scale.
func play_star_receive_pulse() -> void:
	if _star_pulse_tween != null and _star_pulse_tween.is_valid():
		_star_pulse_tween.kill()

	_star_icon.pivot_offset = _star_icon.size * 0.5
	_star_icon.scale = Vector2.ONE
	_star_pulse_tween = _star_icon.create_tween()
	_star_pulse_tween.tween_property(_star_icon, "scale", STAR_PULSE_SCALE, STAR_PULSE_IN_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_star_pulse_tween.tween_property(_star_icon, "scale", Vector2.ONE, STAR_PULSE_OUT_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Kills any in-flight pulse and resets the star icon's scale -- used when a level (re)starts so a
## pulse from the previous run is never retained.
func reset_star_pulse() -> void:
	if _star_pulse_tween != null and _star_pulse_tween.is_valid():
		_star_pulse_tween.kill()
	_star_pulse_tween = null
	_star_icon.scale = Vector2.ONE
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
	_pause_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if is_enabled else Control.CURSOR_ARROW
	)


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
	var is_compact := usable_width <= GameplayUIThemeScript.HUD_ICON_COMPACT_VIEWPORT_WIDTH
	# Below the 540px compact reference width, scale every top-row role together. This preserves the
	# same non-overlapping regions when side cutouts reduce usable width instead of merely assigning
	# a tiny timer rect that its font minimum immediately overrides.
	var icon_size := GameplayUIThemeScript.get_hud_icon_size(usable_width)
	var compact_scale := (
		icon_size.x / GameplayUIThemeScript.HUD_ICON_COMPACT_SIZE.x if is_compact else 1.0
	)
	var side_margin := COMPACT_HUD_SIDE_MARGIN * compact_scale if is_compact else HUD_SIDE_MARGIN
	var star_gap := COMPACT_STAR_COUNTER_GAP * compact_scale if is_compact else STAR_COUNTER_GAP
	var star_size := COMPACT_STAR_COUNTER_SIZE * compact_scale if is_compact else STAR_COUNTER_SIZE
	var level_margin_left := (
		COMPACT_LEVEL_LABEL_MARGIN_LEFT * compact_scale if is_compact else LEVEL_LABEL_MARGIN_LEFT
	)
	var level_size := COMPACT_LEVEL_LABEL_SIZE * compact_scale if is_compact else LEVEL_LABEL_SIZE
	var timer_width := COMPACT_TIMER_WIDTH * compact_scale if is_compact else REGULAR_TIMER_WIDTH
	_timer_label.add_theme_font_size_override(
		"font_size",
		maxi(roundi(COMPACT_TIMER_FONT_SIZE * compact_scale), 10) if is_compact else REGULAR_TIMER_FONT_SIZE
	)
	_level_label.add_theme_font_size_override(
		"font_size",
		maxi(roundi(COMPACT_LEVEL_FONT_SIZE * compact_scale), 10) if is_compact else REGULAR_LEVEL_FONT_SIZE
	)

	var pause_size := PAUSE_BUTTON_SIZE * (compact_scale if is_compact else 1.0)
	var pause_right_x := viewport_size.x - (safe_margins.z + side_margin)
	var pause_left_x := pause_right_x - pause_size.x
	# Keep every status control on the authored y=60 row center even though Pause intentionally uses
	# the smaller warm Main Menu settings-button role instead of the larger circular ability role.
	var row_center_y := safe_margins.y + HUD_ROW_CENTER_Y
	var pause_top_y := row_center_y - pause_size.y * 0.5
	_layout_absolute(_pause_button, pause_left_x, pause_top_y, pause_right_x, pause_top_y + pause_size.y)

	var star_right_x := pause_left_x - star_gap
	var star_left_x := star_right_x - star_size.x
	var star_top_y := row_center_y - star_size.y * 0.5
	_layout_absolute(_star_counter, star_left_x, star_top_y, star_right_x, star_top_y + star_size.y)
	_layout_star_counter_children(star_size, compact_scale if is_compact else 1.0)

	var level_left_x := safe_margins.x + level_margin_left
	var level_top_y := safe_margins.y + LEVEL_LABEL_TOP
	_layout_absolute(_level_label, level_left_x, level_top_y, level_left_x + level_size.x, level_top_y + level_size.y)

	# The compact side roles above reserve a real, font-sized center region. Giving the timer a known
	# width prevents Label minimum-size resolution from expanding a nominal 1-2px allocation into
	# the star pill after the layout pass.
	var timer_top_y := safe_margins.y + HUD_TOP_MARGIN
	var timer_center_x := viewport_size.x * 0.5
	_layout_absolute(
		_timer_label,
		timer_center_x - timer_width * 0.5,
		timer_top_y,
		timer_center_x + timer_width * 0.5,
		timer_top_y + TIMER_LABEL_HEIGHT * compact_scale
	)

	_hud_center_slot.anchor_left = 0.5
	_hud_center_slot.anchor_right = 0.5
	_hud_center_slot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud_center_slot.offset_left = -COMBO_SLOT_SIZE.x * 0.5
	_hud_center_slot.offset_right = COMBO_SLOT_SIZE.x * 0.5
	_hud_center_slot.offset_top = safe_margins.y + COMBO_SLOT_TOP
	_hud_center_slot.offset_bottom = safe_margins.y + COMBO_SLOT_TOP + COMBO_SLOT_SIZE.y


func _layout_star_counter_children(star_size: Vector2, layout_scale: float) -> void:
	var icon_margin := 8.0 * layout_scale
	var icon_size := minf(34.0 * layout_scale, star_size.y - icon_margin * 2.0)
	var label_left := icon_margin + icon_size + 2.0 * layout_scale
	var label_right_margin := 12.0 * layout_scale
	_layout_absolute(
		_star_icon,
		icon_margin,
		(star_size.y - icon_size) * 0.5,
		icon_margin + icon_size,
		(star_size.y + icon_size) * 0.5
	)
	_layout_absolute(_star_count_label, label_left, 0.0, star_size.x - label_right_margin, star_size.y)
	_fit_star_count_font()


func _fit_star_count_font() -> void:
	if _star_count_label == null:
		return
	var available_width := _star_count_label.offset_right - _star_count_label.offset_left - 4.0
	var maximum_size := 26
	_star_count_label.add_theme_font_size_override(
		"font_size",
		GameplayUIThemeScript.fit_label_font_size(
			_star_count_label,
			available_width,
			maximum_size,
			10
		)
	)

func _layout_absolute(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom
