extends RefCounted

## The single AUDIO-001 event catalog: every sound effect the game can play, with its streams,
## mix trim, pitch variation, cooldown, and polyphony budget in one place.
##
## Gameplay and UI scripts never preload an AudioStream. They call
## `SfxManager.play(SfxCatalog.EVENT_*)` and the manager resolves everything from here, so
## rebalancing the mix or swapping a variant pool is a change to this file alone.
##
## `item_place_valid` and `match_clear` intentionally keep the project's existing source
## recordings. Every stream is grouped under an event-named directory. The original AUDIO-001
## palette is deterministic output from scripts/tools/generate_core_sfx.gd; selected authored
## source cues, including coin_gain, are catalogued here without being claimed by that
## synthesizer's manifest.
##
## Per-event fields:
##   streams              res:// paths. More than one makes the event a variant pool.
##   loudness_class       Required category from docs/AUDIO_LOUDNESS_STANDARD.md.
##   volume_db            Mix trim on top of the asset's authored level.
##   stream_volume_offsets_db Optional per-path correction applied before random variation. Use it
##                        to loudness-match variants; do not encode creative hierarchy here.
##   volume_variation_db  Symmetric random trim per play, for repeated gameplay cues.
##   pitch_range          Subtle random pitch window. Kept narrow so event identity and the
##                        currency cues' musical relationships stay stable.
##   cooldown_seconds     Minimum spacing between accepted plays of this event.
##   max_polyphony        Concurrent instances. The oldest instance yields to the newest so the
##                        most recent action is always the audible one.
##   count_scaling        Optional. Folds a multi-item reward into one coherent cue instead of one
##                        full-volume sound per item (see SfxManager._apply_count_scaling).

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
const EVENT_STICKY_MOVE_BLOCKED := &"sticky_move_blocked"
const EVENT_SHELF_UNLOCK := &"shelf_unlock"
const EVENT_ABILITY_HAMMER := &"ability_hammer"
const EVENT_ABILITY_SHUFFLE := &"ability_shuffle"
const EVENT_ABILITY_LANTERN := &"ability_lantern"
const EVENT_ABILITY_FREEZER := &"ability_freezer"
const EVENT_LEVEL_COMPLETE := &"level_complete"
const EVENT_LEVEL_FAILED := &"level_failed"

