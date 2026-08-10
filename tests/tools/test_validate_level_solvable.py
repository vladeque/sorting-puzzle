from __future__ import annotations

import sys
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOLS_PATH = REPOSITORY_ROOT / "scripts" / "tools"
sys.path.insert(0, str(TOOLS_PATH))

from validate_level_solvable import (  # noqa: E402
    legal_moves,
    normalize_state,
    shelves_to_state,
    solve_level,
    validate_shelves_shape,
)


def standard_shelf(*layers: list[str | None]) -> dict[str, object]:
    return {"layers": [list(layer) for layer in layers]}


def dispenser_shelf(*items: str) -> dict[str, object]:
    return {"type": "dispenser", "layers": [[item] for item in items]}


class DispenserShelfShapeTests(unittest.TestCase):
    def test_accepts_a_well_formed_dispenser(self) -> None:
        shelves = [
            standard_shelf(["a", "a", None]),
            dispenser_shelf("a", "b", "b"),
            standard_shelf(["b", None, None]),
        ]
        errors, counts = validate_shelves_shape(shelves, set(), skip_known_items=True)
        self.assertEqual(errors, [])
        self.assertEqual(counts["a"], 3)
        self.assertEqual(counts["b"], 3)

    def test_rejects_a_dispenser_layer_that_is_not_one_slot_wide(self) -> None:
        shelves = [{"type": "dispenser", "layers": [["a", "a", "a"], ["b"]]}]
        errors, _counts = validate_shelves_shape(shelves, set(), skip_known_items=True)
        self.assertTrue(any("must contain 1 slots" in error for error in errors))

    def test_rejects_a_hole_in_a_dispenser_queue(self) -> None:
        shelves = [{"type": "dispenser", "layers": [["a"], [None], ["a"]]}]
        errors, _counts = validate_shelves_shape(shelves, set(), skip_known_items=True)
        self.assertTrue(any("must contain an item ID, not null" in error for error in errors))

    def test_rejects_a_dispenser_outside_the_supported_layer_range(self) -> None:
        for items in [("a",), ("a", "b", "c", "d", "e")]:
            with self.subTest(layer_count=len(items)):
                errors, _counts = validate_shelves_shape(
                    [dispenser_shelf(*items)], set(), skip_known_items=True
                )
                self.assertTrue(any("is a dispenser with" in error for error in errors))

    def test_rejects_an_unknown_shelf_type(self) -> None:
        shelves = [{"type": "conveyor", "layers": [["a", "a", "a"]]}]
        errors, _counts = validate_shelves_shape(shelves, set(), skip_known_items=True)
        self.assertTrue(any("type must be one of" in error for error in errors))


class DispenserSearchTests(unittest.TestCase):
    ## A dispenser layer is one slot wide, so "every slot holds the same item" is trivially true for
    ## it. If the settle step did not gate matching on the shelf kind, this board would clear itself
    ## before a single move and report free triples.
    def test_a_dispenser_does_not_clear_itself(self) -> None:
        state = normalize_state(shelves_to_state([dispenser_shelf("a", "a", "a")]))
        triples_cleared, shelves = state
        self.assertEqual(triples_cleared, 0)
        self.assertEqual(len(shelves[0].layers), 3)

    def test_a_dispenser_is_a_source_but_never_a_target(self) -> None:
        state = normalize_state(
            shelves_to_state(
                [
                    dispenser_shelf("a", "b", "b"),
                    standard_shelf(["a", None, None]),
                ]
            )
        )
        moves = legal_moves(state)
        self.assertTrue(moves, "the dispenser's item should be movable onto the standard shelf")
        self.assertTrue(
            all(move.to_shelf != 0 for move in moves),
            "no move may target the dispenser",
        )
        self.assertTrue(
            any(move.from_shelf == 0 for move in moves),
            "the dispenser must be usable as a move source",
        )

    def test_solves_a_board_whose_last_item_sits_in_a_dispenser(self) -> None:
        shelves = [
            standard_shelf(["a", "a", None]),
            dispenser_shelf("a", "b", "b"),
            standard_shelf(["b", None, None]),
        ]
        result = solve_level(
            normalize_state(shelves_to_state(shelves)),
            max_states=20000,
            max_depth=200,
            keep_solution=False,
        )
        self.assertTrue(result.solvable, result.reason)

    ## Items can only leave a dispenser, so a board with nowhere to put them cannot be finished.
    def test_reports_a_board_with_no_drop_targets_unsolvable(self) -> None:
        shelves = [dispenser_shelf("a", "a", "a"), dispenser_shelf("b", "b", "b")]
        result = solve_level(
            normalize_state(shelves_to_state(shelves)),
            max_states=20000,
            max_depth=200,
            keep_solution=False,
        )
        self.assertFalse(result.solvable)


if __name__ == "__main__":
    unittest.main()
