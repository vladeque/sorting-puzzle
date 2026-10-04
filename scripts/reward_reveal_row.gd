extends VBoxContainer
class_name RewardRevealRow

## The reward row both reward sequences share: a coin pile with its "+amount" label above up to four
## booster chips. It pops its rewards in from wherever they came from (the chest's mouth, or the
## purchased offer's own icons), then flies the coins to the coin counter and the boosters to their
## target through the owner's flyer layer. Slots for absent rewards collapse, so the row only shows
## what was granted.
##
## Owners: scripts/reward_chest_open_ceremony.gd and scripts/purchase_reward_sequence.gd. Each owns
## its dim, effects, and beat order; this row owns the reward visuals, the flights, and the landing
## signals and sounds. Flight timings are exported so tests can compress them.

signal coin_arrived(arrived_count: int, total_count: int)
signal ability_arrived(ability_id: StringName)
signal flights_finished

const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")
const COIN_TEXTURE := preload("res://assets/ui/clover_coin_transparent_96x96.png")
const COIN_FLYER_SIZE := Vector2(54.0, 54.0)
const ABILITY_FLYER_SIZE := Vector2(64.0, 64.0)
const MIN_COIN_FLYERS := 5
const MAX_COIN_FLYERS := 12
const COINS_PER_FLYER := 20
## The key `pop_in()` origins use for the coin pile; boosters use their ability id.
const COINS_KEY := "coins"

@export_group("Timing")
@export var reveal_stagger := 0.07
@export var reveal_pop_duration := 0.42
@export var coin_scatter_duration := 0.16
@export var coin_flight_duration := 0.58
@export var coin_stagger := 0.045
@export var ability_flight_duration := 0.66
@export var ability_stagger := 0.1

@onready var _coin_slot := %CoinSlot as Control
@onready var _coin_visual := %CoinVisual as Control
@onready var _coin_amount_label := %CoinAmountLabel as Label
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

var _coin_reward := 0
var _coin_flyer_count := 0
var _coins_landed := 0
var _flights_in_progress := 0
var _flyer_layer: Control


func _ready() -> void:
	reset()


## `rewards` is `{"coins": int, "abilities": {ability_id: count}}`. Shows only the positive rewards'
## slots and leaves every visual hidden until `pop_in()`.
func set_rewards(rewards: Dictionary) -> void:
	_coin_reward = maxi(int(rewards.get("coins", 0)), 0)
	_coin_amount_label.text = "+%s" % _format_count(_coin_reward)
	_coin_slot.visible = _coin_reward > 0
	var raw_abilities = rewards.get("abilities", {})
	var abilities: Dictionary = raw_abilities if raw_abilities is Dictionary else {}
	for ability_id in _ability_chips.keys():
		var count := maxi(int(abilities.get(String(ability_id), abilities.get(ability_id, 0))), 0)
		(_ability_chips[ability_id] as OfferBoosterChip).set_count(count)
		(_ability_slots[ability_id] as Control).visible = count > 0
	reset()


func has_rewards() -> bool:
	return not _get_shown_keys().is_empty()


## Hides the row and puts every reward visual back at rest, ready for the next `pop_in()`.
func reset() -> void:
	modulate.a = 0.0
	for visual in [_coin_visual] + _ability_chips.values():
		(visual as Control).modulate.a = 0.0
		(visual as Control).scale = Vector2.ONE


## Pops each shown reward out of its origin into its slot, staggered. `origins` maps `COINS_KEY` or
## an ability id to a global point; rewards without one start from `fallback_origin_global`. Returns
## the seconds until the last reward settles. The row must already be laid out (a frame after
## `set_rewards()`), because each reward returns to its slot's current position.
func pop_in(fallback_origin_global: Vector2, origins: Dictionary = {}) -> float:
	modulate.a = 1.0
	var delay := 0.0
	for key in _get_shown_keys():
		var origin: Vector2 = origins.get(key, fallback_origin_global)
		_pop_from(_get_visual(key), origin, delay)
		delay += reveal_stagger
	return delay + reveal_pop_duration


## Flies every shown reward out of the row: coins burst from the pile and arc to
## `coin_target_global`, boosters leave their chips and arc to `ability_target_global`. Flyers are
## added to `flyer_layer`, which must sit above everything they cross. Returns the number of flights
## launched; `flights_finished` follows the last landing and is not emitted when nothing flies.
func launch_flights(
	flyer_layer: Control, coin_target_global: Vector2, ability_target_global: Vector2
) -> int:
	_flyer_layer = flyer_layer
	_flights_in_progress = 0
	_launch_coin_flights(_to_layer(coin_target_global))
	_launch_ability_flights(_to_layer(ability_target_global))
	return _flights_in_progress


