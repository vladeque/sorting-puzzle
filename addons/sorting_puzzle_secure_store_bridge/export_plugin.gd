@tool
extends EditorPlugin

## GAME-003: packages the SortingPuzzleSecureStoreBridge Android AAR into Gradle-build Android
## exports as the `SortingPuzzleSecureStoreBridge` v2 plugin singleton referenced by
## `scripts/save/secure_session_store.gd`.
##
## Build the AAR first (JDK 17, Android SDK 36 — see platform/android/secure-store-plugin/README.md):
##   platform/android/secure-store-plugin> ./gradlew :plugin:assembleDebug :plugin:assembleRelease
##
## Debug Godot exports load the debug AAR, whose plugin/src/debug/AndroidManifest.xml requests the
## INTERNET permission and android:usesCleartextTraffic="true" so a debug build can reach a
## developer-hosted http:// backend. The release AAR requests neither, so this plugin stays safe by
## default even if accidentally left enabled for a release export.

var export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "SortingPuzzleSecureStoreBridge"
	const AAR_DIR := "res://platform/android/secure-store-plugin/plugin/build/outputs/aar/"
	const DEBUG_AAR := AAR_DIR + "SortingPuzzleSecureStoreBridge-debug.aar"
	const RELEASE_AAR := AAR_DIR + "SortingPuzzleSecureStoreBridge-release.aar"
	const DEBUG_CONFIG_PATH := "res://local/backend_debug.cfg"
	const KOTLIN_STDLIB_DEPENDENCY := "org.jetbrains.kotlin:kotlin-stdlib:2.2.21"

	func _get_name() -> String:
		return PLUGIN_NAME

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _export_begin(
		_features: PackedStringArray,
		is_debug: bool,
		_path: String,
		_flags: int
	) -> void:
		if not is_debug:
			return
		if not FileAccess.file_exists(DEBUG_CONFIG_PATH):
			push_warning(
				(
					"%s is missing. The debug export will keep synchronization disabled; copy "
					+ "local/backend_debug.example.cfg to local/backend_debug.cfg before running "
					+ "the GAME-003 emulator smoke check."
				) % DEBUG_CONFIG_PATH
			)
			return
		add_file(DEBUG_CONFIG_PATH, FileAccess.get_file_as_bytes(DEBUG_CONFIG_PATH), false)

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var aar_path := DEBUG_AAR if debug else RELEASE_AAR
		if not FileAccess.file_exists(aar_path):
			push_warning(
				(
					"%s AAR not found at %s. Build it first with: ./gradlew :plugin:%s "
					+ "(run from platform/android/secure-store-plugin/). Export continues without "
					+ "the secure storage bridge until the AAR exists."
				) % [
					PLUGIN_NAME,
					aar_path,
					"assembleDebug" if debug else "assembleRelease",
				]
			)
			return PackedStringArray()
		return PackedStringArray([aar_path])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([KOTLIN_STDLIB_DEPENDENCY])
