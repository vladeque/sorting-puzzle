from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOLS_PATH = REPOSITORY_ROOT / "scripts" / "tools"
sys.path.insert(0, str(TOOLS_PATH))

from validate_level_solvable import (  # noqa: E402
    KEPT_SHELVES_PER_COLUMN,
    LAYOUT_PRESET_ROW_LAYOUTS,
    MAX_VISIBLE_SHELVES_PER_COLUMN,
    CollapsingColumnsRules,
    Move,
    ThrowingBoard,
    ThrowingDispensersRules,
    apply_move,
    build_search_inputs,
    canonicalize_shelf,
    canonicalize_state,
    collapsing_shelves_to_state,
    is_empty_layer,
    legal_moves,
    normalize_state,
    settle_state,
    shelves_to_state,
    solve_level,
    validate_gameplay_mode_shape,
    validate_shelves_shape,
    visible_layer,
)


def standard_shelf(*layers: list[str | None]) -> dict[str, object]:
    return {"layers": [list(layer) for layer in layers]}


def dispenser_shelf(*items: str) -> dict[str, object]:
    return {"type": "dispenser", "layers": [[item] for item in items]}


class MovingLayoutPresetMetadataTests(unittest.TestCase):
    def test_shape_moving_presets_match_their_scene_shelf_groups(self) -> None:
        expected = {
            "shape_arch_3x5_moving_5_bottom": ([9, 5], "horizontal_wrap", "left", 3),
            "shape_alternating_alcoves_3x5_moving_8_center": (
                [8, 5], "vertical_wrap", "down", 4
            ),
            "shape_hourglass_3x5_moving_5_waist": (
                [3, 1, 5, 1, 3], "horizontal_wrap", "right", 3
            ),
            "shape_side_elevator_steps_3x5_moving_8_left": (
                [8, 7], "vertical_wrap", "down", 4
            ),
        }
        for preset, (shelf_counts, motion_type, direction, visible_count) in expected.items():
            with self.subTest(preset=preset):
                row_layouts = LAYOUT_PRESET_ROW_LAYOUTS[preset]
                self.assertEqual([row["shelf_count"] for row in row_layouts], shelf_counts)
                moving_layouts = [row for row in row_layouts if "motion" in row]
                self.assertEqual(len(moving_layouts), 1)
                self.assertEqual(moving_layouts[0]["motion"]["type"], motion_type)
                self.assertEqual(moving_layouts[0]["motion"]["direction"], direction)
                self.assertEqual(moving_layouts[0]["visible_count"], visible_count)

    def test_top_bottom_belt_preset_matches_its_scene_shelf_groups(self) -> None:
        row_layouts = LAYOUT_PRESET_ROW_LAYOUTS["grid_3x2_moving_5_5_top_bottom"]
        self.assertEqual([row["shelf_count"] for row in row_layouts], [5, 3, 3, 5])
        moving_layouts = [row for row in row_layouts if "motion" in row]
        self.assertEqual(
            [row["motion"]["direction"] for row in moving_layouts], ["right", "left"]
        )


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


def sticky_shelf(layer: list[str | None], *sticky: tuple[int, int]) -> dict[str, object]:
    return {
        "layers": [list(layer)],
        "sticky_items": [{"layer": layer_index, "slot": slot} for layer_index, slot in sticky],
    }


