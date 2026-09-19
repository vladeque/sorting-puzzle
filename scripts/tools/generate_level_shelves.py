#!/usr/bin/env python3
"""Generate Sorting Puzzle shelf layouts for level JSON files."""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from level_item_progression import logical_item_ids
from validate_level_solvable import (
    CLASSIC_RULES,
    COLUMN_SHELF_COUNTS_KEY,
    COLUMN_VISIBLE_SHELVES_KEY,
    GAMEPLAY_MODE_CLASSIC,
    GAMEPLAY_MODE_COLLAPSING_COLUMNS,
    MAX_VISIBLE_SHELVES_PER_COLUMN,
    CollapsingColumnsRules,
    collapsing_shelves_to_state,
    solve_level,
    shelves_to_state,
    validate_collapsing_shelf_contract,
    validate_shelves_shape,
)


SLOTS_PER_SHELF = 3
SHELF_KIND_DISPENSER = "dispenser"
COLLAPSING_LAYER_COUNT = 1
DEFAULT_LAYOUT_PRESET = "grid_3x3"
DISPENSER_MIN_LAYERS = 2
DISPENSER_MAX_LAYERS = 4
DEFAULT_PREFERRED_COPIES_PER_TYPE = 3.0
LAYER_TRIPLE_RATIO_TOLERANCE = 0.05
LAYOUT_PRESETS = (
    "grid_2x3",
    "grid_3x2",
    "grid_3x3",
    "grid_3x4",
    "grid_3x5",
    "grid_4x3",
    "grid_4x4_hollow",
    "grid_1x4_moving_6_6_sides",
    "grid_2x4_moving_8_left",
    "grid_3x2_moving_5_bottom",
    "grid_3x2_moving_4_4_center",
    "grid_3x3_moving_4_middle",
    "grid_3x3_moving_5_bottom",
    "staggered_rows_2_3_2",
    "staggered_rows_3_2_3",
    "staggered_rows_2_3_3_2",
    "staggered_rows_3_4_4_3",
    "staggered_columns_4_3_4",
    "staggered_columns_4_5_4",
    "staggered_columns_5_4_5",
    "staggered_columns_4_moving_6_4",
    "staggered_columns_5_moving_6_5",
)


@dataclass(frozen=True)
class DifficultyPreset:
    empty_ratio_min: float
    empty_ratio_max: float
    preferred_layer_triple_ratio: float
    max_same_item_per_layer: int
    max_items_per_type: int | None
    allow_front_layer_matches: bool
    shuffle_passes: int


DIFFICULTIES = {
    "easy": DifficultyPreset(
        empty_ratio_min=0.20,
        empty_ratio_max=0.25,
        preferred_layer_triple_ratio=0.65,
        max_same_item_per_layer=5,
        max_items_per_type=None,
        allow_front_layer_matches=True,
        shuffle_passes=1,
    ),
    "medium": DifficultyPreset(
        empty_ratio_min=0.15,
        empty_ratio_max=0.20,
        preferred_layer_triple_ratio=0.50,
        max_same_item_per_layer=4,
        max_items_per_type=None,
        allow_front_layer_matches=True,
        shuffle_passes=2,
    ),
    "hard": DifficultyPreset(
        empty_ratio_min=0.15,
        empty_ratio_max=0.20,
        preferred_layer_triple_ratio=0.40,
        max_same_item_per_layer=3,
        max_items_per_type=None,
        allow_front_layer_matches=True,
        shuffle_passes=4,
    ),
    "expert": DifficultyPreset(
        empty_ratio_min=0.10,
        empty_ratio_max=0.15,
        preferred_layer_triple_ratio=0.30,
        max_same_item_per_layer=3,
        max_items_per_type=None,
        allow_front_layer_matches=False,
        shuffle_passes=6,
    ),
}


def parse_locked_shelves(raw_locked_shelves: str | None) -> dict[int, int]:
    if not raw_locked_shelves:
        return {}

    locked_shelves: dict[int, int] = {}
    for raw_entry in raw_locked_shelves.split(","):
        entry = raw_entry.strip()
        if not entry:
            continue

        parts = entry.split(":")
        if len(parts) != 2:
            raise ValueError("--locked-shelves entries must use SHELF:TRIPLES")

        try:
            shelf_number = int(parts[0])
            unlock_after_triples = int(parts[1])
        except ValueError as error:
            raise ValueError("--locked-shelves entries must contain integers") from error

        if shelf_number <= 0:
            raise ValueError("--locked-shelves shelf numbers are 1-based and must be positive")
        if unlock_after_triples < 0:
            raise ValueError("--locked-shelves triple counts must be non-negative")

        locked_shelves[shelf_number] = unlock_after_triples

    return locked_shelves


def parse_dispenser_shelves(raw_dispenser_shelves: str | None) -> dict[int, int]:
    if not raw_dispenser_shelves:
        return {}

    dispenser_shelves: dict[int, int] = {}
    for raw_entry in raw_dispenser_shelves.split(","):
        entry = raw_entry.strip()
        if not entry:
            continue

        parts = entry.split(":")
        if len(parts) != 2:
            raise ValueError("--dispenser-shelves entries must use SHELF:LAYERS")

        try:
            shelf_number = int(parts[0])
            layer_count = int(parts[1])
        except ValueError as error:
            raise ValueError("--dispenser-shelves entries must contain integers") from error

        if shelf_number <= 0:
            raise ValueError("--dispenser-shelves shelf numbers are 1-based and must be positive")
        if not DISPENSER_MIN_LAYERS <= layer_count <= DISPENSER_MAX_LAYERS:
            raise ValueError(
                f"--dispenser-shelves layer counts must be {DISPENSER_MIN_LAYERS} "
                f"to {DISPENSER_MAX_LAYERS}"
            )

        dispenser_shelves[shelf_number] = layer_count

    return dispenser_shelves


def collect_dispenser_donor_slots(
    shelves: list[dict[str, Any]],
    rng: random.Random,
) -> list[tuple[int, int, int]]:
    """Filled slot coordinates, deepest layer first, shuffled within each layer."""
    donors: list[tuple[int, int, int]] = []
    max_layer_count = max((len(shelf["layers"]) for shelf in shelves), default=0)
    for layer_index in range(max_layer_count - 1, -1, -1):
        layer_donors: list[tuple[int, int, int]] = []
        for shelf_index, shelf in enumerate(shelves):
            layers = shelf["layers"]
            if layer_index >= len(layers):
                continue

            for slot_index, item_id in enumerate(layers[layer_index]):
                if item_id is not None:
                    layer_donors.append((shelf_index, layer_index, slot_index))

        rng.shuffle(layer_donors)
        donors.extend(layer_donors)

    return donors


def apply_dispenser_shelves(
    shelves: list[dict[str, Any]],
    dispenser_shelves: dict[int, int],
    rng: random.Random,
) -> None:
    """Insert source-only dispenser shelves, stocking them from the generated board.

    Queue items are relocated rather than newly minted, so every item ID keeps the multiple-of-three
    count the distribution engine gave it. They come out of the deepest layers first, which disturbs
    the opening board least. Whether the result is still winnable is not assumed here --
    --require-solvable re-runs the search after this pass.
    """
    if not dispenser_shelves:
        return

    total_shelf_count = len(shelves) + len(dispenser_shelves)
    for shelf_number in sorted(dispenser_shelves):
        if shelf_number > total_shelf_count:
            raise ValueError(
                f"--dispenser-shelves references shelf {shelf_number}, "
                f"but only {total_shelf_count} shelves exist"
            )

    required_item_count = sum(dispenser_shelves.values())
    donors = collect_dispenser_donor_slots(shelves, rng)
    if len(donors) < required_item_count:
        raise ValueError(
            f"--dispenser-shelves needs {required_item_count} items, but the generated board "
            f"only holds {len(donors)}"
        )

    queue_items: list[str] = []
    for shelf_index, layer_index, slot_index in donors[:required_item_count]:
        queue_items.append(shelves[shelf_index]["layers"][layer_index][slot_index])
        shelves[shelf_index]["layers"][layer_index][slot_index] = None

    # Ascending order so an earlier insertion never shifts a later target position.
    item_cursor = 0
    for shelf_number in sorted(dispenser_shelves):
        layer_count = dispenser_shelves[shelf_number]
        items = queue_items[item_cursor : item_cursor + layer_count]
        item_cursor += layer_count
        shelves.insert(
            shelf_number - 1,
            {"type": SHELF_KIND_DISPENSER, "layers": [[item_id] for item_id in items]},
        )


def apply_locked_shelves(shelves: list[dict[str, Any]], locked_shelves: dict[int, int]) -> None:
    for shelf_number, unlock_after_triples in locked_shelves.items():
        if shelf_number > len(shelves):
            raise ValueError(
                f"--locked-shelves references shelf {shelf_number}, but only {len(shelves)} shelves exist"
            )

        if unlock_after_triples > 0:
            shelves[shelf_number - 1]["unlock_after_triples"] = unlock_after_triples
        else:
            shelves[shelf_number - 1].pop("unlock_after_triples", None)


def calculate_filled_slots(total_slots: int, preset: DifficultyPreset, rng: random.Random) -> int:
    empty_ratio = rng.uniform(preset.empty_ratio_min, preset.empty_ratio_max)
    target_empty_slots = round(total_slots * empty_ratio)
    empty_slots = min(total_slots - SLOTS_PER_SHELF, target_empty_slots)
    empty_slots -= empty_slots % SLOTS_PER_SHELF
    return total_slots - empty_slots


