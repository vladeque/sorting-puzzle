extends TextureRect


func show_chapter(chapter_id: String) -> void:
	var texture_path := ChapterCatalog.get_background_texture_path(chapter_id)
	if texture_path.is_empty():
		texture = null
		return
	texture = load(texture_path) as Texture2D

