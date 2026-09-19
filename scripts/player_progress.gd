extends Node

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")
const SecureSessionStoreScript := preload("res://scripts/save/secure_session_store.gd")
const AccountSaveCoordinatorScript := preload("res://scripts/save/account_save_coordinator.gd")
const GuestSessionBootstrapServiceScript := preload("res://scripts/save/guest_session_bootstrap_service.gd")
const SaveSyncServiceScript := preload("res://scripts/save/save_sync_service.gd")
const BackendTransportScript := preload("res://scripts/backend/backend_transport.gd")
const ProfileFrameCatalogScript := preload("res://scripts/profile_frame_catalog.gd")
const ContentProvenanceManifestScript := preload(
	"res://scripts/save/content_provenance_manifest.gd"
)
const AdPacingStateScript := preload("res://scripts/ads/ad_pacing_state.gd")
const SAVE_PATH := "user://player_progress.json"
const SAVE_VERSION := 9
const MIN_LEVEL := 1
const ABILITY_HAMMER := "hammer"
const ABILITY_SHUFFLE := "shuffle"
const ABILITY_HIGHLIGHT := "highlight"
const ABILITY_FREEZER := "freezer"
const DEFAULT_AVATAR_ID := "avatar_cat"
const PLAYER_NAME_PREFIX := "player_"
const PLAYER_NAME_RANDOM_ALPHABET := "abcdefghijklmnopqrstuvwxyz0123456789"
const PLAYER_NAME_RANDOM_LENGTH := 5
const REWARD_CHEST_GOALS_CONFIG := "res://configs/reward_chest_goals.json"
const LEADERBOARD_REWARD_TIERS_CONFIG := "res://configs/leaderboard_reward_tiers.json"
const LIFE_PURCHASE_CONFIG := "res://configs/life_purchase.json"
const DEFAULT_COINS := 300
const DEFAULT_LIFE_PURCHASE_COIN_PRICE := 500
const LEADERBOARD_WEEK_SECONDS := 7 * 24 * 60 * 60
const UNIX_EPOCH_MONDAY_OFFSET_DAYS := 3
const DEFAULT_REWARD_CHEST_GOALS := [
	{"stars": 500, "coin_reward": 100},
	{"stars": 1000, "coin_reward": 225},
	{"stars": 1500, "coin_reward": 375},
	{"stars": 2000, "coin_reward": 550},
	{"stars": 3000, "coin_reward": 900},
]
## Weekly leaderboard placement rewards. Ranks are local-observation-based (see
## `record_weekly_leaderboard_rank()`), not a backend-authoritative final standing -- see
## `docs/LEADERBOARDS.md` for the gap this approximates.
const DEFAULT_LEADERBOARD_REWARD_TIERS := [
	{"min_rank": 1, "max_rank": 1, "coin_reward": 500},
	{"min_rank": 2, "max_rank": 3, "coin_reward": 300},
	{"min_rank": 4, "max_rank": 10, "coin_reward": 150},
	{"min_rank": 11, "max_rank": 50, "coin_reward": 50},
]
const AVAILABLE_AVATAR_IDS := [
	"avatar_bear",
	"avatar_cat",
	"avatar_cow",
	"avatar_deer",
	"avatar_dog",
	"avatar_dolphin",
	"avatar_elephant",
	"avatar_frog",
	"avatar_hamster",
	"avatar_koala",
	"avatar_lion",
	"avatar_monkey",
	"avatar_owl",
	"avatar_penguin",
	"avatar_sheep",
	"avatar_sloth",
	"avatar_tiger",
	"avatar_turtle",
]
const AVATAR_TEXTURE_PATH_FORMAT := "res://assets/ui/avatars/%s.png"
const MAX_LIVES := 5
const LIFE_RESTORE_SECONDS := 3600
const DEFAULT_ABILITY_USES := {
	ABILITY_HAMMER: 3,
	ABILITY_SHUFFLE: 3,
	ABILITY_HIGHLIGHT: 3,
	ABILITY_FREEZER: 3,
}
const DEFAULT_DISABLED_SETTINGS := {
	"music": false,
	"sound_effects": false,
	"vibration": false,
}

var _data := {}
var _reward_chest_goals := []
var _pending_reward_chest_animation := {}
var _pending_leaderboard_reward := {}
var _leaderboard_reward_tiers: Array = []
var _life_purchase_coin_price := DEFAULT_LIFE_PURCHASE_COIN_PRICE
var _session_store
var _account_coordinator
var _local_store
var _guest_bootstrap_service
var _sync_service
var _backend_transport
var _content_provenance
var _content_operation_diagnostic := {}


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	_load_content_provenance()
	_load_life_purchase_configuration()
	if _session_store == null:
		_session_store = SecureSessionStoreScript.new()
		var identity_result: Dictionary = _session_store.initialize()
		if not bool(identity_result.get("ok", false)):
			push_error("Could not initialize installation identity: %s" % identity_result.get("error", ""))
			_data = _default_data()
			return

	var legacy_data := _load_legacy_data()
	var initial_data := _sanitize_data(legacy_data if not legacy_data.is_empty() else _default_data())
	var initial_preferences := {
		"settings_disabled": initial_data.get("settings_disabled", DEFAULT_DISABLED_SETTINGS).duplicate(true),
		"selected_chapter_id": initial_data.get("selected_chapter_id", _default_chapter_id()),
		"ad_pacing_state": initial_data.get(
			"ad_pacing_state",
			AdPacingStateScript.create_default()
		).duplicate(true),
	}
	initial_data.erase("settings_disabled")
	initial_data.erase("selected_chapter_id")
	initial_data.erase("ad_pacing_state")
	if _account_coordinator == null:
		_account_coordinator = AccountSaveCoordinatorScript.new(_session_store)
	var open_result: Dictionary = _account_coordinator.initialize(
		initial_data,
		initial_preferences,
		SAVE_PATH if not legacy_data.is_empty() else "",
		int(legacy_data.get("version", 0)),
		_snapshot_without_preferences(_sanitize_data(_default_data()))
	)
	if not bool(open_result.get("ok", false)):
		push_error("Could not open local-first progress: %s" % open_result.get("error", ""))
		_data = _sanitize_data(legacy_data if not legacy_data.is_empty() else _default_data())
		return

	_local_store = _account_coordinator.get_store()
	var opened_snapshot := open_result.get("snapshot", {}) as Dictionary
	var opened_version := int(opened_snapshot.get("version", 0))
	var requires_schema_migration := opened_version < SAVE_VERSION
	var migration_operations := _schema_migration_operations(opened_snapshot)
	_apply_loaded_partitions(
		opened_snapshot,
		open_result.get("preferences", {}) as Dictionary
	)
	if (
		requires_schema_migration
		and not bool(_commit_current_state(migration_operations).get("ok", false))
	):
		push_error("Could not persist the gameplay save schema-%d migration." % SAVE_VERSION)
	if _sync_service == null:
		_sync_service = SaveSyncServiceScript.new()
		add_child(_sync_service)
		_sync_service.reconciliation_applied.connect(_on_reconciliation_applied)
	_sync_service.configure(
		_local_store,
		_session_store,
		_map_checkpoint_to_snapshot,
		_content_provenance.is_valid()
	)
	if _guest_bootstrap_service == null:
		_guest_bootstrap_service = GuestSessionBootstrapServiceScript.new()
		add_child(_guest_bootstrap_service)
		_guest_bootstrap_service.guest_registered.connect(_on_guest_registered)
	_guest_bootstrap_service.configure(
		_local_store,
		_session_store,
		_account_coordinator,
		_content_provenance.is_valid()
	)
	if _backend_transport == null:
		_backend_transport = BackendTransportScript.new()
		add_child(_backend_transport)
	_backend_transport.configure(_session_store, _active_player_id)
	if _refresh_lives_state():
		_commit_current_state([_life_state_operation()])
	_guest_bootstrap_service.request_registration()
	_sync_service.request_background_sync()


func save_progress() -> void:
	if not _commit_current_state():
		push_error("Could not save local-first progress.")


func get_current_level() -> int:
	return int(_data.get("current_level", MIN_LEVEL))


func get_highest_completed_level() -> int:
	return int(_data.get("highest_completed_level", 0))


func get_completed_level_stars() -> Dictionary:
	return (_data.get("completion_stars_by_level", {}) as Dictionary).duplicate(true)


func is_level_completed(level_number: int) -> bool:
	return (_data.get("completion_stars_by_level", {}) as Dictionary).has(str(level_number))


func get_selected_chapter_id() -> String:
	var selected := str(_data.get("selected_chapter_id", _default_chapter_id()))
	if _can_select_chapter(selected):
		return selected
	return _latest_selectable_chapter_id()


