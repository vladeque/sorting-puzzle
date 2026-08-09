extends SceneTree

## Focused timing/integration verification for the polished Hammer strike. The same test can be
## launched with Godot's --write-movie option to capture a deterministic in-level preview.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"
const PREVIEW_ARGUMENT := "--hammer-animation-preview"
const SUPPORTED_VIEWPORT_SIZES := [
	Vector2i(540, 960),
	Vector2i(720, 1280),
	Vector2i(1080, 1920),
	Vector2i(1080, 2400),
	Vector2i(900, 1200),
]

var _failures: Array[String] = []
var _preview_mode := false


func _init() -> void:
	_preview_mode = OS.get_cmdline_user_args().has(PREVIEW_ARGUMENT)
	if not _preview_mode and not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Hammer animation verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	if not _preview_mode:
		await _verify_responsive_effect_layout()
		get_root().content_scale_size = Vector2i(720, 1280)
		get_root().size = Vector2i(720, 1280)
		await process_frame
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level = level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 2)
	level.set("hammer_haptics_enabled", false)
	level.set("_sound_effects_enabled", false)
	root.add_child(level)
	await process_frame
	await process_frame
	level.set("_sound_effects_enabled", false)
	if _preview_mode:
		await create_timer(0.35).timeout

	var visible_items := level.call("_get_visible_items") as Array
	var hammer_targets := level.call("_find_hammer_targets", visible_items) as Array
	_check(hammer_targets.size() == 3, "Level 2 exposes a deterministic Hammer triple.")
	if hammer_targets.size() != 3:
		_finish(level)
		return

	var expected_impact_global_position: Vector2 = level.call("_get_hammer_target_center", hammer_targets)
	var expected_impact_screen_position: Vector2 = level.get_canvas_transform() * expected_impact_global_position
	level.set("_has_player_started_timer", true)
	level.call("_play_hammer_ability", hammer_targets)
	var effect := level.get_node_or_null("UI/HammerImpactEffect") as HammerImpactEffect
	_check(effect != null, "Hammer effect starts immediately instead of waiting for item gathering.")
	if effect == null:
		_finish(level)
		return

	var pivot := effect.get_node("ImpactAnchor/HammerPivot") as Node2D
	var impact_anchor := effect.get_node("ImpactAnchor") as Node2D
	var animation_player := effect.get_node("AnimationPlayer") as AnimationPlayer
	var strike := animation_player.get_animation(&"strike")
	var texture_track := strike.find_track(
		NodePath("ImpactAnchor/HammerPivot/HammerSprite:texture"),
		Animation.TYPE_VALUE
	)
	_check(texture_track >= 0, "Hammer strike owns a texture-swap track.")
	if texture_track >= 0:
		_check(strike.track_get_key_count(texture_track) == 10, "Hammer strike uses all ten pose assets.")
	for property_path in [
		NodePath(".:_trail_amount"),
		NodePath(".:_glow_amount"),
		NodePath(".:_burst_amount"),
		NodePath(".:_flash_amount"),
		NodePath(".:_debris_amount"),
	]:
		_check(
			strike.find_track(property_path, Animation.TYPE_VALUE) >= 0,
			"Hammer strike animates the %s VFX layer." % property_path.get_subname(0)
		)
	_check(effect.get_node_or_null("ImpactLowAudio") != null, "Hammer owns a dedicated impact-thump cue.")
	_check(effect.get_node_or_null("DownstrokeAudio") != null, "Hammer owns a dedicated downstroke cue.")
	_check(effect.get_node_or_null("SparkleTailAudio") != null, "Hammer owns a dedicated sparkle-tail cue.")
	var early_afterimage := effect.get_node_or_null("ImpactAnchor/HammerPivot/AfterimageEarly") as Sprite2D
	var late_afterimage := effect.get_node_or_null("ImpactAnchor/HammerPivot/AfterimageLate") as Sprite2D
	_check(early_afterimage != null, "Hammer owns an early downstroke afterimage.")
	_check(late_afterimage != null, "Hammer owns a late downstroke afterimage.")
	_check(
		early_afterimage != null
			and early_afterimage.material is CanvasItemMaterial
			and (early_afterimage.material as CanvasItemMaterial).blend_mode
				== CanvasItemMaterial.BLEND_MODE_ADD,
		"Hammer smear afterimages use a shared additive mobile canvas material."
	)
	var script_constants: Dictionary = effect.get_script().get_script_constant_map()
	_check(
		int(script_constants.get("BURST_RAY_COUNT", 999)) <= 20
			and int(script_constants.get("SPARK_COUNT", 999)) <= 24
			and int(script_constants.get("TRAIL_LINE_COUNT", 999)) <= 4,
		"Hammer procedural VFX stays inside the mobile element-count budget."
	)
	_check(not bool(effect.get("_sound_enabled")), "Hammer inherits the disabled sound-effects setting.")
	var hammer_uses_before_repeat := int((level.get("_ability_uses") as Dictionary).get(&"hammer", -1))
	level.call("_on_ability_button_pressed", &"hammer")
	await process_frame
	_check(
		int((level.get("_ability_uses") as Dictionary).get(&"hammer", -1)) == hammer_uses_before_repeat
			and level.get_tree().get_nodes_in_group(&"hammer_impact_effect").size() == 1,
		"Repeated Hammer taps are ignored while the strike owns the ability input lock."
	)
	_check(
		impact_anchor.position.is_equal_approx(expected_impact_screen_position),
		"Hammer gathers and strikes at the selected targets' averaged board position."
	)
	_check(
		pivot.position.x < 0.0 and pivot.position.y > 0.0,
		"Hammer begins in the lower-left launch pose."
	)

	await create_timer(0.24).timeout
	_check(
		pivot.position.x > 0.0 and pivot.position.y < 0.0,
		"Hammer reaches the upper-right anticipation pose while the gather completes."
	)

	await effect.pre_impact
	await create_timer(0.04).timeout
	var merged_item := hammer_targets[0] as ShelfItem
	_check(
		merged_item != null
			and is_instance_valid(merged_item)
			and merged_item.scale.x > merged_item.scale.y,
		"Merged item compresses during the final 80 ms anticipation window."
	)

	await effect.impact
	var impact_animation_position := animation_player.current_animation_position
	_check(
		impact_animation_position >= 0.47 and impact_animation_position <= 0.52,
		"Hammer impact signal is aligned to the 480 ms strike frame."
	)
	await process_frame
	for item in hammer_targets:
		_check(
			item == null
				or not is_instance_valid(item)
				or not item.visible
				or item.is_queued_for_deletion(),
			"Every Hammer target disappears on the impact frame."
		)
	var reward_layer := level.get("_star_reward_effect_layer") as Control
	_check(
		reward_layer != null and reward_layer.get_child_count() == 0,
		"Hammer reward waits briefly after impact instead of obscuring the hit frame."
	)
	await create_timer(0.16).timeout
	_check(
		reward_layer != null and reward_layer.get_child_count() > 0,
		"Combo reward starts 140 ms after impact and overlaps the recoil tail."
	)

	await effect.finished
	_check(
		animation_player.current_animation_position >= 1.1,
		"Hammer recoil and layered VFX remain visible for the full 1.12 second strike."
	)
	await create_timer(0.45).timeout
	_check(not bool(level.get("_hammer_effect_active")), "Hammer input lock clears after the effect finishes.")
	_check(
		level.get_tree().get_nodes_in_group(&"hammer_impact_effect").is_empty(),
		"Hammer effect leaves no scene instances behind after cleanup."
	)

	_finish(level)


