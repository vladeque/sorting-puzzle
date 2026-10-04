extends Control

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const ILLUSTRATION_CORNER_RADIUS := 16.0
const PANEL_TOP_OVERHANG := 80.0
const PANEL_RIGHT_OVERHANG := 44.0
const HORIZONTAL_MARGIN := 16.0
const VERTICAL_MARGIN := 24.0

@export var hero_title_font_size := 28
@export var minimum_hero_title_font_size := 16

@onready var _panel := $RewardChestPanel as Panel
@onready var _close_button := %CloseButton as Button
@onready var _continue_button := %ContinueButton as Button
@onready var _illustration := %Illustration as TextureRect
@onready var _progress_bar := %ProgressBar as ProgressBar
@onready var _amount_label := %AmountLabel as Label
@onready var _hero_title_label := %HeroTitleLabel as Label


func _ready() -> void:
	_close_button.pressed.connect(close)
	_continue_button.pressed.connect(close)
	resized.connect(_fit_panel_to_viewport)
	_fit_panel_to_viewport()
	_illustration.resized.connect(_sync_illustration_corner_mask)
	_sync_illustration_corner_mask()
	_apply_reward_progress(PlayerProgress.get_reward_chest_progress())
	_hero_title_label.resized.connect(_fit_hero_title)
	_fit_hero_title.call_deferred()


func _fit_hero_title() -> void:
	_hero_title_label.add_theme_font_size_override("font_size", GameplayUIThemeScript.fit_label_font_size(
		_hero_title_label, _hero_title_label.size.x, hero_title_font_size, minimum_hero_title_font_size
	))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fit_hero_title.call_deferred()


func _fit_panel_to_viewport() -> void:
	_panel.pivot_offset = _panel.size * 0.5
	var panel_center_y := (_panel.offset_top + _panel.offset_bottom) * 0.5
	var top_extent := _panel.size.y * 0.5 + PANEL_TOP_OVERHANG
	var bottom_extent := _panel.size.y * 0.5
	var top_room := size.y * 0.5 + panel_center_y - VERTICAL_MARGIN
	var bottom_room := size.y * 0.5 - panel_center_y - VERTICAL_MARGIN
	var right_extent := _panel.size.x * 0.5 + PANEL_RIGHT_OVERHANG
	var horizontal_room := size.x * 0.5 - HORIZONTAL_MARGIN
	var fit_scale := minf(
		1.0,
		minf(
			minf(top_room / top_extent, bottom_room / bottom_extent),
			horizontal_room / right_extent
		)
	)
	_panel.scale = Vector2.ONE * maxf(fit_scale, 0.01)


## Fades out and frees this modal. Safe to call more than once (Close pressed, Continue pressed,
## and the owning menu's `ui_cancel` handling can all reach here) -- a repeat call while already
## closing is ignored.
func close() -> void:
	UIMotionScript.close_with_fade(self, queue_free)


func _apply_reward_progress(progress: Dictionary) -> void:
	var goal := maxi(int(progress.get("goal", 1)), 1)
	var stars := clampi(int(progress.get("stars", 0)), 0, goal)

	_progress_bar.max_value = goal
	_progress_bar.value = stars
	_amount_label.text = "%d/%d" % [stars, goal]


func _sync_illustration_corner_mask() -> void:
	var shader_material := _illustration.material as ShaderMaterial
	if shader_material == null:
		push_warning("Reward chest illustration is missing its rounded-corner material.")
		return
	shader_material.set_shader_parameter("rect_size", _illustration.size)
	shader_material.set_shader_parameter("corner_radius", ILLUSTRATION_CORNER_RADIUS)
