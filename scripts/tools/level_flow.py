#!/usr/bin/env python3
"""Measure how much a board gives the player to do, move by move.

Solvability asks whether a board *can* be finished. That is a different question
from whether finishing it feels like playing. A board can be provably solvable
and still sit at "one possible match on the whole field" for most of its length,
which reads as being stuck even though progress is available.

This module answers the second question. It plays the board with a deterministic
greedy player and records, at every decision point, how many distinct item types
the player could actually finish a triple with right now. A triple clears only
when all three copies sit on one shelf's front layer, so "right now" means three
copies reachable, a shelf able to host them, and few enough moves of preparation
to read as a match rather than as a project.

The resulting `FlowReport` is what `generate_level_shelves.py` gates on and
reports, and it is deliberately mode-agnostic: it drives the board through the
`SortingRules` interface, so it never constructs a move itself and cannot
propose one the mode would reject.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any, NamedTuple

from validate_level_solvable import (
    GAMEPLAY_MODE_THROWING_DISPENSERS,
    Move,
    ShelfState,
    SortingRules,
    TRIPLE_SIZE,
    build_search_inputs,
    get_gameplay_mode,
    load_level_data,
    load_shelves,
    score_move,
    visible_layer,
)

# Moves one simulated playthrough may take before it is abandoned, when the caller does not scale it
# to the board. `move_limit_for()` is what generation uses; this is the ceiling for a hand-run.
DEFAULT_MOVE_LIMIT = 4000
# Moves allowed per triple on the board. Clearing one costs two gathers and a completing move, so a
# board that has not finished within this many per triple is not going to: the player is circling,
# which is itself the finding rather than a reason to keep walking.
MOVES_ALLOWED_PER_TRIPLE = 12
# `score_move` awards ten points per copy of the moved item already sitting on the target shelf, so
# any score at least this high means the move put a copy next to at least one of its partners. Those
# moves build a triple; everything else is the shuffling a player experiences as wasted effort.
CONSOLIDATING_MOVE_SCORE = 10
# Moves of preparation a match may cost and still read to the player as something they can do now.
# Two is the floor for a triple whose copies sit on separate shelves, so this counts every match that
# needs no blocker cleared out of the way first. Anything dearer is work the player has to set up,
# which is exactly the state that reads as being stuck.
AVAILABLE_WITHIN_MOVES = 2
# At or below this many available matches the board stops offering the player a choice: they are
# either doing the one thing there is to do or hunting for it. An average hides these stretches --
# a level can average four options and still spend its last quarter at one -- so they are counted
# separately, and this is the number a level is worth gating on.
SCARCE_OPTION_COUNT = 1


class FlowReport(NamedTuple):
    """What a simulated playthrough felt like.

    Counts start after the board's opening settle, so an authored layer that is already three of a
    kind is in neither `total_triples` nor `cleared_triples`: it resolves before the player touches
    anything, and this describes the part they play.
    """

    average_options: float
    zero_option_ratio: float
    scarce_option_ratio: float
    longest_drought: int
    filler_move_ratio: float
    cleared_triples: int
    total_triples: int
    moves: int
    completed: bool
    option_samples: tuple[int, ...]

    def as_dict(self) -> dict[str, Any]:
        return {
            "average_options": round(self.average_options, 3),
            "zero_option_ratio": round(self.zero_option_ratio, 4),
            "scarce_option_ratio": round(self.scarce_option_ratio, 4),
            "longest_drought": self.longest_drought,
            "filler_move_ratio": round(self.filler_move_ratio, 4),
            "cleared_triples": self.cleared_triples,
            "total_triples": self.total_triples,
            "moves": self.moves,
            "completed": self.completed,
        }


## The one honest account of what the player can act on, shared by the generator's opening check and
## by every step of the simulation. Three copies being visible somewhere is not enough: they have to
## be gatherable onto a single shelf, and the blockers already sitting on that shelf have to have
## somewhere to go. Both requirements are what a layer-wide count of copies misses, and missing them
## is how a frozen board gets reported as a rich one.
def completion_costs(accessible: list[tuple[int, ShelfState]]) -> dict[str, int]:
    """Cheapest number of moves that would finish each item type's triple, right now.

    `accessible` is `SortingRules.accessible_shelves()`: the unlocked, on-window shelves, each
    tagged with the address its moves use. A type is absent from the result when no shelf could
    host it at all.

    The cost is what separates a board that offers something from one that only technically does.
    Two copies already sharing a shelf with a free slot is one move -- a match the player can see.
    The same three copies scattered over three shelves behind two blockers is four, which reads as
    work rather than as a move, even though both count the same to anything that just asks whether
    three copies are visible.

    A sticky item cannot leave its slot, so a shelf holding one can only ever complete that item's
    triple, and a sticky copy never counts as a partner that could travel to another shelf.
    """
    movable: Counter[str] = Counter()
    available_empty = 0
    for _, shelf in accessible:
        if not shelf.layers:
            if shelf.accepts_dropped_items:
                available_empty += shelf.slot_count
            continue

        front = visible_layer(shelf)
        for slot_index, item_id in enumerate(front):
            if item_id is None:
                if shelf.accepts_dropped_items:
                    available_empty += 1
            elif (0, slot_index) not in shelf.sticky_items:
                movable[item_id] += 1

    costs: dict[str, int] = {}
    for _, shelf in accessible:
        if not shelf.forms_triples or not shelf.layers:
            continue

        front = visible_layer(shelf)
        sticky_item = next((front[slot] for layer, slot in shelf.sticky_items if layer == 0), None)
        candidates = set(movable) | ({sticky_item} if sticky_item else set())
        for item_id in candidates:
            # A sticky item owns its shelf: nothing else can be completed around it.
            if sticky_item is not None and sticky_item != item_id:
                continue

            blockers = sum(value is not None and value != item_id for value in front)
            # Blockers have to be parked somewhere other than the slots this shelf is about to use.
            if available_empty - front.count(None) < blockers:
                continue

            already_here = front.count(item_id)
            needed = TRIPLE_SIZE - already_here
            elsewhere = movable[item_id] - already_here + int(sticky_item == item_id)
            if elsewhere < needed:
                continue

            # Park every blocker, then carry in the copies this shelf is missing.
            cost = blockers + needed
            if cost < costs.get(item_id, cost + 1):
                costs[item_id] = cost

    return costs


def collectible_front_types(
    accessible: list[tuple[int, ShelfState]],
    max_moves: int | None = None,
) -> set[str]:
    """Item types the player could finish a triple with, optionally within `max_moves` moves."""
    costs = completion_costs(accessible)
    if max_moves is None:
        return set(costs)

    return {item_id for item_id, cost in costs.items() if cost <= max_moves}


def move_limit_for(rules: SortingRules, state: Any) -> int:
    """A walk budget proportional to the board, so a big level is not cut off mid-play and a small
    one does not pay for four thousand moves of circling."""
    return max(120, MOVES_ALLOWED_PER_TRIPLE * count_triples(rules, state))


def count_triples(rules: SortingRules, state: Any) -> int:
    items = Counter(item
                    for shelf in rules.iter_shelf_states(state)
                    for layer in shelf.layers
                    for item in layer
                    if item is not None)
    return sum(items.values()) // TRIPLE_SIZE


def simulate_flow(
    rules: SortingRules,
    state: Any,
    move_limit: int | None = None,
) -> FlowReport:
    """Play the board greedily and report what the player had to choose from along the way.

    The player is deliberately ordinary rather than optimal: it takes the best move it can see one
    ply ahead, preferring one that clears a triple, then one that carries a copy to its partners,
    and only then one that digs a layer out while the board can still spare the room. An optimal
    line would understate how stuck a board feels, because a perfect player never wanders into the
    positions a person does.

    A move counts as filler when it neither clears a triple nor puts a copy beside one of its
    partners -- pure rearranging to make room, which is the part that reads as busywork.
    """
    state = rules.settle(state)
    total_triples = count_triples(rules, state)
    if move_limit is None:
        move_limit = move_limit_for(rules, state)
    start_cleared = state[0]

    option_samples: list[int] = []
    ## Positions are keyed canonically, so shuffling two shelves into each other's arrangement counts
    ## as the position it is rather than as progress. Keying them raw lets the player circle through
    ## re-orderings of one position and spend the whole budget going nowhere.
    visited = {rules.canonicalize(state)}
    productive_moves = 0
    filler_moves = 0
    drought = 0
    longest_drought = 0

    while not rules.is_cleared(state) and productive_moves + filler_moves < move_limit:
        costs = completion_costs(rules.accessible_shelves(state))
        options = sum(1 for cost in costs.values() if cost <= AVAILABLE_WITHIN_MOVES)
        option_samples.append(options)
        if options:
            longest_drought = max(longest_drought, drought)
            drought = 0
        else:
            drought += 1

        chosen = _choose_move(rules, state, visited)
        if chosen is None:
            break

        next_state, cleared_gain, advanced_a_set = chosen
        if cleared_gain > 0 or advanced_a_set:
            productive_moves += 1
        else:
            filler_moves += 1
        state = next_state
        visited.add(rules.canonicalize(state))

    longest_drought = max(longest_drought, drought)
    moves = productive_moves + filler_moves
    sample_count = len(option_samples) or 1
    cleared_triples = state[0] - start_cleared
    return FlowReport(
        average_options=sum(option_samples) / sample_count,
        zero_option_ratio=sum(1 for value in option_samples if value == 0) / sample_count,
        scarce_option_ratio=sum(1 for value in option_samples
                                if value <= SCARCE_OPTION_COUNT) / sample_count,
        longest_drought=longest_drought,
        filler_move_ratio=filler_moves / moves if moves else 0.0,
        cleared_triples=cleared_triples,
        total_triples=total_triples,
        moves=moves,
        completed=rules.is_cleared(state),
        option_samples=tuple(option_samples),
    )


def _free_slots(rules: SortingRules, state: Any) -> int:
    total = 0
    for _, shelf in rules.accessible_shelves(state):
        if not shelf.accepts_dropped_items:
            continue
        total += shelf.slot_count if not shelf.layers else visible_layer(shelf).count(None)
    return total


def _filled_in_next_layer(shelf: ShelfState) -> int:
    """Items waiting on the layer that surfaces when this shelf's front layer goes away."""
    if len(shelf.layers) < 2:
        return 0
    return sum(1 for item in shelf.layers[1] if item is not None)


