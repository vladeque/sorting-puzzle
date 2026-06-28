#!/usr/bin/env python3
"""Generate Sorting Puzzle shelf layouts for level JSON files."""

from __future__ import annotations

import argparse
import json
import random
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from validate_level_solvable import load_item_ids as load_known_item_ids
from validate_level_solvable import solve_level, shelves_to_state, validate_shelves_shape


SLOTS_PER_SHELF = 3
DEFAULT_ITEM_CONFIG = Path("configs/item_sprites.json")
LAYOUT_PRESETS = (
    "grid_2x3",
    "grid_3x3",
    "grid_3x4",
    "grid_3x5",
    "grid_4x3",
    "staggered_5_4_5",
    "staggered_4_5_4",
)


@dataclass(frozen=True)
class DifficultyPreset:
    empty_ratio_min: float
    empty_ratio_max: float
    max_same_item_per_layer: int
    max_items_per_type: int | None
    allow_front_layer_matches: bool
    shuffle_passes: int


DIFFICULTIES = {
    "easy": DifficultyPreset(
        empty_ratio_min=0.22,
        empty_ratio_max=0.32,
        max_same_item_per_layer=5,
        max_items_per_type=None,
        allow_front_layer_matches=True,
        shuffle_passes=1,
    ),
    "medium": DifficultyPreset(
        empty_ratio_min=0.12,
        empty_ratio_max=0.20,
        max_same_item_per_layer=4,
        max_items_per_type=None,
        allow_front_layer_matches=True,
        shuffle_passes=2,
    ),
    "hard": DifficultyPreset(
        empty_ratio_min=0.10,
        empty_ratio_max=0.15,
        max_same_item_per_layer=3,
        max_items_per_type=None,
        allow_front_layer_matches=False,
        shuffle_passes=4,
    ),
    "expert": DifficultyPreset(
        empty_ratio_min=0.05,
        empty_ratio_max=0.10,
        max_same_item_per_layer=3,
        max_items_per_type=None,
        allow_front_layer_matches=False,
        shuffle_passes=6,
    ),
}


def load_item_ids(item_config_path: Path) -> list[str]:
    with item_config_path.open("r", encoding="utf-8") as config_file:
        config = json.load(config_file)

    item_ids = []
    for item in config.get("items", []):
        item_id = item.get("id")
        if isinstance(item_id, str) and item_id:
            item_ids.append(item_id)

    if not item_ids:
        raise ValueError(f"No items found in {item_config_path}")

    return item_ids


def parse_item_types(raw_item_types: str | None, item_config_path: Path) -> list[str]:
    if raw_item_types:
        item_ids = [item_id.strip() for item_id in raw_item_types.split(",")]
        item_ids = [item_id for item_id in item_ids if item_id]
        if not item_ids:
            raise ValueError("--item-types did not contain any item IDs")
        return item_ids

    return load_item_ids(item_config_path)


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


def round_down_to_triple_count(item_count: int) -> int:
    return item_count - (item_count % SLOTS_PER_SHELF)


def calculate_max_items_per_type(
    preset: DifficultyPreset,
    filled_layer_count: int,
    max_items_per_type_override: int | None,
) -> int:
    derived_max_items = preset.max_same_item_per_layer * filled_layer_count
    configured_limits = [derived_max_items]
    if preset.max_items_per_type is not None:
        configured_limits.append(preset.max_items_per_type)
    if max_items_per_type_override is not None:
        configured_limits.append(max_items_per_type_override)

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
    item_types: list[str],
    difficulty: str,
    seed: int | None,
    max_items_per_type_override: int | None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if shelf_count <= 0:
        raise ValueError("--shelf-count must be greater than 0")
    if layer_count <= 0:
        raise ValueError("--layer-count must be greater than 0")
    if filled_layer_count <= 0 or filled_layer_count > layer_count:
        raise ValueError("--filled-layer-count must be between 1 and --layer-count")

    preset = DIFFICULTIES[difficulty]
    rng = random.Random(seed)
    eligible_slots = shelf_count * filled_layer_count * SLOTS_PER_SHELF
    target_filled_slots = calculate_filled_slots(eligible_slots, preset, rng)
    max_items_per_type = calculate_max_items_per_type(
        preset=preset,
        filled_layer_count=filled_layer_count,
        max_items_per_type_override=max_items_per_type_override,
    )
    filled_slots = min(target_filled_slots, len(item_types) * max_items_per_type)
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
        target_filled_slots=target_filled_slots,
    )
    return shelves, stats


