extends Control

const PROFILE_MENU_SCENE := preload("res://scenes/ui/profile_menu.tscn")
const SETTINGS_MENU_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const LANGUAGE_SELECTION_MODAL_SCENE := preload("res://scenes/ui/language_selection_modal.tscn")
const SUPPORT_SCREEN_SCENE := preload("res://scenes/ui/support_screen.tscn")
const ACCOUNT_DELETION_MODAL_SCENE := preload("res://scenes/ui/account_deletion_modal.tscn")
const REWARD_CHEST_MENU_SCENE := preload("res://scenes/ui/reward_chest_menu.tscn")
const CHAPTER_SELECTION_SCENE := preload("res://scenes/ui/chapter_selection_screen.tscn")
const SfxCatalogScript := preload("res://scripts/audio/sfx_catalog.gd")
const HapticsCatalogScript := preload("res://scripts/haptics/haptics_catalog.gd")
const MenuBackgroundResolverScript := preload("res://scripts/chapters/menu_background_resolver.gd")
const UIMotionScript := preload("res://scripts/ui_motion.gd")
const RewardedLifeClientScript := preload("res://scripts/ads/rewarded_life_client.gd")
const StoreServiceScript := preload("res://scripts/store/store_service.gd")
const ShopPurchaseFlowScript := preload("res://scripts/store/shop_purchase_flow.gd")
const PRODUCTION_MENU_SCENE := "res://scenes/main_menu.tscn"
const SHOP_SCENE := "res://scenes/ui/shop_screen.tscn"
const LEADERBOARD_SCENE := "res://scenes/ui/leaderboard_screen.tscn"
const TOP_BAR_HEIGHT := 86.0
const TOP_MARGIN := 28.0
const TOP_SIDE_MARGIN := 24.0
const CAMERA_CUTOUT_PADDING := 12.0
const STATUS_CENTER_VISUAL_OVERFLOW := 6.0
const CUTOUT_LAYOUT_TOLERANCE := 0.5
const PROFILE_WIDGET_WIDTH := 76.0
const REWARD_CHEST_SIZE := Vector2(116.0, 136.0)
const REWARD_CHEST_TOP_GAP := 72.0
const STARTER_BADGE_SIZE := Vector2(142.0, 164.0)
## The shop sign's bracket sits this far above the reward chest's top, so the hanging board lines
## up with the chest art.
const STARTER_BADGE_RAISE := 30.0
const STARTER_BADGE_GAP := 16.0
const STARTER_BUNDLE_ID := "starter_bundle"
const BOTTOM_BAR_HEIGHT := 245.0
const BOTTOM_MARGIN := 112.0
const SIDE_MARGIN := 48.0
const LEVEL_BUTTON_MAX_WIDTH := 420.0
const CHAPTER_BUTTON_MAX_WIDTH := 280.0
const BOTTOM_NAVIGATION_HEIGHT := 96.0
const LIFE_STATUS_REFRESH_SECONDS := 1.0
const MAIN_MENU_OVERLAY_Z_INDEX := 100
const AD_PRIVACY_POLICY_SETTING := "application/config/ad_privacy_policy_url"
const CHAPTER_SELECTION_ENABLED_SETTING := "application/config/chapter_selection_enabled"

@onready var _background := %Background as TextureRect
@onready var _top_status_bar := %TopStatusBar as MarginContainer
@onready var _reward_chest := %RewardChest as Control
@onready var _starter_badge = %StarterBundleBadge
@onready var _starter_modal = %StarterBundleOfferModal
@onready var _house_reward_origin := %HouseRewardOrigin as Control
@onready var _reward_star_flyer := %RewardStarFlyer as Control
@onready var _chest_ceremony := %RewardChestOpenCeremony as Control
@onready var _purchase_reward_sequence := %PurchaseRewardSequence as Control
@onready var _bottom_bar := %BottomBar as MarginContainer
@onready var _level_button := %LevelButton as Button
@onready var _chapter_button := %ChapterButton as Button
@onready var _bottom_navigation := %BottomNavigation as MarginContainer
@onready var _leaderboard_reward_dialog := %LeaderboardRewardDialog as Control
@onready var _out_of_lives_menu := %OutOfLivesMenu as OutOfLivesMenu
@onready var _top_status := %TopStatusBar.get_node("MainMenuTopStatus") as HBoxContainer
@onready var _profile_button := %TopStatusBar.get_node("MainMenuTopStatus/ProfileWidget") as Button
@onready var _settings_button := %TopStatusBar.get_node("MainMenuTopStatus/SettingsWidget/SettingsButton") as Button
@onready var _profile_avatar_view := %TopStatusBar.get_node("MainMenuTopStatus/ProfileWidget/ProfileAvatarView") as ProfileAvatarView
@onready var _coin_shortcut := %TopStatusBar.get_node("MainMenuTopStatus/CoinsWidget") as Button
@onready var _life_shortcut := %TopStatusBar.get_node("MainMenuTopStatus/LivesWidget") as Button
@onready var _life_count_label := %TopStatusBar.get_node("MainMenuTopStatus/LivesWidget/LifeCount") as Label
@onready var _life_status_label := %TopStatusBar.get_node("MainMenuTopStatus/LivesWidget/LifeStatus") as Label

var _life_status_refresh_time := 0.0
var _profile_menu: Control
var _settings_menu: Control
var _language_selection_modal: Control
var _support_screen: Control
var _account_deletion_modal: Control
var _reward_chest_menu: Control
var _chapter_selection_screen: Control
var _animated_reward_stars := 0
var _animated_reward_goal_index := 0
## While positive, the chest widget shows this filled goal instead of wrapping to the next one, until
## the opening sequence has delivered its rewards.
var _chest_full_hold_goal := 0
## `{"coins": int, "abilities": {ability_id: count}}` for every goal the star flight has filled.
var _chest_ceremony_rewards := {}
## Coins PlayerProgress already granted for filled goals that the opening sequence has not flown
## into the counter yet. The displayed balance subtracts them so it can count up on each landing.
var _undisplayed_chest_coins := 0
var _chest_ceremony_coin_holdback := 0
## The same hold-back for a Starter Bundle purchase, counted up by the purchase reward sequence. It
## is separate from the chest's because a purchase can land while the star flight still holds coins.
var _undisplayed_purchase_coins := 0
var _purchase_coin_holdback := 0
## True when the star flight filled a goal while a purchase reward sequence was playing; the chest
## opening then waits for that sequence to finish instead of playing over it.
var _chest_ceremony_deferred := false
var _is_navigating := false
var _life_recovery_in_progress := false
var _rewarded_life_client
var _rewarded_life_action_state := OutOfLivesMenu.REWARDED_STATE_UNAVAILABLE
var _rewarded_life_prepare_in_progress := false
## True only while the lives modal is open on top of an interrupted campaign launch. The top-status
## lives widget opens the same modal informationally, and that entry point must never resume a
## launch or be dismissed out from under the player when a countdown restores a life.
var _out_of_lives_launch_pending := false
var _chapter_selection_enabled := false
var _starter_store_service = StoreServiceScript.new()
var _starter_offer := {}
var _starter_catalog_serial := 0
var _starter_purchase_in_progress := false