## The search canonicalizes, settles and applies a move for every successor it generates, so these
## three carry a solvability run. Each has a fast path for the common shape, and each fast path has
## to land on exactly the board the general one would have produced.
class HotPathEquivalenceTests(unittest.TestCase):
    def test_a_shelf_without_sticky_items_sorts_its_items_ahead_of_its_empty_slots(self) -> None:
        shelf = shelves_to_state([standard_shelf(["b", None, "a"])])[1][0]
        self.assertEqual(canonicalize_shelf(shelf).layers, (("a", "b", None),))

    def test_slot_order_alone_does_not_distinguish_two_boards(self) -> None:
        left = canonicalize_state(shelves_to_state([standard_shelf([None, "a", "b"])]))
        right = canonicalize_state(shelves_to_state([standard_shelf(["b", "a", None])]))
        self.assertEqual(left, right)

    ## A sticky item is pinned to its slot, so it cannot be reordered into the item run the way a
    ## loose copy of the same id can.
    def test_a_sticky_anchor_keeps_its_shelf_distinct_from_a_loose_one(self) -> None:
        sticky = canonicalize_state(shelves_to_state([sticky_shelf(["a", "b", None], (0, 0))]))
        loose = canonicalize_state(shelves_to_state([standard_shelf(["a", "b", None])]))
        self.assertNotEqual(sticky, loose)

    def test_canonicalization_is_stable_across_equivalent_sticky_boards(self) -> None:
        left = canonicalize_state(shelves_to_state([sticky_shelf(["a", None, "b"], (0, 2))]))
        right = canonicalize_state(shelves_to_state([sticky_shelf([None, "a", "b"], (0, 2))]))
        self.assertEqual(left, right)

    def test_a_board_with_nothing_to_settle_is_left_alone(self) -> None:
        state = shelves_to_state([standard_shelf(["a", "b", None]), standard_shelf(["c", "a", "b"])])
        self.assertEqual(settle_state(state), state)

    def test_settling_clears_a_finished_triple_and_cascades_into_an_unlocked_shelf(self) -> None:
        shelves = [
            standard_shelf(["a", "a", "a"], ["b", "b", "b"]),
            {"layers": [["c", "c", "c"]], "unlock_after_triples": 2},
        ]
        triples_cleared, settled = settle_state(shelves_to_state(shelves))
        self.assertEqual(triples_cleared, 3)
        self.assertEqual([shelf.layers for shelf in settled], [(), ()])

    ## A locked shelf holds its contents until its triple count is reached, even when its front
    ## layer already matches.
    def test_settling_leaves_a_locked_shelf_untouched(self) -> None:
        shelves = [{"layers": [["a", "a", "a"]], "unlock_after_triples": 5}]
        state = shelves_to_state(shelves)
        self.assertEqual(settle_state(state), state)

    def test_a_move_changes_only_the_two_shelves_it_touches(self) -> None:
        shelves = [
            standard_shelf(["a", "b", None]),
            standard_shelf(["c", None, None]),
            standard_shelf(["d", "e", "f"], ["g", "h", "i"]),
        ]
        _cleared, before = shelves_to_state(shelves)
        _cleared, after = apply_move((0, before), Move("a", 0, 0, 1, 1))
        self.assertEqual(after[0].layers, ((None, "b", None),))
        self.assertEqual(after[1].layers, (("c", "a", None),))
        self.assertIs(after[2], before[2])

    ## A shelf the player emptied earlier is still a drop target, so it has to grow a layer back.
    def test_a_move_onto_an_emptied_shelf_grows_a_layer_back(self) -> None:
        state = settle_state(
            shelves_to_state([standard_shelf(["a", "b", None]), standard_shelf([None, None, None])])
        )
        _cleared, shelves = state
        self.assertEqual(shelves[1].layers, ())
        _cleared, moved = apply_move(state, Move("a", 0, 0, 1, 0))
        self.assertEqual(moved[1].layers, (("a", None, None),))
        self.assertEqual(moved[0].layers, ((None, "b", None),))

    def test_a_move_keeps_the_layers_behind_the_front_one(self) -> None:
        shelves = [standard_shelf(["a", None, None], ["x", "y", "z"]), standard_shelf([None] * 3)]
        state = shelves_to_state(shelves)
        _cleared, moved = apply_move(state, Move("a", 0, 0, 1, 2))
        self.assertEqual(moved[0].layers, ((None, None, None), ("x", "y", "z")))
        self.assertEqual(moved[1].layers, ((None, None, "a"),))


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
        rules = CollapsingColumnsRules(4, kept_shelves_per_column=0)
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
        rules = CollapsingColumnsRules(4, kept_shelves_per_column=0)
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
        rules = CollapsingColumnsRules(5, kept_shelves_per_column=0)
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

    def test_completion_requires_an_item_free_board_not_an_empty_one(self) -> None:
        rules = CollapsingColumnsRules(2)
        state = collapsing_shelves_to_state(
            [standard_shelf(["a", "a", "a"]), standard_shelf(["b", "b", "b"])], [2]
        )
        self.assertFalse(rules.is_cleared(state))
        settled = rules.settle(state)
        self.assertTrue(rules.is_cleared(settled))
        # Both shelves are within the kept floor, so the cleared board still has them.
        self.assertEqual(column_shelf_ids(settled), [[0, 1]])


