#!/usr/bin/env python3
"""Validate whether a Sorting Puzzle level can be completed."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any, NamedTuple

from sticky_items import validate_sticky_items


SLOTS_PER_SHELF = 3
TRIPLE_SIZE = 3
SHELF_KIND_STANDARD = "standard"
SHELF_KIND_DISPENSER = "dispenser"
SHELF_KINDS = {SHELF_KIND_STANDARD, SHELF_KIND_DISPENSER}
DISPENSER_SLOTS_PER_SHELF = 1
DISPENSER_MIN_LAYERS = 2
DISPENSER_MAX_LAYERS = 4
DEFAULT_ITEM_CONFIG = Path("configs/item_sprites.json")
ROW_MOTION_HORIZONTAL_WRAP = "horizontal_wrap"
ROW_MOTION_VERTICAL_WRAP = "vertical_wrap"
ROW_MOTION_TYPES = {ROW_MOTION_HORIZONTAL_WRAP, ROW_MOTION_VERTICAL_WRAP}
ROW_VISUAL_VARIANTS = {"full", "floor_only"}
LAYOUT_GRID_3X3_MOVING_5_BOTTOM = "grid_3x3_moving_5_bottom"
LAYOUT_GRID_3X2_MOVING_4_BOTTOM = "grid_3x2_moving_4_bottom"
LAYOUT_GRID_3X3_MOVING_4_MIDDLE = "grid_3x3_moving_4_middle"
LAYOUT_GRID_3X2_MOVING_6_6_CENTER = "grid_3x2_moving_6_6_center"
LAYOUT_STAGGERED_COLUMNS_4_MOVING_6_4 = "staggered_columns_4_moving_6_4"
LAYOUT_STAGGERED_COLUMNS_5_MOVING_6_5 = "staggered_columns_5_moving_6_5"
LAYOUT_GRID_2X4_MOVING_6_LEFT = "grid_2x4_moving_6_left"
LAYOUT_GRID_2X4_MOVING_8_LEFT = "grid_2x4_moving_8_left"
LAYOUT_GRID_3X2_MOVING_5_BOTTOM = "grid_3x2_moving_5_bottom"
LAYOUT_GRID_1X4_MOVING_6_6_SIDES = "grid_1x4_moving_6_6_sides"
LAYOUT_SHAPE_ARCH_3X5_MOVING_6_BOTTOM = "shape_arch_3x5_moving_6_bottom"
LAYOUT_SHAPE_ALTERNATING_ALCOVES_3X5_MOVING_6_CENTER = (
    "shape_alternating_alcoves_3x5_moving_6_center"
)
LAYOUT_SHAPE_HOURGLASS_3X5_MOVING_6_WAIST = "shape_hourglass_3x5_moving_6_waist"
LAYOUT_SHAPE_SIDE_ELEVATOR_STEPS_3X5_MOVING_8_LEFT = (
    "shape_side_elevator_steps_3x5_moving_8_left"
)
ROW_LAYOUTS_KEY = "row_layouts"
LAYOUT_PRESET_KEY = "layout_preset"
GAMEPLAY_MODE_KEY = "gameplay_mode"
GAMEPLAY_MODE_CLASSIC = "classic"
GAMEPLAY_MODE_COLLAPSING_COLUMNS = "collapsing_columns"
GAMEPLAY_MODES = {GAMEPLAY_MODE_CLASSIC, GAMEPLAY_MODE_COLLAPSING_COLUMNS}
COLUMN_LAYOUT_KEY = "column_layout"
COLUMN_SHELF_COUNTS_KEY = "shelf_counts"
COLUMN_VISIBLE_SHELVES_KEY = "visible_shelves_per_column"
COLLAPSING_LAYERS_PER_SHELF = 1
# Deepest window `scripts/collapsing_shelf_column.gd` is built to draw. A level authors the
# guaranteed minimum window every device reveals; the runtime may reveal more when the fitted board
# has room, but never more than this, so an authored value above it could never be honoured.
MAX_VISIBLE_SHELVES_PER_COLUMN = 8
# Shelves every collapsing column keeps once its emptied shelves would take it lower, capped at the
# authored window so a kept shelf can never be stranded above it. They stay on the board as ordinary
# shelves, so the endgame always has room to sort instead of shrinking into a deadlock. Mirrored by
# `KEPT_SHELVES_PER_COLUMN` in `scripts/collapsing_column_rules.gd`.
KEPT_SHELVES_PER_COLUMN = 3


def moving_row(
    shelf_count: int,
    speed: float,
    direction: str,
    motion_type: str = ROW_MOTION_HORIZONTAL_WRAP,
    visible_count: int = 3,
) -> dict[str, Any]:
    """Mirrors one `ShelfLayoutRow` node of a layout template scene."""
    return {
        "shelf_count": shelf_count,
        "visible_count": visible_count,
        "motion": {
            "type": motion_type,
            "speed": speed,
            "direction": direction,
        },
        "visual_variant": "floor_only",
    }


# Preset-defined moving rows, mirrored from the `ShelfLayoutRow` nodes in
# `scenes/layouts/layout_<preset>.tscn`. Entries are in shelf order, so a preset whose belt sits
# between static rows lists the static rows before and after it. Presets without a moving row need no
# entry: `get_effective_row_layouts` only uses this table to recover moving-row metadata.
LAYOUT_PRESET_ROW_LAYOUTS: dict[str, list[dict[str, Any]]] = {
    LAYOUT_GRID_2X4_MOVING_8_LEFT: [
        moving_row(8, 60, "down", motion_type=ROW_MOTION_VERTICAL_WRAP, visible_count=4),
        {"shelf_count": 8},
    ],
    LAYOUT_GRID_3X2_MOVING_5_BOTTOM: [
        {"shelf_count": 3}, {"shelf_count": 3}, moving_row(5, 60, "right"),
    ],
    LAYOUT_GRID_3X3_MOVING_5_BOTTOM: [
        {"shelf_count": 3},
        {"shelf_count": 3},
        {"shelf_count": 3},
        moving_row(5, 70, "right"),
    ],
    LAYOUT_GRID_3X2_MOVING_4_BOTTOM: [
        {"shelf_count": 3},
        {"shelf_count": 3},
        moving_row(4, 45, "right"),
    ],
    LAYOUT_GRID_3X3_MOVING_4_MIDDLE: [
        {"shelf_count": 3},
        moving_row(4, 60, "right"),
        {"shelf_count": 3},
        {"shelf_count": 3},
    ],
    LAYOUT_GRID_3X2_MOVING_6_6_CENTER: [
        {"shelf_count": 3},
        moving_row(6, 60, "right"),
        moving_row(6, 60, "left"),
        {"shelf_count": 3},
    ],
    # Columns, not rows: the two static entries are the left and right columns of four shelves and
    # the moving entry is the vertical belt between them. Only the shelf-order grouping and the
    # motion metadata matter here; the validator does not model shelf geometry.
    LAYOUT_STAGGERED_COLUMNS_4_MOVING_6_4: [
        {"shelf_count": 4},
        moving_row(6, 55, "down", motion_type=ROW_MOTION_VERTICAL_WRAP),
        {"shelf_count": 4},
    ],
    LAYOUT_STAGGERED_COLUMNS_5_MOVING_6_5: [
        {"shelf_count": 5},
        moving_row(6, 55, "down", motion_type=ROW_MOTION_VERTICAL_WRAP, visible_count=4),
        {"shelf_count": 5},
    ],
    LAYOUT_GRID_2X4_MOVING_6_LEFT: [
        moving_row(6, 55, "down", motion_type=ROW_MOTION_VERTICAL_WRAP, visible_count=4),
        {"shelf_count": 8},
    ],
    LAYOUT_GRID_1X4_MOVING_6_6_SIDES: [
        moving_row(6, 55, "down", motion_type=ROW_MOTION_VERTICAL_WRAP, visible_count=4),
        moving_row(6, 55, "up", motion_type=ROW_MOTION_VERTICAL_WRAP, visible_count=4),
        {"shelf_count": 4},
    ],
    LAYOUT_SHAPE_ARCH_3X5_MOVING_6_BOTTOM: [
        {"shelf_count": 9},
        moving_row(6, 60, "left"),
    ],
    LAYOUT_SHAPE_ALTERNATING_ALCOVES_3X5_MOVING_6_CENTER: [
        moving_row(6, 60, "down", motion_type=ROW_MOTION_VERTICAL_WRAP, visible_count=4),
        {"shelf_count": 5},
    ],
    LAYOUT_SHAPE_HOURGLASS_3X5_MOVING_6_WAIST: [
        {"shelf_count": 3},
        {"shelf_count": 1},
        moving_row(6, 60, "right"),
        {"shelf_count": 1},
        {"shelf_count": 3},
    ],
    LAYOUT_SHAPE_SIDE_ELEVATOR_STEPS_3X5_MOVING_8_LEFT: [
        moving_row(8, 60, "down", motion_type=ROW_MOTION_VERTICAL_WRAP, visible_count=4),
        {"shelf_count": 7},
    ],
}

Item = str | None
Layer = tuple[Item, ...]


class ShelfState(NamedTuple):
    unlock_after_triples: int
    layers: tuple[Layer, ...]
    kind: str = SHELF_KIND_STANDARD
    sticky_items: tuple[tuple[int, int], ...] = ()

    @property
    def slot_count(self) -> int:
        return slots_for_kind(self.kind)

    @property
    def accepts_dropped_items(self) -> bool:
        return self.kind != SHELF_KIND_DISPENSER

    @property
    def forms_triples(self) -> bool:
        return self.kind != SHELF_KIND_DISPENSER


def shelf_kind(shelf: dict[str, Any]) -> str:
    kind = shelf.get("type", SHELF_KIND_STANDARD)
    return kind if kind in SHELF_KINDS else SHELF_KIND_STANDARD


def slots_for_kind(kind: str) -> int:
    return DISPENSER_SLOTS_PER_SHELF if kind == SHELF_KIND_DISPENSER else SLOTS_PER_SHELF


State = tuple[int, tuple[ShelfState, ...]]


class Move(NamedTuple):
    item_id: str
    from_shelf: int
    from_slot: int
    to_shelf: int
    to_slot: int


class SearchResult(NamedTuple):
    solvable: bool | None
    reason: str
    moves: int | None
    states_checked: int
    max_queue_size: int
    solution: list[Move]


def load_item_ids(item_config_path: Path) -> set[str]:
    with item_config_path.open("r", encoding="utf-8") as config_file:
        config = json.load(config_file)

    return {
        item["id"]
        for item in config.get("items", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }


def load_level_data(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as level_file:
        return json.load(level_file)


def load_shelves(path: Path, shelves_only: bool) -> list[dict[str, Any]]:
    data = load_level_data(path)

    if shelves_only:
        if not isinstance(data, list):
            raise ValueError("--shelves-only expects a JSON array")
        return data

    if isinstance(data, dict) and isinstance(data.get("shelves"), list):
        return data["shelves"]
    if isinstance(data, list):
        return data

    raise ValueError("Expected a level JSON object with 'shelves' or a shelves array")


def get_gameplay_mode(level_data: Any) -> Any:
    """Raw `gameplay_mode` value, defaulting to classic. Validation decides whether it is legal."""
    if not isinstance(level_data, dict):
        return GAMEPLAY_MODE_CLASSIC

    return level_data.get(GAMEPLAY_MODE_KEY, GAMEPLAY_MODE_CLASSIC)


## Fails closed on purpose. An unrecognized mode or a malformed column contract is a content error,
## never a reason to fall back to a classic board: the same shelves array means something different
## under each mode, so a silent fallback would accept an invalid level and change its rules.
def validate_gameplay_mode_shape(level_data: Any, shelves: list[dict[str, Any]]) -> list[str]:
    if not isinstance(level_data, dict):
        return []

    mode = level_data.get(GAMEPLAY_MODE_KEY, GAMEPLAY_MODE_CLASSIC)
    if mode not in GAMEPLAY_MODES:
        return [f"{GAMEPLAY_MODE_KEY} must be one of {sorted(GAMEPLAY_MODES)}"]

    if mode == GAMEPLAY_MODE_CLASSIC:
        if COLUMN_LAYOUT_KEY in level_data:
            return [
                f"{COLUMN_LAYOUT_KEY} is only valid when {GAMEPLAY_MODE_KEY} is "
                f"'{GAMEPLAY_MODE_COLLAPSING_COLUMNS}'"
            ]
        return []

    return validate_column_layout_shape(level_data, shelves)


def validate_column_layout_shape(level_data: dict[str, Any], shelves: list[dict[str, Any]]) -> list[str]:
    errors = []
    for exclusive_key in (LAYOUT_PRESET_KEY, ROW_LAYOUTS_KEY):
        if exclusive_key in level_data:
            errors.append(
                f"{exclusive_key} cannot be combined with {GAMEPLAY_MODE_KEY} "
                f"'{GAMEPLAY_MODE_COLLAPSING_COLUMNS}'"
            )

    column_layout = level_data.get(COLUMN_LAYOUT_KEY)
    if not isinstance(column_layout, dict):
        errors.append(
            f"{COLUMN_LAYOUT_KEY} must be an object when {GAMEPLAY_MODE_KEY} is "
            f"'{GAMEPLAY_MODE_COLLAPSING_COLUMNS}'"
        )
        return errors

    shelf_counts = column_layout.get(COLUMN_SHELF_COUNTS_KEY)
    if not isinstance(shelf_counts, list) or not shelf_counts:
        errors.append(
            f"{COLUMN_LAYOUT_KEY}.{COLUMN_SHELF_COUNTS_KEY} must be a non-empty array of "
            "positive integers"
        )
    else:
        total_shelf_count = 0
        counts_are_valid = True
        for column_index, shelf_count in enumerate(shelf_counts):
            if type(shelf_count) is not int or shelf_count <= 0:
                errors.append(
                    f"{COLUMN_LAYOUT_KEY}.{COLUMN_SHELF_COUNTS_KEY}[{column_index}] must be a "
                    "positive integer"
                )
                counts_are_valid = False
                continue

            total_shelf_count += shelf_count

        if counts_are_valid and total_shelf_count != len(shelves):
            errors.append(
                f"{COLUMN_LAYOUT_KEY}.{COLUMN_SHELF_COUNTS_KEY} total is {total_shelf_count}, "
                f"expected {len(shelves)} shelves"
            )

    visible_count = column_layout.get(COLUMN_VISIBLE_SHELVES_KEY)
    if (
        type(visible_count) is not int
        or visible_count <= 0
        or visible_count > MAX_VISIBLE_SHELVES_PER_COLUMN
    ):
        errors.append(
            f"{COLUMN_LAYOUT_KEY}.{COLUMN_VISIBLE_SHELVES_KEY} must be a positive integer no "
            f"greater than {MAX_VISIBLE_SHELVES_PER_COLUMN}"
        )

    errors.extend(validate_collapsing_shelf_contract(shelves))
    return errors


## First-version content restrictions. Each rejected feature needs its own compatibility task with
## solver fixtures before content may use it; removing a rejection here without that work would let
## an unproven board ship.
def validate_collapsing_shelf_contract(shelves: list[dict[str, Any]]) -> list[str]:
    errors = []
    for shelf_index, shelf in enumerate(shelves):
        if not isinstance(shelf, dict):
            # Already reported by validate_shelves_shape.
            continue

        shelf_number = shelf_index + 1
        if shelf.get("type", SHELF_KIND_STANDARD) != SHELF_KIND_STANDARD:
            errors.append(
                f"shelf {shelf_number} must be a standard shelf in {GAMEPLAY_MODE_KEY} "
                f"'{GAMEPLAY_MODE_COLLAPSING_COLUMNS}'"
            )

        unlock_after_triples = shelf.get("unlock_after_triples", 0)
        if type(unlock_after_triples) is int and unlock_after_triples > 0:
            errors.append(
                f"shelf {shelf_number} is locked; locked shelves are not supported in "
                f"{GAMEPLAY_MODE_KEY} '{GAMEPLAY_MODE_COLLAPSING_COLUMNS}'"
            )

        sticky_items = shelf.get("sticky_items")
        if isinstance(sticky_items, list) and sticky_items:
            errors.append(
                f"shelf {shelf_number} has sticky items; sticky items are not supported in "
                f"{GAMEPLAY_MODE_KEY} '{GAMEPLAY_MODE_COLLAPSING_COLUMNS}'"
            )

        layers = shelf.get("layers")
        if not isinstance(layers, list) or not layers:
            # Already reported by validate_shelves_shape.
            continue

        if len(layers) != COLLAPSING_LAYERS_PER_SHELF:
            errors.append(
                f"shelf {shelf_number} has {len(layers)} layers, expected exactly "
                f"{COLLAPSING_LAYERS_PER_SHELF} in {GAMEPLAY_MODE_KEY} "
                f"'{GAMEPLAY_MODE_COLLAPSING_COLUMNS}'"
            )
            continue

        layer = layers[0]
        if not isinstance(layer, list) or len(layer) != SLOTS_PER_SHELF:
            # Already reported by validate_shelves_shape.
            continue

        # An authored shelf with no items would be destroyed before the player could touch it, so it
        # is a content mistake rather than a zero-cost head start.
        if all(item_id is None for item_id in layer):
            errors.append(
                f"shelf {shelf_number} is empty; an authored collapsing shelf must contain at "
                "least one item"
            )

    return errors


def validate_row_layouts_shape(level_data: Any, shelves: list[dict[str, Any]]) -> list[str]:
    if not isinstance(level_data, dict):
        return []

    row_layouts = get_effective_row_layouts(level_data)
    if row_layouts is None:
        return []

    if not isinstance(row_layouts, list) or not row_layouts:
        return ["row_layouts must be a non-empty array when present"]

    errors = []
    total_shelf_count = 0
    moving_motion_type = None
    for row_index, row_layout in enumerate(row_layouts):
        row_number = row_index + 1
        if not isinstance(row_layout, dict):
            errors.append(f"row_layouts[{row_index}] must be an object")
            continue

        shelf_count = row_layout.get("shelf_count")
        if type(shelf_count) is not int or shelf_count <= 0:
            errors.append(f"row_layouts[{row_index}].shelf_count must be a positive integer")
            continue

        visible_count = row_layout.get("visible_count")
        if visible_count is not None and (
            type(visible_count) is not int or visible_count <= 0 or visible_count > shelf_count
        ):
            errors.append(
                f"row_layouts[{row_index}].visible_count must be a positive integer no greater than shelf_count"
            )

        visual_variant = row_layout.get("visual_variant")
        if visual_variant is not None and visual_variant not in ROW_VISUAL_VARIANTS:
            errors.append(
                f"row_layouts[{row_index}].visual_variant must be one of {sorted(ROW_VISUAL_VARIANTS)}"
            )

        moving = row_layout.get("moving")
        if moving is not None and type(moving) is not bool:
            errors.append(f"row_layouts[{row_index}].moving must be a boolean")

        motion_errors = validate_row_motion_shape(row_layout, row_index)
        errors.extend(motion_errors)

        is_moving = row_layout_is_moving(row_layout)
        if is_moving:
            row_motion_type = get_row_motion_type(row_layout)
            if row_motion_type in ROW_MOTION_TYPES:
                if moving_motion_type is not None and row_motion_type != moving_motion_type:
                    errors.append(
                        "moving rows must use only one motion.type per level; "
                        f"found '{moving_motion_type}' and '{row_motion_type}'"
                    )
                moving_motion_type = row_motion_type

            row_start = total_shelf_count
            row_end = row_start + shelf_count
            for shelf_index in range(row_start, min(row_end, len(shelves))):
                shelf = shelves[shelf_index]
                unlock_after_triples = shelf.get("unlock_after_triples", 0) if isinstance(shelf, dict) else 0
                if type(unlock_after_triples) is int and unlock_after_triples > 0:
                    errors.append(f"shelf {shelf_index + 1} is locked, but row {row_number} is moving")

        total_shelf_count += shelf_count

    if total_shelf_count != len(shelves):
        errors.append(f"row_layouts shelf_count total is {total_shelf_count}, expected {len(shelves)} shelves")

    return errors


def get_effective_row_layouts(level_data: dict[str, Any]) -> Any:
    if "row_layouts" in level_data:
        return level_data.get("row_layouts")

    layout_preset = level_data.get("layout_preset")
    if isinstance(layout_preset, str):
        return LAYOUT_PRESET_ROW_LAYOUTS.get(layout_preset)

    return None


def validate_row_motion_shape(row_layout: dict[str, Any], row_index: int) -> list[str]:
    errors = []
    motion = row_layout.get("motion")
    if motion is not None and not isinstance(motion, dict):
        return [f"row_layouts[{row_index}].motion must be an object"]

    motion_config = motion if isinstance(motion, dict) else {}
    motion_type = motion_config.get("type")
    if motion_type is not None and motion_type not in ROW_MOTION_TYPES:
        errors.append(f"row_layouts[{row_index}].motion.type must be one of {sorted(ROW_MOTION_TYPES)}")

    direction = motion_config.get("direction", row_layout.get("direction"))
    if direction is not None:
        row_motion_type = get_row_motion_type(row_layout)
        allowed_directions = {"up", "down"} if row_motion_type == ROW_MOTION_VERTICAL_WRAP else {"left", "right"}
        if direction not in allowed_directions:
            errors.append(
                f"row_layouts[{row_index}] direction must be one of {sorted(allowed_directions)}"
            )

    for field_path, value in (
        ("speed", row_layout.get("speed")),
        ("motion.speed", motion_config.get("speed")),
    ):
        if value is None:
            continue
        if type(value) not in (int, float) or value < 0:
            errors.append(f"row_layouts[{row_index}].{field_path} must be a non-negative number")

    return errors


def row_layout_is_moving(row_layout: dict[str, Any]) -> bool:
    motion = row_layout.get("motion")
    motion_config = motion if isinstance(motion, dict) else {}
    if motion_config.get("type") in ROW_MOTION_TYPES:
        return True
    if row_layout.get("moving") is True:
        return True

    speed = motion_config.get("speed", row_layout.get("speed", 0))
    return type(speed) in (int, float) and speed > 0


def get_row_motion_type(row_layout: dict[str, Any]) -> str | None:
    motion = row_layout.get("motion")
    motion_config = motion if isinstance(motion, dict) else {}
    motion_type = motion_config.get("type", ROW_MOTION_HORIZONTAL_WRAP)
    return motion_type if motion_type in ROW_MOTION_TYPES else None


def validate_shelves_shape(
    shelves: list[dict[str, Any]],
    known_item_ids: set[str],
    skip_known_items: bool,
) -> tuple[list[str], Counter[str]]:
    errors = []
    item_counts: Counter[str] = Counter()

    if not shelves:
        errors.append("level must contain at least one shelf")

    for shelf_index, shelf in enumerate(shelves):
        if not isinstance(shelf, dict):
            errors.append(f"shelf {shelf_index + 1} must be an object")
            continue

        errors.extend(f"shelf {shelf_index + 1}: {error}" for error in validate_sticky_items(shelf))

        unlock_after_triples = shelf.get("unlock_after_triples", 0)
        if type(unlock_after_triples) is not int or unlock_after_triples < 0:
            errors.append(f"shelf {shelf_index + 1} unlock_after_triples must be a non-negative integer")

        raw_kind = shelf.get("type", SHELF_KIND_STANDARD)
        if raw_kind not in SHELF_KINDS:
            errors.append(
                f"shelf {shelf_index + 1} type must be one of {sorted(SHELF_KINDS)}"
            )
        kind = shelf_kind(shelf)
        slot_count = slots_for_kind(kind)
        is_dispenser = kind == SHELF_KIND_DISPENSER

        layers = shelf.get("layers")
        if not isinstance(layers, list) or not layers:
            errors.append(f"shelf {shelf_index + 1} must contain a non-empty layers array")
            continue

        # A dispenser holds one item per layer and the player can only take from it, so its layer
        # count is exactly how many items it will ever hand out.
        if is_dispenser and not DISPENSER_MIN_LAYERS <= len(layers) <= DISPENSER_MAX_LAYERS:
            errors.append(
                f"shelf {shelf_index + 1} is a dispenser with {len(layers)} layers, expected "
                f"{DISPENSER_MIN_LAYERS} to {DISPENSER_MAX_LAYERS}"
            )

        for layer_index, layer in enumerate(layers):
            if not isinstance(layer, list):
                errors.append(f"shelf {shelf_index + 1} layer {layer_index + 1} must be an array")
                continue
            if len(layer) != slot_count:
                errors.append(
                    f"shelf {shelf_index + 1} layer {layer_index + 1} must contain {slot_count} slots"
                )
                continue

            for slot_index, item_id in enumerate(layer):
                if item_id is None:
                    # A hole in a dispenser's queue has no meaning: there is nothing to move into
                    # it and nothing for it to hand out.
                    if is_dispenser:
                        errors.append(
                            f"shelf {shelf_index + 1} layer {layer_index + 1} is a dispenser layer "
                            "and must contain an item ID, not null"
                        )
                    continue
                if not isinstance(item_id, str) or not item_id:
                    errors.append(
                        f"shelf {shelf_index + 1} layer {layer_index + 1} slot {slot_index + 1} "
                        "must be an item ID string or null"
                    )
                    continue
                if not skip_known_items and item_id not in known_item_ids:
                    errors.append(f"unknown item ID '{item_id}'")

                item_counts[item_id] += 1

    for item_id, count in sorted(item_counts.items()):
        if count % TRIPLE_SIZE != 0:
            errors.append(f"item '{item_id}' appears {count} times, expected a multiple of {TRIPLE_SIZE}")

    return errors, item_counts


def shelves_to_state(shelves: list[dict[str, Any]]) -> State:
    state_shelves = []
    for shelf in shelves:
        layers = []
        for layer in shelf["layers"]:
            layers.append(tuple(layer))
        state_shelves.append(
            ShelfState(
                unlock_after_triples=max(0, int(shelf.get("unlock_after_triples", 0))),
                layers=tuple(layers),
                kind=shelf_kind(shelf),
                sticky_items=tuple(sorted((entry["layer"], entry["slot"])
                                          for entry in shelf.get("sticky_items", []))),
            )
        )

    return (0, tuple(state_shelves))


def slot_sort_key(item: Item) -> tuple[int, str]:
    return (1, "") if item is None else (0, item)


def shelf_sort_key(shelf: ShelfState) -> tuple:
    return (
        shelf.kind,
        shelf.unlock_after_triples,
        tuple(tuple(slot_sort_key(item) for item in layer) for layer in shelf.layers),
        shelf.sticky_items,
    )


## Slot order inside one layer carries no meaning, so two boards that differ only by it are the same
## position. Which shelf is which does carry meaning in collapsing columns, so shelf-level ordering
## stays with the mode that owns it rather than living here.
def canonicalize_shelf(shelf: ShelfState) -> ShelfState:
    ## Without a sticky anchor the order is decided by `slot_sort_key` alone, which puts the items
    ## first and the empty slots last. Sorting the items directly reaches that same layout without
    ## a keyed sort over slot indices, and the search canonicalizes every state it generates, so
    ## this path carries most of a solvability run.
    if not shelf.sticky_items:
        canonical_layers = []
        for layer in shelf.layers:
            items: list[Item] = sorted(item for item in layer if item is not None)
            items.extend([None] * (len(layer) - len(items)))
            canonical_layers.append(tuple(items))

        return shelf._replace(layers=tuple(canonical_layers))

    canonical_layers = []
    sticky_items = []
    for layer_index, layer in enumerate(shelf.layers):
        order = sorted(range(len(layer)), key=lambda slot: (
            slot_sort_key(layer[slot]), (layer_index, slot) in shelf.sticky_items))
        canonical_layers.append(tuple(layer[slot] for slot in order))
        sticky_items.extend((layer_index, new_slot) for new_slot, old_slot in enumerate(order)
                            if (layer_index, old_slot) in shelf.sticky_items)

    return ShelfState(
        unlock_after_triples=shelf.unlock_after_triples,
        layers=tuple(canonical_layers),
        kind=shelf.kind,
        sticky_items=tuple(sticky_items),
    )


def canonicalize_state(state: State) -> State:
    triples_cleared, shelves = state
    canonical_shelves = [canonicalize_shelf(shelf) for shelf in shelves]

    return (triples_cleared, tuple(sorted(canonical_shelves, key=shelf_sort_key)))


def is_empty_layer(layer: Layer) -> bool:
    return all(item is None for item in layer)


## A dispenser's layer is one slot wide, so the "every slot holds the same item" test is trivially
## true for it. Without the shelf-kind gate every dispenser would clear itself on sight and hand out
## free triples, and the search would call unsolvable levels solvable.
def is_matching_layer(shelf: ShelfState, layer: Layer) -> bool:
    if not shelf.forms_triples or len(layer) != TRIPLE_SIZE:
        return False

    first = layer[0]
    return first is not None and all(item == first for item in layer)


def is_shelf_unlocked(shelf: ShelfState, triples_cleared: int) -> bool:
    return shelf.unlock_after_triples <= triples_cleared


def settle_state(state: State) -> State:
    triples_cleared, state_shelves = state
    ## Most moves the search tries settle nothing, and a shelf that cannot settle now cannot be
    ## reached by a cascade either: only a cleared triple raises `triples_cleared`, and nothing
    ## clears if nothing settles. Recognizing that leaves the state untouched instead of rebuilding
    ## every shelf to arrive back at the same board.
    if not any(
        shelf.layers
        and is_shelf_unlocked(shelf, triples_cleared)
        and (is_empty_layer(shelf.layers[0]) or is_matching_layer(shelf, shelf.layers[0]))
        for shelf in state_shelves
    ):
        return state

    shelves = [list(shelf.layers) for shelf in state_shelves]
    changed = True

    while changed:
        changed = False
        for shelf_index, shelf in enumerate(shelves):
            shelf_state = state_shelves[shelf_index]
            while shelf and is_shelf_unlocked(shelf_state, triples_cleared) and (
                is_empty_layer(shelf[0]) or is_matching_layer(shelf_state, shelf[0])
            ):
                if is_matching_layer(shelf_state, shelf[0]):
                    triples_cleared += 1
                shelf.pop(0)
                changed = True

            shelves[shelf_index] = shelf

    settled_shelves = []
    for shelf_index, layers in enumerate(shelves):
        settled_shelves.append(
            ShelfState(
                unlock_after_triples=state_shelves[shelf_index].unlock_after_triples,
                layers=tuple(layers),
                kind=state_shelves[shelf_index].kind,
                sticky_items=tuple((layer - (len(state_shelves[shelf_index].layers) - len(layers)), slot)
                                   for layer, slot in state_shelves[shelf_index].sticky_items
                                   if layer >= len(state_shelves[shelf_index].layers) - len(layers)),
            )
        )

    return (triples_cleared, tuple(settled_shelves))


def normalize_state(state: State) -> State:
    return canonicalize_state(settle_state(state))


def is_cleared(state: State) -> bool:
    return all(len(shelf.layers) == 0 for shelf in state[1])


def visible_layer(shelf: ShelfState) -> Layer:
    if not shelf.layers:
        return (None,) * shelf.slot_count

    return shelf.layers[0]


def legal_moves(state: State) -> list[Move]:
    sources = []
    targets = []
    triples_cleared, shelves = state

    for shelf_index, shelf in enumerate(shelves):
        if not is_shelf_unlocked(shelf, triples_cleared):
            continue

        front = visible_layer(shelf)
        for slot_index, item_id in enumerate(front):
            if item_id is None:
                # A source-only shelf never offers its empty slot as somewhere to put an item.
                if shelf.accepts_dropped_items:
                    targets.append((shelf_index, slot_index))
            elif (0, slot_index) not in shelf.sticky_items:
                sources.append((shelf_index, slot_index, item_id))

    moves = []
    for from_shelf, from_slot, item_id in sources:
        for to_shelf, to_slot in targets:
            if from_shelf == to_shelf:
                continue

            moves.append(Move(item_id, from_shelf, from_slot, to_shelf, to_slot))

    moves.sort(key=lambda move: move_score(state, move), reverse=True)
    return moves


## Move ordering only, never legality: the search still explores every move, this decides which it
## looks at first. Shared by both modes because it reads two shelves, not a board shape.
def score_move(source: ShelfState, target: ShelfState, item_id: str) -> int:
    target_front = visible_layer(target)
    target_same_count = sum(1 for slot_item in target_front if slot_item == item_id)
    target_empty_count = sum(1 for slot_item in target_front if slot_item is None)
    source_front = visible_layer(source)
    source_remaining_count = sum(1 for slot_item in source_front if slot_item == item_id) - 1

    score = target_same_count * 10
    if target_same_count == 2 and target_empty_count == 1:
        score += 100
    if source_remaining_count == 0:
        score += 3
    return score


def move_score(state: State, move: Move) -> int:
    shelves = state[1]
    return score_move(shelves[move.from_shelf], shelves[move.to_shelf], move.item_id)


def apply_move(state: State, move: Move) -> State:
    triples_cleared, state_shelves = state
    if not (0 <= move.from_shelf < len(state_shelves) and 0 <= move.to_shelf < len(state_shelves)):
        raise ValueError("move shelf out of range")
    source, target = state_shelves[move.from_shelf], state_shelves[move.to_shelf]
    if (move.from_shelf == move.to_shelf
            or not 0 <= move.from_slot < source.slot_count
            or not 0 <= move.to_slot < target.slot_count
            or not is_shelf_unlocked(source, triples_cleared)
            or not is_shelf_unlocked(target, triples_cleared)
            or not target.accepts_dropped_items
            or (0, move.from_slot) in source.sticky_items
            or not move.item_id
            or visible_layer(source)[move.from_slot] != move.item_id
            or visible_layer(target)[move.to_slot] is not None):
        raise ValueError("illegal move (source, sticky item, target, or lock)")
    ## A move rewrites one slot on each of two shelves, so only those two are rebuilt. The checks
    ## above already rejected `from_shelf == to_shelf`, which is what makes the two edits
    ## independent.
    moved_shelves = list(state_shelves)

    source_front = source.layers[0]
    moved_shelves[move.from_shelf] = source._replace(
        layers=((*source_front[:move.from_slot], None, *source_front[move.from_slot + 1:]),
                *source.layers[1:]),
    )

    ## A shelf emptied earlier has no layer left to drop onto, so it grows one back.
    target_layers = target.layers or ((None,) * target.slot_count,)
    target_front = target_layers[0]
    moved_shelves[move.to_shelf] = target._replace(
        layers=((*target_front[:move.to_slot], move.item_id, *target_front[move.to_slot + 1:]),
                *target_layers[1:]),
    )

    return (triples_cleared, tuple(moved_shelves))


class ColumnShelf(NamedTuple):
    """One surviving shelf in a collapsing column, tagged with the authored ID that never changes.

    Stack position moves as shelves below it are destroyed; `shelf_id` does not, so a reported
    solution stays replayable against the authored board.
    """

    shelf_id: int
    state: ShelfState


# Surviving shelves per column, bottom-to-top, in authored column order.
CollapsingState = tuple[int, tuple[tuple[ColumnShelf, ...], ...]]


def replace_front_slot(shelf: ShelfState, slot_index: int, item_id: Item) -> ShelfState:
    front = list(shelf.layers[0])
    front[slot_index] = item_id
    return shelf._replace(layers=(tuple(front),) + shelf.layers[1:])


## One rules object per gameplay mode, rather than `if collapsing` branches through every helper.
## The search drives only this interface, so a mode owns its own settle, reachability, move
## addressing, and terminal condition.
class SortingRules:
    mode = GAMEPLAY_MODE_CLASSIC

    def iter_shelf_states(self, state) -> list[ShelfState]:
        raise NotImplementedError

    def settle(self, state):
        raise NotImplementedError

    def canonicalize(self, state):
        raise NotImplementedError

    def legal_moves(self, state) -> list[Move]:
        raise NotImplementedError

    def apply_move(self, state, move: Move):
        raise NotImplementedError

    def is_cleared(self, state) -> bool:
        raise NotImplementedError

    ## A sticky item never leaves its slot, so its own shelf has to complete the triple around it.
    ## More sticky copies of an item than the board has triples of it is decidable up front, in both
    ## modes, without spending any search budget.
    def preflight(self, state) -> SearchResult | None:
        shelves = self.iter_shelf_states(state)
        counts = Counter(item for shelf in shelves for layer in shelf.layers for item in layer if item)
        sticky_counts = Counter(shelf.layers[layer][slot] for shelf in shelves
                                for layer, slot in shelf.sticky_items)
        if any(count * TRIPLE_SIZE > counts[item] for item, count in sticky_counts.items()):
            return SearchResult(False, "sticky_copy_limit", None, 1, 1, [])

        return None


class ClassicRules(SortingRules):
    """Shelves persist for the whole level and an emptied shelf stays a reusable destination."""

    mode = GAMEPLAY_MODE_CLASSIC

    def iter_shelf_states(self, state: State) -> list[ShelfState]:
        return list(state[1])

    def settle(self, state: State) -> State:
        return settle_state(state)

    def canonicalize(self, state: State) -> State:
        return canonicalize_state(state)

    def legal_moves(self, state: State) -> list[Move]:
        return legal_moves(state)

    def apply_move(self, state: State, move: Move) -> State:
        return apply_move(state, move)

    def is_cleared(self, state: State) -> bool:
        return is_cleared(state)


class CollapsingColumnsRules(SortingRules):
    """Columns of one-layer shelves. An emptied shelf is destroyed and the shelves above it fall,
    until its column is down to `kept_count` shelves; from then on emptied shelves stay as ordinary
    empty shelves. The level is cleared once no item is left.

    `visible_count` is the authored guaranteed minimum window, not a device measurement. The runtime
    may reveal more shelves per column when the fitted board has room, and proving the minimum also
    proves those larger windows: every move legal in a smaller window stays legal in a larger one,
    and the only extra forced event a larger window can trigger is an automatic triple clear, which
    only removes items. Whether the shelf it empties is then destroyed depends only on how many
    shelves its column has left, so both windows hold the same shelf contents afterwards; at most
    they keep a different empty shelf.

    `kept_shelves_per_column` defaults to the shipped rule. Tests pass 0 to exercise destruction on
    fixtures too small for the floor.
    """

    mode = GAMEPLAY_MODE_COLLAPSING_COLUMNS

    def __init__(self, visible_count: int, kept_shelves_per_column: int | None = None) -> None:
        self.visible_count = max(1, int(visible_count))
        requested = KEPT_SHELVES_PER_COLUMN if kept_shelves_per_column is None else kept_shelves_per_column
        self.kept_count = max(0, min(int(requested), self.visible_count))

    def iter_shelf_states(self, state: CollapsingState) -> list[ShelfState]:
        return [entry.state for column in state[1] for entry in column]

    def active_entries(self, state: CollapsingState) -> list[ColumnShelf]:
        """Every shelf currently inside a column's visible window, bottom-to-top."""
        return [entry for column in state[1] for entry in column[: self.visible_count]]

    def remaining_shelf_count(self, state: CollapsingState) -> int:
        return sum(len(column) for column in state[1])

    ## Clearing and destroying reveal the next shelf, which can itself be an authored triple, so this
    ## repeats until nothing changes. A shelf outside the window is never touched: offscreen content
    ## must not resolve before the player can see it. The scan runs bottom to top, so when a column
    ## may lose only some of its emptied shelves, the lowest go first -- the order
    ## `CollapsingShelfColumn.get_removable_shelves()` uses at runtime.
    def settle(self, state: CollapsingState) -> CollapsingState:
        triples_cleared, columns = state
        working = [list(column) for column in columns]
        changed = True
        while changed:
            changed = False
            for column_index, column in enumerate(working):
                survivors: list[ColumnShelf] = []
                for stack_index, entry in enumerate(column):
                    shelf = entry.state
                    if stack_index >= self.visible_count or not is_shelf_unlocked(shelf, triples_cleared):
                        survivors.append(entry)
                        continue

                    front = visible_layer(shelf)
                    if is_matching_layer(shelf, front):
                        triples_cleared += 1
                        changed = True
                        entry = ColumnShelf(entry.shelf_id, shelf._replace(layers=((None,) * shelf.slot_count,)))
                    elif not is_empty_layer(front):
                        survivors.append(entry)
                        continue

                    # Empty now. Destroying it must leave the column at least `kept_count` tall.
                    shelves_left_without_it = len(survivors) + len(column) - stack_index - 1
                    if shelves_left_without_it < self.kept_count:
                        survivors.append(entry)
                        continue

                    changed = True

                working[column_index] = survivors

        return (triples_cleared, tuple(tuple(column) for column in working))

    ## Column membership and bottom-to-top order are part of the position, so only slot order inside
    ## one shelf is normalized here. Authored IDs are labels rather than state and are dropped, which
    ## lets two boards that differ only in labelling share a visited entry.
    def canonicalize(self, state: CollapsingState):
        triples_cleared, columns = state
        return (
            triples_cleared,
            tuple(tuple(canonicalize_shelf(entry.state) for entry in column) for column in columns),
        )

    def legal_moves(self, state: CollapsingState) -> list[Move]:
        triples_cleared = state[0]
        active_states: dict[int, ShelfState] = {}
        sources: list[tuple[int, int, str]] = []
        targets: list[tuple[int, int]] = []

        for entry in self.active_entries(state):
            shelf = entry.state
            active_states[entry.shelf_id] = shelf
            if not is_shelf_unlocked(shelf, triples_cleared):
                continue

            for slot_index, item_id in enumerate(visible_layer(shelf)):
                if item_id is None:
                    if shelf.accepts_dropped_items:
                        targets.append((entry.shelf_id, slot_index))
                elif (0, slot_index) not in shelf.sticky_items:
                    sources.append((entry.shelf_id, slot_index, item_id))

        moves = []
        for from_shelf, from_slot, item_id in sources:
            for to_shelf, to_slot in targets:
                if from_shelf == to_shelf:
                    continue

                moves.append(Move(item_id, from_shelf, from_slot, to_shelf, to_slot))

        moves.sort(
            key=lambda move: score_move(
                active_states[move.from_shelf], active_states[move.to_shelf], move.item_id
            ),
            reverse=True,
        )
        return moves

    ## Moves address shelves by authored ID, so a coordinate stays valid after earlier shelves have
    ## been destroyed. Resolving that ID through the visible window is also what makes a move against
    ## a hidden or already-destroyed shelf impossible to apply.
    def apply_move(self, state: CollapsingState, move: Move) -> CollapsingState:
        triples_cleared, columns = state
        source_location = self._active_location(state, move.from_shelf)
        target_location = self._active_location(state, move.to_shelf)
        if source_location is None or target_location is None:
            raise ValueError("move addresses a shelf that is hidden or already destroyed")

        source = columns[source_location[0]][source_location[1]].state
        target = columns[target_location[0]][target_location[1]].state
        if (move.from_shelf == move.to_shelf
                or not source.layers
                or not target.layers
                or not 0 <= move.from_slot < source.slot_count
                or not 0 <= move.to_slot < target.slot_count
                or not is_shelf_unlocked(source, triples_cleared)
                or not is_shelf_unlocked(target, triples_cleared)
                or not target.accepts_dropped_items
                or (0, move.from_slot) in source.sticky_items
                or not move.item_id
                or visible_layer(source)[move.from_slot] != move.item_id
                or visible_layer(target)[move.to_slot] is not None):
            raise ValueError("illegal move (source, sticky item, target, or lock)")

        working = [list(column) for column in columns]
        working[source_location[0]][source_location[1]] = ColumnShelf(
            move.from_shelf, replace_front_slot(source, move.from_slot, None)
        )
        working[target_location[0]][target_location[1]] = ColumnShelf(
            move.to_shelf, replace_front_slot(target, move.to_slot, move.item_id)
        )

        return (triples_cleared, tuple(tuple(column) for column in working))

    ## Kept shelves outlive the last item, so the objective is an item-free board. A hidden shelf is
    ## never empty -- every authored shelf starts with an item and nothing reaches it off-window --
    ## so an item-free board also means nothing is left waiting above the window.
    def is_cleared(self, state: CollapsingState) -> bool:
        return all(
            is_empty_layer(layer) for column in state[1] for entry in column for layer in entry.state.layers
        )

    def _active_location(self, state: CollapsingState, shelf_id: int) -> tuple[int, int] | None:
        for column_index, column in enumerate(state[1]):
            for stack_index, entry in enumerate(column[: self.visible_count]):
                if entry.shelf_id == shelf_id:
                    return (column_index, stack_index)

        return None