func _ready() -> void:
	UIMotionScript.fade_in(self)
	PlayerProgress.load_progress()
	PlayerProgress.refresh_lives()
	var pending_reward_animation := PlayerProgress.consume_pending_reward_chest_animation()
	var pending_leaderboard_reward := PlayerProgress.consume_pending_leaderboard_reward()
	_chapter_selection_enabled = bool(ProjectSettings.get_setting(
		CHAPTER_SELECTION_ENABLED_SETTING,
		false
	))
	_chapter_button.visible = _chapter_selection_enabled
	_chapter_button.disabled = not _chapter_selection_enabled
	_level_button.pressed.connect(_launch_campaign_level)
	if _chapter_selection_enabled:
		_chapter_button.pressed.connect(_open_chapter_selection)
	_profile_button.pressed.connect(_open_profile_menu)
	_settings_button.pressed.connect(_open_settings_menu)
	_coin_shortcut.pressed.connect(_open_shop)
	_life_shortcut.pressed.connect(_open_out_of_lives_menu.bind(false))
	_out_of_lives_menu.close_requested.connect(_on_out_of_lives_close_requested)
	_out_of_lives_menu.purchase_requested.connect(_on_out_of_lives_purchase_requested)
	_out_of_lives_menu.rewarded_ad_requested.connect(_on_out_of_lives_rewarded_ad_requested)
	_setup_rewarded_life_client()
	var ad_service: Node = _get_ad_service()
	var privacy_requirement_callback := Callable(
		self,
		"_on_privacy_options_requirement_changed"
	)
	if ad_service != null and not ad_service.is_connected(
		"privacy_options_requirement_changed",
		privacy_requirement_callback
	):
		ad_service.connect("privacy_options_requirement_changed", privacy_requirement_callback)
	if _reward_chest.has_signal("chest_pressed"):
		_reward_chest.connect("chest_pressed", Callable(self, "_open_reward_chest_menu"))
	_chest_ceremony.connect("coin_arrived", Callable(self, "_on_chest_ceremony_coin_arrived"))
	_chest_ceremony.connect("ability_arrived", Callable(self, "_on_chest_ceremony_ability_arrived"))
	_chest_ceremony.connect("finished", Callable(self, "_on_chest_ceremony_finished"))
	_purchase_reward_sequence.connect("coin_arrived", Callable(self, "_on_purchase_reward_coin_arrived"))
	_purchase_reward_sequence.connect("ability_arrived", Callable(self, "_on_purchase_reward_ability_arrived"))
	_purchase_reward_sequence.connect("finished", Callable(self, "_on_purchase_reward_finished"))
	_starter_badge.pressed.connect(_open_starter_bundle_offer)
	_starter_modal.buy_requested.connect(_buy_starter_bundle)
	_starter_modal.close_requested.connect(_close_starter_bundle_offer)
	_bottom_navigation.connect("shop_pressed", Callable(self, "_open_shop"))
	_bottom_navigation.connect("leaderboard_pressed", Callable(self, "_open_leaderboard"))
	_bottom_navigation.connect("home_pressed", Callable(self, "_on_home_tab_reselected"))
	if _bottom_navigation.has_method("set_active_tab"):
		_bottom_navigation.call("set_active_tab", &"home")
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_update_profile_customization()
	_update_coin_balance()
	_update_lives_status()
	if pending_reward_animation.is_empty():
		_update_reward_chest_status()
	else:
		_prepare_pending_reward_animation(pending_reward_animation)
	_update_level_button()
	_update_chapter_button()
	_update_chapter_background(PlayerProgress.get_selected_chapter_id())
	_leaderboard_reward_dialog.z_index = MAIN_MENU_OVERLAY_Z_INDEX
	_out_of_lives_menu.z_index = MAIN_MENU_OVERLAY_Z_INDEX
	_starter_modal.z_index = MAIN_MENU_OVERLAY_Z_INDEX + 1
	_chest_ceremony.z_index = MAIN_MENU_OVERLAY_Z_INDEX + 2
	_purchase_reward_sequence.z_index = MAIN_MENU_OVERLAY_Z_INDEX + 2
	_apply_responsive_layout()
	if not pending_reward_animation.is_empty():
		_play_pending_reward_animation.call_deferred(pending_reward_animation)
	if not pending_leaderboard_reward.is_empty():
		var weekly_coin_reward := maxi(int(pending_leaderboard_reward.get("coin_reward", 0)), 0)
		_leaderboard_reward_dialog.call(
			"show_reward",
			int(pending_leaderboard_reward.get("rank", 0)),
			weekly_coin_reward
		)
		# A weekly reward is a visible accepted payout being presented, not initial balance
		# population -- consume_pending_leaderboard_reward() only returns it once.
		if weekly_coin_reward > 0:
			SfxManager.play(SfxCatalogScript.EVENT_COIN_GAIN)
			HapticsManager.play(HapticsCatalogScript.EVENT_LEADERBOARD_REWARD)
	call_deferred("_prepare_rewarded_life")
	call_deferred("_refresh_starter_bundle_offer")
	if PlayerProgress.is_account_deletion_blocking():
		# GAME-012: an unsettled or finished deletion resumes at launch, above everything else.
		_open_account_deletion_modal.call_deferred()


func _process(delta: float) -> void:
	_life_status_refresh_time += delta
	if _life_status_refresh_time < LIFE_STATUS_REFRESH_SECONDS:
		return

	_life_status_refresh_time = fmod(_life_status_refresh_time, LIFE_STATUS_REFRESH_SECONDS)
	_update_lives_status()
	_refresh_out_of_lives_offer()
	_update_level_button()
	_update_chapter_button()


