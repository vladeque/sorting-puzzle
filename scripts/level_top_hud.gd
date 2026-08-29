extends Control
class_name LevelTopHud

## Extracted top HUD (UI-003): owns the top strip background, combo slot, timer, level label, star
## pill, and Pause button as one safe-area-aware component instead of level.tscn embedding them
## piecemeal across the Background control and the UI canvas layer. scripts/level.gd only supplies
## data (set_level_text/set_timer_state/set_star_count/set_combo/set_pause_enabled), calls
## apply_safe_layout() on resize, and listens for pause_pressed.
##
## The background strip height and the combo slot both now grow/shift with the safe-top inset --
## previously only the timer/level/star/pause row did, so a top inset could push those below the
## strip's background. The timer is also kept clear of the level label and star/pause cluster so
## long values (LEVEL 99, 59:59, large star totals) can't overlap either side.

signal pause_pressed
## Emitted from the same decision that starts the critical-second pulse, so the countdown's audio
## follows the HUD's own threshold/frozen/counting-down state instead of a second copy of it
## somewhere else (AUDIO-001 section 4). `displayed_seconds` is the second now on screen.
signal critical_second_pulsed(displayed_seconds: int)

const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")

const STRIP_BASE_HEIGHT := 132.0
const TIMER_TOP_MARGIN := 28.0
const HUD_ROW_CENTER_Y := 60.0
const HUD_SIDE_MARGIN := 24.0
const LEVEL_LABEL_MARGIN_LEFT := 32.0
const LEVEL_LABEL_TOP := 42.0
const LEVEL_LABEL_SIZE := Vector2(194.0, 40.0)
const COMPACT_HUD_SIDE_MARGIN := 16.0
const COMPACT_LEVEL_LABEL_MARGIN_LEFT := 20.0
const COMPACT_LEVEL_LABEL_SIZE := Vector2(160.0, 40.0)
const COMPACT_STAR_COUNTER_SIZE := Vector2(88.0, 46.0)
const COMPACT_STAR_COUNTER_GAP := 30.0
const COMPACT_TIMER_WIDTH := 120.0
const REGULAR_TIMER_WIDTH := 140.0
const COMPACT_TIMER_FONT_SIZE := 40
const REGULAR_TIMER_FONT_SIZE := 46
const COMPACT_LEVEL_FONT_SIZE := 24
const REGULAR_LEVEL_FONT_SIZE := 28
const TIMER_LABEL_HEIGHT := 64.0
const STAR_COUNTER_SIZE := Vector2(112.0, 52.0)
## Deliberately wider than the row's other gaps: the star pill and Pause are separate roles (a
## status readout and a control), so they read as two things rather than one cluster.
const STAR_COUNTER_GAP := 36.0
const COMBO_SLOT_SIZE := Vector2(170.0, 29.0)
const COMBO_SLOT_TOP := 112.0
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
## The timer digits carry every countdown state on one channel, so all three treatments are written
## from _refresh_timer_label_colors() instead of each caller adding and removing its own overrides.
## The normal values mirror what level_top_hud.tscn authors on %TimerLabel; the scene keeps them so
## the editor still previews the default state.
const TIMER_NORMAL_FONT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const TIMER_NORMAL_OUTLINE_SIZE := 0
## The final-30-seconds alarm. The dark maroon outline is what keeps the red digits legible against
## the warm terracotta strip, which is close enough to the font color to swallow it on its own.
const TIMER_CRITICAL_FONT_COLOR := Color(1.0, 0.23, 0.18, 1.0)
const TIMER_CRITICAL_OUTLINE_COLOR := Color(0.23, 0.02, 0.01, 0.96)
const TIMER_CRITICAL_OUTLINE_SIZE := 5
const TIMER_FROZEN_FONT_COLOR := Color(0.68, 0.96, 1.0, 1.0)
const TIMER_FROZEN_OUTLINE_COLOR := Color(0.08, 0.34, 0.52, 0.95)
const TIMER_FROZEN_OUTLINE_SIZE := 5
const TIMER_PULSE_SCALE := Vector2(1.08, 1.08)
const TIMER_PULSE_IN_SECONDS := 0.09
const TIMER_PULSE_OUT_SECONDS := 0.18

@export_range(1, 120, 1) var critical_time_seconds := 30

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
var _timer_pulse_tween: Tween
var _last_timer_seconds := -1
var _timer_is_critical := false
var _timer_is_frozen := false


func _ready() -> void:
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_refresh_timer_label_colors()


