extends SceneTree

## GAME-010 cross-runtime fixture gate. Loads every document named by the authoritative backend
## v1, v1.1, and v2 manifests through Godot's JSON implementation and performs the protocol-v2
## hash-chain invariants used by the shipped save client. GAME-011 additionally checks the
## client-owned additive v2.1 Freezer goldens while the checked-out backend manifest remains the
## supported v2.0 compatibility gate.

const EXPECTED_MANIFESTS := {
	"v1": {"protocol_version": "1.0", "fixture_version": "1.0.0"},
	"v1.1": {"protocol_version": "1.1", "fixture_version": "1.1.6"},
	"v2": {"protocol_version": "2.0", "fixture_version": "save-sync-fixtures/1"},
}

var _failures: Array[String] = []
var _fixture_count := 0


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var backend_root := (
		str(arguments[0])
		if arguments.size() == 1
		else ProjectSettings.globalize_path("res://../sorting-puzzle-backend")
	)
	var fixtures_root := backend_root.path_join("contracts/fixtures")

	for directory: String in EXPECTED_MANIFESTS:
		_check_manifest(fixtures_root.path_join(directory).path_join("manifest.json"), directory)
	_check_client_v21_fixtures()

	if _failures.is_empty():
		print(
			"GAME-010 contract fixture gate passed: %d fixtures across v1=%s, v1.1=%s, v2=%s."
			% [
				_fixture_count,
				EXPECTED_MANIFESTS["v1"]["fixture_version"],
				EXPECTED_MANIFESTS["v1.1"]["fixture_version"],
				EXPECTED_MANIFESTS["v2"]["fixture_version"],
			]
		)
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _check_manifest(manifest_path: String, directory: String) -> void:
	var manifest = _parse_object(manifest_path)
	if not (manifest is Dictionary):
		return
	var expected: Dictionary = EXPECTED_MANIFESTS[directory]
	_check(
		str(manifest.get("protocol_version", "")) == str(expected["protocol_version"]),
		"%s protocol_version matches the pinned gate version" % directory
	)
	_check(
		str(manifest.get("fixture_version", "")) == str(expected["fixture_version"]),
		"%s fixture_version matches the pinned gate version" % directory
	)
	_check(not str(manifest.get("schema_id", "")).is_empty(), "%s names its schema" % directory)

	var fixtures = manifest.get("fixtures", [])
	if not (fixtures is Array) or fixtures.is_empty():
		_failures.append("%s manifest fixtures must be a non-empty array" % directory)
		return
	for raw_fixture in fixtures:
		if not (raw_fixture is Dictionary):
			_failures.append("%s manifest contains a non-object fixture descriptor" % directory)
			continue
		var fixture: Dictionary = raw_fixture
		var relative_path := str(fixture.get("path", ""))
		_check(not str(fixture.get("id", "")).is_empty(), "%s fixture id is present" % directory)
		_check(not str(fixture.get("schema_ref", "")).is_empty(), "%s schema_ref is present" % directory)
		var document = _parse_object(manifest_path.get_base_dir().path_join(relative_path))
		if not (document is Dictionary):
			continue
		var reparsed = JSON.parse_string(JSON.stringify(document))
		_check(reparsed is Dictionary, "%s round-trips through Godot JSON" % relative_path)
		_fixture_count += 1
		if directory == "v2" and str(fixture.get("id", "")) == "save-sync-request":
			_check_v2_save_request(document)