## Closes whichever scoped overlay is currently open, one per press. Chapter Selection and Support
## own their own `ui_cancel` handling, so this skips them rather than also closing Settings beneath
## Support. With no overlay open, `ui_cancel` intentionally does nothing -- Main Menu must not quit
## or navigate unexpectedly without a separately approved exit flow (see docs/SCENES.md's
## "Back/ui_cancel Behavior").
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# The account-deletion modal owns `ui_cancel` and never lets it reach anything beneath.
	if is_instance_valid(_account_deletion_modal):
		return
	# Back behaves like a tap while the chest opens or a purchase reward plays: it advances the
	# sequence instead of closing whatever overlay sits underneath it.
	if _chest_ceremony.visible:
		get_viewport().set_input_as_handled()
		_chest_ceremony.call("advance")
		return
	if _purchase_reward_sequence.visible:
		get_viewport().set_input_as_handled()
		_purchase_reward_sequence.call("advance")
		return
	if _starter_modal.visible:
		get_viewport().set_input_as_handled()
		_starter_modal.request_close()
		return
	if is_instance_valid(_chapter_selection_screen):
		return
	if is_instance_valid(_support_screen):
		return
	if is_instance_valid(_language_selection_modal):
		return

	if _out_of_lives_menu.visible:
		get_viewport().set_input_as_handled()
		if not _out_of_lives_menu.is_transitioning():
			_close_out_of_lives_menu()
	elif is_instance_valid(_profile_menu):
		get_viewport().set_input_as_handled()
		_profile_menu.call("close")
	elif is_instance_valid(_settings_menu):
		get_viewport().set_input_as_handled()
		_close_settings_menu()
	elif is_instance_valid(_reward_chest_menu):
		get_viewport().set_input_as_handled()
		_reward_chest_menu.call("close")
	elif _leaderboard_reward_dialog.visible:
		get_viewport().set_input_as_handled()
		_leaderboard_reward_dialog.call("close")


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_margins := _get_safe_area_margins(viewport_size)
	var display_cutouts := _get_display_cutouts(viewport_size)
	_layout_top_status_bar(safe_margins, viewport_size, display_cutouts)
	_layout_reward_chest(safe_margins)
	_layout_starter_bundle_badge(safe_margins, viewport_size)
	_layout_bottom_navigation(safe_margins)
	_out_of_lives_menu.apply_safe_layout(safe_margins, viewport_size)
	_starter_modal.apply_safe_layout(safe_margins, viewport_size)
	safe_margins = DestinationScreenLayout.logical_safe_margins(_bottom_bar, safe_margins)
	_bottom_bar.anchor_left = 0.0
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_left = safe_margins.x + SIDE_MARGIN
	_bottom_bar.offset_top = -(BOTTOM_MARGIN + BOTTOM_BAR_HEIGHT + maxf(safe_margins.w, 0.0))
	_bottom_bar.offset_right = -(safe_margins.z + SIDE_MARGIN)
	_bottom_bar.offset_bottom = -(BOTTOM_MARGIN + maxf(safe_margins.w, 0.0))

	var available_width := maxf(viewport_size.x - safe_margins.x - safe_margins.z - SIDE_MARGIN * 2.0, 1.0)
	var button_minimum_size := _level_button.custom_minimum_size
	button_minimum_size.x = minf(LEVEL_BUTTON_MAX_WIDTH, available_width)
	_level_button.custom_minimum_size = button_minimum_size
	var chapter_minimum_size := _chapter_button.custom_minimum_size
	chapter_minimum_size.x = minf(CHAPTER_BUTTON_MAX_WIDTH, available_width)
	_chapter_button.custom_minimum_size = chapter_minimum_size


func _layout_bottom_navigation(safe_margins: Vector4) -> void:
	if _bottom_navigation == null:
		return

	var safe_bottom := maxf(safe_margins.w, 0.0)
	_bottom_navigation.anchor_left = 0.0
	_bottom_navigation.anchor_top = 1.0
	_bottom_navigation.anchor_right = 1.0
	_bottom_navigation.anchor_bottom = 1.0
	_bottom_navigation.offset_left = 0.0
	_bottom_navigation.offset_top = -(BOTTOM_NAVIGATION_HEIGHT + safe_bottom)
	_bottom_navigation.offset_right = 0.0
	_bottom_navigation.offset_bottom = 0.0
	if _bottom_navigation.has_method("set_safe_bottom_margin"):
		_bottom_navigation.call("set_safe_bottom_margin", safe_bottom)


func _layout_top_status_bar(
	safe_margins: Vector4,
	viewport_size: Vector2,
	display_cutouts: Array[Rect2]
) -> void:
	# Cutouts are physical; mirror them into the same authored space as the bar offsets.
	safe_margins = DestinationScreenLayout.logical_safe_margins(_top_status_bar, safe_margins)
	if _top_status_bar.is_layout_rtl():
		display_cutouts = display_cutouts.duplicate()
		for index in display_cutouts.size():
			var cutout := display_cutouts[index]
			cutout.position.x = viewport_size.x - cutout.end.x
			display_cutouts[index] = cutout
	var bar_left := safe_margins.x + TOP_SIDE_MARGIN
	var bar_right := viewport_size.x - safe_margins.z - TOP_SIDE_MARGIN
	var bar_width := maxf(bar_right - bar_left, 0.0)
	var bar_center_x := (bar_left + bar_right) * 0.5
	var default_bar_rect := Rect2(
		Vector2(bar_left, TOP_MARGIN),
		Vector2(bar_width, TOP_BAR_HEIGHT)
	)
	var required_center_exclusion := 0.0
	var cutout_fallback_top := TOP_MARGIN

	for cutout: Rect2 in display_cutouts:
		var padded_cutout := cutout.grow(CAMERA_CUTOUT_PADDING)
		if not padded_cutout.intersects(default_bar_rect):
			continue

		var farthest_horizontal_edge := maxf(
			absf(padded_cutout.position.x - bar_center_x),
			absf(padded_cutout.end.x - bar_center_x)
		)
		required_center_exclusion = maxf(
			required_center_exclusion,
			(farthest_horizontal_edge + STATUS_CENTER_VISUAL_OVERFLOW) * 2.0
		)
		cutout_fallback_top = maxf(cutout_fallback_top, padded_cutout.end.y)

	var actual_center_exclusion := 0.0
	if _top_status.has_method("set_center_exclusion_width"):
		actual_center_exclusion = float(
			_top_status.call("set_center_exclusion_width", required_center_exclusion, bar_width)
		)

	var bar_top := TOP_MARGIN
	if required_center_exclusion > actual_center_exclusion + CUTOUT_LAYOUT_TOLERANCE:
		bar_top = cutout_fallback_top
		if _top_status.has_method("set_center_exclusion_width"):
			_top_status.call("set_center_exclusion_width", 0.0, bar_width)

	_top_status_bar.anchor_left = 0.0
	_top_status_bar.anchor_top = 0.0
	_top_status_bar.anchor_right = 1.0
	_top_status_bar.anchor_bottom = 0.0
	_top_status_bar.offset_left = bar_left
	_top_status_bar.offset_top = bar_top
	_top_status_bar.offset_right = -(safe_margins.z + TOP_SIDE_MARGIN)
	_top_status_bar.offset_bottom = bar_top + TOP_BAR_HEIGHT


