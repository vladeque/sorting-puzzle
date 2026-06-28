#!/usr/bin/env python3
"""Validate whether a Sorting Puzzle level can be completed."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any, NamedTuple


SLOTS_PER_SHELF = 3
DEFAULT_ITEM_CONFIG = Path("configs/item_sprites.json")
ROW_MOTION_HORIZONTAL_WRAP = "horizontal_wrap"
ROW_VISUAL_VARIANTS = {"full", "floor_only"}
LAYOUT_GRID_3X3_MOVING_5_BOTTOM = "grid_3x3_moving_5_bottom"
LAYOUT_PRESET_ROW_LAYOUTS: dict[str, list[dict[str, Any]]] = {
    LAYOUT_GRID_3X3_MOVING_5_BOTTOM: [
        {"shelf_count": 3},
        {"shelf_count": 3},
        {"shelf_count": 3},
        {
            "shelf_count": 5,
            "visible_count": 3,
            "motion": {
                "type": ROW_MOTION_HORIZONTAL_WRAP,
                "speed": 70,
                "direction": "right",
            },
            "visual_variant": "floor_only",
        },
    ],
}

Item = str | None
Layer = tuple[Item, Item, Item]


class ShelfState(NamedTuple):
    unlock_after_triples: int
    layers: tuple[Layer, ...]


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
    if motion_type is not None and motion_type != ROW_MOTION_HORIZONTAL_WRAP:
        errors.append(f"row_layouts[{row_index}].motion.type must be '{ROW_MOTION_HORIZONTAL_WRAP}'")

    direction = motion_config.get("direction", row_layout.get("direction"))
    if direction is not None and direction not in {"left", "right"}:
        errors.append(f"row_layouts[{row_index}] direction must be 'left' or 'right'")

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
    if motion_config.get("type") == ROW_MOTION_HORIZONTAL_WRAP:
        return True
    if row_layout.get("moving") is True:
        return True

    speed = motion_config.get("speed", row_layout.get("speed", 0))
    return type(speed) in (int, float) and speed > 0


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

        unlock_after_triples = shelf.get("unlock_after_triples", 0)
        if type(unlock_after_triples) is not int or unlock_after_triples < 0:
            errors.append(f"shelf {shelf_index + 1} unlock_after_triples must be a non-negative integer")

        layers = shelf.get("layers")
        if not isinstance(layers, list) or not layers:
            errors.append(f"shelf {shelf_index + 1} must contain a non-empty layers array")
            continue

        for layer_index, layer in enumerate(layers):
            if not isinstance(layer, list):
                errors.append(f"shelf {shelf_index + 1} layer {layer_index + 1} must be an array")
                continue
            if len(layer) != SLOTS_PER_SHELF:
                errors.append(
                    f"shelf {shelf_index + 1} layer {layer_index + 1} must contain {SLOTS_PER_SHELF} slots"
                )
                continue

            for slot_index, item_id in enumerate(layer):
                if item_id is None:
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
        if count % SLOTS_PER_SHELF != 0:
            errors.append(f"item '{item_id}' appears {count} times, expected a multiple of {SLOTS_PER_SHELF}")

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
            )
        )

    return (0, tuple(state_shelves))


def slot_sort_key(item: Item) -> tuple[int, str]:
    return (1, "") if item is None else (0, item)


def shelf_sort_key(shelf: ShelfState) -> tuple[int, tuple[tuple[tuple[int, str], ...], ...]]:
    return (
        shelf.unlock_after_triples,
        tuple(tuple(slot_sort_key(item) for item in layer) for layer in shelf.layers),
    )


def canonicalize_state(state: State) -> State:
    triples_cleared, shelves = state
    canonical_shelves = []
    for shelf in shelves:
        canonical_layers = []
        for layer in shelf.layers:
            canonical_layers.append(tuple(sorted(layer, key=slot_sort_key)))
        canonical_shelves.append(
            ShelfState(
                unlock_after_triples=shelf.unlock_after_triples,
                layers=tuple(canonical_layers),
            )
        )

    return (triples_cleared, tuple(sorted(canonical_shelves, key=shelf_sort_key)))


def is_empty_layer(layer: Layer) -> bool:
    return all(item is None for item in layer)


def is_matching_layer(layer: Layer) -> bool:
    first = layer[0]
    return first is not None and all(item == first for item in layer)


def is_shelf_unlocked(shelf: ShelfState, triples_cleared: int) -> bool:
    return shelf.unlock_after_triples <= triples_cleared


def settle_state(state: State) -> State:
    triples_cleared, state_shelves = state
    shelves = [list(shelf.layers) for shelf in state_shelves]
    changed = True

    while changed:
        changed = False
        for shelf_index, shelf in enumerate(shelves):
            shelf_state = state_shelves[shelf_index]
            while shelf and is_shelf_unlocked(shelf_state, triples_cleared) and (
                is_empty_layer(shelf[0]) or is_matching_layer(shelf[0])
            ):
                if is_matching_layer(shelf[0]):
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
            )
        )

    return (triples_cleared, tuple(settled_shelves))


def normalize_state(state: State) -> State:
    return canonicalize_state(settle_state(state))


def is_cleared(state: State) -> bool:
    return all(len(shelf.layers) == 0 for shelf in state[1])


def visible_layer(shelf: ShelfState) -> Layer:
    if not shelf.layers:
        return (None, None, None)

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
                targets.append((shelf_index, slot_index))
            else:
                sources.append((shelf_index, slot_index, item_id))

    moves = []
    for from_shelf, from_slot, item_id in sources:
        for to_shelf, to_slot in targets:
            if from_shelf == to_shelf:
                continue

            moves.append(Move(item_id, from_shelf, from_slot, to_shelf, to_slot))

    moves.sort(key=lambda move: move_score(state, move), reverse=True)
    return moves


def move_score(state: State, move: Move) -> int:
    shelves = state[1]
    target_front = visible_layer(shelves[move.to_shelf])
    target_same_count = sum(1 for item_id in target_front if item_id == move.item_id)
    target_empty_count = sum(1 for item_id in target_front if item_id is None)
    source_front = visible_layer(shelves[move.from_shelf])
    source_remaining_count = sum(1 for item_id in source_front if item_id == move.item_id) - 1

    score = target_same_count * 10
    if target_same_count == 2 and target_empty_count == 1:
        score += 100
    if source_remaining_count == 0:
        score += 3
    return score


def apply_move(state: State, move: Move) -> State:
    triples_cleared, state_shelves = state
    shelves = [[list(layer) for layer in shelf.layers] for shelf in state_shelves]

    if not shelves[move.to_shelf]:
        shelves[move.to_shelf].append([None, None, None])

    shelves[move.from_shelf][0][move.from_slot] = None
    shelves[move.to_shelf][0][move.to_slot] = move.item_id

    moved_shelves = []
    for shelf_index, shelf in enumerate(shelves):
        moved_shelves.append(
            ShelfState(
                unlock_after_triples=state_shelves[shelf_index].unlock_after_triples,
                layers=tuple(tuple(layer) for layer in shelf),
            )
        )

    return (triples_cleared, tuple(moved_shelves))


def solve_level(initial_state: State, max_states: int, max_depth: int, keep_solution: bool) -> SearchResult:
    start_state = normalize_state(initial_state)
    if is_cleared(start_state):
        return SearchResult(True, "solved", 0, 1, 1, [])

    queue = [(start_state, 0)]
    visited = {start_state}
    parents: dict[State, tuple[State, Move]] = {}
    states_checked = 0
    max_queue_size = 1

    while queue:
        state, depth = queue.pop()
        states_checked += 1

        if states_checked > max_states:
            return SearchResult(None, "state_limit", None, states_checked, max_queue_size, [])
        if depth >= max_depth:
            continue

        moves = legal_moves(state)
        for move in reversed(moves):
            next_state = normalize_state(apply_move(state, move))
            if next_state in visited:
                continue

            if keep_solution:
                parents[next_state] = (state, move)

            if is_cleared(next_state):
                solution = reconstruct_solution(parents, start_state, next_state) if keep_solution else []
                return SearchResult(True, "solved", depth + 1, states_checked, max_queue_size, solution)

            visited.add(next_state)
            queue.append((next_state, depth + 1))
            max_queue_size = max(max_queue_size, len(queue))

    return SearchResult(False, "exhausted", None, states_checked, max_queue_size, [])


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
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "file": str(path),
        "valid": valid,
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
        result["solution"] = [
            {
                "item": move.item_id,
                "from_canonical_shelf": move.from_shelf + 1,
                "from_slot": move.from_slot + 1,
                "to_canonical_shelf": move.to_shelf + 1,
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
    except (OSError, ValueError, json.JSONDecodeError) as error:
        result = result_to_json(args.level, False, [str(error)], Counter(), None)
        print(json.dumps(result, indent=2))
        return 1

    if errors:
        result = result_to_json(args.level, False, errors, item_counts, None)
        print(json.dumps(result, indent=2))
        return 1

    search_result = solve_level(
        initial_state=shelves_to_state(shelves),
        max_states=args.max_states,
        max_depth=args.max_depth,
        keep_solution=args.show_solution,
    )
    result = result_to_json(args.level, True, [], item_counts, search_result)
    print(json.dumps(result, indent=2))

    if search_result.solvable is True:
        return 0
    if search_result.solvable is False:
        return 2
    return 3


if __name__ == "__main__":
    raise SystemExit(main())
