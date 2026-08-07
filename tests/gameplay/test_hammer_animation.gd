extends SceneTree

## Focused timing/integration verification for the Hammer timing animatic. The same test can be
## launched with Godot's --write-movie option to capture a deterministic in-level preview.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"
const PREVIEW_ARGUMENT := "--hammer-animation-preview"

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
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level = level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 2)
	root.add_child(level)
	await process_frame
	await process_frame
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

	await effect.impact
	var animation_player := effect.get_node("AnimationPlayer") as AnimationPlayer
	var impact_animation_position := animation_player.current_animation_position
	_check(
		impact_animation_position >= 0.47 and impact_animation_position <= 0.52,
		"Hammer impact signal is aligned to the 480 ms strike frame."
	)

	await effect.finished
	_check(
		animation_player.current_animation_position >= 1.1,
		"Hammer recoil and placeholder burst remain visible for the full 1.12 second animatic."
	)
	var reward_layer := level.get("_star_reward_effect_layer") as Control
	_check(
		reward_layer != null and reward_layer.get_child_count() > 0,
		"Combo reward star flight overlaps the Hammer recoil tail."
	)
	await create_timer(0.45).timeout
	_check(not bool(level.get("_hammer_effect_active")), "Hammer input lock clears after the effect finishes.")

	_finish(level)


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
