class_name GameplayUITheme
extends RefCounted

## Shared gameplay-scope geometry/typography constants and small pure layout helpers for the
## in-level HUD, ability bar, gameplay modals (Pause, Leave Confirmation, Ability Purchase), and
## terminal result screens (Completion, Failure) -- see docs/UI_003_LEVEL_UI_CONSISTENCY_TICKET.md
## and the "Shared Gameplay UI Roles" section of docs/SCENES.md.
##
## This is the gameplay-scope equivalent of scripts/destination_screen_layout.gd: consumers preload
## this script and call its static consts/funcs by the preloaded constant, matching the project
## convention, rather than relying on the bare global class name.
##
## The level intentionally keeps its own denser, higher-contrast palette rather than reusing the
## menu system's resources (see docs/SCENES.md "Shared UI Style Tokens"), so these roles are
## separate from -- not merged into -- scripts/destination_screen_layout.gd.

## Compact/regular size variants shared by the Pause button and all four ability buttons (the "one
## gameplay HUD icon-button role" the ticket asks for). Ability bar compact/regular were already
## these sizes; Pause now matches instead of keeping its own bespoke 64px size.
const HUD_ICON_COMPACT_SIZE := Vector2(82.0, 82.0)
const HUD_ICON_REGULAR_SIZE := Vector2(96.0, 96.0)
const HUD_ICON_COMPACT_REFERENCE_WIDTH := 540.0
## Usable-width breakpoint below which HUD icon buttons (and the ability bar) switch to compact.
## Matches the ability bar's pre-existing threshold so Pause and abilities always agree.
const HUD_ICON_COMPACT_VIEWPORT_WIDTH := 620.0

## Gameplay modal shell geometry: a preferred/maximum outer-panel width, and the minimum gap kept
## clear beyond safe-area insets on every edge at every supported viewport.
const MODAL_MAX_WIDTH := 520.0
const MODAL_MIN_EDGE_GAP := 20.0
const CLOSE_BUTTON_SIZE := Vector2(72.0, 72.0)

## Modal-title regular/long typography roles (regular for short titles like "PAUSE", long for
## titles that need to fit more text in the same panel width, like "LEAVING THE LEVEL").
const MODAL_TITLE_REGULAR_SIZE := 44
const MODAL_TITLE_LONG_SIZE := 40

## Terminal-result hero title role shared by Completion and Failure, plus the responsive scale
## clamp applied to the whole result shell (matches level_completion_screen.gd's pre-existing
## scale formula so Completion's on-screen size does not change).
const RESULT_HERO_TITLE_SIZE := 58
const RESULT_TITLE_SCALE_MIN := 0.75
const RESULT_TITLE_SCALE_MAX := 1.35

## UI-002 held-scale roles (docs/SCENES.md "Shared Interaction Roles"), named here for the
## gameplay-scope call sites that use them.
const CTA_HELD_SCALE := 0.94
const ICON_HELD_SCALE := 0.97


## Returns the HUD icon-button size (Pause or an ability button) for the given *usable* width --
## callers should already have subtracted safe-area side insets, matching
## AbilityBar.apply_responsive_layout()'s contract.
static func get_hud_icon_size(usable_width: float) -> Vector2:
	if usable_width > HUD_ICON_COMPACT_VIEWPORT_WIDTH:
		return HUD_ICON_REGULAR_SIZE
	var safe_scale := clampf(usable_width / HUD_ICON_COMPACT_REFERENCE_WIDTH, 0.0, 1.0)
	return HUD_ICON_COMPACT_SIZE * safe_scale


## Clamps a modal's preferred outer-panel size so it never exceeds the safe content rect minus
## MODAL_MIN_EDGE_GAP on every side, at any supported viewport.
static func fit_outer_panel_size(preferred_size: Vector2, safe_margins: Vector4, viewport_size: Vector2) -> Vector2:
	var max_width := viewport_size.x - safe_margins.x - safe_margins.z - MODAL_MIN_EDGE_GAP * 2.0
	var max_height := viewport_size.y - safe_margins.y - safe_margins.w - MODAL_MIN_EDGE_GAP * 2.0
	return Vector2(
		minf(preferred_size.x, maxf(max_width, 1.0)),
		minf(preferred_size.y, maxf(max_height, 1.0))
	)


## Shared responsive scale for the terminal-result shell, identical to the formula
## level_completion_screen.gd already used so Completion's on-screen size is unchanged.
static func get_result_title_scale(viewport_size: Vector2) -> float:
	return clampf(minf(viewport_size.x / 720.0, viewport_size.y / 1280.0), RESULT_TITLE_SCALE_MIN, RESULT_TITLE_SCALE_MAX)


## Returns the largest font size in [minimum_size, maximum_size] whose rendered text fits within
## available_width. Numeric HUD labels use this after their responsive rect changes so assigning a
## longer value cannot silently overflow an otherwise correctly positioned badge/pill.
static func fit_label_font_size(
	label: Label,
	available_width: float,
	maximum_size: int,
	minimum_size: int = 10
) -> int:
	var font := label.get_theme_font("font")
	if font == null:
		return maximum_size

	var fitted_size := maximum_size
	var safe_width := maxf(available_width, 1.0)
	while fitted_size > minimum_size:
		var rendered_width := font.get_string_size(
			label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fitted_size
		).x
		if rendered_width <= safe_width:
			break
		fitted_size -= 1
	return fitted_size
