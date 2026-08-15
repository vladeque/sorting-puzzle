extends SceneTree

## Focused verification for the reusable Lantern Focus Mode overlay and its level integration.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const EFFECT_SCENE_PATH := "res://scenes/abilities/lantern_screen_effect.tscn"
const LEVEL_SCENE_PATH := "res://level.tscn"
const LanternScreenEffectClass := preload("res://scripts/lantern_screen_effect.gd")

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Lantern screen effect verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _verify_effect_scene()
	await _verify_level_integration()
	_finish()


func _verify_effect_scene() -> void:
	var effect := (load(EFFECT_SCENE_PATH) as PackedScene).instantiate() as LanternScreenEffectClass
	root.add_child(effect)
	await process_frame

	var overlay := effect.get_node("Overlay") as Control
	var wash := effect.get_node("Overlay/SearchlightWash") as ColorRect
	var motes := effect.get_node("Overlay/Motes") as CPUParticles2D
	var material := wash.material as ShaderMaterial
	var warm_color: Color = material.get_shader_parameter(&"warm_color")
	var shade_opacity := float(material.get_shader_parameter(&"shade_opacity"))
	var focus_warmth := float(material.get_shader_parameter(&"focus_warmth"))
	_check(effect.layer == 4, "Lantern renders above gameplay and below Freezer/UI layers.")
	_check(not effect.visible, "Lantern overlay starts hidden.")
	_check(
		overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and wash.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The fullscreen Lantern controls ignore gameplay input."
	)
	_check(
		warm_color.r > warm_color.g
		and warm_color.g > warm_color.b
		and shade_opacity >= 0.2
		and focus_warmth >= 0.2,
		"Focus Mode strongly separates the shaded board from warm target pools."
	)
	_check(
		motes.amount >= 18 and motes.amount <= 24 and motes.lifetime >= 4.0,
		"Focus Mode uses a visible but bounded slow-moving mote field."
	)

	effect.apply_layout(Vector2(720.0, 1280.0))
	_check(
		motes.position.is_equal_approx(Vector2(360.0, 640.0))
		and motes.emission_rect_extents.is_equal_approx(Vector2(360.0, 640.0)),
		"The mote field follows the responsive viewport."
	)
	effect.set_target_positions([Vector2(180.0, 320.0), Vector2(540.0, 960.0)])
	var normalized_targets := effect.get_target_positions_normalized()
	_check(
		effect.get_target_count() == 2
		and normalized_targets.size() == 2
		and normalized_targets[0].is_equal_approx(Vector2(0.25, 0.25))
		and normalized_targets[1].is_equal_approx(Vector2(0.75, 0.75)),
		"Target item centers are normalized for the fullscreen focus shader."
	)
	_check(
		motes.emission_rect_extents.x < 360.0
		and motes.emission_rect_extents.y < 640.0,
		"Active target positions concentrate motes around highlighted goods."
	)

	effect.set_active(true)
	await create_timer(0.16).timeout
	var partial_intensity: float = effect.get_effect_intensity()
	var partial_activation: float = effect.get_activation_progress()
	_check(
		effect.visible
		and effect.is_active()
		and motes.emitting
		and partial_intensity > 0.0
		and partial_intensity < 1.0
		and partial_activation > 0.0
		and partial_activation < 1.0,
		"Activation blooms outward while the drifting motes start."
	)

	# Level may refresh active state repeatedly; a repeat must not restart the entrance tween.
	effect.set_active(true)
	await create_timer(0.44).timeout
	_check(
		effect.get_effect_intensity() > 0.99
		and effect.get_activation_progress() > 0.99
		and effect.get_elapsed_seconds() > 0.4,
		"Repeated active updates preserve the completed Focus Mode entrance."
	)
	effect.set_target_positions([])
	_check(
		effect.get_target_count() == 0
		and motes.position.is_equal_approx(Vector2(360.0, 640.0))
		and motes.emission_rect_extents.is_equal_approx(Vector2(360.0, 640.0)),
		"Targetless Lantern returns motes to the full-screen searching state."
	)

	effect.set_active(false)
	await create_timer(effect.fade_duration_seconds + 0.08).timeout
	_check(
		not effect.visible and not effect.is_active() and not motes.emitting,
		"Ending Lantern fades and hides every part of the screen effect."
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

	var effect := level.get_node("LanternScreenEffect") as LanternScreenEffectClass
	var freezer_effect := level.get_node("FreezerScreenEffect") as FreezerScreenEffect
	var ui := level.get_node("UI") as CanvasLayer
	_check(effect != null, "The playable level owns the reusable Lantern screen effect scene.")
	_check(
		effect != null
		and freezer_effect != null
		and effect.layer < freezer_effect.layer
		and freezer_effect.layer < ui.layer,
		"Lantern stays below Freezer cracks and all HUD/modal controls."
	)
	_check(level.call("_use_highlight"), "Lantern starts from an inactive level state.")
	await process_frame
	_check(
		effect != null and effect.is_active() and effect.get_target_count() >= 3,
		"Starting gameplay Lantern tracks highlighted items in Focus Mode."
	)
	level.call("_clear_ability_highlights", true)
	_check(
		effect != null and not effect.visible and not effect.is_active(),
		"An immediate level reset clears every trace of Lantern Focus Mode."
	)
	level.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("Lantern Focus Mode verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
