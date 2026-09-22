extends Control
class_name PauseMenu

## Reusable in-level pause menu overlay -- also reused as-is for the Main Menu settings popup via
## scenes/ui/settings_menu.tscn (production_main_menu.gd manages that instance's fade/free itself
## and reaches its CloseButton by path, unrelated to the shell wiring below).
##
## Composes scenes/ui/gameplay_modal_shell.tscn for shade, outer panel, title, close button,
## content region, and action row (UI-003; see docs/SCENES.md "Shared Gameplay UI Roles"). Settings
## buttons are located by name rather than a fixed NodePath so this one script keeps working for
## both this scene's shell-composed layout and settings_menu.tscn's own unrelated layout.
##
## scripts/level.gd only calls open()/close()/apply_safe_layout() and listens for
## leave_pressed/continue_pressed/setting_toggled -- it does not reach into this scene's children.

signal setting_toggled(setting_id: StringName, is_disabled: bool)
signal leave_pressed
signal continue_pressed
signal support_requested
signal ad_privacy_requested

const SETTING_MUSIC := &"music"
const SETTING_SOUND_EFFECTS := &"sound_effects"
const SETTING_VIBRATION := &"vibration"
const SETTINGS_BUTTONS: Array[Dictionary] = [
	{"name": "MusicButton", "setting_id": SETTING_MUSIC},
	{"name": "SoundEffectsButton", "setting_id": SETTING_SOUND_EFFECTS},
	{"name": "VibrationButton", "setting_id": SETTING_VIBRATION},
]
const CROSS_OUT_NAME := "CrossOut"
const CONTENT_REGION_HEIGHT := 234.0
const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")

static var _disabled_settings: Dictionary = {}
static var _settings_loaded_from_save := false

@onready var _shell := get_node_or_null("Shell") as GameplayModalShell
@onready var _settings_content := get_node_or_null("SettingsContent") as Control
@onready var _leave_button := get_node_or_null("LeaveButton") as Button
@onready var _continue_button := get_node_or_null("ContinueButton") as Button


func _ready() -> void:
	_ensure_settings_loaded()
	for button_config in SETTINGS_BUTTONS:
		var button := find_child(String(button_config.get("name")), true, false) as Button
		var setting_id := button_config.get("setting_id") as StringName
		if button == null:
			push_warning("Missing pause menu setting button: %s" % button_config.get("name"))
			continue

		var cross_out := _create_cross_out_marker(button)
		cross_out.visible = is_setting_disabled(setting_id)
		button.pressed.connect(_on_setting_button_pressed.bind(cross_out, setting_id))
		if setting_id == SETTING_SOUND_EFFECTS:
			# This one button owns a complete replacement cue: turning sound effects off has to
			# acknowledge the press before muting, and turning them on after enabling, which the
			# generic click policy cannot express. Every other settings toggle keeps the normal
			# click (AUDIO-001 section 7).
			SfxManager.set_button_click_suppressed(button)

	if _shell != null:
		_shell.configure("PAUSE")
		_shell.set_preferred_size(Vector2(
			GameplayUIThemeScript.MODAL_MAX_WIDTH,
			GameplayUIThemeScript.MODAL_COMPACT_HEIGHT
		))
		_shell.set_content_region_height(CONTENT_REGION_HEIGHT)
		_shell.close_requested.connect(func() -> void: continue_pressed.emit())
		if _settings_content != null:
			_settings_content.reparent(_shell.get_content_region(), false)
		if _leave_button != null:
			_leave_button.reparent(_shell.get_action_row(), false)
		if _continue_button != null:
			_continue_button.reparent(_shell.get_action_row(), false)

	if _leave_button != null:
		_leave_button.pressed.connect(func() -> void: leave_pressed.emit())
	if _continue_button != null:
		_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	var support_button := find_child("SupportButton", true, false) as Button
	if support_button != null:
		support_button.pressed.connect(func() -> void: support_requested.emit())
	var ad_privacy_button := find_child("AdPrivacyButton", true, false) as Button
	if ad_privacy_button != null:
		ad_privacy_button.pressed.connect(func() -> void: ad_privacy_requested.emit())


