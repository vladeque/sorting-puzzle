extends RefCounted

## Shows the weekly leaderboard reward dialog for responsive screenshot review.


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("show_reward", 2, 300)
	await tree.create_timer(0.4).timeout
	for _frame in range(2):
		await tree.process_frame
