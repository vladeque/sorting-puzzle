from __future__ import annotations

import sys
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOLS_PATH = REPOSITORY_ROOT / "scripts" / "tools"
sys.path.insert(0, str(TOOLS_PATH))

from level_flow import (  # noqa: E402
    AVAILABLE_WITHIN_MOVES,
    SCARCE_OPTION_COUNT,
    collectible_front_types,
    completion_costs,
    flow_for_level,
    move_limit_for,
    simulate_flow,
)
from validate_level_solvable import (  # noqa: E402
    CLASSIC_RULES,
    CollapsingColumnsRules,
    collapsing_shelves_to_state,
    shelves_to_state,
)


def shelf(*layers: list[str | None], **extra) -> dict:
    return {"layers": [list(layer) for layer in layers], **extra}


def accessible(shelves: list[dict]):
    return CLASSIC_RULES.accessible_shelves(shelves_to_state(shelves))


class CompletionCostTests(unittest.TestCase):
    def test_a_pair_beside_a_free_slot_is_a_one_move_match(self) -> None:
        shelves = [
            shelf(["apple", "apple", None]),
            shelf(["apple", "pear", "plum"]),
        ]
        self.assertEqual(completion_costs(accessible(shelves))["apple"], 1)

    def test_three_copies_on_three_shelves_cost_two_moves(self) -> None:
        shelves = [
            shelf(["apple", None, None]),
            shelf(["apple", "pear", None]),
            shelf(["apple", "plum", None]),
        ]
        self.assertEqual(completion_costs(accessible(shelves))["apple"], 2)

    def test_blockers_on_the_host_shelf_add_to_the_cost(self) -> None:
        # The only shelf holding a copy is full, so both blockers have to be parked first.
        shelves = [
            shelf(["apple", "pear", "plum"]),
            shelf(["apple", None, None]),
            shelf(["apple", None, None]),
            shelf([None, None, None]),
        ]
        costs = completion_costs(accessible(shelves))
        # Hosting on shelf 1 costs two carried copies; hosting on the crowded shelf would cost more.
        self.assertEqual(costs["apple"], 2)

    def test_a_type_with_two_copies_is_not_completable(self) -> None:
        shelves = [shelf(["apple", "apple", None]), shelf(["pear", None, None])]
        self.assertNotIn("apple", completion_costs(accessible(shelves)))

    def test_a_board_with_no_free_slot_offers_nothing(self) -> None:
        shelves = [
            shelf(["apple", "pear", "plum"]),
            shelf(["apple", "pear", "plum"]),
            shelf(["apple", "pear", "plum"]),
        ]
        self.assertEqual(completion_costs(accessible(shelves)), {})

    def test_a_locked_shelf_contributes_neither_copies_nor_space(self) -> None:
        shelves = [
            shelf(["apple", "apple", None]),
            shelf(["apple", None, None], unlock_after_triples=5),
        ]
        self.assertNotIn("apple", completion_costs(accessible(shelves)))

    def test_a_dispenser_hands_out_copies_but_never_hosts_a_triple(self) -> None:
        shelves = [
            shelf(["apple"], ["apple"], type="dispenser"),
            shelf(["apple", None, None]),
        ]
        costs = completion_costs(accessible(shelves))
        # Two copies reachable on the dispenser front plus one on the shelf is not three: only the
        # dispenser's front layer is exposed, so the board cannot finish this triple yet.
        self.assertNotIn("apple", costs)

    def test_a_sticky_item_restricts_its_shelf_to_its_own_triple(self) -> None:
        shelves = [
            shelf(["apple", None, None], sticky_items=[{"layer": 0, "slot": 0}]),
            shelf(["pear", "pear", None]),
            shelf(["pear", None, None]),
        ]
        costs = completion_costs(accessible(shelves))
        self.assertNotIn("apple", costs)
        # Pear still completes on its own shelf, which holds no sticky item.
        self.assertEqual(costs["pear"], 1)

    def test_collectible_front_types_can_be_bounded_by_move_cost(self) -> None:
        shelves = [
            shelf(["apple", "apple", None]),
            shelf(["apple", "pear", None]),
            shelf(["pear", None, None]),
            shelf(["pear", None, None]),
        ]
        every = collectible_front_types(accessible(shelves))
        cheap = collectible_front_types(accessible(shelves), max_moves=1)
        self.assertEqual(every, {"apple", "pear"})
        self.assertEqual(cheap, {"apple"})


