extends RefCounted

## Adapts the shared theme's fonts to the selected locale and restores the theme's authored fonts
## for every other locale. Traditional Chinese moves its Taiwan glyph forms ahead of the Japanese
## ones. Russian and Ukrainian draw each DynaPuff display role entirely in its heavier bundled
## Nunito fallback, so digits and Latin text match the Cyrillic letters beside them.
const THEME := preload("res://assets/themes/game_typography.tres")
const DISPLAY_FONT := "res://assets/fonts/DynaPuff-Variable.ttf"
const CYRILLIC_FONTS: Array[String] = ["res://assets/fonts/Nunito-Variable.ttf"]
const CHINESE_FONTS: Array[String] = [
	"res://assets/fonts/Huninn-Regular.ttf",
	"res://assets/fonts/NotoSansTC-Variable.ttf",
]
const JAPANESE_FONTS: Array[String] = [
	"res://assets/fonts/MPLUSRounded1c-ExtraBold.ttf",
	"res://assets/fonts/NotoSansJP-Variable.ttf",
]
const CYRILLIC_DISPLAY_LANGUAGES: Array[String] = ["ru", "uk"]
const WEIGHT_AXIS := 2003265652 # OpenType "wght".
static var _originals: Dictionary = {}


static func apply_locale(locale: String) -> void:
	var cyrillic_display := CYRILLIC_DISPLAY_LANGUAGES.has(locale.get_slice("_", 0))
	for font: FontVariation in _theme_fonts():
		var original := _original_state(font)
		var base_font: Font = original["base_font"]
		var variation: Dictionary = (original["variation"] as Dictionary).duplicate()
		var fallbacks: Array[Font] = (original["fallbacks"] as Array[Font]).duplicate()
		if locale.begins_with("zh_Hant"):
			var chinese := _find_fallback(fallbacks, CHINESE_FONTS)
			var japanese := _find_fallback(fallbacks, JAPANESE_FONTS)
			if chinese != null and japanese != null:
				fallbacks.erase(chinese)
				fallbacks.insert(fallbacks.find(japanese), chinese)
		if cyrillic_display and _path(base_font) == DISPLAY_FONT:
			var cyrillic := _find_fallback(fallbacks, CYRILLIC_FONTS)
			if cyrillic != null:
				base_font = cyrillic.base_font
				variation[WEIGHT_AXIS] = cyrillic.variation_opentype.get(WEIGHT_AXIS, variation.get(WEIGHT_AXIS))
				fallbacks.erase(cyrillic)
		if font.base_font != base_font:
			font.base_font = base_font
		if font.variation_opentype != variation:
			font.variation_opentype = variation
		if font.fallbacks != fallbacks:
			font.fallbacks = fallbacks


static func _theme_fonts() -> Array[FontVariation]:
	var fonts: Array[FontVariation] = []
	var candidates: Array[Font] = [THEME.default_font]
	for theme_type in THEME.get_font_type_list():
		for font_name in THEME.get_font_list(theme_type):
			candidates.append(THEME.get_font(font_name, theme_type))
	for font in candidates:
		if font is FontVariation and not fonts.has(font):
			fonts.append(font as FontVariation)
	return fonts


static func _original_state(font: FontVariation) -> Dictionary:
	var font_id := font.get_instance_id()
	if not _originals.has(font_id):
		_originals[font_id] = {
			"base_font": font.base_font,
			"variation": font.variation_opentype.duplicate(),
			"fallbacks": font.fallbacks.duplicate(),
		}
	return _originals[font_id]


static func _find_fallback(fallbacks: Array[Font], paths: Array[String]) -> FontVariation:
	for fallback in fallbacks:
		if fallback is FontVariation and paths.has(_path((fallback as FontVariation).base_font)):
			return fallback as FontVariation
	return null


static func _path(font: Font) -> String:
	return font.resource_path if font != null else ""
