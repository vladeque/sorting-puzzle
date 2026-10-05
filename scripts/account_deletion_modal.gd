extends Control
class_name AccountDeletionModal

## GAME-012 account-deletion modal (docs/ACCOUNT_DELETION_PLAN.md). Composes
## scenes/ui/gameplay_modal_shell.tscn and renders every deletion state from
## `AccountDeletionService.get_state()` and `get_availability()`: the account or local-data
## confirmation, progress, a not-deleted failure, unavailable explanations, the locked retry,
## unconfirmed, cleanup, and unreadable-record states, and the result with **Start New Game**.
##
## Only the confirmation, failure, and unavailable views can be dismissed (close button, Cancel,
## Close, or `ui_cancel`). Every other view keeps the player here until the service settles. The
## host (Main Menu) opens it from Support or at launch, and restarts through the launch router on
## `new_game_started`.

signal closed
signal new_game_started

const DestinationScreenLayoutScript := preload("res://scripts/destination_screen_layout.gd")
const GameplayUIThemeScript := preload("res://scripts/gameplay_ui_theme.gd")
const SupportContactScript := preload("res://scripts/support_contact.gd")
const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")
const ServiceScript := preload("res://scripts/save/account_deletion_service.gd")
const OperationsScript := preload("res://scripts/backend/account_deletion_operations.gd")
const DESTRUCTIVE_STYLE := preload("res://assets/themes/style_box_gameplay_destructive_action.tres")
const POSITIVE_STYLE := preload("res://assets/themes/style_box_green_primary_button.tres")
const DESTRUCTIVE_OUTLINE := Color(0.34, 0.02, 0.02, 0.95)
const POSITIVE_OUTLINE := Color(0.03, 0.25, 0.04, 0.95)
const PREFERRED_SIZE := Vector2(520.0, 760.0)
const CONTENT_HEIGHT := 500.0
const SINGLE_BUTTON_WIDTH := 300.0
const LONG_TITLE_LENGTH := 15

const ACTION_NONE := &""
const ACTION_CLOSE := &"close"
const ACTION_CONFIRM := &"confirm"
const ACTION_RETRY := &"retry"
const ACTION_CONTACT_SUPPORT := &"contact_support"
const ACTION_START_NEW_GAME := &"start_new_game"

const ROLE_DESTRUCTIVE := &"destructive"
const ROLE_POSITIVE := &"positive"

const FAILURE_HEADLINES := {
	OperationsScript.REASON_OFFLINE: "Connect to the internet to delete your account.",
	OperationsScript.REASON_RATE_LIMITED: "Too many attempts. Wait a moment, then try again.",
	OperationsScript.REASON_UNAVAILABLE: "Account deletion is busy right now. Try again in a moment.",
	ServiceScript.REASON_NETWORK_BUSY: "The game is still syncing. Try again in a moment.",
	OperationsScript.REASON_AUTHENTICATION: "We couldn't verify your account. Restart the game, then try again.",
	OperationsScript.REASON_UNSUPPORTED_CLIENT: "Update the game to delete your account.",
	OperationsScript.REASON_NOT_CONFIGURED: "Account deletion isn't available in this version of the game.",
	ServiceScript.REASON_VERSION_CONFLICT: "Your account changed while we were deleting it. Try again.",
	ServiceScript.REASON_ACCOUNT_CHANGED: "Your account changed while we were deleting it. Try again.",
	ServiceScript.REASON_STORAGE: "Your device couldn't save the deletion request. Try again.",
}
## Reasons a new attempt cannot fix; the failure view offers support instead.
const SUPPORT_ONLY_REASONS := [
	OperationsScript.REASON_UNSUPPORTED_CLIENT,
	OperationsScript.REASON_NOT_CONFIGURED,
]

@onready var _shell := %Shell as GameplayModalShell
@onready var _message_content := %MessageContent as Control
@onready var _message_scroll := %MessageScroll as ScrollContainer
@onready var _headline_label := %HeadlineLabel as Label
@onready var _body_label := %BodyLabel as Label
@onready var _reference_label := %ReferenceLabel as Label
@onready var _secondary_button := %SecondaryButton as Button
@onready var _primary_button := %PrimaryButton as Button

