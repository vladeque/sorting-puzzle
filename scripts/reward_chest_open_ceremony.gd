extends Control

## Full-screen reward-chest opening the Main Menu plays after its star flight fills a chest goal.
##
## Beats: the chest lifts from its side widget to the centre of a dimmed screen and wobbles until
## the player taps (or `auto_open_delay` passes), bursts open with a flash, rays, and confetti, then
## reveals the granted coins and abilities. Coins fly to the top coin counter and abilities to the
## LEVEL button, and the chest shrinks back into its widget.
##
## Presentation only: PlayerProgress granted and saved these rewards when the level completed. The
## owner (scripts/production_main_menu.gd) advances its displayed coin count from `coin_arrived`,
## pulses the LEVEL button from `ability_arrived`, and settles every widget to saved values on
## `finished`. The reveal row and the flights are scenes/ui/reward_reveal_row.tscn, shared with the
## purchase reward sequence. Chest beat durations are exported here and flight durations on
## `%RewardPanel`, so tests can compress the whole sequence.

signal opened
signal coin_arrived(arrived_count: int, total_count: int)
signal ability_arrived(ability_id: StringName)
signal finished

enum Phase { IDLE, LIFTING, AWAITING_TAP, OPENING, REVEALING, COLLECTING, RETURNING }

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")
const HapticsCatalogScript := preload("res://scripts/haptics/haptics_catalog.gd")
## Where the open chest's mouth sits, as a fraction of the stage. Rewards pop out from here.
const MOUTH_FRACTION := Vector2(0.49, 0.4)
## The chest wobbles and squashes from its base rather than its centre.
const BASE_PIVOT_FRACTION := Vector2(0.5, 0.9)
## Must match the Stage/RewardPanel/TapHint vertical anchor in the scene; short screens shrink the
## reward group around this line.
const CONTENT_ANCHOR_Y := 0.55
## The reward row, chest, and prompt span about 640px. Screens shorter than this height scale that
## group down (to no less than MIN_CONTENT_SCALE) so it clears the top status bar.
const CONTENT_REFERENCE_HEIGHT := 1200.0
const MIN_CONTENT_SCALE := 0.78
const SHAKE_META := &"_chest_shake_tween"
const HINT_META := &"_chest_hint_tween"

@export_group("Timing")
@export var lift_duration := 0.5
@export var auto_open_delay := 1.6
@export var shake_pause := 0.26
@export var reveal_hold := 1.0
@export var return_duration := 0.42

@onready var _dim := %Dim as ColorRect
@onready var _flash := %Flash as ColorRect
@onready var _content := %Content as Control
@onready var _stage := %Stage as Control
@onready var _rays := %Rays as Control
@onready var _closed_chest := %ClosedChest as TextureRect
@onready var _open_chest := %OpenChest as TextureRect
@onready var _chest_burst := %ChestBurst as CPUParticles2D
@onready var _chest_sparkles := %ChestSparkles as CPUParticles2D
@onready var _tap_hint := %TapHint as Label
@onready var _reward_panel := %RewardPanel as RewardRevealRow
@onready var _flyer_layer := %FlyerLayer as Control

var _phase := Phase.IDLE
var _play_generation := 0
var _source_position := Vector2.ZERO
var _source_scale := Vector2.ONE
var _rest_position := Vector2.ZERO
var _coin_target_global := Vector2.ZERO
var _ability_target_global := Vector2.ZERO
var _shake_count := 0
var _reveal_settled := false
## The stage's authored anchor offsets. The lift and return tween its position away from them, so
## every run restores them first and measures the resting centre from the current layout.
var _stage_rest_offsets := Vector4.ZERO


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage_rest_offsets = Vector4(
		_stage.offset_left, _stage.offset_top, _stage.offset_right, _stage.offset_bottom
	)
	resized.connect(_apply_content_scale)
	_reward_panel.coin_arrived.connect(coin_arrived.emit)
	_reward_panel.ability_arrived.connect(ability_arrived.emit)
	_reward_panel.flights_finished.connect(_on_flights_finished)
	_apply_content_scale()
	_reset_visuals()