class SimulateFlowTests(unittest.TestCase):
    def test_a_board_that_is_one_move_from_done_finishes_with_an_option_in_hand(self) -> None:
        shelves = [shelf(["apple", "apple", None]), shelf(["apple", None, None])]
        report = simulate_flow(CLASSIC_RULES, shelves_to_state(shelves))
        self.assertTrue(report.completed)
        self.assertEqual(report.cleared_triples, 1)
        self.assertEqual(report.total_triples, 1)
        self.assertGreaterEqual(report.average_options, 1.0)
        self.assertEqual(report.zero_option_ratio, 0.0)

    def test_an_already_matching_layer_settles_before_the_walk_starts(self) -> None:
        shelves = [shelf(["apple", "apple", "apple"])]
        report = simulate_flow(CLASSIC_RULES, shelves_to_state(shelves))
        self.assertTrue(report.completed)
        self.assertEqual(report.moves, 0)

    def test_a_jammed_board_reports_itself_unfinished_rather_than_looping(self) -> None:
        # Every front layer is full and nothing matches, so there is no legal move at all.
        shelves = [
            shelf(["apple", "pear", "plum"]),
            shelf(["apple", "pear", "plum"]),
            shelf(["apple", "pear", "plum"]),
        ]
        report = simulate_flow(CLASSIC_RULES, shelves_to_state(shelves))
        self.assertFalse(report.completed)
        self.assertEqual(report.moves, 0)
        self.assertEqual(report.average_options, 0.0)

    def test_scarce_ratio_counts_moves_with_at_most_one_option(self) -> None:
        shelves = [shelf(["apple", "apple", None]), shelf(["apple", None, None])]
        report = simulate_flow(CLASSIC_RULES, shelves_to_state(shelves))
        # One option throughout: a single triple is all this board has.
        self.assertEqual(report.scarce_option_ratio, 1.0)
        self.assertLessEqual(max(report.option_samples), SCARCE_OPTION_COUNT)

    def test_the_walk_budget_scales_with_the_board(self) -> None:
        small = shelves_to_state([shelf(["apple", "apple", "apple"])])
        self.assertGreaterEqual(move_limit_for(CLASSIC_RULES, small), 120)

    def test_the_walk_is_deterministic(self) -> None:
        shelves = [
            shelf(["apple", "pear", None], ["plum", "plum", None]),
            shelf(["apple", "plum", None], ["pear", "apple", None]),
            shelf(["pear", None, None], [None, None, None]),
        ]
        first = simulate_flow(CLASSIC_RULES, shelves_to_state(shelves))
        second = simulate_flow(CLASSIC_RULES, shelves_to_state(shelves))
        self.assertEqual(first, second)

    def test_options_are_counted_within_the_move_budget(self) -> None:
        # Apple is one move away; plum needs three blockers parked first and so is not "available".
        shelves = [
            shelf(["apple", "apple", None]),
            shelf(["apple", "pear", "cake"]),
            shelf(["plum", "pear", "cake"]),
            shelf(["plum", "pear", "cake"]),
            shelf(["plum", "pear", "cake"]),
        ]
        costs = completion_costs(accessible(shelves))
        self.assertEqual(costs["apple"], 1)
        self.assertGreater(costs.get("plum", 99), AVAILABLE_WITHIN_MOVES)


class CollapsingColumnFlowTests(unittest.TestCase):
    def test_a_collapsing_board_is_walked_through_its_visible_window(self) -> None:
        shelves = [shelf(["apple", "apple", None]), shelf(["apple", "pear", None]),
                   shelf(["pear", "pear", None])]
        rules = CollapsingColumnsRules(visible_count=3, kept_shelves_per_column=0)
        state = collapsing_shelves_to_state(shelves, [3])
        report = simulate_flow(rules, state)
        self.assertTrue(report.completed)
        self.assertEqual(report.total_triples, 2)

    def test_a_shelf_above_the_window_offers_nothing_yet(self) -> None:
        shelves = [shelf(["apple", "apple", None]), shelf(["pear", "pear", "plum"]),
                   shelf(["apple", None, None])]
        rules = CollapsingColumnsRules(visible_count=2, kept_shelves_per_column=0)
        state = rules.settle(collapsing_shelves_to_state(shelves, [3]))
        # The third apple is still stacked above the two-shelf window.
        self.assertNotIn("apple", completion_costs(rules.accessible_shelves(state)))


class FlowForLevelTests(unittest.TestCase):
    def test_throwing_dispenser_levels_have_no_board_to_walk(self) -> None:
        level_data = {
            "gameplay_mode": "throwing_dispensers",
            "throw_seed": "0123456789abcdef",
            "dispensers": [{"contents": ["apple"] * 3, "throw_count": 3}],
            "shelves": [shelf([None, None, None])],
        }
        self.assertIsNone(flow_for_level(level_data, level_data["shelves"]))

    def test_every_shipped_classic_level_can_be_measured(self) -> None:
        import json

        for level_path in sorted((REPOSITORY_ROOT / "configs" / "levels").glob("level_*.json")):
            level_data = json.loads(level_path.read_text(encoding="utf-8"))
            with self.subTest(level=level_path.name):
                report = flow_for_level(level_data, level_data["shelves"])
                if report is None:
                    continue
                self.assertGreaterEqual(report.average_options, 0.0)
                self.assertGreaterEqual(report.total_triples, 1)


if __name__ == "__main__":
    unittest.main()
