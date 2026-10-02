extends RefCounted

## GAME-012: scrolls Support to the end of its FAQ list so the Account section and its deletion
## action are in view for responsive review.
##
##   & .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/support_screen.tscn -Name support_account `
##       -Setup scripts/tools/captures/support_account_action_setup.gd


func setup(scene_root: Node, tree: SceneTree) -> void:
	for _frame in range(3):
		await tree.process_frame
	var scroll := scene_root.get_node_or_null(
		"ContentMargin/ContentStack/FaqPanel/FaqScroll"
	) as ScrollContainer
	if scroll == null:
		push_error("support_account_action_setup could not find the FAQ scroll.")
		return
	# Re-scroll after every resize, since the harness captures each resolution in turn.
	var scroll_to_end := func() -> void:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	scene_root.get_viewport().size_changed.connect(func() -> void: scroll_to_end.call_deferred())
	scroll_to_end.call()
	for _frame in range(2):
		await tree.process_frame
