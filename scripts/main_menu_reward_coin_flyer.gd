extends Control

signal coin_arrived
signal animation_finished

const COIN_TEXTURE := preload("res://assets/ui/clover_coin_transparent_96x96.png")
const COIN_SIZE := Vector2(42.0, 42.0)
const FLIGHT_DURATION := 0.68
const MAX_LAUNCH_WINDOW := 1.8
const MIN_STAGGER := 0.002
const MAX_STAGGER := 0.09

var _coins_in_flight := 0
var _is_launching := false


func play(coin_count: int, start_global_position: Vector2, target_global_position: Vector2) -> void:
	if coin_count <= 0 or _is_launching or _coins_in_flight > 0:
		animation_finished.emit()
		return

	_is_launching = true
	var inverse_global_transform := get_global_transform().affine_inverse()
	var start_position: Vector2 = inverse_global_transform * start_global_position
	var target_position: Vector2 = inverse_global_transform * target_global_position
	var stagger := clampf(MAX_LAUNCH_WINDOW / float(coin_count), MIN_STAGGER, MAX_STAGGER)
	for coin_index in range(coin_count):
		_launch_coin(start_position, target_position, coin_index)
		if coin_index < coin_count - 1:
			await get_tree().create_timer(stagger).timeout

	_is_launching = false
	_try_finish_animation()


func _launch_coin(start_position: Vector2, target_position: Vector2, coin_index: int) -> void:
	_coins_in_flight += 1
	var coin := TextureRect.new()
	coin.name = "RewardCoin%03d" % coin_index
	coin.custom_minimum_size = COIN_SIZE
	coin.size = COIN_SIZE
	coin.position = start_position - COIN_SIZE * 0.5
	coin.pivot_offset = COIN_SIZE * 0.5
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.texture = COIN_TEXTURE
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.scale = Vector2(0.45, 0.45)
	coin.modulate.a = 0.0
	add_child(coin)

	var target_top_left := target_position - COIN_SIZE * 0.5
	var horizontal_direction := -1.0 if coin_index % 2 == 0 else 1.0
	var arc_offset := Vector2(horizontal_direction * (24.0 + float(coin_index % 4) * 8.0), -70.0 - float(coin_index % 3) * 14.0)
	var midpoint := start_position.lerp(target_position, 0.48) + arc_offset - COIN_SIZE * 0.5

	var flight_tween := coin.create_tween()
	flight_tween.tween_property(coin, "modulate:a", 1.0, 0.1)
	flight_tween.parallel().tween_property(coin, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flight_tween.tween_property(coin, "position", midpoint, FLIGHT_DURATION * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight_tween.tween_property(coin, "position", target_top_left, FLIGHT_DURATION * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight_tween.parallel().tween_property(coin, "rotation", horizontal_direction * TAU, FLIGHT_DURATION * 0.55)
	flight_tween.tween_property(coin, "scale", Vector2(0.25, 0.25), 0.08)
	flight_tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.08)
	await flight_tween.finished

	coin.queue_free()
	_coins_in_flight -= 1
	coin_arrived.emit()
	_try_finish_animation()


func _try_finish_animation() -> void:
	if not _is_launching and _coins_in_flight <= 0:
		animation_finished.emit()
