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
	var separator := " " if language in ["ru", "uk"] else ","
	if language == "it":
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
	if language in ["ru", "uk", "it"]:
		var month_name := TranslationServer.translate("date.month.%d" % month)
		return TranslationServer.translate("date.day_month_year") % [day, month_name, year]
	return "%s %d, %d" % [MONTH_NAMES[month - 1], day, year]


static func counted_booster(title: String, count: int) -> String:
	return TranslationServer.translate_plural(title, title + ".plural", count, "booster.counted")


## Only reviewed purchase copy reaches the UI. Protocol/validation prose remains diagnostic.
static func purchase_error(message: String, grant_failed: bool = false) -> String:
	if PURCHASE_MESSAGES.has(message):
		return message
	return (
		"The purchased rewards could not be granted." if grant_failed
		else "The purchase could not be completed."
	)