func select_chapter(chapter_id: String) -> bool:
	if not _can_select_chapter(chapter_id):
		return false
	if get_selected_chapter_id() == chapter_id:
		return true
	var previous_data := _data.duplicate(true)
	_data["selected_chapter_id"] = chapter_id
	return _commit_or_restore(previous_data)


func is_chapter_unlocked(chapter_id: String) -> bool:
	return _is_chapter_unlocked_with_completions(
		chapter_id,
		_data.get("completion_stars_by_level", {}) as Dictionary
	)


func _is_chapter_unlocked_with_completions(chapter_id: String, completions: Dictionary) -> bool:
	var chapter := ChapterCatalog.get_chapter(chapter_id)
	if chapter.is_empty():
		return false
	if int(chapter.get("order", 0)) == 1:
		return true
	var previous_chapter_id := str(chapter.get("previous_chapter_id", ""))
	var requirement := maxi(int(chapter.get("required_completed_levels", 0)), 0)
	return _completed_level_count_from(completions, previous_chapter_id) >= requirement


func get_completed_level_count(chapter_id: String) -> int:
	return _completed_level_count_from(
		_data.get("completion_stars_by_level", {}) as Dictionary,
		chapter_id
	)


func _completed_level_count_from(completions: Dictionary, chapter_id: String) -> int:
	var count := 0
	for level_id in ChapterCatalog.get_level_ids(chapter_id):
		if completions.has(str(level_id)):
			count += 1
	return count


func get_next_level_for_chapter(chapter_id: String) -> int:
	if not is_chapter_unlocked(chapter_id):
		return 0
	for level_id in ChapterCatalog.get_level_ids(chapter_id):
		if not is_level_completed(level_id):
			return level_id
	return 0


func get_chapter_progress(chapter_id: String) -> Dictionary:
	var chapter := ChapterCatalog.get_chapter(chapter_id)
	if chapter.is_empty():
		return {}
	var previous_chapter_id := str(chapter.get("previous_chapter_id", ""))
	var level_ids := ChapterCatalog.get_level_ids(chapter_id)
	var completed := get_completed_level_count(chapter_id)
	var previous_completed := get_completed_level_count(previous_chapter_id)
	var requirement := maxi(int(chapter.get("required_completed_levels", 0)), 0)
	return {
		"chapter_id": chapter_id,
		"completed_levels": completed,
		"total_levels": level_ids.size(),
		"previous_completed_levels": previous_completed,
		"required_completed_levels": requirement,
		"unlocked": is_chapter_unlocked(chapter_id),
		"complete": not level_ids.is_empty() and completed >= level_ids.size(),
		"has_levels": not level_ids.is_empty(),
		"next_level": get_next_level_for_chapter(chapter_id),
	}


func get_ability_uses() -> Dictionary:
	var ability_uses := _data.get("ability_uses", {}) as Dictionary
	if ability_uses == null:
		return DEFAULT_ABILITY_USES.duplicate()

	return ability_uses.duplicate()


func get_coins() -> int:
	return maxi(int(_data.get("coins", DEFAULT_COINS)), 0)


func get_total_earned_stars() -> int:
	return maxi(int(_data.get("total_earned_stars", 0)), 0)


func get_weekly_earned_stars() -> int:
	if _refresh_leaderboard_week_state():
		save_progress()

	return maxi(int(_data.get("weekly_earned_stars", 0)), 0)


func get_current_leaderboard_week_start_unix() -> int:
	var now_unix := int(Time.get_unix_time_from_system())
	var day_number := floori(float(now_unix) / float(24 * 60 * 60))
	var days_since_monday := posmod(day_number + UNIX_EPOCH_MONDAY_OFFSET_DAYS, 7)
	return (day_number - days_since_monday) * 24 * 60 * 60


func get_current_leaderboard_week_end_unix() -> int:
	return get_current_leaderboard_week_start_unix() + LEADERBOARD_WEEK_SECONDS


func spend_coins(amount: int, reason: String = "gameplay") -> bool:
	var normalized_amount := maxi(amount, 0)
	if normalized_amount <= 0:
		return true

	var coins := get_coins()
	if coins < normalized_amount:
		return false

	var previous_data := _data.duplicate(true)
	_data["coins"] = coins - normalized_amount
	return _commit_or_restore(previous_data, [{
		"operation_type": "resource_spend",
		"payload": {
			"asset": "coins",
			"amount": normalized_amount,
			"reason": (
				reason
				if ["ability_use", "gameplay", "shop", "time_extension"].has(reason)
				else "gameplay"
			),
		},
	}])


func apply_shop_purchase(
	transaction_id: String,
	rewards: Dictionary,
	offer_id: String = ""
) -> Dictionary:
	var normalized_transaction_id := transaction_id.strip_edges()
	if normalized_transaction_id.is_empty():
		return {"ok": false, "applied": false, "error": "Purchase transaction id is empty."}

	var processed_ids := _get_processed_shop_purchase_ids()
	if processed_ids.has(normalized_transaction_id):
		return {"ok": true, "applied": false}

	var previous_data := _data.duplicate(true)
	var granted_coins := maxi(int(rewards.get("coins", 0)), 0)
	var granted_abilities := {}
	var raw_abilities = rewards.get("abilities", {})
	if raw_abilities is Dictionary:
		var ability_uses := get_ability_uses()
		for ability_id in DEFAULT_ABILITY_USES.keys():
			var granted_uses := maxi(int((raw_abilities as Dictionary).get(ability_id, 0)), 0)
			if granted_uses <= 0:
				continue
			ability_uses[ability_id] = int(ability_uses.get(ability_id, 0)) + granted_uses
			granted_abilities[ability_id] = granted_uses
		_data["ability_uses"] = ability_uses

	_data["coins"] = get_coins() + granted_coins
	processed_ids.append(normalized_transaction_id)
	_data["processed_shop_purchase_ids"] = processed_ids
	var normalized_offer_id := offer_id.strip_edges()
	if not normalized_offer_id.is_empty():
		var purchased_offer_ids := _get_purchased_shop_offer_ids()
		if not purchased_offer_ids.has(normalized_offer_id):
			purchased_offer_ids.append(normalized_offer_id)
		_data["purchased_shop_offer_ids"] = purchased_offer_ids
	if not _commit_or_restore(previous_data):
		return {"ok": false, "applied": false, "error": "Could not persist the verified purchase fact."}
	return {
		"ok": true,
		"applied": true,
		"coins": granted_coins,
		"abilities": granted_abilities,
	}


func has_purchased_shop_offer(offer_id: StringName) -> bool:
	var normalized_offer_id := String(offer_id).strip_edges()
	return (
		not normalized_offer_id.is_empty()
		and _get_purchased_shop_offer_ids().has(normalized_offer_id)
	)


func get_reward_chest_progress() -> Dictionary:
	var goals := _get_reward_chest_goals()
	var goal_index := _get_reward_chest_goal_index(goals)
	var active_goal := goals[goal_index] as Dictionary
	return {
		"stars": maxi(int(_data.get("reward_chest_stars", 0)), 0),
		"goal": int(active_goal.get("stars", 1)),
		"goal_index": goal_index,
		"coin_reward": int(active_goal.get("coin_reward", 0)),
	}


func get_reward_chest_goal_at_index(goal_index: int) -> int:
	var goals := _get_reward_chest_goals()
	return _get_reward_chest_goal_stars(goals, clampi(goal_index, 0, goals.size() - 1))


## The coin reward attached to one specific goal, for owners animating past goals the player has
## already crossed (the Main Menu's staggered star flight). Read-only: the grant itself still
## happens once inside _apply_reward_chest_stars().
func get_reward_chest_goal_coin_reward_at_index(goal_index: int) -> int:
	var goals := _get_reward_chest_goals()
	return _get_reward_chest_goal_coin_reward(goals, clampi(goal_index, 0, goals.size() - 1))


func get_reward_chest_last_goal_index() -> int:
	return maxi(_get_reward_chest_goals().size() - 1, 0)


func consume_pending_reward_chest_animation() -> Dictionary:
	var pending := _pending_reward_chest_animation.duplicate()
	_pending_reward_chest_animation.clear()
	return pending


## Records the best (lowest-numbered) Weekly rank the leaderboard screen has observed this week,
## so a reward can be granted for it once the week rolls over even if the player never has the
## leaderboard open at the exact reset moment. Call this whenever a Weekly fetch resolves with a
## valid player rank.
func record_weekly_leaderboard_rank(rank: int) -> void:
	var safe_rank := maxi(rank, 0)
	if safe_rank <= 0:
		return

	_refresh_leaderboard_week_state()
	var current_week_start := get_current_leaderboard_week_start_unix()
	var observation := _data.get("last_weekly_rank_observation", {}) as Dictionary
	var has_better_observation := (
		int(observation.get("week_start_unix", -1)) == current_week_start
		and int(observation.get("rank", 0)) > 0
		and int(observation.get("rank", 0)) <= safe_rank
	)
	if has_better_observation:
		return

	_data["last_weekly_rank_observation"] = {
		"week_start_unix": current_week_start,
		"rank": safe_rank,
	}
	save_progress()


