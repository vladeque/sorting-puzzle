extends RefCounted
class_name ProfileFrameCatalog

const CONFIG_PATH := "res://configs/profile_frames.json"
const FALLBACK_FRAME_ID := "frame_classic"

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


static func create_frame_style(frame_id: String) -> StyleBoxFlat:
	_ensure_loaded()
	var definition := _frames.get(sanitize_frame_id(frame_id), {}) as Dictionary
	var style := StyleBoxFlat.new()
	style.bg_color = Color.from_string(
		str(definition.get("background_color", "#8f514eff")),
		Color("8f514e")
	)
	style.border_color = Color.from_string(
		str(definition.get("border_color", "#ffe6a6ff")),
		Color("ffe6a6")
	)
	var border_width := maxi(int(definition.get("border_width", 4)), 1)
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 96
	style.corner_radius_top_right = 96
	style.corner_radius_bottom_right = 96
	style.corner_radius_bottom_left = 96
	style.shadow_color = Color.from_string(
		str(definition.get("shadow_color", "#2f0f0a55")),
		Color(0.18, 0.06, 0.04, 0.34)
	)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style


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
			"background_color": "#8f514eff",
			"border_color": "#ffe6a6ff",
			"border_width": 4,
			"shadow_color": "#2f0f0a55",
		}
		_ordered_ids.append(FALLBACK_FRAME_ID)
		_default_frame_id = FALLBACK_FRAME_ID
	elif not _frames.has(_default_frame_id):
		_default_frame_id = _ordered_ids[0]
