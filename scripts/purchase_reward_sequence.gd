extends Control
class_name PurchaseRewardSequence

## Full-screen reward reveal that confirms a successful purchase, in place of a "Purchase complete"
## dialog. The Shop (destination and in-level overlay) and the Main Menu Starter Bundle play it.
##
## Beats: the screen dims behind a flash, rays, and confetti while a green "PURCHASE COMPLETE"
## ribbon pops in and each purchased reward lifts off the offer that sold it into a centred reveal
## row. After a short hold (a tap cuts it short once everything has landed), coins fly to the
## screen's coin counter and boosters to the owner's booster target, then the overlay fades away.
##
## Presentation only: the purchase flow granted and saved the rewards before this plays. Owners
## (scripts/shop_screen.gd, scripts/production_main_menu.gd) count their displayed balance up from
## `coin_arrived`, pulse their booster target from `ability_arrived`, and settle to saved values on
## `finished`. Beat durations are exported here and flight durations on `%RewardRow`, so tests can
## compress the whole sequence.

signal coin_arrived(arrived_count: int, total_count: int)
signal ability_arrived(ability_id: StringName)
signal finished

enum Phase { IDLE, REVEALING, COLLECTING, CLOSING }

const UIMotionScript := preload("res://scripts/ui_motion.gd")
## Must match the Rays/Banner/RewardRow/TapHint vertical anchor in the scene; short screens shrink
## the reveal group around this line.
const CONTENT_ANCHOR_Y := 0.48
## The ribbon, reward row, and prompt span about 500px. Screens shorter than this height scale that
## group down (to no less than MIN_CONTENT_SCALE) so it stays clear of the top and bottom bars.
const CONTENT_REFERENCE_HEIGHT := 1100.0
const MIN_CONTENT_SCALE := 0.78
const HINT_META := &"_purchase_hint_tween"
## How dim the screen stays while rewards fly, so the counter and booster target read clearly.
const COLLECT_DIM_ALPHA := 0.35

@export_group("Timing")
@export var intro_duration := 0.3
@export var reveal_hold := 1.4
@export var outro_duration := 0.3

@onready var _dim := %Dim as ColorRect
@onready var _flash := %Flash as ColorRect
@onready var _content := %Content as Control
@onready var _rays := %Rays as Control
@onready var _burst := %Burst as CPUParticles2D
@onready var _sparkles := %Sparkles as CPUParticles2D
@onready var _banner := %Banner as OfferRibbonBanner
@onready var _reward_row := %RewardRow as RewardRevealRow
@onready var _tap_hint := %TapHint as Label
@onready var _flyer_layer := %FlyerLayer as Control

var _phase := Phase.IDLE
var _play_generation := 0
var _coin_target_global := Vector2.ZERO
var _ability_target_global := Vector2.ZERO
var _reveal_settled := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_banner.set_text("PURCHASE COMPLETE")
	resized.connect(_apply_content_scale)
	_reward_row.coin_arrived.connect(coin_arrived.emit)
	_reward_row.ability_arrived.connect(ability_arrived.emit)
	_reward_row.flights_finished.connect(_on_flights_finished)
	_apply_content_scale()
	_reset_visuals()


## Starts the sequence. `rewards` is `{"coins": int, "abilities": {ability_id: count}}`, the amounts
## actually granted. `origin_rects` maps "coins" or an ability id to the global rect of that reward's
## art on the purchased offer; rewards without one rise from the centre. Ignored while a sequence is
## already running; `finished` follows on the next frame when there is nothing to show.
func play(
	rewards: Dictionary,
	origin_rects: Dictionary,
	coin_target_global: Vector2,
	ability_target_global: Vector2
) -> void:
	if _phase != Phase.IDLE:
		return

	_play_generation += 1
	_coin_target_global = coin_target_global
	_ability_target_global = ability_target_global
	_reset_visuals()
	_reward_row.set_rewards(rewards)
	if not _reward_row.has_rewards():
		finished.emit.call_deferred()
		return

	_phase = Phase.REVEALING
	show()
	# The row lays out its newly shown slots at the end of this frame, and each reward pops into its
	# slot's laid-out position, so the reveal starts on the next frame. Every later beat is a
	# callback on a tween bound to this node rather than an await, so nothing outlives the sequence.
	get_tree().process_frame.connect(
		_reveal.bind(_play_generation, origin_rects), CONNECT_ONE_SHOT
	)


