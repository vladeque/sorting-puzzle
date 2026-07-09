class_name HammerImpactEffect
extends Control

signal impact
signal finished

const DESIGN_WIDTH := 720.0
const HAMMER_HEAD_CENTER_OFFSET := 364.0
const WIND_UP_OFFSET := Vector2(156, -268)
const READY_OFFSET := Vector2(68, -152)
const RECOVER_OFFSET := Vector2(86, -236)
const BURST_RAY_COUNT := 10

@export_range(0.1, 1.0, 0.01) var base_hammer_scale := 0.42
@export_range(0.0, 1.0, 0.01) var appear_seconds := 0.16
@export_range(0.0, 1.0, 0.01) var strike_seconds := 0.11
@export_range(0.0, 1.0, 0.01) var rebound_seconds := 0.08
@export_range(0.0, 1.0, 0.01) var recover_seconds := 0.2

@onready var _hammer_pivot: Node2D = %HammerPivot
@onready var _hammer_sprite: Sprite2D = %HammerSprite

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
	modulate = Color(1, 1, 1, 0)
	_burst_amount = 0.0

	var hammer_scale := Vector2.ONE * base_hammer_scale * _layout_scale
	_hammer_pivot.position = _impact_position + WIND_UP_OFFSET * _layout_scale
	_hammer_pivot.rotation = deg_to_rad(-34.0)
	_hammer_pivot.scale = hammer_scale * 0.82
	_hammer_sprite.position = Vector2(0, HAMMER_HEAD_CENTER_OFFSET)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color.WHITE, appear_seconds)
	tween.tween_property(_hammer_pivot, "position", _impact_position + READY_OFFSET * _layout_scale, appear_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hammer_pivot, "rotation", deg_to_rad(-18.0), appear_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hammer_pivot, "scale", hammer_scale * 1.08, appear_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.04)
	tween.chain().set_parallel(true)
	tween.tween_property(_hammer_pivot, "position", _impact_position, strike_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_hammer_pivot, "rotation", deg_to_rad(7.0), strike_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_hammer_pivot, "scale", hammer_scale * 1.18, strike_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_emit_impact)
	tween.chain().set_parallel(true)
	tween.tween_property(_hammer_pivot, "position", _impact_position + Vector2(-10, 12) * _layout_scale, rebound_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hammer_pivot, "rotation", deg_to_rad(-4.0), rebound_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hammer_pivot, "scale", hammer_scale * 1.04, rebound_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), recover_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_hammer_pivot, "position", _impact_position + RECOVER_OFFSET * _layout_scale, recover_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_hammer_pivot, "rotation", deg_to_rad(24.0), recover_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_hammer_pivot, "scale", hammer_scale * 0.92, recover_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_emit_finished)


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
	_play_burst()


func _emit_finished() -> void:
	visible = false
	finished.emit()


func _play_burst() -> void:
	_burst_amount = 1.0
	var burst_tween := create_tween()
	burst_tween.tween_property(self, "_burst_amount", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_full_rect() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
