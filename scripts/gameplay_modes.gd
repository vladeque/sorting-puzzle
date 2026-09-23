class_name GameplayModes
extends RefCounted

## The canonical list of board behaviors a level may declare, and the one place that decides whether
## a `gameplay_mode` string is a mode at all.
##
## Each mode owns its own contract rules elsewhere -- `scripts/collapsing_column_rules.gd` and
## `scripts/throwing_dispenser_rules.gd` -- and those guards run on every level regardless of mode,
## because each one is also responsible for rejecting *its own* fields on a level that did not
## declare it. Without a shared list each guard would have to know every other mode's name to avoid
## reporting a valid level as unknown.
##
## Mirrors `GAMEPLAY_MODES` in `scripts/tools/validate_level_solvable.py`, which stays the
## authoritative validator.

const GAMEPLAY_MODE_KEY := "gameplay_mode"
const CLASSIC := "classic"
const COLLAPSING_COLUMNS := "collapsing_columns"
const THROWING_DISPENSERS := "throwing_dispensers"
const ALL := [CLASSIC, COLLAPSING_COLUMNS, THROWING_DISPENSERS]


## Levels authored before modes existed carry no key at all and are `classic`.
static func get_mode(config: Dictionary) -> String:
	return str(config.get(GAMEPLAY_MODE_KEY, CLASSIC))


static func is_known(mode) -> bool:
	return mode is String and ALL.has(mode)


## The shared "unknown mode" message, so two guards reporting the same malformed level agree.
static func describe_unknown_mode() -> String:
	return "%s must be one of %s" % [GAMEPLAY_MODE_KEY, ", ".join(ALL)]