## Drains the coin reward granted by the most recent weekly rollover, if any. Consuming clears it
## so it is only ever shown once.
func consume_pending_leaderboard_reward() -> Dictionary:
	var pending := _pending_leaderboard_reward.duplicate()
	_pending_leaderboard_reward.clear()
	return pending


func get_leaderboard_reward_tiers() -> Array:
	if _leaderboard_reward_tiers.is_empty():
		_leaderboard_reward_tiers = _load_leaderboard_reward_tiers()

	return _leaderboard_reward_tiers.duplicate(true)


func add_reward_chest_stars(star_count: int) -> void:
	var previous_data := _data.duplicate(true)
	if _apply_reward_chest_stars(star_count):
		_commit_or_restore(previous_data)


func get_available_avatar_ids() -> Array:
	return AVAILABLE_AVATAR_IDS.duplicate()


func get_available_avatar_frame_ids() -> Array[String]:
	return ProfileFrameCatalogScript.get_available_frame_ids()


func get_avatar_id() -> String:
	return _sanitize_avatar_id(str(_data.get("avatar_id", DEFAULT_AVATAR_ID)))


func get_avatar_frame_id() -> String:
	return _sanitize_avatar_frame_id(str(_data.get(
		"avatar_frame_id",
		ProfileFrameCatalogScript.get_default_frame_id()
	)))


func get_avatar_texture_path(avatar_id: String) -> String:
	return AVATAR_TEXTURE_PATH_FORMAT % _sanitize_avatar_id(avatar_id)


func get_player_name() -> String:
	return _sanitize_player_name(str(_data.get("player_name", "")))


func get_disabled_settings() -> Dictionary:
	var disabled_settings := _data.get("settings_disabled", {}) as Dictionary
	if disabled_settings == null:
		return DEFAULT_DISABLED_SETTINGS.duplicate()

	return disabled_settings.duplicate()


## Local-only ad pacing is a preference partition: it controls presentation frequency but cannot
## grant economy or gameplay state and is never emitted as a backend journal operation.
func get_ad_pacing_state() -> Dictionary:
	return AdPacingStateScript.sanitize(_data.get("ad_pacing_state", {}))


func set_ad_pacing_state(raw_state: Dictionary) -> bool:
	var sanitized := AdPacingStateScript.sanitize(raw_state)
	if get_ad_pacing_state() == sanitized:
		return true
	var previous_data := _data.duplicate(true)
	_data["ad_pacing_state"] = sanitized
	return _commit_or_restore(previous_data)


func is_setting_disabled(setting_id: StringName) -> bool:
	var disabled_settings := get_disabled_settings()
	return bool(disabled_settings.get(String(setting_id), false))


func set_setting_disabled(setting_id: StringName, is_disabled: bool) -> bool:
	var setting_key := String(setting_id)
	if not DEFAULT_DISABLED_SETTINGS.has(setting_key):
		return false

	var disabled_settings := get_disabled_settings()
	if bool(disabled_settings.get(setting_key, false)) == is_disabled:
		return true

	disabled_settings[setting_key] = is_disabled
	var previous_data := _data.duplicate(true)
	_data["settings_disabled"] = disabled_settings
	return _commit_or_restore(previous_data)


func set_avatar_id(avatar_id: String) -> bool:
	if not AVAILABLE_AVATAR_IDS.has(avatar_id):
		return false

	if get_avatar_id() == avatar_id:
		return true

	var previous_data := _data.duplicate(true)
	_data["avatar_id"] = avatar_id
	return _commit_or_restore(previous_data, [{
		"operation_type": "profile_edit",
		"payload": {"avatar_id": avatar_id},
	}])


func set_player_name(player_name: String) -> bool:
	var sanitized_player_name := _sanitize_player_name(player_name, get_player_name())
	if get_player_name() == sanitized_player_name:
		return true

	var previous_data := _data.duplicate(true)
	_data["player_name"] = sanitized_player_name
	return _commit_or_restore(previous_data, [{
		"operation_type": "profile_edit",
		"payload": {"display_name": sanitized_player_name},
	}])


func set_profile(avatar_id: String, player_name: String) -> bool:
	return set_profile_customization(avatar_id, get_avatar_frame_id(), player_name)


func set_profile_customization(avatar_id: String, avatar_frame_id: String, player_name: String) -> bool:
	if not AVAILABLE_AVATAR_IDS.has(avatar_id):
		return false
	if not ProfileFrameCatalogScript.get_available_frame_ids().has(avatar_frame_id):
		return false

	var sanitized_player_name := _sanitize_player_name(player_name, get_player_name())
	var previous_data := _data.duplicate(true)
	var did_change := false
	var profile_payload := {}
	if get_avatar_id() != avatar_id:
		_data["avatar_id"] = avatar_id
		profile_payload["avatar_id"] = avatar_id
		did_change = true
	if get_avatar_frame_id() != avatar_frame_id:
		_data["avatar_frame_id"] = avatar_frame_id
		profile_payload["avatar_frame_id"] = avatar_frame_id
		did_change = true
	if get_player_name() != sanitized_player_name:
		_data["player_name"] = sanitized_player_name
		profile_payload["display_name"] = sanitized_player_name
		did_change = true

	if did_change:
		return _commit_or_restore(previous_data, [{
			"operation_type": "profile_edit",
			"payload": profile_payload,
		}])

	return true


func get_lives() -> int:
	refresh_lives()
	return int(_data.get("lives", MAX_LIVES))


func get_max_lives() -> int:
	return MAX_LIVES


func get_life_purchase_coin_price() -> int:
	return _life_purchase_coin_price


## Buys exactly one life using the bundled, configurable coin price. The updated snapshot and
## single life_purchase journal operation are written in one crash-safe local save generation, so
## offline play never persists the coin spend without the matching life state (or vice versa).
func purchase_life() -> bool:
	refresh_lives()
	var lives := int(_data.get("lives", MAX_LIVES))
	if lives >= MAX_LIVES or get_coins() < _life_purchase_coin_price:
		return false

	var previous_data := _data.duplicate(true)
	_data["coins"] = get_coins() - _life_purchase_coin_price
	_data["lives"] = lives + 1
	if int(_data.get("lives", 0)) >= MAX_LIVES:
		_data["next_life_restore_unix"] = 0
	elif int(_data.get("next_life_restore_unix", 0)) <= 0:
		_data["next_life_restore_unix"] = (
			int(Time.get_unix_time_from_system()) + LIFE_RESTORE_SECONDS
		)

	return _commit_or_restore(previous_data, [_life_purchase_operation()])


func get_next_life_restore_seconds_remaining() -> int:
	refresh_lives()
	if get_lives() >= MAX_LIVES:
		return 0

	var next_restore_unix := int(_data.get("next_life_restore_unix", 0))
	if next_restore_unix <= 0:
		return LIFE_RESTORE_SECONDS

	var now_unix := int(Time.get_unix_time_from_system())
	return maxi(next_restore_unix - now_unix, 0)


func refresh_lives() -> void:
	var previous_data := _data.duplicate(true)
	if _refresh_lives_state():
		_commit_or_restore(previous_data, [_life_state_operation()])


func spend_life(level_number: int = 0, outcome: String = "left") -> bool:
	refresh_lives()
	var lives := int(_data.get("lives", MAX_LIVES))
	if lives <= 0:
		return false

	var previous_data := _data.duplicate(true)
	_data["lives"] = lives - 1
	if int(_data.get("lives", 0)) < MAX_LIVES and int(_data.get("next_life_restore_unix", 0)) <= 0:
		_data["next_life_restore_unix"] = int(Time.get_unix_time_from_system()) + LIFE_RESTORE_SECONDS

	var operations := []
	if level_number >= MIN_LEVEL:
		var attempt_payload := _campaign_attempt_payload(level_number, outcome)
		if not attempt_payload.is_empty():
			operations.append({
				"operation_type": "campaign_attempt",
				"payload": attempt_payload,
			})
	operations.append(_life_state_operation())
	return _commit_or_restore(previous_data, operations)