class CollapsingColumnKeptShelfTests(unittest.TestCase):
    def test_the_floor_is_the_shipped_count_capped_at_the_window(self) -> None:
        self.assertEqual(CollapsingColumnsRules(4).kept_count, KEPT_SHELVES_PER_COLUMN)
        self.assertEqual(CollapsingColumnsRules(2).kept_count, 2)
        self.assertEqual(CollapsingColumnsRules(4, kept_shelves_per_column=0).kept_count, 0)

    ## Two shelves are emptied at once but the column may lose only one: the lowest goes, and the
    ## other stays as an empty, reusable shelf.
    def test_a_column_stops_collapsing_at_the_floor_and_destroys_its_lowest_shelves_first(self) -> None:
        shelves = [
            standard_shelf(["a", "a", "a"]),
            standard_shelf(["b", "b", "b"]),
            standard_shelf(["c", None, None]),
            standard_shelf(["c", "c", None]),
        ]
        rules = CollapsingColumnsRules(4)
        settled = rules.settle(collapsing_shelves_to_state(shelves, [4]))
        self.assertEqual(settled[0], 2)
        self.assertEqual(column_shelf_ids(settled), [[1, 2, 3]])
        kept = settled[1][0][0].state
        self.assertTrue(is_empty_layer(visible_layer(kept)))
        self.assertTrue(any(move.to_shelf == 1 for move in rules.legal_moves(settled)))

    ## The deadlock the floor exists for: once the third shelf clears, `aab` and `bba` fill every
    ## remaining slot. Destroying that shelf leaves no move at all; keeping it leaves room to sort.
    def test_kept_shelves_keep_room_to_sort_at_the_end(self) -> None:
        shelves = [
            standard_shelf(["a", "a", "b"]),
            standard_shelf(["b", "b", "a"]),
            standard_shelf(["c", "c", "c"]),
        ]
        state = collapsing_shelves_to_state(shelves, [3])
        destroying = CollapsingColumnsRules(3, kept_shelves_per_column=0)
        result = solve_level(state, max_states=20000, max_depth=200, keep_solution=False, rules=destroying)
        self.assertFalse(result.solvable, result.reason)

        keeping = CollapsingColumnsRules(3)
        result = solve_level(state, max_states=20000, max_depth=200, keep_solution=True, rules=keeping)
        self.assertTrue(result.solvable, result.reason)
        self.assertTrue(keeping.is_cleared(replay(keeping, state, result.solution)))


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


def empty_shelf() -> dict[str, object]:
    return {"layers": [[None, None, None]]}


def throwing_level(**overrides: object) -> dict[str, object]:
    level: dict[str, object] = {
        "level": 21,
        "time_seconds": 300,
        "gameplay_mode": "throwing_dispensers",
        "layout_preset": "grid_3x4",
        "throw_seed": "00000000000052ad",
        "dispensers": [{"throw_count": 3, "contents": ["a", "b", "a", "a", "b", "b"]}],
        "shelves": [empty_shelf() for _ in range(4)],
    }
    level.update(overrides)
    return level


