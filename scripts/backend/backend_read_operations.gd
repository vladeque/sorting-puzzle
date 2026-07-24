extends RefCounted
class_name BackendReadOperations

## GAME-007 closed protocol adapters for the backend's bodyless authenticated v1 GET reads
## (PROTOCOL_BOUNDARY.md Decision 4's "bodyless GET exception" list: player/state, player/devices,
## catalog, purchases/{transaction_id}, leaderboards/{scope}). Each `parse_*` function validates
## every field its own return value exposes, maps unrecognized response enum values to `"unknown"`
## per Decision 3's additive-enum compatibility rule, and reads only the specific keys it needs so
## additive response fields are ignored by construction. Path builders never invent a request body
## or protocol/app headers for these reads; `BackendTransport.get_json()` owns the HTTP mechanics.

const LocalSaveCodecScript := preload("res://scripts/save/local_save_codec.gd")

const ACCOUNT_KINDS := ["guest", "platform_verified"]
const MODERATION_STATES := ["active", "name_replaced", "quarantined", "banned"]
const AVATAR_IDS := [
	"avatar_bear", "avatar_cat", "avatar_cow", "avatar_deer", "avatar_dog", "avatar_dolphin",
	"avatar_elephant", "avatar_frog", "avatar_hamster", "avatar_koala", "avatar_lion",
	"avatar_monkey", "avatar_owl", "avatar_penguin", "avatar_sheep", "avatar_sloth",
	"avatar_tiger", "avatar_turtle",
]
const DEVICE_PLATFORMS := ["android", "ios"]
const OFFER_TYPES := ["starter", "timed_bundle", "evergreen_bundle", "coin_pack"]
const LIMIT_PERIODS := ["lifetime", "campaign", "day", "week", "offer_window", "none"]
const PURCHASE_STATUSES := [
	"pending", "verified", "granted", "acknowledged", "canceled", "refunded", "revoked",
]
const RESTRICTION_STATUSES := ["none", "debt_outstanding"]
const GRANT_SOURCES := ["run", "reward_chest", "purchase", "bootstrap", "compensation"]
const LEADERBOARD_SCOPES := ["weekly", "country", "world"]
const UNKNOWN := "unknown"


static func player_state_path() -> String:
	return "/v1/player/state"


static func player_devices_path() -> String:
	return "/v1/player/devices"


static func catalog_path() -> String:
	return "/v1/catalog"


static func purchase_path(transaction_id: String) -> String:
	return "/v1/purchases/%s" % transaction_id.uri_encode()


static func leaderboard_path(scope: String, limit: int = 50, cursor: String = "") -> String:
	var path := "/v1/leaderboards/%s?limit=%d" % [scope.uri_encode(), limit]
	if not cursor.is_empty():
		path += "&cursor=%s" % cursor.uri_encode()
	return path


static func parse_player_state(data: Variant) -> Dictionary:
	if not (data is Dictionary):
		return _error("Player state response data is not an object.")
	var document := data as Dictionary
	if not LocalSaveCodecScript.is_uuid(document.get("player_id")):
		return _error("Player state response has an invalid player_id.")
	var campaign_result := _parse_campaign(document.get("campaign"))
	if not bool(campaign_result.get("ok", false)):
		return campaign_result
	var lives_result := _parse_lives(document.get("lives"))
	if not bool(lives_result.get("ok", false)):
		return lives_result
	var balances_result := _parse_balances(document.get("balances"))
	if not bool(balances_result.get("ok", false)):
		return balances_result
	var abilities_result := _parse_abilities(document.get("abilities"))
	if not bool(abilities_result.get("ok", false)):
		return abilities_result
	var restriction_result := _parse_purchase_restriction(document.get("purchase_restriction"))
	if not bool(restriction_result.get("ok", false)):
		return restriction_result
	var reward_chest_result := _parse_reward_chest(document.get("reward_chest"))
	if not bool(reward_chest_result.get("ok", false)):
		return reward_chest_result
	var leaderboards_result := _parse_leaderboard_summary(document.get("leaderboards"))
	if not bool(leaderboards_result.get("ok", false)):
		return leaderboards_result
	var profile_result := _parse_player_profile(document.get("profile"))
	if not bool(profile_result.get("ok", false)):
		return profile_result

	return _success({
		"player_id": str(document.get("player_id", "")),
		"account_kind": _normalize_enum(document.get("account_kind"), ACCOUNT_KINDS),
		"campaign": campaign_result.get("campaign"),
		"lives": lives_result.get("lives"),
		"balances": balances_result.get("balances"),
		"abilities": abilities_result.get("abilities"),
		"purchase_restriction": restriction_result.get("restriction"),
		"reward_chest": reward_chest_result.get("reward_chest"),
		"leaderboards": leaderboards_result.get("leaderboards"),
		"profile": profile_result.get("profile"),
	})


