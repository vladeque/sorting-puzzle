extends Control
class_name ProfileAvatarView

const ProfileFrameCatalogScript := preload("res://scripts/profile_frame_catalog.gd")
const AVATAR_CLIP_SHADER := preload("res://assets/ui/avatar_circle_clip.gdshader")
const DIMMED_AVATAR_COLOR := Color(0.4, 0.34, 0.3, 1.0)

@export var avatar_id := "avatar_cat"
@export var frame_id := "frame_classic"
## Darkens only the avatar layer, leaving the frame at full color, so a lock drawn on top reads clearly.
@export var avatar_dimmed := false

@onready var _avatar_texture := %AvatarTexture as TextureRect
@onready var _frame_texture := %FrameTexture as TextureRect


func _ready() -> void:
	if _avatar_texture.material == null:
		var clip_material := ShaderMaterial.new()
		clip_material.shader = AVATAR_CLIP_SHADER
		_avatar_texture.material = clip_material
	_apply_profile()


func set_profile(next_avatar_id: String, next_frame_id: String) -> void:
	avatar_id = next_avatar_id
	frame_id = ProfileFrameCatalogScript.sanitize_frame_id(next_frame_id)
	if is_node_ready():
		_apply_profile()


func set_avatar(next_avatar_id: String) -> void:
	avatar_id = next_avatar_id
	if is_node_ready():
		_apply_profile()


func set_frame(next_frame_id: String) -> void:
	frame_id = ProfileFrameCatalogScript.sanitize_frame_id(next_frame_id)
	if is_node_ready():
		_apply_profile()


func set_avatar_dimmed(is_dimmed: bool) -> void:
	avatar_dimmed = is_dimmed
	if is_node_ready():
		_apply_profile()


func _apply_profile() -> void:
	if _frame_texture == null or _avatar_texture == null:
		return
	_avatar_texture.texture = load(PlayerProgress.get_avatar_texture_path(avatar_id)) as Texture2D
	_frame_texture.texture = load(ProfileFrameCatalogScript.get_frame_texture_path(frame_id)) as Texture2D
	_avatar_texture.self_modulate = DIMMED_AVATAR_COLOR if avatar_dimmed else Color.WHITE
