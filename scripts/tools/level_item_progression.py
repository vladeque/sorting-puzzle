"""Resolve abstract level item tokens through the campaign item progression."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_PROGRESSION_CONFIG = Path("configs/item_progression.json")
DEFAULT_ITEM_CONFIG = Path("configs/item_sprites.json")
LOGICAL_ITEM_PATTERN = re.compile(r"^item_(\d{2,})$")
SLOTS_PER_SHELF = 3


@dataclass(frozen=True)
class ItemProgression:
    mapping_salt: str
    milestones: tuple[tuple[int, tuple[str, ...]], ...]

    def available_items(self, level_number: int) -> tuple[str, ...]:
        if level_number < 1:
            raise ValueError("level number must be at least 1")

        available: list[str] = []
        for from_level, unlocked_items in self.milestones:
            if from_level > level_number:
                break
            available.extend(unlocked_items)
        return tuple(available)


def load_json_object(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as source_file:
        document = json.load(source_file)
    if not isinstance(document, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return document


def load_item_catalog_ids(path: Path = DEFAULT_ITEM_CONFIG) -> tuple[str, ...]:
    document = load_json_object(path)
    raw_items = document.get("items")
    if not isinstance(raw_items, list) or not raw_items:
        raise ValueError(f"{path} must define a non-empty items array")

    item_ids: list[str] = []
    seen: set[str] = set()
    for index, raw_item in enumerate(raw_items):
        if not isinstance(raw_item, dict):
            raise ValueError(f"{path} items[{index}] must be an object")
        item_id = raw_item.get("id")
        if not isinstance(item_id, str) or not item_id:
            raise ValueError(f"{path} items[{index}].id must be a non-empty string")
        if item_id in seen:
            raise ValueError(f"{path} contains duplicate item ID '{item_id}'")
        seen.add(item_id)
        item_ids.append(item_id)
    return tuple(item_ids)


def load_item_progression(
    progression_path: Path = DEFAULT_PROGRESSION_CONFIG,
    item_config_path: Path = DEFAULT_ITEM_CONFIG,
) -> ItemProgression:
    document = load_json_object(progression_path)
    if set(document) != {"schema_version", "mapping_salt", "milestones"}:
        raise ValueError(f"{progression_path} has unexpected or missing fields")
    if document.get("schema_version") != 1:
        raise ValueError(f"{progression_path} schema_version must be 1")

    mapping_salt = document.get("mapping_salt")
    if not isinstance(mapping_salt, str) or not mapping_salt:
        raise ValueError(f"{progression_path} mapping_salt must be a non-empty string")

    raw_milestones = document.get("milestones")
    if not isinstance(raw_milestones, list) or not raw_milestones:
        raise ValueError(f"{progression_path} must define a non-empty milestones array")

    known_items = set(load_item_catalog_ids(item_config_path))
    assigned_items: set[str] = set()
    milestones: list[tuple[int, tuple[str, ...]]] = []
    previous_level = 0
    for index, raw_milestone in enumerate(raw_milestones):
        if not isinstance(raw_milestone, dict) or set(raw_milestone) != {"from_level", "unlock"}:
            raise ValueError(f"{progression_path} milestones[{index}] has invalid fields")

        from_level = raw_milestone.get("from_level")
        if type(from_level) is not int or from_level <= previous_level:
            raise ValueError(
                f"{progression_path} milestone levels must be strictly increasing positive integers"
            )
        if index == 0 and from_level != 1:
            raise ValueError(f"{progression_path} first milestone must start at level 1")

        raw_unlocks = raw_milestone.get("unlock")
        if not isinstance(raw_unlocks, list) or not raw_unlocks:
            raise ValueError(f"{progression_path} milestones[{index}].unlock must not be empty")

        unlocked_items: list[str] = []
        for raw_item_id in raw_unlocks:
            if not isinstance(raw_item_id, str) or not raw_item_id:
                raise ValueError(
                    f"{progression_path} milestones[{index}].unlock contains an invalid item ID"
                )
            if raw_item_id not in known_items:
                raise ValueError(f"{progression_path} references unknown item '{raw_item_id}'")
            if raw_item_id in assigned_items:
                raise ValueError(
                    f"{progression_path} assigns item '{raw_item_id}' more than once"
                )
            assigned_items.add(raw_item_id)
            unlocked_items.append(raw_item_id)

        milestones.append((from_level, tuple(unlocked_items)))
        previous_level = from_level

    missing_items = known_items - assigned_items
    if missing_items:
        raise ValueError(
            f"{progression_path} does not schedule catalog items: {', '.join(sorted(missing_items))}"
        )

    return ItemProgression(mapping_salt=mapping_salt, milestones=tuple(milestones))


def logical_item_ids(item_type_count: int) -> list[str]:
    if item_type_count < 1:
        raise ValueError("item type count must be at least 1")
    return [f"item_{index:02d}" for index in range(1, item_type_count + 1)]


def collect_logical_item_ids(level: dict[str, Any]) -> tuple[str, ...]:
    shelves = level.get("shelves")
    if not isinstance(shelves, list) or not shelves:
        raise ValueError("level must contain a non-empty shelves array")

    item_counts: Counter[str] = Counter()
    for shelf_index, shelf in enumerate(shelves):
        if not isinstance(shelf, dict):
            raise ValueError(f"shelf {shelf_index + 1} must be an object")
        layers = shelf.get("layers")
        if not isinstance(layers, list) or not layers:
            raise ValueError(f"shelf {shelf_index + 1} must contain layers")
        for layer_index, layer in enumerate(layers):
            if not isinstance(layer, list):
                raise ValueError(
                    f"shelf {shelf_index + 1} layer {layer_index + 1} must be an array"
                )
            if len(layer) != SLOTS_PER_SHELF:
                raise ValueError(
                    f"shelf {shelf_index + 1} layer {layer_index + 1} "
                    f"must contain {SLOTS_PER_SHELF} slots"
                )
            for slot_index, item_id in enumerate(layer):
                if item_id is None:
                    continue
                if not isinstance(item_id, str) or LOGICAL_ITEM_PATTERN.fullmatch(item_id) is None:
                    raise ValueError(
                        f"shelf {shelf_index + 1} layer {layer_index + 1} "
                        f"slot {slot_index + 1} must contain item_NN or null"
                    )
                item_counts[item_id] += 1

    if not item_counts:
        raise ValueError("level must contain at least one logical item")
    logical_ids = tuple(sorted(item_counts, key=_logical_item_sort_key))
    expected_ids = tuple(logical_item_ids(len(logical_ids)))
    if logical_ids != expected_ids:
        raise ValueError(
            "logical item IDs must be contiguous canonical tokens starting at item_01"
        )
    for item_id, count in item_counts.items():
        if count % SLOTS_PER_SHELF != 0:
            raise ValueError(
                f"logical item '{item_id}' appears {count} times; expected a multiple of 3"
            )
    return logical_ids


def build_item_mapping(
    logical_ids: tuple[str, ...],
    level_number: int,
    progression: ItemProgression,
) -> dict[str, str]:
    available_items = progression.available_items(level_number)
    if len(logical_ids) > len(available_items):
        raise ValueError(
            f"level {level_number} uses {len(logical_ids)} logical item types, "
            f"but only {len(available_items)} item types are available"
        )

    ranked_items = sorted(
        available_items,
        key=lambda item_id: (
            hashlib.sha256(
                f"{progression.mapping_salt}:{level_number}:{item_id}".encode("utf-8")
            ).digest(),
            item_id.encode("utf-8"),
        ),
    )
    # Preserve the logical token order after selecting the level-specific subset.
    # Solvability search and future deterministic replay tie-break by item ID bytes.
    selected_items = sorted(
        ranked_items[: len(logical_ids)],
        key=lambda item_id: item_id.encode("utf-8"),
    )
    return dict(zip(logical_ids, selected_items, strict=True))


def materialize_level(
    abstract_level: dict[str, Any],
    progression: ItemProgression,
) -> tuple[dict[str, Any], dict[str, str]]:
    level_number = abstract_level.get("level")
    if type(level_number) is not int or level_number < 1:
        raise ValueError("level.level must be a positive integer")

    logical_ids = collect_logical_item_ids(abstract_level)
    mapping = build_item_mapping(logical_ids, level_number, progression)
    materialized = copy.deepcopy(abstract_level)
    for shelf in materialized["shelves"]:
        for layer in shelf["layers"]:
            for slot_index, item_id in enumerate(layer):
                if item_id is not None:
                    layer[slot_index] = mapping[item_id]
    return materialized, mapping


def write_json(path: Path, document: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(format_json(document), encoding="utf-8")


def format_json(document: dict[str, Any]) -> str:
    return f"{json.dumps(document, indent=2)}\n"


def _logical_item_sort_key(item_id: str) -> tuple[int, str]:
    match = LOGICAL_ITEM_PATTERN.fullmatch(item_id)
    if match is None:
        raise ValueError(f"invalid logical item ID '{item_id}'")
    return int(match.group(1)), item_id


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Materialize an abstract Sorting Puzzle level with progression-available items."
    )
    parser.add_argument("input", type=Path, help="Abstract level JSON containing item_NN tokens.")
    parser.add_argument("--output", type=Path, required=True, help="Concrete runtime level path.")
    parser.add_argument(
        "--progression-config",
        type=Path,
        default=DEFAULT_PROGRESSION_CONFIG,
    )
    parser.add_argument("--item-config", type=Path, default=DEFAULT_ITEM_CONFIG)
    parser.add_argument(
        "--mapping",
        action="store_true",
        help="Print the resolved logical-to-concrete item mapping to stderr.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        progression = load_item_progression(args.progression_config, args.item_config)
        abstract_level = load_json_object(args.input)
        materialized, mapping = materialize_level(abstract_level, progression)
        write_json(args.output, materialized)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if args.mapping:
        print(json.dumps(mapping, indent=2), file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
