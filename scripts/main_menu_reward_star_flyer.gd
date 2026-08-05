extends Control

## Flies earned reward stars from the background house marker into the reward chest and advances
## its progress on each arrival. Renamed from "coin flyer" (UI-002): this always represents earned
## stars, never spendable coins, so it now uses the shared reward-star art instead of clover-coin
## art -- see docs/SCENES.md's "Reward-Progress Semantics" for the presentation rule this exists to
## keep correct. Presentation only; reward-chest thresholds, goals, and saved progress stay owned
## by PlayerProgress and scripts/production_main_menu.gd.

signal star_arrived
signal animation_finished

const STAR_TEXTURE := preload("res://assets/ui/reward_star_84x84.png")
const STAR_SIZE := Vector2(42.0, 42.0)
const FLIGHT_DURATION := 0.68
const MAX_LAUNCH_WINDOW := 1.8
const MIN_STAGGER := 0.002
const MAX_STAGGER := 0.09

var _stars_in_flight := 0
var _is_launching := false


func play(star_count: int, start_global_position: Vector2, target_global_position: Vector2) -> void:
	if star_count <= 0 or _is_launching or _stars_in_flight > 0:
		animation_finished.emit()
		return

	_is_launching = true
	var inverse_global_transform := get_global_transform().affine_inverse()
	var start_position: Vector2 = inverse_global_transform * start_global_position
	var target_position: Vector2 = inverse_global_transform * target_global_position
	var stagger := clampf(MAX_LAUNCH_WINDOW / float(star_count), MIN_STAGGER, MAX_STAGGER)
	for star_index in range(star_count):
		_launch_star(start_position, target_position, star_index)
		if star_index < star_count - 1:
			await get_tree().create_timer(stagger).timeout

	_is_launching = false
	_try_finish_animation()


func _launch_star(start_position: Vector2, target_position: Vector2, star_index: int) -> void:
	_stars_in_flight += 1
	var star := TextureRect.new()
	star.name = "RewardStar%03d" % star_index
	star.custom_minimum_size = STAR_SIZE
	star.size = STAR_SIZE
	star.position = start_position - STAR_SIZE * 0.5
	star.pivot_offset = STAR_SIZE * 0.5
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.texture = STAR_TEXTURE
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.scale = Vector2(0.45, 0.45)
	star.modulate.a = 0.0
	add_child(star)

	var target_top_left := target_position - STAR_SIZE * 0.5
	var horizontal_direction := -1.0 if star_index % 2 == 0 else 1.0
	var arc_offset := Vector2(horizontal_direction * (24.0 + float(star_index % 4) * 8.0), -70.0 - float(star_index % 3) * 14.0)
	var midpoint := start_position.lerp(target_position, 0.48) + arc_offset - STAR_SIZE * 0.5

	var flight_tween := star.create_tween()
	flight_tween.tween_property(star, "modulate:a", 1.0, 0.1)
	flight_tween.parallel().tween_property(star, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flight_tween.tween_property(star, "position", midpoint, FLIGHT_DURATION * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight_tween.tween_property(star, "position", target_top_left, FLIGHT_DURATION * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight_tween.parallel().tween_property(star, "rotation", horizontal_direction * TAU, FLIGHT_DURATION * 0.55)
	flight_tween.tween_property(star, "scale", Vector2(0.25, 0.25), 0.08)
	flight_tween.parallel().tween_property(star, "modulate:a", 0.0, 0.08)
	await flight_tween.finished

	star.queue_free()
	_stars_in_flight -= 1
	star_arrived.emit()
	_try_finish_animation()


func _try_finish_animation() -> void:
	if not _is_launching and _stars_in_flight <= 0:
		animation_finished.emit()
