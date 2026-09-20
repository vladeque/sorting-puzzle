extends RefCounted

## Capture setup for `level.tscn`: a collapsing-columns board as a player first sees it, with the
## window each resolution resolves for itself. Hidden shelves wait above the window at every size.
##
## Captures the development fixture by default, or a campaign level when
## `SORTING_PUZZLE_CAPTURE_COLLAPSE_LEVEL` names one.
##
## ```powershell
## & .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name collapsing_columns_initial -Position '0,0' `
##     -Settle 30 -Setup scripts/tools/captures/collapsing_columns_initial_setup.gd
## ```

const Support := preload("res://scripts/tools/captures/collapsing_columns_capture_support.gd")

var _level: Node
var _tree: SceneTree


func setup(scene_root: Node, tree: SceneTree) -> void:
	_level = scene_root
	_tree = tree
	Support.keep_alive(scene_root, self)
	tree.root.size_changed.connect(_rebuild)
	await _rebuild()


func _rebuild() -> void:
	if Support.build(_level, 0, false, true) == null:
		return
	await Support.settle(_level, _tree)
