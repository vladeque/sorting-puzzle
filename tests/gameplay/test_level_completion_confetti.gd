extends SceneTree

## Focused verification for the post-clear celebration window (scripts/level.gd's _complete_level and
## scenes/effects/level_completion_confetti.tscn). Covers the delay before the completion screen
## opens, layered textured cannons firing from the bottom corners toward the middle, the center beat,
## the overlap between falling pieces and the reward overlay, and the back-press skip.

const ISOLATED_TEST_PROJECT_PREFIX := "SortingPuzzleTest_"
const LEVEL_SCENE_PATH := "res://level.tscn"

## Sampled inside the celebration window rather than at its edge, so the assertions do not depend on
## landing exactly on a frame boundary.
const PRE_REVEAL_SECONDS := 0.75
const POST_REVEAL_SECONDS := 0.8

## The representative portrait resolutions from AGENTS.md's "Responsive UI", plus a squarer
## tablet-like viewport.
const TEST_VIEWPORT_SIZES := [
	Vector2(540.0, 960.0),
	Vector2(720.0, 1280.0),
	Vector2(1080.0, 1920.0),
	Vector2(1080.0, 2400.0),
	Vector2(1024.0, 1280.0),
]

var _failures: Array[String] = []


func _init() -> void:
	if not str(ProjectSettings.get_setting("application/config/name", "")).begins_with(
		ISOLATED_TEST_PROJECT_PREFIX
	):
		push_error("Completion confetti verification must run through run_isolated_godot_test.ps1.")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _verify_celebration_window()
	await _verify_back_press_skip()
	await _verify_responsive_aim()

	await process_frame
	if _failures.is_empty():
		print("Level completion confetti verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_celebration_window() -> void:
	var level := await _make_level()
	var confetti := level.get_node("UI/CompletionConfetti") as LevelCompletionConfetti
	var completion_screen := level.get_node("UI/CompletionScreen") as Control

	_check(confetti != null, "level.tscn instances the completion confetti effect.")
	if confetti == null:
		level.queue_free()
		return

	_check(not confetti.visible, "Confetti stays hidden while the level is still being played.")
	_check(
		confetti.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Confetti never intercepts touches meant for the level or the reward screen."
	)

	level.call("_complete_level")

	var viewport_size := confetti.get_viewport_rect().size
	var left_cannon := confetti.get_node("LeftCannon") as CPUParticles2D
	var right_cannon := confetti.get_node("RightCannon") as CPUParticles2D
	var center_burst := confetti.get_node("CenterBurst") as CPUParticles2D
	var textured_emitters: Array[CPUParticles2D] = []
	for node_name in [
		"LeftBackCurl",
		"RightBackCurl",
		"LeftCannon",
		"RightCannon",
		"LeftFold",
		"RightFold",
		"LeftStars",
		"RightStars",
		"LeftFrontCurl",
		"RightFrontCurl",
	]:
		textured_emitters.append(confetti.get_node(node_name) as CPUParticles2D)
	var all_layers_textured_and_emitting := true
	var side_particle_count := 0
	for emitter: CPUParticles2D in textured_emitters:
		all_layers_textured_and_emitting = (
			all_layers_textured_and_emitting and emitter.texture != null and emitter.emitting
		)
		side_particle_count += emitter.amount

	_check(confetti.visible, "Clearing the board starts the confetti burst.")
	_check(
		left_cannon.emitting and right_cannon.emitting,
		"Both main cannons fire on completion."
	)
	_check(
		all_layers_textured_and_emitting,
		"Every depth and shape layer uses a texture and fires with the main burst."
	)
	_check(
		side_particle_count <= 260,
		"Layered side emitters stay within the previous 260-piece particle budget."
	)
	_check(
		center_burst.texture != null
		and center_burst.position.distance_to(viewport_size * Vector2(0.5, 0.43)) < 1.0,
		"The delayed textured star burst is centered where the two arcs meet."
	)
	_check(
		left_cannon.position.x < viewport_size.x * 0.1
		and left_cannon.position.y > viewport_size.y * 0.9,
		"The left cannon sits in the bottom-left corner."
	)
	_check(
		right_cannon.position.x > viewport_size.x * 0.9
		and right_cannon.position.y > viewport_size.y * 0.9,
		"The right cannon sits in the bottom-right corner."
	)
	_check(
		left_cannon.direction.x > 0.0 and left_cannon.direction.y < 0.0,
		"The left cannon aims up and inward, toward the middle of the screen."
	)
	_check(
		right_cannon.direction.x < 0.0 and right_cannon.direction.y < 0.0,
		"The right cannon aims up and inward, toward the middle of the screen."
	)
	_check(
		left_cannon.initial_velocity_min > 0.0 and left_cannon.gravity.y > 0.0,
		"Pieces are launched with real speed and fall back down."
	)

	await create_timer(PRE_REVEAL_SECONDS).timeout
	_check(
		not completion_screen.visible,
		"The cleared level stays on screen for the celebration before the reward screen opens."
	)
	_check(
		bool(level.get("_level_completed")),
		"Completion is committed up front, not deferred until the celebration ends."
	)

	await create_timer(POST_REVEAL_SECONDS).timeout
	_check(
		completion_screen.visible,
		"The reward screen starts opening after the shorter reveal delay."
	)
	_check(
		confetti.visible,
		"Confetti keeps falling in front of the reward screen instead of ending at the transition."
	)
	_check(
		not bool(level.get("_completion_celebration_active")),
		"The celebration window closes when the reward screen opens."
	)

	level.queue_free()
	await process_frame


func _verify_back_press_skip() -> void:
	var level := await _make_level()
	var completion_screen := level.get_node("UI/CompletionScreen") as Control

	level.call("_complete_level")
	await create_timer(PRE_REVEAL_SECONDS).timeout

	# The back-press branch of _unhandled_input routes here rather than exiting to the main menu.
	level.call("_open_completion_screen")
	_check(
		completion_screen.visible,
		"Skipping the celebration opens the reward screen immediately."
	)

	# The celebration timer is still counting down; it must not re-open the screen behind the skip.
	completion_screen.hide()
	await create_timer(POST_REVEAL_SECONDS).timeout
	_check(
		not completion_screen.visible,
		"The celebration timer no-ops after a skip instead of opening the screen twice."
	)

	level.queue_free()
	await process_frame


## The burst is aimed from the live viewport rather than from baked velocities, so the arcs have to
## land in the same relative place on every supported resolution. Solves each cannon's trajectory
## back out of the properties it wrote and checks where the average piece actually peaks.
func _verify_responsive_aim() -> void:
	var level := await _make_level()
	var confetti := level.get_node("UI/CompletionConfetti") as LevelCompletionConfetti

	for viewport_size: Vector2 in TEST_VIEWPORT_SIZES:
		var label := "%dx%d" % [int(viewport_size.x), int(viewport_size.y)]
		confetti.apply_safe_layout(Vector4.ZERO, viewport_size)
		confetti.play()

		for horizontal_sign in [1.0, -1.0]:
			var node_name := "LeftCannon" if horizontal_sign > 0.0 else "RightCannon"
			var cannon := confetti.get_node(node_name) as CPUParticles2D
			var expected_x := 0.0 if horizontal_sign > 0.0 else viewport_size.x
			_check(
				absf(cannon.position.x - expected_x) < viewport_size.x * 0.1
				and cannon.position.y > viewport_size.y * 0.9,
				"%s stays in its bottom corner at %s." % [node_name, label]
			)

			# The average piece flies at the midpoint of the min/max velocity spread.
			var speed := (cannon.initial_velocity_min + cannon.initial_velocity_max) * 0.5
			var rise_seconds := speed * -cannon.direction.y / cannon.gravity.y
			var apex_height := 0.5 * cannon.gravity.y * rise_seconds * rise_seconds
			var apex_x := cannon.position.x + speed * cannon.direction.x * rise_seconds

			_check(
				apex_height > viewport_size.y * 0.38 and apex_height < viewport_size.y * 0.6,
				"%s peaks around the middle of the screen at %s (got %.2f of the height)."
					% [node_name, label, apex_height / viewport_size.y]
			)
			_check(
				apex_x > viewport_size.x * 0.35 and apex_x < viewport_size.x * 0.65,
				"%s converges on the middle of the screen at %s (got %.2f of the width)."
					% [node_name, label, apex_x / viewport_size.x]
			)

	level.queue_free()
	await process_frame


func _make_level() -> Node:
	var level_scene := load(LEVEL_SCENE_PATH) as PackedScene
	var level := level_scene.instantiate()
	level.set("launched_from_dev_mode", true)
	level.set("selected_level", 2)
	root.add_child(level)
	await process_frame
	await process_frame
	return level


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
