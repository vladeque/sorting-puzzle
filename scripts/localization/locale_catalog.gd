class_name LocaleCatalog
extends RefCounted

## Stable release-language allowlist. Labels are English development copy only; translation
## resources and localized/native language names are intentionally owned by later localization work.

const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES: Array[Dictionary] = [
	{"locale": "en", "label": "English"},
	{"locale": "es", "label": "Spanish"},
	{"locale": "pt_BR", "label": "Brazilian Portuguese"},
	{"locale": "de", "label": "German"},
	{"locale": "fr", "label": "French"},
	{"locale": "ja", "label": "Japanese"},
	{"locale": "ko", "label": "Korean"},
	{"locale": "zh_Hant", "label": "Traditional Chinese"},
	{"locale": "id", "label": "Indonesian"},
	{"locale": "tr", "label": "Turkish"},
	{"locale": "ru", "label": "Russian"},
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
		"en", "es", "de", "fr", "ja", "ko", "id", "tr", "ru":
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