def infer_item_type_count(target_filled_slots: int, preferred_copies_per_type: float) -> int:
    if (
        not math.isfinite(preferred_copies_per_type)
        or preferred_copies_per_type < SLOTS_PER_SHELF
    ):
        raise ValueError("--preferred-copies-per-type must be finite and at least 3")

    triple_count = target_filled_slots // SLOTS_PER_SHELF
    if triple_count <= 0:
        raise ValueError("At least one item triple is required to infer the item type count")

    preferred_type_count = math.ceil(target_filled_slots / preferred_copies_per_type)
    return min(triple_count, preferred_type_count)


def round_down_to_triple_count(item_count: int) -> int:
    return item_count - (item_count % SLOTS_PER_SHELF)


def calculate_max_items_per_type(
    preset: DifficultyPreset,
    max_items_per_type_override: int | None,
) -> int | None:
    configured_limits = []
    if preset.max_items_per_type is not None:
        configured_limits.append(preset.max_items_per_type)
    if max_items_per_type_override is not None:
        configured_limits.append(max_items_per_type_override)
    if not configured_limits:
        return None

    max_items_per_type = round_down_to_triple_count(min(configured_limits))
    if max_items_per_type < SLOTS_PER_SHELF:
        raise ValueError("Effective max items per type must allow at least one triple")

    return max_items_per_type


def would_create_front_match(shelves: list[dict[str, list[list[str | None]]]]) -> bool:
    return count_front_layer_matches(shelves) > 0


def count_front_layer_matches(shelves: list[dict[str, list[list[str | None]]]]) -> int:
    match_count = 0
    for shelf in shelves:
        layers = shelf["layers"]
        if not layers:
            continue

        front_layer = layers[0]
        if None in front_layer:
            continue

        if len(set(front_layer)) == 1:
            match_count += 1

    return match_count


def parse_column_heights(raw_column_heights: str | None) -> list[int]:
    if not raw_column_heights:
        return []

    column_heights = []
    for raw_entry in raw_column_heights.split(","):
        entry = raw_entry.strip()
        if not entry:
            continue

        try:
            column_height = int(entry)
        except ValueError as error:
            raise ValueError(
                f"--column-heights entries must be integers, found '{entry}'"
            ) from error

        if column_height <= 0:
            raise ValueError("--column-heights entries must be greater than 0")

        column_heights.append(column_height)

    if not column_heights:
        raise ValueError("--column-heights must list at least one column")

    return column_heights


def split_shelves_into_columns(
    shelves: list[dict[str, Any]],
    column_heights: list[int],
) -> list[list[dict[str, Any]]]:
    """The flat shelves array is consumed column by column, bottom to top inside each column."""
    columns = []
    cursor = 0
    for column_height in column_heights:
        columns.append(shelves[cursor : cursor + column_height])
        cursor += column_height

    return columns


def active_collapsing_shelves(
    shelves: list[dict[str, Any]],
    column_heights: list[int],
    visible_shelves_per_column: int,
) -> list[dict[str, Any]]:
    """The shelves a collapsing board opens with, which is all the player can act on at first."""
    active = []
    for column in split_shelves_into_columns(shelves, column_heights):
        active.extend(column[:visible_shelves_per_column])

    return active


## An authored collapsing shelf with no items would be destroyed before the player could touch it, so
## the distribution engine's empty slots are redistributed rather than rejected. Items only move
## between shelves, so every item's copy count -- and its divisibility by three -- is preserved.
def fill_empty_collapsing_shelves(shelves: list[dict[str, Any]], rng: random.Random) -> int:
    def occupied_count(shelf: dict[str, Any]) -> int:
        return sum(1 for item_id in shelf["layers"][0] if item_id is not None)

    rescued_count = 0
    for shelf in shelves:
        layer = shelf["layers"][0]
        if any(item_id is not None for item_id in layer):
            continue

        donor = max(
            (candidate for candidate in shelves if candidate is not shelf),
            key=lambda candidate: occupied_count(candidate),
            default=None,
        )
        if donor is None or occupied_count(donor) < 2:
            raise ValueError(
                "Could not give every collapsing shelf an item; use fewer shelves, a denser "
                "difficulty, or more item copies"
            )

        donor_layer = donor["layers"][0]
        donor_slot = next(
            slot for slot, item_id in enumerate(donor_layer) if item_id is not None
        )
        layer[rng.randrange(SLOTS_PER_SHELF)] = donor_layer[donor_slot]
        donor_layer[donor_slot] = None
        rescued_count += 1

    return rescued_count


def distribute_slots(slot_values: list[str | None], shelf_count: int, layer_count: int) -> list[dict[str, Any]]:
    shelves = []
    value_index = 0

    for _shelf_index in range(shelf_count):
        layers = []
        for _layer_index in range(layer_count):
            layer = slot_values[value_index : value_index + SLOTS_PER_SHELF]
            value_index += SLOTS_PER_SHELF
            layers.append(layer)

        shelves.append({"layers": layers})

    return shelves


def compose_shelves(
    eligible_slot_values: list[str | None],
    shelf_count: int,
    layer_count: int,
    filled_layer_count: int,
) -> list[dict[str, Any]]:
    shelves = []
    value_index = 0

    for _shelf_index in range(shelf_count):
        layers = []
        for layer_index in range(layer_count):
            if layer_index < filled_layer_count:
                layer = eligible_slot_values[value_index : value_index + SLOTS_PER_SHELF]
                value_index += SLOTS_PER_SHELF
            else:
                layer = [None] * SLOTS_PER_SHELF

            layers.append(layer)

        shelves.append({"layers": layers})

    return shelves