## Mirrors a life state already committed by an authoritative online-run transaction. This writes
## no local-first operation: journaling another decrement would spend the same reserved life twice
## when the v2 checkpoint is rebuilt from the online-run result.
func apply_authoritative_life_state(life_state: Dictionary) -> bool:
	if not life_state.has("current") or not life_state.has("maximum"):
		return false
	var maximum := int(life_state.get("maximum", 0))
	var current := int(life_state.get("current", -1))
	if maximum <= 0 or current < 0 or current > maximum:
		return false
	var previous_data := _data.duplicate(true)
	_data["lives"] = clampi(current, 0, MAX_LIVES)
	_data["next_life_restore_unix"] = LocalSaveCodecScript.unix_from_timestamp(
		life_state.get("next_restore_at")
	)
	if int(_data.get("lives", 0)) >= MAX_LIVES:
		_data["next_life_restore_unix"] = 0
	return _commit_or_restore(previous_data)


func spend_ability(ability_id: StringName) -> bool:
	var ability_key := String(ability_id)
	if not DEFAULT_ABILITY_USES.has(ability_key):
		return false
	var ability_uses := _data.get("ability_uses", {}) as Dictionary
	if ability_uses == null:
		ability_uses = DEFAULT_ABILITY_USES.duplicate()
		_data["ability_uses"] = ability_uses

	var uses_left := int(ability_uses.get(ability_key, 0))
	if uses_left <= 0:
		return false

	var previous_data := _data.duplicate(true)
	ability_uses[ability_key] = uses_left - 1
	return _commit_or_restore(previous_data, [{
		"operation_type": "resource_spend",
		"payload": {
			"asset": ability_key,
			"amount": 1,
			"reason": "ability_use",
		},
	}])


func complete_level(level_number: int, earned_stars: int = 0) -> bool:
	var chapter_id := ChapterCatalog.get_chapter_id_for_level(level_number)
	if chapter_id.is_empty() or not is_chapter_unlocked(chapter_id):
		return false
	if is_level_completed(level_number) or get_next_level_for_chapter(chapter_id) != level_number:
		return false

	var safe_earned_stars := maxi(earned_stars, 0)
	var previous_data := _data.duplicate(true)
	var previous_animation := _pending_reward_chest_animation.duplicate(true)
	var starting_progress := get_reward_chest_progress()
	_record_level_completion(level_number, safe_earned_stars)
	_apply_reward_chest_stars(safe_earned_stars)
	if safe_earned_stars > 0:
		_refresh_leaderboard_week_state()
		_data["total_earned_stars"] = get_total_earned_stars() + safe_earned_stars
		_data["weekly_earned_stars"] = get_weekly_earned_stars() + safe_earned_stars
		_pending_reward_chest_animation = {
			"amount": safe_earned_stars,
			"start_stars": int(starting_progress.get("stars", 0)),
			"start_goal_index": int(starting_progress.get("goal_index", 0)),
		}
	var operations := []
	var completion_payload := _campaign_completion_payload(level_number, safe_earned_stars)
	if not completion_payload.is_empty():
		operations.append({
			"operation_type": "campaign_completion",
			"payload": completion_payload,
		})
	var result := _commit_current_state(operations)
	if not bool(result.get("ok", false)):
		_data = previous_data
		_pending_reward_chest_animation = previous_animation
		push_error("Could not atomically save completed level %d." % level_number)
		return false
	return true


func reset_progress() -> void:
	var previous_data := _data.duplicate(true)
	_data = _default_data()
	_pending_reward_chest_animation.clear()
	_pending_leaderboard_reward.clear()
	if not _commit_current_state().get("ok", false):
		_data = previous_data


func get_save_provider_name() -> String:
	return "local_first_v2"


func _sanitize_data(raw_data: Dictionary) -> Dictionary:
	var sanitized := _default_data()
	var source_version := maxi(int(raw_data.get("version", 0)), 0)
	sanitized["version"] = SAVE_VERSION
	var legacy_highest_completed := maxi(int(raw_data.get("highest_completed_level", 0)), 0)
	legacy_highest_completed = maxi(
		legacy_highest_completed,
		maxi(int(raw_data.get("current_level", MIN_LEVEL)) - 1, 0)
	)
	sanitized["completion_stars_by_level"] = _sanitize_completion_stars(
		raw_data.get("completion_stars_by_level", {}),
		legacy_highest_completed
	)
	_apply_legacy_cursor(sanitized)
	sanitized["lives"] = clampi(int(raw_data.get("lives", MAX_LIVES)), 0, MAX_LIVES)
	sanitized["next_life_restore_unix"] = maxi(int(raw_data.get("next_life_restore_unix", 0)), 0)
	sanitized["coins"] = maxi(int(raw_data.get("coins", DEFAULT_COINS)), 0)
	sanitized["processed_shop_purchase_ids"] = _sanitize_processed_shop_purchase_ids(
		raw_data.get("processed_shop_purchase_ids", [])
	)
	sanitized["purchased_shop_offer_ids"] = _sanitize_purchased_shop_offer_ids(
		raw_data.get("purchased_shop_offer_ids", [])
	)
	sanitized["avatar_id"] = _sanitize_avatar_id(str(raw_data.get("avatar_id", DEFAULT_AVATAR_ID)))
	sanitized["avatar_frame_id"] = _sanitize_avatar_frame_id(str(raw_data.get(
		"avatar_frame_id",
		ProfileFrameCatalogScript.get_default_frame_id()
	)))
	sanitized["player_name"] = _sanitize_player_name(str(raw_data.get("player_name", sanitized["player_name"])), sanitized["player_name"])
	sanitized["moderation_state"] = str(raw_data.get("moderation_state", "active"))
	sanitized["settings_disabled"] = _sanitize_disabled_settings(raw_data.get("settings_disabled", {}))
	sanitized["ad_pacing_state"] = AdPacingStateScript.sanitize(
		raw_data.get("ad_pacing_state", {})
	)
	sanitized["selected_chapter_id"] = _sanitize_selected_chapter_id(
		str(raw_data.get("selected_chapter_id", _default_chapter_id())),
		sanitized["completion_stars_by_level"] as Dictionary
	)
	sanitized["total_earned_stars"] = maxi(
		int(raw_data.get("total_earned_stars", raw_data.get("reward_chest_stars", 0))),
		0
	)
	var current_week_start := get_current_leaderboard_week_start_unix()
	var saved_week_start := int(raw_data.get("leaderboard_week_start_unix", current_week_start))
	sanitized["leaderboard_week_start_unix"] = saved_week_start
	sanitized["weekly_earned_stars"] = maxi(int(raw_data.get("weekly_earned_stars", 0)), 0)
	sanitized["last_weekly_rank_observation"] = _sanitize_rank_observation(
		raw_data.get("last_weekly_rank_observation", {})
	)
	var granted_reward := _apply_leaderboard_week_rollover(sanitized, saved_week_start)
	if not granted_reward.is_empty():
		_pending_leaderboard_reward = granted_reward
	var reward_chest_state := _normalize_reward_chest_progress(
		maxi(int(raw_data.get("reward_chest_stars", 0)), 0),
		maxi(int(raw_data.get("reward_chest_goal_index", 0)), 0)
	)
	sanitized["reward_chest_stars"] = reward_chest_state["stars"]
	sanitized["reward_chest_goal_index"] = reward_chest_state["goal_index"]
	sanitized["reward_chest_completed_cycles"] = maxi(
		int(raw_data.get("reward_chest_completed_cycles", 0)),
		0
	)
	if int(sanitized["lives"]) >= MAX_LIVES:
		sanitized["next_life_restore_unix"] = 0
	elif int(sanitized["next_life_restore_unix"]) <= 0:
		sanitized["next_life_restore_unix"] = int(Time.get_unix_time_from_system()) + LIFE_RESTORE_SECONDS

	var raw_ability_uses := raw_data.get("ability_uses", {}) as Dictionary
	if raw_ability_uses != null:
		var ability_uses := sanitized["ability_uses"] as Dictionary
		for ability_key in DEFAULT_ABILITY_USES.keys():
			ability_uses[ability_key] = maxi(int(raw_ability_uses.get(ability_key, ability_uses[ability_key])), 0)
		if source_version > 0 and source_version < 5:
			ability_uses[ABILITY_FREEZER] = maxi(
				int(raw_ability_uses.get(ABILITY_FREEZER, 0)),
				0
			) + DEFAULT_ABILITY_USES[ABILITY_FREEZER]

	return sanitized


func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"current_level": MIN_LEVEL,
		"highest_completed_level": 0,
		"completion_stars_by_level": {},
		"lives": MAX_LIVES,
		"next_life_restore_unix": 0,
		"coins": DEFAULT_COINS,
		"processed_shop_purchase_ids": [],
		"purchased_shop_offer_ids": [],
		"ability_uses": DEFAULT_ABILITY_USES.duplicate(),
		"avatar_id": DEFAULT_AVATAR_ID,
		"avatar_frame_id": ProfileFrameCatalogScript.get_default_frame_id(),
		"player_name": _generate_player_name(),
		"moderation_state": "active",
		"settings_disabled": DEFAULT_DISABLED_SETTINGS.duplicate(),
		"ad_pacing_state": AdPacingStateScript.create_default(),
		"selected_chapter_id": _default_chapter_id(),
		"total_earned_stars": 0,
		"leaderboard_week_start_unix": get_current_leaderboard_week_start_unix(),
		"weekly_earned_stars": 0,
		"last_weekly_rank_observation": {},
		"reward_chest_stars": 0,
		"reward_chest_goal_index": 0,
		"reward_chest_completed_cycles": 0,
	}