func _layout_reward_chest(safe_margins: Vector4) -> void:
	if _reward_chest == null:
		return
	safe_margins = DestinationScreenLayout.logical_safe_margins(_reward_chest, safe_margins)

	var centered_left := safe_margins.x + TOP_SIDE_MARGIN + ((PROFILE_WIDGET_WIDTH - REWARD_CHEST_SIZE.x) * 0.5)
	var left := maxf(centered_left, safe_margins.x + 26.0)
	var top := _top_status_bar.offset_top + PROFILE_WIDGET_WIDTH + REWARD_CHEST_TOP_GAP
	_reward_chest.anchor_left = 0.0
	_reward_chest.anchor_top = 0.0
	_reward_chest.anchor_right = 0.0
	_reward_chest.anchor_bottom = 0.0
	_reward_chest.offset_left = left
	_reward_chest.offset_top = top
	_reward_chest.offset_right = left + REWARD_CHEST_SIZE.x
	_reward_chest.offset_bottom = top + REWARD_CHEST_SIZE.y


func _layout_starter_bundle_badge(safe_margins: Vector4, viewport_size: Vector2) -> void:
	safe_margins = DestinationScreenLayout.logical_safe_margins(_starter_badge, safe_margins)
	# The bracket's wall plate mounts on the safe right edge itself, not inside the side margin.
	var left := viewport_size.x - safe_margins.z - STARTER_BADGE_SIZE.x
	var top := _reward_chest.offset_top - STARTER_BADGE_RAISE
	if left < _reward_chest.offset_right + STARTER_BADGE_GAP:
		top = _reward_chest.offset_bottom + STARTER_BADGE_GAP
	_starter_badge.anchor_left = 0.0
	_starter_badge.anchor_top = 0.0
	_starter_badge.anchor_right = 0.0
	_starter_badge.anchor_bottom = 0.0
	_starter_badge.offset_left = maxf(left, safe_margins.x + TOP_SIDE_MARGIN)
	_starter_badge.offset_top = top
	_starter_badge.offset_right = _starter_badge.offset_left + STARTER_BADGE_SIZE.x
	_starter_badge.offset_bottom = top + STARTER_BADGE_SIZE.y


func _get_safe_area_margins(viewport_size: Vector2) -> Vector4:
	return DestinationScreenLayout.get_safe_area_margins(viewport_size)


func _get_display_cutouts(viewport_size: Vector2) -> Array[Rect2]:
	var logical_cutouts: Array[Rect2] = []
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return logical_cutouts

	var scale := Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	for display_cutout: Rect2 in DisplayServer.get_display_cutouts():
		logical_cutouts.append(Rect2(
			Vector2(display_cutout.position) * scale,
			Vector2(display_cutout.size) * scale
		))
	return logical_cutouts


func _update_level_button() -> void:
	var chapter_id := PlayerProgress.get_selected_chapter_id()
	var next_level := PlayerProgress.get_next_level_for_chapter(chapter_id)
	if next_level > 0:
		_level_button.text = tr("menu.level_button") % ChapterCatalog.get_local_level_number(next_level)
		_level_button.disabled = false
	else:
		var progress := PlayerProgress.get_chapter_progress(chapter_id)
		_level_button.text = (
			"MORE LEVELS COMING SOON"
			if bool(progress.get("complete", false))
			else "COMING SOON"
		)
		_level_button.disabled = true


func _update_chapter_button() -> void:
	var chapter_id := PlayerProgress.get_selected_chapter_id()
	var chapter := ChapterCatalog.get_chapter(chapter_id)
	if chapter.is_empty():
		return
	if _chapter_button.has_method("set_chapter"):
		_chapter_button.call("set_chapter", chapter, PlayerProgress.get_chapter_progress(chapter_id))


func _update_lives_status() -> void:
	var lives := PlayerProgress.get_lives()
	if _life_count_label != null:
		_life_count_label.text = str(lives)

	if _life_status_label == null:
		return

	if lives >= PlayerProgress.get_max_lives():
		_life_status_label.text = "Full"
		return

	var seconds_remaining := PlayerProgress.get_next_life_restore_seconds_remaining()
	_life_status_label.text = _format_life_restore_time(seconds_remaining)


func _refresh_out_of_lives_offer() -> void:
	if _out_of_lives_menu == null:
		return
	var lives := PlayerProgress.get_lives()
	_out_of_lives_menu.set_offer(
		lives,
		PlayerProgress.get_max_lives(),
		PlayerProgress.get_next_life_restore_seconds_remaining(),
		PlayerProgress.get_life_purchase_coin_price()
	)
	_out_of_lives_menu.set_purchase_enabled(not _life_recovery_in_progress)
	_refresh_rewarded_life_action()
	if (
		_out_of_lives_launch_pending
		and lives > 0
		and _out_of_lives_menu.visible
		and not _out_of_lives_menu.is_transitioning()
		and not _life_recovery_in_progress
	):
		_life_recovery_in_progress = true
		_complete_life_recovery()


func _setup_rewarded_life_client() -> void:
	if _rewarded_life_client != null:
		return
	_rewarded_life_client = RewardedLifeClientScript.new()
	add_child(_rewarded_life_client)
	var ad_service := get_tree().root.get_node_or_null(^"AdService")
	_rewarded_life_client.configure(PlayerProgress.get_backend_transport(), ad_service)


func _prepare_rewarded_life() -> void:
	if _rewarded_life_client == null or _life_recovery_in_progress or _rewarded_life_prepare_in_progress:
		return
	_rewarded_life_prepare_in_progress = true
	_rewarded_life_action_state = OutOfLivesMenu.REWARDED_STATE_LOADING
	_refresh_rewarded_life_action()
	var result: Dictionary = await _rewarded_life_client.prepare()
	if not is_inside_tree():
		return
	_rewarded_life_prepare_in_progress = false
	_rewarded_life_action_state = (
		OutOfLivesMenu.REWARDED_STATE_READY
		if bool(result.get("status", &"") == &"ready") and _rewarded_life_client.can_offer()
		else OutOfLivesMenu.REWARDED_STATE_UNAVAILABLE
	)
	_refresh_rewarded_life_action()


func _refresh_rewarded_life_action() -> void:
	if _out_of_lives_menu == null or _rewarded_life_client == null:
		return
	if _life_recovery_in_progress:
		_out_of_lives_menu.set_rewarded_action_state(_rewarded_life_action_state, false)
		return
	if _rewarded_life_client.is_awaiting_verification():
		_rewarded_life_action_state = OutOfLivesMenu.REWARDED_STATE_PENDING
	elif _rewarded_life_client.can_offer():
		_rewarded_life_action_state = OutOfLivesMenu.REWARDED_STATE_READY
	elif _rewarded_life_action_state != OutOfLivesMenu.REWARDED_STATE_ERROR:
		_rewarded_life_action_state = OutOfLivesMenu.REWARDED_STATE_UNAVAILABLE
	_out_of_lives_menu.set_rewarded_action_state(
		_rewarded_life_action_state,
		_rewarded_life_client.can_offer()
	)


