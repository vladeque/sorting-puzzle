from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts" / "tools"))

from generate_level_shelves import apply_sticky_items, count_collectible_front_types, generate_with_optional_validation
from level_item_progression import collect_logical_item_ids, load_item_progression, materialize_level
from sticky_items import validate_sticky_items
from validate_level_solvable import (Move, apply_move, canonicalize_state, is_cleared, legal_moves,
                                    settle_state, shelves_to_state, solve_level, validate_shelves_shape)


def board():
    return [
        {"layers": [["a", None, None], ["b", None, None]],
         "sticky_items": [{"layer": 0, "slot": 0}, {"layer": 1, "slot": 0}]},
        {"layers": [["a", "b", None]]},
        {"layers": [["a", "b", None]]},
    ]


class StickyContractTests(unittest.TestCase):
    def test_materialization_preserves_coordinates_and_maps_target(self):
        abstract = {"level": 1, "shelves": board()}
        for shelf in abstract["shelves"]:
            shelf["layers"] = [[{"a": "item_01", "b": "item_02"}.get(x) for x in layer]
                               for layer in shelf["layers"]]
        original = copy.deepcopy(abstract)
        runtime, mapping = materialize_level(abstract, load_item_progression())
        self.assertEqual(abstract, original)
        self.assertEqual(runtime["shelves"][0]["sticky_items"], abstract["shelves"][0]["sticky_items"])
        for entry in runtime["shelves"][0]["sticky_items"]:
            layer, slot = entry["layer"], entry["slot"]
            self.assertEqual(runtime["shelves"][0]["layers"][layer][slot],
                             mapping[abstract["shelves"][0]["layers"][layer][slot]])

    def test_one_per_layer_and_materializer_validation(self):
        shelves = board()
        self.assertEqual(validate_shelves_shape(shelves, set(), True)[0], [])
        for shelf in shelves:
            shelf["layers"] = [[{"a": "item_01", "b": "item_02"}.get(x) for x in layer]
                               for layer in shelf["layers"]]
        self.assertEqual(collect_logical_item_ids({"shelves": shelves}), ("item_01", "item_02"))
        shelves[0]["sticky_items"].append({"layer": 0, "slot": 1})
        with self.assertRaises(ValueError):
            collect_logical_item_ids({"shelves": shelves})

    def test_rejects_bad_coordinates_and_dispenser(self):
        invalid = [None, {}, [{"layer": True, "slot": 0}], [{"layer": 0.0, "slot": 0}],
                   [{"layer": -1, "slot": 0}], [{"layer": 4, "slot": 0}],
                   [{"layer": 0, "slot": 1}], [{"layer": 0, "slot": 0, "extra": True}],
                   [{"layer": 0, "slot": 0}, {"layer": 0, "slot": 0}]]
        for entries in invalid:
            with self.subTest(entries=entries):
                self.assertTrue(validate_sticky_items({"layers": [["a", None, None]], "sticky_items": entries}))
        self.assertTrue(validate_sticky_items({"type": "dispenser", "layers": [["a"]],
                                              "sticky_items": [{"layer": 0, "slot": 0}]}))


class StickySolverTests(unittest.TestCase):
    def test_shared_godot_fixture_replays_and_clears(self):
        fixture_path = Path(__file__).resolve().parents[1] / "fixtures" / "sticky_items_conformance.json"
        fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
        state = settle_state(shelves_to_state(fixture["config"]["shelves"]))
        for entry in fixture["solution"]:
            move = Move(entry["item"], entry["from_shelf"], entry["from_slot"],
                        entry["to_shelf"], entry["to_slot"])
            self.assertIn(move, legal_moves(state))
            state = settle_state(apply_move(state, move))
        self.assertTrue(is_cleared(state))

    def test_sticky_cannot_move_but_can_receive_and_promote(self):
        state = shelves_to_state(board())
        self.assertFalse(any(m.from_shelf == 0 for m in legal_moves(state)))
        with self.assertRaises(ValueError):
            apply_move(state, Move("a", 0, 0, 1, 2))
        state = settle_state(apply_move(state, Move("a", 1, 0, 0, 1)))
        state = settle_state(apply_move(state, Move("a", 2, 0, 0, 2)))
        self.assertEqual(state[1][0].layers[0][0], "b")
        self.assertEqual(state[1][0].sticky_items, ((0, 0),))
        self.assertEqual(state[0], 1)

    def test_solution_replays_in_original_coordinates(self):
        state = shelves_to_state(board())
        result = solve_level(state, 5000, 50, True)
        self.assertIs(result.solvable, True)
        state = settle_state(state)
        for move in result.solution:
            self.assertIn(move, legal_moves(state))
            state = settle_state(apply_move(state, move))
        self.assertTrue(is_cleared(state))

    def test_canonical_state_preserves_identity_of_sticky_item(self):
        a = [{"layers": [["a", "b", None]], "sticky_items": [{"layer": 0, "slot": 0}]}]
        equivalent = [{"layers": [["b", None, "a"]], "sticky_items": [{"layer": 0, "slot": 2}]}]
        different = [{"layers": [["a", "b", None]], "sticky_items": [{"layer": 0, "slot": 1}]}]
        self.assertEqual(canonicalize_state(shelves_to_state(a)), canonicalize_state(shelves_to_state(equivalent)))
        self.assertNotEqual(canonicalize_state(shelves_to_state(a)), canonicalize_state(shelves_to_state(different)))

    def test_insufficient_partners_and_depth_limit(self):
        shelves = [{"layers": [["a", None, None], ["a", None, None]],
                    "sticky_items": [{"layer": 0, "slot": 0}, {"layer": 1, "slot": 0}]},
                   {"layers": [["a", None, None]]}]
        self.assertIs(solve_level(shelves_to_state(shelves), 100, 20, False).solvable, False)
        limited = solve_level(shelves_to_state(board()), 500, 0, False)
        self.assertIsNone(limited.solvable)
        self.assertEqual(limited.reason, "depth_limit")