func _verify_responsive_effect_layout() -> void:
	var effect_scene := load("res://scenes/abilities/hammer_impact_effect.tscn") as PackedScene
	for viewport_size in SUPPORTED_VIEWPORT_SIZES:
		get_root().content_scale_size = viewport_size
		get_root().size = viewport_size
		await process_frame
		var effect := effect_scene.instantiate() as HammerImpactEffect
		root.add_child(effect)
		await process_frame
		var target := Vector2(viewport_size) * Vector2(0.5, 0.58)
		effect.play(target, false, false)
		await process_frame
		var anchor := effect.get_node("ImpactAnchor") as Node2D
		var sprite := effect.get_node("ImpactAnchor/HammerPivot/HammerSprite") as Sprite2D
		_check(
			effect.size.is_equal_approx(Vector2(viewport_size)),
			"Hammer overlay fills the %s viewport." % viewport_size
		)
		_check(
			anchor.position.is_equal_approx(target),
			"Hammer keeps its board-relative target at %s." % viewport_size
		)
		_check(
			sprite.scale.x >= 0.5 and sprite.scale.x <= 0.92,
			"Hammer scale remains capped for mobile/tablet viewport %s." % viewport_size
		)
		effect.queue_free()
		await process_frame


func _finish(level: Node) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Hammer animation verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