## Schema 8 introduced avatar frames as a local-only field. Preserve a non-default selection made
## by those clients by turning it into one signed profile edit before the first authoritative
## checkpoint can replace it. A classic value is not backfilled because schema 8 cannot distinguish
## an explicit classic selection from the default; uploading every default would incorrectly win
## over a frame selected on another device.
func _schema_migration_operations(source_snapshot: Dictionary) -> Array:
	if int(source_snapshot.get("version", 0)) != 8:
		return []
	var frame_id := _sanitize_avatar_frame_id(str(source_snapshot.get(
		"avatar_frame_id",
		ProfileFrameCatalogScript.get_default_frame_id()
	)))
	if frame_id == ProfileFrameCatalogScript.get_default_frame_id():
		return []
	return [{
		"operation_type": "profile_edit",
		"payload": {"avatar_frame_id": frame_id},
	}]


func _sanitize_avatar_id(avatar_id: String) -> String:
	if AVAILABLE_AVATAR_IDS.has(avatar_id):
		return avatar_id

	return DEFAULT_AVATAR_ID


func _sanitize_avatar_frame_id(avatar_frame_id: String) -> String:
	return ProfileFrameCatalogScript.sanitize_frame_id(avatar_frame_id)


func _sanitize_player_name(player_name: String, fallback_name: String = "") -> String:
	var sanitized_name := player_name.strip_edges()
	if sanitized_name.is_empty():
		return fallback_name if not fallback_name.is_empty() else _generate_player_name()

	return sanitized_name.left(24)


func _sanitize_disabled_settings(raw_settings) -> Dictionary:
	var sanitized := DEFAULT_DISABLED_SETTINGS.duplicate()
	if not (raw_settings is Dictionary):
		return sanitized

	var raw_dictionary := raw_settings as Dictionary
	for setting_key in DEFAULT_DISABLED_SETTINGS.keys():
		sanitized[setting_key] = bool(raw_dictionary.get(setting_key, sanitized[setting_key]))

	return sanitized


func _get_processed_shop_purchase_ids() -> Array:
	return _sanitize_processed_shop_purchase_ids(_data.get("processed_shop_purchase_ids", []))


func _sanitize_processed_shop_purchase_ids(raw_ids) -> Array:
	var sanitized := []
	if not (raw_ids is Array):
		return sanitized

	for raw_id in raw_ids as Array:
		var transaction_id := str(raw_id).strip_edges()
		if not transaction_id.is_empty() and not sanitized.has(transaction_id):
			sanitized.append(transaction_id)

	return sanitized


func _get_purchased_shop_offer_ids() -> Array:
	return _sanitize_purchased_shop_offer_ids(_data.get("purchased_shop_offer_ids", []))


func _sanitize_purchased_shop_offer_ids(raw_ids) -> Array:
	var sanitized := []
	if not (raw_ids is Array):
		return sanitized

	for raw_id in raw_ids as Array:
		var offer_id := str(raw_id).strip_edges()
		if not offer_id.is_empty() and not sanitized.has(offer_id):
			sanitized.append(offer_id)

	return sanitized


func _apply_reward_chest_stars(star_count: int) -> bool:
	if star_count <= 0:
		return false

	var normalized := _normalize_reward_chest_progress(
		maxi(int(_data.get("reward_chest_stars", 0)), 0) + star_count,
		_get_reward_chest_goal_index(_get_reward_chest_goals())
	)
	_data["reward_chest_stars"] = normalized["stars"]
	_data["reward_chest_goal_index"] = normalized["goal_index"]
	_data["reward_chest_completed_cycles"] = int(
		_data.get("reward_chest_completed_cycles", 0)
	) + int(normalized.get("completed_cycles", 0))
	_data["coins"] = get_coins() + int(normalized.get("coin_reward", 0))
	return true


func _normalize_reward_chest_progress(stars: int, goal_index: int) -> Dictionary:
	var goals := _get_reward_chest_goals()
	var safe_goal_index := clampi(goal_index, 0, goals.size() - 1)
	var safe_stars := maxi(stars, 0)
	var coin_reward := 0
	var completed_cycles := 0

	while safe_stars >= _get_reward_chest_goal_stars(goals, safe_goal_index):
		safe_stars -= _get_reward_chest_goal_stars(goals, safe_goal_index)
		coin_reward += _get_reward_chest_goal_coin_reward(goals, safe_goal_index)
		completed_cycles += 1
		if safe_goal_index < goals.size() - 1:
			safe_goal_index += 1

	return {
		"stars": safe_stars,
		"goal_index": safe_goal_index,
		"coin_reward": coin_reward,
		"completed_cycles": completed_cycles,
	}


func _get_reward_chest_goal_index(goals: Array) -> int:
	return clampi(int(_data.get("reward_chest_goal_index", 0)), 0, goals.size() - 1)


func _get_reward_chest_goal_stars(goals: Array, goal_index: int) -> int:
	var goal := goals[clampi(goal_index, 0, goals.size() - 1)] as Dictionary
	return maxi(int(goal.get("stars", 1)), 1)


func _get_reward_chest_goal_coin_reward(goals: Array, goal_index: int) -> int:
	var goal := goals[clampi(goal_index, 0, goals.size() - 1)] as Dictionary
	return maxi(int(goal.get("coin_reward", 0)), 0)


func _get_reward_chest_goals() -> Array:
	if _reward_chest_goals.is_empty():
		_reward_chest_goals = _load_reward_chest_goals()

	return _reward_chest_goals.duplicate()


func _load_reward_chest_goals() -> Array:
	if not FileAccess.file_exists(REWARD_CHEST_GOALS_CONFIG):
		return DEFAULT_REWARD_CHEST_GOALS.duplicate()

	var config_file := FileAccess.open(REWARD_CHEST_GOALS_CONFIG, FileAccess.READ)
	if config_file == null:
		push_warning("Could not open reward chest goals config: %s" % REWARD_CHEST_GOALS_CONFIG)
		return DEFAULT_REWARD_CHEST_GOALS.duplicate()

	var parsed_config = JSON.parse_string(config_file.get_as_text())
	if not (parsed_config is Dictionary):
		push_warning("Reward chest goals config must contain a JSON object.")
		return DEFAULT_REWARD_CHEST_GOALS.duplicate()

	var parsed_goals := []
	var parsed_dictionary := parsed_config as Dictionary
	var raw_goals = parsed_dictionary.get("goals", [])
	if not (raw_goals is Array):
		push_warning("Reward chest goals config must define goals as an array.")
		return DEFAULT_REWARD_CHEST_GOALS.duplicate()

	for raw_goal in raw_goals:
		var parsed_goal := _parse_reward_chest_goal(raw_goal)
		if not parsed_goal.is_empty():
			parsed_goals.append(parsed_goal)

	if parsed_goals.is_empty():
		push_warning("Reward chest goals config does not define positive goals.")
		return DEFAULT_REWARD_CHEST_GOALS.duplicate()

	return parsed_goals


func _parse_reward_chest_goal(raw_goal) -> Dictionary:
	if raw_goal is Dictionary:
		var goal_dictionary := raw_goal as Dictionary
		var stars := maxi(int(goal_dictionary.get("stars", 0)), 0)
		var coin_reward := maxi(int(goal_dictionary.get("coin_reward", 0)), 0)
		if stars <= 0:
			return {}

		return {
			"stars": stars,
			"coin_reward": coin_reward,
		}

	var legacy_stars := maxi(int(raw_goal), 0)
	if legacy_stars <= 0:
		return {}

	return {
		"stars": legacy_stars,
		"coin_reward": 0,
	}


