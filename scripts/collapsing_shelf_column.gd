class_name CollapsingShelfColumn
extends Node2D

## One bottom-to-top pile of shelves in a `collapsing_columns` level (`scenes/collapsing_shelf_column.tscn`).
##
## The column owns placement, the active window, the rows that peek over it, and every shelf
## movement. `Shelf` keeps owning its slots and art, `CollapsingShelfBoard` owns the set of columns
## and how deep its clip window opens, and `scripts/level.gd` decides which shelves are empty enough
## to remove.
##
## Removal is logical first. `remove_shelves()` commits the new order immediately and
## `start_collapse()` only moves visuals toward it, so anything that interrupts the animation --
## a pause, backgrounding, teardown, or `settle_immediately()` -- finds a complete order rather than
## a half-applied one.

## Emitted exactly once per collapse, after every shelf sits at its final row. Also emitted when
## `settle_immediately()` cuts a running collapse short.
signal collapse_settled

const AUTHORED_ID_META := &"collapsing_shelf_id"
const DESTRUCTION_EFFECT_SCENE := preload("res://scenes/effects/shelf_destruction_effect.tscn")

## The wood snap leads the fall, then overlaps its opening frames so the column responds without a
## dead beat. Survivors accelerate down and finish with a restrained contact rebound.
@export_range(0.0, 1.0, 0.01) var destroy_duration_seconds := 0.18
@export_range(0.0, 1.0, 0.01) var shift_duration_seconds := 0.24
@export_range(0.0, 0.25, 0.01) var shift_overlap_seconds := 0.04
@export_range(0.0, 12.0, 0.5) var landing_overshoot := 4.0
@export_range(0.0, 8.0, 0.5) var landing_rebound := 1.5

var column_index := 0
var _visible_count := 1
## Shelves this column never drops below; see `CollapsingColumnRules.KEPT_SHELVES_PER_COLUMN`.
var _kept_count := 0
## Shelves rendered above the window, cut off by the board's clip edge. Presentation only.
var _peek_row_count := 0
var _shelf_step := Vector2.ZERO
## Surviving shelves, bottom to top. Stack index is the logical row.
var _shelves: Array[Shelf] = []
## Logically removed, still playing their destroy beat.
var _removing: Array[Shelf] = []
## Logically inside the window, still sliding in from above it.
var _entering: Array[Shelf] = []
var _collapse_tween: Tween
var _is_collapsing := false
var _destruction_effects: Array[Node] = []


func configure(index: int, visible_count: int, shelf_step: Vector2, kept_count := 0) -> void:
	column_index = index
	_visible_count = maxi(visible_count, 1)
	_shelf_step = shelf_step
	_kept_count = maxi(kept_count, 0)
	_layout_immediately()


func get_kept_count() -> int:
	return _kept_count


func set_visible_count(visible_count: int) -> void:
	_visible_count = maxi(visible_count, 1)
	_layout_immediately()


func get_visible_count() -> int:
	return _visible_count


## How many shelves above the window draw into the board's peek strip. They are rendered, never
## playable: `_visible_count` alone decides that, and a peeking shelf sits outside it.
func set_peek_row_count(count: int) -> void:
	_peek_row_count = maxi(count, 0)
	_apply_window_state()


## Shelves that currently render: the window, plus whatever peeks over it.
func get_render_count() -> int:
	return mini(_visible_count + _peek_row_count, _shelves.size())


## Shelves are stacked in the order they are added, so callers add them bottom to top. The authored
## ID travels with the node and never changes, however far the shelf later falls.
func add_shelf(shelf: Shelf, authored_shelf_id: int) -> void:
	if shelf == null or _shelves.has(shelf):
		return

	if shelf.get_parent() == null:
		add_child(shelf)
	elif shelf.get_parent() != self:
		shelf.reparent(self, false)

	shelf.set_meta(AUTHORED_ID_META, authored_shelf_id)
	_shelves.append(shelf)
	_layout_immediately()


