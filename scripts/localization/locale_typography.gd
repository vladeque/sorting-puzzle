extends RefCounted

## Prioritize Taiwan glyph forms while Traditional Chinese is selected. Restore the shared
## theme's original order for other locales, keeping Japanese glyph forms and Latin faces.
const THEME := preload("res://assets/themes/game_typography.tres")
const CHINESE_FONT := "res://assets/fonts/NotoSansTC-Variable.ttf"
const JAPANESE_FONT := "res://assets/fonts/NotoSansJP-Variable.ttf"
static var _original_fallbacks: Dictionary = {}


static func apply_locale(locale: String) -> void:
	var fonts: Array[Font] = [THEME.default_font]
	for theme_type in THEME.get_font_type_list():
		for font_name in THEME.get_font_list(theme_type):
			var font := THEME.get_font(font_name, theme_type)
			if not fonts.has(font):
				fonts.append(font)
	for font in fonts:
		var font_id := font.get_instance_id()
		if not _original_fallbacks.has(font_id):
			_original_fallbacks[font_id] = font.fallbacks.duplicate()
		var fallbacks: Array[Font] = _original_fallbacks[font_id].duplicate()
		if locale.begins_with("zh_Hant"):
			var chinese: Font
			var japanese: Font
			for fallback in fallbacks:
				if not fallback is FontVariation:
					continue
				var path := (fallback as FontVariation).base_font.resource_path
				if path == CHINESE_FONT:
					chinese = fallback
				elif path == JAPANESE_FONT:
					japanese = fallback
			if chinese != null and japanese != null:
				fallbacks.erase(chinese)
				fallbacks.insert(fallbacks.find(japanese), chinese)
		if font.fallbacks != fallbacks:
			font.fallbacks = fallbacks
