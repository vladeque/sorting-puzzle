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

	var expected_impact_screen_position: Vector2 = level.get_viewport_rect().size * 0.5
	var expected_impact_global_position: Vector2 = level.call(
		"_screen_position_to_global", expected_impact_screen_position
	)
	var starting_distances: Array[float] = []
	for item in hammer_targets:
		starting_distances.append(
			(item as ShelfItem).global_position.distance_to(expected_impact_global_position)
		)
	level.set("_has_player_started_timer", true)
	level.call("_play_hammer_ability", hammer_targets)
	var effect := level.get_node_or_null("UI/HammerImpactEffect") as HammerImpactEffect
	_check(effect == null, "Hammer stays hidden until the three targets have merged.")
	await create_timer(0.1).timeout
	for item_index in range(hammer_targets.size()):
		var gathering_item := hammer_targets[item_index] as ShelfItem
		_check(
			gathering_item != null
				and is_instance_valid(gathering_item)
				and gathering_item.global_position.distance_to(expected_impact_global_position)
					< starting_distances[item_index],
			"Every Hammer target flies toward the viewport center before the strike."
		)
	await create_timer(0.25).timeout
	effect = level.get_node_or_null("UI/HammerImpactEffect") as HammerImpactEffect
	_check(effect != null, "Hammer starts after the center merge pop completes.")
	if effect == null:
		_finish(level)
		return
	var visible_merged_items := 0
	for item in hammer_targets:
		if item != null and is_instance_valid(item) and item.visible and not item.is_queued_for_deletion():
			visible_merged_items += 1
	_check(visible_merged_items == 1, "The three gathered targets merge into one visible item.")
	var merged_item := hammer_targets[0] as ShelfItem
	_check(
		merged_item != null
			and is_instance_valid(merged_item)
			and merged_item.global_position.distance_to(expected_impact_global_position) < 1.0,
		"The merged item settles at the exact viewport center."
	)

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
		_check(
			strike.track_get_key_count(texture_track) == 8,
			"Hammer strike swaps through the eight swing poses."
		)
		_check(
			strike.track_get_key_time(texture_track, 7) <= 0.59,
			"Hammer reaches supplied frame 8 on the impact beat."
		)
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
		"Hammer strikes at the exact viewport center."
	)
	_check(
		pivot.position.x > 0.0 and pivot.position.y < 0.0,
		"Hammer begins in its raised upper-right approach pose."
	)

	await create_timer(0.24).timeout
	_check(
		pivot.position.x > 0.0 and pivot.position.y < 0.0,
		"Hammer circles above the already-merged center item before descending."
	)

	await effect.pre_impact
	await create_timer(0.04).timeout
	_check(
		merged_item != null
			and is_instance_valid(merged_item)
			and merged_item.scale.x > merged_item.scale.y,
		"Merged item compresses during the final 80 ms anticipation window."
	)

	await effect.impact
	var impact_animation_position := animation_player.current_animation_position
	_check(
		impact_animation_position >= 0.57 and impact_animation_position <= 0.62,
		"Hammer impact signal is aligned to the 580 ms final supplied frame."
	)
	await process_frame
	_check(
		(effect.call("_get_head_position") as Vector2).distance_to(expected_impact_screen_position)
			< 24.0,
		"Hammer head lands on the impact point instead of beside it."
	)
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
		animation_player.current_animation_position >= 1.24,
		"Hammer recoil and layered VFX remain visible for the full 1.26 second strike."
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
			sprite.scale.x >= 0.28 and sprite.scale.x <= 0.56,
			"Hammer scale remains capped for mobile/tablet viewport %s." % viewport_size
		)
		effect.queue_free()
		await process_frame

	await _verify_edge_target_framing()


## Targets near the right edge must mirror their approach, otherwise the raised pose hangs off the
## viewport and the player never sees the wind-up.
func _verify_edge_target_framing() -> void:
	var effect_scene := load("res://scenes/abilities/hammer_impact_effect.tscn") as PackedScene
	var viewport_size := Vector2i(720, 1280)
	get_root().content_scale_size = viewport_size
	get_root().size = viewport_size
	await process_frame

	for target_ratio in [0.18, 0.5, 0.86]:
		var effect := effect_scene.instantiate() as HammerImpactEffect
		root.add_child(effect)
		await process_frame
		var target := Vector2(viewport_size) * Vector2(target_ratio, 0.5)
		effect.play(target, false, false)
		await process_frame
		var anchor := effect.get_node("ImpactAnchor") as Node2D
		var mirrored := anchor.scale.x < 0.0
		_check(
			mirrored == (target_ratio > 0.55),
			"Hammer mirrors its approach only for right-side targets (ratio %s)." % target_ratio
		)

		var animation_player := effect.get_node("AnimationPlayer") as AnimationPlayer
		# Pausing keeps the pose fixed while the effect's own _process aligns the sprite, so these
		# assertions do not depend on how far a frame advances the strike.
		animation_player.seek(0.3, true)
		animation_player.pause()
		await process_frame
		var raised_head: Vector2 = effect.call("_get_head_position")
		_check(
			raised_head.x >= 0.0 and raised_head.x <= float(viewport_size.x),
			"Hammer keeps its raised pose on screen for target ratio %s." % target_ratio
		)

		animation_player.seek(0.58, true)
		animation_player.pause()
		await process_frame
		var pose_offsets: Dictionary = effect.get_script().get_script_constant_map().get(
			"POSE_HEAD_OFFSETS", {}
		)
		var sprite := effect.get_node("ImpactAnchor/HammerPivot/HammerSprite") as Sprite2D
		var head_offset: Vector2 = pose_offsets.get(sprite.texture, Vector2.INF)
		_check(
			head_offset.is_finite()
				and (sprite.position + head_offset * sprite.scale).length() < 0.01,
			"Impact pose keeps its head centre on the pivot the burst is drawn around."
		)
		_check(
			(effect.call("_get_head_position") as Vector2).distance_to(target) < 0.01,
			"Hammer head lands exactly on the impact point for target ratio %s." % target_ratio
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
