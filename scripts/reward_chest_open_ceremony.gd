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
## `finished`. Beat durations are exported so tests can compress the whole sequence.

signal opened
signal coin_arrived(arrived_count: int, total_count: int)
signal ability_arrived(ability_id: StringName)
signal finished

enum Phase { IDLE, LIFTING, AWAITING_TAP, OPENING, REVEALING, COLLECTING, RETURNING }

const UIMotionScript := preload("res://scripts/ui_motion.gd")
const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")
const HapticsCatalogScript := preload("res://scripts/haptics/haptics_catalog.gd")
const COIN_TEXTURE := preload("res://assets/ui/clover_coin_transparent_96x96.png")
const COIN_FLYER_SIZE := Vector2(54.0, 54.0)
const ABILITY_FLYER_SIZE := Vector2(64.0, 64.0)
const MIN_COIN_FLYERS := 5
const MAX_COIN_FLYERS := 12
const COINS_PER_FLYER := 20
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
@export var reveal_stagger := 0.07
@export var reveal_pop_duration := 0.42
@export var reveal_hold := 1.0
@export var coin_scatter_duration := 0.16
@export var coin_flight_duration := 0.58
@export var coin_stagger := 0.045
@export var ability_flight_duration := 0.66
@export var ability_stagger := 0.1
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
@onready var _reward_panel := %RewardPanel as Control
@onready var _coin_slot := %CoinSlot as Control
@onready var _coin_visual := %CoinVisual as Control
@onready var _coin_amount_label := %CoinAmountLabel as Label
@onready var _flyer_layer := %FlyerLayer as Control
@onready var _ability_slots := {
	&"hammer": %HammerSlot as Control,
	&"shuffle": %ShuffleSlot as Control,
	&"highlight": %HighlightSlot as Control,
	&"freezer": %FreezerSlot as Control,
}
@onready var _ability_chips := {
	&"hammer": %HammerReward as OfferBoosterChip,
	&"shuffle": %ShuffleReward as OfferBoosterChip,
	&"highlight": %HighlightReward as OfferBoosterChip,
	&"freezer": %FreezerReward as OfferBoosterChip,
}

var _phase := Phase.IDLE
var _play_generation := 0
var _coin_reward := 0
var _ability_rewards := {}
var _source_position := Vector2.ZERO
var _source_scale := Vector2.ONE
var _rest_position := Vector2.ZERO
var _coin_target := Vector2.ZERO
var _ability_target := Vector2.ZERO
var _coin_flyer_count := 0
var _coins_landed := 0
var _flights_in_progress := 0
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
	_coin_reward = maxi(int(rewards.get("coins", 0)), 0)
	_ability_rewards = (rewards.get("abilities", {}) as Dictionary).duplicate()
	_coin_target = _to_local(coin_target_global)
	_ability_target = _to_local(ability_target_global)
	_reset_visuals()
	_apply_reward_counts()
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
	_reward_panel.modulate.a = 1.0
	var mouth := _stage.get_global_transform() * (_stage.size * MOUTH_FRACTION)
	var delay := 0.0
	for visual in _get_reward_visuals():
		_pop_from_mouth(visual, mouth, delay)
		delay += reveal_stagger

	# A tap only cuts the hold short once every reward has landed in its slot, so a flight never
	# launches from a reward that is still popping out.
	var generation := _play_generation
	await get_tree().create_timer(delay + reveal_pop_duration).timeout
	if generation != _play_generation or _phase != Phase.REVEALING:
		return
	_reveal_settled = true
	await get_tree().create_timer(reveal_hold).timeout
	if generation == _play_generation and _phase == Phase.REVEALING:
		_collect()


