# MIT License
#
# Copyright (c) 2026-present Poing Studios
#
# This project-local entry point is intentionally smaller than the upstream v5.1.0 editor plugin:
# it registers only settings and Android/iOS export hooks. The upstream network downloader, editor
# menus, samples, C# surface, AI skills, and native mediation packages are deliberately not
# vendored. Upstream GDScript mediation value types remain because core request classes reference
# them, but no mediation network binary is packaged.

@tool
extends EditorPlugin

const ProjectSettingsService := preload(
	"res://addons/admob/internal/services/project_settings_service.gd"
)

var _main_exporter := preload(
	"res://addons/admob/internal/exporters/main_export_plugin.gd"
).new()
var _android_exporter := preload(
	"res://addons/admob/internal/exporters/android/export_plugin.gd"
).new()
var _ios_exporter := preload(
	"res://addons/admob/internal/exporters/ios/export_plugin.gd"
).new()


func _enter_tree() -> void:
	ProjectSettingsService.register_settings()
	add_export_plugin(_main_exporter)
	add_export_plugin(_android_exporter)
	add_export_plugin(_ios_exporter)


func _exit_tree() -> void:
	remove_export_plugin(_main_exporter)
	remove_export_plugin(_android_exporter)
	remove_export_plugin(_ios_exporter)