CLASSIC_RULES = ClassicRules()


def collapsing_shelves_to_state(
    shelves: list[dict[str, Any]],
    shelf_counts: list[int],
) -> CollapsingState:
    """Split the flat authored shelves array into columns, left-to-right and bottom-to-top."""
    flat_shelves = shelves_to_state(shelves)[1]
    columns = []
    cursor = 0
    for shelf_count in shelf_counts:
        columns.append(
            tuple(
                ColumnShelf(cursor + offset, flat_shelves[cursor + offset])
                for offset in range(shelf_count)
            )
        )
        cursor += shelf_count

    return (0, tuple(columns))


def build_search_inputs(level_data: Any, shelves: list[dict[str, Any]]) -> tuple[SortingRules, Any]:
    """Rules object and initial state for an already validated level."""
    if get_gameplay_mode(level_data) != GAMEPLAY_MODE_COLLAPSING_COLUMNS:
        return CLASSIC_RULES, shelves_to_state(shelves)

    column_layout = level_data[COLUMN_LAYOUT_KEY]
    shelf_counts = [int(shelf_count) for shelf_count in column_layout[COLUMN_SHELF_COUNTS_KEY]]
    rules = CollapsingColumnsRules(int(column_layout[COLUMN_VISIBLE_SHELVES_KEY]))
    return rules, collapsing_shelves_to_state(shelves, shelf_counts)