func _load_leaderboard_reward_tiers() -> Array:
	if not FileAccess.file_exists(LEADERBOARD_REWARD_TIERS_CONFIG):
		return DEFAULT_LEADERBOARD_REWARD_TIERS.duplicate(true)

	var config_file := FileAccess.open(LEADERBOARD_REWARD_TIERS_CONFIG, FileAccess.READ)
	if config_file == null:
		push_warning(
			"Could not open leaderboard reward tiers config: %s" % LEADERBOARD_REWARD_TIERS_CONFIG
		)
		return DEFAULT_LEADERBOARD_REWARD_TIERS.duplicate(true)

	var parsed_config = JSON.parse_string(config_file.get_as_text())
	if not (parsed_config is Dictionary):
		push_warning("Leaderboard reward tiers config must contain a JSON object.")
		return DEFAULT_LEADERBOARD_REWARD_TIERS.duplicate(true)

	var raw_tiers = (parsed_config as Dictionary).get("tiers", [])
	if not (raw_tiers is Array):
		push_warning("Leaderboard reward tiers config must define tiers as an array.")
		return DEFAULT_LEADERBOARD_REWARD_TIERS.duplicate(true)

	var parsed_tiers := []
	for raw_tier in raw_tiers as Array:
		var parsed_tier := _parse_leaderboard_reward_tier(raw_tier)
		if not parsed_tier.is_empty():
			parsed_tiers.append(parsed_tier)

	if parsed_tiers.is_empty():
		push_warning("Leaderboard reward tiers config does not define valid tiers.")
		return DEFAULT_LEADERBOARD_REWARD_TIERS.duplicate(true)

	return parsed_tiers


func _parse_leaderboard_reward_tier(raw_tier) -> Dictionary:
	if not (raw_tier is Dictionary):
		return {}

	var tier := raw_tier as Dictionary
	var min_rank := maxi(int(tier.get("min_rank", 0)), 1)
	var max_rank := maxi(int(tier.get("max_rank", 0)), min_rank)
	var coin_reward := maxi(int(tier.get("coin_reward", 0)), 0)
	if coin_reward <= 0:
		return {}

	return {"min_rank": min_rank, "max_rank": max_rank, "coin_reward": coin_reward}


func _get_leaderboard_reward_tier_coins(rank: int) -> int:
	if rank <= 0:
		return 0

	for raw_tier in get_leaderboard_reward_tiers():
		var tier := raw_tier as Dictionary
		if rank >= int(tier.get("min_rank", 1)) and rank <= int(tier.get("max_rank", 0)):
			return int(tier.get("coin_reward", 0))

	return 0


func _generate_player_name() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var suffix := ""
	for index in range(PLAYER_NAME_RANDOM_LENGTH):
		var suffix_index := rng.randi_range(0, PLAYER_NAME_RANDOM_ALPHABET.length() - 1)
		suffix += PLAYER_NAME_RANDOM_ALPHABET.substr(suffix_index, 1)

	return "%s%s" % [PLAYER_NAME_PREFIX, suffix]


func _refresh_lives_state() -> bool:
	var current_lives := clampi(int(_data.get("lives", MAX_LIVES)), 0, MAX_LIVES)
	var next_restore_unix := maxi(int(_data.get("next_life_restore_unix", 0)), 0)
	var original_lives := current_lives
	var original_next_restore_unix := next_restore_unix

	if current_lives >= MAX_LIVES:
		next_restore_unix = 0
	else:
		var now_unix := int(Time.get_unix_time_from_system())
		if next_restore_unix <= 0:
			next_restore_unix = now_unix + LIFE_RESTORE_SECONDS
		elif next_restore_unix <= now_unix:
			var elapsed_after_next_restore := now_unix - next_restore_unix
			var restored_lives := 1 + floori(float(elapsed_after_next_restore) / float(LIFE_RESTORE_SECONDS))
			current_lives = mini(current_lives + restored_lives, MAX_LIVES)
			if current_lives >= MAX_LIVES:
				next_restore_unix = 0
			else:
				next_restore_unix += restored_lives * LIFE_RESTORE_SECONDS

	_data["lives"] = current_lives
	_data["next_life_restore_unix"] = next_restore_unix
	return current_lives != original_lives or next_restore_unix != original_next_restore_unix


func _refresh_leaderboard_week_state() -> bool:
	var current_week_start := get_current_leaderboard_week_start_unix()
	var previous_week_start := int(_data.get("leaderboard_week_start_unix", current_week_start))
	if previous_week_start == current_week_start:
		return false

	var granted_reward := _apply_leaderboard_week_rollover(_data, previous_week_start)
	if not granted_reward.is_empty():
		_pending_leaderboard_reward = granted_reward
	return true


## Shared by both places a leaderboard week rollover can be detected: `_sanitize_data()` (the
## load-time path, taken whenever the app was closed across the boundary -- the common case) and
## `_refresh_leaderboard_week_state()` (the runtime path, taken if the app stays open across it).
## Resets the weekly score in `target` and, if `target` carries a rank observation from the week
## that just ended, grants that rank's configured coin reward. Mutates `target` in place and
## returns the granted reward (empty if the week did not roll over, there was no observation for
## it, or no tier matched).
func _apply_leaderboard_week_rollover(target: Dictionary, previous_week_start: int) -> Dictionary:
	var current_week_start := get_current_leaderboard_week_start_unix()
	if previous_week_start == current_week_start:
		return {}

	target["leaderboard_week_start_unix"] = current_week_start
	target["weekly_earned_stars"] = 0

	var observation := target.get("last_weekly_rank_observation", {}) as Dictionary
	target["last_weekly_rank_observation"] = {}
	if int(observation.get("week_start_unix", -1)) != previous_week_start:
		return {}

	var rank := maxi(int(observation.get("rank", 0)), 0)
	var coin_reward := _get_leaderboard_reward_tier_coins(rank)
	if coin_reward <= 0:
		return {}

	target["coins"] = maxi(int(target.get("coins", DEFAULT_COINS)), 0) + coin_reward
	return {"rank": rank, "coin_reward": coin_reward, "week_start_unix": previous_week_start}


func _sanitize_rank_observation(raw_observation) -> Dictionary:
	if not (raw_observation is Dictionary):
		return {}

	var observation := raw_observation as Dictionary
	var week_start := int(observation.get("week_start_unix", 0))
	var rank := int(observation.get("rank", 0))
	if week_start <= 0 or rank <= 0:
		return {}

	return {"week_start_unix": week_start, "rank": rank}


func bind_registered_guest(player_id: String, session: Dictionary) -> bool:
	var result: Dictionary = _account_coordinator.bind_registered_guest(player_id, session)
	if not bool(result.get("ok", false)):
		push_warning("Could not bind guest progress: %s" % result.get("error", ""))
		return false
	_activate_coordinator_result(result)
	return true


func switch_to_player(
	player_id: String,
	session: Dictionary = {},
	remote_checkpoint: Dictionary = {}
) -> bool:
	var result: Dictionary = _account_coordinator.switch_to_player(player_id, session, remote_checkpoint)
	if not bool(result.get("ok", false)):
		push_warning("Could not switch player save: %s" % result.get("error", ""))
		return false
	_activate_coordinator_result(result)
	var checkpoint = result.get("remote_checkpoint")
	if checkpoint is Dictionary and not checkpoint.is_empty():
		var mapped := _map_checkpoint_to_snapshot(checkpoint, _local_store.get_snapshot(), [])
		var cursor := {
			"device_id": _session_store.get_device_id(),
			"acknowledged_sequence": 0,
			"acknowledged_hash": null,
		}
		if bool(_local_store.apply_reconciliation(mapped, cursor, checkpoint, []).get("ok", false)):
			_apply_loaded_partitions(mapped, _local_store.get_preferences())
	return true


func sign_out() -> bool:
	var result: Dictionary = _account_coordinator.sign_out()
	if not bool(result.get("ok", false)):
		push_warning("Could not activate signed-out guest progress: %s" % result.get("error", ""))
		return false
	_activate_coordinator_result(result)
	return true


func get_active_save_namespace() -> Dictionary:
	return _account_coordinator.get_active_namespace() if _account_coordinator != null else {}


## GAME-007: shared authenticated read transport for backend features outside the focused save
## services (Shop catalog, leaderboards, purchase status, device list). Session lifecycle and
## active-player resolution are wired once here; callers only issue reads.
func get_backend_transport():
	return _backend_transport