class ThrowingDispenserContractTests(unittest.TestCase):
    def errors(self, level: dict[str, object]) -> list[str]:
        return validate_gameplay_mode_shape(level, level["shelves"])

    def test_a_valid_level_passes(self) -> None:
        self.assertEqual(self.errors(throwing_level()), [])

    def test_shelves_must_start_empty(self) -> None:
        level = throwing_level(shelves=[{"layers": [["a", None, None]]}])
        self.assertIn("shelf 1 must start empty; every item begins in a dispenser", self.errors(level))

    def test_a_second_layer_is_rejected(self) -> None:
        level = throwing_level(shelves=[{"layers": [[None] * 3, [None] * 3]}])
        self.assertIn("shelf 1 must have exactly one layer", self.errors(level))

    def test_locked_sticky_and_dispenser_shelves_are_rejected(self) -> None:
        locked = throwing_level(shelves=[{"unlock_after_triples": 2, "layers": [[None] * 3]}])
        self.assertIn("shelf 1 is locked; locked shelves are not supported", self.errors(locked))

        sticky = throwing_level(
            shelves=[{"layers": [[None] * 3], "sticky_items": [{"layer": 0, "slot": 1}]}]
        )
        self.assertIn(
            "shelf 1 has sticky items; sticky items are not supported", self.errors(sticky)
        )

        # The source-only *shelf* type is a different object that happens to share the word.
        source_shelf = throwing_level(shelves=[dispenser_shelf("a", "b")])
        self.assertIn("shelf 1 must be a standard shelf", self.errors(source_shelf))

    def test_exclusive_layout_keys_are_rejected(self) -> None:
        self.assertIn(
            "row_layouts cannot be combined with gameplay_mode 'throwing_dispensers'",
            self.errors(throwing_level(row_layouts=[{"shelf_count": 4}])),
        )
        self.assertIn(
            "column_layout cannot be combined with gameplay_mode 'throwing_dispensers'",
            self.errors(throwing_level(column_layout={"shelf_counts": [4]})),
        )

    ## Every one of these silently changes the scatter the level was tuned against.
    def test_malformed_seeds_are_rejected(self) -> None:
        for bad_seed in ("", "52ad", "00000000000052AD", "0x0000000000052a", "zzzzzzzzzzzzzzzz"):
            with self.subTest(seed=bad_seed):
                self.assertIn(
                    "throw_seed must be a 16-digit lowercase hex string",
                    self.errors(throwing_level(throw_seed=bad_seed)),
                )

    def test_dispenser_shape_is_enforced(self) -> None:
        self.assertIn(
            "dispensers must be a non-empty array when gameplay_mode is 'throwing_dispensers'",
            self.errors(throwing_level(dispensers=[])),
        )
        self.assertIn(
            "dispenser 1 throw_count must be a positive integer",
            self.errors(throwing_level(dispensers=[{"throw_count": 0, "contents": ["a"] * 3}])),
        )
        # A hole has nothing to throw, and unlike a shelf slot nothing can ever move into it.
        self.assertIn(
            "dispenser 1 contents entry 2 must be an item ID string",
            self.errors(
                throwing_level(dispensers=[{"throw_count": 3, "contents": ["a", None, "a"]}])
            ),
        )

    def test_item_totals_are_counted_across_dispensers(self) -> None:
        self.assertIn(
            "item 'a' appears 2 times across dispensers, expected a multiple of 3",
            self.errors(throwing_level(dispensers=[{"throw_count": 3, "contents": ["a", "a"]}])),
        )
        split = throwing_level(
            dispensers=[
                {"throw_count": 3, "contents": ["a", "a"]},
                {"throw_count": 3, "contents": ["a"]},
            ]
        )
        self.assertEqual(self.errors(split), [])

    ## A throw is clamped to the room the board has, so this is not unsafe -- but a level authored to
    ## throw more than the board can ever hold is not the level its author described.
    def test_a_throw_larger_than_the_board_is_reported(self) -> None:
        level = throwing_level(
            shelves=[empty_shelf()],
            dispensers=[{"throw_count": 3, "contents": ["a"] * 3}],
        )
        self.assertIn(
            "dispenser 1 throw_count is 3, more than the 2 slots a throw may ever fill",
            self.errors(level),
        )

    ## The guard runs on every level, so another mode carrying these fields has to be told they mean
    ## nothing there rather than having them quietly ignored.
    def test_other_modes_reject_dispenser_fields(self) -> None:
        classic = {
            "shelves": [standard_shelf(["a", "a", "a"])],
            "dispensers": [{"throw_count": 3, "contents": ["a"] * 3}],
        }
        self.assertIn(
            "dispensers is only valid when gameplay_mode is 'throwing_dispensers'",
            validate_gameplay_mode_shape(classic, classic["shelves"]),
        )

        seeded = {"shelves": [standard_shelf(["a", "a", "a"])], "throw_seed": "00000000000052ad"}
        self.assertIn(
            "throw_seed is only valid when gameplay_mode is 'throwing_dispensers'",
            validate_gameplay_mode_shape(seeded, seeded["shelves"]),
        )

        plain = {"shelves": [standard_shelf(["a", "a", "a"])]}
        self.assertEqual(validate_gameplay_mode_shape(plain, plain["shelves"]), [])