## Absolute destination for a logical row, counted upward from the column base. Every movement
## targets this instead of adding relative offsets, so repeated collapses cannot drift.
func get_row_position(row: int) -> Vector2:
	return Vector2(0.0, -float(row) * _shelf_step.y)


func get_shelf_count() -> int:
	return _shelves.size()


func get_shelves() -> Array[Shelf]:
	return _shelves.duplicate()


func has_shelf(shelf: Node) -> bool:
	return shelf is Shelf and _shelves.has(shelf)


func get_stack_index(shelf: Node) -> int:
	if not shelf is Shelf:
		return -1

	return _shelves.find(shelf)


func get_active_shelves() -> Array[Shelf]:
	var active: Array[Shelf] = []
	for stack_index in range(mini(_visible_count, _shelves.size())):
		var shelf := _shelves[stack_index]
		if not _entering.has(shelf):
			active.append(shelf)

	return active


## Inside the window and finished arriving. A shelf still sliding in is not playable yet.
func is_shelf_active(shelf: Node) -> bool:
	var stack_index := get_stack_index(shelf)
	return stack_index >= 0 and stack_index < _visible_count and not _entering.has(shelf)


func is_collapsing() -> bool:
	return _is_collapsing


## The candidates this column may actually destroy: those it holds, lowest first, for as long as it
## stays at least `_kept_count` tall. The rest stay as ordinary empty shelves. Bottom-up matches the
## scan `CollapsingColumnsRules.settle()` in `scripts/tools/validate_level_solvable.py` uses.
func get_removable_shelves(candidates: Array) -> Array[Shelf]:
	var removable: Array[Shelf] = []
	var may_remove := maxi(_shelves.size() - _kept_count, 0)
	for shelf in _shelves:
		if removable.size() >= may_remove:
			break
		if candidates.has(shelf):
			removable.append(shelf)

	return removable


## Commits the new bottom-to-top order and reports which shelves it reveals. Shelves this column
## does not hold -- including ones already removed -- are ignored, so no shelf is destroyed twice,
## and the result does not depend on the order `shelves_to_remove` lists them in. A column never
## drops below its kept count; see `get_removable_shelves()`.
func remove_shelves(shelves_to_remove: Array) -> Dictionary:
	var removed := get_removable_shelves(shelves_to_remove)
	var revealed: Array[Shelf] = []

	if removed.is_empty():
		return {"removed": removed, "revealed": revealed}

	# A second batch before the first finished would animate from a stale layout. The level
	# serializes collapses, so this only guards against misuse.
	if _is_collapsing:
		settle_immediately()

	var previously_hidden: Array[Shelf] = []
	for stack_index in range(_visible_count, _shelves.size()):
		previously_hidden.append(_shelves[stack_index])

	for shelf in removed:
		_shelves.erase(shelf)

	for stack_index in range(mini(_visible_count, _shelves.size())):
		var shelf := _shelves[stack_index]
		if previously_hidden.has(shelf):
			revealed.append(shelf)

	_removing = removed.duplicate()
	_entering = revealed.duplicate()
	_is_collapsing = true
	return {"removed": removed, "revealed": revealed}


