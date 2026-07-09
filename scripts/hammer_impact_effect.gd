class_name HammerImpactEffect
extends Control

signal impact
signal finished

const DESIGN_WIDTH := 720.0
const HAMMER_HEAD_CENTER_OFFSET := 364.0
const BURST_RAY_COUNT := 10

@export_range(0.1, 1.0, 0.01) var base_hammer_scale := 0.42

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

	_impact_anchor.position = _impact_position
	_impact_anchor.scale = Vector2.ONE * base_hammer_scale * _layout_scale
	_hammer_sprite.position = Vector2(0, HAMMER_HEAD_CENTER_OFFSET)
	_animation_player.stop()
	_animation_player.play(&"strike")


func _draw() -> void:
	if _burst_amount <= 0.0:
		return

	var alpha := _burst_amount
	var radius := lerpf(28.0, 98.0, 1.0 - alpha) * _layout_scale
	var ring_color := Color(1.0, 0.86, 0.26, 0.82 * alpha)
	var ray_color := Color(1.0, 0.94, 0.58, 0.9 * alpha)
	draw_arc(_impact_position, radius, 0.0, TAU, 48, ring_color, 7.0 * _layout_scale, true)
	draw_arc(_impact_position, radius * 0.58, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.5 * alpha), 4.0 * _layout_scale, true)

	for ray_index in range(BURST_RAY_COUNT):
		var direction := Vector2.RIGHT.rotated(TAU * float(ray_index) / float(BURST_RAY_COUNT))
		var start := _impact_position + direction * (38.0 * _layout_scale)
		var end := _impact_position + direction * (lerpf(74.0, 128.0, 1.0 - alpha) * _layout_scale)
		draw_line(start, end, ray_color, 5.0 * _layout_scale, true)


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