func _pop_from_mouth(visual: Control, mouth_global: Vector2, delay: float) -> void:
	var rest := visual.position
	var parent := visual.get_parent() as Control
	var start := parent.get_global_transform().affine_inverse() * mouth_global - visual.size * 0.5
	visual.pivot_offset = visual.size * 0.5
	visual.position = start
	visual.scale = Vector2(0.3, 0.3)
	var tween := visual.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(visual, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(visual, "position", rest, reveal_pop_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual, "scale", Vector2.ONE, reveal_pop_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _collect() -> void:
	_phase = Phase.COLLECTING
	# Lift the dim so the coin counter and LEVEL button are visible when the rewards land.
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 0.5, 0.4)
	tween.tween_property(_rays, "modulate:a", 0.0, 0.5)

	_flights_in_progress = 0
	_launch_coin_flights()
	_launch_ability_flights()
	if _flights_in_progress == 0:
		_return_chest()


func _launch_coin_flights() -> void:
	_coins_landed = 0
	_coin_flyer_count = 0
	if _coin_reward <= 0 or not _coin_slot.visible:
		return

	_coin_flyer_count = clampi(
		ceili(float(_coin_reward) / float(COINS_PER_FLYER)), MIN_COIN_FLYERS, MAX_COIN_FLYERS
	)
	var pile_center := _to_local(_coin_visual.get_global_rect().get_center())
	for index in range(_coin_flyer_count):
		var angle := TAU * float(index) / float(_coin_flyer_count) + randf_range(-0.3, 0.3)
		var scatter := pile_center + Vector2.from_angle(angle) * randf_range(46.0, 96.0)
		var flyer := _make_flyer(COIN_TEXTURE, COIN_FLYER_SIZE, pile_center)
		var control := scatter.lerp(_coin_target, 0.5) + Vector2(randf_range(-90.0, 90.0), 40.0)
		var flight := flyer.create_tween()
		flight.tween_interval(float(index) * coin_stagger)
		flight.tween_property(flyer, "modulate:a", 1.0, 0.05)
		flight.parallel().tween_property(flyer, "position", scatter - COIN_FLYER_SIZE * 0.5, coin_scatter_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flight.tween_method(
			_move_along_curve.bind(flyer, scatter, control, _coin_target), 0.0, 1.0, coin_flight_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		flight.parallel().tween_property(flyer, "scale", Vector2(0.7, 0.7), coin_flight_duration)
		flight.tween_callback(_on_coin_landed.bind(flyer))
		_flights_in_progress += 1

	var pile_tween := _coin_visual.create_tween()
	pile_tween.tween_property(_coin_visual, "scale", Vector2(0.4, 0.4), 0.22 + coin_stagger * _coin_flyer_count)
	pile_tween.parallel().tween_property(_coin_visual, "modulate:a", 0.0, 0.22 + coin_stagger * _coin_flyer_count)


func _launch_ability_flights() -> void:
	var index := 0
	for ability_id in _ability_chips.keys():
		var slot := _ability_slots[ability_id] as Control
		if not slot.visible:
			continue
		var chip := _ability_chips[ability_id] as OfferBoosterChip
		var start := _to_local(chip.get_icon_global_rect().get_center())
		var flyer := _make_flyer(chip.icon, ABILITY_FLYER_SIZE, start)
		flyer.modulate.a = 1.0
		# Outer chips swing wide before dropping onto the button, which keeps the four paths apart.
		var side := (float(index) - 1.5) / 1.5
		var control := start.lerp(_ability_target, 0.45) + Vector2(side * 150.0, -40.0)
		var flight := flyer.create_tween()
		flight.tween_interval(0.12 + float(index) * ability_stagger)
		flight.tween_callback(_hide_chip.bind(chip))
		flight.tween_method(
			_move_along_curve.bind(flyer, start, control, _ability_target), 0.0, 1.0, ability_flight_duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flight.parallel().tween_property(flyer, "scale", Vector2(0.62, 0.62), ability_flight_duration)
		flight.tween_callback(_on_ability_landed.bind(flyer, StringName(ability_id)))
		_flights_in_progress += 1
		index += 1


func _hide_chip(chip: Control) -> void:
	chip.modulate.a = 0.0


func _make_flyer(texture: Texture2D, flyer_size: Vector2, center: Vector2) -> TextureRect:
	var flyer := TextureRect.new()
	flyer.texture = texture
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.custom_minimum_size = flyer_size
	flyer.size = flyer_size
	flyer.pivot_offset = flyer_size * 0.5
	flyer.position = center - flyer_size * 0.5
	flyer.modulate.a = 0.0
	_flyer_layer.add_child(flyer)
	return flyer


func _move_along_curve(
	progress: float, flyer: Control, start: Vector2, control: Vector2, end: Vector2
) -> void:
	var inverse := 1.0 - progress
	var point := start * inverse * inverse + control * 2.0 * inverse * progress + end * progress * progress
	flyer.position = point - flyer.size * 0.5


func _on_coin_landed(flyer: Control) -> void:
	flyer.queue_free()
	_coins_landed += 1
	coin_arrived.emit(_coins_landed, _coin_flyer_count)
	SfxManager.play(SfxCatalogScript.EVENT_COIN_GAIN)
	_on_flight_finished()


func _on_ability_landed(flyer: Control, ability_id: StringName) -> void:
	flyer.queue_free()
	ability_arrived.emit(ability_id)
	SfxManager.play(SfxCatalogScript.EVENT_REWARD_CHEST_STAR_ARRIVAL)
	_on_flight_finished()


func _on_flight_finished() -> void:
	_flights_in_progress -= 1
	if _flights_in_progress <= 0 and _phase == Phase.COLLECTING:
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


func _apply_reward_counts() -> void:
	_coin_amount_label.text = "+%d" % _coin_reward
	_coin_slot.visible = _coin_reward > 0
	for ability_id in _ability_chips.keys():
		var count := maxi(int(_ability_rewards.get(String(ability_id), _ability_rewards.get(ability_id, 0))), 0)
		(_ability_chips[ability_id] as OfferBoosterChip).set_count(count)
		(_ability_slots[ability_id] as Control).visible = count > 0


func _get_reward_visuals() -> Array[Control]:
	var visuals: Array[Control] = []
	if _coin_slot.visible:
		visuals.append(_coin_visual)
	for ability_id in _ability_chips.keys():
		if (_ability_slots[ability_id] as Control).visible:
			visuals.append(_ability_chips[ability_id] as Control)
	return visuals


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
	_reward_panel.modulate.a = 0.0
	for visual in [_coin_visual] + _ability_chips.values():
		(visual as Control).modulate.a = 0.0
		(visual as Control).scale = Vector2.ONE


func _apply_content_scale() -> void:
	var content_scale := clampf(size.y / CONTENT_REFERENCE_HEIGHT, MIN_CONTENT_SCALE, 1.0)
	_content.pivot_offset = Vector2(size.x * 0.5, size.y * CONTENT_ANCHOR_Y)
	_content.scale = Vector2(content_scale, content_scale)


func _to_local(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point