func _check_v2_save_request(document: Dictionary) -> void:
	var meta = document.get("meta", {})
	var data = document.get("data", {})
	_check(meta is Dictionary and str(meta.get("protocol_version", "")) == "2.0", "v2 request selects 2.0")
	if not (data is Dictionary):
		_failures.append("v2 save-sync request data must be an object")
		return
	var operations = data.get("operations", [])
	_check(operations is Array and operations.size() <= 500, "v2 operation batch respects the 500 limit")
	if not (operations is Array):
		return
	var cursor = data.get("cursor", {})
	if not (cursor is Dictionary):
		_failures.append("v2 save-sync cursor must be an object")
		return
	var expected_sequence := int(cursor.get("acknowledged_sequence", 0)) + 1
	var previous_hash = cursor.get("acknowledged_hash")
	for raw_operation in operations:
		if not (raw_operation is Dictionary):
			_failures.append("v2 save-sync operation must be an object")
			continue
		var operation: Dictionary = raw_operation
		_check(str(operation.get("format", "")) == "save-operation/2", "v2 operation format is closed")
		_check(
			int(operation.get("device_sequence", 0)) == expected_sequence,
			"v2 device sequence is contiguous"
		)
		_check(
			operation.get("previous_operation_hash") == previous_hash,
			"v2 previous hash chains from the cursor"
		)
		expected_sequence += 1
		previous_hash = operation.get("operation_hash")


func _check_client_v21_fixtures() -> void:
	var fixture_root := ProjectSettings.globalize_path("res://tests/fixtures/save_sync_v2")
	var request: Variant = _parse_object(fixture_root.path_join("batch_sync_request.json"))
	if request is Dictionary:
		var request_meta := (request as Dictionary).get("meta", {}) as Dictionary
		_check(
			str(request_meta.get("protocol_version", "")) == "2.1",
			"client Freezer request selects protocol 2.1"
		)
		_check_v2_save_request_chain(request as Dictionary)

	for response_name in [
		"batch_sync_response.json",
		"empty_sync_response.json",
		"continuation_first_response.json",
		"continuation_second_response.json",
		"final_state_response.json",
	]:
		var response: Variant = _parse_object(fixture_root.path_join(response_name))
		if not (response is Dictionary):
			continue
		var response_document := response as Dictionary
		var meta := response_document.get("meta", {}) as Dictionary
		var data := response_document.get("data", {}) as Dictionary
		var checkpoint := data.get("checkpoint", {}) as Dictionary
		var abilities := checkpoint.get("abilities", {}) as Dictionary
		_check(
			str(meta.get("protocol_version", "")) == "2.1",
			"%s selects protocol 2.1" % response_name
		)
		_check(
			int(abilities.get("freezer", -1)) == 3,
			"%s checkpoints the fourth ability" % response_name
		)

	var compatibility: Variant = _parse_object(fixture_root.path_join("stale_cursor_response.json"))
	if compatibility is Dictionary:
		var compatibility_body := (compatibility as Dictionary).get("body", {}) as Dictionary
		var compatibility_meta := compatibility_body.get("meta", {}) as Dictionary
		_check(
			str(compatibility_meta.get("protocol_version", "")) == "2.0",
			"client retains an explicit supported v2.0 response fixture"
		)


func _check_v2_save_request_chain(document: Dictionary) -> void:
	var data := document.get("data", {}) as Dictionary
	var operations := data.get("operations", []) as Array
	var cursor := data.get("cursor", {}) as Dictionary
	var expected_sequence := int(cursor.get("acknowledged_sequence", 0)) + 1
	var previous_hash = cursor.get("acknowledged_hash")
	for raw_operation in operations:
		var operation := raw_operation as Dictionary
		_check(
			int(operation.get("device_sequence", 0)) == expected_sequence,
			"client v2.1 device sequence is contiguous"
		)
		_check(
			operation.get("previous_operation_hash") == previous_hash,
			"client v2.1 previous hash chains from the cursor"
		)
		expected_sequence += 1
		previous_hash = operation.get("operation_hash")


func _parse_object(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("Could not open fixture: %s" % path)
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_failures.append(
			"Invalid JSON in %s at line %d: %s"
			% [path, parser.get_error_line(), parser.get_error_message()]
		)
		return null
	if not (parser.data is Dictionary):
		_failures.append("Fixture root must be an object: %s" % path)
		return null
	return parser.data


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