def validate_generated_shelves(
    shelves: list[dict[str, Any]],
    item_config_path: Path,
    max_states: int,
    max_depth: int,
) -> dict[str, Any]:
    known_item_ids = load_known_item_ids(item_config_path)
    errors, item_counts = validate_shelves_shape(
        shelves=shelves,
        known_item_ids=known_item_ids,
        skip_known_items=False,
    )
    if errors:
        return {
            "valid": False,
            "errors": errors,
            "item_counts": dict(sorted(item_counts.items())),
            "solvable": None,
            "reason": "invalid",
            "moves": None,
            "states_checked": 0,
            "max_queue_size": 0,
        }

    search_result = solve_level(
        initial_state=shelves_to_state(shelves),
        max_states=max_states,
        max_depth=max_depth,
        keep_solution=False,
    )
    return {
        "valid": True,
        "errors": [],
        "item_counts": dict(sorted(item_counts.items())),
        "solvable": search_result.solvable,
        "reason": search_result.reason,
        "moves": search_result.moves,
        "states_checked": search_result.states_checked,
        "max_queue_size": search_result.max_queue_size,
    }


def generate_with_optional_validation(
    shelf_count: int,
    layer_count: int,
    filled_layer_count: int,
    item_types: list[str],
    difficulty: str,
    seed: int | None,
    should_validate: bool,
    require_solvable: bool,
    max_attempts: int,
    max_items_per_type_override: int | None,
    item_config_path: Path,
    max_states: int,
    max_depth: int,
    locked_shelves: dict[int, int] | None = None,
) -> tuple[list[dict[str, Any]], dict[str, Any], dict[str, Any] | None, int | None]:
    attempts = max(1, max_attempts if require_solvable else 1)
    random_seed_source = random.SystemRandom()
    last_result = None
    locked_shelves = locked_shelves or {}

    for attempt_index in range(attempts):
        attempt_seed = seed + attempt_index if seed is not None else random_seed_source.randrange(1, 2**31)
        shelves, stats = generate_shelves(
            shelf_count=shelf_count,
            layer_count=layer_count,
            filled_layer_count=filled_layer_count,
            item_types=item_types,
            difficulty=difficulty,
            seed=attempt_seed,
            max_items_per_type_override=max_items_per_type_override,
        )
        apply_locked_shelves(shelves, locked_shelves)
        stats["attempt"] = attempt_index + 1
        stats["max_attempts"] = attempts
        stats["locked_shelves"] = {
            str(shelf_number): unlock_after_triples
            for shelf_number, unlock_after_triples in sorted(locked_shelves.items())
        }

        validation = None
        if should_validate or require_solvable:
            validation = validate_generated_shelves(
                shelves=shelves,
                item_config_path=item_config_path,
                max_states=max_states,
                max_depth=max_depth,
            )
            stats["validation"] = validation

        last_result = (shelves, stats, validation, attempt_seed)
        if not require_solvable or (validation is not None and validation["solvable"] is True):
            return last_result

    if last_result is None:
        raise ValueError("Could not generate shelves")

    return last_result


def build_item_pool_with_limit(
    item_types: list[str],
    filled_slots: int,
    max_items_per_type: int,
    rng: random.Random,
) -> list[str]:
    triple_count = filled_slots // SLOTS_PER_SHELF
    max_triples_per_item = max_items_per_type // SLOTS_PER_SHELF
    required_type_count = (triple_count + max_triples_per_item - 1) // max_triples_per_item
    usable_count = min(len(item_types), triple_count, required_type_count)
    if usable_count <= 0:
        raise ValueError("At least one item type and one item triple are required")

    shuffled_item_types = item_types[:]
    rng.shuffle(shuffled_item_types)
    selected_item_types = shuffled_item_types[:usable_count]

    triples_by_item: Counter[str] = Counter()
    for triple_index in range(triple_count):
        triples_by_item[selected_item_types[triple_index % usable_count]] += 1

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


