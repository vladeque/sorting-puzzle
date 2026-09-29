extends RefCounted

## Preview the selected weekly-placement frame textures without exposing them in the frame catalog.

const TILE_SCENE := preload("res://scenes/ui/profile_choice_tile.tscn")
const FRAME_PATHS := [
	"res://assets/ui/avatar_frames/frame_weekly_gold.png",
	"res://assets/ui/avatar_frames/frame_weekly_silver.png",
	"res://assets/ui/avatar_frames/frame_weekly_bronze.png",
]


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("_switch_tab", &"frame")
	await tree.process_frame
	var grid := scene_root.get_node("%ChoiceGrid") as GridContainer
	for child in grid.get_children():
		child.queue_free()
	await tree.process_frame
	var preview_tiles := {}
	for index in range(FRAME_PATHS.size()):
		var tile := TILE_SCENE.instantiate() as ProfileChoiceTile
		grid.add_child(tile)
		var preview_id := "weekly_preview_%d" % index
		tile.setup(preview_id, PlayerProgress.get_avatar_id(), "frame_classic")
		var frame_texture := tile.get_node("ProfileAvatarView/FrameTexture") as TextureRect
		frame_texture.texture = load(FRAME_PATHS[index]) as Texture2D
		preview_tiles[preview_id] = tile
	scene_root.set("_choice_tiles", preview_tiles)
	scene_root.call("_apply_responsive_layout")
	var profile_preview := scene_root.get_node("%ProfilePreview") as Control
	var preview_frame_texture := profile_preview.get_node("FrameTexture") as TextureRect
	preview_frame_texture.texture = load(FRAME_PATHS[0]) as Texture2D
	await tree.process_frame
