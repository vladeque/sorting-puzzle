extends RefCounted

## Capture setup for the lives modal's full-lives state, driven through `scenes/main_menu.tscn`.
##
## The modal starts hidden and is positioned by the Main Menu's own `apply_safe_layout()` pass, so a
## bare instance would render neither the real safe-area fit nor the top status bar the widget lives
## in. Capturing the whole Main Menu instead keeps the menu's `size_changed` layout pass in the loop
## at every captured resolution.

const LIVES_WIDGET_PATH := "TopStatusBar/MainMenuTopStatus/LivesWidget"


func setup(scene_root: Node, tree: SceneTree) -> void:
	var progress := scene_root.get_node_or_null("/root/PlayerProgress")
	if progress == null:
		push_error("lives_menu_full_setup expects the PlayerProgress autoload.")
		return

	progress.reset_progress()
	_open_lives_modal(scene_root, tree)
	# Let the open fade finish before the first resolution is captured.
	await tree.create_timer(0.4).timeout


func _open_lives_modal(scene_root: Node, _tree: SceneTree) -> void:
	var lives_widget := scene_root.get_node_or_null(LIVES_WIDGET_PATH) as Button
	if lives_widget == null:
		push_error("lives_menu_full_setup could not find a pressable %s." % LIVES_WIDGET_PATH)
		return
	lives_widget.emit_signal("pressed")