class ThrowingDispenserPlayabilityTests(unittest.TestCase):
    ## The mode is sampled rather than proven, so what matters is that the estimate separates a board
    ## a player can finish from one nobody could.
    def test_a_roomy_board_is_playable(self) -> None:
        rules = ThrowingDispensersRules(
            [{"throw_count": 3, "contents": ["a", "b", "a", "b", "a", "b"]}],
            6,
            "00000000000052ad",
        )
        result, stats = rules.estimate_playability(trials=25)
        self.assertTrue(result.solvable)
        self.assertEqual(stats["completion_rate"], 1.0)
        self.assertEqual(stats["failure_reasons"], {})

    ## One shelf holds two items once the reserved slot is kept, so a triple can never be assembled.
    def test_a_board_too_small_to_hold_a_triple_is_not_playable(self) -> None:
        rules = ThrowingDispensersRules(
            [{"throw_count": 3, "contents": ["a", "a", "a"]}], 1, "00000000000052ad"
        )
        result, stats = rules.estimate_playability(trials=25)
        self.assertFalse(result.solvable)
        self.assertEqual(stats["completion_rate"], 0.0)
        self.assertEqual(stats["failure_reasons"], {"stuck": 25})

    ## A throw never takes the last free slot. Without that rule the board can reach zero free slots,
    ## and a move needs somewhere to land, so the level would be over with items still on the shelves.
    def test_a_throw_never_takes_the_last_free_slot(self) -> None:
        board = ThrowingBoard(1, [{"throw_count": 9, "contents": ["a"] * 9}])
        self.assertEqual(board.throw_size(0, len(board.free_slots())), 2)
        board.shelves[0][0] = "b"
        self.assertEqual(board.throw_size(0, len(board.free_slots())), 1)
        board.shelves[0][1] = "b"
        self.assertEqual(board.throw_size(0, len(board.free_slots())), 0)

    ## The level is over when nothing is left anywhere -- an empty board with stock still waiting is
    ## the middle of a level, not the end of one.
    def test_stock_still_held_is_not_a_cleared_level(self) -> None:
        board = ThrowingBoard(2, [{"throw_count": 3, "contents": ["a", "a", "a"]}])
        self.assertFalse(board.is_cleared())
        board.stocks[0].clear()
        self.assertTrue(board.is_cleared())

    def test_three_matching_items_on_one_shelf_clear(self) -> None:
        board = ThrowingBoard(2, [{"throw_count": 3, "contents": []}])
        board.shelves[0] = ["a", "a", "a"]
        board.resolve()
        self.assertEqual(board.shelves[0], [None, None, None])
        self.assertEqual(board.triples_cleared, 1)

    ## The mode has no search state, so it must not be handed to `solve_level()` by accident.
    def test_build_search_inputs_returns_no_search_state(self) -> None:
        level = throwing_level()
        rules, initial_state = build_search_inputs(level, level["shelves"])
        self.assertIsInstance(rules, ThrowingDispensersRules)
        self.assertIsNone(initial_state)
        with self.assertRaises(NotImplementedError):
            rules.legal_moves(None)


class CommittedThrowingLevelTests(unittest.TestCase):
    ## Guards the shipped fixture the same way the collapsing levels are guarded, so it cannot drift
    ## into an unplayable state unnoticed.
    def test_the_preview_fixture_is_valid_and_playable(self) -> None:
        fixture = REPOSITORY_ROOT / "configs" / "test_levels" / "throwing_dispensers_preview.json"
        level = json.loads(fixture.read_text(encoding="utf-8"))
        self.assertEqual(validate_gameplay_mode_shape(level, level["shelves"]), [])

        rules, _ = build_search_inputs(level, level["shelves"])
        result, stats = rules.estimate_playability(trials=50)
        self.assertTrue(result.solvable, stats)


if __name__ == "__main__":
    unittest.main()
