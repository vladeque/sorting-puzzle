extends Control
class_name ShopScreen

signal close_requested
signal closed

enum PresentationMode {
	DESTINATION,
	IN_LEVEL_OVERLAY,
}

const StoreServiceScript := preload("res://scripts/store/store_service.gd")
const ShopPurchaseFlowScript := preload("res://scripts/store/shop_purchase_flow.gd")
const DestinationScreenLayoutScript := preload("res://scripts/destination_screen_layout.gd")
const UIMotionScript := preload("res://scripts/ui_motion.gd")
const BUNDLE_CARD_SCENE := preload("res://scenes/ui/shop_bundle_card.tscn")
const COIN_OFFER_ROW_SCENE := preload("res://scenes/ui/shop_coin_offer_row.tscn")
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const LEADERBOARD_SCENE := "res://scenes/ui/leaderboard_screen.tscn"
const ABILITY_INFO := {
	&"hammer": {
		"name": "Hammer",
		"description": "Instantly clears one matching set of items off the shelves.",
	},
	&"shuffle": {
		"name": "Shuffle",
		"description": "Shuffles shelf items into new spots to help you find a match.",
	},
	&"highlight": {
		"name": "Lantern",
		"description": "Highlights a matching triple you can clear for 15 seconds.",
	},
	&"freezer": {
		"name": "Freezer",
		"description": "Freezes the level timer for 30 seconds.",
	},
}

@export var presentation_mode := PresentationMode.DESTINATION

@onready var _destination_shell := %DestinationShell as Control
@onready var _content_margin := %ContentMargin as MarginContainer
@onready var _title_label := %TitleLabel as Label
@onready var _coin_balance := %CoinBalance as Control
@onready var _shop_scroll := %ShopScroll as ScrollContainer
@onready var _bundles_section := %BundlesSection as VBoxContainer
@onready var _bundles_container := %BundlesContainer as VBoxContainer
@onready var _coin_offers_section := %CoinOffersSection as VBoxContainer
@onready var _coin_offers_container := %CoinOffersContainer as VBoxContainer
@onready var _status_panel := %StatusPanel as Control
@onready var _purchase_dialog := %PurchaseDialog as Control
@onready var _bottom_navigation := %BottomNavigation as MarginContainer
@onready var _overlay_close_button := %OverlayCloseButton as Button

var _store_service = StoreServiceScript.new()
var _offer_views: Array[Control] = []
var _purchase_in_progress := false
var _load_request_serial := 0
var _is_navigating := false
var _is_overlay_transitioning := false


func _ready() -> void:
	PlayerProgress.load_progress()
	_status_panel.connect("retry_pressed", Callable(self, "_load_shop"))
	_overlay_close_button.pressed.connect(_request_overlay_close)
	var is_overlay := presentation_mode == PresentationMode.IN_LEVEL_OVERLAY
	_bottom_navigation.visible = not is_overlay
	_overlay_close_button.visible = is_overlay
	if is_overlay:
		hide()
		modulate = Color.WHITE
	else:
		UIMotionScript.fade_in(self)
		_bottom_navigation.connect("shop_pressed", Callable(self, "_on_shop_tab_reselected"))
		_bottom_navigation.connect("home_pressed", Callable(self, "_return_to_main_menu"))
		_bottom_navigation.connect("leaderboard_pressed", Callable(self, "_open_leaderboard"))
		if _bottom_navigation.has_method("set_active_tab"):
			_bottom_navigation.call("set_active_tab", &"shop")
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_destination_shell.call("set_background_for_chapter", PlayerProgress.get_selected_chapter_id())
	_update_coin_balance()
	_apply_responsive_layout()
	if not is_overlay:
		_load_shop.call_deferred()


func open() -> void:
	if presentation_mode != PresentationMode.IN_LEVEL_OVERLAY or visible or _is_overlay_transitioning:
		return

	_is_overlay_transitioning = true
	_purchase_dialog.hide()
	_purchase_dialog.modulate = Color.WHITE
	_update_coin_balance()
	_apply_responsive_layout()
	show()
	_load_shop.call_deferred()
	var tween := UIMotionScript.fade_in(self)
	await tween.finished
	if is_instance_valid(self):
		_is_overlay_transitioning = false