func set_level_text(text: String) -> void:
	_level_label.text = text


func set_timer_text(text: String) -> void:
	_timer_label.text = text


## Updates both timer copy and its critical visual state. `is_counting_down` keeps a short level
## from alarming before the player's first meaningful action. Repeated frame updates inside the
## same displayed second do not restart the pulse; only entering the critical range or advancing
## to a new displayed second does.
func set_timer_state(text: String, displayed_seconds: int, is_counting_down: bool) -> void:
	_timer_label.text = text
	var normalized_seconds := maxi(displayed_seconds, 0)
	var should_be_critical := (
		is_counting_down
		and normalized_seconds > 0
		and normalized_seconds <= critical_time_seconds
	)
	var entered_critical := should_be_critical and not _timer_is_critical
	var displayed_second_changed := normalized_seconds != _last_timer_seconds

	_timer_is_critical = should_be_critical
	_last_timer_seconds = normalized_seconds
	_refresh_timer_label_colors()

	if not should_be_critical:
		_stop_timer_pulse()
	elif not _timer_is_frozen and (entered_critical or displayed_second_changed):
		_play_timer_second_pulse()
		critical_second_pulsed.emit(normalized_seconds)


## Clears all transient critical-timer state at a run boundary. The next active countdown update
## can then treat 00:30 as a fresh threshold entry even if the previous run ended on that value.
func reset_timer_attention() -> void:
	_timer_is_critical = false
	_last_timer_seconds = -1
	_refresh_timer_label_colors()
	_stop_timer_pulse()


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
##
## level.gd reaches this through _update_freezer_visuals(), which several routine refreshes call
## with is_frozen false, so clearing the frozen look must not disturb anything else the label is
## showing -- restoring it through _refresh_timer_label_colors() is what lets a Freezer that expires
## mid-countdown fall back to the critical red instead of plain white.
func set_timer_frozen_visual(is_frozen: bool) -> void:
	_timer_is_frozen = is_frozen
	if is_frozen:
		_stop_timer_pulse()
	_refresh_timer_label_colors()


## Frozen wins over critical: both states now speak through the digits, and while Freezer holds the
## countdown the low-time alarm is not currently true. The critical treatment returns on the next
## update after Freezer ends if the countdown is still inside the threshold.
func _refresh_timer_label_colors() -> void:
	var font_color := TIMER_NORMAL_FONT_COLOR
	var outline_color := Color(0.0, 0.0, 0.0, 0.0)
	var outline_size := TIMER_NORMAL_OUTLINE_SIZE
	if _timer_is_frozen:
		font_color = TIMER_FROZEN_FONT_COLOR
		outline_color = TIMER_FROZEN_OUTLINE_COLOR
		outline_size = TIMER_FROZEN_OUTLINE_SIZE
	elif _timer_is_critical:
		font_color = TIMER_CRITICAL_FONT_COLOR
		outline_color = TIMER_CRITICAL_OUTLINE_COLOR
		outline_size = TIMER_CRITICAL_OUTLINE_SIZE

	_timer_label.add_theme_color_override("font_color", font_color)
	_timer_label.add_theme_color_override("font_outline_color", outline_color)
	_timer_label.add_theme_constant_override("outline_size", outline_size)


func _play_timer_second_pulse() -> void:
	_stop_timer_pulse()
	_timer_label.pivot_offset = _timer_label.size * 0.5
	_timer_pulse_tween = _timer_label.create_tween()
	_timer_pulse_tween.tween_property(
		_timer_label,
		"scale",
		TIMER_PULSE_SCALE,
		TIMER_PULSE_IN_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_timer_pulse_tween.tween_property(
		_timer_label,
		"scale",
		Vector2.ONE,
		TIMER_PULSE_OUT_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _stop_timer_pulse() -> void:
	if _timer_pulse_tween != null and _timer_pulse_tween.is_valid():
		_timer_pulse_tween.kill()
	_timer_pulse_tween = null
	_timer_label.scale = Vector2.ONE


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
	var timer_top_y := safe_margins.y + TIMER_TOP_MARGIN
	var timer_center_x := viewport_size.x * 0.5
	_layout_absolute(
		_timer_label,
		timer_center_x - timer_width * 0.5,
		timer_top_y,
		timer_center_x + timer_width * 0.5,
		timer_top_y + TIMER_LABEL_HEIGHT * compact_scale
	)
	_timer_label.pivot_offset = Vector2(timer_width, TIMER_LABEL_HEIGHT * compact_scale) * 0.5

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
