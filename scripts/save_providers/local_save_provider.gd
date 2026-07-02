extends SaveProvider
class_name LocalSaveProvider

var _save_path := ""


func _init(save_path: String) -> void:
	_save_path = save_path


func get_provider_name() -> String:
	return "local"


func load_data() -> Dictionary:
	if not FileAccess.file_exists(_save_path):
		return _success({})

	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return _error("Could not open local save for reading: %s" % _save_path)

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return _success(parsed)

	return _error("Ignoring invalid local save: %s" % _save_path)


func save_data(data: Dictionary) -> Dictionary:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		return _error("Could not open local save for writing: %s" % _save_path)

	file.store_string(JSON.stringify(data, "\t"))
	return _success({})
