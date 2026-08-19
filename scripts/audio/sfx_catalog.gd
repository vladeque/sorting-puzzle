extends RefCounted

## The single AUDIO-001 event catalog: every sound effect the game can play, with its streams,
## mix trim, pitch variation, cooldown, and polyphony budget in one place.
##
## Gameplay and UI scripts never preload an AudioStream. They call
## `SfxManager.play(SfxCatalog.EVENT_*)` and the manager resolves everything from here, so
## rebalancing the mix or swapping a variant pool is a change to this file alone.
##
## `item_place_valid` and `match_clear` intentionally keep the project's existing source
## recordings; every other event uses the deterministic generated palette written by
## scripts/tools/generate_core_sfx.gd (see docs/AUDIO_001_GODOT_ONLY_SFX_TICKET.md).
##
## Per-event fields:
##   streams              res:// paths. More than one makes the event a variant pool.
##   volume_db            Mix trim on top of the asset's authored peak. UI clicks and timer ticks
##                        stay under gameplay matches and currency confirmations.
##   volume_variation_db  Symmetric random trim per play, for repeated gameplay cues.
##   pitch_range          Subtle random pitch window. Kept narrow so event identity and the
##                        currency cues' musical relationships stay stable.
##   cooldown_seconds     Minimum spacing between accepted plays of this event.
##   max_polyphony        Concurrent instances. The oldest instance yields to the newest so the
##                        most recent action is always the audible one.
##   count_scaling        Optional. Folds a multi-item reward into one coherent cue instead of one
##                        full-volume sound per item (see SfxManager._apply_count_scaling).

const GENERATED_DIRECTORY := "res://assets/audio/generated"

const EVENT_ITEM_SELECT := &"item_select"
const EVENT_ITEM_PLACE_VALID := &"item_place_valid"
const EVENT_MATCH_CLEAR := &"match_clear"
const EVENT_STAR_HUD_ARRIVAL := &"star_hud_arrival"
const EVENT_TIMER_CRITICAL_TICK := &"timer_critical_tick"
const EVENT_TIME_UP := &"time_up"
const EVENT_COIN_GAIN := &"coin_gain"
const EVENT_COIN_SPEND := &"coin_spend"
const EVENT_SHOP_PURCHASE_SUCCESS := &"shop_purchase_success"
const EVENT_REWARD_CHEST_STAR_ARRIVAL := &"reward_chest_star_arrival"
const EVENT_UI_CLICK := &"ui_click"

## The eleven approved AUDIO-001 events. Adding a twelfth means adding it here first -- the manager
## warns and stays silent for anything it cannot resolve.
const EVENTS := {
	EVENT_ITEM_SELECT: {
		"streams": [
			"res://assets/audio/generated/item_select_01.wav",
			"res://assets/audio/generated/item_select_02.wav",
			"res://assets/audio/generated/item_select_03.wav",
		],
		"volume_db": -1.0,
		"volume_variation_db": 0.5,
		"pitch_range": Vector2(0.97, 1.03),
		"cooldown_seconds": 0.035,
		"max_polyphony": 3,
	},
	EVENT_ITEM_PLACE_VALID: {
		"streams": ["res://assets/audio/item_place.wav"],
		"volume_db": -5.0,
		"volume_variation_db": 1.0,
		"pitch_range": Vector2(0.95, 1.05),
		"cooldown_seconds": 0.02,
		"max_polyphony": 4,
	},
	EVENT_MATCH_CLEAR: {
		"streams": ["res://assets/audio/triple_clear.wav"],
		"volume_db": -5.0,
		"volume_variation_db": 0.5,
		"pitch_range": Vector2(0.97, 1.03),
		"cooldown_seconds": 0.02,
		"max_polyphony": 3,
	},
	EVENT_STAR_HUD_ARRIVAL: {
		"streams": ["res://assets/audio/generated/star_hud_arrival.wav"],
		"volume_db": -2.0,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(0.99, 1.01),
		"cooldown_seconds": 0.09,
		"max_polyphony": 2,
		# A five-star combo reads as one bigger arrival, not five stacked chimes.
		"count_scaling": {
			"volume_db_per_extra": 0.9,
			"max_volume_db": 3.0,
			"pitch_per_extra": 0.012,
			"max_pitch": 1.05,
		},
	},
	EVENT_TIMER_CRITICAL_TICK: {
		"streams": [
			"res://assets/audio/generated/timer_tick_01.wav",
			"res://assets/audio/generated/timer_tick_02.wav",
			"res://assets/audio/generated/timer_tick_03.wav",
		],
		"volume_db": -3.0,
		"volume_variation_db": 0.4,
		"pitch_range": Vector2(0.98, 1.02),
		"cooldown_seconds": 0.30,
		"max_polyphony": 2,
	},
	EVENT_TIME_UP: {
		"streams": ["res://assets/audio/generated/time_up.wav"],
		"volume_db": -1.0,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.75,
		"max_polyphony": 1,
	},
	EVENT_COIN_GAIN: {
		"streams": ["res://assets/audio/generated/coin_gain.wav"],
		"volume_db": -1.0,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(0.995, 1.005),
		"cooldown_seconds": 0.20,
		"max_polyphony": 2,
	},
	EVENT_COIN_SPEND: {
		"streams": ["res://assets/audio/generated/coin_spend.wav"],
		"volume_db": -2.0,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(0.995, 1.005),
		"cooldown_seconds": 0.15,
		"max_polyphony": 2,
	},
	EVENT_SHOP_PURCHASE_SUCCESS: {
		"streams": ["res://assets/audio/generated/shop_purchase_success.wav"],
		"volume_db": -1.0,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.60,
		"max_polyphony": 1,
	},
	EVENT_REWARD_CHEST_STAR_ARRIVAL: {
		"streams": [
			"res://assets/audio/generated/reward_chest_star_arrival_01.wav",
			"res://assets/audio/generated/reward_chest_star_arrival_02.wav",
			"res://assets/audio/generated/reward_chest_star_arrival_03.wav",
		],
		"volume_db": -3.0,
		"volume_variation_db": 0.6,
		"pitch_range": Vector2(0.98, 1.04),
		# Matches the flyer's authored stagger floor so a long flight keeps its rhythm instead of
		# collapsing into one loud stack.
		"cooldown_seconds": 0.05,
		"max_polyphony": 3,
	},
	EVENT_UI_CLICK: {
		"streams": [
			"res://assets/audio/generated/ui_click_01.wav",
			"res://assets/audio/generated/ui_click_02.wav",
			"res://assets/audio/generated/ui_click_03.wav",
		],
		"volume_db": -2.0,
		"volume_variation_db": 0.4,
		"pitch_range": Vector2(0.97, 1.03),
		"cooldown_seconds": 0.04,
		"max_polyphony": 3,
	},
}


static func get_event_ids() -> Array:
	return EVENTS.keys()


static func has_event(event_id: StringName) -> bool:
	return EVENTS.has(event_id)


static func get_event(event_id: StringName) -> Dictionary:
	return (EVENTS.get(event_id, {}) as Dictionary).duplicate(true)


## Every distinct stream path referenced by the catalog, for asset verification.
static func get_all_stream_paths() -> Array[String]:
	var paths: Array[String] = []
	for event_id in EVENTS:
		for stream_path in (EVENTS[event_id] as Dictionary).get("streams", []):
			var path := str(stream_path)
			if not paths.has(path):
				paths.append(path)

	return paths
