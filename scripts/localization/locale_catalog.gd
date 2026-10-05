class_name LocaleCatalog
extends RefCounted

## Stable release-language allowlist. Each label is the language's native display name so players
## can identify it before the rest of the interface has been translated.

const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES: Array[Dictionary] = [
	{"locale": "en", "label": "English"},
	{"locale": "es", "label": "Español"},
	{"locale": "pt_BR", "label": "Português (Brasil)"},
	{"locale": "de", "label": "Deutsch"},
	{"locale": "fr", "label": "Français"},
	{"locale": "it", "label": "Italiano"},
	{"locale": "ja", "label": "日本語"},
	{"locale": "ko", "label": "한국어"},
	{"locale": "zh_Hant", "label": "繁體中文"},
	{"locale": "id", "label": "Bahasa Indonesia"},
	{"locale": "tr", "label": "Türkçe"},
	{"locale": "ru", "label": "Русский"},
	{"locale": "uk", "label": "Українська"},
	{"locale": "ar", "label": "العربية"},
]


static func get_entries() -> Array[Dictionary]:
	return SUPPORTED_LOCALES.duplicate(true)


static func is_supported(locale: String) -> bool:
	return _supported_code(locale) != ""


static func sanitize_saved_locale(locale: String) -> String:
	var supported := _supported_code(locale)
	return supported if not supported.is_empty() else DEFAULT_LOCALE


## Maps a device locale to one of the deliberately supported release locales. Simplified Chinese
## does not silently map to Traditional Chinese; players can still choose Traditional Chinese from
## the language modal if they prefer it.
static func resolve_device_locale(locale: String) -> String:
	var standardized := TranslationServer.standardize_locale(locale)
	var exact := _supported_code(standardized)
	if not exact.is_empty():
		return exact

	if standardized.begins_with("zh_Hant"):
		return "zh_Hant"
	if (
		standardized.begins_with("zh_TW")
		or standardized.begins_with("zh_HK")
		or standardized.begins_with("zh_MO")
	):
		return "zh_Hant"

	var language := standardized.get_slice("_", 0)
	match language:
		"pt":
			return "pt_BR"
		"en", "es", "de", "fr", "it", "ja", "ko", "id", "tr", "ru", "uk", "ar":
			return language
		_:
			return DEFAULT_LOCALE


static func _supported_code(locale: String) -> String:
	var standardized := TranslationServer.standardize_locale(locale)
	for entry in SUPPORTED_LOCALES:
		var candidate := str(entry.get("locale", ""))
		if standardized == candidate:
			return candidate
	return ""
