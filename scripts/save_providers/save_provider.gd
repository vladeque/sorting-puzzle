extends RefCounted
class_name SaveProvider


func get_provider_name() -> String:
	return "save_provider"


func is_available() -> bool:
	return true


func load_data() -> Dictionary:
	return _error("Save provider does not implement load_data().")


func save_data(_data: Dictionary) -> Dictionary:
	return _error("Save provider does not implement save_data().")


func _success(data: Dictionary = {}) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error": "",
	}


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"error": message,
	}