## Starts the sequence. `rewards` is `{"coins": int, "abilities": {ability_id: count}}`;
## `chest_global_rect` is the side widget's chest icon, which the stage lifts out of and returns to.
## Ignored while a sequence is already running.
func play(
	rewards: Dictionary,
	chest_global_rect: Rect2,
	coin_target_global: Vector2,
	ability_target_global: Vector2
) -> void:
	if _phase != Phase.IDLE:
		return

	_play_generation += 1
	_coin_target_global = coin_target_global
	_ability_target_global = ability_target_global
	_reset_visuals()
	_reward_panel.set_rewards(rewards)
	show()
	_lift(chest_global_rect)


## A tap anywhere (or the owner forwarding `ui_cancel`) opens a waiting chest or cuts the reveal
## hold short. Flights and the return are brief and always play out.
func advance() -> void:
	match _phase:
		Phase.AWAITING_TAP:
			_open()
		Phase.REVEALING:
			if _reveal_settled:
				_collect()


func is_playing() -> bool:
	return _phase != Phase.IDLE


func _gui_input(event: InputEvent) -> void:
	var is_press := (
		(event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	)
	if is_press:
		accept_event()
		advance()


func _lift(chest_global_rect: Rect2) -> void:
	_phase = Phase.LIFTING
	_rest_position = _stage.position
	_stage.pivot_offset = _stage.size * 0.5
	# The stage lives inside the (possibly scaled) content group, so the widget's chest rect is
	# measured in that group's space.
	var content_inverse := _content.get_global_transform().affine_inverse()
	var source_size := chest_global_rect.size * content_inverse.get_scale()
	var source_center := content_inverse * chest_global_rect.get_center()
	_source_scale = Vector2.ONE * maxf(source_size.x / maxf(_stage.size.x, 1.0), 0.05)
	_source_position = source_center - _stage.size * 0.5
	_stage.position = _source_position
	_stage.scale = _source_scale

	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, lift_duration * 0.6)
	tween.tween_property(_stage, "position", _rest_position, lift_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_stage, "scale", Vector2.ONE, lift_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rays, "modulate:a", 0.45, lift_duration)
	tween.tween_property(_rays, "scale", Vector2(0.72, 0.72), lift_duration)
	await tween.finished
	if _phase != Phase.LIFTING:
		return

	_phase = Phase.AWAITING_TAP
	_stage.pivot_offset = _stage.size * BASE_PIVOT_FRACTION
	_shake_count = 0
	_play_shake()
	_show_tap_hint()
	var generation := _play_generation
	get_tree().create_timer(auto_open_delay).timeout.connect(_on_auto_open_timeout.bind(generation))


func _on_auto_open_timeout(generation: int) -> void:
	if generation == _play_generation and _phase == Phase.AWAITING_TAP:
		_open()


## Each wobble is a little stronger than the last, so the wait builds toward the opening.
func _play_shake() -> void:
	if _phase != Phase.AWAITING_TAP:
		return

	var strength := minf(1.0 + float(_shake_count) * 0.35, 2.0)
	_shake_count += 1
	var angle := 0.045 * strength
	var tween := UIMotionScript.retween(_stage, SHAKE_META)
	tween.tween_property(_stage, "rotation", -angle, 0.06).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_stage, "scale", Vector2(1.04, 0.97), 0.06)
	tween.tween_property(_stage, "rotation", angle, 0.09).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_stage, "rotation", -angle * 0.55, 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_stage, "rotation", 0.0, 0.07).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_stage, "scale", Vector2.ONE, 0.07)
	tween.tween_interval(shake_pause)
	tween.tween_callback(_play_shake)