## Every candidate is judged from the two shelves it touches, without building the position it would
## lead to. Applying and settling each one only to rank it made the walk tens of seconds per board,
## and the three things the ranking needs -- does it complete a triple, does it carry a copy to its
## partners, does it uncover a layer -- are all readable off the shelves themselves.
##
## The arithmetic is exact for the move itself and approximate only for a settle that cascades, which
## costs nothing: the chosen move is still applied through `rules`, so this decides the order moves
## are tried in, never what a move does.
def _rank_move(
    source: ShelfState,
    target: ShelfState,
    item_id: str,
    to_slot: int,
    free_slots: int,
) -> tuple[int, int, int, bool, bool]:
    quality = score_move(source, target, item_id)
    target_front = visible_layer(target)
    source_front = visible_layer(source)

    # The move completes the target layer when its other two slots already hold this item.
    completes = all(
        slot_item == item_id
        for slot, slot_item in enumerate(target_front)
        if slot != to_slot
    ) and len(target_front) == TRIPLE_SIZE

    # It uncovers a layer when the moved item was the last thing on its shelf's front layer.
    uncovers = sum(1 for slot_item in source_front if slot_item is not None) == 1

    free_after = free_slots
    if completes:
        free_after += TRIPLE_SIZE - _filled_in_next_layer(target)
    if uncovers:
        free_after -= _filled_in_next_layer(source)

    # Digging is only worth it while the board keeps room to gather a triple afterwards. A dig that
    # overdraws the board ranks below doing nothing useful, because spending the last free slots to
    # reveal a full layer is how a player talks themselves into a dead board.
    if not uncovers:
        affordable_dig = 0
    elif free_after >= TRIPLE_SIZE:
        affordable_dig = 1
    else:
        affordable_dig = -1
    return (
        1 if completes else 0,
        quality,
        affordable_dig,
        completes,
        quality >= CONSOLIDATING_MOVE_SCORE,
    )