def spread_values_across_layers(
    item_pool: list[str],
    empty_slots: int,
    shelf_count: int,
    filled_layer_count: int,
    max_same_item_per_layer: int,
    rng: random.Random,
) -> list[str | None]:
    layer_capacity = shelf_count * SLOTS_PER_SHELF
    layer_values: list[list[str | None]] = [[] for _ in range(filled_layer_count)]
    layer_item_counts: list[Counter[str]] = [Counter() for _ in range(filled_layer_count)]
    item_counts = Counter(item_pool)
    item_limits = build_layer_item_limits(
        item_counts=item_counts,
        filled_layer_count=filled_layer_count,
        max_same_item_per_layer=max_same_item_per_layer,
    )
    shuffled_item_ids = list(item_counts)
    rng.shuffle(shuffled_item_ids)

    for item_id in shuffled_item_ids:
        for _copy_index in range(item_counts[item_id]):
            candidates = [
                layer_index
                for layer_index in range(filled_layer_count)
                if len(layer_values[layer_index]) < layer_capacity
                and layer_item_counts[layer_index][item_id] < item_limits[item_id]
            ]
            if not candidates:
                candidates = [
                    layer_index
                    for layer_index in range(filled_layer_count)
                    if len(layer_values[layer_index]) < layer_capacity
                ]

            candidates.sort(
                key=lambda layer_index: (
                    layer_item_counts[layer_index][item_id],
                    len(layer_values[layer_index]),
                    rng.random(),
                )
            )
            layer_index = candidates[0]
            layer_values[layer_index].append(item_id)
            layer_item_counts[layer_index][item_id] += 1

    for _empty_index in range(empty_slots):
        candidates = [
            layer_index
            for layer_index in range(filled_layer_count)
            if len(layer_values[layer_index]) < layer_capacity
        ]
        candidates.sort(key=lambda layer_index: (len(layer_values[layer_index]), rng.random()))
        layer_values[candidates[0]].append(None)

    for values in layer_values:
        rng.shuffle(values)

    return rebuild_values_from_layers(
        layer_values=layer_values,
        shelf_count=shelf_count,
        filled_layer_count=filled_layer_count,
    )


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
    target_filled_slots: int,
) -> dict[str, Any]:
    values = flatten_shelves(shelves)
    item_counts = Counter(value for value in values if value is not None)
    invalid_counts = {
        item_id: count
        for item_id, count in sorted(item_counts.items())
        if count % SLOTS_PER_SHELF != 0
    }
    derived_max_items_per_type = round_down_to_triple_count(
        preset.max_same_item_per_layer * filled_layer_count
    )
    effective_max_items_per_type = calculate_max_items_per_type(
        preset=preset,
        filled_layer_count=filled_layer_count,
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
        "item_cap_added_empty_slots": target_filled_slots - sum(1 for value in values if value is not None),
        "item_counts": dict(sorted(item_counts.items())),
        "invalid_item_counts": invalid_counts,
        "max_same_item_per_layer": preset.max_same_item_per_layer,
        "derived_max_items_per_type": derived_max_items_per_type,
        "preset_max_items_per_type": preset.max_items_per_type,
        "requested_max_items_per_type": max_items_per_type_override,
        "effective_max_items_per_type": effective_max_items_per_type,
        "layer_item_counts": [
            dict(sorted(layer_counts.items()))
            for layer_counts in build_layer_item_counts(shelves, filled_layer_count)
        ],
        "layer_item_overloads": find_layer_item_overloads(
            shelves=shelves,
            filled_layer_count=filled_layer_count,
            max_same_item_per_layer=preset.max_same_item_per_layer,
        ),
        "front_layer_matches": would_create_front_match(shelves),
        "front_layer_match_count": count_front_layer_matches(shelves),
    }


def wrap_level(
    shelves: list[dict[str, Any]],
    level_number: int,
    time_seconds: int,
    layout_preset: str,
    seed: int | None,
    difficulty: str,
) -> dict[str, Any]:
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
    parser.add_argument("--shelf-count", type=int, required=True)
    parser.add_argument("--layer-count", type=int, required=True)
    parser.add_argument(
        "--filled-layer-count",
        type=int,
        help="Number of top layers that can contain generated items. Defaults to --layer-count.",
    )
    parser.add_argument(
        "--item-types",
        help="Comma-separated item IDs. Defaults to all IDs from configs/item_sprites.json.",
    )
    parser.add_argument(
        "--item-config",
        type=Path,
        default=DEFAULT_ITEM_CONFIG,
        help="Path to item_sprites.json when --item-types is omitted.",
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
    parser.add_argument("--layout-preset", choices=LAYOUT_PRESETS, default="grid_3x3")
    parser.add_argument("--stats", action="store_true", help="Print generation stats to stderr.")
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
        "--locked-shelves",
        help=(
            "Comma-separated 1-based shelf unlock requirements, such as 7:3,8:5. "
            "Each shelf unlocks after that many cleared triples."
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    filled_layer_count = args.filled_layer_count
    if filled_layer_count is None:
        filled_layer_count = args.layer_count

    try:
        item_types = parse_item_types(args.item_types, args.item_config)
        locked_shelves = parse_locked_shelves(args.locked_shelves)
        shelves, stats, validation, used_seed = generate_with_optional_validation(
            shelf_count=args.shelf_count,
            layer_count=args.layer_count,
            filled_layer_count=filled_layer_count,
            item_types=item_types,
            difficulty=args.difficulty,
            seed=args.seed,
            should_validate=args.validate,
            require_solvable=args.require_solvable,
            max_attempts=args.max_generation_attempts,
            max_items_per_type_override=args.max_items_per_type,
            item_config_path=args.item_config,
            max_states=args.validator_max_states,
            max_depth=args.validator_max_depth,
            locked_shelves=locked_shelves,
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
    if args.full_level:
        output_data = wrap_level(
            shelves=shelves,
            level_number=args.level_number,
            time_seconds=args.time_seconds,
            layout_preset=args.layout_preset,
            seed=used_seed,
            difficulty=args.difficulty,
        )

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