func _update_reward_chest_status() -> void:
	if _reward_chest == null or not _reward_chest.has_method("set_reward_progress"):
		return

	var progress := PlayerProgress.get_reward_chest_progress()
	_reward_chest.call(
		"set_reward_progress",
		int(progress.get("stars", 0)),
		int(progress.get("goal", 1))
	)


func _prepare_pending_reward_animation(pending: Dictionary) -> void:
	_animated_reward_stars = maxi(int(pending.get("start_stars", 0)), 0)
	_animated_reward_goal_index = maxi(int(pending.get("start_goal_index", 0)), 0)
	var grant := PlayerProgress.get_reward_chest_grant_preview(
		_animated_reward_stars,
		_animated_reward_goal_index,
		maxi(int(pending.get("amount", 0)), 0)
	)
	_undisplayed_chest_coins = maxi(int(grant.get("coin_reward", 0)), 0)
	_update_coin_balance()
	_set_animated_reward_chest_status()


func _play_pending_reward_animation(pending: Dictionary) -> void:
	var amount := maxi(int(pending.get("amount", 0)), 0)
	if amount <= 0 or _reward_star_flyer == null or _house_reward_origin == null:
		_undisplayed_chest_coins = 0
		_update_coin_balance()
		_update_reward_chest_status()
		return

	if not _reward_star_flyer.star_arrived.is_connected(_on_reward_star_arrived):
		_reward_star_flyer.star_arrived.connect(_on_reward_star_arrived)
	if not _reward_star_flyer.animation_finished.is_connected(_on_reward_star_animation_finished):
		_reward_star_flyer.animation_finished.connect(_on_reward_star_animation_finished)

	var start_position := _house_reward_origin.get_global_rect().get_center()
	var target_position := _reward_chest.get_global_rect().get_center()
	if _reward_chest.has_method("get_reward_target_global_position"):
		target_position = _reward_chest.call("get_reward_target_global_position") as Vector2
	_reward_star_flyer.call("play", amount, start_position, target_position)


## The one accepted-arrival callback: it advances the visible chest count, starts the receive
## pulse, and plays the arrival cue together. Silent state reconciliation goes through
## _update_reward_chest_status()/_prepare_pending_reward_animation() instead and stays quiet.
##
## The arrival that fills a goal does not pay out here: it holds the widget at full and queues the
## goal's rewards for the opening sequence, whose own beats carry the payout sound and haptic.
func _on_reward_star_arrived() -> void:
	_animated_reward_stars += 1
	var goal := PlayerProgress.get_reward_chest_goal_at_index(_animated_reward_goal_index)
	if _animated_reward_stars >= goal:
		_queue_chest_ceremony_rewards(_animated_reward_goal_index)
		if _chest_full_hold_goal <= 0:
			_chest_full_hold_goal = goal
		_animated_reward_stars -= goal
		_animated_reward_goal_index = mini(
			_animated_reward_goal_index + 1,
			PlayerProgress.get_reward_chest_last_goal_index()
		)

	_set_animated_reward_chest_status()
	if _reward_chest.has_method("play_receive_pulse"):
		_reward_chest.call("play_receive_pulse")

	# The catalog's variant pool, subtle pitch spread, cooldown, and polyphony budget are what keep
	# a long staggered flight intelligible instead of turning it into one loud stack.
	SfxManager.play(SfxCatalogScript.EVENT_REWARD_CHEST_STAR_ARRIVAL)


func _on_reward_star_animation_finished() -> void:
	if _chest_full_hold_goal > 0 and not _chest_ceremony_rewards.is_empty():
		if _purchase_reward_sequence.call("is_playing"):
			_chest_ceremony_deferred = true
			return
		_play_chest_ceremony()
		return
	_update_reward_chest_status()


func _set_animated_reward_chest_status() -> void:
	if _reward_chest == null or not _reward_chest.has_method("set_reward_progress"):
		return

	if _chest_full_hold_goal > 0:
		_reward_chest.call("set_reward_progress", _chest_full_hold_goal, _chest_full_hold_goal)
		return

	_reward_chest.call(
		"set_reward_progress",
		_animated_reward_stars,
		PlayerProgress.get_reward_chest_goal_at_index(_animated_reward_goal_index)
	)


## Rare long flights can fill more than one goal; they share one opening with the summed rewards.
func _queue_chest_ceremony_rewards(goal_index: int) -> void:
	var abilities := _chest_ceremony_rewards.get("abilities", {}) as Dictionary
	var goal_abilities := PlayerProgress.get_reward_chest_goal_ability_rewards_at_index(goal_index)
	for ability_id in goal_abilities.keys():
		abilities[ability_id] = int(abilities.get(ability_id, 0)) + int(goal_abilities[ability_id])
	_chest_ceremony_rewards = {
		"coins": int(_chest_ceremony_rewards.get("coins", 0))
			+ PlayerProgress.get_reward_chest_goal_coin_reward_at_index(goal_index),
		"abilities": abilities,
	}


func _play_chest_ceremony() -> void:
	_chest_ceremony_coin_holdback = _undisplayed_chest_coins
	var chest_rect := _reward_chest.get_global_rect()
	if _reward_chest.has_method("get_chest_icon_global_rect"):
		chest_rect = _reward_chest.call("get_chest_icon_global_rect") as Rect2
	if _reward_chest.has_method("set_chest_icon_hidden"):
		_reward_chest.call("set_chest_icon_hidden", true)
	_chest_ceremony.call(
		"play",
		_chest_ceremony_rewards,
		chest_rect,
		_coin_shortcut.call("get_coin_icon_global_center") as Vector2,
		_level_button.get_global_rect().get_center()
	)


## Counts the displayed balance up in step with the coins landing, reaching the saved balance on
## the last one.
func _on_chest_ceremony_coin_arrived(arrived_count: int, total_count: int) -> void:
	var remaining_share := 1.0 - float(arrived_count) / float(maxi(total_count, 1))
	_undisplayed_chest_coins = roundi(float(_chest_ceremony_coin_holdback) * remaining_share)
	_update_coin_balance()
	_coin_shortcut.call("play_receive_pulse")


func _on_chest_ceremony_ability_arrived(_ability_id: StringName) -> void:
	_play_level_button_receive_pulse()


