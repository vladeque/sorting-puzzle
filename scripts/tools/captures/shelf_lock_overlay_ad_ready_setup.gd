extends RefCounted

## Capture setup for ADS-006's tappable locked-shelf state.
##
## Same locked overlay as `shelf_lock_overlay_setup.gd`, but with the rewarded plate offered, which
## is what distinguishes an actionable `AD` plate from the decorative one shown when the placement
## is unavailable. The idle pulse is sampled at its widest point so the two states are comparable
## in a still capture.

const REMAINING_CLEARS := 3
## ShelfLockOverlay.AD_PLATE_PULSE_SECONDS: one full ease-in-out to the pulse's peak scale.
const PULSE_PEAK_SECONDS := 0.62


func setup(scene_root: Node, tree: SceneTree) -> void:
	var overlay := scene_root as ShelfLockOverlay
	if overlay == null:
		push_error("shelf_lock_overlay_ad_ready_setup expects a ShelfLockOverlay scene root.")
		return

	overlay.show_locked(REMAINING_CLEARS)
	overlay.set_ad_unlock_available(true)
	await tree.create_timer(PULSE_PEAK_SECONDS).timeout
	await tree.process_frame
