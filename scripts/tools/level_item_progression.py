"""Resolve abstract level item tokens through the campaign item progression."""

from __future__ import annotations

from sticky_items import validate_sticky_items
from validate_level_solvable import validate_gameplay_mode_shape

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
DEFAULT_CHAPTERS_CONFIG = Path("configs/chapters.json")
LOGICAL_ITEM_PATTERN = re.compile(r"^item_(\d{2,})$")
SLOTS_PER_SHELF = 3
TRIPLE_SIZE = 3
SHELF_KIND_DISPENSER = "dispenser"
DISPENSER_SLOTS_PER_SHELF = 1


@dataclass(frozen=True)
class ChapterDefinition:
    chapter_id: str
    order: int
    title: str
    level_ids: tuple[int, ...]
    previous_chapter_id: str | None
    required_completed_levels: int


@dataclass(frozen=True)
class CampaignChapters:
    chapters: tuple[ChapterDefinition, ...]

    def chapter_for_level(self, level_number: int) -> tuple[ChapterDefinition, int]:
        if level_number < 1:
            raise ValueError("level number must be at least 1")
        for chapter in self.chapters:
            try:
                chapter_level = chapter.level_ids.index(level_number) + 1
            except ValueError:
                continue
            return chapter, chapter_level
        raise ValueError(f"campaign level {level_number} is not assigned to a chapter")


@dataclass(frozen=True)
class ChapterItemProgression:
    chapter_id: str
    milestones: tuple[tuple[int, tuple[str, ...]], ...]

    def available_items(self, chapter_level: int) -> tuple[str, ...]:
        if chapter_level < 1:
            raise ValueError("chapter level must be at least 1")
        available: list[str] = []
        for from_chapter_level, unlocked_items in self.milestones:
            if from_chapter_level > chapter_level:
                break
            available.extend(unlocked_items)
        return tuple(available)


@dataclass(frozen=True)
class ItemProgression:
    mapping_salt: str
    campaign_chapters: CampaignChapters
    chapter_progressions: tuple[ChapterItemProgression, ...]

    def available_items(self, level_number: int) -> tuple[str, ...]:
        chapter, chapter_level = self.campaign_chapters.chapter_for_level(level_number)
        for progression in self.chapter_progressions:
            if progression.chapter_id == chapter.chapter_id:
                return progression.available_items(chapter_level)
        raise ValueError(f"chapter '{chapter.chapter_id}' has no item progression")

    def chapter_item_ids(self, chapter_id: str) -> tuple[str, ...]:
        for progression in self.chapter_progressions:
            if progression.chapter_id == chapter_id:
                result: list[str] = []
                for _from_level, item_ids in progression.milestones:
                    result.extend(item_ids)
                return tuple(result)
        raise ValueError(f"unknown chapter '{chapter_id}'")


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


