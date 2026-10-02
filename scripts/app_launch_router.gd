extends Node

## Startup entry configured as `run/main_scene`. Until the player beats the first campaign level,
## the game opens straight into it through the level loading screen; afterwards, and whenever no
## life is left to play it, the game opens on the production Main Menu.

@export_file("*.tscn") var main_menu_scene_path := "res://scenes/main_menu.tscn"
## Turns the first-level start off so every launch opens the Main Menu, for example while testing
## the menu against a fresh save.
@export var start_unbeaten_first_level := true


func _ready() -> void:
	# Deferred so the route runs once this scene has finished entering the tree, still ahead of the
	# first rendered frame.
	_route.call_deferred()


## Returns the level a launch should open directly, or 0 when the launch belongs on the Main Menu.
func get_first_level_to_start() -> int:
	if not start_unbeaten_first_level:
		return 0
	# GAME-012: no gameplay while an account deletion is unsettled or awaiting a new game.
	if PlayerProgress.is_account_deletion_blocking():
		return 0
	var first_chapter_id := ChapterCatalog.get_first_chapter_id()
	var level_ids := ChapterCatalog.get_level_ids(first_chapter_id)
	if level_ids.is_empty():
		return 0
	var first_level := level_ids[0]
	if PlayerProgress.get_next_level_for_chapter(first_chapter_id) != first_level:
		return 0
	PlayerProgress.refresh_lives()
	if PlayerProgress.get_lives() <= 0:
		return 0
	return first_level


func _route() -> void:
	var first_level := get_first_level_to_start()
	if first_level > 0:
		LevelTransition.launch_level_at_startup(first_level, main_menu_scene_path, self)
		return
	_open_main_menu()


## Swaps the Main Menu in directly. change_scene_to_file() only adds the new scene on the following
## frame, which would draw one empty frame between the boot splash and the menu.
func _open_main_menu() -> void:
	var packed_menu := load(main_menu_scene_path) as PackedScene
	if packed_menu == null:
		push_error("Could not load the Main Menu: %s" % main_menu_scene_path)
		return
	var tree := get_tree()
	var menu := packed_menu.instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu
	queue_free()
