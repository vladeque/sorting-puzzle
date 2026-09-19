class_name CollapsingShelfColumn
extends Node2D

## One bottom-to-top pile of shelves in a `collapsing_columns` level (`scenes/collapsing_shelf_column.tscn`).
##
## The column owns placement, the active window, and every shelf movement. `Shelf` keeps owning its
## slots and art, `CollapsingShelfBoard` owns the set of columns, and `scripts/level.gd` decides
## which shelves are empty enough to remove.
##
## Removal is logical first. `remove_shelves()` commits the new order immediately and
## `start_collapse()` only moves visuals toward it, so anything that interrupts the animation --
## a pause, backgrounding, teardown, or `settle_immediately()` -- finds a complete order rather than
## a half-applied one.

## Emitted exactly once per collapse, after every shelf sits at its final row. Also emitted when
## `settle_immediately()` cuts a running collapse short.
signal collapse_settled

const AUTHORED_ID_META := &"collapsing_shelf_id"
## One easing for every column, so parallel collapses read as a single coordinated drop.
const COLLAPSE_TRANSITION := Tween.TRANS_QUAD
const COLLAPSE_EASE := Tween.EASE_IN_OUT

## The emptied shelf shrinks and fades first; only then does the pile above it drop. Keeping the two
## beats separate is what makes a destruction read differently from an ordinary shift.
@export_range(0.0, 1.0, 0.01) var destroy_duration_seconds := 0.14
@export_range(0.0, 1.0, 0.01) var shift_duration_seconds := 0.24
@export_range(0.1, 1.0, 0.01) var destroyed_shelf_end_scale := 0.82

var column_index := 0
var _visible_count := 1
var _shelf_step := Vector2.ZERO
## Surviving shelves, bottom to top. Stack index is the logical row.
var _shelves: Array[Shelf] = []
## Logically removed, still playing their destroy beat.
var _removing: Array[Shelf] = []
## Logically inside the window, still sliding in from above it.
var _entering: Array[Shelf] = []
var _collapse_tween: Tween
var _is_collapsing := false


func configure(index: int, visible_count: int, shelf_step: Vector2) -> void:
	column_index = index
	_visible_count = maxi(visible_count, 1)
	_shelf_step = shelf_step
	_layout_immediately()


func set_visible_count(visible_count: int) -> void:
	_visible_count = maxi(visible_count, 1)
	_layout_immediately()


func get_visible_count() -> int:
	return _visible_count


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


## Commits the new bottom-to-top order and reports which shelves it reveals. Shelves this column
## does not hold -- including ones already removed -- are ignored, so no shelf is destroyed twice,
## and the result does not depend on the order `shelves_to_remove` lists them in.
func remove_shelves(shelves_to_remove: Array) -> Dictionary:
	var removed: Array[Shelf] = []
	var revealed: Array[Shelf] = []
	for shelf in _shelves:
		if shelves_to_remove.has(shelf):
			removed.append(shelf)

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
	# Revealed shelves wait above the window, where the board clips them, and fade in as they drop
	# so none of them flashes into place.
	for shelf in _entering:
		shelf.visible = true
		shelf.modulate.a = 0.0

	var has_tweeners := false
	var tween := create_tween()
	tween.set_trans(COLLAPSE_TRANSITION).set_ease(COLLAPSE_EASE).set_parallel(true)
	if destroy_duration_seconds > 0.0:
		for shelf in _removing:
			tween.tween_property(shelf, "modulate:a", 0.0, destroy_duration_seconds)
			tween.tween_property(
				shelf, "scale", shelf.scale * destroyed_shelf_end_scale, destroy_duration_seconds
			)
			has_tweeners = true
	else:
		for shelf in _removing:
			shelf.visible = false

	var shift_started := false
	if shift_duration_seconds > 0.0:
		for stack_index in range(_shelves.size()):
			var shelf := _shelves[stack_index]
			var destination := get_row_position(stack_index)
			# Shelves still above the window after the drop are invisible; they snap at the end.
			if stack_index >= _visible_count or shelf.position.is_equal_approx(destination):
				continue

			if has_tweeners and not shift_started:
				tween.chain()
			shift_started = true
			has_tweeners = true
			tween.tween_property(shelf, "position", destination, shift_duration_seconds)
			if _entering.has(shelf):
				tween.tween_property(shelf, "modulate:a", 1.0, shift_duration_seconds)

	if not has_tweeners:
		tween.kill()
		_finish_collapse()
		return

	_collapse_tween = tween
	tween.finished.connect(_finish_collapse, CONNECT_ONE_SHOT)


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


## Only shelves inside the window render. The window's top shelf carries the ceiling cap: the pile
## visibly ends at the window edge even when more shelves wait above it, and a hidden shelf above
## must never suppress the cap and leave the top shelf's ceiling exposed.
func _apply_window_state() -> void:
	var window_top_index := mini(_visible_count, _shelves.size()) - 1
	for stack_index in range(_shelves.size()):
		var shelf := _shelves[stack_index]
		shelf.visible = stack_index < _visible_count
		shelf.set_top_ceiling_cap_visible(stack_index == window_top_index)
