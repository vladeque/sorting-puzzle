extends SceneTree

const ContentProvenanceManifestScript := preload(
	"res://scripts/save/content_provenance_manifest.gd"
)


func _init() -> void:
	var manifest = ContentProvenanceManifestScript.new()
	var result: Dictionary = manifest.load_manifest_with_source_verification()
	if not bool(result.get("ok", false)):
		push_error(
			"GAME-002 content provenance check failed [%s]: %s" % [
				result.get("code", "content_manifest.invalid"),
				result.get("error", "Unknown manifest error."),
			]
		)
		quit(1)
		return
	print(
		"GAME-002 content provenance check passed: %s (%s)." % [
			result.get("digest_sha256", ""),
			result.get("environment", ""),
		]
	)
	quit(0)