func is_setting_disabled(setting_id: StringName) -> bool:
	_ensure_settings_loaded()
	return bool(_disabled_settings.get(String(setting_id), false))


## True while this menu's shell is fading in/out; scripts/level.gd's ui_cancel chain and button
## handlers should ignore duplicate input until this clears. Scenes without a shell (the Main Menu
## settings popup) are never mid-transition from this method's point of view.
func is_transitioning() -> bool:
	return _shell != null and _shell.is_transitioning()


func apply_safe_layout(safe_margins: Vector4, viewport_size: Vector2) -> void:
	if _shell != null:
		_shell.apply_safe_layout(safe_margins, viewport_size)


func set_ad_compliance_actions(
	privacy_label: String,
	privacy_visible: bool
) -> void:
	var ad_privacy_button := find_child("AdPrivacyButton", true, false) as Button
	if ad_privacy_button != null:
		ad_privacy_button.text = privacy_label
		ad_privacy_button.visible = privacy_visible


## Shows this overlay's root immediately (so the shell's own fade-in is actually visible), then
## starts the shell's animated fade. The root's own visible flag is what scripts/level.gd's
## `_pause_menu_overlay.visible` checks observe, and what keeps this overlay from acting as a
## permanently-present, screen-covering input blocker while conceptually closed.
func open() -> void:
	show()
	if _shell != null:
		_shell.open()


## Waits for the shell's fade-out before hiding the root -- hiding the root immediately would skip
## the fade entirely, since an invisible ancestor stops all descendant rendering regardless of the
## shell's own modulate/visible state.
func close() -> void:
	if _shell != null:
		await _shell.close()
		# A new open() can supersede this close while it awaits the fade. In that case the shell is
		# visible again and this stale owner coroutine must not hide the freshly reopened overlay.
		if _shell.visible:
			return
	hide()


func _on_setting_button_pressed(cross_out: Control, setting_id: StringName) -> void:
	if _shell != null and _shell.is_transitioning():
		return
	var is_disabled := not is_setting_disabled(setting_id)
	_disabled_settings[String(setting_id)] = is_disabled
	if not PlayerProgress.set_setting_disabled(setting_id, is_disabled):
		push_warning("Ignoring unsupported setting toggle: %s" % setting_id)
	cross_out.visible = is_disabled
	setting_toggled.emit(setting_id, is_disabled)
	if setting_id == SETTING_SOUND_EFFECTS:
		# Emitted first on purpose: owners react to the new state (scripts/level.gd stops its
		# gameplay cues) and only then does the acknowledgement sound, so nothing cuts it off.
		SfxManager.acknowledge_sound_effects_toggle(is_disabled)
	elif setting_id == SETTING_VIBRATION:
		# Preview after enabling and force one final short acknowledgement after disabling. The
		# manager owns that exception so every other request still obeys the saved preference.
		HapticsManager.acknowledge_vibration_toggle(is_disabled)


static func _ensure_settings_loaded() -> void:
	if _settings_loaded_from_save:
		return

	_disabled_settings = PlayerProgress.get_disabled_settings()
	_settings_loaded_from_save = true


## Returns the button's scene-authored CrossOut child if present (scenes/pause_menu.tscn authors
## one per settings button, per UI-003), otherwise builds one at runtime with the same visuals --
## kept as a defensive fallback so scenes/ui/settings_menu.tscn, which does not author its own
## CrossOut children, keeps working unmodified.
func _create_cross_out_marker(button: Button) -> Control:
	var existing := button.get_node_or_null(CROSS_OUT_NAME) as Control
	if existing != null:
		return existing

	var cross_out := Control.new()
	cross_out.name = CROSS_OUT_NAME
	cross_out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross_out.position = Vector2(2, 42)
	cross_out.size = Vector2(96, 14)
	cross_out.pivot_offset = cross_out.size * 0.5
	cross_out.rotation_degrees = -45.0
	cross_out.visible = false
	button.add_child(cross_out)

	var slash := ColorRect.new()
	slash.name = "Slash"
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.color = Color(0.86, 0.08, 0.06, 1.0)
	slash.position = Vector2(3, 3)
	slash.size = cross_out.size - Vector2(6, 6)
	cross_out.add_child(slash)

	return cross_out