static func parse_player_devices(data: Variant) -> Dictionary:
	if not (data is Dictionary):
		return _error("Player devices response data is not an object.")
	var raw_devices = (data as Dictionary).get("devices")
	if not (raw_devices is Array):
		return _error("Player devices response is missing a devices array.")
	var devices := []
	for raw_device in raw_devices as Array:
		if not (raw_device is Dictionary):
			return _error("Player devices response has a malformed device entry.")
		var device := raw_device as Dictionary
		if (
			not LocalSaveCodecScript.is_uuid(device.get("device_id"))
			or not LocalSaveCodecScript.is_timestamp(device.get("created_at"))
			or not LocalSaveCodecScript.is_timestamp(device.get("last_seen_at"))
			or not (device.get("current") is bool)
		):
			return _error("Player devices response has a malformed device entry.")
		devices.append({
			"device_id": str(device.get("device_id", "")),
			"platform": _normalize_enum(device.get("platform"), DEVICE_PLATFORMS),
			"created_at": str(device.get("created_at", "")),
			"last_seen_at": str(device.get("last_seen_at", "")),
			"current": bool(device.get("current", false)),
		})
	return _success({"devices": devices})


static func parse_catalog(data: Variant) -> Dictionary:
	if not (data is Dictionary):
		return _error("Catalog response data is not an object.")
	var document := data as Dictionary
	if not LocalSaveCodecScript.is_opaque_id(document.get("catalog_version")):
		return _error("Catalog response has an invalid catalog_version.")
	var raw_offers = document.get("offers")
	if not (raw_offers is Array):
		return _error("Catalog response is missing an offers array.")
	var offers := []
	for raw_offer in raw_offers as Array:
		var offer_result := _parse_catalog_offer(raw_offer)
		if not bool(offer_result.get("ok", false)):
			return offer_result
		offers.append(offer_result.get("offer"))
	return _success({
		"catalog_version": str(document.get("catalog_version", "")),
		"offers": offers,
	})


static func parse_purchase(data: Variant) -> Dictionary:
	if not (data is Dictionary):
		return _error("Purchase response data is not an object.")
	var document := data as Dictionary
	if (
		not LocalSaveCodecScript.is_uuid(document.get("transaction_id"))
		or not LocalSaveCodecScript.is_uuid(document.get("intent_id"))
		or not (document.get("new_grant") is bool)
	):
		return _error("Purchase response is missing a required field.")
	var raw_grants = document.get("grants")
	if not (raw_grants is Array):
		return _error("Purchase response is missing a grants array.")
	var grants := []
	for raw_grant in raw_grants as Array:
		var grant_result := _parse_reward_grant(raw_grant)
		if not bool(grant_result.get("ok", false)):
			return grant_result
		grants.append(grant_result.get("grant"))
	var result := {
		"transaction_id": str(document.get("transaction_id", "")),
		"intent_id": str(document.get("intent_id", "")),
		"status": _normalize_enum(document.get("status"), PURCHASE_STATUSES),
		"new_grant": bool(document.get("new_grant", false)),
		"grants": grants,
	}
	if document.get("restriction") is Dictionary:
		var restriction_result := _parse_purchase_restriction(document.get("restriction"))
		if not bool(restriction_result.get("ok", false)):
			return restriction_result
		result["restriction"] = restriction_result.get("restriction")
	if document.get("state") is Dictionary:
		var state_result := parse_player_state(document.get("state"))
		if not bool(state_result.get("ok", false)):
			return state_result
		var state_fields := state_result.duplicate(true)
		state_fields.erase("ok")
		state_fields.erase("error")
		result["state"] = state_fields
	return _success(result)