def generate_shelves(
    shelf_count: int,
    layer_count: int,
    filled_layer_count: int,
    item_types: list[str] | None,
    difficulty: str,
    seed: int | None,
    max_items_per_type_override: int | None,
    min_front_visible_triples: int,
    preferred_copies_per_type: float = DEFAULT_PREFERRED_COPIES_PER_TYPE,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if shelf_count <= 0:
        raise ValueError("--shelf-count must be greater than 0")
    if layer_count <= 0:
        raise ValueError("--layer-count must be greater than 0")
    if filled_layer_count <= 0 or filled_layer_count > layer_count:
        raise ValueError("--filled-layer-count must be between 1 and --layer-count")
    if min_front_visible_triples < 0:
        raise ValueError("--min-front-visible-triples must be zero or greater")

    preset = DIFFICULTIES[difficulty]
    rng = random.Random(seed)
    eligible_slots = shelf_count * filled_layer_count * SLOTS_PER_SHELF
    target_filled_slots = calculate_filled_slots(eligible_slots, preset, rng)
    item_type_count_source = "explicit"
    if item_types is None:
        item_type_count = infer_item_type_count(
            target_filled_slots=target_filled_slots,
            preferred_copies_per_type=preferred_copies_per_type,
        )
        item_types = logical_item_ids(item_type_count)
        item_type_count_source = "inferred"
    elif (
        not math.isfinite(preferred_copies_per_type)
        or preferred_copies_per_type < SLOTS_PER_SHELF
    ):
        raise ValueError("--preferred-copies-per-type must be finite and at least 3")

    max_items_per_type = calculate_max_items_per_type(
        preset=preset,
        max_items_per_type_override=max_items_per_type_override,
    )
    filled_slots = target_filled_slots
    if max_items_per_type is not None:
        filled_slots = min(filled_slots, len(item_types) * max_items_per_type)
    filled_slots -= filled_slots % SLOTS_PER_SHELF
    empty_slots = eligible_slots - filled_slots
    item_pool = build_item_pool_with_limit(
        item_types=item_types,
        filled_slots=filled_slots,
        max_items_per_type=max_items_per_type,
        rng=rng,
    )
    eligible_slot_values = spread_values_across_layers(
        item_pool=item_pool,
        empty_slots=empty_slots,
        shelf_count=shelf_count,
        filled_layer_count=filled_layer_count,
        preferred_layer_triple_ratio=preset.preferred_layer_triple_ratio,
        max_same_item_per_layer=preset.max_same_item_per_layer,
        min_front_visible_triples=min_front_visible_triples,
        rng=rng,
    )
    ensure_min_front_visible_triples(
        eligible_slot_values=eligible_slot_values,
        shelf_count=shelf_count,
        filled_layer_count=filled_layer_count,
        min_front_visible_triples=min_front_visible_triples,
        max_same_item_per_layer=preset.max_same_item_per_layer,
        rng=rng,
    )

    for _ in range(preset.shuffle_passes):
        shuffle_values_within_layers(
            eligible_slot_values=eligible_slot_values,
            shelf_count=shelf_count,
            filled_layer_count=filled_layer_count,
            rng=rng,
        )

    shelves = compose_shelves(
        eligible_slot_values=eligible_slot_values,
        shelf_count=shelf_count,
        layer_count=layer_count,
        filled_layer_count=filled_layer_count,
    )
    shelves = reshuffle_for_layout_constraints(
        eligible_slot_values=eligible_slot_values,
        shelf_count=shelf_count,
        layer_count=layer_count,
        filled_layer_count=filled_layer_count,
        preset=preset,
        rng=rng,
        max_attempts=250,
    )

    stats = build_stats(
        shelves=shelves,
        difficulty=difficulty,
        seed=seed,
        shelf_count=shelf_count,
        layer_count=layer_count,
        filled_layer_count=filled_layer_count,
        preset=preset,
        max_items_per_type_override=max_items_per_type_override,
        min_front_visible_triples=min_front_visible_triples,
        target_filled_slots=target_filled_slots,
        item_type_count=len(item_types),
        item_type_count_source=item_type_count_source,
        preferred_copies_per_type=preferred_copies_per_type,
    )
    return shelves, stats


def validate_generated_shelves(
    shelves: list[dict[str, Any]],
    max_states: int,
    max_depth: int,
    column_heights: list[int] | None = None,
    visible_shelves_per_column: int | None = None,
) -> dict[str, Any]:
    errors, item_counts = validate_shelves_shape(
        shelves=shelves,
        known_item_ids=set(),
        skip_known_items=True,
    )
    rules = CLASSIC_RULES
    if column_heights:
        errors.extend(validate_collapsing_shelf_contract(shelves))
        rules = CollapsingColumnsRules(int(visible_shelves_per_column or 1))

    if errors:
        return {
            "valid": False,
            "gameplay_mode": rules.mode,
            "errors": errors,
            "item_counts": dict(sorted(item_counts.items())),
            "solvable": None,
            "reason": "invalid",
            "moves": None,
            "states_checked": 0,
            "max_queue_size": 0,
        }

    initial_state = (
        collapsing_shelves_to_state(shelves, column_heights)
        if column_heights
        else shelves_to_state(shelves)
    )
    search_result = solve_level(
        initial_state=initial_state,
        max_states=max_states,
        max_depth=max_depth,
        keep_solution=False,
        rules=rules,
    )
    return {
        "valid": True,
        "gameplay_mode": rules.mode,
        "errors": [],
        "item_counts": dict(sorted(item_counts.items())),
        "solvable": search_result.solvable,
        "reason": search_result.reason,
        "moves": search_result.moves,
        "states_checked": search_result.states_checked,
        "max_queue_size": search_result.max_queue_size,
    }


def apply_sticky_items(shelves: list[dict[str, Any]], percent: float, seed: int) -> dict[str, Any]:
    """Seeded capacity matching assigns at most one sticky item per occupied standard layer.

    Matching layers to per-type triple tokens avoids unlucky greedy choices stranding capacity.
    It is only a necessary copy-count check; the final board must still pass the solver.
    """
    if not math.isfinite(percent) or not 0 <= percent <= 100:
        raise ValueError("--sticky-items-percent must be finite and between 0 and 100")
    counts = Counter(item for shelf in shelves for layer in shelf["layers"] for item in layer if item)
    total = sum(counts.values())
    layers = [(si, li) for si, shelf in enumerate(shelves)
              if shelf.get("type", "standard") != SHELF_KIND_DISPENSER
              for li, layer in enumerate(shelf["layers"]) if any(layer)]
    requested = math.floor(total * percent / 100 + 0.5)
    target = min(requested, len(layers))
    stats: dict[str, Any] = {
        "requested_percent": percent, "requested_count": requested,
        "eligible_layer_count": len(layers), "target_count": target,
        "actual_count": 0, "effective_percent": 0.0, "placements": [],
        "cap_reason": "occupied_standard_layers" if requested > len(layers) else None,
    }
    if target == 0:
        return stats
    rng = random.Random(f"sticky:{seed}")
    rng.shuffle(layers)
    candidates: dict[tuple[int, int], list[tuple[str, int]]] = {}
    for si, li in layers:
        tokens = [(item, copy) for item in sorted(set(shelves[si]["layers"][li]) - {None})
                  for copy in range(counts[item] // 3)]
        rng.shuffle(tokens)
        candidates[si, li] = tokens
    owners: dict[tuple[str, int], tuple[int, int]] = {}

    def assign(layer: tuple[int, int], seen: set[tuple[str, int]]) -> bool:
        for token in candidates[layer]:
            if token in seen:
                continue
            seen.add(token)
            if token not in owners or assign(owners[token], seen):
                owners[token] = layer
                return True
        return False

    for layer in layers:
        assign(layer, set())
        if len(owners) == target:
            break
    if len(owners) < target:
        raise ValueError(f"Cannot place {target} sticky items with one per layer and enough matching "
                         f"copies; maximum assignment is {len(owners)}. Lower --sticky-items-percent.")
    for (item, _copy), (si, li) in sorted(owners.items(), key=lambda pair: pair[1]):
        slot = rng.choice([i for i, value in enumerate(shelves[si]["layers"][li]) if value == item])
        shelves[si].setdefault("sticky_items", []).append({"layer": li, "slot": slot})
        stats["placements"].append({"shelf": si, "layer": li, "slot": slot})
    stats["actual_count"] = target
    stats["effective_percent"] = 100 * target / total if total else 0.0
    return stats


def count_collectible_front_types(shelves: list[dict[str, Any]]) -> int:
    """Conservative opening check: park blockers in free slots, then gather ordinary partners.

    No hidden layer, locked shelf, or second sticky anchor is treated as an available partner.
    This witnesses a gathering sequence without assuming that three visible copies suffice.
    """
    state = shelves_to_state(shelves)[1]
    reachable = [(si, shelf) for si, shelf in enumerate(state) if shelf.unlock_after_triples == 0]
    movable = Counter(item for _, shelf in reachable for slot, item in enumerate(shelf.layers[0])
                      if item is not None and (0, slot) not in shelf.sticky_items)
    available_empty = sum(shelf.layers[0].count(None) for _, shelf in reachable if shelf.accepts_dropped_items)
    collectible: set[str] = set()
    for _, shelf in reachable:
        if not shelf.forms_triples:
            continue
        front = shelf.layers[0]
        sticky = next((front[slot] for layer, slot in shelf.sticky_items if layer == 0), None)
        for item in set(movable) | ({sticky} if sticky else set()):
            if sticky is not None and sticky != item:
                continue
            blockers = sum(value is not None and value != item for value in front)
            # Outside matching copies must be movable. Slots freed by them can also park blockers,
            # but requiring initial buffer slots here deliberately gives a conservative witness.
            if available_empty - front.count(None) < blockers:
                continue
            existing = front.count(item)
            outside = movable[item] - existing + int(sticky == item)
            if outside >= 3 - existing:
                collectible.add(item)
    return len(collectible)


def generate_with_optional_validation(
    shelf_count: int,
    layer_count: int,
    filled_layer_count: int,
    item_types: list[str] | None,
    difficulty: str,
    seed: int | None,
    should_validate: bool,
    require_solvable: bool,
    max_attempts: int,
    max_items_per_type_override: int | None,
    min_front_visible_triples: int,
    max_states: int,
    max_depth: int,
    preferred_copies_per_type: float = DEFAULT_PREFERRED_COPIES_PER_TYPE,
    locked_shelves: dict[int, int] | None = None,
    dispenser_shelves: dict[int, int] | None = None,
    sticky_items_percent: float = 0.0,
    column_heights: list[int] | None = None,
    visible_shelves_per_column: int | None = None,
) -> tuple[list[dict[str, Any]], dict[str, Any], dict[str, Any] | None, int | None]:
    if not math.isfinite(sticky_items_percent) or not 0 <= sticky_items_percent <= 100:
        raise ValueError("--sticky-items-percent must be finite and between 0 and 100")
    attempts = max(1, max_attempts if require_solvable else 1)
    random_seed_source = random.SystemRandom()
    last_result = None
    locked_shelves = locked_shelves or {}
    dispenser_shelves = dispenser_shelves or {}
    last_placement_error = None

    # Dispensers are inserted after generation, so the distribution engine lays out only the
    # standard shelves and the requested total still comes out right.
    standard_shelf_count = shelf_count - len(dispenser_shelves)
    if standard_shelf_count < 1:
        raise ValueError("--dispenser-shelves must leave at least one standard shelf")

    for attempt_index in range(attempts):
        attempt_seed = seed + attempt_index if seed is not None else random_seed_source.randrange(1, 2**31)
        shelves, stats = generate_shelves(
            shelf_count=standard_shelf_count,
            layer_count=layer_count,
            filled_layer_count=filled_layer_count,
            item_types=item_types,
            difficulty=difficulty,
            seed=attempt_seed,
            max_items_per_type_override=max_items_per_type_override,
            min_front_visible_triples=min_front_visible_triples,
            preferred_copies_per_type=preferred_copies_per_type,
        )
        apply_dispenser_shelves(shelves, dispenser_shelves, random.Random(attempt_seed))
        apply_locked_shelves(shelves, locked_shelves)
        if column_heights:
            visible_count = int(visible_shelves_per_column or 1)
            stats["rescued_empty_shelves"] = fill_empty_collapsing_shelves(
                shelves, random.Random(attempt_seed)
            )
            active_shelves = active_collapsing_shelves(shelves, column_heights, visible_count)
            # Opening progress is judged on the window the player actually opens with. A triple
            # waiting behind a hidden shelf is not a start the player can act on.
            active_ready = count_collectible_front_types(active_shelves)
            stats["active_collectible_front_types"] = active_ready
            if active_ready < min_front_visible_triples:
                last_placement_error = ValueError(
                    "Generated columns do not open with the requested collectible front triples; "
                    "try another seed, more attempts, or a larger visible window."
                )
                if require_solvable:
                    continue
                raise last_placement_error
        if sticky_items_percent > 0:
            try:
                stats["sticky_items"] = apply_sticky_items(shelves, sticky_items_percent, attempt_seed)
            except ValueError as error:
                last_placement_error = error
                if require_solvable:
                    continue
                raise
            shape_errors, _ = validate_shelves_shape(shelves, set(), True)
            if shape_errors:
                raise ValueError("Invalid final sticky layout: " + "; ".join(shape_errors))
            ready = count_collectible_front_types(shelves)
            stats["collectible_front_types"] = ready
            if ready < min_front_visible_triples:
                last_placement_error = ValueError("Sticky placement did not preserve the requested "
                                                 "collectible front triples; try another seed or more attempts.")
                if require_solvable:
                    continue
                raise last_placement_error
            final_values = flatten_shelves(shelves)
            final_depth = max(len(shelf["layers"]) for shelf in shelves)
            final_counts = Counter(value for value in final_values if value is not None)
            stats.update({
                "shelf_count": len(shelves),
                "total_slots": len(final_values),
                "filled_slots": sum(final_counts.values()),
                "empty_slots": final_values.count(None),
                "item_counts": dict(sorted(final_counts.items())),
                "front_visible_triple_candidates": count_front_visible_triple_candidates(shelves),
                "layer_item_counts": [dict(sorted(c.items())) for c in build_layer_item_counts(shelves, final_depth)],
                "layer_triple_readiness": build_layer_triple_readiness(shelves, final_depth),
                "non_adjacent_item_spreads": find_non_adjacent_item_spreads(shelves, final_depth),
                "layer_item_overloads": find_layer_item_overloads(
                    shelves, final_depth, DIFFICULTIES[difficulty].max_same_item_per_layer),
                "front_layer_matches": would_create_front_match(shelves),
                "front_layer_match_count": count_front_layer_matches(shelves),
            })
        stats["dispenser_shelves"] = {
            str(shelf_number): layer_count
            for shelf_number, layer_count in sorted(dispenser_shelves.items())
        }
        stats["attempt"] = attempt_index + 1
        stats["max_attempts"] = attempts
        stats["locked_shelves"] = {
            str(shelf_number): unlock_after_triples
            for shelf_number, unlock_after_triples in sorted(locked_shelves.items())
        }
        stats.update(
            build_collapsing_stats(shelves, column_heights, visible_shelves_per_column)
        )

        validation = None
        if should_validate or require_solvable:
            validation = validate_generated_shelves(
                shelves=shelves,
                max_states=max_states,
                max_depth=max_depth,
                column_heights=column_heights,
                visible_shelves_per_column=visible_shelves_per_column,
            )
            stats["validation"] = validation

        last_result = (shelves, stats, validation, attempt_seed)
        if not require_solvable or (validation is not None and validation["solvable"] is True):
            return last_result

    if last_result is None:
        if last_placement_error is not None:
            raise last_placement_error
        raise ValueError("Could not generate shelves")

    return last_result


def build_item_pool_with_limit(
    item_types: list[str],
    filled_slots: int,
    max_items_per_type: int | None,
    rng: random.Random,
) -> list[str]:
    triple_count = filled_slots // SLOTS_PER_SHELF
    usable_count = min(len(item_types), triple_count)
    if usable_count <= 0:
        raise ValueError("At least one item type and one item triple are required")

    shuffled_item_types = item_types[:]
    rng.shuffle(shuffled_item_types)
    selected_item_types = shuffled_item_types[:usable_count]

    triples_by_item: Counter[str] = Counter()
    for triple_index in range(triple_count):
        item_id = selected_item_types[triple_index % usable_count]
        triples_by_item[item_id] += 1
        if (
            max_items_per_type is not None
            and triples_by_item[item_id] * SLOTS_PER_SHELF > max_items_per_type
        ):
            raise ValueError("Generated item pool exceeds --max-items-per-type")

    item_pool = []
    for item_id, triples in triples_by_item.items():
        item_pool.extend([item_id] * triples * SLOTS_PER_SHELF)

    rng.shuffle(item_pool)
    return item_pool


def rebuild_values_from_layers(
    layer_values: list[list[str | None]],
    shelf_count: int,
    filled_layer_count: int,
) -> list[str | None]:
    eligible_slot_values: list[str | None] = []
    layer_offsets = [0] * filled_layer_count

    for _shelf_index in range(shelf_count):
        for layer_index in range(filled_layer_count):
            layer_offset = layer_offsets[layer_index]
            eligible_slot_values.extend(
                layer_values[layer_index][layer_offset : layer_offset + SLOTS_PER_SHELF]
            )
            layer_offsets[layer_index] += SLOTS_PER_SHELF

    return eligible_slot_values


def split_values_by_layer(
    eligible_slot_values: list[str | None],
    shelf_count: int,
    filled_layer_count: int,
) -> list[list[str | None]]:
    layer_values: list[list[str | None]] = [[] for _ in range(filled_layer_count)]
    value_index = 0

    for _shelf_index in range(shelf_count):
        for layer_index in range(filled_layer_count):
            layer_values[layer_index].extend(
                eligible_slot_values[value_index : value_index + SLOTS_PER_SHELF]
            )
            value_index += SLOTS_PER_SHELF

    return layer_values


def shuffle_values_within_layers(
    eligible_slot_values: list[str | None],
    shelf_count: int,
    filled_layer_count: int,
    rng: random.Random,
) -> None:
    layer_values = split_values_by_layer(
        eligible_slot_values=eligible_slot_values,
        shelf_count=shelf_count,
        filled_layer_count=filled_layer_count,
    )
    for values in layer_values:
        rng.shuffle(values)

    eligible_slot_values[:] = rebuild_values_from_layers(
        layer_values=layer_values,
        shelf_count=shelf_count,
        filled_layer_count=filled_layer_count,
    )


def build_balanced_layer_targets(
    value_count: int,
    layer_count: int,
    rng: random.Random,
) -> list[int]:
    base_count, extra_count = divmod(value_count, layer_count)
    targets = [base_count] * layer_count
    layer_order = list(range(layer_count))
    rng.shuffle(layer_order)
    for layer_index in layer_order[:extra_count]:
        targets[layer_index] += 1
    return targets


def count_ready_triples_in_pattern(pattern: tuple[int, ...]) -> list[int]:
    return [count // SLOTS_PER_SHELF for count in pattern]


def build_compact_layer_order(
    layer_count: int,
    first_layer: int,
    last_layer: int,
    prefer_lower_layers: bool,
) -> list[int]:
    outside_layers = [
        layer_index
        for layer_index in range(layer_count)
        if layer_index < first_layer or layer_index > last_layer
    ]

    def sort_key(layer_index: int) -> tuple[int, int]:
        if layer_index < first_layer:
            distance = first_layer - layer_index
            preferred_side = 0 if prefer_lower_layers else 1
        else:
            distance = layer_index - last_layer
            preferred_side = 1 if prefer_lower_layers else 0
        return distance, preferred_side

    return sorted(outside_layers, key=sort_key)


def build_compact_item_patterns(
    item_count: int,
    preferred_local_triples: int,
    layer_count: int,
    per_layer_limit: int,
) -> list[tuple[int, ...]]:
    if layer_count == 1:
        return [(item_count,)]

    anchored_layer_count = min(
        preferred_local_triples,
        item_count // SLOTS_PER_SHELF,
        layer_count,
    )
    pattern_keys: set[tuple[int, ...]] = set()
    anchor_starts: list[int | None]
    if anchored_layer_count > 0:
        anchor_starts = list(range(layer_count - anchored_layer_count + 1))
    else:
        anchor_starts = [None]

    for anchor_start in anchor_starts:
        origins = range(layer_count) if anchor_start is None else [anchor_start]
        for origin in origins:
            for prefer_lower_layers in (False, True):
                for scatter_limit in range(2, per_layer_limit + 1):
                    pattern = [0] * layer_count
                    anchor_layers: list[int] = []
                    if anchor_start is None:
                        first_layer = origin
                        last_layer = origin
                        compact_order = [origin]
                        compact_order.extend(
                            build_compact_layer_order(
                                layer_count=layer_count,
                                first_layer=origin,
                                last_layer=origin,
                                prefer_lower_layers=prefer_lower_layers,
                            )
                        )
                    else:
                        first_layer = anchor_start
                        last_layer = anchor_start + anchored_layer_count - 1
                        anchor_layers = list(range(first_layer, last_layer + 1))
                        for layer_index in anchor_layers:
                            pattern[layer_index] = SLOTS_PER_SHELF
                        compact_order = build_compact_layer_order(
                            layer_count=layer_count,
                            first_layer=first_layer,
                            last_layer=last_layer,
                            prefer_lower_layers=prefer_lower_layers,
                        )

                    remaining_count = item_count - sum(pattern)
                    for layer_index in compact_order:
                        if remaining_count <= 0:
                            break
                        soft_room = max(
                            0,
                            min(scatter_limit, per_layer_limit) - pattern[layer_index],
                        )
                        added_count = min(remaining_count, soft_room)
                        pattern[layer_index] += added_count
                        remaining_count -= added_count

                    overflow_order = compact_order + anchor_layers
                    for layer_index in overflow_order:
                        if remaining_count <= 0:
                            break
                        hard_room = max(0, per_layer_limit - pattern[layer_index])
                        added_count = min(remaining_count, hard_room)
                        pattern[layer_index] += added_count
                        remaining_count -= added_count

                    if remaining_count == 0:
                        pattern_keys.add(tuple(pattern))

    return sorted(pattern_keys)


def allocate_preferred_local_triples(
    item_counts: Counter[str],
    item_limits: dict[str, int],
    target_triple_count: int,
    filled_layer_count: int,
    rng: random.Random,
) -> dict[str, int]:
    capacities = {
        item_id: min(
            item_count // SLOTS_PER_SHELF,
            filled_layer_count * (item_limits[item_id] // SLOTS_PER_SHELF),
        )
        for item_id, item_count in item_counts.items()
    }
    available_triples = [
        item_id
        for item_id, capacity in capacities.items()
        for _triple_index in range(capacity)
    ]
    rng.shuffle(available_triples)
    selected_triples = available_triples[: min(target_triple_count, len(available_triples))]
    selected_counts = Counter(selected_triples)
    return {
        item_id: selected_counts[item_id]
        for item_id in item_counts
    }


def score_layer_allocation(
    layer_item_counts: list[int],
    layer_ready_triples: list[int],
    target_item_counts: list[int],
    preferred_layer_triple_ratio: float,
    min_front_visible_triples: int,
) -> tuple[int, int, int, int, int, int, int]:
    item_deviations = [
        abs(actual_count - target_count)
        for actual_count, target_count in zip(layer_item_counts, target_item_counts)
    ]
    ratio_deviations = [
        round(
            abs(
                ready_triple_count * SLOTS_PER_SHELF / max(1, item_count)
                - preferred_layer_triple_ratio
            )
            * 10_000
        )
        for item_count, ready_triple_count in zip(layer_item_counts, layer_ready_triples)
    ]
    tolerated_ratio_deviation = round(LAYER_TRIPLE_RATIO_TOLERANCE * 10_000)
    ratio_overages = [
        max(0, deviation - tolerated_ratio_deviation)
        for deviation in ratio_deviations
    ]
    return (
        max(0, min_front_visible_triples - layer_ready_triples[0]),
        max(ratio_overages, default=0),
        sum(ratio_overages),
        max(item_deviations, default=0),
        sum(item_deviations),
        max(ratio_deviations, default=0),
        sum(ratio_deviations),
    )


def build_preferred_layer_item_counts(
    item_counts: Counter[str],
    layer_capacity: int,
    filled_layer_count: int,
    preferred_layer_triple_ratio: float,
    max_same_item_per_layer: int,
    min_front_visible_triples: int,
    rng: random.Random,
) -> list[Counter[str]]:
    filled_slot_count = sum(item_counts.values())
    target_item_counts = build_balanced_layer_targets(
        value_count=filled_slot_count,
        layer_count=filled_layer_count,
        rng=rng,
    )
    target_ready_triple_count = min(
        filled_slot_count // SLOTS_PER_SHELF,
        int(
            math.floor(
                filled_slot_count * preferred_layer_triple_ratio / SLOTS_PER_SHELF + 0.5
            )
        ),
    )
    item_limits = build_layer_item_limits(
        item_counts=item_counts,
        filled_layer_count=filled_layer_count,
        max_same_item_per_layer=max_same_item_per_layer,
    )
    best_item_patterns: dict[str, tuple[int, ...]] | None = None
    best_score: tuple[int, int, int, int, int, int, int] | None = None
    attempt_count = max(12, min(32, len(item_counts)))
    beam_width = 64

    for _attempt_index in range(attempt_count):
        target_ready_triples = build_balanced_layer_targets(
            value_count=target_ready_triple_count,
            layer_count=filled_layer_count,
            rng=rng,
        )
        if target_ready_triples[0] < min_front_visible_triples:
            needed_front_triples = min_front_visible_triples - target_ready_triples[0]
            target_ready_triples[0] += needed_front_triples
            for layer_index in range(filled_layer_count - 1, 0, -1):
                moved_count = min(needed_front_triples, target_ready_triples[layer_index])
                target_ready_triples[layer_index] -= moved_count
                needed_front_triples -= moved_count
                if needed_front_triples == 0:
                    break
        preferred_triples = allocate_preferred_local_triples(
            item_counts=item_counts,
            item_limits=item_limits,
            target_triple_count=sum(target_ready_triples),
            filled_layer_count=filled_layer_count,
            rng=rng,
        )
        item_order = list(item_counts)
        rng.shuffle(item_order)
        patterns_by_item = {
            item_id: build_compact_item_patterns(
                item_count=item_counts[item_id],
                preferred_local_triples=preferred_triples[item_id],
                layer_count=filled_layer_count,
                per_layer_limit=item_limits[item_id],
            )
            for item_id in item_order
        }
        item_order.sort(
            key=lambda item_id: (
                len(patterns_by_item[item_id]),
                -item_counts[item_id],
            )
        )
        beam: list[
            tuple[
                tuple[int, ...],
                tuple[int, ...],
                dict[str, tuple[int, ...]],
                int,
            ]
        ] = [
            (
                tuple(0 for _layer_index in range(filled_layer_count)),
                tuple(0 for _layer_index in range(filled_layer_count)),
                {},
                0,
            )
        ]

        for item_id in item_order:
            expanded_states: dict[
                tuple[tuple[int, ...], tuple[int, ...]],
                tuple[
                    tuple[int, ...],
                    tuple[int, ...],
                    dict[str, tuple[int, ...]],
                    int,
                ],
            ] = {}
            for layer_item_counts, layer_ready_triples, item_patterns, local_error in beam:
                for pattern in patterns_by_item[item_id]:
                    projected_items = tuple(
                        layer_item_counts[layer_index] + pattern[layer_index]
                        for layer_index in range(filled_layer_count)
                    )
                    if any(count > layer_capacity for count in projected_items):
                        continue

                    pattern_triples = count_ready_triples_in_pattern(pattern)
                    projected_triples = tuple(
                        layer_ready_triples[layer_index] + pattern_triples[layer_index]
                        for layer_index in range(filled_layer_count)
                    )
                    projected_local_error = local_error + abs(
                        sum(pattern_triples) - preferred_triples[item_id]
                    )
                    projected_patterns = dict(item_patterns)
                    projected_patterns[item_id] = pattern
                    state = (
                        projected_items,
                        projected_triples,
                        projected_patterns,
                        projected_local_error,
                    )
                    state_key = projected_items, projected_triples
                    previous_state = expanded_states.get(state_key)
                    if previous_state is None or projected_local_error < previous_state[3]:
                        expanded_states[state_key] = state

            if not expanded_states:
                beam = []
                break

            def quality_score(
                state: tuple[
                    tuple[int, ...],
                    tuple[int, ...],
                    dict[str, tuple[int, ...]],
                    int,
                ],
            ) -> tuple[int, int, int, int, int, int, float]:
                projected_items, projected_triples, _patterns, local_error = state
                triple_overage = sum(
                    max(0, actual_count - target_count)
                    for actual_count, target_count in zip(
                        projected_triples,
                        target_ready_triples,
                    )
                )
                triple_error = sum(
                    abs(actual_count - target_count)
                    for actual_count, target_count in zip(
                        projected_triples,
                        target_ready_triples,
                    )
                )
                item_overage = sum(
                    max(0, actual_count - target_count)
                    for actual_count, target_count in zip(projected_items, target_item_counts)
                )
                largest_item_error = max(
                    (
                        abs(actual_count - target_count)
                        for actual_count, target_count in zip(
                            projected_items,
                            target_item_counts,
                        )
                    ),
                    default=0,
                )
                item_error = sum(
                    abs(actual_count - target_count)
                    for actual_count, target_count in zip(projected_items, target_item_counts)
                )
                return (
                    local_error,
                    triple_overage,
                    triple_error,
                    item_overage,
                    largest_item_error,
                    item_error,
                    rng.random(),
                )

            def feasibility_score(
                state: tuple[
                    tuple[int, ...],
                    tuple[int, ...],
                    dict[str, tuple[int, ...]],
                    int,
                ],
            ) -> tuple[int, int, int, int, int, float]:
                projected_items, projected_triples, _patterns, local_error = state
                item_overage = sum(
                    max(0, actual_count - target_count)
                    for actual_count, target_count in zip(projected_items, target_item_counts)
                )
                largest_item_error = max(
                    (
                        abs(actual_count - target_count)
                        for actual_count, target_count in zip(
                            projected_items,
                            target_item_counts,
                        )
                    ),
                    default=0,
                )
                item_error = sum(
                    abs(actual_count - target_count)
                    for actual_count, target_count in zip(projected_items, target_item_counts)
                )
                triple_error = sum(
                    abs(actual_count - target_count)
                    for actual_count, target_count in zip(
                        projected_triples,
                        target_ready_triples,
                    )
                )
                return (
                    item_overage,
                    largest_item_error,
                    item_error,
                    local_error,
                    triple_error,
                    rng.random(),
                )

            expanded = list(expanded_states.values())
            quality_states = sorted(expanded, key=quality_score)[: beam_width // 2]
            feasibility_states = sorted(expanded, key=feasibility_score)[: beam_width // 2]
            beam = []
            seen_state_keys = set()
            for state in quality_states + feasibility_states:
                state_key = state[0], state[1]
                if state_key not in seen_state_keys:
                    beam.append(state)
                    seen_state_keys.add(state_key)

        if not beam:
            continue

        candidate_state = min(
            beam,
            key=lambda state: score_layer_allocation(
                layer_item_counts=list(state[0]),
                layer_ready_triples=list(state[1]),
                target_item_counts=target_item_counts,
                preferred_layer_triple_ratio=preferred_layer_triple_ratio,
                min_front_visible_triples=min_front_visible_triples,
            ),
        )
        score = score_layer_allocation(
            layer_item_counts=list(candidate_state[0]),
            layer_ready_triples=list(candidate_state[1]),
            target_item_counts=target_item_counts,
            preferred_layer_triple_ratio=preferred_layer_triple_ratio,
            min_front_visible_triples=min_front_visible_triples,
        )
        if best_score is None or score < best_score:
            best_score = score
            best_item_patterns = candidate_state[2]

    if best_item_patterns is None:
        raise ValueError("Could not arrange item copies across adjacent filled layers")

    layer_item_counters: list[Counter[str]] = [Counter() for _ in range(filled_layer_count)]
    for item_id, pattern in best_item_patterns.items():
        for layer_index, count in enumerate(pattern):
            if count > 0:
                layer_item_counters[layer_index][item_id] = count
    return layer_item_counters


def spread_values_across_layers(
    item_pool: list[str],
    empty_slots: int,
    shelf_count: int,
    filled_layer_count: int,
    preferred_layer_triple_ratio: float,
    max_same_item_per_layer: int,
    min_front_visible_triples: int,
    rng: random.Random,
) -> list[str | None]:
    layer_capacity = shelf_count * SLOTS_PER_SHELF
    item_counts = Counter(item_pool)
    layer_item_counts = build_preferred_layer_item_counts(
        item_counts=item_counts,
        layer_capacity=layer_capacity,
        filled_layer_count=filled_layer_count,
        preferred_layer_triple_ratio=preferred_layer_triple_ratio,
        max_same_item_per_layer=max_same_item_per_layer,
        min_front_visible_triples=min_front_visible_triples,
        rng=rng,
    )
    layer_values: list[list[str | None]] = []
    for item_counter in layer_item_counts:
        values = [
            item_id
            for item_id, count in item_counter.items()
            for _copy_index in range(count)
        ]
        values.extend([None] * (layer_capacity - len(values)))
        rng.shuffle(values)
        layer_values.append(values)

    if sum(value is None for values in layer_values for value in values) != empty_slots:
        raise ValueError("Layer allocation produced an unexpected empty-slot count")

    return rebuild_values_from_layers(
        layer_values=layer_values,
        shelf_count=shelf_count,
        filled_layer_count=filled_layer_count,
    )


def count_front_visible_triple_candidates(shelves: list[dict[str, Any]]) -> int:
    front_counts: Counter[str] = Counter()
    for shelf in shelves:
        layers = shelf["layers"]
        if not layers:
            continue

        front_counts.update(item_id for item_id in layers[0] if item_id is not None)

    return sum(1 for count in front_counts.values() if count >= SLOTS_PER_SHELF)


def ensure_min_front_visible_triples(
    eligible_slot_values: list[str | None],
    shelf_count: int,
    filled_layer_count: int,
    min_front_visible_triples: int,
    max_same_item_per_layer: int,
    rng: random.Random,
) -> None:
    if min_front_visible_triples <= 0:
        return

    layer_values = split_values_by_layer(
        eligible_slot_values=eligible_slot_values,
        shelf_count=shelf_count,
        filled_layer_count=filled_layer_count,
    )
    item_counts = Counter(value for values in layer_values for value in values if value is not None)
    item_limits = build_layer_item_limits(
        item_counts=item_counts,
        filled_layer_count=filled_layer_count,
        max_same_item_per_layer=max_same_item_per_layer,
    )
    front_counts = Counter(value for value in layer_values[0] if value is not None)
    satisfied_items = {item_id for item_id, count in front_counts.items() if count >= SLOTS_PER_SHELF}
    needed_count = min_front_visible_triples - len(satisfied_items)
    if needed_count <= 0:
        return

    candidate_items = [
        item_id
        for item_id, count in item_counts.items()
        if count >= SLOTS_PER_SHELF and item_id not in satisfied_items
    ]
    rng.shuffle(candidate_items)

    for item_id in candidate_items:
        if needed_count <= 0:
            break
        if front_counts[item_id] >= SLOTS_PER_SHELF:
            continue

        moved_count = move_item_copies_to_front_layer(
            layer_values=layer_values,
            front_counts=front_counts,
            item_limits=item_limits,
            item_id=item_id,
            rng=rng,
        )
        if moved_count > 0 and front_counts[item_id] >= SLOTS_PER_SHELF:
            satisfied_items.add(item_id)
            needed_count -= 1

    if needed_count > 0:
        possible_count = len(satisfied_items)
        raise ValueError(
            f"Could not satisfy --min-front-visible-triples={min_front_visible_triples}; "
            f"only {possible_count} visible triple candidates could be arranged"
        )

    eligible_slot_values[:] = rebuild_values_from_layers(
        layer_values=layer_values,
        shelf_count=shelf_count,
        filled_layer_count=filled_layer_count,
    )


def move_item_copies_to_front_layer(
    layer_values: list[list[str | None]],
    front_counts: Counter[str],
    item_limits: dict[str, int],
    item_id: str,
    rng: random.Random,
) -> int:
    moved_count = 0

    while front_counts[item_id] < SLOTS_PER_SHELF:
        move = find_front_layer_swap(
            layer_values=layer_values,
            front_counts=front_counts,
            item_limits=item_limits,
            item_id=item_id,
            rng=rng,
        )
        if move is None:
            break

        target_position, source_layer_index, source_position = move
        swapped_item = layer_values[0][target_position]
        layer_values[0][target_position] = item_id
        layer_values[source_layer_index][source_position] = swapped_item
        front_counts[item_id] += 1
        if swapped_item is not None:
            front_counts[swapped_item] -= 1
        moved_count += 1

    return moved_count


def find_front_layer_swap(
    layer_values: list[list[str | None]],
    front_counts: Counter[str],
    item_limits: dict[str, int],
    item_id: str,
    rng: random.Random,
) -> tuple[int, int, int] | None:
    source_candidates = []
    for layer_index in range(1, len(layer_values)):
        for source_position, source_item_id in enumerate(layer_values[layer_index]):
            if source_item_id == item_id:
                source_candidates.append((layer_index, source_position))
    rng.shuffle(source_candidates)
    source_candidates.sort(key=lambda candidate: candidate[0])

    target_positions = [
        target_position
        for target_position, target_item_id in enumerate(layer_values[0])
        if target_item_id != item_id
        and (target_item_id is None or front_counts[target_item_id] != SLOTS_PER_SHELF)
    ]
    rng.shuffle(target_positions)

    layer_counts = [
        Counter(value for value in values if value is not None)
        for values in layer_values
    ]
    for target_position in target_positions:
        swapped_item = layer_values[0][target_position]
        for source_layer_index, source_position in source_candidates:
            if swapped_item is None:
                return target_position, source_layer_index, source_position
            if layer_counts[source_layer_index][swapped_item] < item_limits[swapped_item]:
                return target_position, source_layer_index, source_position

    return None


def flatten_shelves(shelves: list[dict[str, Any]]) -> list[str | None]:
    values = []
    for shelf in shelves:
        for layer in shelf["layers"]:
            values.extend(layer)
    return values


def build_layer_item_counts(
    shelves: list[dict[str, Any]],
    filled_layer_count: int,
) -> list[Counter[str]]:
    layer_counts: list[Counter[str]] = [Counter() for _ in range(filled_layer_count)]
    for shelf in shelves:
        for layer_index, layer in enumerate(shelf["layers"][:filled_layer_count]):
            layer_counts[layer_index].update(value for value in layer if value is not None)

    return layer_counts


def build_layer_triple_readiness(
    shelves: list[dict[str, Any]],
    filled_layer_count: int,
) -> list[dict[str, int | float]]:
    readiness = []
    for layer_index, layer_counts in enumerate(
        build_layer_item_counts(shelves, filled_layer_count)
    ):
        filled_item_count = sum(layer_counts.values())
        ready_triple_count = sum(
            count // SLOTS_PER_SHELF
            for count in layer_counts.values()
        )
        ready_item_count = ready_triple_count * SLOTS_PER_SHELF
        ready_ratio = ready_item_count / filled_item_count if filled_item_count > 0 else 0.0
        readiness.append(
            {
                "layer": layer_index + 1,
                "filled_items": filled_item_count,
                "triple_ready_items": ready_item_count,
                "triple_ready_count": ready_triple_count,
                "triple_ready_ratio": round(ready_ratio, 4),
            }
        )
    return readiness


def find_non_adjacent_item_spreads(
    shelves: list[dict[str, Any]],
    filled_layer_count: int,
) -> dict[str, list[int]]:
    layer_counts = build_layer_item_counts(shelves, filled_layer_count)
    item_ids = sorted(
        {
            item_id
            for counts in layer_counts
            for item_id in counts
        }
    )
    non_adjacent_spreads = {}
    for item_id in item_ids:
        occupied_layers = [
            layer_index + 1
            for layer_index, counts in enumerate(layer_counts)
            if counts[item_id] > 0
        ]
        if occupied_layers and occupied_layers[-1] - occupied_layers[0] + 1 != len(occupied_layers):
            non_adjacent_spreads[item_id] = occupied_layers
    return non_adjacent_spreads


def build_layer_item_limits(
    item_counts: Counter[str],
    filled_layer_count: int,
    max_same_item_per_layer: int,
) -> dict[str, int]:
    if filled_layer_count <= 0:
        return {}

    return {
        item_id: max(max_same_item_per_layer, (count + filled_layer_count - 1) // filled_layer_count)
        for item_id, count in item_counts.items()
    }


def find_layer_item_overloads(
    shelves: list[dict[str, Any]],
    filled_layer_count: int,
    max_same_item_per_layer: int,
) -> dict[str, dict[str, int]]:
    item_counts = Counter(value for value in flatten_shelves(shelves) if value is not None)
    item_limits = build_layer_item_limits(
        item_counts=item_counts,
        filled_layer_count=filled_layer_count,
        max_same_item_per_layer=max_same_item_per_layer,
    )
    overloads: dict[str, dict[str, int]] = {}

    for layer_index, layer_counts in enumerate(build_layer_item_counts(shelves, filled_layer_count)):
        layer_overloads = {
            item_id: count
            for item_id, count in sorted(layer_counts.items())
            if count > item_limits[item_id]
        }
        if layer_overloads:
            overloads[str(layer_index)] = layer_overloads

    return overloads


def score_layer_item_spread(
    shelves: list[dict[str, Any]],
    filled_layer_count: int,
    max_same_item_per_layer: int,
) -> tuple[int, int, int]:
    item_counts = Counter(value for value in flatten_shelves(shelves) if value is not None)
    item_limits = build_layer_item_limits(
        item_counts=item_counts,
        filled_layer_count=filled_layer_count,
        max_same_item_per_layer=max_same_item_per_layer,
    )
    total_overage = 0
    largest_overage = 0
    largest_layer_count = 0

    for layer_counts in build_layer_item_counts(shelves, filled_layer_count):
        for item_id, count in layer_counts.items():
            largest_layer_count = max(largest_layer_count, count)
            overage = max(0, count - item_limits[item_id])
            total_overage += overage
            largest_overage = max(largest_overage, overage)

    return total_overage, largest_overage, largest_layer_count


def score_layout_constraints(
    shelves: list[dict[str, Any]],
    filled_layer_count: int,
    preset: DifficultyPreset,
) -> tuple[int, int, int, int]:
    front_match_count = 0
    if not preset.allow_front_layer_matches:
        front_match_count = count_front_layer_matches(shelves)

    layer_overage, largest_overage, largest_layer_count = score_layer_item_spread(
        shelves=shelves,
        filled_layer_count=filled_layer_count,
        max_same_item_per_layer=preset.max_same_item_per_layer,
    )
    return front_match_count, layer_overage, largest_overage, largest_layer_count


def reshuffle_for_layout_constraints(
    eligible_slot_values: list[str | None],
    shelf_count: int,
    layer_count: int,
    filled_layer_count: int,
    preset: DifficultyPreset,
    rng: random.Random,
    max_attempts: int,
) -> list[dict[str, Any]]:
    shelves = compose_shelves(
        eligible_slot_values=eligible_slot_values,
        shelf_count=shelf_count,
        layer_count=layer_count,
        filled_layer_count=filled_layer_count,
    )
    best_shelves = shelves
    best_score = score_layout_constraints(
        shelves=shelves,
        filled_layer_count=filled_layer_count,
        preset=preset,
    )
    for _attempt in range(max_attempts):
        if best_score[:3] == (0, 0, 0):
            return best_shelves

        shuffle_values_within_layers(
            eligible_slot_values=eligible_slot_values,
            shelf_count=shelf_count,
            filled_layer_count=filled_layer_count,
            rng=rng,
        )
        shelves = compose_shelves(
            eligible_slot_values=eligible_slot_values,
            shelf_count=shelf_count,
            layer_count=layer_count,
            filled_layer_count=filled_layer_count,
        )
        score = score_layout_constraints(
            shelves=shelves,
            filled_layer_count=filled_layer_count,
            preset=preset,
        )
        if score < best_score:
            best_shelves = shelves
            best_score = score

    return best_shelves


def build_stats(
    shelves: list[dict[str, Any]],
    difficulty: str,
    seed: int | None,
    shelf_count: int,
    layer_count: int,
    filled_layer_count: int,
    preset: DifficultyPreset,
    max_items_per_type_override: int | None,
    min_front_visible_triples: int,
    target_filled_slots: int,
    item_type_count: int,
    item_type_count_source: str,
    preferred_copies_per_type: float,
) -> dict[str, Any]:
    values = flatten_shelves(shelves)
    item_counts = Counter(value for value in values if value is not None)
    invalid_counts = {
        item_id: count
        for item_id, count in sorted(item_counts.items())
        if count % SLOTS_PER_SHELF != 0
    }
    effective_max_items_per_type = calculate_max_items_per_type(
        preset=preset,
        max_items_per_type_override=max_items_per_type_override,
    )

    return {
        "difficulty": difficulty,
        "seed": seed,
        "shelf_count": shelf_count,
        "layer_count": layer_count,
        "filled_layer_count": filled_layer_count,
        "total_slots": len(values),
        "target_filled_slots": target_filled_slots,
        "filled_slots": sum(1 for value in values if value is not None),
        "empty_slots": sum(1 for value in values if value is None),
        "item_type_count": item_type_count,
        "item_type_count_source": item_type_count_source,
        "preferred_copies_per_type": preferred_copies_per_type,
        "item_cap_added_empty_slots": target_filled_slots - sum(1 for value in values if value is not None),
        "item_counts": dict(sorted(item_counts.items())),
        "invalid_item_counts": invalid_counts,
        "preferred_layer_triple_ratio": preset.preferred_layer_triple_ratio,
        "max_same_item_per_layer": preset.max_same_item_per_layer,
        "preset_max_items_per_type": preset.max_items_per_type,
        "requested_max_items_per_type": max_items_per_type_override,
        "effective_max_items_per_type": effective_max_items_per_type,
        "min_front_visible_triples": min_front_visible_triples,
        "front_visible_triple_candidates": count_front_visible_triple_candidates(shelves),
        "layer_item_counts": [
            dict(sorted(layer_counts.items()))
            for layer_counts in build_layer_item_counts(shelves, filled_layer_count)
        ],
        "layer_triple_readiness": build_layer_triple_readiness(
            shelves=shelves,
            filled_layer_count=filled_layer_count,
        ),
        "non_adjacent_item_spreads": find_non_adjacent_item_spreads(
            shelves=shelves,
            filled_layer_count=filled_layer_count,
        ),
        "layer_item_overloads": find_layer_item_overloads(
            shelves=shelves,
            filled_layer_count=filled_layer_count,
            max_same_item_per_layer=preset.max_same_item_per_layer,
        ),
        "front_layer_matches": would_create_front_match(shelves),
        "front_layer_match_count": count_front_layer_matches(shelves),
    }


def build_collapsing_stats(
    shelves: list[dict[str, Any]],
    column_heights: list[int] | None,
    visible_shelves_per_column: int | None,
) -> dict[str, Any]:
    if not column_heights:
        return {"gameplay_mode": GAMEPLAY_MODE_CLASSIC}

    visible_count = int(visible_shelves_per_column or 1)
    active_shelf_count = sum(min(visible_count, height) for height in column_heights)
    total_shelf_count = sum(column_heights)
    return {
        "gameplay_mode": GAMEPLAY_MODE_COLLAPSING_COLUMNS,
        "column_heights": list(column_heights),
        "visible_shelves_per_column": visible_count,
        "total_shelf_count": total_shelf_count,
        "active_shelf_count": active_shelf_count,
        "hidden_shelf_count": total_shelf_count - active_shelf_count,
        "active_occupied_slots": sum(
            1
            for shelf in active_collapsing_shelves(shelves, column_heights, visible_count)
            for item_id in shelf["layers"][0]
            if item_id is not None
        ),
    }


def wrap_level(
    shelves: list[dict[str, Any]],
    level_number: int,
    time_seconds: int,
    layout_preset: str,
    seed: int | None,
    difficulty: str,
    column_heights: list[int] | None = None,
    visible_shelves_per_column: int | None = None,
) -> dict[str, Any]:
    # `layout_preset` and the column contract are mutually exclusive, so a collapsing level must not
    # carry a preset it would be rejected for.
    if column_heights:
        return {
            "level": level_number,
            "time_seconds": time_seconds,
            "gameplay_mode": GAMEPLAY_MODE_COLLAPSING_COLUMNS,
            "column_layout": {
                COLUMN_SHELF_COUNTS_KEY: list(column_heights),
                COLUMN_VISIBLE_SHELVES_KEY: int(visible_shelves_per_column or 1),
            },
            "seed": seed,
            "difficulty": difficulty,
            "shelves": shelves,
        }

    return {
        "level": level_number,
        "time_seconds": time_seconds,
        "layout_preset": layout_preset,
        "seed": seed,
        "difficulty": difficulty,
        "shelves": shelves,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate the shelves array for a Sorting Puzzle level JSON file."
    )
    parser.add_argument(
        "--gameplay-mode",
        choices=sorted((GAMEPLAY_MODE_CLASSIC, GAMEPLAY_MODE_COLLAPSING_COLUMNS)),
        default=GAMEPLAY_MODE_CLASSIC,
    )
    parser.add_argument(
        "--column-heights",
        help=(
            "Comma-separated shelf count per collapsing column, left to right, such as 8,8,8. "
            "Determines --shelf-count, which must not also be given."
        ),
    )
    parser.add_argument(
        "--visible-shelves-per-column",
        type=int,
        help=(
            "Guaranteed minimum shelves revealed per collapsing column on every viewport. "
            "This is the window the solvability proof is made against."
        ),
    )
    parser.add_argument("--shelf-count", type=int)
    parser.add_argument("--layer-count", type=int)
    parser.add_argument(
        "--filled-layer-count",
        type=int,
        help="Number of top layers that can contain generated items. Defaults to --layer-count.",
    )
    parser.add_argument(
        "--item-type-count",
        type=int,
        help=(
            "Number of abstract item_NN identities available to the generated level. "
            "When omitted, infer it from the target filled slots and --preferred-copies-per-type."
        ),
    )
    parser.add_argument(
        "--preferred-copies-per-type",
        type=float,
        default=DEFAULT_PREFERRED_COPIES_PER_TYPE,
        help=(
            "Target average copies per item type when --item-type-count is omitted. "
            f"Accepts fractional values and defaults to {DEFAULT_PREFERRED_COPIES_PER_TYPE:g}."
        ),
    )
    parser.add_argument(
        "--difficulty",
        choices=sorted(DIFFICULTIES),
        default="medium",
    )
    parser.add_argument("--seed", type=int)
    parser.add_argument("--output", type=Path, help="Write JSON to this path instead of stdout.")
    parser.add_argument(
        "--full-level",
        action="store_true",
        help="Output a full level JSON object instead of only the shelves array.",
    )
    parser.add_argument("--level-number", type=int, default=1)
    parser.add_argument("--time-seconds", type=int, default=300)
    # No argparse default: `collapsing_columns` must be able to tell an omitted preset from an
    # explicitly requested one, because a preset and the column contract are mutually exclusive.
    parser.add_argument("--layout-preset", choices=LAYOUT_PRESETS)
    parser.add_argument("--stats", action="store_true", help="Print generation stats to stderr.")
    parser.add_argument("--sticky-items-percent", type=float, default=0.0,
                        help="Percent of occupied items made sticky (0-100, default 0); at most one per standard shelf layer.")
    parser.add_argument("--validate", action="store_true", help="Run the solvability validator once after generation.")
    parser.add_argument(
        "--require-solvable",
        action="store_true",
        help="Retry generation until the validator finds a solvable layout or attempts run out.",
    )
    parser.add_argument("--max-generation-attempts", type=int, default=25)
    parser.add_argument("--validator-max-states", type=int, default=20_000)
    parser.add_argument("--validator-max-depth", type=int, default=200)
    parser.add_argument(
        "--max-items-per-type",
        type=int,
        help=(
            "Optional global cap for generated item copies per type. "
            "The effective value is rounded down to a multiple of three."
        ),
    )
    parser.add_argument(
        "--min-front-visible-triples",
        type=int,
        default=1,
        help=(
            "Minimum number of item types with at least three visible front-layer copies. "
            "Use 0 to disable this starter-progress guarantee."
        ),
    )
    parser.add_argument(
        "--dispenser-shelves",
        help=(
            "Comma-separated 1-based dispenser shelf positions and layer counts, such as 10:3,11:4. "
            "Each becomes a source-only shelf holding that many items, counted against --shelf-count."
        ),
    )
    parser.add_argument(
        "--locked-shelves",
        help=(
            "Comma-separated 1-based shelf unlock requirements, such as 7:3,8:5. "
            "Each shelf unlocks after that many cleared triples."
        ),
    )
    args = parser.parse_args()
    validate_mode_arguments(parser, args)
    return args


## Mode conflicts are rejected here rather than being quietly reconciled. Silently accepting, say, a
## dispenser request under collapsing columns would produce content the solver cannot prove.
def validate_mode_arguments(parser: argparse.ArgumentParser, args: argparse.Namespace) -> None:
    if args.gameplay_mode != GAMEPLAY_MODE_COLLAPSING_COLUMNS:
        if args.column_heights is not None:
            parser.error(
                f"--column-heights requires --gameplay-mode {GAMEPLAY_MODE_COLLAPSING_COLUMNS}"
            )
        if args.visible_shelves_per_column is not None:
            parser.error(
                "--visible-shelves-per-column requires --gameplay-mode "
                f"{GAMEPLAY_MODE_COLLAPSING_COLUMNS}"
            )
        if args.shelf_count is None:
            parser.error("--shelf-count is required")
        if args.layer_count is None:
            parser.error("--layer-count is required")
        return

    if args.column_heights is None:
        parser.error(
            f"--gameplay-mode {GAMEPLAY_MODE_COLLAPSING_COLUMNS} requires --column-heights"
        )
    if args.shelf_count is not None:
        parser.error("--column-heights determines the shelf count; do not also pass --shelf-count")
    if args.visible_shelves_per_column is None:
        parser.error(
            f"--gameplay-mode {GAMEPLAY_MODE_COLLAPSING_COLUMNS} requires "
            "--visible-shelves-per-column"
        )
    if not 1 <= args.visible_shelves_per_column <= MAX_VISIBLE_SHELVES_PER_COLUMN:
        parser.error(
            "--visible-shelves-per-column must be between 1 and "
            f"{MAX_VISIBLE_SHELVES_PER_COLUMN}"
        )
    for layer_argument, value in (
        ("--layer-count", args.layer_count),
        ("--filled-layer-count", args.filled_layer_count),
    ):
        if value is not None and value != COLLAPSING_LAYER_COUNT:
            parser.error(
                f"{layer_argument} must be {COLLAPSING_LAYER_COUNT} for "
                f"--gameplay-mode {GAMEPLAY_MODE_COLLAPSING_COLUMNS}"
            )
    if args.dispenser_shelves:
        parser.error(
            f"--dispenser-shelves is not supported by --gameplay-mode "
            f"{GAMEPLAY_MODE_COLLAPSING_COLUMNS}"
        )
    if args.locked_shelves:
        parser.error(
            f"--locked-shelves is not supported by --gameplay-mode "
            f"{GAMEPLAY_MODE_COLLAPSING_COLUMNS}"
        )
    if args.sticky_items_percent:
        parser.error(
            f"--sticky-items-percent is not supported by --gameplay-mode "
            f"{GAMEPLAY_MODE_COLLAPSING_COLUMNS}"
        )
    if args.layout_preset is not None:
        parser.error(
            f"--layout-preset cannot be combined with --gameplay-mode "
            f"{GAMEPLAY_MODE_COLLAPSING_COLUMNS}"
        )


def main() -> int:
    args = parse_args()
    is_collapsing = args.gameplay_mode == GAMEPLAY_MODE_COLLAPSING_COLUMNS
    layer_count = COLLAPSING_LAYER_COUNT if is_collapsing else args.layer_count
    filled_layer_count = args.filled_layer_count
    if filled_layer_count is None:
        filled_layer_count = layer_count

    try:
        column_heights = parse_column_heights(args.column_heights) if is_collapsing else None
        shelf_count = sum(column_heights) if column_heights else args.shelf_count
        item_types = None
        if args.item_type_count is not None:
            item_types = logical_item_ids(args.item_type_count)
        locked_shelves = parse_locked_shelves(args.locked_shelves)
        dispenser_shelves = parse_dispenser_shelves(args.dispenser_shelves)
        shelves, stats, validation, used_seed = generate_with_optional_validation(
            shelf_count=shelf_count,
            layer_count=layer_count,
            filled_layer_count=filled_layer_count,
            item_types=item_types,
            difficulty=args.difficulty,
            seed=args.seed,
            should_validate=args.validate,
            require_solvable=args.require_solvable,
            max_attempts=args.max_generation_attempts,
            max_items_per_type_override=args.max_items_per_type,
            min_front_visible_triples=args.min_front_visible_triples,
            max_states=args.validator_max_states,
            max_depth=args.validator_max_depth,
            preferred_copies_per_type=args.preferred_copies_per_type,
            locked_shelves=locked_shelves,
            dispenser_shelves=dispenser_shelves,
            sticky_items_percent=args.sticky_items_percent,
            column_heights=column_heights,
            visible_shelves_per_column=args.visible_shelves_per_column,
        )
    except (OSError, ValueError, KeyError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if args.require_solvable and (validation is None or validation["solvable"] is not True):
        if args.stats:
            print(json.dumps(stats, indent=2), file=sys.stderr)
        print("error: could not generate a solvable level within the attempt limit", file=sys.stderr)
        return 3

    output_data: Any = shelves
    sticky_stats = stats.get("sticky_items", {})
    if args.sticky_items_percent > 0 and (validation is None or validation["solvable"] is not True):
        reason = validation["reason"] if validation is not None else "validation not requested"
        print(f"warning: sticky layout has no solvability proof ({reason}); use --require-solvable",
              file=sys.stderr)
    if sticky_stats.get("cap_reason"):
        print(f"warning: sticky count capped to {sticky_stats['target_count']} occupied standard "
              f"layers ({sticky_stats['effective_percent']:.2f}% effective)", file=sys.stderr)
    if args.full_level:
        output_data = wrap_level(
            shelves=shelves,
            level_number=args.level_number,
            time_seconds=args.time_seconds,
            layout_preset=args.layout_preset or DEFAULT_LAYOUT_PRESET,
            seed=used_seed,
            difficulty=args.difficulty,
            column_heights=column_heights,
            visible_shelves_per_column=args.visible_shelves_per_column,
        )
        if args.sticky_items_percent > 0:
            output_data["sticky_items_percent"] = args.sticky_items_percent

    output_text = json.dumps(output_data, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output_text + "\n", encoding="utf-8")
    else:
        print(output_text)

    if args.stats:
        print(json.dumps(stats, indent=2), file=sys.stderr)

    if stats["invalid_item_counts"]:
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