class StickyGenerationTests(unittest.TestCase):
    def test_cli_does_not_overwrite_output_when_proof_budget_is_exhausted(self):
        root = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "shelves.json"
            output.write_text("keep existing content", encoding="utf-8")
            result = subprocess.run([
                sys.executable, str(root / "scripts/tools/generate_level_shelves.py"),
                "--shelf-count", "6", "--layer-count", "2", "--difficulty", "easy",
                "--seed", "42", "--sticky-items-percent", "10", "--require-solvable",
                "--max-generation-attempts", "1", "--validator-max-states", "1",
                "--validator-max-depth", "1", "--output", str(output),
            ], cwd=root, capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(output.read_text(encoding="utf-8"), "keep existing content")

    def test_deterministic_matching_and_layer_capacity(self):
        source = [{"layers": [["a", "a", "a"], ["b", "b", "b"]]},
                  {"layers": [["c", "c", "c"]]}]
        a, b = copy.deepcopy(source), copy.deepcopy(source)
        stats = apply_sticky_items(a, 100, 41)
        self.assertEqual(stats, apply_sticky_items(b, 100, 41))
        self.assertEqual(a, b)
        self.assertEqual(stats["actual_count"], 3)
        self.assertEqual(stats["requested_count"], 9)
        self.assertEqual(len(a[0]["sticky_items"]), 2)
        self.assertEqual(stats["cap_reason"], "occupied_standard_layers")

    def test_invalid_percent_rounding_and_impossible_count(self):
        for percent in (-1, 101, float("nan"), float("inf")):
            with self.assertRaises(ValueError):
                apply_sticky_items(board(), percent, 1)
        shelves = [{"layers": [["a", "a", "a"]]}]
        self.assertEqual(apply_sticky_items(copy.deepcopy(shelves), 1, 1)["actual_count"], 0)
        self.assertEqual(apply_sticky_items(copy.deepcopy(shelves), 50, 1)["requested_count"], 2)
        with self.assertRaisesRegex(ValueError, "matching copies"):
            apply_sticky_items([{"layers": [["a", None, None]]} for _ in range(3)], 100, 1)

    def test_opening_does_not_count_two_sticky_partners(self):
        shelves = [{"layers": [["a", None, None]], "sticky_items": [{"layer": 0, "slot": 0}]},
                   {"layers": [["a", None, None]], "sticky_items": [{"layer": 0, "slot": 0}]},
                   {"layers": [["a", None, None]]}]
        self.assertEqual(count_collectible_front_types(shelves), 0)
        self.assertGreater(count_collectible_front_types(board()), 0)

    def test_zero_is_unchanged_and_positive_generation_solves(self):
        args = dict(shelf_count=6, layer_count=2, filled_layer_count=2, item_types=None,
                    difficulty="easy", seed=42, should_validate=False, require_solvable=True,
                    max_attempts=10, max_items_per_type_override=None, min_front_visible_triples=1,
                    max_states=5000, max_depth=100)
        old = generate_with_optional_validation(**args)
        self.assertEqual(old, generate_with_optional_validation(**args, sticky_items_percent=0))
        shelves, stats, validation, _ = generate_with_optional_validation(**args, sticky_items_percent=10)
        self.assertIs(validation["solvable"], True)
        self.assertGreater(stats["sticky_items"]["actual_count"], 0)
        self.assertEqual(validate_shelves_shape(shelves, set(), True)[0], [])


if __name__ == "__main__":
    unittest.main()
