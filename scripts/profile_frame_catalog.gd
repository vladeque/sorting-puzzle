extends RefCounted
class_name ProfileFrameCatalog

const CONFIG_PATH := "res://configs/profile_frames.json"
const FALLBACK_FRAME_ID := "frame_classic"
const FALLBACK_TEXTURE_PATH := "res://assets/ui/avatar_frames/frame_classic.png"

static var _frames: Dictionary = {}
static var _ordered_ids: Array[String] = []
static var _default_frame_id := FALLBACK_FRAME_ID


static func get_available_frame_ids() -> Array[String]:
	_ensure_loaded()
	return _ordered_ids.duplicate()


static func get_default_frame_id() -> String:
	_ensure_loaded()
	return _default_frame_id


static func sanitize_frame_id(frame_id: String) -> String:
	_ensure_loaded()
	return frame_id if _frames.has(frame_id) else _default_frame_id


static func get_frame_texture_path(frame_id: String) -> String:
	_ensure_loaded()
	var definition := _frames.get(sanitize_frame_id(frame_id), {}) as Dictionary
	var texture_path := str(definition.get("texture", FALLBACK_TEXTURE_PATH))
	return texture_path if ResourceLoader.exists(texture_path, "Texture2D") else FALLBACK_TEXTURE_PATH


static func _ensure_loaded() -> void:
	if not _ordered_ids.is_empty():
		return

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			var document := parsed as Dictionary
			_default_frame_id = str(document.get("default_frame_id", FALLBACK_FRAME_ID))
			for raw_definition in document.get("frames", []) as Array:
				if not (raw_definition is Dictionary):
					continue
				var definition := raw_definition as Dictionary
				var frame_id := str(definition.get("id", "")).strip_edges()
				if frame_id.is_empty() or _frames.has(frame_id):
					continue
				_frames[frame_id] = definition.duplicate(true)
				_ordered_ids.append(frame_id)

	if _ordered_ids.is_empty():
		_frames[FALLBACK_FRAME_ID] = {
			"id": FALLBACK_FRAME_ID,
			"texture": FALLBACK_TEXTURE_PATH,
		}
		_ordered_ids.append(FALLBACK_FRAME_ID)
		_default_frame_id = FALLBACK_FRAME_ID
	elif not _frames.has(_default_frame_id):
		_default_frame_id = _ordered_ids[0]