func get_local_save_diagnostics() -> Dictionary:
	if _local_store == null:
		return {}
	var sync: Dictionary = _local_store.get_sync_metadata()
	var cursor := sync.get("cursor", {}) as Dictionary
	var registration := sync.get("guest_registration", {}) as Dictionary
	return {
		"namespace": _local_store.get_namespace(),
		"device_id": _session_store.get_device_id() if _session_store != null else "",
		"generation": _local_store.get_generation(),
		"journal_entries": _local_store.get_journal().size(),
		"journal_head_sequence": int(sync.get("journal_head_sequence", 0)),
		"acknowledged_sequence": int(cursor.get("acknowledged_sequence", 0)),
		"retry_attempt": int(sync.get("retry_attempt", 0)),
		"terminal_error": (sync.get("terminal_error", {}) as Dictionary).duplicate(true),
		"last_correlation_id": str(sync.get("last_correlation_id", "")),
		"guest_registration": {
			"phase": str(registration.get("phase", "")),
			"retry_attempt": int(registration.get("retry_attempt", 0)),
			"terminal_error": (registration.get("terminal_error", {}) as Dictionary).duplicate(true),
		},
		"identity_diagnostics": (sync.get("identity_diagnostics", {}) as Dictionary).duplicate(true),
		"sync_gate": {
			"feature_enabled": bool(ProjectSettings.get_setting("application/config/save_sync_v2_enabled", false)),
			"backend_url_configured": not str(
				ProjectSettings.get_setting("application/config/backend_base_url", "")
			).strip_edges().is_empty(),
			"can_synchronize": _session_store.can_synchronize() if _session_store != null else false,
			"installation_public_key_present": (
				not _session_store.get_installation_public_key_der_base64().is_empty()
				if _session_store != null
				else false
			),
			"content_manifest_valid": _content_provenance != null and _content_provenance.is_valid(),
		},
		"merge_adjustment_count": (sync.get("adjustments", []) as Array).size(),
		"migration": (sync.get("migration", {}) as Dictionary).duplicate(true),
		"content_manifest_valid": _content_provenance != null and _content_provenance.is_valid(),
		"content_manifest_digest": (
			_content_provenance.get_manifest_digest() if _content_provenance != null else ""
		),
		"content_manifest_environment": (
			_content_provenance.get_environment() if _content_provenance != null else ""
		),
		"content_diagnostic": _current_content_diagnostic(),
	}


func _active_player_id() -> String:
	if _local_store == null:
		return ""
	var save_namespace: Dictionary = _local_store.get_namespace()
	return str(save_namespace.get("player_id", "")) if str(save_namespace.get("kind", "")) == "player" else ""


func _activate_coordinator_result(result: Dictionary) -> void:
	_local_store = _account_coordinator.get_store()
	_apply_loaded_partitions(
		result.get("snapshot", {}) as Dictionary,
		result.get("preferences", {}) as Dictionary
	)
	if _sync_service != null:
		_sync_service.replace_store(_local_store)
		_sync_service.request_background_sync()
	if _guest_bootstrap_service != null:
		_guest_bootstrap_service.replace_store(_local_store)
		_guest_bootstrap_service.request_registration()


func _load_legacy_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _apply_loaded_partitions(snapshot: Dictionary, preferences: Dictionary) -> void:
	var combined := snapshot.duplicate(true)
	combined["settings_disabled"] = preferences.get(
		"settings_disabled",
		DEFAULT_DISABLED_SETTINGS
	)
	combined["selected_chapter_id"] = preferences.get(
		"selected_chapter_id",
		_default_chapter_id()
	)
	combined["ad_pacing_state"] = preferences.get(
		"ad_pacing_state",
		AdPacingStateScript.create_default()
	)
	_data = _sanitize_data(combined)


func _snapshot_for_storage() -> Dictionary:
	return _snapshot_without_preferences(_data)


func _snapshot_without_preferences(source: Dictionary) -> Dictionary:
	var snapshot := source.duplicate(true)
	snapshot.erase("settings_disabled")
	snapshot.erase("selected_chapter_id")
	snapshot.erase("ad_pacing_state")
	return snapshot


func _preferences_for_storage() -> Dictionary:
	return {
		"settings_disabled": get_disabled_settings(),
		"selected_chapter_id": get_selected_chapter_id(),
		"ad_pacing_state": get_ad_pacing_state(),
	}


func _commit_current_state(operation_specs: Array = []) -> Dictionary:
	if _local_store == null:
		return {"ok": false, "error": "Local save store is unavailable."}
	var result: Dictionary = _local_store.commit_snapshot(
		_snapshot_for_storage(),
		_preferences_for_storage(),
		operation_specs
	)
	if bool(result.get("ok", false)) and not operation_specs.is_empty() and _sync_service != null:
		_sync_service.notify_local_mutation()
	return result


func _commit_or_restore(previous_data: Dictionary, operation_specs: Array = []) -> bool:
	var result := _commit_current_state(operation_specs)
	if bool(result.get("ok", false)):
		return true
	_data = previous_data
	push_error("Could not commit local-first mutation: %s" % result.get("error", ""))
	return false


func _campaign_completion_payload(level_number: int, earned_stars: int) -> Dictionary:
	var provenance := _campaign_provenance(level_number)
	if provenance.is_empty():
		return {}
	return {
		"campaign_level": level_number,
		"stars": maxi(earned_stars, 0),
		"configuration_version": provenance.get("configuration_version"),
		"level_version": provenance.get("level_version"),
		"rules_version": provenance.get("rules_version"),
	}


func _campaign_attempt_payload(level_number: int, outcome: String) -> Dictionary:
	var payload := _campaign_completion_payload(level_number, 0)
	if payload.is_empty():
		return {}
	payload.erase("stars")
	payload["outcome"] = outcome if outcome == "failed" else "left"
	return payload


func _load_content_provenance() -> void:
	_content_operation_diagnostic.clear()
	_content_provenance = ContentProvenanceManifestScript.new()
	var result: Dictionary = _content_provenance.load_manifest()
	if not bool(result.get("ok", false)):
		push_warning(
			"Backend synchronization disabled [%s]: %s" % [
				result.get("code", "content_manifest.invalid"),
				result.get("error", "Bundled content provenance is invalid."),
			]
		)


