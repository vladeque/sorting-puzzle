extends RefCounted

## Capture setup for `scenes/ui/shelf_lock_overlay.tscn`.
##
## The overlay starts hidden and is driven by `scripts/level.gd` at runtime, so a bare instance
## renders nothing. This puts it into its locked state with a countdown still remaining, which is the
## state where chain geometry, wall attachment, lock, and badge are all visible at once.

const REMAINING_CLEARS := 3


func setup(scene_root: Node, tree: SceneTree) -> void:
	var overlay := scene_root as ShelfLockOverlay
	if overlay == null:
		push_error("shelf_lock_overlay_setup expects a ShelfLockOverlay scene root.")
		return
	overlay.show_locked(REMAINING_CLEARS)
	# Let the layout pass and the badge settle before the first resolution is captured.
	await tree.process_frame
	await tree.process_frame