var _service
var _presented_state: Dictionary = {}
var _presented_availability: Dictionary = {}
var _view := {}
var _waiting := false
var _is_closing := false
## Set once this modal has asked the service to delete, so a failure from an earlier visit to
## Support is never shown as this attempt's result.
var _attempted := false
var _requested_kind := ""


## Optional before adding to the tree; defaults to PlayerProgress's service.
func setup(service) -> void:
	_service = service


func _ready() -> void:
	_shell.set_preferred_size(PREFERRED_SIZE)
	_shell.set_content_region_height(CONTENT_HEIGHT)
	_message_content.reparent(_shell.get_content_region(), false)
	_secondary_button.reparent(_shell.get_action_row(), false)
	_primary_button.reparent(_shell.get_action_row(), false)
	_shell.close_requested.connect(_request_close)
	_primary_button.pressed.connect(func() -> void: _perform(_view.get("primary", ACTION_NONE)))
	_secondary_button.pressed.connect(func() -> void: _perform(_view.get("secondary", ACTION_NONE)))
	if _service == null:
		var player_progress := get_node_or_null(^"/root/PlayerProgress")
		if player_progress != null:
			_service = player_progress.call("get_account_deletion_service")
	if _service != null:
		_service.state_changed.connect(_on_service_state_changed)
		if str(_service.get_availability().get("kind", "")) == ServiceScript.AVAILABILITY_REGISTRATION_PENDING:
			_service.request_registration_resolution()
	refresh()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_shell.hide()
	open.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Back never leaves an unsettled or finished deletion, so it is consumed in every state.
	get_viewport().set_input_as_handled()
	_request_close()


func open() -> void:
	show()
	_apply_responsive_layout()
	_shell.show()
	_shell.open()


func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	await _shell.close()
	closed.emit()
	queue_free()


func is_closable() -> bool:
	return bool(_view.get("closable", false)) and not _is_busy()


func get_view() -> Dictionary:
	return _view.duplicate(true)


func refresh() -> void:
	if _service == null:
		return
	present(_service.get_state(), _service.get_availability())


## Renders one deletion state. Captures and tests call it directly with synthetic states.
func present(state: Dictionary, availability: Dictionary) -> void:
	_presented_state = state.duplicate(true)
	_presented_availability = availability.duplicate(true)
	_view = describe(state, availability)
	_apply_view()


