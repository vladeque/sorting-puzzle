extends SaveProvider
class_name CloudSaveProvider

const DEFAULT_ANDROID_BRIDGE := "GooglePlayGamesSaveBridge"
const DEFAULT_IOS_BRIDGE := "GameCenterSaveBridge"
const FALLBACK_BRIDGE := "CloudSaveBridge"
const LOAD_METHODS := [
	"load_save",
	"load_game",
	"load_progress",
	"load_data",
]
const SAVE_METHODS := [
	"save_save",
	"save_game",
	"save_progress",
	"save_data",
]
const SIGNED_IN_METHODS := [
	"is_signed_in",
	"is_authenticated",
]

var _save_name := ""
var _bridge_singleton_name := ""


func _init(save_name: String, bridge_singleton_name: String = "") -> void:
	_save_name = save_name
	_bridge_singleton_name = bridge_singleton_name


func get_provider_name() -> String:
	match OS.get_name():
		"Android":
			return "google_play_games"
		"iOS":
			return "apple_game_center"
		_:
			return "cloud"


func is_available() -> bool:
	var bridge := _get_bridge()
	return bridge != null and _has_any_method(bridge, LOAD_METHODS) and _has_any_method(bridge, SAVE_METHODS)


func load_data() -> Dictionary:
	var bridge := _get_bridge()
	if bridge == null:
		return _error("No cloud save bridge singleton is available for %s." % get_provider_name())

	if not _is_bridge_signed_in(bridge):
		return _error("Cloud save bridge is not signed in for %s." % get_provider_name())

	var call_result := _call_first_method(bridge, LOAD_METHODS, [_save_name])
	if not bool(call_result.get("called", false)):
		return _error("Cloud save bridge does not expose a load method.")

	return _normalize_load_result(call_result.get("value"))


func save_data(data: Dictionary) -> Dictionary:
	var bridge := _get_bridge()
	if bridge == null:
		return _error("No cloud save bridge singleton is available for %s." % get_provider_name())

	if not _is_bridge_signed_in(bridge):
		return _error("Cloud save bridge is not signed in for %s." % get_provider_name())

	var payload := JSON.stringify(data)
	var call_result := _call_first_method(bridge, SAVE_METHODS, [_save_name, payload])
	if not bool(call_result.get("called", false)):
		return _error("Cloud save bridge does not expose a save method.")

	return _normalize_save_result(call_result.get("value"))


func _get_bridge() -> Object:
	for singleton_name in _get_bridge_singleton_candidates():
		if Engine.has_singleton(singleton_name):
			return Engine.get_singleton(singleton_name)

	return null


func _get_bridge_singleton_candidates() -> Array:
	var candidates := []
	if not _bridge_singleton_name.is_empty():
		candidates.append(_bridge_singleton_name)

	match OS.get_name():
		"Android":
			candidates.append(DEFAULT_ANDROID_BRIDGE)
		"iOS":
			candidates.append(DEFAULT_IOS_BRIDGE)

	candidates.append(FALLBACK_BRIDGE)
	return candidates


func _is_bridge_signed_in(bridge: Object) -> bool:
	for method_name in SIGNED_IN_METHODS:
		if bridge.has_method(method_name):
			return bool(bridge.call(method_name))

	return true


func _has_any_method(bridge: Object, method_names: Array) -> bool:
	for method_name in method_names:
		if bridge.has_method(method_name):
			return true

	return false


func _call_first_method(bridge: Object, method_names: Array, args: Array) -> Dictionary:
	for method_name in method_names:
		if bridge.has_method(method_name):
			return {
				"called": true,
				"value": bridge.callv(method_name, args),
			}

	return {"called": false}


func _normalize_load_result(result) -> Dictionary:
	if result == null:
		return _error("Cloud save load returned no data.")

	if result is Dictionary:
		if result.has("ok") and not bool(result.get("ok")):
			return _error(str(result.get("error", "Cloud save load failed.")))

		var raw_data = result.get("data", result)
		return _parse_cloud_payload(raw_data)

	return _parse_cloud_payload(result)


func _normalize_save_result(result) -> Dictionary:
	if result == null:
		return _success({})

	if result is bool:
		return _success({}) if result else _error("Cloud save write failed.")

	if result is Dictionary:
		if result.has("ok") and not bool(result.get("ok")):
			return _error(str(result.get("error", "Cloud save write failed.")))

		return _success({})

	return _success({})


func _parse_cloud_payload(raw_data) -> Dictionary:
	if raw_data is Dictionary:
		return _success(raw_data)

	if raw_data is PackedByteArray:
		return _parse_cloud_payload(raw_data.get_string_from_utf8())

	if raw_data is String:
		if raw_data.is_empty():
			return _success({})

		var parsed = JSON.parse_string(raw_data)
		if parsed is Dictionary:
			return _success(parsed)

		return _error("Cloud save payload is not valid JSON.")

	return _error("Cloud save payload has unsupported type: %s" % type_string(typeof(raw_data)))