func _load_life_purchase_configuration() -> void:
	_life_purchase_coin_price = DEFAULT_LIFE_PURCHASE_COIN_PRICE
	if not FileAccess.file_exists(LIFE_PURCHASE_CONFIG):
		return
	var file := FileAccess.open(LIFE_PURCHASE_CONFIG, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var configured_price := int((parsed as Dictionary).get(
		"coin_price",
		DEFAULT_LIFE_PURCHASE_COIN_PRICE
	))
	if configured_price > 0:
		_life_purchase_coin_price = configured_price


func _campaign_provenance(level_number: int) -> Dictionary:
	if _content_provenance == null or not _content_provenance.is_valid():
		return {}
	var provenance: Dictionary = _content_provenance.get_level_provenance(level_number)
	if provenance.is_empty() and _content_operation_diagnostic.is_empty():
		_content_operation_diagnostic = {
			"code": "content_manifest.level_unsupported",
			"message": "Campaign progress remains local because this level is not integration-ready.",
		}
	return provenance


func _current_content_diagnostic() -> Dictionary:
	if _content_provenance != null and not _content_provenance.is_valid():
		return _content_provenance.get_diagnostic()
	return _content_operation_diagnostic.duplicate(true)


func _life_state_operation() -> Dictionary:
	var next_restore_unix := int(_data.get("next_life_restore_unix", 0))
	return {
		"operation_type": "life_state",
		"payload": {
			"available_lives": clampi(int(_data.get("lives", MAX_LIVES)), 0, MAX_LIVES),
			"maximum_lives": MAX_LIVES,
			"restore_interval_seconds": LIFE_RESTORE_SECONDS,
			"next_restore_at": (
				LocalSaveCodecScript.iso_timestamp(next_restore_unix)
				if next_restore_unix > 0
				else null
			),
			"observed_at": LocalSaveCodecScript.iso_timestamp(),
		},
	}


func _life_purchase_operation() -> Dictionary:
	var next_restore_unix := int(_data.get("next_life_restore_unix", 0))
	var provenance := _campaign_provenance(MIN_LEVEL)
	return {
		"operation_type": "life_purchase",
		"payload": {
			"configuration_version": provenance.get("configuration_version", "local"),
			"coin_price": _life_purchase_coin_price,
			"lives_granted": 1,
			"available_lives": clampi(int(_data.get("lives", MAX_LIVES)), 0, MAX_LIVES),
			"maximum_lives": MAX_LIVES,
			"restore_interval_seconds": LIFE_RESTORE_SECONDS,
			"next_restore_at": (
				LocalSaveCodecScript.iso_timestamp(next_restore_unix)
				if next_restore_unix > 0
				else null
			),
			"observed_at": LocalSaveCodecScript.iso_timestamp(),
		},
	}


func _map_checkpoint_to_snapshot(
	checkpoint: Dictionary,
	current_snapshot: Dictionary,
	remaining_operations: Array
) -> Dictionary:
	var mapped := current_snapshot.duplicate(true)
	var campaign := checkpoint.get("campaign", {}) as Dictionary
	var balances := checkpoint.get("balances", {}) as Dictionary
	var abilities := checkpoint.get("abilities", {}) as Dictionary
	var lives := checkpoint.get("lives", {}) as Dictionary
	var chest := checkpoint.get("reward_chest", {}) as Dictionary
	var leaderboards := checkpoint.get("leaderboards", {}) as Dictionary
	var profile := checkpoint.get("profile", {}) as Dictionary
	mapped["version"] = SAVE_VERSION
	mapped["current_level"] = int(campaign.get("current_level", MIN_LEVEL))
	mapped["highest_completed_level"] = int(campaign.get("highest_completed_level", 0))
	var checkpoint_completions := {}
	for level_number in range(1, int(mapped["highest_completed_level"]) + 1):
		checkpoint_completions[str(level_number)] = 0
	for raw_completion in campaign.get("selected_completions", []) as Array:
		var completion := raw_completion as Dictionary
		if completion == null:
			continue
		var completed_level := int(completion.get("campaign_level", 0))
		if completed_level >= MIN_LEVEL:
			checkpoint_completions[str(completed_level)] = maxi(int(completion.get("stars", 0)), 0)
	mapped["completion_stars_by_level"] = checkpoint_completions
	mapped["coins"] = int(balances.get("coins", DEFAULT_COINS))
	mapped["ability_uses"] = {
		ABILITY_HAMMER: int(abilities.get(ABILITY_HAMMER, 0)),
		ABILITY_SHUFFLE: int(abilities.get(ABILITY_SHUFFLE, 0)),
		ABILITY_HIGHLIGHT: int(abilities.get(ABILITY_HIGHLIGHT, 0)),
		ABILITY_FREEZER: int(
			abilities.get(
				ABILITY_FREEZER,
				(current_snapshot.get("ability_uses", {}) as Dictionary).get(
					ABILITY_FREEZER,
					DEFAULT_ABILITY_USES[ABILITY_FREEZER]
				)
			)
		),
	}
	mapped["lives"] = int(lives.get("available_lives", MAX_LIVES))
	mapped["next_life_restore_unix"] = LocalSaveCodecScript.unix_from_timestamp(
		lives.get("next_restore_at")
	)
	mapped["reward_chest_stars"] = int(chest.get("stars", 0))
	mapped["reward_chest_goal_index"] = int(chest.get("goal_index", 0))
	mapped["reward_chest_completed_cycles"] = int(chest.get("completed_cycles", 0))
	mapped["total_earned_stars"] = int(leaderboards.get("lifetime_stars", 0))
	mapped["weekly_earned_stars"] = int(leaderboards.get("weekly_stars", 0))
	mapped["leaderboard_week_start_unix"] = LocalSaveCodecScript.unix_from_timestamp(
		leaderboards.get("weekly_period_start")
	)
	mapped["avatar_id"] = str(profile.get("avatar_id", DEFAULT_AVATAR_ID))
	mapped["avatar_frame_id"] = _sanitize_avatar_frame_id(str(profile.get(
		"avatar_frame_id",
		current_snapshot.get(
			"avatar_frame_id",
			ProfileFrameCatalogScript.get_default_frame_id()
		)
	)))
	mapped["player_name"] = str(profile.get("display_name", mapped.get("player_name", "")))
	mapped["moderation_state"] = str(profile.get("moderation_state", "active"))
	for operation in remaining_operations:
		mapped = _apply_unacknowledged_operation(mapped, operation as Dictionary)
	return _sanitize_data(mapped)


func _apply_unacknowledged_operation(snapshot: Dictionary, operation: Dictionary) -> Dictionary:
	var result := snapshot.duplicate(true)
	var payload := operation.get("payload", {}) as Dictionary
	match str(operation.get("operation_type", "")):
		"campaign_completion":
			var level_number := int(payload.get("campaign_level", 0))
			var stars := maxi(int(payload.get("stars", 0)), 0)
			var completions := result.get("completion_stars_by_level", {}) as Dictionary
			if level_number >= MIN_LEVEL and not completions.has(str(level_number)):
				completions[str(level_number)] = stars
				result["completion_stars_by_level"] = completions
				_apply_legacy_cursor(result)
				var normalized := _normalize_reward_chest_progress(
					int(result.get("reward_chest_stars", 0)) + stars,
					int(result.get("reward_chest_goal_index", 0))
				)
				result["reward_chest_stars"] = normalized["stars"]
				result["reward_chest_goal_index"] = normalized["goal_index"]
				result["reward_chest_completed_cycles"] = int(
					result.get("reward_chest_completed_cycles", 0)
				) + int(normalized.get("completed_cycles", 0))
				result["coins"] = int(result.get("coins", 0)) + int(normalized.get("coin_reward", 0))
				result["total_earned_stars"] = int(result.get("total_earned_stars", 0)) + stars
				result["weekly_earned_stars"] = int(result.get("weekly_earned_stars", 0)) + stars
		"resource_spend":
			var asset := str(payload.get("asset", ""))
			var amount := maxi(int(payload.get("amount", 0)), 0)
			if asset == "coins":
				result["coins"] = maxi(int(result.get("coins", 0)) - amount, 0)
			else:
				var uses := result.get("ability_uses", {}) as Dictionary
				uses[asset] = maxi(int(uses.get(asset, 0)) - amount, 0)
				result["ability_uses"] = uses
		"life_purchase":
			result["coins"] = maxi(
				int(result.get("coins", 0)) - maxi(int(payload.get("coin_price", 0)), 0),
				0
			)
			result["lives"] = int(payload.get("available_lives", MAX_LIVES))
			result["next_life_restore_unix"] = LocalSaveCodecScript.unix_from_timestamp(
				payload.get("next_restore_at")
			)
		"life_state":
			result["lives"] = int(payload.get("available_lives", MAX_LIVES))
			result["next_life_restore_unix"] = LocalSaveCodecScript.unix_from_timestamp(
				payload.get("next_restore_at")
			)
		"profile_edit":
			if payload.has("display_name"):
				result["player_name"] = str(payload.get("display_name"))
			if payload.has("avatar_id"):
				result["avatar_id"] = str(payload.get("avatar_id"))
			if payload.has("avatar_frame_id"):
				result["avatar_frame_id"] = _sanitize_avatar_frame_id(str(
					payload.get("avatar_frame_id")
				))
	return result


func _record_level_completion(level_number: int, earned_stars: int) -> void:
	var completions := _data.get("completion_stars_by_level", {}) as Dictionary
	completions[str(level_number)] = maxi(earned_stars, 0)
	_data["completion_stars_by_level"] = completions
	_apply_legacy_cursor(_data)


func _apply_legacy_cursor(target: Dictionary) -> void:
	var completions := target.get("completion_stars_by_level", {}) as Dictionary
	var highest_contiguous := 0
	while completions.has(str(highest_contiguous + 1)):
		highest_contiguous += 1
	target["highest_completed_level"] = highest_contiguous
	target["current_level"] = highest_contiguous + 1


func _sanitize_completion_stars(raw_value: Variant, legacy_highest_completed: int) -> Dictionary:
	var sanitized := {}
	if raw_value is Dictionary:
		for raw_key in (raw_value as Dictionary).keys():
			var level_number := int(str(raw_key))
			if level_number >= MIN_LEVEL:
				sanitized[str(level_number)] = maxi(int((raw_value as Dictionary).get(raw_key, 0)), 0)
	for level_number in range(1, legacy_highest_completed + 1):
		if not sanitized.has(str(level_number)):
			sanitized[str(level_number)] = 0
	return sanitized


func _sanitize_selected_chapter_id(chapter_id: String, completions: Dictionary) -> String:
	if _can_select_chapter_with_completions(chapter_id, completions):
		return chapter_id
	return _latest_selectable_chapter_id_with_completions(completions)


func _can_select_chapter(chapter_id: String) -> bool:
	return _can_select_chapter_with_completions(
		chapter_id,
		_data.get("completion_stars_by_level", {}) as Dictionary
	)


func _can_select_chapter_with_completions(chapter_id: String, completions: Dictionary) -> bool:
	return (
		_is_chapter_unlocked_with_completions(chapter_id, completions)
		and not ChapterCatalog.get_level_ids(chapter_id).is_empty()
	)


func _latest_selectable_chapter_id() -> String:
	return _latest_selectable_chapter_id_with_completions(
		_data.get("completion_stars_by_level", {}) as Dictionary
	)


func _latest_selectable_chapter_id_with_completions(completions: Dictionary) -> String:
	var latest := _default_chapter_id()
	for chapter in ChapterCatalog.get_chapters():
		var chapter_id := str(chapter.get("id", ""))
		if _can_select_chapter_with_completions(chapter_id, completions):
			latest = chapter_id
	return latest


func _default_chapter_id() -> String:
	return ChapterCatalog.get_first_chapter_id() if ChapterCatalog != null else "chapter_01"


func _on_reconciliation_applied() -> void:
	if _local_store != null:
		_apply_loaded_partitions(_local_store.get_snapshot(), _local_store.get_preferences())


func _on_guest_registered(result: Dictionary) -> void:
	_activate_coordinator_result(result)
