extends RefCounted

## Capture setup for `level.tscn`: the collapsing-columns fixture part-way through its proven
## solution, so columns of different heights, revealed shelves, and the moved-down caps can be
## reviewed. The window is pinned to the authored four shelves the solution was proven against.
##
## ```powershell
## & .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name collapsing_columns_progress -Position '0,0' `
##     -Settle 90 -Setup scripts/tools/captures/collapsing_columns_progress_setup.gd
## ```

const Support := preload("res://scripts/tools/captures/collapsing_columns_capture_support.gd")
const MOVES_PLAYED := 12

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
	await Support.replay(_level, _tree, board, MOVES_PLAYED)