## The view for a service state: title, headline, body, optional support reference, closability,
## and the primary/secondary actions with their labels.
func describe(state: Dictionary, availability: Dictionary) -> Dictionary:
	var phase := str(state.get("phase", ServiceScript.PHASE_IDLE))
	var kind := str(state.get("kind", ""))
	if kind.is_empty():
		kind = _requested_kind
	var local := kind == ServiceScript.KIND_LOCAL_DATA
	var busy := bool(state.get("busy", false)) or _waiting
	var failure := state.get("failure", {}) as Dictionary
	match phase:
		ServiceScript.PHASE_IDLE:
			if _waiting:
				return _progress_view(local)
			if _attempted and not failure.is_empty():
				return _failure_view(str(failure.get("reason", "")), local)
			return _availability_view(availability)
		ServiceScript.PHASE_PREPARING, ServiceScript.PHASE_SUBMITTING:
			return _progress_view(local)
		ServiceScript.PHASE_RETRY_PENDING:
			if busy:
				return _progress_view(local)
			return _view_of(
				"NOT CONFIRMED",
				"We haven't heard back about your deletion yet.",
				tr("deletion.not_confirmed.body"),
				false, ACTION_RETRY, "Try Again", ROLE_POSITIVE, ACTION_CONTACT_SUPPORT, "Get Help",
				_reference_text(state)
			)
		ServiceScript.PHASE_UNCONFIRMED:
			if busy:
				return _progress_view(local)
			return _view_of(
				"STATUS UNCONFIRMED",
				"Deletion status unconfirmed",
				tr("deletion.unconfirmed.body"),
				false, ACTION_CONTACT_SUPPORT, "Get Help", ROLE_POSITIVE, ACTION_RETRY, "Check Again",
				_reference_text(state)
			)
		ServiceScript.PHASE_CLEANING:
			if busy:
				return _progress_view(local)
			return _view_of(
				"FINISHING UP",
				"Your local game data couldn't be fully deleted yet." if local
				else "Account deletion accepted; finishing cleanup.",
				"Some game data couldn't be removed from this device yet. Try again to finish.",
				false, ACTION_RETRY, "Try Again", ROLE_POSITIVE, ACTION_NONE, ""
			)
		ServiceScript.PHASE_READY, ServiceScript.PHASE_ACTIVATING:
			if busy:
				return _view_of(
					"NEW GAME", "Starting a new game...", "This only takes a moment.",
					false, ACTION_NONE, "", ROLE_POSITIVE, ACTION_NONE, ""
				)
			return _result_view(state, local)
		ServiceScript.PHASE_RECORD_CORRUPT:
			return _view_of(
				"STATUS UNKNOWN",
				"We couldn't read the deletion status on this device.",
				"To keep your data safe, the game stays locked. Contact support for help.",
				false, ACTION_CONTACT_SUPPORT, "Get Help", ROLE_POSITIVE, ACTION_NONE, ""
			)
	return _progress_view(local)


static func format_deadline(timestamp: String) -> String:
	if not LocalSaveCodecScript.is_timestamp(timestamp):
		return ""
	var unix_time := LocalSaveCodecScript.unix_from_timestamp(timestamp)
	var bias_minutes := int(Time.get_time_zone_from_system().get("bias", 0))
	var date := Time.get_date_dict_from_unix_time(unix_time + bias_minutes * 60)
	return GameText.format_date(date)


func _availability_view(availability: Dictionary) -> Dictionary:
	var kind := str(availability.get("kind", ""))
	var reason := str(availability.get("reason", ""))
	match kind:
		ServiceScript.AVAILABILITY_ACCOUNT:
			_requested_kind = ServiceScript.KIND_ACCOUNT
			return _view_of(
				"DELETE ACCOUNT",
				"This permanently deletes your account.",
				tr("deletion.confirm.body"),
				true, ACTION_CONFIRM, "Delete Account", ROLE_DESTRUCTIVE, ACTION_CLOSE, "Cancel"
			)
		ServiceScript.AVAILABILITY_LOCAL_DATA:
			_requested_kind = ServiceScript.KIND_LOCAL_DATA
			return _view_of(
				"DELETE GAME DATA",
				"This deletes your game data on this device.",
				tr("deletion.local_confirm.body"),
				true, ACTION_CONFIRM, "Delete Data", ROLE_DESTRUCTIVE, ACTION_CLOSE, "Cancel"
			)
		ServiceScript.AVAILABILITY_REGISTRATION_PENDING:
			return _view_of(
				"DELETE ACCOUNT",
				"Your account is still being set up.",
				"Connect to the internet and try again in a moment. Nothing was deleted.",
				true, ACTION_CLOSE, "Close", ROLE_POSITIVE, ACTION_NONE, ""
			)
	match reason:
		ServiceScript.REASON_SIGNED_OUT_ACCOUNT:
			return _view_of(
				"DELETE ACCOUNT",
				"Sign in to the account you want to delete.",
				"If you can't sign in, contact support for help.",
				true, ACTION_CONTACT_SUPPORT, "Get Help", ROLE_POSITIVE, ACTION_CLOSE, "Close"
			)
		ServiceScript.REASON_STORAGE:
			return _view_of(
				"DELETE ACCOUNT",
				"Your game data couldn't be read.",
				"Restart the game, then try again. Nothing was deleted.",
				true, ACTION_CLOSE, "Close", ROLE_POSITIVE, ACTION_NONE, ""
			)
	return _view_of(
		"DELETE ACCOUNT",
		"Account deletion isn't available in this version of the game.",
		"Update the game, or contact support for help deleting your account. Nothing was deleted.",
		true, ACTION_CONTACT_SUPPORT, "Get Help", ROLE_POSITIVE, ACTION_CLOSE, "Close"
	)


