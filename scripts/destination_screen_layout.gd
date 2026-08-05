class_name DestinationScreenLayout
extends RefCounted

## Shared responsive-layout math for Shop/Leaderboard-style "destination" screens: safe-area-aware
## content margins capped to a maximum logical width, compact/regular title sizing, and
## bottom-navigation placement. Consumers preload this script (matching the project convention used
## by scripts/backend/backend_read_operations.gd and scripts/save/local_save_codec.gd) rather than
## relying on the global class name, and call its static funcs directly -- no instance needed.
##
## Chapter Selection reuses only get_safe_area_margins(): its full-bleed per-chapter layout is not
## a fixed-content-rect screen, so the rest of this helper does not apply there.

const CONTENT_MAX_WIDTH := 720.0
const CONTENT_SIDE_MARGIN := 16.0
const CONTENT_TOP_MARGIN := 18.0
const CONTENT_BOTTOM_GAP := 12.0
const BOTTOM_NAVIGATION_HEIGHT := 96.0
const COMPACT_VIEWPORT_HEIGHT := 1100.0
const TITLE_SIZE_REGULAR := 48
const TITLE_SIZE_COMPACT := 40


## Returns (left, top, right, bottom) safe-area insets in logical pixels, or zero outside
## Android/iOS. Identical on every platform this project targets -- extracted verbatim from the
## copy that used to be duplicated in shop_screen.gd and leaderboard_screen.gd.
static func get_safe_area_margins(viewport_size: Vector2) -> Vector4:
	if OS.get_name() not in ["Android", "iOS"]:
		return Vector4.ZERO

	var window_size := Vector2(DisplayServer.window_get_size())
	var safe_area := DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return Vector4.ZERO

	var scale := Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	var safe_end := safe_area.position + safe_area.size
	return Vector4(
		maxf(float(safe_area.position.x) * scale.x, 0.0),
		maxf(float(safe_area.position.y) * scale.y, 0.0),
		maxf(float(window_size.x - safe_end.x) * scale.x, 0.0),
		maxf(float(window_size.y - safe_end.y) * scale.y, 0.0)
	)


## Logical pixels the bottom navigation (plus its own safe-bottom inset and a small gap) reserves
## at the bottom of a destination screen's content rect.
static func get_bottom_reserved(safe_margins: Vector4) -> float:
	return BOTTOM_NAVIGATION_HEIGHT + maxf(safe_margins.w, 0.0) + CONTENT_BOTTOM_GAP


## Positions `content_margin` (a full-rect MarginContainer) inside the safe area, centered up to
## CONTENT_MAX_WIDTH, leaving `bottom_reserved` logical pixels clear at the bottom.
static func apply_content_rect(
	content_margin: Control,
	viewport_size: Vector2,
	safe_margins: Vector4,
	bottom_reserved: float
) -> void:
	var available_width := maxf(
		viewport_size.x - safe_margins.x - safe_margins.z - CONTENT_SIDE_MARGIN * 2.0,
		1.0
	)
	var content_width := minf(CONTENT_MAX_WIDTH, available_width)
	var content_left := (
		safe_margins.x
		+ (viewport_size.x - safe_margins.x - safe_margins.z - content_width) * 0.5
	)
	content_margin.offset_left = content_left
	content_margin.offset_top = safe_margins.y + CONTENT_TOP_MARGIN
	content_margin.offset_right = -(viewport_size.x - content_left - content_width)
	content_margin.offset_bottom = -bottom_reserved


static func is_compact_viewport(viewport_size: Vector2) -> bool:
	return viewport_size.y < COMPACT_VIEWPORT_HEIGHT


## Screen-title font size: TITLE_SIZE_REGULAR (48) on regular viewports, TITLE_SIZE_COMPACT (40)
## below COMPACT_VIEWPORT_HEIGHT.
static func get_title_font_size(viewport_size: Vector2) -> int:
	return TITLE_SIZE_COMPACT if is_compact_viewport(viewport_size) else TITLE_SIZE_REGULAR


## Positions `nav` (a full-width MarginContainer bottom-anchored instance of
## main_menu_bottom_navigation.tscn) above the safe-bottom inset and forwards the safe-bottom
## margin into it when supported.
static func layout_bottom_navigation(nav: Control, safe_margins: Vector4) -> void:
	if nav == null:
		return

	var safe_bottom := maxf(safe_margins.w, 0.0)
	nav.offset_top = -(BOTTOM_NAVIGATION_HEIGHT + safe_bottom)
	nav.offset_bottom = 0.0
	if nav.has_method("set_safe_bottom_margin"):
		nav.call("set_safe_bottom_margin", safe_bottom)
