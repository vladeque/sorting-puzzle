class_name HammerImpactEffect
extends Control

signal impact
signal finished

const DESIGN_WIDTH := 720.0
const BURST_RAY_COUNT := 16

@export_range(0.1, 2.0, 0.01) var base_hammer_scale := 0.82

@onready var _impact_anchor: Node2D = %ImpactAnchor
@onready var _hammer_pivot: Node2D = %HammerPivot
@onready var _hammer_sprite: Sprite2D = %HammerSprite
@onready var _animation_player: AnimationPlayer = %AnimationPlayer

var _impact_position := Vector2.ZERO
var _layout_scale := 1.0
var _burst_amount := 0.0:
	set(value):
		_burst_amount = value
		queue_redraw()
var _flash_amount := 0.0:
	set(value):
		_flash_amount = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_apply_full_rect()


func play(target_screen_position: Vector2) -> void:
	_apply_full_rect()
	_impact_position = target_screen_position
	_layout_scale = clampf(size.x / DESIGN_WIDTH, 0.75, 1.35)
	visible = true
	_burst_amount = 0.0
	_flash_amount = 0.0

	_impact_anchor.position = _impact_position
	_impact_anchor.scale = Vector2.ONE
	_hammer_sprite.scale = Vector2.ONE * base_hammer_scale * _layout_scale
	_animation_player.stop()
	_animation_player.play(&"strike")


func _draw() -> void:
	if _burst_amount <= 0.0 and _flash_amount <= 0.0:
		return

	if _flash_amount > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.78, 0.92, 0.16 * _flash_amount))

	if _burst_amount <= 0.0:
		return

	var alpha := _burst_amount
	var expansion := 1.0 - alpha
	var radius := lerpf(34.0, 126.0, expansion) * _layout_scale
	draw_circle(
		_impact_position,
		lerpf(78.0, 150.0, expansion) * _layout_scale,
		Color(1.0, 0.18, 0.72, 0.12 * alpha)
	)
	draw_circle(
		_impact_position,
		lerpf(34.0, 76.0, expansion) * _layout_scale,
		Color(1.0, 0.72, 0.92, 0.24 * alpha)
	)
	draw_arc(
		_impact_position,
		radius,
		0.0,
		TAU,
		64,
		Color(1.0, 0.34, 0.78, 0.82 * alpha),
		8.0 * _layout_scale,
		true
	)
	draw_arc(
		_impact_position,
		radius * 0.62,
		0.0,
		TAU,
		48,
		Color(1.0, 1.0, 1.0, 0.72 * alpha),
		5.0 * _layout_scale,
		true
	)

	for ray_index in range(BURST_RAY_COUNT):
		var direction := Vector2.RIGHT.rotated(TAU * float(ray_index) / float(BURST_RAY_COUNT))
		var alternating_length := 34.0 if ray_index % 2 == 0 else 0.0
		var start := _impact_position + direction * (42.0 * _layout_scale)
		var end_distance := lerpf(108.0, 176.0, expansion) + alternating_length
		var end := _impact_position + direction * (end_distance * _layout_scale)
		var ray_color := Color(1.0, 0.88, 0.98, (0.94 if ray_index % 2 == 0 else 0.66) * alpha)
		var ray_width := (6.0 if ray_index % 2 == 0 else 3.5) * _layout_scale
		draw_line(start, end, ray_color, ray_width, true)

	draw_circle(
		_impact_position,
		lerpf(28.0, 8.0, expansion) * _layout_scale,
		Color(1.0, 1.0, 1.0, 0.92 * alpha)
	)


func _emit_impact() -> void:
	impact.emit()


func _emit_finished() -> void:
	visible = false
	finished.emit()


func _apply_full_rect() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
