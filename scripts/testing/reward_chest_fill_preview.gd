extends Control

## Standalone developer preview for the real reward-chest widget, reward-star flyer, receive pulse,
## and per-impact sound. It changes presentation state only and never touches PlayerProgress.

const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")

@export_range(1, 30, 1) var stars_per_run := 12
@export_range(1, 100, 1) var goal_stars := 12
@export var autoplay := true

@onready var _source_star := %SourceStar as Control
@onready var _reward_chest := %RewardChest as Control
@onready var _star_flyer := %StarFlyer as Control
@onready var _status_label := %StatusLabel as Label
@onready var _play_button := %PlayButton as Button
@onready var _reset_button := %ResetButton as Button

var _current_stars := 0
var _is_playing := false
var _autoplay_pending := false


func _ready() -> void:
	_play_button.pressed.connect(_play_fill)
	_reset_button.pressed.connect(_reset_preview)
	_star_flyer.connect("star_arrived", Callable(self, "_on_star_arrived"))
	_star_flyer.connect("animation_finished", Callable(self, "_on_animation_finished"))
	_reset_preview()

	_autoplay_pending = autoplay
	if _autoplay_pending:
		_start_autoplay_after_layout()


func _start_autoplay_after_layout() -> void:
	await get_tree().create_timer(0.65).timeout
	if _autoplay_pending and not _is_playing:
		_play_fill()


func _play_fill() -> void:
	if _is_playing:
		return
	if _current_stars >= goal_stars:
		_reset_preview()

	_autoplay_pending = false
	_is_playing = true
	_play_button.disabled = true
	_reset_button.disabled = true
	_status_label.text = "Stars are flying into the chest..."

	var remaining := maxi(goal_stars - _current_stars, 0)
	var launch_count := mini(stars_per_run, remaining)
	_star_flyer.call(
		"play",
		launch_count,
		_source_star.get_global_rect().get_center(),
		_reward_chest.call("get_reward_target_global_position") as Vector2
	)


func _on_star_arrived() -> void:
	_current_stars = mini(_current_stars + 1, goal_stars)
	_apply_progress()
	_reward_chest.call("play_receive_pulse")
	var sfx_manager := get_node_or_null(^"/root/SfxManager")
	if sfx_manager != null:
		sfx_manager.call("play", SfxCatalogScript.EVENT_REWARD_CHEST_STAR_ARRIVAL)


func _on_animation_finished() -> void:
	_is_playing = false
	_play_button.disabled = false
	_reset_button.disabled = false
	_play_button.text = "Replay" if _current_stars >= goal_stars else "Add stars"
	_status_label.text = (
		"Chest filled — replay to hear it again."
		if _current_stars >= goal_stars
		else "Ready for another star flight."
	)


func _reset_preview() -> void:
	if _is_playing:
		return
	_current_stars = 0
	_play_button.text = "Fill chest"
	_status_label.text = "Ready — %d stars will arrive one by one." % mini(stars_per_run, goal_stars)
	_apply_progress()


func _apply_progress() -> void:
	_reward_chest.call("set_reward_progress", _current_stars, goal_stars)


## Capture tooling uses a stable partially-filled state instead of racing the autoplay animation.
func prepare_capture() -> void:
	_autoplay_pending = false
	_current_stars = clampi(7, 0, goal_stars)
	_apply_progress()
	_play_button.text = "Add stars"
	_status_label.text = "Each impact advances the counter and plays the arrival event."
