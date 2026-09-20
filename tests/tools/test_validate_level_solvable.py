from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOLS_PATH = REPOSITORY_ROOT / "scripts" / "tools"
sys.path.insert(0, str(TOOLS_PATH))

from validate_level_solvable import (  # noqa: E402
    MAX_VISIBLE_SHELVES_PER_COLUMN,
    CollapsingColumnsRules,
    build_search_inputs,
    collapsing_shelves_to_state,
    legal_moves,
    normalize_state,
    shelves_to_state,
    solve_level,
    validate_gameplay_mode_shape,
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


def collapsing_level(
    shelf_counts: list[int],
    visible_shelves_per_column: int,
    shelves: list[dict[str, object]],
    **overrides: object,
) -> dict[str, object]:
    level = {
        "level": 11,
        "time_seconds": 300,
        "gameplay_mode": "collapsing_columns",
        "column_layout": {
            "shelf_counts": list(shelf_counts),
            "visible_shelves_per_column": visible_shelves_per_column,
        },
        "shelves": shelves,
    }
    level.update(overrides)
    return level


def collapsing_errors(level: dict[str, object]) -> list[str]:
    return validate_gameplay_mode_shape(level, level["shelves"])


def column_shelf_ids(state) -> list[list[int]]:
    return [[entry.shelf_id for entry in column] for column in state[1]]


def replay(rules, state, solution) -> object:
    """Re-apply a reported solution against the authored board, exactly as the runtime would."""
    replayed = rules.settle(state)
    for move in solution:
        replayed = rules.settle(rules.apply_move(replayed, move))
    return replayed


class CollapsingColumnContractTests(unittest.TestCase):
    def test_accepts_a_well_formed_column_contract(self) -> None:
        level = collapsing_level(
            [2, 1],
            2,
            [
                standard_shelf(["a", "a", None]),
                standard_shelf(["a", None, None]),
                standard_shelf(["b", "b", "b"]),
            ],
        )
        self.assertEqual(collapsing_errors(level), [])

    def test_classic_levels_stay_unaffected_and_reject_a_column_layout(self) -> None:
        classic = {"level": 1, "shelves": [standard_shelf(["a", "a", "a"])]}
        self.assertEqual(validate_gameplay_mode_shape(classic, classic["shelves"]), [])

        classic["column_layout"] = {"shelf_counts": [1], "visible_shelves_per_column": 1}
        errors = validate_gameplay_mode_shape(classic, classic["shelves"])
        self.assertTrue(any("only valid when gameplay_mode" in error for error in errors))

    def test_rejects_an_unknown_gameplay_mode(self) -> None:
        level = {"level": 1, "gameplay_mode": "conveyor", "shelves": [standard_shelf(["a", "a", "a"])]}
        errors = validate_gameplay_mode_shape(level, level["shelves"])
        self.assertTrue(any("gameplay_mode must be one of" in error for error in errors))

    def test_rejects_a_missing_or_malformed_column_layout(self) -> None:
        shelves = [standard_shelf(["a", "a", "a"])]
        for column_layout in [None, [], "3x4", 4]:
            with self.subTest(column_layout=column_layout):
                level = {"level": 11, "gameplay_mode": "collapsing_columns", "shelves": shelves}
                if column_layout is not None:
                    level["column_layout"] = column_layout
                errors = validate_gameplay_mode_shape(level, shelves)
                self.assertTrue(any("column_layout must be an object" in error for error in errors))

    def test_rejects_malformed_shelf_counts(self) -> None:
        shelves = [standard_shelf(["a", "a", "a"])]
        for shelf_counts in [[], "1", {}, None]:
            with self.subTest(shelf_counts=shelf_counts):
                level = collapsing_level([1], 1, shelves)
                level["column_layout"]["shelf_counts"] = shelf_counts
                errors = collapsing_errors(level)
                self.assertTrue(any("non-empty array of positive integers" in error for error in errors))

        for bad_entry in [0, -2, 1.5, "2", True]:
            with self.subTest(entry=bad_entry):
                level = collapsing_level([1], 1, shelves)
                level["column_layout"]["shelf_counts"] = [bad_entry]
                errors = collapsing_errors(level)
                self.assertTrue(any("must be a positive integer" in error for error in errors))

    def test_rejects_a_shelf_count_sum_that_misses_the_shelves_array(self) -> None:
        level = collapsing_level(
            [2, 2],
            2,
            [
                standard_shelf(["a", "a", None]),
                standard_shelf(["a", None, None]),
                standard_shelf(["b", "b", "b"]),
            ],
        )
        errors = collapsing_errors(level)
        self.assertTrue(any("total is 4, expected 3 shelves" in error for error in errors))

    def test_rejects_zero_negative_and_excessive_visible_counts(self) -> None:
        shelves = [standard_shelf(["a", "a", "a"])]
        for visible_count in [0, -1, MAX_VISIBLE_SHELVES_PER_COLUMN + 1, 1.0, "2", None]:
            with self.subTest(visible_count=visible_count):
                level = collapsing_level([1], 1, shelves)
                level["column_layout"]["visible_shelves_per_column"] = visible_count
                errors = collapsing_errors(level)
                self.assertTrue(
                    any("visible_shelves_per_column must be a positive integer" in error for error in errors)
                )

    def test_rejects_more_than_one_layer(self) -> None:
        level = collapsing_level(
            [1], 1, [standard_shelf(["a", "a", "a"], ["b", "b", "b"])]
        )
        errors = collapsing_errors(level)
        self.assertTrue(any("has 2 layers, expected exactly 1" in error for error in errors))

    def test_rejects_an_empty_authored_shelf(self) -> None:
        level = collapsing_level(
            [2],
            2,
            [standard_shelf(["a", "a", "a"]), standard_shelf([None, None, None])],
        )
        errors = collapsing_errors(level)
        self.assertTrue(any("shelf 2 is empty" in error for error in errors))

    def test_rejects_dispensers_locks_and_sticky_items(self) -> None:
        dispenser = dispenser_shelf("a", "a", "a")
        locked = standard_shelf(["a", "a", "a"]) | {"unlock_after_triples": 2}
        sticky = standard_shelf(["a", "a", "a"]) | {"sticky_items": [{"layer": 0, "slot": 0}]}
        for shelf, expected in [
            (dispenser, "must be a standard shelf"),
            (locked, "is locked"),
            (sticky, "has sticky items"),
        ]:
            with self.subTest(expected=expected):
                level = collapsing_level([1], 1, [shelf])
                errors = collapsing_errors(level)
                self.assertTrue(any(expected in error for error in errors), errors)

    def test_rejects_layout_preset_and_row_layouts(self) -> None:
        shelves = [standard_shelf(["a", "a", "a"])]
        for key, value in [("layout_preset", "grid_3x3"), ("row_layouts", [{"shelf_count": 1}])]:
            with self.subTest(key=key):
                level = collapsing_level([1], 1, shelves, **{key: value})
                errors = collapsing_errors(level)
                self.assertTrue(any(f"{key} cannot be combined with" in error for error in errors))


class CollapsingColumnSearchTests(unittest.TestCase):
    def test_reveals_a_hidden_shelf_and_resolves_its_authored_triple(self) -> None:
        level = collapsing_level(
            [3],
            2,
            [
                standard_shelf(["a", "a", None]),
                standard_shelf(["a", None, None]),
                standard_shelf(["b", "b", "b"]),
            ],
        )
        self.assertEqual(collapsing_errors(level), [])
        rules, state = build_search_inputs(level, level["shelves"])

        # The authored triple sits above the window, so it must not resolve before it is revealed.
        settled = rules.settle(state)
        self.assertEqual(settled[0], 0)
        self.assertEqual(column_shelf_ids(settled), [[0, 1, 2]])
        self.assertTrue(all(move.to_shelf != 2 and move.from_shelf != 2 for move in rules.legal_moves(settled)))

        result = solve_level(state, max_states=20000, max_depth=200, keep_solution=True, rules=rules)
        self.assertTrue(result.solvable, result.reason)
        self.assertTrue(rules.is_cleared(replay(rules, state, result.solution)))

    def test_a_larger_visible_window_keeps_a_solvable_board_solvable(self) -> None:
        shelves = [
            standard_shelf(["a", "a", None]),
            standard_shelf(["a", None, None]),
            standard_shelf(["b", "b", "b"]),
        ]
        for visible_count in [2, 3]:
            with self.subTest(visible_count=visible_count):
                rules = CollapsingColumnsRules(visible_count)
                state = collapsing_shelves_to_state(shelves, [3])
                result = solve_level(state, max_states=20000, max_depth=200, keep_solution=False, rules=rules)
                self.assertTrue(result.solvable, result.reason)

    ## Item counts alone cannot see this: every item has exactly three copies, but the only workspace
    ## that could finish either triple is behind a shelf that can never be emptied first.
    def test_reports_a_board_whose_required_workspace_is_hidden_unsolvable(self) -> None:
        shelves = [
            standard_shelf(["a", "a", None]),
            standard_shelf(["b", "b", None]),
            standard_shelf(["a", "b", None]),
        ]
        errors, counts = validate_shelves_shape(shelves, set(), skip_known_items=True)
        self.assertEqual(errors, [])
        self.assertEqual(dict(counts), {"a": 3, "b": 3})

        rules = CollapsingColumnsRules(2)
        state = collapsing_shelves_to_state(shelves, [3])
        result = solve_level(state, max_states=20000, max_depth=200, keep_solution=False, rules=rules)
        self.assertFalse(result.solvable, result.reason)

    def test_an_emptied_shelf_is_destroyed_and_never_offered_again(self) -> None:
        shelves = [
            standard_shelf(["a", None, None]),
            standard_shelf(["a", "a", None]),
            standard_shelf(["b", "b", None]),
            standard_shelf(["b", None, None]),
        ]
        rules = CollapsingColumnsRules(4)
        state = rules.settle(collapsing_shelves_to_state(shelves, [4]))
        self.assertEqual(column_shelf_ids(state), [[0, 1, 2, 3]])

        emptying_move = next(
            move for move in rules.legal_moves(state)
            if move.from_shelf == 0 and move.to_shelf == 1 and move.to_slot == 2
        )
        after = rules.settle(rules.apply_move(state, emptying_move))

        # Shelf 1 emptied, shelf 2 completed its triple; both are gone and the survivors keep order.
        self.assertEqual(column_shelf_ids(after), [[2, 3]])
        self.assertEqual(after[0], 1)
        remaining_ids = {move.from_shelf for move in rules.legal_moves(after)} | {
            move.to_shelf for move in rules.legal_moves(after)
        }
        self.assertTrue(remaining_ids <= {2, 3})

    def test_removes_several_empty_shelves_from_one_column_in_one_settle_pass(self) -> None:
        shelves = [
            standard_shelf(["a", "a", "a"]),
            standard_shelf(["b", "b", "b"]),
            standard_shelf(["c", "c", None]),
            standard_shelf(["c", None, None]),
        ]
        rules = CollapsingColumnsRules(4)
        settled = rules.settle(collapsing_shelves_to_state(shelves, [4]))
        self.assertEqual(settled[0], 2)
        self.assertEqual(column_shelf_ids(settled), [[2, 3]])

    ## Discovery order must not decide the result: the same column settles to the same survivors and
    ## the same order whichever end the removals are found from.
    def test_survivor_order_does_not_depend_on_discovery_order(self) -> None:
        shelves = [
            standard_shelf(["a", "a", "a"]),
            standard_shelf(["d", None, None]),
            standard_shelf(["b", "b", "b"]),
            standard_shelf(["e", None, None]),
            standard_shelf(["c", "c", "c"]),
        ]
        rules = CollapsingColumnsRules(5)
        settled = rules.settle(collapsing_shelves_to_state(shelves, [5]))
        self.assertEqual(column_shelf_ids(settled), [[1, 3]])
        self.assertEqual(settled[0], 3)

    def test_solution_coordinates_stay_replayable_after_earlier_shelves_disappear(self) -> None:
        level = collapsing_level(
            [3, 3],
            2,
            [
                standard_shelf(["a", "a", None]),
                standard_shelf(["a", "b", None]),
                standard_shelf(["b", "b", None]),
                standard_shelf(["c", "c", "c"]),
                standard_shelf(["d", "d", None]),
                standard_shelf(["d", None, None]),
            ],
        )
        self.assertEqual(collapsing_errors(level), [])
        rules, state = build_search_inputs(level, level["shelves"])
        result = solve_level(state, max_states=20000, max_depth=200, keep_solution=True, rules=rules)
        self.assertTrue(result.solvable, result.reason)

        # Every reported coordinate is an authored shelf ID, and replaying them in order against the
        # authored board still clears it even though shelves are destroyed along the way.
        authored_ids = set(range(len(level["shelves"])))
        for move in result.solution:
            self.assertIn(move.from_shelf, authored_ids)
            self.assertIn(move.to_shelf, authored_ids)
        self.assertTrue(rules.is_cleared(replay(rules, state, result.solution)))

    def test_completion_requires_destroying_every_shelf(self) -> None:
        rules = CollapsingColumnsRules(2)
        state = collapsing_shelves_to_state(
            [standard_shelf(["a", "a", "a"]), standard_shelf(["b", "b", "b"])], [2]
        )
        self.assertFalse(rules.is_cleared(state))
        self.assertTrue(rules.is_cleared(rules.settle(state)))


## The campaign guard: a shipped collapsing level must stay provably finishable. Classic levels are
## covered by their own generation-time proof and are skipped here.
class CommittedCollapsingLevelTests(unittest.TestCase):
    def test_every_committed_collapsing_campaign_level_is_valid_and_solvable(self) -> None:
        levels_directory = REPOSITORY_ROOT / "configs" / "levels"
        collapsing_paths = []
        for level_path in sorted(levels_directory.glob("level_*.json")):
            level = json.loads(level_path.read_text(encoding="utf-8"))
            if level.get("gameplay_mode") == "collapsing_columns":
                collapsing_paths.append((level_path, level))

        self.assertTrue(collapsing_paths, "no committed collapsing campaign level to check")
        for level_path, level in collapsing_paths:
            with self.subTest(level=level_path.name):
                shelves = level["shelves"]
                errors, _counts = validate_shelves_shape(shelves, set(), skip_known_items=True)
                errors += validate_gameplay_mode_shape(level, shelves)
                self.assertEqual(errors, [])

                rules, state = build_search_inputs(level, shelves)
                result = solve_level(state, max_states=60000, max_depth=400, keep_solution=False, rules=rules)
                self.assertTrue(result.solvable, f"{level_path.name}: {result.reason}")


class CollapsingColumnCanonicalizationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.rules = CollapsingColumnsRules(4)

    def canonical(self, shelves, shelf_counts):
        return self.rules.canonicalize(collapsing_shelves_to_state(shelves, shelf_counts))

    def test_slot_order_inside_one_shelf_is_normalized(self) -> None:
        left = self.canonical([standard_shelf(["a", None, "b"])], [1])
        right = self.canonical([standard_shelf(["b", "a", None])], [1])
        self.assertEqual(left, right)

    ## The classic canonicalizer sorted every shelf into one global order, which erased exactly the
    ## information this mode plays on: which pile a shelf is in and what sits under it.
    def test_column_topology_produces_distinct_canonical_states(self) -> None:
        shelves = [
            standard_shelf(["a", None, None]),
            standard_shelf(["b", None, None]),
            standard_shelf(["c", None, None]),
        ]
        self.assertNotEqual(self.canonical(shelves, [2, 1]), self.canonical(shelves, [1, 2]))

    def test_stack_order_inside_a_column_produces_distinct_canonical_states(self) -> None:
        bottom_first = [standard_shelf(["a", None, None]), standard_shelf(["b", None, None])]
        top_first = [standard_shelf(["b", None, None]), standard_shelf(["a", None, None])]
        self.assertNotEqual(self.canonical(bottom_first, [2]), self.canonical(top_first, [2]))

    def test_column_order_produces_distinct_canonical_states(self) -> None:
        left_first = [standard_shelf(["a", None, None]), standard_shelf(["b", None, None])]
        right_first = [standard_shelf(["b", None, None]), standard_shelf(["a", None, None])]
        self.assertNotEqual(self.canonical(left_first, [1, 1]), self.canonical(right_first, [1, 1]))


if __name__ == "__main__":
    unittest.main()
