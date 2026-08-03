extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := root.get_node_or_null("ChapterCatalog")
	_check(catalog != null, "ChapterCatalog autoload exists")
	if catalog != null:
		_check(catalog.is_valid(), "chapter catalog is valid: %s" % catalog.get_diagnostic())
		var chapters: Array = catalog.get_chapters()
		_check(chapters.size() == 2, "two chapter definitions are available")
		_check(catalog.get_first_chapter_id() == "chapter_01", "Chapter 1 is the default")
		_check(catalog.get_chapter_id_for_level(10) == "chapter_01", "level 10 belongs to Chapter 1")
		_check(catalog.get_local_level_number(10) == 10, "level 10 has chapter-local number 10")
		_check(catalog.get_unlock_requirement("chapter_02") == 25, "Chapter 2 requires 25 completions")
		_check(catalog.get_level_ids("chapter_02").is_empty(), "future Chapter 2 content may be empty")
		_check(
			ResourceLoader.exists(catalog.get_background_texture_path("chapter_01")),
			"Chapter 1 background texture exists"
		)

	if _failures.is_empty():
		print("Chapter catalog tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("FAILED: %s" % description)