func close() -> void:
	if presentation_mode != PresentationMode.IN_LEVEL_OVERLAY or not visible or _is_overlay_transitioning:
		return

	_is_overlay_transitioning = true
	var tween := UIMotionScript.fade_out(self)
	await tween.finished
	if not is_instance_valid(self):
		return
	hide()
	modulate = Color.WHITE
	_is_overlay_transitioning = false
	closed.emit()


func is_transitioning() -> bool:
	return _is_overlay_transitioning


func _request_overlay_close() -> void:
	if (
		presentation_mode != PresentationMode.IN_LEVEL_OVERLAY
		or _is_overlay_transitioning
		or _purchase_in_progress
	):
		return
	close_requested.emit()


func handle_back() -> void:
	if _purchase_dialog.visible:
		_purchase_dialog.call("close")
		return
	if presentation_mode == PresentationMode.IN_LEVEL_OVERLAY:
		_request_overlay_close()
		return
	_return_to_main_menu()


func _load_shop() -> void:
	if _purchase_in_progress:
		return

	_load_request_serial += 1
	var request_serial := _load_request_serial
	_clear_offers()
	_set_loading_state()
	var result: Dictionary = await _store_service.load_catalog()
	if request_serial != _load_request_serial:
		return
	if not bool(result.get("ok", false)):
		_set_error_state(str(result.get("error", "Could not load the shop.")))
		return

	for raw_offer in result.get("offers", []) as Array:
		if not (raw_offer is Dictionary):
			continue
		var offer := raw_offer as Dictionary
		if str(offer.get("type", "")) == "bundle":
			_add_bundle_offer(offer)
		else:
			_add_coin_offer(offer)

	if _offer_views.is_empty():
		_set_error_state("No shop offers are available for this region.")
		return

	_status_panel.call("hide_status")
	_shop_scroll.visible = true
	_bundles_section.visible = _bundles_container.get_child_count() > 0
	_coin_offers_section.visible = _coin_offers_container.get_child_count() > 0
	_apply_offer_sizes()


func _add_bundle_offer(offer: Dictionary) -> void:
	var card := BUNDLE_CARD_SCENE.instantiate() as Control
	_bundles_container.add_child(card)
	card.call("set_offer", offer)
	card.connect("purchase_pressed", Callable(self, "_purchase_offer"))
	card.connect("info_requested", Callable(self, "_show_ability_info"))
	_offer_views.append(card)


func _show_ability_info(ability_id: StringName) -> void:
	var info: Dictionary = ABILITY_INFO.get(ability_id, {})
	if info.is_empty():
		return
	_purchase_dialog.call(
		"show_result", str(info.get("name", "")), str(info.get("description", "")), "Got it"
	)


func _add_coin_offer(offer: Dictionary) -> void:
	var row := COIN_OFFER_ROW_SCENE.instantiate() as Control
	_coin_offers_container.add_child(row)
	row.call("set_offer", offer)
	row.connect("purchase_pressed", Callable(self, "_purchase_offer"))
	_offer_views.append(row)


func _purchase_offer(offer_id: StringName) -> void:
	if _purchase_in_progress:
		return

	_purchase_in_progress = true
	_set_overlay_close_locked(true)
	_set_offers_locked(true, offer_id)
	var flow := ShopPurchaseFlowScript.new(_store_service, PlayerProgress)
	var result: Dictionary = await flow.execute(offer_id)
	if not bool(result.get("ok", false)):
		_purchase_dialog.call(
			"show_result",
			"Reward error" if str(result.get("stage", "")) == "grant" else "Purchase unavailable",
			str(result.get("error", "The purchase could not be completed."))
		)
		_purchase_in_progress = false
		_set_overlay_close_locked(false)
		_set_offers_locked(false)
		return

	var grant_result := result.get("grant", {}) as Dictionary
	_update_coin_balance()
	ShopPurchaseFlowScript.play_success_feedback(grant_result)
	_purchase_dialog.call(
		"show_result",
		"Purchase complete",
		_format_reward_message(result.get("rewards", {}) as Dictionary)
	)

	_purchase_in_progress = false
	_set_overlay_close_locked(false)
	await _load_shop()


