extends RefCounted

## Shows the Shop purchase-result dialog with its longest production title, so the capture proves
## the awning plate shrinks to fit. Set `SORTING_PUZZLE_CAPTURE_PURCHASE_TITLE` to review another.

const DEFAULT_TITLE := "Purchase unavailable"


func setup(scene_root: Node, tree: SceneTree) -> void:
	var title := OS.get_environment("SORTING_PUZZLE_CAPTURE_PURCHASE_TITLE")
	scene_root.call(
		"show_result",
		title if not title.is_empty() else DEFAULT_TITLE,
		"The purchase could not be completed."
	)
	await tree.create_timer(0.4).timeout
	for _frame in range(2):
		await tree.process_frame