## Plays the pending collapse without blocking. `collapse_settled` fires when it ends -- straight away
## when both durations are zero, which is the deterministic path setup and tests rely on.
func start_collapse() -> void:
	if not _is_collapsing:
		return

	_apply_window_state()
	# Revealed shelves wait above the window and enter through its clip edge. Keeping them opaque
	# makes them read as physical shelves descending into view instead of ghosting into existence.
	for shelf in _entering:
		shelf.visible = true
		shelf.modulate.a = 1.0

	var has_tweeners := false
	var tween := create_tween()
	tween.set_parallel(true)
	if destroy_duration_seconds > 0.0:
		for shelf in _removing:
			var effect = DESTRUCTION_EFFECT_SCENE.instantiate()
			effect.name = "ShelfDestructionEffect_%s" % get_authored_shelf_id(shelf)
			effect.position = shelf.position
			effect.scale = shelf.scale
			add_child(effect)
			_destruction_effects.append(effect)
			var break_direction := -1.0 if column_index % 2 == 0 else 1.0
			effect.add_to_tween(tween, shelf, destroy_duration_seconds, break_direction)
			has_tweeners = true
	else:
		for shelf in _removing:
			shelf.visible = false

	if shift_duration_seconds > 0.0:
		var shift_delay := get_shift_start_delay()
		var fall_duration := shift_duration_seconds * 0.76
		var rebound_duration := shift_duration_seconds * 0.10
		var settle_duration := shift_duration_seconds - fall_duration - rebound_duration
		var render_count := get_render_count()
		for stack_index in range(_shelves.size()):
			var shelf := _shelves[stack_index]
			var destination := get_row_position(stack_index)
			# Shelves that stay out of sight after the drop are invisible; they snap at the end. A
			# shelf falling into the peek strip is on screen, so it animates like any other.
			if stack_index >= render_count or shelf.position.is_equal_approx(destination):
				continue

			has_tweeners = true
			var overshoot_position := destination + Vector2(0.0, landing_overshoot)
			var rebound_position := destination - Vector2(0.0, landing_rebound)
			tween.tween_property(shelf, "position", overshoot_position, fall_duration) \
				.set_delay(shift_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(shelf, "position", rebound_position, rebound_duration) \
				.set_delay(shift_delay + fall_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(shelf, "position", destination, settle_duration) \
				.set_delay(shift_delay + fall_duration + rebound_duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	if not has_tweeners:
		tween.kill()
		_finish_collapse()
		return

	_collapse_tween = tween
	tween.finished.connect(_finish_collapse, CONNECT_ONE_SHOT)


func get_shift_start_delay() -> float:
	return maxf(destroy_duration_seconds - minf(shift_overlap_seconds, destroy_duration_seconds), 0.0)


func get_authored_shelf_id(shelf: Shelf) -> int:
	return int(shelf.get_meta(AUTHORED_ID_META, -1)) if shelf != null else -1


## Deterministic, animation-free settle for setup, tests, and teardown. Completes a running
## collapse in place, so input can never stay locked behind an animation that will not finish.
func settle_immediately() -> void:
	if _is_collapsing:
		_finish_collapse()
	else:
		_layout_immediately()


func _finish_collapse() -> void:
	if not _is_collapsing:
		return

	if _collapse_tween != null:
		if _collapse_tween.is_valid():
			_collapse_tween.kill()
		_collapse_tween = null

	for effect in _destruction_effects:
		if effect != null and is_instance_valid(effect):
			if effect.get_parent() == self:
				remove_child(effect)
			effect.queue_free()
	_destruction_effects.clear()

	# Out of the tree at once, not merely queued: the level's recursive shelf discovery must never
	# find a destroyed shelf in the frame before it is actually freed.
	for shelf in _removing:
		if shelf != null and is_instance_valid(shelf):
			if shelf.get_parent() == self:
				remove_child(shelf)
			shelf.queue_free()
	_removing.clear()

	for shelf in _entering:
		if shelf != null and is_instance_valid(shelf):
			shelf.modulate.a = 1.0
	_entering.clear()

	_is_collapsing = false
	_layout_immediately()
	collapse_settled.emit()


func _layout_immediately() -> void:
	for stack_index in range(_shelves.size()):
		var shelf := _shelves[stack_index]
		shelf.position = get_row_position(stack_index)

	_apply_window_state()


## The window and the board's peek rows render; everything deeper in the stack stays hidden. The
## topmost rendered shelf carries the ceiling cap, so a column that really ends here visibly ends,
## while one that continues keeps its cap above the clip edge, out of sight. The cap draws beneath
## every shelf wall and floor, so a column shorter than its neighbors tucks its cap under their
## shared walls instead of painting over them.
func _apply_window_state() -> void:
	var render_count := get_render_count()
	for stack_index in range(_shelves.size()):
		var shelf := _shelves[stack_index]
		shelf.visible = stack_index < render_count
		shelf.set_top_ceiling_cap_visible(stack_index == render_count - 1)