func _format_reward_message(rewards: Dictionary) -> String:
	var reward_lines := []
	var coins := maxi(int(rewards.get("coins", 0)), 0)
	if coins > 0:
		reward_lines.append("%s coins" % _format_count(coins))

	var abilities := rewards.get("abilities", {}) as Dictionary
	var labels := {
		"hammer": "hammers",
		"shuffle": "shuffles",
		"highlight": "lanterns",
		"freezer": "freezers",
	}
	for ability_id in ["hammer", "shuffle", "highlight", "freezer"]:
		var amount := maxi(int(abilities.get(ability_id, 0)), 0)
		if amount > 0:
			reward_lines.append("%d %s" % [amount, labels[ability_id]])

	return "Mock purchase added:\n%s" % "\n".join(reward_lines)


func _set_offers_locked(is_locked: bool, active_offer_id: StringName = &"") -> void:
	for view in _offer_views:
		if not is_instance_valid(view):
			continue
		var is_active: bool = is_locked and view.call("get_offer_id") == active_offer_id
		view.call("set_shop_locked", is_locked, is_active)


func _set_overlay_close_locked(is_locked: bool) -> void:
	if presentation_mode != PresentationMode.IN_LEVEL_OVERLAY:
		return
	_overlay_close_button.disabled = is_locked
	_overlay_close_button.mouse_default_cursor_shape = (
		Control.CURSOR_ARROW if is_locked else Control.CURSOR_POINTING_HAND
	)


func _clear_offers() -> void:
	for view in _offer_views:
		if is_instance_valid(view):
			view.queue_free()
	_offer_views.clear()


func _set_loading_state() -> void:
	_shop_scroll.visible = false
	_status_panel.call("show_loading", "Loading regional prices…")


func _set_error_state(message: String) -> void:
	_shop_scroll.visible = false
	_status_panel.call("show_error", message)


func _update_coin_balance() -> void:
	_coin_balance.call("set_amount", PlayerProgress.get_coins())


## With no overlay open, `ui_cancel` returns to Main Menu, matching Leaderboard (see
## docs/SCENES.md's "Back/ui_cancel Behavior"). The purchase-result dialog counts as a scoped
## overlay and is closed first if it is showing, rather than also leaving the screen.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	get_viewport().set_input_as_handled()
	handle_back()


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_margins := DestinationScreenLayoutScript.get_safe_area_margins(viewport_size)
	var bottom_reserved := (
		DestinationScreenLayoutScript.get_overlay_bottom_reserved(safe_margins)
		if presentation_mode == PresentationMode.IN_LEVEL_OVERLAY
		else DestinationScreenLayoutScript.get_bottom_reserved(safe_margins)
	)
	DestinationScreenLayoutScript.apply_content_rect(
		_content_margin,
		viewport_size,
		safe_margins,
		bottom_reserved
	)
	if presentation_mode == PresentationMode.DESTINATION:
		DestinationScreenLayoutScript.layout_bottom_navigation(_bottom_navigation, safe_margins)

	_title_label.add_theme_font_size_override(
		"font_size", DestinationScreenLayoutScript.get_title_font_size(viewport_size)
	)
	_apply_offer_sizes()


func _apply_offer_sizes() -> void:
	var is_compact := DestinationScreenLayoutScript.is_compact_viewport(get_viewport_rect().size)
	for view in _offer_views:
		if is_instance_valid(view):
			view.call("set_compact", is_compact)


func _format_count(value: int) -> String:
	var value_text := str(maxi(value, 0))
	var formatted := ""
	while value_text.length() > 3:
		formatted = ",%s%s" % [value_text.right(3), formatted]
		value_text = value_text.substr(0, value_text.length() - 3)
	return value_text + formatted


## Retapping the already-active Shop tab is a no-op (see docs/SCENES.md's "Active-Tab Reselection
## Rule"); catalog refresh stays available only through the status panel's explicit Retry action,
## not a hidden tab-retap convention.
func _on_shop_tab_reselected() -> void:
	pass


func _return_to_main_menu() -> void:
	_begin_navigation(MAIN_MENU_SCENE)


func _open_leaderboard() -> void:
	_begin_navigation(LEADERBOARD_SCENE)


## Ignores a duplicate cross-destination press while a scene transition is already underway, so a
## rapid double-tap on Home/Leaderboard can never call change_scene_to_file() twice, and stops this
## whole screen (every descendant's mouse/touch/keyboard input, not just navigation) from accepting
## further input for the brief window before the deferred scene swap resolves.
func _begin_navigation(scene_path: String) -> void:
	if _is_navigating:
		return

	_is_navigating = true
	process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().change_scene_to_file(scene_path)