static func parse_leaderboard(data: Variant) -> Dictionary:
	if not (data is Dictionary):
		return _error("Leaderboard response data is not an object.")
	var document := data as Dictionary
	var raw_entries = document.get("entries")
	var limit = document.get("limit")
	if not (raw_entries is Array) or not _is_integer(limit):
		return _error("Leaderboard response is missing a required field.")
	var entries := []
	for raw_entry in raw_entries as Array:
		var entry_result := _parse_leaderboard_entry(raw_entry)
		if not bool(entry_result.get("ok", false)):
			return entry_result
		entries.append(entry_result.get("entry"))
	var result := {
		"scope": _normalize_enum(document.get("scope"), LEADERBOARD_SCOPES),
		"entries": entries,
		"limit": int(limit),
		"period_id": str(document.get("period_id", "")),
		"period_end": str(document.get("period_end", "")),
		"next_cursor": str(document.get("next_cursor", "")),
	}
	if document.get("current_player") is Dictionary:
		var current_player_result := _parse_leaderboard_entry(document.get("current_player"))
		if not bool(current_player_result.get("ok", false)):
			return current_player_result
		result["current_player"] = current_player_result.get("entry")
	return _success(result)


static func _parse_campaign(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Player state response is missing campaign.")
	var campaign := value as Dictionary
	var current_level = campaign.get("current_level")
	var highest_completed_level = campaign.get("highest_completed_level")
	if not _is_integer(current_level) or not _is_integer(highest_completed_level):
		return _error("Player state campaign has a malformed field.")
	return _success({"campaign": {
		"current_level": int(current_level),
		"highest_completed_level": int(highest_completed_level),
	}})


static func _parse_lives(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Player state response is missing lives.")
	var lives := value as Dictionary
	var current = lives.get("current")
	var maximum = lives.get("maximum")
	var restore_interval_seconds = lives.get("restore_interval_seconds")
	if not _is_integer(current) or not _is_integer(maximum) or not _is_integer(restore_interval_seconds):
		return _error("Player state lives has a malformed field.")
	var result := {
		"current": int(current),
		"maximum": int(maximum),
		"restore_interval_seconds": int(restore_interval_seconds),
	}
	if lives.get("next_restore_at") != null:
		if not LocalSaveCodecScript.is_timestamp(lives.get("next_restore_at")):
			return _error("Player state lives has a malformed next_restore_at.")
		result["next_restore_at"] = str(lives.get("next_restore_at", ""))
	return _success({"lives": result})


static func _parse_balances(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Player state response is missing balances.")
	var coins = (value as Dictionary).get("coins")
	if not _is_integer(coins):
		return _error("Player state balances has a malformed coins field.")
	return _success({"balances": {"coins": int(coins)}})


static func _parse_abilities(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Player state response is missing abilities.")
	var abilities := value as Dictionary
	var hammer = abilities.get("hammer")
	var shuffle = abilities.get("shuffle")
	var highlight = abilities.get("highlight")
	if not _is_integer(hammer) or not _is_integer(shuffle) or not _is_integer(highlight):
		return _error("Player state abilities has a malformed field.")
	return _success({"abilities": {
		"hammer": int(hammer),
		"shuffle": int(shuffle),
		"highlight": int(highlight),
	}})


static func _parse_purchase_restriction(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Response is missing purchase_restriction.")
	var restriction := value as Dictionary
	var purchase_debt_coins = restriction.get("purchase_debt_coins")
	var recovery = restriction.get("recovery")
	if (
		not _is_integer(purchase_debt_coins)
		or not (restriction.get("purchase_intents_allowed") is bool)
		or not (recovery is Dictionary)
	):
		return _error("purchase_restriction has a malformed field.")
	return _success({"restriction": {
		"status": _normalize_enum(restriction.get("status"), RESTRICTION_STATUSES),
		"purchase_debt_coins": int(purchase_debt_coins),
		"purchase_intents_allowed": bool(restriction.get("purchase_intents_allowed", false)),
		"recovery_action": str((recovery as Dictionary).get("action", "")),
	}})


static func _parse_reward_chest(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Player state response is missing reward_chest.")
	var reward_chest := value as Dictionary
	var stars = reward_chest.get("stars")
	var goal_index = reward_chest.get("goal_index")
	var goal_stars = reward_chest.get("goal_stars")
	var coin_reward = reward_chest.get("coin_reward")
	if (
		not LocalSaveCodecScript.is_opaque_id(reward_chest.get("configuration_version"))
		or not _is_integer(stars)
		or not _is_integer(goal_index)
		or not _is_integer(goal_stars)
		or not _is_integer(coin_reward)
	):
		return _error("reward_chest has a malformed field.")
	return _success({"reward_chest": {
		"configuration_version": str(reward_chest.get("configuration_version", "")),
		"stars": int(stars),
		"goal_index": int(goal_index),
		"goal_stars": int(goal_stars),
		"coin_reward": int(coin_reward),
	}})


static func _parse_leaderboard_summary(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Player state response is missing leaderboards.")
	var summary := value as Dictionary
	var lifetime_stars = summary.get("lifetime_stars")
	var weekly_stars = summary.get("weekly_stars")
	if (
		not _is_integer(lifetime_stars)
		or not _is_integer(weekly_stars)
		or not LocalSaveCodecScript.is_opaque_id(summary.get("weekly_period_id"))
		or not LocalSaveCodecScript.is_timestamp(summary.get("weekly_period_start"))
		or not LocalSaveCodecScript.is_timestamp(summary.get("weekly_period_end"))
	):
		return _error("leaderboards summary has a malformed field.")
	return _success({"leaderboards": {
		"lifetime_stars": int(lifetime_stars),
		"weekly_stars": int(weekly_stars),
		"weekly_period_id": str(summary.get("weekly_period_id", "")),
		"weekly_period_start": str(summary.get("weekly_period_start", "")),
		"weekly_period_end": str(summary.get("weekly_period_end", "")),
	}})


static func _parse_player_profile(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Response is missing profile.")
	var profile := value as Dictionary
	var display_name := str(profile.get("display_name", ""))
	if (
		display_name.is_empty()
		or not LocalSaveCodecScript.is_timestamp(profile.get("created_at"))
		or not LocalSaveCodecScript.is_timestamp(profile.get("updated_at"))
	):
		return _error("profile has a malformed field.")
	var result := {
		"display_name": display_name,
		"avatar_id": _normalize_enum(profile.get("avatar_id"), AVATAR_IDS),
		"created_at": str(profile.get("created_at", "")),
		"updated_at": str(profile.get("updated_at", "")),
		"moderation_state": _normalize_enum(profile.get("moderation_state"), MODERATION_STATES),
	}
	if profile.get("country_code") != null:
		result["country_code"] = str(profile.get("country_code", ""))
	return _success({"profile": result})


static func _parse_catalog_offer(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Catalog response has a malformed offer entry.")
	var offer := value as Dictionary
	var rewards = offer.get("rewards")
	var display_priority = offer.get("display_priority")
	var platform_product_id := str(offer.get("platform_product_id", ""))
	if (
		not LocalSaveCodecScript.is_opaque_id(offer.get("offer_id"))
		or not LocalSaveCodecScript.is_opaque_id(offer.get("title_key"))
		or platform_product_id.is_empty()
		or not (rewards is Dictionary)
		or not _is_integer(display_priority)
		or not (offer.get("eligible") is bool)
	):
		return _error("Catalog response has a malformed offer entry.")
	var reward_data := rewards as Dictionary
	var coins = reward_data.get("coins")
	var abilities = reward_data.get("abilities")
	if not _is_integer(coins) or not (abilities is Dictionary):
		return _error("Catalog offer rewards are malformed.")
	var ability_data := abilities as Dictionary
	var hammer = ability_data.get("hammer")
	var shuffle = ability_data.get("shuffle")
	var highlight = ability_data.get("highlight")
	if not _is_integer(hammer) or not _is_integer(shuffle) or not _is_integer(highlight):
		return _error("Catalog offer ability rewards are malformed.")
	var result := {
		"offer_id": str(offer.get("offer_id", "")),
		"type": _normalize_enum(offer.get("type"), OFFER_TYPES),
		"title_key": str(offer.get("title_key", "")),
		"rewards": {
			"coins": int(coins),
			"abilities": {
				"hammer": int(hammer),
				"shuffle": int(shuffle),
				"highlight": int(highlight),
			},
		},
		"platform_product_id": platform_product_id,
		"limit_period": _normalize_enum(offer.get("limit_period"), LIMIT_PERIODS),
		"display_priority": int(display_priority),
		"eligible": bool(offer.get("eligible", false)),
	}
	if _is_integer(offer.get("purchase_limit")):
		result["purchase_limit"] = int(offer.get("purchase_limit"))
	if offer.get("starts_at") != null:
		result["starts_at"] = str(offer.get("starts_at", ""))
	if offer.get("ends_at") != null:
		result["ends_at"] = str(offer.get("ends_at", ""))
	return _success({"offer": result})


static func _parse_reward_grant(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Response has a malformed grant entry.")
	var grant := value as Dictionary
	var assets = grant.get("assets")
	if not LocalSaveCodecScript.is_uuid(grant.get("grant_id")) or not (assets is Dictionary):
		return _error("Response has a malformed grant entry.")
	var asset_data := assets as Dictionary
	var coins = asset_data.get("coins")
	var hammer = asset_data.get("hammer")
	var shuffle = asset_data.get("shuffle")
	var highlight = asset_data.get("highlight")
	if not _is_integer(coins) or not _is_integer(hammer) or not _is_integer(shuffle) or not _is_integer(highlight):
		return _error("Response has malformed grant assets.")
	return _success({"grant": {
		"grant_id": str(grant.get("grant_id", "")),
		"source": _normalize_enum(grant.get("source"), GRANT_SOURCES),
		"assets": {
			"coins": int(coins),
			"hammer": int(hammer),
			"shuffle": int(shuffle),
			"highlight": int(highlight),
		},
	}})


static func _parse_leaderboard_entry(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _error("Leaderboard response has a malformed entry.")
	var entry := value as Dictionary
	var rank = entry.get("rank")
	var score = entry.get("score")
	var display_name := str(entry.get("display_name", ""))
	if (
		not LocalSaveCodecScript.is_uuid(entry.get("player_id"))
		or not _is_integer(rank)
		or not _is_integer(score)
		or display_name.is_empty()
		or not (entry.get("is_current_player") is bool)
	):
		return _error("Leaderboard response has a malformed entry.")
	var result := {
		"player_id": str(entry.get("player_id", "")),
		"rank": int(rank),
		"score": int(score),
		"display_name": display_name,
		"avatar_id": _normalize_enum(entry.get("avatar_id"), AVATAR_IDS),
		"is_current_player": bool(entry.get("is_current_player", false)),
	}
	if entry.get("country_code") != null:
		result["country_code"] = str(entry.get("country_code", ""))
	return _success({"entry": result})


static func _normalize_enum(value: Variant, known_values: Array) -> String:
	var text := str(value)
	return text if known_values.has(text) else UNKNOWN


static func _is_integer(value: Variant) -> bool:
	return (
		value is int
		or (value is float and is_finite(float(value)) and float(value) == floor(float(value)))
	)


static func _success(data: Dictionary) -> Dictionary:
	var response := {"ok": true, "error": ""}
	response.merge(data, true)
	return response


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