func _failure_view(reason: String, local: bool) -> Dictionary:
	var headline := str(FAILURE_HEADLINES.get(
		reason,
		"We couldn't delete your account. Try again later or contact support."
	))
	if local and (reason == ServiceScript.REASON_STORAGE or not FAILURE_HEADLINES.has(reason)):
		headline = "Your game data couldn't be deleted. Try again."
	if SUPPORT_ONLY_REASONS.has(reason):
		return _view_of(
			"NOT DELETED", headline, "Nothing was deleted, and you can keep playing.",
			true, ACTION_CONTACT_SUPPORT, "Get Help", ROLE_POSITIVE, ACTION_CLOSE, "Close"
		)
	return _view_of(
		"NOT DELETED", headline, "Nothing was deleted, and you can keep playing.",
		true, ACTION_CONFIRM, "Try Again", ROLE_POSITIVE, ACTION_CLOSE, "Close"
	)


func _progress_view(local: bool) -> Dictionary:
	return _view_of(
		"DELETE GAME DATA" if local else "DELETE ACCOUNT",
		"Deleting your game data..." if local else "Deleting your account...",
		"Keep the game open. This only takes a moment.",
		false, ACTION_NONE, "", ROLE_POSITIVE, ACTION_NONE, ""
	)


func _result_view(state: Dictionary, local: bool) -> Dictionary:
	var failure := state.get("failure", {}) as Dictionary
	var activation_note := ""
	if str(failure.get("reason", "")) == ServiceScript.REASON_STORAGE:
		activation_note = "\n\n" + tr("deletion.new_game_failed")
	if local:
		return _view_of(
			"DATA DELETED",
			"Your local game data was deleted.",
			tr("deletion.done_local.body") + activation_note,
			false, ACTION_START_NEW_GAME, "Start New Game", ROLE_POSITIVE, ACTION_NONE, ""
		)
	var deadline := format_deadline(str((state.get("receipt", {}) as Dictionary).get("complete_by", "")))
	var body := tr("deletion.accepted.body")
	if not deadline.is_empty():
		body = tr("deletion.accepted.body_deadline") % GameText.isolate_ltr(deadline)
	return _view_of(
		"DELETION ACCEPTED",
		"Your account is no longer accessible.",
		body + activation_note,
		false, ACTION_START_NEW_GAME, "Start New Game", ROLE_POSITIVE, ACTION_NONE, ""
	)


func _view_of(
	title: String,
	headline: String,
	body: String,
	closable: bool,
	primary: StringName,
	primary_text: String,
	primary_role: StringName,
	secondary: StringName,
	secondary_text: String,
	reference: String = ""
) -> Dictionary:
	return {
		"title": title,
		"headline": headline,
		"body": body,
		"reference": reference,
		"closable": closable,
		"primary": primary,
		"primary_text": primary_text,
		"primary_role": primary_role,
		"secondary": secondary,
		"secondary_text": secondary_text,
	}


func _reference_text(state: Dictionary) -> String:
	var reference := str((state.get("support_reference", {}) as Dictionary).get("operation_id", ""))
	return tr("deletion.reference") % GameText.isolate_ltr(reference) if not reference.is_empty() else ""