## The complete shared event catalog. The manager warns and stays silent for anything it cannot
## resolve, so a gameplay owner must add its semantic event here before requesting playback.
const EVENTS := {
	EVENT_ITEM_SELECT: {
		"loudness_class": &"interaction_micro",
		"streams": [
			"res://assets/audio/item_select/item_select_01.wav",
			"res://assets/audio/item_select/item_select_02.wav",
			"res://assets/audio/item_select/item_select_03.wav",
		],
		"volume_db": 1.0,
		"volume_variation_db": 0.5,
		"pitch_range": Vector2(0.97, 1.03),
		"cooldown_seconds": 0.035,
		"max_polyphony": 3,
	},
	EVENT_ITEM_PLACE_VALID: {
		"loudness_class": &"interaction_micro",
		"streams": ["res://assets/audio/item_place_valid/item_place.wav"],
		"volume_db": 2.5,
		"volume_variation_db": 1.0,
		"pitch_range": Vector2(0.95, 1.05),
		"cooldown_seconds": 0.02,
		"max_polyphony": 4,
	},
	EVENT_MATCH_CLEAR: {
		"loudness_class": &"reward_confirmation",
		"streams": ["res://assets/audio/match_clear/triple_clear.wav"],
		"volume_db": -3.0,
		"volume_variation_db": 0.5,
		"pitch_range": Vector2(0.97, 1.03),
		"cooldown_seconds": 0.02,
		"max_polyphony": 3,
	},
	EVENT_STAR_HUD_ARRIVAL: {
		"loudness_class": &"gameplay_feedback",
		"streams": ["res://assets/audio/star_hud_arrival/star_hud_arrival.wav"],
		"volume_db": 4.0,
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
		"loudness_class": &"gameplay_feedback",
		# One authored 30-second bed, started once on entry into the critical range and resumed at
		# the matching offset after pause or Freezer. It must never be requested once per frame.
		"streams": ["res://assets/audio/timer_critical_tick/timer_tick.wav"],
		"volume_db": 3.0,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.0,
		"max_polyphony": 1,
	},
	EVENT_TIME_UP: {
		"loudness_class": &"terminal_stinger",
		"streams": ["res://assets/audio/time_up/times_up2.mp3"],
		"volume_db": 10.2,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.75,
		"max_polyphony": 1,
	},
	EVENT_COIN_GAIN: {
		"loudness_class": &"reward_confirmation",
		"streams": ["res://assets/audio/coin_gain/coin_gain.wav"],
		"volume_db": -2.0,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(0.995, 1.005),
		"cooldown_seconds": 0.20,
		"max_polyphony": 2,
	},
	EVENT_COIN_SPEND: {
		"loudness_class": &"reward_confirmation",
		"streams": ["res://assets/audio/coin_spend/coin_spend.wav"],
		"volume_db": -2.0,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(0.995, 1.005),
		"cooldown_seconds": 0.15,
		"max_polyphony": 2,
	},
	EVENT_SHOP_PURCHASE_SUCCESS: {
		"loudness_class": &"reward_confirmation",
		"streams": ["res://assets/audio/shop_purchase_success/purchase_successful.wav"],
		"volume_db": 11.0,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.60,
		"max_polyphony": 1,
	},
	EVENT_REWARD_CHEST_STAR_ARRIVAL: {
		"loudness_class": &"gameplay_feedback",
		# A short, smoothly faded derivative of the HUD arrival keeps rapid impacts distinct without
		# stacking its full tonal tail. The source HUD recording remains unchanged.
		"streams": [
			"res://assets/audio/reward_chest_star_arrival/reward_chest_star_arrival_short.wav"
		],
		"volume_db": 4.0,
		"volume_variation_db": 0.6,
		"pitch_range": Vector2(0.995, 1.005),
		# Matches the flyer's authored stagger floor so a long flight keeps its rhythm instead of
		# collapsing into one loud stack.
		"cooldown_seconds": 0.05,
		"max_polyphony": 3,
	},
	EVENT_UI_CLICK: {
		"loudness_class": &"ui_micro",
		"streams": [
			"res://assets/audio/ui_click/ui_click_01.wav",
			"res://assets/audio/ui_click/ui_click_02.wav",
			"res://assets/audio/ui_click/ui_click_03.wav",
		],
		"volume_db": 8.0,
		# The source variants differ by almost 4 LU. These offsets place all three near the same
		# nominal loudness while retaining one shared creative event trim.
		"stream_volume_offsets_db": {
			"res://assets/audio/ui_click/ui_click_01.wav": -1.0,
			"res://assets/audio/ui_click/ui_click_02.wav": 2.2,
			"res://assets/audio/ui_click/ui_click_03.wav": 1.8,
		},
		"volume_variation_db": 0.4,
		"pitch_range": Vector2(0.97, 1.03),
		"cooldown_seconds": 0.04,
		"max_polyphony": 3,
	},
	EVENT_STICKY_MOVE_BLOCKED: {
		"loudness_class": &"gameplay_feedback",
		# Deliberately scoped to sticky resistance: ordinary rejected moves stay silent.
		"streams": ["res://assets/audio/sticky_move_blocked/cartoon_gum_pop.wav"],
		"volume_db": -7.9,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.18,
		"max_polyphony": 1,
	},
	EVENT_SHELF_UNLOCK: {
		"loudness_class": &"reward_confirmation",
		"streams": ["res://assets/audio/shelf_unlock/shelve_unlock.wav"],
		"volume_db": -10.3,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.20,
		"max_polyphony": 1,
	},
	EVENT_ABILITY_HAMMER: {
		"loudness_class": &"ability_warning",
		"streams": ["res://assets/audio/ability_hammer/hammer.wav"],
		"volume_db": -1.93,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.20,
		"max_polyphony": 1,
	},
	EVENT_ABILITY_SHUFFLE: {
		"loudness_class": &"ability_warning",
		"streams": ["res://assets/audio/ability_shuffle/shuffle.wav"],
		"volume_db": 9.5,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.20,
		"max_polyphony": 1,
	},
	EVENT_ABILITY_LANTERN: {
		"loudness_class": &"ability_warning",
		"streams": ["res://assets/audio/ability_lantern/lantern.wav"],
		"volume_db": 1.5,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.20,
		"max_polyphony": 1,
	},
	EVENT_ABILITY_FREEZER: {
		"loudness_class": &"ability_warning",
		"streams": ["res://assets/audio/ability_freezer/freeze.wav"],
		"volume_db": -1.44,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.20,
		"max_polyphony": 1,
	},
	EVENT_LEVEL_COMPLETE: {
		"loudness_class": &"terminal_stinger",
		"streams": ["res://assets/audio/level_complete/level_complete.mp3"],
		"volume_db": -4.0,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.75,
		"max_polyphony": 1,
	},
	EVENT_LEVEL_FAILED: {
		"loudness_class": &"terminal_stinger",
		"streams": ["res://assets/audio/level_failed/level_failed.wav"],
		"volume_db": -7.72,
		"volume_variation_db": 0.0,
		"pitch_range": Vector2(1.0, 1.0),
		"cooldown_seconds": 0.75,
		"max_polyphony": 1,
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