func _play_level_button_receive_pulse() -> void:
	_level_button.pivot_offset = _level_button.size * 0.5
	var tween := UIMotionScript.retween(_level_button, &"_chest_reward_pulse_tween")
	tween.tween_property(_level_button, "scale", Vector2(1.06, 1.06), 0.07) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_level_button, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_chest_ceremony_finished() -> void:
	_chest_full_hold_goal = 0
	_chest_ceremony_rewards = {}
	_undisplayed_chest_coins = 0
	_chest_ceremony_coin_holdback = 0
	_update_coin_balance()
	if _reward_chest.has_method("set_chest_icon_hidden"):
		_reward_chest.call("set_chest_icon_hidden", false)
	var progress := PlayerProgress.get_reward_chest_progress()
	if _reward_chest.has_method("play_refill"):
		_reward_chest.call(
			"play_refill", int(progress.get("stars", 0)), int(progress.get("goal", 1))
		)
	else:
		_update_reward_chest_status()


func _format_life_restore_time(seconds_remaining: int) -> String:
	var clamped_seconds := maxi(seconds_remaining, 0)
	var minutes_remaining := floori(float(clamped_seconds) / 60.0)
	var remaining_seconds := clamped_seconds % 60
	return "%02d:%02d" % [minutes_remaining, remaining_seconds]


func _update_profile_customization() -> void:
	if _profile_avatar_view == null:
		return
	_profile_avatar_view.set_profile(
		PlayerProgress.get_avatar_id(),
		PlayerProgress.get_avatar_frame_id()
	)


func _update_coin_balance() -> void:
	if _coin_shortcut != null:
		_coin_shortcut.call(
			"set_amount",
			maxi(PlayerProgress.get_coins() - _undisplayed_chest_coins - _undisplayed_purchase_coins, 0)
		)


func _open_profile_menu() -> void:
	if is_instance_valid(_profile_menu):
		return

	_profile_menu = PROFILE_MENU_SCENE.instantiate() as Control
	_add_main_menu_overlay(_profile_menu)
	_profile_menu.connect("profile_saved", Callable(self, "_on_profile_saved"))
	_profile_menu.tree_exited.connect(_clear_profile_menu_reference)


func _open_settings_menu() -> void:
	if is_instance_valid(_settings_menu):
		return

	_settings_menu = SETTINGS_MENU_SCENE.instantiate() as Control
	_add_main_menu_overlay(_settings_menu)
	_settings_menu.connect("support_requested", Callable(self, "_open_support_screen"))
	_settings_menu.connect("language_requested", Callable(self, "_open_language_selection_modal"))
	_settings_menu.connect("ad_privacy_requested", Callable(self, "_on_ad_privacy_requested"))
	_refresh_ad_compliance_actions()

	var close_button := _settings_menu.get_node_or_null("PauseMenuPanel/CloseButton") as Button
	if close_button != null:
		close_button.pressed.connect(_close_settings_menu)

	_settings_menu.tree_exited.connect(_clear_settings_menu_reference)


func _close_settings_menu() -> void:
	if is_instance_valid(_settings_menu):
		UIMotionScript.close_with_fade(_settings_menu, _settings_menu.queue_free)


func _open_language_selection_modal() -> void:
	if is_instance_valid(_language_selection_modal):
		return
	_language_selection_modal = LANGUAGE_SELECTION_MODAL_SCENE.instantiate() as Control
	_language_selection_modal.z_index = MAIN_MENU_OVERLAY_Z_INDEX + 1
	add_child(_language_selection_modal)
	_language_selection_modal.tree_exited.connect(_clear_language_selection_modal_reference)


func _refresh_ad_compliance_actions() -> void:
	if not is_instance_valid(_settings_menu):
		return
	var ad_service: Node = _get_ad_service()
	var privacy_options_required := (
		ad_service != null and bool(ad_service.call("is_privacy_options_required"))
	)
	var privacy_url := str(ProjectSettings.get_setting(AD_PRIVACY_POLICY_SETTING, "")).strip_edges()
	_settings_menu.call(
		"set_ad_compliance_actions",
		"Privacy Choices" if privacy_options_required else "Privacy Policy",
		privacy_options_required or _is_safe_external_url(privacy_url)
	)


func _on_privacy_options_requirement_changed(_required: bool) -> void:
	_refresh_ad_compliance_actions()


func _on_ad_privacy_requested() -> void:
	var ad_service: Node = _get_ad_service()
	if ad_service != null and bool(ad_service.call("is_privacy_options_required")):
		await ad_service.call("show_privacy_options")
		_refresh_ad_compliance_actions()
		return
	_open_ad_compliance_url(AD_PRIVACY_POLICY_SETTING)


func _open_ad_compliance_url(setting: String) -> void:
	var url := str(ProjectSettings.get_setting(setting, "")).strip_edges()
	if not _is_safe_external_url(url):
		push_warning("Ad compliance URL is not configured: %s" % setting)
		return
	var error := OS.shell_open(url)
	if error != OK:
		push_warning("Could not open ad compliance URL: %s" % url)


func _is_safe_external_url(url: String) -> bool:
	return url.begins_with("https://") and url.length() <= 2048


func _get_ad_service() -> Node:
	return get_tree().root.get_node_or_null(^"AdService") as Node


func _open_support_screen() -> void:
	if is_instance_valid(_support_screen):
		return
	_support_screen = SUPPORT_SCREEN_SCENE.instantiate() as Control
	_add_main_menu_overlay(_support_screen)
	_support_screen.connect("account_deletion_requested", Callable(self, "_open_account_deletion_modal"))
	_support_screen.tree_exited.connect(_clear_support_screen_reference)


## GAME-012: opened from Support's account action, or at launch while a deletion blocks progress.
func _open_account_deletion_modal() -> void:
	if is_instance_valid(_account_deletion_modal):
		return
	_account_deletion_modal = ACCOUNT_DELETION_MODAL_SCENE.instantiate() as Control
	_account_deletion_modal.z_index = MAIN_MENU_OVERLAY_Z_INDEX + 3
	add_child(_account_deletion_modal)
	_account_deletion_modal.connect("new_game_started", Callable(self, "_on_account_deletion_new_game_started"))
	_account_deletion_modal.tree_exited.connect(_clear_account_deletion_modal_reference)


## A new game after deletion follows the first-time launch route from the main scene, which starts
## level 1 for the fresh progress. Nothing in this menu is reused for the new identity.
func _on_account_deletion_new_game_started() -> void:
	get_tree().change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene", "")))


func _clear_account_deletion_modal_reference() -> void:
	_account_deletion_modal = null
	if is_instance_valid(_support_screen):
		_support_screen.call("refresh_account_action")


func _open_reward_chest_menu() -> void:
	if is_instance_valid(_reward_chest_menu):
		return

	_reward_chest_menu = REWARD_CHEST_MENU_SCENE.instantiate() as Control
	_add_main_menu_overlay(_reward_chest_menu)
	_reward_chest_menu.tree_exited.connect(_clear_reward_chest_menu_reference)


