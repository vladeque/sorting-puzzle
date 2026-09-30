extends RefCounted

## Main Menu reward-chest opening, a moment after the lid bursts: flash, rays, and confetti. The
## beat is time-sensitive, so capture a single resolution with a short settle:
##
##     & .\scripts\tools\capture_ui.ps1 -Scene scenes/main_menu.tscn -Name chest_burst `
##         -Setup scripts/tools/captures/reward_chest_ceremony_burst_setup.gd `
##         -Resolutions '720x1280' -Settle 1

const SupportScript := preload("res://scripts/tools/captures/reward_chest_ceremony_capture_support.gd")


func setup(scene_root: Node, tree: SceneTree) -> void:
	SupportScript.start(scene_root, {"auto_open_delay": 0.2, "reveal_hold": 999.0})
	await tree.create_timer(0.95).timeout