func _apply_view() -> void:
	if not is_node_ready():
		return
	var title := str(_view.get("title", ""))
	_shell.configure(title, title.length() >= LONG_TITLE_LENGTH)
	_shell.set_close_available(bool(_view.get("closable", false)))
	_headline_label.text = str(_view.get("headline", ""))
	_body_label.text = str(_view.get("body", ""))
	var reference := str(_view.get("reference", ""))
	_reference_label.text = reference
	_reference_label.visible = not reference.is_empty()
	var primary := _view.get("primary", ACTION_NONE) as StringName
	var secondary := _view.get("secondary", ACTION_NONE) as StringName
	_primary_button.visible = primary != ACTION_NONE
	_primary_button.text = str(_view.get("primary_text", ""))
	_secondary_button.visible = secondary != ACTION_NONE
	_secondary_button.text = str(_view.get("secondary_text", ""))
	var destructive := (_view.get("primary_role", ROLE_POSITIVE) as StringName) == ROLE_DESTRUCTIVE
	var primary_style: StyleBox = DESTRUCTIVE_STYLE if destructive else POSITIVE_STYLE
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		_primary_button.add_theme_stylebox_override(style_name, primary_style)
	_primary_button.add_theme_color_override(
		"font_outline_color",
		DESTRUCTIVE_OUTLINE if destructive else POSITIVE_OUTLINE
	)
	var busy := _is_busy()
	_primary_button.disabled = busy
	_secondary_button.disabled = busy
	_message_scroll.scroll_vertical = 0
	_apply_responsive_layout()


func _perform(action: StringName) -> void:
	if _is_busy() or _is_closing or _service == null:
		return
	match action:
		ACTION_CLOSE:
			_request_close()
		ACTION_CONFIRM:
			_attempted = true
			_set_waiting(true)
			if _requested_kind == ServiceScript.KIND_LOCAL_DATA:
				await _service.request_local_data_deletion()
			else:
				await _service.request_account_deletion()
			_set_waiting(false)
		ACTION_RETRY:
			_set_waiting(true)
			await _service.retry()
			_set_waiting(false)
		ACTION_START_NEW_GAME:
			_set_waiting(true)
			var state: Dictionary = _service.start_new_game()
			_set_waiting(false)
			if str(state.get("phase", "")) == ServiceScript.PHASE_IDLE:
				new_game_started.emit()
		ACTION_CONTACT_SUPPORT:
			_open_support_email()


func _request_close() -> void:
	if is_closable():
		close()


func _set_waiting(waiting: bool) -> void:
	_waiting = waiting
	refresh()


func _is_busy() -> bool:
	return _waiting or (_service != null and bool(_service.get_state().get("busy", false)))


func _on_service_state_changed(_state: Dictionary) -> void:
	refresh()


## Opens a prefilled support e-mail with only safe references: the deletion operation, the last
## server correlation id, and the public player id. Never a token, payload, or save file.
func _open_support_email() -> void:
	var state: Dictionary = _service.get_state() if _service != null else {}
	var reference := state.get("support_reference", {}) as Dictionary
	var lines := PackedStringArray([
		tr("deletion.email.body"),
		"",
		tr("support.email.status") % str(state.get("phase", "")),
	])
	for entry in [
		[tr("support.email.deletion_reference"), "operation_id"],
		[tr("support.email.server_reference"), "correlation_id"],
		[tr("support.email.player_id"), "player_id"],
	]:
		var value := str(reference.get(entry[1], ""))
		if not value.is_empty():
			lines.append("%s: %s" % [entry[0], value])
	SupportContactScript.open_email(tr("deletion.email.subject"), "\n".join(lines) + "\n")


func _apply_responsive_layout() -> void:
	if _shell == null or not is_node_ready():
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var safe_margins := DestinationScreenLayoutScript.get_safe_area_margins(viewport_size)
	_shell.apply_safe_layout(safe_margins, viewport_size)
	var single := _primary_button.visible != _secondary_button.visible
	for button in [_primary_button, _secondary_button]:
		var minimum := (button as Button).custom_minimum_size
		minimum.x = SINGLE_BUTTON_WIDTH if single else 180.0
		(button as Button).custom_minimum_size = minimum
		(button as Button).size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER if single else Control.SIZE_EXPAND_FILL
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		if not _presented_state.is_empty():
			present(_presented_state, _presented_availability)
