extends SceneTree

## Focused verification for the reusable Freezer screen overlay and its level integration.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const EFFECT_SCENE_PATH := "res://scenes/abilities/freezer_screen_effect.tscn"
const LEVEL_SCENE_PATH := "res://level.tscn"
const FreezerSnowflakeFieldScript := preload("res://scripts/freezer_snowflake_field.gd")

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
	var edge_glow := effect.get_node("Overlay/EdgeGlow") as ColorRect
	var snowflake_field := effect.get_node("Overlay/SnowflakeField") as FreezerSnowflakeFieldScript
	var hud_overlay_layer := effect.get_node("HudOverlayLayer") as CanvasLayer
	var hud_clip := effect.get_node("HudOverlayLayer/HudClip") as Control
	var hud_edge_glow := effect.get_node("HudOverlayLayer/HudClip/HudEdgeGlow") as ColorRect
	var hud_snowflake_field := effect.get_node(
		"HudOverlayLayer/HudClip/HudSnowflakeField"
	) as FreezerSnowflakeFieldScript
	var glow_material := edge_glow.material as ShaderMaterial
	var hud_glow_material := hud_edge_glow.material as ShaderMaterial
	_check(effect.layer == 5, "Freezer renders between gameplay and the layer-10 HUD.")
	_check(hud_overlay_layer.layer == 11, "Freezer's clipped top edge renders above the TopHud.")
	_check(not effect.visible, "Freezer overlay starts hidden.")
	_check(
		overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and edge_glow.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and snowflake_field.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and hud_clip.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and hud_edge_glow.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and hud_snowflake_field.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Every fullscreen Freezer control ignores gameplay input."
	)
	_check(
		effect.find_children("*", "TextureRect", true, false).is_empty(),
		"The redesigned Freezer effect contains no cracked-ice texture overlay."
	)
	var glow_color: Color = glow_material.get_shader_parameter(&"glow_color")
	var glow_width := float(glow_material.get_shader_parameter(&"glow_width"))
	var glow_intensity := float(glow_material.get_shader_parameter(&"glow_intensity"))
	var edge_rim_boost := float(glow_material.get_shader_parameter(&"edge_rim_boost"))
	var hud_glow_width := float(hud_glow_material.get_shader_parameter(&"glow_width"))
	var hud_edge_rim_boost := float(hud_glow_material.get_shader_parameter(&"edge_rim_boost"))
	_check(
		glow_color.b > glow_color.r
		and glow_color.b > glow_color.g
		and glow_width >= 0.085
		and glow_intensity >= 0.4
		and edge_rim_boost >= 0.7
		and is_equal_approx(glow_width, hud_glow_width)
		and is_equal_approx(edge_rim_boost, hud_edge_rim_boost),
		"Both Freezer passes share the larger blue glow and bright near-edge rim."
	)
	_check(
		hud_snowflake_field.get_mirror_source() == snowflake_field,
		"The clipped TopHud field mirrors the main snowflake simulation."
	)
	effect.apply_layout(Vector2(720.0, 1280.0), 144.0)
	_check(
		is_equal_approx(effect.get_hud_overlay_height(), 144.0)
		and hud_edge_glow.size.is_equal_approx(Vector2(720.0, 1280.0))
		and hud_snowflake_field.size.is_equal_approx(Vector2(720.0, 1280.0)),
		"The HUD copy clips to the responsive strip without squeezing either render pass."
	)

	effect.set_active(true)
	await create_timer(0.18).timeout
	var partial_activation := effect.get_activation_amount()
	_check(
		effect.visible
		and effect.is_active()
		and partial_activation > 0.0
		and partial_activation < 1.0,
		"Activation expands the glow inward from the viewport edges."
	)
	_check(
		snowflake_field.is_emitting()
		and snowflake_field.get_particle_count() > 0
		and snowflake_field.get_particle_count() <= snowflake_field.max_particles
		and snowflake_field.activation_burst_count >= 16
		and snowflake_field.emission_rate_per_second >= 30.0
		and snowflake_field.get_maximum_lifetime() <= 0.5,
		"Freezer activation emits a denser bounded set of faster-disappearing snowflakes."
	)

	# Level refreshes the active state every frame; a repeat must not restart the entrance tween.
	effect.set_active(true)
	await create_timer(0.32).timeout
	_check(
		effect.get_activation_amount() > 0.99 and effect.get_effect_opacity() > 0.99,
		"Repeated active updates do not restart the Freezer entrance."
	)
	effect.set_modal_dimmed(true)
	await create_timer(0.1).timeout
	_check(
		effect.get_modal_shade_amount() > 0.0 and effect.get_modal_shade_amount() < 1.0,
		"The TopHud glow and flakes fade into the gameplay modal shade instead of changing abruptly."
	)
	await create_timer(0.14).timeout
	_check(
		effect.get_modal_shade_amount() > 0.99,
		"The TopHud glow and flakes reach the full gameplay modal shade."
	)
	effect.set_modal_dimmed(false, true)
	_check(
		effect.get_modal_shade_amount() < 0.01,
		"An immediate modal reset restores the bright active-gameplay effect."
	)

	effect.set_active(false)
	await create_timer(effect.thaw_duration_seconds + 0.08).timeout
	_check(
		not effect.visible
		and not effect.is_active()
		and not snowflake_field.is_emitting()
		and snowflake_field.get_particle_count() == 0,
		"Thawing stops emission and clears the short-lived particles after its exit transition."
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
		"The main glow and snowflakes stay below HUD buttons and gameplay modals."
	)
	_check(
		effect != null
		and (effect.get_node("HudOverlayLayer") as CanvasLayer).layer > ui.layer,
		"The dedicated clipped glow and flake pass renders over the TopHud."
	)
	_check(level.call("_use_freezer"), "The Freezer ability starts from an inactive level state.")
	await process_frame
	_check(
		effect != null and effect.is_active(),
		"Starting the gameplay Freezer also starts its screen effect."
	)
	level.call("_open_pause_menu")
	await create_timer(0.24).timeout
	_check(
		effect != null and effect.get_modal_shade_amount() > 0.99,
		"Pausing an active Freezer tints its TopHud effect like the main pass."
	)
	level.call("_close_pause_menu")
	await create_timer(0.24).timeout
	_check(
		effect != null and effect.get_modal_shade_amount() < 0.01,
		"Resuming restores matching brightness across both render passes."
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
