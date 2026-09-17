extends RefCounted

## Shared semantic haptic catalog. Durations are milliseconds and amplitudes are normalized 0..1
## values for Godot's handheld fallback. Platform-native providers may map these same event ids to
## device-tuned selection, impact, notification, or warning effects instead.

const EVENT_ITEM_SELECT := &"item_select"
const EVENT_ITEM_PICKUP := &"item_pickup"
const EVENT_ITEM_PLACE_VALID := &"item_place_valid"
const EVENT_STICKY_MOVE_BLOCKED := &"sticky_move_blocked"
const EVENT_MATCH_CLEAR := &"match_clear"
const EVENT_SHELF_UNLOCK := &"shelf_unlock"
const EVENT_ABILITY_HAMMER := &"ability_hammer"
const EVENT_ABILITY_SHUFFLE := &"ability_shuffle"
const EVENT_ABILITY_LANTERN := &"ability_lantern"
const EVENT_ABILITY_FREEZER := &"ability_freezer"
const EVENT_TIME_UP := &"time_up"
const EVENT_TIME_EXTENSION_SUCCESS := &"time_extension_success"
const EVENT_LEVEL_COMPLETE := &"level_complete"
const EVENT_LEVEL_FAILED := &"level_failed"
const EVENT_SHOP_PURCHASE_SUCCESS := &"shop_purchase_success"
const EVENT_LIFE_PURCHASE_SUCCESS := &"life_purchase_success"
const EVENT_REWARD_CHEST_GOAL_COMPLETE := &"reward_chest_goal_complete"
const EVENT_LEADERBOARD_REWARD := &"leaderboard_reward"
const EVENT_VIBRATION_TOGGLE := &"vibration_toggle"

## `priority` lets an important result replace queued low-value feedback. `cooldown_seconds` bounds
## bursts from concurrent shelf resolution. Every pattern step has a pre-pulse delay, duration, and
## amplitude; keeping every individual pulse at or below 70 ms avoids lingering buzzy feedback.
const EVENTS := {
	EVENT_ITEM_SELECT: {
		"priority": 10,
		"cooldown_seconds": 0.035,
		"pattern": [{"delay_ms": 0, "duration_ms": 16, "amplitude": 0.18}],
	},
	EVENT_ITEM_PICKUP: {
		"priority": 10,
		"cooldown_seconds": 0.035,
		"pattern": [{"delay_ms": 0, "duration_ms": 16, "amplitude": 0.18}],
	},
	EVENT_ITEM_PLACE_VALID: {
		"priority": 20,
		"cooldown_seconds": 0.035,
		"pattern": [{"delay_ms": 0, "duration_ms": 22, "amplitude": 0.27}],
	},
	EVENT_STICKY_MOVE_BLOCKED: {
		"priority": 25,
		"cooldown_seconds": 0.28,
		"pattern": [{"delay_ms": 0, "duration_ms": 32, "amplitude": 0.34}],
	},
	EVENT_MATCH_CLEAR: {
		"priority": 40,
		"cooldown_seconds": 0.12,
		"count_amplitude_step": 0.035,
		"max_count_amplitude_bonus": 0.10,
		"pattern": [{"delay_ms": 0, "duration_ms": 40, "amplitude": 0.44}],
	},
	EVENT_SHELF_UNLOCK: {
		"priority": 50,
		"cooldown_seconds": 0.20,
		"pattern": [
			{"delay_ms": 0, "duration_ms": 18, "amplitude": 0.28},
			{"delay_ms": 42, "duration_ms": 34, "amplitude": 0.43},
		],
	},
	EVENT_ABILITY_HAMMER: {
		"priority": 70,
		"cooldown_seconds": 0.25,
		"pattern": [{"delay_ms": 0, "duration_ms": 65, "amplitude": 0.70}],
	},
	EVENT_ABILITY_SHUFFLE: {
		"priority": 55,
		"cooldown_seconds": 0.20,
		"pattern": [
			{"delay_ms": 0, "duration_ms": 22, "amplitude": 0.34},
			{"delay_ms": 35, "duration_ms": 22, "amplitude": 0.28},
		],
	},
	EVENT_ABILITY_LANTERN: {
		"priority": 55,
		"cooldown_seconds": 0.20,
		"pattern": [{"delay_ms": 0, "duration_ms": 28, "amplitude": 0.30}],
	},
	EVENT_ABILITY_FREEZER: {
		"priority": 55,
		"cooldown_seconds": 0.20,
		"pattern": [{"delay_ms": 0, "duration_ms": 42, "amplitude": 0.40}],
	},
	EVENT_TIME_UP: {
		"priority": 80,
		"cooldown_seconds": 0.75,
		"pattern": [
			{"delay_ms": 0, "duration_ms": 32, "amplitude": 0.38},
			{"delay_ms": 65, "duration_ms": 65, "amplitude": 0.55},
		],
	},
	EVENT_TIME_EXTENSION_SUCCESS: {
		"priority": 60,
		"cooldown_seconds": 0.30,
		"pattern": [{"delay_ms": 0, "duration_ms": 34, "amplitude": 0.40}],
	},
	EVENT_LEVEL_COMPLETE: {
		"priority": 90,
		"cooldown_seconds": 0.75,
		"pattern": [
			{"delay_ms": 0, "duration_ms": 22, "amplitude": 0.32},
			{"delay_ms": 45, "duration_ms": 50, "amplitude": 0.52},
		],
	},
	EVENT_LEVEL_FAILED: {
		"priority": 90,
		"cooldown_seconds": 0.75,
		"pattern": [
			{"delay_ms": 0, "duration_ms": 45, "amplitude": 0.42},
			{"delay_ms": 55, "duration_ms": 70, "amplitude": 0.58},
		],
	},
	EVENT_SHOP_PURCHASE_SUCCESS: {
		"priority": 80,
		"cooldown_seconds": 0.60,
		"pattern": [
			{"delay_ms": 0, "duration_ms": 22, "amplitude": 0.34},
			{"delay_ms": 45, "duration_ms": 48, "amplitude": 0.50},
		],
	},
	EVENT_LIFE_PURCHASE_SUCCESS: {
		"priority": 60,
		"cooldown_seconds": 0.30,
		"pattern": [{"delay_ms": 0, "duration_ms": 34, "amplitude": 0.40}],
	},
	EVENT_REWARD_CHEST_GOAL_COMPLETE: {
		"priority": 65,
		"cooldown_seconds": 0.35,
		"pattern": [
			{"delay_ms": 0, "duration_ms": 20, "amplitude": 0.30},
			{"delay_ms": 40, "duration_ms": 42, "amplitude": 0.46},
		],
	},
	EVENT_LEADERBOARD_REWARD: {
		"priority": 65,
		"cooldown_seconds": 0.60,
		"pattern": [
			{"delay_ms": 0, "duration_ms": 20, "amplitude": 0.30},
			{"delay_ms": 40, "duration_ms": 42, "amplitude": 0.46},
		],
	},
	EVENT_VIBRATION_TOGGLE: {
		"priority": 100,
		"cooldown_seconds": 0.0,
		"pattern": [{"delay_ms": 0, "duration_ms": 20, "amplitude": 0.25}],
	},
}


static func has_event(event_id: StringName) -> bool:
	return EVENTS.has(event_id)


static func get_event(event_id: StringName) -> Dictionary:
	return (EVENTS.get(event_id, {}) as Dictionary).duplicate(true)


static func get_event_ids() -> Array:
	return EVENTS.keys()