def load_chapter_catalog(path: Path = DEFAULT_CHAPTERS_CONFIG) -> CampaignChapters:
    document = load_json_object(path)
    if set(document) != {"schema_version", "default_unlock_required_levels", "chapters"}:
        raise ValueError(f"{path} has unexpected or missing fields")
    if document.get("schema_version") != 1:
        raise ValueError(f"{path} schema_version must be 1")
    default_requirement = document.get("default_unlock_required_levels")
    if type(default_requirement) is not int or default_requirement < 1:
        raise ValueError(f"{path} default unlock requirement must be a positive integer")

    raw_chapters = document.get("chapters")
    if not isinstance(raw_chapters, list) or not raw_chapters:
        raise ValueError(f"{path} must define a non-empty chapters array")

    chapters: list[ChapterDefinition] = []
    seen_ids: set[str] = set()
    seen_levels: set[int] = set()
    for index, raw_chapter in enumerate(raw_chapters):
        expected_fields = {
            "id",
            "order",
            "title",
            "level_ids",
            "unlock",
            "gameplay_background_mode",
            "background_texture",
            "selection_preview",
        }
        if not isinstance(raw_chapter, dict) or set(raw_chapter) != expected_fields:
            raise ValueError(f"{path} chapters[{index}] has invalid fields")
        chapter_id = raw_chapter.get("id")
        order = raw_chapter.get("order")
        title = raw_chapter.get("title")
        if not isinstance(chapter_id, str) or not chapter_id or chapter_id in seen_ids:
            raise ValueError(f"{path} chapters[{index}].id must be unique and non-empty")
        if type(order) is not int or order != index + 1:
            raise ValueError(f"{path} chapter order must be contiguous starting at 1")
        if not isinstance(title, str) or not title.strip():
            raise ValueError(f"{path} chapters[{index}].title must be non-empty")
        gameplay_background_mode = raw_chapter.get("gameplay_background_mode")
        if gameplay_background_mode not in {"legacy", "artwork"}:
            raise ValueError(
                f"{path} chapters[{index}].gameplay_background_mode must be legacy or artwork"
            )
        for presentation_key in ("background_texture", "selection_preview"):
            presentation_path = raw_chapter.get(presentation_key)
            if not isinstance(presentation_path, str) or not presentation_path.startswith("res://"):
                raise ValueError(f"{path} chapters[{index}].{presentation_key} must be a res:// path")

        raw_level_ids = raw_chapter.get("level_ids")
        if not isinstance(raw_level_ids, list):
            raise ValueError(f"{path} chapters[{index}].level_ids must be an array")
        level_ids: list[int] = []
        for level_id in raw_level_ids:
            if type(level_id) is not int or level_id < 1 or level_id in seen_levels:
                raise ValueError(f"{path} chapter levels must be unique positive integers")
            seen_levels.add(level_id)
            level_ids.append(level_id)
        if index == 0 and not level_ids:
            raise ValueError(f"{path} first chapter must contain at least one level")

        raw_unlock = raw_chapter.get("unlock")
        if not isinstance(raw_unlock, dict) or not set(raw_unlock).issubset(
            {"previous_chapter_id", "required_completed_levels"}
        ) or "previous_chapter_id" not in raw_unlock:
            raise ValueError(f"{path} chapters[{index}].unlock has invalid fields")
        previous_chapter_id = raw_unlock.get("previous_chapter_id")
        required_completed_levels = raw_unlock.get(
            "required_completed_levels", 0 if index == 0 else default_requirement
        )
        if index == 0:
            if previous_chapter_id is not None or required_completed_levels != 0:
                raise ValueError(f"{path} first chapter must be unlocked by default")
        else:
            expected_previous_id = chapters[index - 1].chapter_id
            if previous_chapter_id != expected_previous_id:
                raise ValueError(f"{path} chapter unlocks must reference the previous chapter")
            if type(required_completed_levels) is not int or required_completed_levels < 1:
                raise ValueError(f"{path} chapter unlock requirement must be positive")

        seen_ids.add(chapter_id)
        chapters.append(
            ChapterDefinition(
                chapter_id=chapter_id,
                order=order,
                title=title.strip(),
                level_ids=tuple(level_ids),
                previous_chapter_id=previous_chapter_id,
                required_completed_levels=required_completed_levels,
            )
        )
    return CampaignChapters(chapters=tuple(chapters))


