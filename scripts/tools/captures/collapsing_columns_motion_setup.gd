extends RefCounted

## Capture setup for `level.tscn`: freezes a collapse part-way through its downward shift, to check
## that a revealed shelf enters from above the window -- clipped at the top row's cap and fading in
## -- rather than appearing in place, and that shelves below the removed one have not moved.
##
## `SORTING_PUZZLE_CAPTURE_COLLAPSE_PROGRESS` picks how far into the shift to freeze (0-1, default
## 0.5). The collapse is advanced with `Tween.custom_step()`, so the frame is identical at every
## resolution rather than wherever real time happened to leave it.
##
## ```powershell
## & .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name collapsing_columns_motion -Position '0,0' `
##     -Settle 120 -Setup scripts/tools/captures/collapsing_columns_motion_setup.gd
## ```

const Support := preload("res://scripts/tools/captures/collapsing_columns_capture_support.gd")
const PROGRESS_ENVIRONMENT_VARIABLE := "SORTING_PUZZLE_CAPTURE_COLLAPSE_PROGRESS"
const MOVES_BEFORE_FREEZE := 10
const DESTROY_SECONDS := 0.2
const SHIFT_SECONDS := 0.8

var _level: Node
var _tree: SceneTree


func setup(scene_root: Node, tree: SceneTree) -> void:
	_level = scene_root
	_tree = tree
	Support.keep_alive(scene_root, self)
	tree.root.size_changed.connect(_rebuild)
	await _rebuild()


func _rebuild() -> void:
	var board := Support.build(_level, Support.AUTHORED_WINDOW, false)
	if board == null:
		return
	await Support.settle(_level, _tree)
	await Support.replay(_level, _tree, board, MOVES_BEFORE_FREEZE)

	board.destroy_duration_seconds = DESTROY_SECONDS
	board.shift_duration_seconds = SHIFT_SECONDS
	for move_index in range(MOVES_BEFORE_FREEZE, Support.SOLUTION_PREFIX.size()):
		if not Support.play_move(_level, board, Support.SOLUTION_PREFIX[move_index]):
			return
		for _frame in range(30):
			if board.is_collapsing():
				_freeze(board)
				return
			await _tree.process_frame
		await Support.settle(_level, _tree)

	push_error("No recorded move started a collapse to freeze.")


func _freeze(board: CollapsingShelfBoard) -> void:
	var raw_progress := OS.get_environment(PROGRESS_ENVIRONMENT_VARIABLE).strip_edges()
	var progress := 0.5 if raw_progress.is_empty() else clampf(raw_progress.to_float(), 0.0, 1.0)
	var target_seconds := DESTROY_SECONDS + SHIFT_SECONDS * progress
	for column_index in range(board.get_column_count()):
		var tween := board.get_column(column_index).get("_collapse_tween") as Tween
		if tween == null or not tween.is_valid():
			continue
		tween.pause()
		tween.custom_step(maxf(target_seconds - tween.get_total_elapsed_time(), 0.0))
