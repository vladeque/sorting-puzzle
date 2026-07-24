extends RefCounted
class_name LocalSaveCodec

const OPERATION_FORMAT := "save-operation/2"
const UUID_PATTERN := "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
const HASH_PATTERN := "^[a-f0-9]{64}$"
const OPAQUE_ID_PATTERN := "^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$"
const TIMESTAMP_PATTERN := "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$"


static func canonical_json(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			var float_value := float(value)
			if not is_finite(float_value) or float_value != floor(float_value):
				return ""
			return str(int(float_value))
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(String(value))
		TYPE_ARRAY:
			var array_parts := PackedStringArray()
			for entry in value as Array:
				var encoded_entry := canonical_json(entry)
				if encoded_entry.is_empty():
					return ""
				array_parts.append(encoded_entry)
			return "[%s]" % ",".join(array_parts)
		TYPE_DICTIONARY:
			var dictionary := value as Dictionary
			var keys := PackedStringArray()
			for raw_key in dictionary.keys():
				if not (raw_key is String or raw_key is StringName):
					return ""
				keys.append(String(raw_key))
			keys.sort()

			var object_parts := PackedStringArray()
			for key in keys:
				var encoded_value := canonical_json(dictionary.get(key))
				if encoded_value.is_empty():
					return ""
				object_parts.append("%s:%s" % [JSON.stringify(key), encoded_value])
			return "{%s}" % ",".join(object_parts)
		_:
			return ""


static func sha256_text(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()


static func sha256_json(value: Variant) -> String:
	var encoded := canonical_json(value)
	return sha256_text(encoded) if not encoded.is_empty() else ""


static func operation_hash(operation: Dictionary) -> String:
	var hashable := {
		"format": operation.get("format"),
		"operation_id": operation.get("operation_id"),
		"device_id": operation.get("device_id"),
		"device_sequence": operation.get("device_sequence"),
		"operation_type": operation.get("operation_type"),
		"occurred_at": operation.get("occurred_at"),
		"previous_operation_hash": operation.get("previous_operation_hash"),
		"payload": operation.get("payload"),
	}
	return sha256_json(hashable)


static func create_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]


static func iso_timestamp(unix_time: int = -1) -> String:
	var timestamp := unix_time
	if timestamp < 0:
		timestamp = int(Time.get_unix_time_from_system())
	# get_datetime_string_from_unix_time's second argument is `use_space`: true renders a space
	# separator ("YYYY-MM-DD HH:MM:SS"), not UTC. It must stay false to produce the ISO-8601 "T"
	# separator the backend's Timestamp schema requires everywhere this client sends a timestamp
	# (meta.client_time, occurred_at, observed_at, ...). A real backend round-trip confirmed the
	# space-separated form is rejected outright: 400 request.invalid / request.schema.pattern on
	# the violating field.
	return "%s.000Z" % Time.get_datetime_string_from_unix_time(timestamp, false)


static func unix_from_timestamp(value: Variant) -> int:
	if value == null:
		return 0
	var timestamp := str(value)
	if timestamp.ends_with("Z"):
		timestamp = timestamp.left(-1)
	var milliseconds_index := timestamp.find(".")
	if milliseconds_index >= 0:
		timestamp = timestamp.left(milliseconds_index)
	return int(Time.get_unix_time_from_datetime_string(timestamp))


static func is_uuid(value: Variant) -> bool:
	return _matches(str(value), UUID_PATTERN)


static func is_hash(value: Variant) -> bool:
	return _matches(str(value), HASH_PATTERN)


static func is_opaque_id(value: Variant) -> bool:
	return _matches(str(value), OPAQUE_ID_PATTERN)


static func is_timestamp(value: Variant) -> bool:
	var text := str(value)
	# Matches the backend's Timestamp schema exactly (any millisecond value, not just this
	# client's own always-".000Z" iso_timestamp() output) so genuine server-issued or
	# real-millisecond-precision timestamps validate correctly, not just self-authored ones.
	if not _matches(text, TIMESTAMP_PATTERN):
		return false
	return unix_from_timestamp(text) > 0


static func is_namespace(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var save_namespace := value as Dictionary
	match str(save_namespace.get("kind", "")):
		"player":
			return save_namespace.size() == 2 and is_uuid(save_namespace.get("player_id"))
		"installation_guest":
			return save_namespace.size() == 2 and is_uuid(save_namespace.get("installation_id"))
	return false


static func namespace_key(save_namespace: Dictionary) -> String:
	if str(save_namespace.get("kind", "")) == "player":
		return "player_%s" % str(save_namespace.get("player_id", ""))
	return "guest_%s" % str(save_namespace.get("installation_id", ""))


static func _matches(value: String, pattern: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return false
	return regex.search(value) != null