func _open_chapter_selection() -> void:
	if not _chapter_selection_enabled or is_instance_valid(_chapter_selection_screen):
		return
	_chapter_selection_screen = CHAPTER_SELECTION_SCENE.instantiate() as Control
	_add_main_menu_overlay(_chapter_selection_screen)
	_chapter_selection_screen.connect("chapter_selected", Callable(self, "_on_chapter_selected"))
	_chapter_selection_screen.tree_exited.connect(_clear_chapter_selection_reference)


func _on_chapter_selected(chapter_id: String) -> void:
	_update_level_button()
	_update_chapter_button()
	_update_chapter_background(chapter_id)


func _update_chapter_background(chapter_id: String) -> void:
	MenuBackgroundResolverScript.apply_background(_background, chapter_id)


func _add_main_menu_overlay(overlay: Control) -> void:
	overlay.z_index = MAIN_MENU_OVERLAY_Z_INDEX
	add_child(overlay)
	UIMotionScript.fade_in(overlay)


func _clear_chapter_selection_reference() -> void:
	_chapter_selection_screen = null


func _clear_reward_chest_menu_reference() -> void:
	_reward_chest_menu = null


func _on_profile_saved(_avatar_id: String, _avatar_frame_id: String) -> void:
	_update_profile_customization()


func _clear_profile_menu_reference() -> void:
	_profile_menu = null


func _clear_settings_menu_reference() -> void:
	_settings_menu = null


func _clear_language_selection_modal_reference() -> void:
	_language_selection_modal = null


func _clear_support_screen_reference() -> void:
	_support_screen = null


## Retapping the already-active Home tab is a no-op (see docs/SCENES.md's "Active-Tab Reselection
## Rule"); Main Menu has no separate reload/refresh action tied to its own bottom-navigation tab.
func _on_home_tab_reselected() -> void:
	pass


func _open_leaderboard() -> void:
	_begin_navigation(LEADERBOARD_SCENE)


func _open_shop() -> void:
	_begin_navigation(SHOP_SCENE)


func _refresh_starter_bundle_offer() -> Dictionary:
	_starter_catalog_serial += 1
	var request_serial := _starter_catalog_serial
	_starter_badge.hide()
	_starter_offer = {}
	# Keep the RefCounted service alive across the await even if the menu is replaced.
	var service = _starter_store_service
	var result: Dictionary = await service.load_catalog()
	if not is_inside_tree() or request_serial != _starter_catalog_serial:
		return {}
	if not bool(result.get("ok", false)) or str(result.get("source", "local")) not in ["local", "live"]:
		return {}
	for raw_offer in result.get("offers", []) as Array:
		if not (raw_offer is Dictionary):
			continue
		var offer := raw_offer as Dictionary
		if str(offer.get("id", "")) != STARTER_BUNDLE_ID or str(offer.get("type", "")) != "bundle":
			continue
		if PlayerProgress.has_purchased_shop_offer(&"starter_bundle"):
			return {}
		var store := offer.get("store", {}) as Dictionary
		if str(store.get("formatted_price", "")).strip_edges().is_empty():
			return {}
		_starter_offer = offer.duplicate(true)
		_starter_badge.set_discount_percent(int(offer.get("discount_percent", 0)))
		_starter_badge.show()
		return _starter_offer
	return {}


func _open_starter_bundle_offer() -> void:
	if (
		_is_navigating
		or _starter_offer.is_empty()
		or _starter_modal.visible
		or _purchase_reward_sequence.visible
	):
		return
	_starter_modal.set_offer(_starter_offer)
	_starter_modal.apply_safe_layout(_get_safe_area_margins(get_viewport_rect().size), get_viewport_rect().size)
	_starter_modal.open()
	_starter_modal.set_busy("Checking offer…")
	var refreshed_offer: Dictionary = await _refresh_starter_bundle_offer()
	if not is_inside_tree() or not _starter_modal.visible:
		return
	if refreshed_offer.is_empty():
		_starter_modal.show_error("This offer is no longer available.", false)
	else:
		_starter_modal.set_offer(refreshed_offer)


func _close_starter_bundle_offer() -> void:
	if _starter_purchase_in_progress:
		return
	_starter_modal.close()


func _buy_starter_bundle() -> void:
	if _starter_purchase_in_progress or not _starter_modal.visible:
		return
	_starter_purchase_in_progress = true
	_starter_modal.set_busy("Checking offer…")
	var refreshed_offer: Dictionary = await _refresh_starter_bundle_offer()
	if not is_inside_tree():
		return
	if refreshed_offer.is_empty():
		_starter_modal.show_error("This offer is no longer available.", false)
		_starter_purchase_in_progress = false
		return

	_starter_modal.set_offer(refreshed_offer)
	_starter_modal.set_busy("Purchasing…")
	var flow := ShopPurchaseFlowScript.new(_starter_store_service, PlayerProgress)
	var result: Dictionary = await flow.execute(&"starter_bundle")
	if not is_inside_tree():
		return
	_starter_purchase_in_progress = false
	if not bool(result.get("ok", false)):
		_starter_modal.show_error(
			GameText.purchase_error(str(result.get("error", "")), str(result.get("stage", "")) == "grant"),
			str(result.get("stage", "")) == "purchase"
		)
		return

	var grant_result := result.get("grant", {}) as Dictionary
	_starter_catalog_serial += 1
	_starter_offer = {}
	_starter_badge.hide()
	# The purchase reward sequence confirms the purchase in place of the modal: the rewards lift off
	# the modal's coin art and booster chips as it closes, coins fly into the counter, and boosters
	# fly to the LEVEL button. A replayed, already-granted transaction brings nothing to reveal.
	var origin_rects: Dictionary = _starter_modal.get_reward_icon_global_rects()
	_starter_modal.close_after_purchase()
	if not bool(grant_result.get("applied", false)):
		_update_coin_balance()
		return
	_purchase_coin_holdback = maxi(int(grant_result.get("coins", 0)), 0)
	_undisplayed_purchase_coins = _purchase_coin_holdback
	_update_coin_balance()
	ShopPurchaseFlowScript.play_success_feedback(grant_result)
	_purchase_reward_sequence.call(
		"play",
		grant_result,
		origin_rects,
		_coin_shortcut.call("get_coin_icon_global_center") as Vector2,
		_level_button.get_global_rect().get_center()
	)


## Counts the displayed balance up in step with the purchased coins landing, reaching the saved
## balance on the last one.
func _on_purchase_reward_coin_arrived(arrived_count: int, total_count: int) -> void:
	var remaining_share := 1.0 - float(arrived_count) / float(maxi(total_count, 1))
	_undisplayed_purchase_coins = roundi(float(_purchase_coin_holdback) * remaining_share)
	_update_coin_balance()
	_coin_shortcut.call("play_receive_pulse")


