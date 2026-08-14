extends SceneTree

## Focused verification for the reusable Freezer screen overlay and its level integration.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const EFFECT_SCENE_PATH := "res://scenes/abilities/freezer_screen_effect.tscn"
const LEVEL_SCENE_PATH := "res://level.tscn"

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Freezer screen effect verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _verify_effect_scene()
	await _verify_level_integration()
	_finish()


func _verify_effect_scene() -> void:
	var effect := (load(EFFECT_SCENE_PATH) as PackedScene).instantiate() as FreezerScreenEffect
	root.add_child(effect)
	await process_frame

	var overlay := effect.get_node("Overlay") as Control
	var ice_frame := effect.get_node("Overlay/IceFrame") as TextureRect
	_check(effect.layer == 5, "Freezer renders between gameplay and the layer-10 HUD.")
	_check(not effect.visible, "Freezer overlay starts hidden.")
	_check(
		overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ice_frame.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Every fullscreen Freezer control ignores gameplay input."
	)

	effect.set_active(true)
	await create_timer(0.18).timeout
	var partial_reveal := effect.get_reveal_amount()
	_check(
		effect.visible and effect.is_active() and partial_reveal > 0.0 and partial_reveal < 1.0,
		"Activation grows the cracks inward from the viewport edges."
	)

	# Level refreshes the active state every frame; a repeat must not restart the entrance tween.
	effect.set_active(true)
	await create_timer(0.32).timeout
	_check(
		effect.get_reveal_amount() > 0.99 and effect.get_effect_opacity() > 0.99,
		"Repeated active updates do not restart the Freezer entrance."
	)

	effect.set_active(false)
	await create_timer(effect.thaw_duration_seconds + 0.08).timeout
	_check(
		not effect.visible and not effect.is_active(),
		"Thawing removes and hides the overlay after its exit transition."
	)
	effect.queue_free()
	await process_frame


func _verify_level_integration() -> void:
	var level := (load(LEVEL_SCENE_PATH) as PackedScene).instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 2)
	root.add_child(level)
	await process_frame
	await process_frame

	var effect := level.get_node("FreezerScreenEffect") as FreezerScreenEffect
	var ui := level.get_node("UI") as CanvasLayer
	_check(effect != null, "The playable level owns the reusable Freezer screen effect scene.")
	_check(
		effect != null and effect.layer < ui.layer,
		"The cracked ice stays below HUD buttons and gameplay modals."
	)
	_check(level.call("_use_freezer"), "The Freezer ability starts from an inactive level state.")
	await process_frame
	_check(
		effect != null and effect.is_active(),
		"Starting the gameplay Freezer also starts its screen effect."
	)

	level.set("_freezer_time_remaining", 0.0)
	level.call("_update_freezer_visuals", true)
	_check(
		effect != null and not effect.visible and not effect.is_active(),
		"An immediate level reset clears every trace of the screen effect."
	)
	level.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("Freezer screen effect verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
