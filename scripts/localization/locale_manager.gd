extends Node

signal locale_changed(locale: String)

const LocaleCatalogScript := preload("res://scripts/localization/locale_catalog.gd")


func _ready() -> void:
	TranslationServer.set_locale(PlayerProgress.get_locale())


func get_supported_locales() -> Array[Dictionary]:
	return LocaleCatalogScript.get_entries()


func get_current_locale() -> String:
	return PlayerProgress.get_locale()


func set_locale(locale: String) -> bool:
	if not LocaleCatalogScript.is_supported(locale):
		return false
	var sanitized := LocaleCatalogScript.sanitize_saved_locale(locale)
	if not PlayerProgress.set_locale(sanitized):
		return false
	TranslationServer.set_locale(sanitized)
	locale_changed.emit(sanitized)
	return true
