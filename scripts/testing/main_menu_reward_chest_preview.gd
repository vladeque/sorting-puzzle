extends Control

## Standalone F6 preview of the production Main Menu filling its reward chest and playing the
## opening sequence that follows. It hands the real menu a pending-reward payload built from the
## saved chest position -- the same path a completed level takes -- so the star flight, chest
## opening, coin counter, LEVEL button pulses, sounds, and haptics are all production code.
##
## Presentation only: it never writes PlayerProgress. The coin counter counts back up to the
## unchanged saved balance, and once the opening finishes the chest widget refills to this preview's
## simulated carry-over instead of the saved progress the menu would show.

@export_range(1, 60, 1) var stars_per_run := 12
## Stars that land after the chest fills and carry over into the next goal.
@export_range(0, 30, 1) var overflow_stars := 4
@export var autoplay := true
@export var autoplay_delay := 0.8

@onready var _menu := %MainMenu as Control
@onready var _status_label := %StatusLabel as Label
@onready var _replay_button := %ReplayButton as Button

var _is_playing := false
var _carry_over := 0
var _next_goal := 1


func _ready() -> void:
	_replay_button.pressed.connect(play_preview)
	# The menu connected its own handlers in its _ready(), which ran first, so this preview's
	# `finished` handler runs after the menu's refill and replaces it with the simulated carry-over.
	var ceremony := _menu.get_node("%RewardChestOpenCeremony")
	ceremony.connect("opened", _on_ceremony_opened)
	ceremony.connect("finished", _on_ceremony_finished)
	_menu.get_node("%RewardStarFlyer").connect("animation_finished", _on_star_flight_finished)
	_status_label.text = "Ready: %d stars will fill the chest." % stars_per_run
	if autoplay:
		_autoplay_after_layout()


func is_playing() -> bool:
	return _is_playing


## Fills the saved chest's active goal from just below it, landing `overflow_stars` past the goal.
func play_preview() -> void:
	if _is_playing:
		return

	var progress := PlayerProgress.get_reward_chest_progress()
	var goal := maxi(int(progress.get("goal", 1)), 1)
	var goal_index := int(progress.get("goal_index", 0))
	var next_index := mini(goal_index + 1, PlayerProgress.get_reward_chest_last_goal_index())
	_next_goal = PlayerProgress.get_reward_chest_goal_at_index(next_index)
	_carry_over = clampi(overflow_stars, 0, _next_goal - 1)
	var filling_stars := clampi(stars_per_run - _carry_over, 1, goal)
	var pending := {
		"amount": filling_stars + _carry_over,
		"start_stars": goal - filling_stars,
		"start_goal_index": goal_index,
	}

	_is_playing = true
	_replay_button.disabled = true
	_status_label.text = "Stars are flying into the chest..."
	_menu.call("_prepare_pending_reward_animation", pending)
	_menu.call("_play_pending_reward_animation", pending)


func _autoplay_after_layout() -> void:
	await get_tree().create_timer(autoplay_delay).timeout
	if autoplay and is_inside_tree():
		play_preview()


func _on_star_flight_finished() -> void:
	if _is_playing:
		_status_label.text = "Tap the chest to open it, or wait for it to open itself."


func _on_ceremony_opened() -> void:
	_status_label.text = "Opened: coins fly to the counter, abilities to LEVEL."


func _on_ceremony_finished() -> void:
	_menu.get_node("%RewardChest").call("play_refill", _carry_over, _next_goal)
	_is_playing = false
	_replay_button.disabled = false
	_replay_button.text = "Replay"
	_status_label.text = "Done. Saved progress is unchanged."