func _open() -> void:
	_phase = Phase.OPENING
	UIMotionScript.stop_tween(_stage, SHAKE_META)
	_hide_tap_hint()
	_stage.rotation = 0.0

	var tween := create_tween()
	tween.tween_property(_stage, "scale", Vector2(1.14, 0.86), 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_burst_open)
	tween.tween_property(_stage, "scale", Vector2(0.93, 1.1), 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_stage, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	if _phase == Phase.OPENING:
		_reveal()


func _burst_open() -> void:
	_closed_chest.visible = false
	_open_chest.visible = true
	_chest_burst.restart()
	_chest_sparkles.restart()

	_flash.modulate.a = 0.7
	var tween := create_tween().set_parallel()
	tween.tween_property(_flash, "modulate:a", 0.0, 0.36).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rays, "modulate:a", 1.0, 0.22)
	tween.tween_property(_rays, "scale", Vector2.ONE, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	SfxManager.play(SfxCatalogScript.EVENT_SHOP_PURCHASE_SUCCESS)
	HapticsManager.play(HapticsCatalogScript.EVENT_REWARD_CHEST_GOAL_COMPLETE)
	opened.emit()


## Rewards pop out of the chest mouth and settle into the row above it, then hold so the player
## can read what they got before it flies away.
func _reveal() -> void:
	_phase = Phase.REVEALING
	var mouth := _stage.get_global_transform() * (_stage.size * MOUTH_FRACTION)
	var settle_seconds := _reward_panel.pop_in(mouth)

	# A tap only cuts the hold short once every reward has landed in its slot, so a flight never
	# launches from a reward that is still popping out.
	var generation := _play_generation
	await get_tree().create_timer(settle_seconds).timeout
	if generation != _play_generation or _phase != Phase.REVEALING:
		return
	_reveal_settled = true
	await get_tree().create_timer(reveal_hold).timeout
	if generation == _play_generation and _phase == Phase.REVEALING:
		_collect()


func _collect() -> void:
	_phase = Phase.COLLECTING
	# Lift the dim so the coin counter and LEVEL button are visible when the rewards land.
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 0.5, 0.4)
	tween.tween_property(_rays, "modulate:a", 0.0, 0.5)

	if _reward_panel.launch_flights(_flyer_layer, _coin_target_global, _ability_target_global) == 0:
		_return_chest()


func _on_flights_finished() -> void:
	if _phase == Phase.COLLECTING:
		_return_chest()


func _return_chest() -> void:
	_phase = Phase.RETURNING
	_open_chest.visible = false
	_closed_chest.visible = true
	_stage.rotation = 0.0
	_stage.pivot_offset = _stage.size * 0.5

	var tween := create_tween().set_parallel()
	tween.tween_property(_stage, "position", _source_position, return_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_stage, "scale", _source_scale, return_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_dim, "modulate:a", 0.0, return_duration)
	tween.tween_property(_rays, "modulate:a", 0.0, return_duration * 0.5)
	await tween.finished

	hide()
	_phase = Phase.IDLE
	_reset_visuals()
	finished.emit()


func _show_tap_hint() -> void:
	_tap_hint.visible = true
	_tap_hint.modulate.a = 0.0
	var tween := UIMotionScript.retween(_tap_hint, HINT_META).set_loops()
	tween.tween_property(_tap_hint, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_tap_hint, "modulate:a", 0.45, 0.55).set_trans(Tween.TRANS_SINE)


func _hide_tap_hint() -> void:
	UIMotionScript.stop_tween(_tap_hint, HINT_META)
	_tap_hint.visible = false


func _reset_visuals() -> void:
	UIMotionScript.stop_tween(_stage, SHAKE_META)
	_hide_tap_hint()
	for child in _flyer_layer.get_children():
		child.queue_free()
	_dim.modulate.a = 0.0
	_flash.modulate.a = 0.0
	_rays.modulate.a = 0.0
	_rays.scale = Vector2(0.5, 0.5)
	_rays.pivot_offset = _rays.size * 0.5
	_closed_chest.visible = true
	_open_chest.visible = false
	_stage.rotation = 0.0
	_stage.scale = Vector2.ONE
	_stage.offset_left = _stage_rest_offsets.x
	_stage.offset_top = _stage_rest_offsets.y
	_stage.offset_right = _stage_rest_offsets.z
	_stage.offset_bottom = _stage_rest_offsets.w
	_reveal_settled = false
	_reward_panel.reset()


func _apply_content_scale() -> void:
	var content_scale := clampf(size.y / CONTENT_REFERENCE_HEIGHT, MIN_CONTENT_SCALE, 1.0)
	_content.pivot_offset = Vector2(size.x * 0.5, size.y * CONTENT_ANCHOR_Y)
	_content.scale = Vector2(content_scale, content_scale)
