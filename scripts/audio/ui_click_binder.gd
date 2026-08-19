extends Node

## The single generic `ui_click` policy for the whole game (AUDIO-001 section 7).
##
## Owned and instantiated by scripts/audio/sfx_manager.gd. It watches `SceneTree.node_added` and
## binds every `BaseButton` -- authored in a scene or created at runtime -- exactly once, so no
## screen has to remember to wire a click and no button can end up with two generic owners.
##
## Rules it enforces:
## - Plays on the accepted `pressed` action, never on pointer-down, so a press that is released
##   outside the button stays silent (Godot only emits `pressed` for an accepted release).
## - Disabled buttons never emit `pressed`, and a button that is not visible in the tree is ignored,
##   so neither can click.
## - Binding is idempotent and recorded on the button itself, so rebinding, reparenting, pooling, or
##   re-entering the tree cannot produce a second click.
## - A button carrying `SUPPRESS_META` stays silent. That is the escape hatch for documented no-op
##   actions (the already-active destination tab) and for controls that own a complete replacement
##   cue (the sound-effects settings toggle, which acknowledges its own press).

## Set this meta on a BaseButton to keep the generic click off it. Prefer
## `SfxManager.set_button_click_suppressed()` so callers do not have to preload this script.
const SUPPRESS_META := &"sfx_click_suppressed"
const BOUND_META := &"_sfx_click_bound"

const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")

var _manager: Node


func _ready() -> void:
	_manager = get_parent()
	var tree := get_tree()
	if tree == null:
		return

	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)

	# Autoloads enter the tree before the main scene, so `node_added` normally covers everything.
	# The sweep only matters when this owner is created after a scene already exists, which is how
	# the audio tests build an isolated manager.
	_bind_existing_buttons(tree.root)


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)


## Marks a button silent (or audible again) for the generic click.
static func set_click_suppressed(button: BaseButton, is_suppressed: bool) -> void:
	if button == null or not is_instance_valid(button):
		return

	button.set_meta(SUPPRESS_META, is_suppressed)


static func is_click_suppressed(button: BaseButton) -> bool:
	return button != null and button.has_meta(SUPPRESS_META) and bool(button.get_meta(SUPPRESS_META))


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null:
		bind_button(button)


func _bind_existing_buttons(node: Node) -> void:
	var button := node as BaseButton
	if button != null:
		bind_button(button)

	for child in node.get_children():
		_bind_existing_buttons(child)


## Connects one button's `pressed` action to the generic click, at most once per button.
func bind_button(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return

	if button.has_meta(BOUND_META):
		return

	button.set_meta(BOUND_META, true)
	button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.disabled or not button.is_visible_in_tree():
		return

	if is_click_suppressed(button):
		return

	if _manager != null and _manager.has_method("play"):
		_manager.call("play", SfxCatalogScript.EVENT_UI_CLICK)