def solve_level(
    initial_state,
    max_states: int,
    max_depth: int,
    keep_solution: bool,
    rules: SortingRules | None = None,
) -> SearchResult:
    # Keep real shelf/slot coordinates in the search path. Canonicalization is only a visited key;
    # replaying a solution must never require rearranging the player's board between moves.
    board_rules = rules if rules is not None else CLASSIC_RULES
    start_state = board_rules.settle(initial_state)
    preflight_result = board_rules.preflight(start_state)
    if preflight_result is not None:
        return preflight_result
    if board_rules.is_cleared(start_state):
        return SearchResult(True, "solved", 0, 1, 1, [])

    queue = [(start_state, 0)]
    visited = {board_rules.canonicalize(start_state): 0}
    parents: dict[Any, tuple[Any, Move]] = {}
    states_checked = 0
    max_queue_size = 1
    hit_depth_limit = False

    while queue:
        state, depth = queue.pop()
        states_checked += 1

        if states_checked > max_states:
            return SearchResult(None, "state_limit", None, states_checked, max_queue_size, [])
        if depth >= max_depth:
            hit_depth_limit = True
            continue

        moves = board_rules.legal_moves(state)
        for move in reversed(moves):
            next_state = board_rules.settle(board_rules.apply_move(state, move))
            key = board_rules.canonicalize(next_state)
            if visited.get(key, max_depth + 1) <= depth + 1:
                continue

            if keep_solution:
                parents[next_state] = (state, move)

            if board_rules.is_cleared(next_state):
                solution = reconstruct_solution(parents, start_state, next_state) if keep_solution else []
                return SearchResult(True, "solved", depth + 1, states_checked, max_queue_size, solution)

            visited[key] = depth + 1
            queue.append((next_state, depth + 1))
            max_queue_size = max(max_queue_size, len(queue))

    return SearchResult(None if hit_depth_limit else False,
                        "depth_limit" if hit_depth_limit else "exhausted",
                        None, states_checked, max_queue_size, [])


