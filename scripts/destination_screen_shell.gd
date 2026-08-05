extends Control

## Shared fullscreen background + secondary-screen shade for Shop/Leaderboard-style destination
## screens. Owns only the background policy; catalog, purchase, leaderboard, ranking, and
## progression logic all stay in the owning screen's own script.

const MenuBackgroundResolverScript := preload("res://scripts/chapters/menu_background_resolver.gd")

@onready var _background := %Background as TextureRect


## Shows the selected chapter's configured menu background, matching the policy Main Menu already
## follows -- keeps the caller's current texture when the chapter has no valid configured preview.
func set_background_for_chapter(chapter_id: String) -> void:
	MenuBackgroundResolverScript.apply_background(_background, chapter_id)