## A tap anywhere (or the owner forwarding `ui_cancel`) cuts the reveal hold short once every
## reward has landed in the row. Flights and the fade-out are brief and always play out.
func advance() -> void:
	if _phase == Phase.REVEALING and _reveal_settled:
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


func _reveal(generation: int, origin_rects: Dictionary) -> void:
	if generation != _play_generation or _phase != Phase.REVEALING:
		return
	var row_center := _reward_row.get_global_rect().get_center()
	_play_burst(row_center)

	var origins := {}
	for key in origin_rects.keys():
		var rect = origin_rects[key]
		if rect is Rect2:
			origins[String(key)] = (rect as Rect2).get_center()
	var settle_seconds := _reward_row.pop_in(row_center, origins)

	# A tap only cuts the hold short once every reward has landed in its slot, so a flight never
	# launches from a reward that is still popping in.
	_after(settle_seconds, _on_reveal_settled.bind(generation))


func _on_reveal_settled(generation: int) -> void:
	if generation != _play_generation or _phase != Phase.REVEALING:
		return
	_reveal_settled = true
	_show_tap_hint()
	_after(reveal_hold, _on_reveal_hold_elapsed.bind(generation))


func _on_reveal_hold_elapsed(generation: int) -> void:
	if generation == _play_generation and _phase == Phase.REVEALING:
		_collect()


## Calls `callback` after `seconds` on a tween bound to this node, so a pending beat is dropped with
## the sequence instead of outliving it the way a SceneTreeTimer or an awaiting coroutine would.
func _after(seconds: float, callback: Callable) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(callback)


func _play_burst(row_center_global: Vector2) -> void:
	var burst_position := _content.get_global_transform().affine_inverse() * row_center_global
	_burst.position = burst_position
	_sparkles.position = burst_position
	_burst.restart()
	_sparkles.restart()

	_flash.modulate.a = 0.6
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.6, 0.6)
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, intro_duration)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.36).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rays, "modulate:a", 1.0, intro_duration)
	tween.tween_property(_rays, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_banner, "modulate:a", 1.0, 0.12)
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.36) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _collect() -> void:
	_phase = Phase.COLLECTING
	_hide_tap_hint()
	# Lift the dim so the coin counter and booster target are visible when the rewards land.
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", COLLECT_DIM_ALPHA, 0.35)
	tween.tween_property(_rays, "modulate:a", 0.0, 0.4)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.25)

	if _reward_row.launch_flights(_flyer_layer, _coin_target_global, _ability_target_global) == 0:
		_close()


func _on_flights_finished() -> void:
	if _phase == Phase.COLLECTING:
		_close()


func _close() -> void:
	_phase = Phase.CLOSING
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 0.0, outro_duration)
	tween.tween_property(_rays, "modulate:a", 0.0, outro_duration * 0.5)
	tween.chain().tween_callback(_on_closed.bind(_play_generation))


func _on_closed(generation: int) -> void:
	if generation != _play_generation:
		return

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
	_hide_tap_hint()
	for child in _flyer_layer.get_children():
		child.queue_free()
	_dim.modulate.a = 0.0
	_flash.modulate.a = 0.0
	_rays.modulate.a = 0.0
	_rays.scale = Vector2(0.5, 0.5)
	_rays.pivot_offset = _rays.size * 0.5
	_banner.modulate.a = 0.0
	_banner.scale = Vector2.ONE
	_reveal_settled = false
	_reward_row.reset()


func _apply_content_scale() -> void:
	var content_scale := clampf(size.y / CONTENT_REFERENCE_HEIGHT, MIN_CONTENT_SCALE, 1.0)
	_content.pivot_offset = Vector2(size.x * 0.5, size.y * CONTENT_ANCHOR_Y)
	_content.scale = Vector2(content_scale, content_scale)
