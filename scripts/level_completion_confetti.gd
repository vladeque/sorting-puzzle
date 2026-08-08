class_name LevelCompletionConfetti
extends Control

## Two-cannon celebration burst played by scripts/level.gd while a completed level stays on screen,
## before scenes/ui/level_completion_screen.tscn opens. Follows the same self-contained effect shape
## as scripts/hammer_impact_effect.gd: a full-rect, input-transparent Control that owns its own
## visuals and reports `finished` when the burst is over.
##
## The two CPUParticles2D cannons are scene-configured (piece shape, colors, spin, fade); this script
## only owns what depends on the live viewport -- muzzle placement in the bottom corners and the
## launch aim that makes both streams converge near the middle of the screen. The aim is solved from
## projectile motion rather than baked into the scene so the arcs land in the same relative place on
## every supported resolution, not just the 720x1280 design size.

signal finished

const DESIGN_WIDTH := 720.0
const DESIGN_HEIGHT := 1280.0
const MIN_PIECE_SCALE := 0.75
const MAX_PIECE_SCALE := 1.35
## Fall acceleration at the design height; scaled with the viewport so the arc keeps its timing.
const GRAVITY_AT_DESIGN_HEIGHT := 1250.0
## Apex of the average piece, as a share of viewport height above the muzzle (0.5 == screen middle).
## Slightly under half so the bulk of the burst peaks around the middle instead of past it -- the
## fastest pieces in the velocity spread still reach the upper third.
const APEX_HEIGHT_RATIO := 0.46
## Share of the muzzle-to-center distance the average piece covers horizontally by its apex. Just
## under 1.0 so the two streams meet around the middle instead of crossing past each other.
const HORIZONTAL_REACH_RATIO := 0.92
## Makes up for the scene's air damping, which bleeds off speed before the apex is reached.
const DAMPING_COMPENSATION := 1.03
## Fastest and slowest pieces, relative to the solved launch speed.
const VELOCITY_SPREAD := 0.14
## Extra time after the last piece can expire, so nothing pops out mid-fall.
const SETTLE_SECONDS := 0.35

## Where each cannon sits relative to its bottom corner, at the design resolution. The vertical part
## is measured from the bottom safe-area inset, not the raw screen edge, so a gesture bar never
## swallows the muzzle.
@export var muzzle_inset := Vector2(28.0, 10.0)

@onready var _left_cannon: CPUParticles2D = %LeftCannon
@onready var _right_cannon: CPUParticles2D = %RightCannon

## Scene-authored piece size at the design resolution, kept so repeated bursts always rescale from
## the same base instead of compounding the previous burst's scaling.
var _base_piece_size := Vector2.ZERO
var _viewport_size := Vector2.ZERO
var _safe_margins := Vector4.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_base_piece_size = Vector2(_left_cannon.scale_amount_min, _left_cannon.scale_amount_max)
	_apply_full_rect()


## Same shape as every other level UI component (UI-003): scripts/level.gd hands each one the current
## viewport and safe-area insets. Nothing to lay out here beyond the full rect -- the values are kept
## for the next play(), which needs them to place the muzzles and solve the aim.
func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	_safe_margins = safe_margins
	_viewport_size = viewport_size
	_apply_full_rect()


## Fires both cannons and returns once the last piece has faded, emitting `finished`. Callers that
## only want the burst started can ignore the coroutine (scripts/level.gd paces the completion screen
## on its own celebration timer rather than on this signal).
func play() -> void:
	_apply_full_rect()
	visible = true
	var viewport_size := _viewport_size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	_aim_cannon(_left_cannon, 1.0, viewport_size)
	_aim_cannon(_right_cannon, -1.0, viewport_size)

	await get_tree().create_timer(get_burst_duration()).timeout
	if not is_inside_tree():
		return

	visible = false
	finished.emit()


## When the last piece can still be on screen: the tail of the (not perfectly instant) emission
## window plus a full lifetime. Per-piece lifetime randomness only shortens lives, so it needs no
## allowance here.
func get_burst_duration() -> float:
	var emission_seconds := _left_cannon.lifetime * (1.0 - _left_cannon.explosiveness)
	return emission_seconds + _left_cannon.lifetime + SETTLE_SECONDS


## Places one cannon in its bottom corner and solves its launch vector so the average piece peaks
## near the middle of the screen. `horizontal_sign` is 1.0 for the left cannon (aiming right) and
## -1.0 for the right one.
func _aim_cannon(cannon: CPUParticles2D, horizontal_sign: float, viewport_size: Vector2) -> void:
	var piece_scale := clampf(
		minf(viewport_size.x / DESIGN_WIDTH, viewport_size.y / DESIGN_HEIGHT),
		MIN_PIECE_SCALE,
		MAX_PIECE_SCALE
	)
	var gravity := GRAVITY_AT_DESIGN_HEIGHT * viewport_size.y / DESIGN_HEIGHT
	var inset := muzzle_inset * piece_scale
	var muzzle_x := inset.x if horizontal_sign > 0.0 else viewport_size.x - inset.x
	cannon.position = Vector2(muzzle_x, viewport_size.y - _safe_margins.w - inset.y)

	# Upward speed that peaks at APEX_HEIGHT_RATIO, then the sideways speed that covers the distance
	# to the screen middle within that same rise time.
	var apex_height := viewport_size.y * APEX_HEIGHT_RATIO
	var vertical_speed := sqrt(2.0 * gravity * apex_height)
	var rise_seconds := vertical_speed / gravity
	var horizontal_distance := absf(viewport_size.x * 0.5 - muzzle_x) * HORIZONTAL_REACH_RATIO
	var horizontal_speed := horizontal_distance / rise_seconds
	var launch_speed := Vector2(horizontal_speed, vertical_speed).length() * DAMPING_COMPENSATION

	cannon.gravity = Vector2(0.0, gravity)
	cannon.direction = Vector2(horizontal_speed * horizontal_sign, -vertical_speed).normalized()
	cannon.initial_velocity_min = launch_speed * (1.0 - VELOCITY_SPREAD)
	cannon.initial_velocity_max = launch_speed * (1.0 + VELOCITY_SPREAD)
	cannon.scale_amount_min = _base_piece_size.x * piece_scale
	cannon.scale_amount_max = _base_piece_size.y * piece_scale
	cannon.restart()


func _apply_full_rect() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