func _pop_from(visual: Control, origin_global: Vector2, delay: float) -> void:
	var rest := visual.position
	var parent := visual.get_parent() as Control
	var start := parent.get_global_transform().affine_inverse() * origin_global - visual.size * 0.5
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


func _launch_coin_flights(coin_target: Vector2) -> void:
	_coins_landed = 0
	_coin_flyer_count = 0
	if _coin_reward <= 0 or not _coin_slot.visible:
		return

	_coin_flyer_count = clampi(
		ceili(float(_coin_reward) / float(COINS_PER_FLYER)), MIN_COIN_FLYERS, MAX_COIN_FLYERS
	)
	var pile_center := _to_layer(_coin_visual.get_global_rect().get_center())
	for index in range(_coin_flyer_count):
		var angle := TAU * float(index) / float(_coin_flyer_count) + randf_range(-0.3, 0.3)
		var scatter := pile_center + Vector2.from_angle(angle) * randf_range(46.0, 96.0)
		var flyer := _make_flyer(COIN_TEXTURE, COIN_FLYER_SIZE, pile_center)
		var control := scatter.lerp(coin_target, 0.5) + Vector2(randf_range(-90.0, 90.0), 40.0)
		var flight := flyer.create_tween()
		flight.tween_interval(float(index) * coin_stagger)
		flight.tween_property(flyer, "modulate:a", 1.0, 0.05)
		flight.parallel().tween_property(flyer, "position", scatter - COIN_FLYER_SIZE * 0.5, coin_scatter_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flight.tween_method(
			_move_along_curve.bind(flyer, scatter, control, coin_target), 0.0, 1.0, coin_flight_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		flight.parallel().tween_property(flyer, "scale", Vector2(0.7, 0.7), coin_flight_duration)
		flight.tween_callback(_on_coin_landed.bind(flyer))
		_flights_in_progress += 1

	var pile_tween := _coin_visual.create_tween()
	pile_tween.tween_property(_coin_visual, "scale", Vector2(0.4, 0.4), 0.22 + coin_stagger * _coin_flyer_count)
	pile_tween.parallel().tween_property(_coin_visual, "modulate:a", 0.0, 0.22 + coin_stagger * _coin_flyer_count)


func _launch_ability_flights(ability_target: Vector2) -> void:
	var index := 0
	for ability_id in _ability_chips.keys():
		var slot := _ability_slots[ability_id] as Control
		if not slot.visible:
			continue
		var chip := _ability_chips[ability_id] as OfferBoosterChip
		var start := _to_layer(chip.get_icon_global_rect().get_center())
		var flyer := _make_flyer(chip.icon, ABILITY_FLYER_SIZE, start)
		flyer.modulate.a = 1.0
		# Outer chips swing wide before dropping onto the target, which keeps the four paths apart.
		var side := (float(index) - 1.5) / 1.5
		var control := start.lerp(ability_target, 0.45) + Vector2(side * 150.0, -40.0)
		var flight := flyer.create_tween()
		flight.tween_interval(0.12 + float(index) * ability_stagger)
		flight.tween_callback(_hide_chip.bind(chip))
		flight.tween_method(
			_move_along_curve.bind(flyer, start, control, ability_target), 0.0, 1.0, ability_flight_duration
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
	if _flights_in_progress == 0:
		flights_finished.emit()


## Reward keys in reveal order: the coin pile first, then the boosters left to right.
func _get_shown_keys() -> Array[String]:
	var keys: Array[String] = []
	if _coin_slot.visible:
		keys.append(COINS_KEY)
	for ability_id in _ability_chips.keys():
		if (_ability_slots[ability_id] as Control).visible:
			keys.append(String(ability_id))
	return keys


func _get_visual(key: String) -> Control:
	if key == COINS_KEY:
		return _coin_visual
	return _ability_chips[StringName(key)] as Control


func _to_layer(global_point: Vector2) -> Vector2:
	return _flyer_layer.get_global_transform().affine_inverse() * global_point


func _format_count(value: int) -> String:
	return GameText.format_number(value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_coin_amount_label.text = "+%s" % _format_count(_coin_reward)