def _choose_move(rules: SortingRules, state: Any, visited: set) -> tuple[Any, int, bool] | None:
    """Best move a person would see, applied. `None` once nothing is left that goes anywhere new."""
    moves = rules.legal_moves(state)
    if not moves:
        return None

    shelves_by_address = dict(rules.accessible_shelves(state))
    free_slots = _free_slots(rules, state)
    ranked = []
    for rank, move in enumerate(moves):
        source = shelves_by_address.get(move.from_shelf)
        target = shelves_by_address.get(move.to_shelf)
        if source is None or target is None or not source.layers:
            continue

        key = _rank_move(source, target, move.item_id, move.to_slot, free_slots)
        ranked.append(((key[0], key[1], key[2], -rank), move, key[3], key[4]))

    ranked.sort(key=lambda entry: entry[0], reverse=True)

    ## The whole list is walked, not a prefix of it. Cutting it short made the player stop the moment
    ## its best two dozen moves all led somewhere it had been, which ends the walk early and reports
    ## the opening's option count as if it were the whole level's.
    repeat = None
    for _, move, completes, advances in ranked:
        try:
            next_state = rules.settle(rules.apply_move(state, move))
        except ValueError:
            continue

        cleared_gain = next_state[0] - state[0]
        if rules.canonicalize(next_state) in visited:
            if repeat is None:
                repeat = (next_state, cleared_gain, advances or completes)
            continue

        return next_state, cleared_gain, advances or completes

    ## Nowhere new to go. A player in that position shuffles rather than stopping, and the shuffling
    ## is the thing worth measuring, so the walk takes the best move it has and lets the move limit
    ## end it. Only a board with no legal move at all reports a dead end.
    return repeat