func _on_purchase_reward_ability_arrived(_ability_id: StringName) -> void:
	_play_level_button_receive_pulse()


func _on_purchase_reward_finished() -> void:
	_undisplayed_purchase_coins = 0
	_purchase_coin_holdback = 0
	_update_coin_balance()
	if _chest_ceremony_deferred:
		_chest_ceremony_deferred = false
		_play_chest_ceremony()


## Ignores a duplicate cross-destination press while a scene transition is already underway, so a
## rapid double-tap on Shop/Leaderboard (including via the top-status coin shortcut) can never call
## change_scene_to_file() twice, and stops this whole screen (every descendant's mouse/touch/
## keyboard input, not just navigation) from accepting further input for the brief window before
## the deferred scene swap resolves.
func _begin_navigation(scene_path: String) -> void:
	if (
		_is_navigating
		or _starter_modal.visible
		or _chest_ceremony.visible
		or _purchase_reward_sequence.visible
	):
		return

	_is_navigating = true
	process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().change_scene_to_file(scene_path)


func _launch_campaign_level() -> void:
	if _chest_ceremony.visible or _purchase_reward_sequence.visible:
		return
	PlayerProgress.refresh_lives()
	if PlayerProgress.get_lives() <= 0:
		_update_lives_status()
		_update_level_button()
		_open_out_of_lives_menu(true)
		return

	var chapter_id := PlayerProgress.get_selected_chapter_id()
	var next_level := PlayerProgress.get_next_level_for_chapter(chapter_id)
	if next_level <= 0:
		return

	LevelTransition.launch_level(next_level, false, PRODUCTION_MENU_SCENE, {}, self)


## `is_launch_pending` separates the two entry points: true only from `_launch_campaign_level()`,
## which resumes that launch once a life exists, and false from the top-status lives widget, which
## only ever reports and sells lives without leaving the Main Menu.
func _open_out_of_lives_menu(is_launch_pending: bool) -> void:
	if _out_of_lives_menu.visible or _is_navigating:
		return
	_out_of_lives_launch_pending = is_launch_pending
	_refresh_out_of_lives_offer()
	_out_of_lives_menu.open()
	if not _rewarded_life_client.can_offer() and not _rewarded_life_client.is_awaiting_verification():
		call_deferred("_prepare_rewarded_life")


## Single close path for the lives modal, so no route can leave a stale pending launch behind and
## resume it the next time the modal is opened from the top status bar.
func _close_out_of_lives_menu() -> void:
	_out_of_lives_launch_pending = false
	await _out_of_lives_menu.close()


func _on_out_of_lives_close_requested() -> void:
	if _life_recovery_in_progress or _out_of_lives_menu.is_transitioning():
		return
	_close_out_of_lives_menu()


func _on_out_of_lives_purchase_requested() -> void:
	if _life_recovery_in_progress or _out_of_lives_menu.is_transitioning():
		return

	PlayerProgress.refresh_lives()
	if _out_of_lives_launch_pending and PlayerProgress.get_lives() > 0:
		await _close_out_of_lives_menu()
		_launch_campaign_level()
		return

	# Defensive: the purchase action is hidden at the cap, so this can only be a stale press.
	# Falling through would reach the coin check and send a player with a full life bar to the Shop.
	if PlayerProgress.get_lives() >= PlayerProgress.get_max_lives():
		_refresh_out_of_lives_offer()
		return

	if PlayerProgress.get_coins() < PlayerProgress.get_life_purchase_coin_price():
		_open_shop()
		return

	_life_recovery_in_progress = true
	_out_of_lives_menu.set_purchase_enabled(false)
	if not PlayerProgress.purchase_life():
		_life_recovery_in_progress = false
		_refresh_out_of_lives_offer()
		return

	SfxManager.play(SfxCatalogScript.EVENT_COIN_SPEND)
	HapticsManager.play(HapticsCatalogScript.EVENT_LIFE_PURCHASE_SUCCESS)
	_update_coin_balance()
	await _complete_life_recovery()


func _on_out_of_lives_rewarded_ad_requested() -> void:
	if _life_recovery_in_progress or _out_of_lives_menu.is_transitioning():
		return
	PlayerProgress.refresh_lives()
	if PlayerProgress.get_lives() > 0 and _out_of_lives_launch_pending:
		_life_recovery_in_progress = true
		await _complete_life_recovery()
		return
	if PlayerProgress.get_lives() >= PlayerProgress.get_max_lives():
		_refresh_out_of_lives_offer()
		return
	if _rewarded_life_client == null or not _rewarded_life_client.can_offer():
		_rewarded_life_action_state = OutOfLivesMenu.REWARDED_STATE_ERROR
		_refresh_rewarded_life_action()
		return

	_life_recovery_in_progress = true
	_rewarded_life_action_state = (
		OutOfLivesMenu.REWARDED_STATE_VERIFYING
		if _rewarded_life_client.is_awaiting_verification()
		else OutOfLivesMenu.REWARDED_STATE_LOADING
	)
	_out_of_lives_menu.set_purchase_enabled(false)
	_refresh_rewarded_life_action()
	var result: Dictionary = await _rewarded_life_client.claim()
	if not is_inside_tree():
		return
	if not bool(result.get("ok", false)):
		_life_recovery_in_progress = false
		_rewarded_life_action_state = (
			OutOfLivesMenu.REWARDED_STATE_PENDING
			if bool(result.get("pending", false))
			else OutOfLivesMenu.REWARDED_STATE_ERROR
		)
		_refresh_out_of_lives_offer()
		if not bool(result.get("pending", false)):
			call_deferred("_prepare_rewarded_life")
		return
	if not PlayerProgress.apply_authoritative_life_state(result.get("life_state", {}) as Dictionary):
		_life_recovery_in_progress = false
		_rewarded_life_action_state = OutOfLivesMenu.REWARDED_STATE_ERROR
		_refresh_out_of_lives_offer()
		return
	if PlayerProgress.get_lives() <= 0:
		_life_recovery_in_progress = false
		_rewarded_life_action_state = OutOfLivesMenu.REWARDED_STATE_ERROR
		_refresh_out_of_lives_offer()
		return
	await _complete_life_recovery()


func _complete_life_recovery() -> void:
	_update_lives_status()
	_update_level_button()
	var should_resume_launch := _out_of_lives_launch_pending
	await _close_out_of_lives_menu()
	_life_recovery_in_progress = false
	_rewarded_life_action_state = OutOfLivesMenu.REWARDED_STATE_UNAVAILABLE
	if should_resume_launch:
		_launch_campaign_level()


func _notification(what: int) -> void:
	if what == NOTIFICATION_LAYOUT_DIRECTION_CHANGED and is_node_ready():
		_apply_responsive_layout.call_deferred()
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_level_button()
		_update_chapter_button()
