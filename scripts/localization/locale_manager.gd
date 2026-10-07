extends Node

signal locale_changed(locale: String)

const LocaleCatalogScript := preload("res://scripts/localization/locale_catalog.gd")
const LocaleTypographyScript := preload("res://scripts/localization/locale_typography.gd")


func _ready() -> void:
	LocaleTypographyScript.apply_locale(PlayerProgress.get_locale())
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
	LocaleTypographyScript.apply_locale(sanitized)
	TranslationServer.set_locale(sanitized)
	locale_changed.emit(sanitized)
	return true
