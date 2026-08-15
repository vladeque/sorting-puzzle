extends RefCounted

## Capture setup for the lives modal's below-cap state opened from the top status widget, driven
## through `scenes/main_menu.tscn` for the same reason as `lives_menu_full_setup.gd`.
##
## This is the state that shows the `GET MORE LIVES` title, so it is also the capture that proves
## the longer title still clears the shell's close action.

const LIVES_WIDGET_PATH := "TopStatusBar/MainMenuTopStatus/LivesWidget"


func setup(scene_root: Node, tree: SceneTree) -> void:
	var progress := scene_root.get_node_or_null("/root/PlayerProgress")
	if progress == null:
		push_error("lives_menu_offer_setup expects the PlayerProgress autoload.")
		return

	progress.reset_progress()
	if not progress.spend_life():
		push_error("lives_menu_offer_setup could not spend a life to reach the below-cap state.")
		return

	var lives_widget := scene_root.get_node_or_null(LIVES_WIDGET_PATH) as Button
	if lives_widget == null:
		push_error("lives_menu_offer_setup could not find a pressable %s." % LIVES_WIDGET_PATH)
		return

	lives_widget.emit_signal("pressed")
	# Let the open fade finish before the first resolution is captured.
	await tree.create_timer(0.4).timeout
