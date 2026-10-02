extends RefCounted
class_name SupportContact

## Shared support e-mail route for the Support screen and the GAME-012 account-deletion modal: reads
## `application/config/support_email`, validates it, and opens a prefilled `mailto:` link. Callers
## supply only non-secret text; never put tokens, save files, or payment details in the body.

const SUPPORT_EMAIL_SETTING := "application/config/support_email"
const DEFAULT_SUPPORT_EMAIL := "support@sortingpuzzle.example"


static func get_support_email() -> String:
	return str(ProjectSettings.get_setting(SUPPORT_EMAIL_SETTING, DEFAULT_SUPPORT_EMAIL)).strip_edges()


## Opens the device e-mail app. Returns false when the address is unsafe or the app cannot open.
static func open_email(subject: String, body: String) -> bool:
	var mailto_url := build_mailto_url(get_support_email(), subject, body)
	if mailto_url.is_empty():
		push_warning("Support email is not configured.")
		return false
	if OS.shell_open(mailto_url) != OK:
		push_warning("Could not open the device email app.")
		return false
	return true


static func build_mailto_url(email: String, subject: String, body: String) -> String:
	var address := email.strip_edges()
	if not is_safe_email(address):
		return ""
	return "mailto:%s?subject=%s&body=%s" % [
		address,
		subject.uri_encode(),
		body.uri_encode(),
	]


static func is_safe_email(email: String) -> bool:
	if email.is_empty() or email.length() > 254 or email.contains("\r") or email.contains("\n"):
		return false
	if email.contains(" ") or email.count("@") != 1:
		return false
	var parts := email.split("@", false, 1)
	return (
		parts.size() == 2
		and not parts[0].is_empty()
		and parts[1].contains(".")
		and not parts[1].begins_with(".")
		and not parts[1].ends_with(".")
	)
