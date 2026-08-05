class_name MenuBackgroundResolver
extends RefCounted

## Shared "selected chapter -> menu background texture" policy for every screen that shows a
## fullscreen destination background driven by the player's selected chapter: Main Menu directly,
## and Shop/Leaderboard through scenes/ui/destination_screen_shell.tscn. Consumers preload this
## script (matching the project convention used by scripts/backend/backend_read_operations.gd) and
## call apply_background() directly -- no instance needed.
##
## Silently keeps the caller's existing texture when the selected chapter has no valid configured
## `selection_preview`, so a missing/invalid catalog entry never blanks a screen's background.


static func apply_background(background: TextureRect, chapter_id: String) -> void:
	if background == null:
		return

	var background_path := ChapterCatalog.get_selection_preview_path(chapter_id)
	if background_path.is_empty() or not ResourceLoader.exists(background_path):
		return

	var background_texture := load(background_path) as Texture2D
	if background_texture != null:
		background.texture = background_texture
