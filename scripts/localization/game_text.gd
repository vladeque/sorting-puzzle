class_name GameText
extends RefCounted

## Presentation-only formatting. Counts, dates, prices, IDs and protocol data stay unchanged.
const MONTH_NAMES := [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]
const PURCHASE_MESSAGES := [
	"The purchase could not be completed.",
	"The purchased rewards could not be granted.",
	"This shop offer is unavailable.",
	"This one-time shop offer has already been purchased.",
	"This offer is no longer available.",
]


static func format_number(value: int) -> String:
	var digits := str(maxi(value, 0))
	var language := TranslationServer.get_locale().get_slice("_", 0)
	var separator := " " if language in ["ru", "uk", "fr"] else ","
	if language in ["it", "es", "pt", "de", "id", "tr"]:
		separator = "."
	var formatted := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += separator
		formatted += digits[index]
	return formatted


static func format_date(date: Dictionary) -> String:
	var month := clampi(int(date.get("month", 1)), 1, 12)
	var day := int(date.get("day", 1))
	var year := int(date.get("year", 1970))
	var language := TranslationServer.get_locale().get_slice("_", 0)
	if language in ["ja", "zh"]:
		return "%d年%d月%d日" % [year, month, day]
	if language == "ko":
		return "%d년 %d월 %d일" % [year, month, day]
	if language == "de":
		return "%02d.%02d.%04d" % [day, month, year]
	if language == "ar":
		return "%d/%d/%d" % [day, month, year]
	if language in ["ru", "uk", "it", "es", "pt", "fr", "id", "tr"]:
		var month_name := TranslationServer.translate("date.month.%d" % month)
		return TranslationServer.translate("date.day_month_year") % [day, month_name, year]
	return "%s %d, %d" % [MONTH_NAMES[month - 1], day, year]


## Godot's default uppercase mapping does not distinguish Turkish dotted/dotless I.
static func uppercase(text: String) -> String:
	if TranslationServer.get_locale().get_slice("_", 0) == "tr":
		text = text.replace("i", "İ").replace("ı", "I")
	return text.to_upper()


static func counted_booster(title: String, count: int) -> String:
	return TranslationServer.translate_plural(title, title + ".plural", count, "booster.counted")


## Display-only isolation of technical LTR tokens embedded in Arabic prose. Never persist this
## result or use it in URLs, email templates, player names, IDs or protocol payloads.
static func isolate_ltr(value: String) -> String:
	if TranslationServer.get_locale().get_slice("_", 0) == "ar" and not value.is_empty():
		return "\u2066" + value + "\u2069"
	return value


## Store prices may contain Arabic currency names or provider direction marks. First-strong
## isolation keeps their own content direction when embedded in an Arabic purchase caption.
static func isolate_price(value: String) -> String:
	if TranslationServer.get_locale().get_slice("_", 0) == "ar" and not value.is_empty():
		return "\u2068" + value + "\u2069"
	return value


static func combo_caption(count: int) -> String:
	var text := TranslationServer.translate("hud.combo") % count
	var token := "×%d" % count
	return text.replace(token, isolate_ltr(token))


static func claimed_booster_caption(title: String, count: int) -> String:
	var text := TranslationServer.translate("booster_chip.claimed") % [count, counted_booster(title, count)]
	var token := "+%d" % count
	return text.replace(token, isolate_ltr(token))


## Only reviewed purchase copy reaches the UI. Protocol/validation prose remains diagnostic.
static func purchase_error(message: String, grant_failed: bool = false) -> String:
	if PURCHASE_MESSAGES.has(message):
		return message
	return (
		"The purchased rewards could not be granted." if grant_failed
		else "The purchase could not be completed."
	)
