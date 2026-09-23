class_name ThrowingDispenserRack
extends Node2D

## Owns where the level's dispensers sit and reports the space they need.
##
## It exists for the same reason `CollapsingShelfBoard` does: the mode needs a container the level's
## responsive fit can ask for one set of bounds, instead of `scripts/level.gd` growing per-dispenser
## placement maths. It is a child of `Shelves`, so it scales and centers with the board and never
## drifts away from it on a different screen.
##
## Dispensers are spaced evenly above the board rather than placed from authored markers. "Above the
## shelves" is the whole placement rule, and authoring it per layout would mean a new
## `scenes/layouts/layout_*.tscn` for every preset crossed with every dispenser count, none of which
## would say anything the spacing does not.

signal throw_requested(dispenser: ThrowingDispenser)

const DISPENSER_SCENE := preload("res://scenes/throwing_dispenser.tscn")

## Clearance between the lowest point of a dispenser and the top of the board. Enough that the chute
## reads as pouring onto the shelves rather than resting on them.
const BOARD_CLEARANCE := 26.0

## Minimum horizontal gap between two dispensers, so a level with several does not read as one wide
## fixture. Spacing above this is spare width and gets shared out evenly.
const MIN_DISPENSER_GAP := 24.0

var _dispensers: Array[ThrowingDispenser] = []
var _layout_bounds := Rect2()
var _input_enabled := true


## `board_bounds` is the shelf board's local rect inside the shared `Shelves` parent, so the rack
## lands directly above whatever layout preset the level chose.
func configure(dispenser_configs: Array, board_bounds: Rect2) -> void:
	_clear()

	for dispenser_index in range(dispenser_configs.size()):
		var dispenser_config := dispenser_configs[dispenser_index] as Dictionary
		if dispenser_config == null:
			continue

		var dispenser := DISPENSER_SCENE.instantiate() as ThrowingDispenser
		dispenser.name = "Dispenser%02d" % (dispenser_index + 1)
		add_child(dispenser)
		dispenser.configure(
			ThrowingDispenserRules.get_contents(dispenser_config),
			ThrowingDispenserRules.get_throw_count(dispenser_config)
		)
		dispenser.throw_requested.connect(_on_dispenser_throw_requested.bind(dispenser))
		_dispensers.append(dispenser)

	_place_dispensers(board_bounds)


func get_dispensers() -> Array[ThrowingDispenser]:
	return _dispensers


func get_remaining_count() -> int:
	var remaining := 0
	for dispenser in _dispensers:
		remaining += dispenser.get_remaining_count()

	return remaining


func is_empty() -> bool:
	return get_remaining_count() == 0


## The rack's own local rect, unioned from every dispenser's drawing bounds. `scripts/level.gd` adds
## this to the board's bounds when it fits the level to the screen, so a dispenser can never be
## pushed off the top on a short viewport.
func get_layout_bounds() -> Rect2:
	return _layout_bounds


## The level refreshes this every frame, so it stops at the first unchanged call rather than walking
## the dispensers to tell each of them what it already knows.
func set_input_enabled(enabled: bool) -> void:
	if enabled == _input_enabled:
		return

	_input_enabled = enabled
	for dispenser in _dispensers:
		dispenser.set_input_enabled(enabled)


func _place_dispensers(board_bounds: Rect2) -> void:
	_layout_bounds = Rect2()
	if _dispensers.is_empty():
		return

	var bounds := ThrowingDispenser.VISUAL_BOUNDS
	var count := _dispensers.size()
	# Spread across the board's width where there is room, and fall back to the minimum gap when
	# there is not, so a wide rack keeps its dispensers over the shelves they feed.
	var step := maxf(bounds.size.x + MIN_DISPENSER_GAP, 0.0)
	if count > 1:
		step = maxf(step, (board_bounds.size.x - bounds.size.x) / float(count - 1))

	var row_width := step * float(count - 1)
	var first_x := board_bounds.position.x + board_bounds.size.x * 0.5 - row_width * 0.5
	# `bounds.end.y` is the lowest drawn point, so this hangs the whole rack above the board rather
	# than aligning origins and letting the chute overlap the top row.
	var row_y := board_bounds.position.y - BOARD_CLEARANCE - bounds.end.y

	for dispenser_index in range(count):
		var dispenser := _dispensers[dispenser_index]
		dispenser.position = Vector2(first_x + step * float(dispenser_index), row_y)
		var dispenser_rect := Rect2(dispenser.position + bounds.position, bounds.size)
		_layout_bounds = dispenser_rect if dispenser_index == 0 else _layout_bounds.merge(dispenser_rect)


func _on_dispenser_throw_requested(dispenser: ThrowingDispenser) -> void:
	throw_requested.emit(dispenser)


func _clear() -> void:
	for dispenser in _dispensers:
		dispenser.queue_free()

	_dispensers.clear()
	_layout_bounds = Rect2()