def flow_for_level(level_data: Any, shelves: list[dict[str, Any]], move_limit: int | None = None):
    """`FlowReport` for a level, or `None` for a mode that has no board to walk.

    The throwing mode starts with an empty board it fills during play, so there is no initial
    position to measure; `ThrowingDispensersRules.estimate_playability()` covers it instead.
    """
    if get_gameplay_mode(level_data) == GAMEPLAY_MODE_THROWING_DISPENSERS:
        return None

    rules, state = build_search_inputs(level_data, shelves)
    return simulate_flow(rules, state, move_limit=move_limit)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Report how much a level gives the player to do, move by move.",
    )
    parser.add_argument("level", type=Path, help="Level JSON file, or a bare shelves array.")
    parser.add_argument("--shelves-only", action="store_true",
                        help="The file holds a shelves array rather than a full level object.")
    parser.add_argument("--move-limit", type=int, default=None,
                        help="Walk budget in moves. Defaults to twelve per triple on the board.")
    parser.add_argument("--json", action="store_true", help="Print the report as JSON.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    shelves = load_shelves(args.level, args.shelves_only)
    level_data = {"shelves": shelves} if args.shelves_only else load_level_data(args.level)
    report = flow_for_level(level_data, shelves, move_limit=args.move_limit)
    if report is None:
        print(f"{args.level}: throwing dispensers are sampled by the validator, not walked here")
        return 0

    if args.json:
        print(json.dumps(report.as_dict(), indent=2))
        return 0

    print(f"{args.level}")
    print(f"  average options per move : {report.average_options:.2f}")
    print(f"  moments with 1 or 0 match: {report.scarce_option_ratio * 100:.1f}%")
    print(f"  moments with no match    : {report.zero_option_ratio * 100:.1f}%")
    print(f"  longest drought (moves)  : {report.longest_drought}")
    print(f"  moves that were shuffling: {report.filler_move_ratio * 100:.1f}%")
    print(f"  triples cleared          : {report.cleared_triples}/{report.total_triples}")
    print(f"  finished                 : {report.completed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