def reconstruct_solution(parents: dict[State, tuple[State, Move]], start_state: State, end_state: State) -> list[Move]:
    solution = []
    state = end_state

    while state != start_state:
        parent_state, move = parents[state]
        solution.append(move)
        state = parent_state

    solution.reverse()
    return solution


def result_to_json(
    path: Path,
    valid: bool,
    errors: list[str],
    item_counts: Counter[str],
    search_result: SearchResult | None,
    gameplay_mode: str = GAMEPLAY_MODE_CLASSIC,
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "file": str(path),
        "valid": valid,
        "gameplay_mode": gameplay_mode,
        "errors": errors,
        "item_counts": dict(sorted(item_counts.items())),
    }

    if search_result is None:
        result.update(
            {
                "solvable": None,
                "reason": "invalid",
                "moves": None,
                "states_checked": 0,
                "max_queue_size": 0,
            }
        )
        return result

    result.update(
        {
            "solvable": search_result.solvable,
            "reason": search_result.reason,
            "moves": search_result.moves,
            "states_checked": search_result.states_checked,
            "max_queue_size": search_result.max_queue_size,
        }
    )

    if search_result.solution:
        result["solution_indexing"] = "authored_1_based"
        result["solution"] = [
            {
                "item": move.item_id,
                "from_shelf": move.from_shelf + 1,
                "from_slot": move.from_slot + 1,
                "to_shelf": move.to_shelf + 1,
                "to_slot": move.to_slot + 1,
            }
            for move in search_result.solution
        ]

    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate whether a Sorting Puzzle level is solvable.")
    parser.add_argument("level", type=Path, help="Path to a full level JSON file or shelves-only JSON array.")
    parser.add_argument("--shelves-only", action="store_true", help="Require the input file to be a shelves array.")
    parser.add_argument("--item-config", type=Path, default=DEFAULT_ITEM_CONFIG)
    parser.add_argument("--skip-known-items", action="store_true")
    parser.add_argument("--max-states", type=int, default=100_000)
    parser.add_argument("--max-depth", type=int, default=200)
    parser.add_argument("--show-solution", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        known_item_ids = set() if args.skip_known_items else load_item_ids(args.item_config)
        level_data = load_level_data(args.level)
        if args.shelves_only:
            if not isinstance(level_data, list):
                raise ValueError("--shelves-only expects a JSON array")
            shelves = level_data
        elif isinstance(level_data, dict) and isinstance(level_data.get("shelves"), list):
            shelves = level_data["shelves"]
        elif isinstance(level_data, list):
            shelves = level_data
        else:
            raise ValueError("Expected a level JSON object with 'shelves' or a shelves array")
        errors, item_counts = validate_shelves_shape(shelves, known_item_ids, args.skip_known_items)
        if not args.shelves_only:
            errors.extend(validate_row_layouts_shape(level_data, shelves))
            errors.extend(validate_gameplay_mode_shape(level_data, shelves))
    except (OSError, ValueError, json.JSONDecodeError) as error:
        result = result_to_json(args.level, False, [str(error)], Counter(), None)
        print(json.dumps(result, indent=2))
        return 1

    reported_mode = get_gameplay_mode(None if args.shelves_only else level_data)
    if not isinstance(reported_mode, str):
        reported_mode = str(reported_mode)

    if errors:
        result = result_to_json(args.level, False, errors, item_counts, None, reported_mode)
        print(json.dumps(result, indent=2))
        return 1

    rules, initial_state = build_search_inputs(None if args.shelves_only else level_data, shelves)
    search_result = solve_level(
        initial_state=initial_state,
        max_states=args.max_states,
        max_depth=args.max_depth,
        keep_solution=args.show_solution,
        rules=rules,
    )
    result = result_to_json(args.level, True, [], item_counts, search_result, rules.mode)
    print(json.dumps(result, indent=2))

    if search_result.solvable is True:
        return 0
    if search_result.solvable is False:
        return 2
    return 3


if __name__ == "__main__":
    raise SystemExit(main())
