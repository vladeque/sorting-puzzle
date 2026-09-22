extends RefCounted

## Capture setup for `level.tscn`: a collapsing-columns board whose middle column has fallen below
## both neighbors. Its top shelf carries a ceiling cap right where the taller neighbors' shared walls
## run past it, so this is the view for checking that the cap tucks under those walls.
##
## ```powershell
## & .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name collapsing_columns_uneven -Position '0,0' `
##     -Settle 30 -Setup scripts/tools/captures/collapsing_columns_uneven_setup.gd
## ```

const Support := preload("res://scripts/tools/captures/collapsing_columns_capture_support.gd")
## The kept floor (`CollapsingColumnRules.KEPT_SHELVES_PER_COLUMN`), which is below the authored
## window, so the middle column visibly ends below its neighbors. The board never goes lower.
const MIDDLE_COLUMN_SHELVES_LEFT := CollapsingColumnRules.KEPT_SHELVES_PER_COLUMN

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

	# Straight through the board, not through play: only the resulting silhouette matters here.
	var middle_shelves := board.get_column(1).get_shelves()
	await board.collapse_shelves(
		middle_shelves.slice(0, maxi(middle_shelves.size() - MIDDLE_COLUMN_SHELVES_LEFT, 0))
	)
	_level.call("_collect_slots")
	await Support.settle(_level, _tree)