def load_item_progression(
    progression_path: Path = DEFAULT_PROGRESSION_CONFIG,
    item_config_path: Path = DEFAULT_ITEM_CONFIG,
    chapters_path: Path = DEFAULT_CHAPTERS_CONFIG,
) -> ItemProgression:
    document = load_json_object(progression_path)
    if set(document) != {"schema_version", "mapping_salt", "chapters"}:
        raise ValueError(f"{progression_path} has unexpected or missing fields")
    if document.get("schema_version") != 2:
        raise ValueError(f"{progression_path} schema_version must be 2")

    mapping_salt = document.get("mapping_salt")
    if not isinstance(mapping_salt, str) or not mapping_salt:
        raise ValueError(f"{progression_path} mapping_salt must be a non-empty string")

    campaign_chapters = load_chapter_catalog(chapters_path)
    known_items = set(load_item_catalog_ids(item_config_path))
    scheduled_items: set[str] = set()
    raw_chapters = document.get("chapters")
    if not isinstance(raw_chapters, list) or not raw_chapters:
        raise ValueError(f"{progression_path} must define chapter progressions")
    expected_chapter_ids = [chapter.chapter_id for chapter in campaign_chapters.chapters]
    chapter_progressions: list[ChapterItemProgression] = []
    for chapter_index, raw_chapter in enumerate(raw_chapters):
        if not isinstance(raw_chapter, dict) or set(raw_chapter) != {"chapter_id", "milestones"}:
            raise ValueError(f"{progression_path} chapters[{chapter_index}] has invalid fields")
        chapter_id = raw_chapter.get("chapter_id")
        if chapter_index >= len(expected_chapter_ids) or chapter_id != expected_chapter_ids[chapter_index]:
            raise ValueError(f"{progression_path} chapter order must match {chapters_path}")
        raw_milestones = raw_chapter.get("milestones")
        if not isinstance(raw_milestones, list) or not raw_milestones:
            raise ValueError(f"{progression_path} chapter '{chapter_id}' must define milestones")

        milestones: list[tuple[int, tuple[str, ...]]] = []
        chapter_assigned_items: set[str] = set()
        previous_level = 0
        for milestone_index, raw_milestone in enumerate(raw_milestones):
            if not isinstance(raw_milestone, dict) or set(raw_milestone) != {
                "from_chapter_level",
                "unlock",
            }:
                raise ValueError(f"{progression_path} chapter milestone has invalid fields")
            from_level = raw_milestone.get("from_chapter_level")
            if type(from_level) is not int or from_level <= previous_level:
                raise ValueError(f"{progression_path} chapter milestones must be strictly increasing")
            if milestone_index == 0 and from_level != 1:
                raise ValueError(f"{progression_path} first chapter milestone must start at level 1")
            raw_unlocks = raw_milestone.get("unlock")
            if not isinstance(raw_unlocks, list) or not raw_unlocks:
                raise ValueError(f"{progression_path} chapter milestone unlock must not be empty")
            unlocked_items: list[str] = []
            for raw_item_id in raw_unlocks:
                if not isinstance(raw_item_id, str) or not raw_item_id:
                    raise ValueError(f"{progression_path} contains an invalid item ID")
                if raw_item_id not in known_items:
                    raise ValueError(f"{progression_path} references unknown item '{raw_item_id}'")
                if raw_item_id in chapter_assigned_items:
                    raise ValueError(
                        f"{progression_path} chapter '{chapter_id}' assigns item "
                        f"'{raw_item_id}' more than once"
                    )
                chapter_assigned_items.add(raw_item_id)
                scheduled_items.add(raw_item_id)
                unlocked_items.append(raw_item_id)
            milestones.append((from_level, tuple(unlocked_items)))
            previous_level = from_level
        chapter_progressions.append(
            ChapterItemProgression(chapter_id=chapter_id, milestones=tuple(milestones))
        )

    if len(chapter_progressions) != len(expected_chapter_ids):
        raise ValueError(f"{progression_path} must define every configured chapter")

    missing_items = known_items - scheduled_items
    if missing_items:
        raise ValueError(
            f"{progression_path} does not schedule catalog items: {', '.join(sorted(missing_items))}"
        )

    return ItemProgression(
        mapping_salt=mapping_salt,
        campaign_chapters=campaign_chapters,
        chapter_progressions=tuple(chapter_progressions),
    )


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
        sticky_errors = validate_sticky_items(shelf)
        if sticky_errors:
            raise ValueError(f"shelf {shelf_index + 1}: {'; '.join(sticky_errors)}")
        layers = shelf.get("layers")
        if not isinstance(layers, list) or not layers:
            raise ValueError(f"shelf {shelf_index + 1} must contain layers")
        slot_count = (
            DISPENSER_SLOTS_PER_SHELF
            if shelf.get("type") == SHELF_KIND_DISPENSER
            else SLOTS_PER_SHELF
        )
        for layer_index, layer in enumerate(layers):
            if not isinstance(layer, list):
                raise ValueError(
                    f"shelf {shelf_index + 1} layer {layer_index + 1} must be an array"
                )
            if len(layer) != slot_count:
                raise ValueError(
                    f"shelf {shelf_index + 1} layer {layer_index + 1} "
                    f"must contain {slot_count} slots"
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
        if count % TRIPLE_SIZE != 0:
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

    chapter, chapter_level = progression.campaign_chapters.chapter_for_level(level_number)
    ranked_items = sorted(
        available_items,
        key=lambda item_id: (
            hashlib.sha256(
                (
                    f"{progression.mapping_salt}:{chapter.chapter_id}:"
                    f"{chapter_level}:{level_number}:{item_id}"
                ).encode("utf-8")
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


## Materialization is the publication path, so a malformed board contract has to stop here rather
## than reach `configs/levels/`. Item identities are resolved purely from the flat shelves array; no
## logical item metadata is ever inferred from a shelf's column or stack position.
def validate_board_contract(abstract_level: dict[str, Any]) -> None:
    shelves = abstract_level.get("shelves")
    if not isinstance(shelves, list):
        raise ValueError("level must contain a non-empty shelves array")

    errors = validate_gameplay_mode_shape(abstract_level, shelves)
    if errors:
        raise ValueError("; ".join(errors))


def materialize_level(
    abstract_level: dict[str, Any],
    progression: ItemProgression,
) -> tuple[dict[str, Any], dict[str, str]]:
    level_number = abstract_level.get("level")
    if type(level_number) is not int or level_number < 1:
        raise ValueError("level.level must be a positive integer")

    validate_board_contract(abstract_level)
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
    parser.add_argument("--chapters-config", type=Path, default=DEFAULT_CHAPTERS_CONFIG)
    parser.add_argument(
        "--mapping",
        action="store_true",
        help="Print the resolved logical-to-concrete item mapping to stderr.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        progression = load_item_progression(
            args.progression_config,
            args.item_config,
            args.chapters_config,
        )
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
